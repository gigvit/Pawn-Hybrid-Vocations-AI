local state = require("PawnHybridVocationsAI/state")
local util = require("PawnHybridVocationsAI/core/util")
local discovery = require("PawnHybridVocationsAI/game/discovery")

local main_pawn_properties = {}

local main_pawn_candidates = {
    { source = "PawnManager:get_MainPawn()", manager = "PawnManager", kind = "method", key = "get_MainPawn" },
    { source = "PawnManager._MainPawn", manager = "PawnManager", kind = "field", key = "_MainPawn" },
    { source = "PawnManager.<MainPawn>k__BackingField", manager = "PawnManager", kind = "field", key = "<MainPawn>k__BackingField" },
    { source = "CharacterManager:get_MainPawn()", manager = "CharacterManager", kind = "method", key = "get_MainPawn" },
    { source = "CharacterManager.<MainPawn>k__BackingField", manager = "CharacterManager", kind = "field", key = "<MainPawn>k__BackingField" },
    { source = "CharacterManager:get_ManualPlayerPawn()", manager = "CharacterManager", kind = "method", key = "get_ManualPlayerPawn" },
    { source = "CharacterManager:get_ManualPlayerMainPawn()", manager = "CharacterManager", kind = "method", key = "get_ManualPlayerMainPawn" },
}

local character_candidates = {
    { source = "pawn", kind = "identity" },
    { source = "pawn:get_CachedCharacter()", kind = "method", key = "get_CachedCharacter" },
    { source = "pawn:get_Character()", kind = "method", key = "get_Character" },
    { source = "pawn:get_Chara()", kind = "method", key = "get_Chara" },
    { source = "pawn:get_PawnCharacter()", kind = "method", key = "get_PawnCharacter" },
    { source = "pawn.<CachedCharacter>k__BackingField", kind = "field", key = "<CachedCharacter>k__BackingField" },
    { source = "pawn.<Character>k__BackingField", kind = "field", key = "<Character>k__BackingField" },
    { source = "pawn.<Chara>k__BackingField", kind = "field", key = "<Chara>k__BackingField" },
    { source = "pawn.Character", kind = "field", key = "Character" },
    { source = "pawn.Chara", kind = "field", key = "Chara" },
}

local function call_first(obj, method_name)
    return util.safe_direct_method(obj, method_name)
        or util.safe_method(obj, method_name .. "()")
        or util.safe_method(obj, method_name)
end

local function field_first(obj, field_name)
    return util.safe_field(obj, field_name)
end

local function scan_for_types(root, wanted, depth, field_limit, out, seen)
    if not util.is_valid_obj(root) then
        return
    end

    local address = tostring(util.get_address(root) or "nil")
    if seen[address] then
        return
    end
    seen[address] = true

    local type_name = util.get_type_full_name(root)
    local wanted_key = wanted[type_name]
    if wanted_key ~= nil and out[wanted_key] == nil then
        out[wanted_key] = root
    end

    if depth <= 0 then
        return
    end

    local ok_td, td = pcall(function()
        return root:get_type_definition()
    end)
    if not ok_td or td == nil then
        return
    end

    local ok_fields, fields = pcall(td.get_fields, td)
    if not ok_fields or fields == nil then
        return
    end

    local max_fields = field_limit or 24
    for index, field in ipairs(fields) do
        if index > max_fields then
            break
        end

        local ok_value, value = pcall(field.get_data, field, root)
        if ok_value and util.is_valid_obj(value) then
            scan_for_types(value, wanted, depth - 1, field_limit, out, seen)
        end
    end
end

local function get_player()
    local character_manager = discovery.get_manager("CharacterManager")
    if character_manager == nil then
        return nil
    end

    return field_first(character_manager, "<ManualPlayer>k__BackingField")
        or field_first(character_manager, "_ManualPlayer")
        or call_first(character_manager, "get_ManualPlayer")
end

local function resolve_main_pawn()
    local errors = {}
    local resolved = nil
    local source = "unresolved"

    for _, spec in ipairs(main_pawn_candidates) do
        local manager = discovery.get_manager(spec.manager)
        if manager == nil then
            table.insert(errors, spec.manager .. "_missing")
        else
            local candidate = spec.kind == "field" and field_first(manager, spec.key) or call_first(manager, spec.key)
            if util.is_valid_obj(candidate) then
                resolved = candidate
                source = spec.source
                break
            end
        end
    end

    local recursive_hits = {}
    if not util.is_valid_obj(resolved) then
        local wanted = {
            ["app.Pawn"] = "pawn",
            ["app.Character"] = "character",
            ["via.GameObject"] = "game_object",
        }

        for _, root in ipairs({
            discovery.get_manager("PawnManager"),
            discovery.get_manager("CharacterManager"),
        }) do
            scan_for_types(root, wanted, 3, 24, recursive_hits, {})
        end

        if util.is_valid_obj(recursive_hits.pawn) then
            resolved = recursive_hits.pawn
            source = "recursive:app.Pawn"
        elseif util.is_valid_obj(recursive_hits.character) then
            resolved = recursive_hits.character
            source = "recursive:app.Character"
        end
    end

    state.discovery.main_pawn.source = source
    state.discovery.main_pawn.errors = errors
    state.discovery.main_pawn.candidate_count = util.is_valid_obj(resolved) and 1 or 0

    return resolved, recursive_hits
end

local function resolve_runtime_character(pawn, recursive_hits)
    local candidate_paths = {}

    local function accept(label, candidate)
        table.insert(candidate_paths, {
            source = label,
            result = util.describe_obj(candidate),
            type_name = util.get_type_full_name(candidate),
        })

        if util.is_valid_obj(candidate) and util.is_a(candidate, "app.Character") then
            state.discovery.main_pawn.character_source = label
            state.discovery.main_pawn.candidate_paths = candidate_paths
            return candidate
        end
        return nil
    end

    for _, spec in ipairs(character_candidates) do
        local candidate = nil
        if spec.kind == "identity" then
            candidate = pawn
        elseif spec.kind == "field" then
            candidate = field_first(pawn, spec.key)
        else
            candidate = call_first(pawn, spec.key)
        end

        local accepted = accept(spec.source, candidate)
        if accepted ~= nil then
            return accepted
        end
    end

    local game_object = util.resolve_game_object(pawn, false)
    local accepted = accept("pawn:resolved_game_object", game_object)
    if accepted ~= nil then
        return accepted
    end

    if util.is_valid_obj(game_object) then
        accepted = accept("pawn:resolved_game_object:app.Character", util.safe_get_component(game_object, "app.Character"))
        if accepted ~= nil then
            return accepted
        end
    end

    if recursive_hits ~= nil then
        accepted = accept("recursive:app.Character", recursive_hits.character)
        if accepted ~= nil then
            return accepted
        end

        if util.is_valid_obj(recursive_hits.game_object) then
            accepted = accept("recursive:game_object:app.Character", util.safe_get_component(recursive_hits.game_object, "app.Character"))
            if accepted ~= nil then
                return accepted
            end
        end
    end

    state.discovery.main_pawn.character_source = "unresolved"
    state.discovery.main_pawn.candidate_paths = candidate_paths
    return nil
end

local function get_current_node(action_manager, layer_index)
    local fsm = field_first(action_manager, "Fsm")
    if fsm == nil then
        return nil
    end

    local node_name = util.safe_method(fsm, "getCurrentNodeName(System.UInt32)", layer_index)
        or util.safe_method(fsm, "getCurrentNodeName", layer_index)
    if type(node_name) == "string" then
        return node_name
    end

    local text = node_name and call_first(node_name, "ToString") or nil
    return type(text) == "string" and text or nil
end

function main_pawn_properties.update()
    local runtime = state.runtime
    runtime.player = get_player()

    local resolved_main_pawn, recursive_hits = resolve_main_pawn()
    local runtime_character = resolve_runtime_character(resolved_main_pawn, recursive_hits)
    if not util.is_valid_obj(runtime_character) then
        runtime.main_pawn = nil
        runtime.main_pawn_data = nil
        return nil
    end

    local human = call_first(runtime_character, "get_Human")
    local action_manager = call_first(runtime_character, "get_ActionManager")
    local object = util.resolve_game_object(runtime_character, false)

    local data = {
        pawn = util.is_valid_obj(resolved_main_pawn) and resolved_main_pawn or nil,
        runtime_character = runtime_character,
        object = object,
        human = human,
        action_manager = action_manager,
        motion = call_first(runtime_character, "get_Motion"),
        stamina_manager = call_first(runtime_character, "get_StaminaManager"),
        status_condition_ctrl = call_first(runtime_character, "get_StatusConditionCtrl"),
        name = object and call_first(object, "get_Name") or nil,
        chara_id = call_first(runtime_character, "get_CharaID"),
        job = field_first(runtime_character, "Job"),
        weapon_job = field_first(runtime_character, "WeaponJob"),
        job_context = human and field_first(human, "<JobContext>k__BackingField") or nil,
        skill_context = human and field_first(human, "<SkillContext>k__BackingField") or nil,
        ability_context = human and field_first(human, "<AbilityContext>k__BackingField") or nil,
        skill_state = human and field_first(human, "<CustomSkillState>k__BackingField") or nil,
        full_node = get_current_node(action_manager, 0),
        upper_node = get_current_node(action_manager, 1),
    }

    data.current_job = data.job_context and field_first(data.job_context, "CurrentJob") or data.job

    runtime.main_pawn = data.pawn or data.runtime_character
    runtime.main_pawn_data = data
    return data
end

return main_pawn_properties

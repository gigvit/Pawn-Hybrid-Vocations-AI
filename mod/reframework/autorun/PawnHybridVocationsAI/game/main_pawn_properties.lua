local state = require("PawnHybridVocationsAI/state")
local util = require("PawnHybridVocationsAI/core/util")

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

local function get_character_manager()
    return util.safe_singleton("managed", "app.CharacterManager")
end

local function get_pawn_manager()
    return util.safe_singleton("managed", "app.PawnManager")
end

local function get_player()
    local character_manager = get_character_manager()
    if character_manager == nil then
        return nil
    end

    return field_first(character_manager, "<ManualPlayer>k__BackingField")
        or field_first(character_manager, "_ManualPlayer")
        or call_first(character_manager, "get_ManualPlayer")
end

local function resolve_main_pawn()
    for _, spec in ipairs(main_pawn_candidates) do
        local manager = spec.manager == "PawnManager" and get_pawn_manager() or get_character_manager()
        if manager ~= nil then
            local candidate = spec.kind == "field" and field_first(manager, spec.key) or call_first(manager, spec.key)
            if util.is_valid_obj(candidate) then
                return candidate
            end
        end
    end

    return nil
end

local function resolve_runtime_character(pawn)
    for _, spec in ipairs(character_candidates) do
        local candidate = nil
        if spec.kind == "identity" then
            candidate = pawn
        elseif spec.kind == "field" then
            candidate = field_first(pawn, spec.key)
        else
            candidate = call_first(pawn, spec.key)
        end

        if util.is_valid_obj(candidate) and util.is_a(candidate, "app.Character") then
            return candidate
        end
    end

    local game_object = util.resolve_game_object(pawn, true)
    if util.is_valid_obj(game_object) then
        local character = util.safe_get_component(game_object, "app.Character")
        if util.is_valid_obj(character) and util.is_a(character, "app.Character") then
            return character
        end
    end

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

    local resolved_main_pawn = resolve_main_pawn()
    local runtime_character = resolve_runtime_character(resolved_main_pawn)
    if not util.is_valid_obj(runtime_character) then
        runtime.main_pawn = nil
        runtime.main_pawn_data = nil
        return nil
    end

    local human = call_first(runtime_character, "get_Human")
    local action_manager = call_first(runtime_character, "get_ActionManager")
    local object = util.resolve_game_object(runtime_character, true)

    local data = {
        pawn = util.is_valid_obj(resolved_main_pawn) and resolved_main_pawn or nil,
        runtime_character = runtime_character,
        object = object,
        human = human,
        action_manager = action_manager,
        lock_on_ctrl = call_first(runtime_character, "get_LockOnCtrl"),
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

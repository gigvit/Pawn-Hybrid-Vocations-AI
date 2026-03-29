local config = require("PawnHybridVocationsAI/config")
local state = require("PawnHybridVocationsAI/state")
local util = require("PawnHybridVocationsAI/core/util")
local readers = require("PawnHybridVocationsAI/core/readers")

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

local call_first = readers.call_first
local field_first = readers.field_first

local function present_field(obj, field_names)
    for _, field_name in ipairs(field_names or {}) do
        local value = field_first(obj, field_name)
        if value ~= nil then
            return value
        end
    end

    return nil
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

local function context_grace_seconds()
    local hybrid_fix = config.hybrid_combat_fix or {}
    return tonumber(hybrid_fix.context_grace_seconds) or 0.75
end

local function clone_main_pawn_data(data)
    if type(data) ~= "table" then
        return nil
    end

    local clone = {}
    for key, value in pairs(data) do
        clone[key] = value
    end
    return clone
end

local function cache_stable_main_pawn_data(runtime, data)
    runtime.main_pawn_data_stable = clone_main_pawn_data(data)
    runtime.main_pawn_data_stable_time = runtime.game_time or os.clock()
end

local function clear_runtime_resolution(runtime, reason)
    runtime.main_pawn_data_resolution_source = "unresolved"
    runtime.main_pawn_data_resolution_reason = tostring(reason or "unresolved")
    runtime.main_pawn_data_resolution_age = nil
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

local function resolve_job_context(human)
    if not util.is_valid_obj(human) then
        return nil
    end

    return present_field(human, {
        "<JobContext>k__BackingField",
        "JobContext",
    }) or call_first(human, "get_JobContext")
end

local function resolve_current_job(human, runtime_character, raw_job, job_context)
    local current_job = present_field(human, {
        "<CurrentJob>k__BackingField",
        "CurrentJob",
    }) or call_first(human, "get_CurrentJob")

    if current_job ~= nil then
        return current_job
    end

    if util.is_valid_obj(job_context) then
        current_job = field_first(job_context, "CurrentJob")
            or call_first(job_context, "get_CurrentJob")
        if current_job ~= nil then
            return current_job
        end
    end

    return raw_job
        or call_first(runtime_character, "get_CurrentJob")
        or call_first(runtime_character, "get_Job")
        or field_first(runtime_character, "Job")
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
        clear_runtime_resolution(runtime, "runtime_character_unresolved")
        return nil
    end

    local human = call_first(runtime_character, "get_Human")
        or field_first(runtime_character, "<Human>k__BackingField")
        or field_first(runtime_character, "Human")
    local action_manager = call_first(runtime_character, "get_ActionManager")
        or field_first(runtime_character, "<ActionManager>k__BackingField")
        or field_first(runtime_character, "ActionManager")
    local object = util.resolve_game_object(runtime_character, false)
    local raw_job = field_first(runtime_character, "Job")
        or call_first(runtime_character, "get_Job")
    local job_context = resolve_job_context(human)

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
        job = raw_job,
        weapon_job = field_first(runtime_character, "WeaponJob"),
        job_context = job_context,
        skill_context = human and present_field(human, {
            "<SkillContext>k__BackingField",
            "SkillContext",
        }) or nil,
        ability_context = human and present_field(human, {
            "<AbilityContext>k__BackingField",
            "AbilityContext",
        }) or nil,
        skill_state = human and present_field(human, {
            "<CustomSkillState>k__BackingField",
            "CustomSkillState",
        }) or nil,
        full_node = get_current_node(action_manager, 0),
        upper_node = get_current_node(action_manager, 1),
    }

    data.current_job = resolve_current_job(human, runtime_character, raw_job, job_context)

    runtime.main_pawn = data.pawn or data.runtime_character
    runtime.main_pawn_data = data
    cache_stable_main_pawn_data(runtime, data)
    runtime.main_pawn_data_resolution_source = "runtime_main_pawn_data"
    runtime.main_pawn_data_resolution_reason = "resolved"
    runtime.main_pawn_data_resolution_age = 0.0
    return data
end

function main_pawn_properties.get_resolved_main_pawn_data(runtime, fallback_reason)
    runtime = runtime or state.runtime
    if type(runtime) ~= "table" then
        return nil, "runtime_unresolved", nil
    end

    local current = runtime.main_pawn_data
    if type(current) == "table" and util.is_valid_obj(current.runtime_character) then
        runtime.main_pawn_data_resolution_source = "runtime_main_pawn_data"
        runtime.main_pawn_data_resolution_reason = "resolved"
        runtime.main_pawn_data_resolution_age = 0.0

        local resolved = clone_main_pawn_data(current)
        resolved.context_resolution_source = "runtime_main_pawn_data"
        resolved.context_resolution_reason = "resolved"
        resolved.context_resolution_age = 0.0
        return resolved, "runtime_main_pawn_data", 0.0
    end

    local stable = runtime.main_pawn_data_stable
    local stable_time = tonumber(runtime.main_pawn_data_stable_time)
    local ttl = context_grace_seconds()
    if type(stable) ~= "table" or stable_time == nil or ttl <= 0 then
        clear_runtime_resolution(runtime, fallback_reason or "main_pawn_data_unresolved")
        return nil, "main_pawn_data_unresolved", nil
    end

    local now = tonumber(runtime.game_time or os.clock()) or 0.0
    local age = math.max(0.0, now - stable_time)
    if age > ttl or not util.is_valid_obj(stable.runtime_character) then
        runtime.main_pawn_data_stable = nil
        runtime.main_pawn_data_stable_time = nil
        clear_runtime_resolution(runtime, age > ttl and "stable_main_pawn_data_expired" or "stable_main_pawn_data_invalid")
        return nil, "main_pawn_data_unresolved", nil
    end

    runtime.main_pawn_data_resolution_source = "stable_main_pawn_data"
    runtime.main_pawn_data_resolution_reason = tostring(fallback_reason or "main_pawn_data_unresolved")
    runtime.main_pawn_data_resolution_age = age

    local resolved = clone_main_pawn_data(stable)
    resolved.context_resolution_source = "stable_main_pawn_data"
    resolved.context_resolution_reason = tostring(fallback_reason or "main_pawn_data_unresolved")
    resolved.context_resolution_age = age
    return resolved, "stable_main_pawn_data", age
end

return main_pawn_properties

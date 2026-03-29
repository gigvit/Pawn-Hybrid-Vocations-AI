local config = require("PawnHybridVocationsAI/config")
local state = require("PawnHybridVocationsAI/state")
local log = require("PawnHybridVocationsAI/core/log")
local util = require("PawnHybridVocationsAI/core/util")
local readers = require("PawnHybridVocationsAI/core/readers")
local runtime_surfaces = require("PawnHybridVocationsAI/core/runtime_surfaces")
local execution_contracts = require("PawnHybridVocationsAI/core/execution_contracts")
local hybrid_jobs = require("PawnHybridVocationsAI/data/hybrid_jobs")
local hybrid_combat_profiles = require("PawnHybridVocationsAI/data/hybrid_combat_profiles")
local main_pawn_properties = require("PawnHybridVocationsAI/game/main_pawn_properties")

local hybrid_combat_fix = {}

local ACTINTER_EXECUTE_SIGNATURE = "setBBValuesToExecuteActInter(app.AIBlackBoardController, app.ActInterPackData, app.AITarget)"
local ACTINTER_REQMAIN_SIGNATURE = "set_ReqMainActInterPackData(app.ActInterPackData)"
local REQUEST_SKIP_THINK_SIGNATURE = "requestSkipThink()"

local EQUIPPED_SKILLS_FIELDS = {
    "EquipedSkills",
    "<EquipedSkills>k__BackingField",
    "_EquipedSkills",
}

local SKILLS_LIST_FIELDS = {
    "Skills",
    "<Skills>k__BackingField",
    "_Skills",
}

local UTILITY_TOKENS = {
    "/common/",
    "/ch1/",
    "movetoposition",
    "moveapproach",
    "keepdistance",
    "strafe",
    "locomotion.",
    "normallocomotion",
    "dodge",
    "drawweapon",
}

local DAMAGE_RECOVERY_TOKENS = {
    "dmgshrink",
    "damage.damage_root.dmgshrink",
}

local SPECIAL_SKIP_TOKENS = {
    "talk",
    "greeting",
    "highfive",
    "chilling",
    "perform_chilling",
    "lookat",
    "sortitem",
    "treasurebox",
    "carry",
    "cling",
    "catch",
    "winbattle",
}

local SPECIAL_RECOVERY_TOKENS = {
    "humanturn_target_talking",
}

local SUPPORT_RECOVERY_TOKENS = {
    "movetoposition",
    "moveapproach",
    "keepdistance",
    "healingspot",
    "moveintohealingspot",
    "anodyne",
    "curespot",
    "boon",
    "enchant",
}

local TARGET_FIELD_NAMES = {
    "<Target>k__BackingField",
    "_Target",
    "Target",
    "CurrentTarget",
    "AttackTarget",
    "LockOnTarget",
    "OrderTarget",
}

local TARGET_METHOD_NAMES = {
    "get_Target",
    "get_CurrentTarget",
    "get_AttackTarget",
    "get_LockOnTarget",
    "get_OrderTarget",
}

local ORDER_TARGET_CONTROLLER_FIELDS = {
    "<OrderTargetController>k__BackingField",
    "_OrderTargetController",
    "OrderTargetController",
}

local BATTLE_CONTROLLER_FIELDS = {
    "<BattleController>k__BackingField",
    "_BattleController",
    "BattleController",
}

local ORDER_CONTROLLER_FIELDS = {
    "<OrderController>k__BackingField",
    "_OrderController",
    "OrderController",
}

local UPDATE_CONTROLLER_FIELDS = {
    "<UpdateController>k__BackingField",
    "_UpdateController",
    "UpdateController",
}

local BLACKBOARD_CONTROLLER_FIELDS = {
    "<AIBlackBoardController>k__BackingField",
    "AIBlackBoardController",
    "<BlackBoardController>k__BackingField",
    "BlackBoardController",
}

local AIMETA_CONTROLLER_FIELDS = {
    "<AIMetaController>k__BackingField",
    "AIMetaController",
}

local CACHED_PAWN_BATTLE_CONTROLLER_FIELDS = {
    "<CachedPawnBattleController>k__BackingField",
    "CachedPawnBattleController",
}

local CACHED_PAWN_ORDER_CONTROLLER_FIELDS = {
    "<CachedPawnOrderController>k__BackingField",
    "CachedPawnOrderController",
}

local CACHED_PAWN_ORDER_TARGET_CONTROLLER_FIELDS = {
    "<CachedPawnOrderTargetController>k__BackingField",
    "CachedPawnOrderTargetController",
}

local CACHED_PAWN_UPDATE_CONTROLLER_FIELDS = {
    "<CachedPawnUpdateController>k__BackingField",
    "CachedPawnUpdateController",
}

local HUMAN_SELECTOR_FIELDS = {
    "<HumanActionSelector>k__BackingField",
    "HumanActionSelector",
}

local COMMON_SELECTOR_FIELDS = {
    "<CommonActionSelector>k__BackingField",
    "CommonActionSelector",
}

local TARGET_CHARACTER_FIELD_NAMES = {
    "<Character>k__BackingField",
    "<OwnerCharacter>k__BackingField",
    "<TargetCharacter>k__BackingField",
    "<CachedCharacter>k__BackingField",
    "Character",
    "OwnerCharacter",
    "TargetCharacter",
    "CachedCharacter",
    "TargetChara",
    "Chara",
}

local TARGET_CHARACTER_METHOD_NAMES = {
    "get_Character",
    "get_OwnerCharacter",
    "get_TargetCharacter",
    "get_Chara",
}

local ORDER_TARGET_COLLECTION_FIELDS = {
    "_EnemyList",
    "_FrontTargetList",
    "_InCameraTargetList",
    "_SensorHitResult",
}

local function fix_config()
    return config.hybrid_combat_fix or {}
end

local function unsafe_skill_probe_mode()
    local mode = string.lower(tostring(fix_config().unsafe_skill_probe_mode or "off"))
    if mode == "action_only" or mode == "carrier_only" or mode == "carrier_then_action" then
        return mode
    end

    return "off"
end

local function synthetic_stall_window_seconds()
    return tonumber(fix_config().synthetic_stall_window_seconds) or 0.75
end

local function synthetic_initiator_window_seconds()
    return tonumber(fix_config().synthetic_initiator_window_seconds) or 0.0
end

local function synthetic_native_output_backoff_seconds()
    return tonumber(fix_config().synthetic_native_output_backoff_seconds) or 1.25
end

local function synthetic_support_recovery_hp_ratio()
    return tonumber(fix_config().synthetic_support_recovery_hp_ratio) or 0.70
end

local function context_grace_seconds()
    return tonumber(fix_config().context_grace_seconds) or 0.75
end

local function phase_failure_quarantine_seconds()
    return tonumber(fix_config().phase_failure_quarantine_seconds) or 1.5
end

local function crash_prone_skill_phases_enabled()
    return fix_config().enable_crash_prone_skill_phases == true
end

local function skip_logging_enabled()
    return (tonumber(fix_config().skip_log_interval_seconds) or 0.0) > 0.0
end

local function target_probe_logging_enabled()
    return (tonumber(fix_config().target_source_log_interval_seconds) or 0.0) > 0.0
end

local get_job_action_ctrl
local compute_distance
local is_invalid_target_identity

local call_first = readers.call_first
local field_first = readers.field_first
local present_field = runtime_surfaces.present_field
local present_method = runtime_surfaces.present_method
local resolve_pack_like_identity = runtime_surfaces.resolve_pack_like_identity
local get_current_node = runtime_surfaces.get_current_node
local resolve_decision_pack_path = runtime_surfaces.resolve_decision_pack_path
local read_collection_count_quick = runtime_surfaces.read_collection_count
local read_collection_item_quick = runtime_surfaces.read_collection_item

local function is_present_value(value)
    if value == nil then
        return false
    end
    if type(value) == "userdata" then
        return util.is_valid_obj(value)
    end

    return tostring(value) ~= "nil"
end

local function is_queryable_obj(value)
    if value == nil then
        return false
    end
    if type(value) ~= "userdata" then
        return tostring(value) ~= "nil"
    end

    return tostring(value) ~= "nil"
end

local function is_character_obj(value)
    if not is_queryable_obj(value) then
        return false
    end

    local type_name = util.get_type_full_name(value)
    return type_name == "app.Character" or util.is_a(value, "app.Character")
end

local function resolve_target_like_root(root)
    if not is_queryable_obj(root) then
        return nil, "root_nil"
    end

    local type_name = util.get_type_full_name(root)
    if (type_name ~= nil and string.find(type_name, "app.AITarget", 1, true) == 1)
        or type_name == "app.Character"
        or type_name == "via.GameObject" then
        return root, "root_direct"
    end

    for _, field_name in ipairs(TARGET_FIELD_NAMES) do
        local target = field_first(root, field_name)
        if is_queryable_obj(target) then
            return target, "field_target"
        end
    end

    for _, method_name in ipairs(TARGET_METHOD_NAMES) do
        local target = call_first(root, method_name)
        if is_queryable_obj(target) then
            return target, "method_target"
        end
    end

    return nil, "target_unresolved"
end

local function type_name_starts_with(obj, prefix)
    local type_name = util.get_type_full_name(obj)
    return type(type_name) == "string"
        and type(prefix) == "string"
        and string.find(type_name, prefix, 1, true) == 1
end

local function is_order_target_controller_obj(obj)
    return util.get_type_full_name(obj) == "app.PawnOrderTargetController"
end

local function is_vision_marker_obj(obj)
    return util.get_type_full_name(obj) == "app.VisionMarker"
end

local function is_hit_result_data_obj(obj)
    return util.get_type_full_name(obj) == "app.PawnOrderTargetController.HitResultData"
end

local function resolve_target_game_object(target, allow_method_call)
    if not is_queryable_obj(target) then
        return nil
    end

    local type_name = util.get_type_full_name(target)
    if type_name == "via.GameObject" then
        return target
    end

    local game_object = util.resolve_game_object(target, false)
    if util.is_valid_obj(game_object) then
        return game_object
    end

    if allow_method_call == true and not is_character_obj(target) then
        game_object = util.resolve_game_object(target, true)
        if util.is_valid_obj(game_object) then
            return game_object
        end
    end

    return nil
end

local function to_string_or_nil(value)
    if value == nil then
        return nil
    end

    local value_type = type(value)
    if value_type == "string" or value_type == "number" or value_type == "boolean" then
        return tostring(value)
    end

    return nil
end

local function describe_value(value)
    if value == nil then
        return "nil"
    end

    local text = to_string_or_nil(value)
    if text ~= nil then
        return text
    end

    if type(value) == "userdata" then
        return util.describe_obj(value)
    end

    return tostring(value)
end

local function decode_small_int(value)
    if type(value) == "number" then
        return value
    end

    local direct = tonumber(value)
    if direct ~= nil then
        return direct
    end

    local text = tostring(value or "")
    local hex_value = text:match("userdata:%s*(%x+)")
    if hex_value == nil then
        return nil
    end

    local parsed = tonumber(hex_value, 16)
    if parsed == nil or parsed < 0 or parsed > 4096 then
        return nil
    end

    return parsed
end

local function clamp_ratio(value)
    local numeric = tonumber(value)
    if numeric == nil then
        return nil
    end
    if numeric > 1.0 and numeric <= 100.0 then
        numeric = numeric / 100.0
    end
    if numeric < 0.0 then
        return 0.0
    end
    if numeric > 1.0 then
        return 1.0
    end
    return numeric
end

local function resolve_actor_hp_ratio(runtime_character)
    if not util.is_valid_obj(runtime_character) then
        return nil, "runtime_character_unresolved"
    end

    local original_ratio = clamp_ratio(call_first(runtime_character, "get_OriginalHpRatio"))
    if original_ratio ~= nil then
        return original_ratio, "get_OriginalHpRatio"
    end

    local current_hp = tonumber(call_first(runtime_character, "get_Hp"))
    local max_hp = tonumber(call_first(runtime_character, "get_OriginalMaxHp"))
    local hit = field_first(runtime_character, "<Hit>k__BackingField")
        or field_first(runtime_character, "Hit")
        or call_first(runtime_character, "get_Hit")

    if current_hp == nil and util.is_valid_obj(hit) then
        current_hp = tonumber(call_first(hit, "get_Hp"))
    end
    if max_hp == nil and util.is_valid_obj(hit) then
        max_hp = tonumber(call_first(hit, "get_ReducedMaxHp"))
            or tonumber(call_first(hit, "get_OriginalMaxHp"))
    end

    if current_hp ~= nil and max_hp ~= nil and max_hp > 0.0 then
        return clamp_ratio(current_hp / max_hp), "hp_over_max_hp"
    end

    return nil, "hp_ratio_unresolved"
end

local function decode_truthy(value)
    if type(value) == "boolean" then
        return value
    end

    local numeric = decode_small_int(value)
    if numeric ~= nil then
        return numeric ~= 0
    end

    local text = tostring(value or "")
    if text == "true" then
        return true
    end
    if text == "false" then
        return false
    end

    return nil
end

local function lower_text(value)
    if value == nil then
        return nil
    end

    return string.lower(tostring(value))
end

local function contains_text(value, needle)
    local haystack = lower_text(value)
    local pattern = lower_text(needle)
    if haystack == nil or pattern == nil then
        return false
    end

    return string.find(haystack, pattern, 1, true) ~= nil
end

local function contains_any_text(value, needles)
    for _, needle in ipairs(needles or {}) do
        if contains_text(value, needle) then
            return true
        end
    end

    return false
end

local extract_target_character
local build_target_info
local resolve_phase_selection_role
local resolve_phase_synthetic_bucket

local function resolve_decision_target(executing_decision, runtime_character, player, allow_method_call)
    if not is_queryable_obj(executing_decision) then
        return nil, "executing_decision_unresolved"
    end

    local ai_target = select(1, resolve_target_like_root(executing_decision))
    if not is_queryable_obj(ai_target) then
        return nil, "decision_target_missing"
    end

    local target, character_reason = extract_target_character(ai_target, runtime_character, player, allow_method_call)
    if not util.is_valid_obj(target) then
        return nil, "decision_" .. tostring(character_reason or "target_character_unresolved")
    end

    local target_info = build_target_info(target, "executing_decision_target", ai_target, allow_method_call)
    if target_info == nil then
        return nil, "decision_target_info_unresolved"
    end

    return target_info, "executing_decision_target"
end

local function resolve_decision_target_type(executing_decision)
    if not is_queryable_obj(executing_decision) then
        return nil, "executing_decision_unresolved"
    end

    local target_like, target_source = resolve_target_like_root(executing_decision)
    if not is_queryable_obj(target_like) then
        return nil, target_source or "decision_target_unresolved"
    end

    return util.get_type_full_name(target_like) or "nil", target_source
end

local function append_unique_character(out, candidate)
    if not is_character_obj(candidate) then
        return
    end

    for _, existing in ipairs(out) do
        if util.same_object(existing, candidate) then
            return
        end
    end

    out[#out + 1] = candidate
end

local function append_character_from_container(out, source)
    if not util.is_valid_obj(source) then
        return
    end

    append_unique_character(out, util.safe_get_component(source, "app.Character", false))

    local human_component = util.safe_get_component(source, "app.Human", false)
    if util.is_valid_obj(human_component) then
        append_unique_character(out, field_first(human_component, "<Character>k__BackingField"))
        append_unique_character(out, field_first(human_component, "Character"))
        append_unique_character(out, field_first(human_component, "<Chara>k__BackingField"))
        append_unique_character(out, field_first(human_component, "Chara"))
        append_unique_character(out, call_first(human_component, "get_Character"))
        append_unique_character(out, call_first(human_component, "get_Chara"))
    end
end

local function append_owner_chain_characters(out, source)
    if not util.is_valid_obj(source) then
        return
    end

    local owner = field_first(source, "<Owner>k__BackingField")
        or field_first(source, "Owner")
        or field_first(source, "<OwnerObject>k__BackingField")
        or field_first(source, "OwnerObject")
        or call_first(source, "get_Owner")
        or call_first(source, "get_OwnerObject")
    if not util.is_valid_obj(owner) or util.same_object(owner, source) then
        return
    end

    append_unique_character(out, owner)
    for _, field_name in ipairs(TARGET_CHARACTER_FIELD_NAMES) do
        append_unique_character(out, field_first(owner, field_name))
    end
    for _, method_name in ipairs(TARGET_CHARACTER_METHOD_NAMES) do
        append_unique_character(out, call_first(owner, method_name))
    end

    append_character_from_container(out, owner)

    local owner_game_object = resolve_target_game_object(owner, false)
    if util.is_valid_obj(owner_game_object) and not util.same_object(owner_game_object, source) then
        append_character_from_container(out, owner_game_object)
    end
end

extract_target_character = function(target, runtime_character, player, allow_method_call)
    if not is_queryable_obj(target) then
        return nil, "target_unresolved"
    end

    local candidates = {}

    append_unique_character(candidates, is_character_obj(target) and target or nil)

    for _, field_name in ipairs(TARGET_CHARACTER_FIELD_NAMES) do
        append_unique_character(candidates, field_first(target, field_name))
    end

    for _, method_name in ipairs(TARGET_CHARACTER_METHOD_NAMES) do
        append_unique_character(candidates, call_first(target, method_name))
    end

    local direct_game_object = resolve_target_game_object(target, false)
    append_character_from_container(candidates, direct_game_object)
    append_owner_chain_characters(candidates, direct_game_object)

    local has_valid_enemy_candidate = false
    for _, candidate in ipairs(candidates) do
        if not is_invalid_target_identity(runtime_character, candidate, player) then
            has_valid_enemy_candidate = true
            break
        end
    end

    if not has_valid_enemy_candidate and allow_method_call == true then
        local method_game_object = resolve_target_game_object(target, true)
        if util.is_valid_obj(method_game_object) and not util.same_object(method_game_object, direct_game_object) then
            append_character_from_container(candidates, method_game_object)
            append_owner_chain_characters(candidates, method_game_object)
        end
    end

    if #candidates == 0 then
        return nil, "target_character_unresolved"
    end

    for index, candidate in ipairs(candidates) do
        if not is_invalid_target_identity(runtime_character, candidate, player) then
            if index == 1 and util.same_object(candidate, target) then
                return candidate, "target_character_direct"
            end
            return candidate, index == 1 and "target_character_nested" or "target_character_alternative"
        end
    end

    if util.same_object(candidates[1], runtime_character) then
        return candidates[1], "target_character_self_only"
    end
    if util.same_object(candidates[1], player) then
        return candidates[1], "target_character_player_only"
    end

    return candidates[1], "target_character_only_candidate"
end

local function extract_vision_marker_character(marker, runtime_character, player, allow_method_call)
    if not is_queryable_obj(marker) then
        return nil, "vision_marker_unresolved", marker
    end

    local candidates = {
        field_first(marker, "<CachedCharacter>k__BackingField"),
        field_first(marker, "CachedCharacter"),
        field_first(marker, "<Character>k__BackingField"),
        field_first(marker, "Character"),
        call_first(marker, "get_CachedCharacter"),
        call_first(marker, "get_Character"),
    }

    for _, candidate in ipairs(candidates) do
        if util.is_valid_obj(candidate)
            and is_character_obj(candidate)
            and not is_invalid_target_identity(runtime_character, candidate, player) then
            return candidate, "vision_marker_cached_character", marker
        end
    end

    local owner_object = field_first(marker, "CachedOwnerObj")
        or field_first(marker, "<CachedOwnerObj>k__BackingField")
        or field_first(marker, "OwnerObject")
        or field_first(marker, "<OwnerObject>k__BackingField")
        or call_first(marker, "get_CachedOwnerObj")
        or call_first(marker, "get_OwnerObject")
    if util.is_valid_obj(owner_object) then
        local owner_character, owner_reason = extract_target_character(
            owner_object,
            runtime_character,
            player,
            allow_method_call
        )
        if util.is_valid_obj(owner_character)
            and not is_invalid_target_identity(runtime_character, owner_character, player) then
            return owner_character, "vision_marker_" .. tostring(owner_reason or "owner_character"), owner_object
        end
    end

    return nil, "vision_marker_character_unresolved", marker
end

local function extract_hit_result_character(hit_result, runtime_character, player, allow_method_call)
    if not is_queryable_obj(hit_result) then
        return nil, "hit_result_unresolved", hit_result
    end

    local obj = field_first(hit_result, "Obj")
        or field_first(hit_result, "<Obj>k__BackingField")
        or field_first(hit_result, "GameObject")
        or call_first(hit_result, "get_Obj")
    if util.is_valid_obj(obj) then
        local character, character_reason = extract_target_character(
            obj,
            runtime_character,
            player,
            allow_method_call
        )
        if util.is_valid_obj(character)
            and not is_invalid_target_identity(runtime_character, character, player) then
            return character, "hit_result_" .. tostring(character_reason or "obj_character"), obj
        end
    end

    return nil, "hit_result_character_unresolved", hit_result
end

build_target_info = function(character, source_label, ai_target_like, allow_method_call)
    if not util.is_valid_obj(character) then
        return nil, tostring(source_label or "target_character_unresolved")
    end

    local game_object = resolve_target_game_object(ai_target_like, false)
        or resolve_target_game_object(character, false)
    if not util.is_valid_obj(game_object) and allow_method_call == true then
        game_object = resolve_target_game_object(ai_target_like, true)
    end
    local transform = field_first(ai_target_like, "<Transform>k__BackingField")
        or field_first(ai_target_like, "Transform")
        or call_first(ai_target_like, "get_Transform")
        or call_first(character, "get_Transform")
    local context_holder = field_first(ai_target_like, "<ContextHolder>k__BackingField")
        or field_first(ai_target_like, "ContextHolder")
        or call_first(ai_target_like, "get_ContextHolder")
        or field_first(character, "<Context>k__BackingField")
        or field_first(character, "Context")
        or call_first(character, "get_Context")

    return {
        ai_target = ai_target_like,
        character = character,
        game_object = game_object,
        transform = transform,
        context_holder = context_holder,
    }, tostring(source_label or "target_info")
end

local function clone_target_info(target_info)
    if type(target_info) ~= "table" then
        return nil
    end

    return {
        ai_target = target_info.ai_target,
        character = target_info.character,
        game_object = target_info.game_object,
        transform = target_info.transform,
        context_holder = target_info.context_holder,
    }
end

local function hydrate_target_info(target_info, allow_method_call)
    local info = clone_target_info(target_info)
    if type(info) ~= "table" or not util.is_valid_obj(info.character) then
        return nil
    end

    if not util.is_valid_obj(info.game_object) then
        info.game_object = resolve_target_game_object(info.ai_target, false)
            or resolve_target_game_object(info.character, false)
    end
    if not util.is_valid_obj(info.game_object) and allow_method_call == true then
        info.game_object = resolve_target_game_object(info.ai_target, true)
    end

    if not util.is_valid_obj(info.transform) then
        info.transform = field_first(info.ai_target, "<Transform>k__BackingField")
            or field_first(info.ai_target, "Transform")
            or call_first(info.ai_target, "get_Transform")
            or call_first(info.character, "get_Transform")
    end

    if not util.is_valid_obj(info.context_holder) then
        info.context_holder = field_first(info.ai_target, "<ContextHolder>k__BackingField")
            or field_first(info.ai_target, "ContextHolder")
            or call_first(info.ai_target, "get_ContextHolder")
            or field_first(info.character, "<Context>k__BackingField")
            or field_first(info.character, "Context")
            or call_first(info.character, "get_Context")
    end

    return info
end

local function resolve_collection_item_character(item, runtime_character, player, allow_method_call)
    if is_vision_marker_obj(item) then
        return extract_vision_marker_character(item, runtime_character, player, allow_method_call)
    end

    if is_hit_result_data_obj(item) then
        return extract_hit_result_character(item, runtime_character, player, allow_method_call)
    end

    local target_like = select(1, resolve_target_like_root(item))
    local probe_target = is_queryable_obj(target_like) and target_like or item

    local character, character_reason = extract_target_character(
        probe_target,
        runtime_character,
        player,
        allow_method_call
    )
    if util.is_valid_obj(character) then
        return character, character_reason, probe_target
    end

    local game_object = resolve_target_game_object(probe_target, allow_method_call)
    if not util.is_valid_obj(game_object) and not util.same_object(probe_target, item) then
        game_object = resolve_target_game_object(item, allow_method_call)
    end
    local component_character = util.safe_get_component(game_object, "app.Character", false)
    if util.is_valid_obj(component_character) then
        if is_invalid_target_identity(runtime_character, component_character, player) then
            return component_character, "collection_item_component_self", probe_target
        end
        return component_character, "collection_item_component_character", probe_target
    end

    return nil, "collection_item_character_unresolved", probe_target
end

local function resolve_order_target_controller_collection_info(root, label, runtime_character, player, allow_method_call)
    local saw_collection = false
    local saw_nonempty_collection = false
    local saw_unresolved_collection_item = false

    for _, field_name in ipairs(ORDER_TARGET_COLLECTION_FIELDS) do
        local collection = field_first(root, field_name)
        if is_queryable_obj(collection) then
            saw_collection = true
        end

        local count = read_collection_count_quick(collection)
        if tonumber(count) ~= nil and tonumber(count) > 0 then
            saw_nonempty_collection = true
        end
        count = count or 0
        local max_items = math.min(count, 6)
        for index = 0, max_items - 1 do
            local item = read_collection_item_quick(collection, index)
            local character, character_reason, probe_target = resolve_collection_item_character(
                item,
                runtime_character,
                player,
                allow_method_call
            )
            if util.is_valid_obj(character)
                and not is_invalid_target_identity(runtime_character, character, player) then
                local info, source = build_target_info(
                    character,
                    string.format("%s:%s#%d", tostring(label or "order_target_controller"), tostring(field_name), index),
                    probe_target or item,
                    allow_method_call
                )
                return info, tostring(source or character_reason or "collection_character")
            end

            if item ~= nil then
                saw_unresolved_collection_item = true
            end
        end
    end

    local reason_prefix = tostring(label or "order_target_controller")
    if not saw_collection then
        return nil, reason_prefix .. "_collections_unresolved"
    end
    if not saw_nonempty_collection then
        return nil, reason_prefix .. "_collections_empty"
    end
    if saw_unresolved_collection_item then
        return nil, reason_prefix .. "_collection_item_unresolved"
    end

    return nil, reason_prefix .. "_collection_target_unresolved"
end

local function resolve_surface_target_info(root, label, runtime_character, player, allow_method_call)
    if not is_queryable_obj(root) then
        return nil, tostring(label or "surface") .. "_unresolved"
    end

    local root_type_name = util.get_type_full_name(root)
    if root_type_name == "app.AIMetaController" then
        local cached_order_target_controller = present_field(root, CACHED_PAWN_ORDER_TARGET_CONTROLLER_FIELDS)
        if is_order_target_controller_obj(cached_order_target_controller) then
            local collection_info, collection_reason = resolve_order_target_controller_collection_info(
                cached_order_target_controller,
                tostring(label or "surface") .. ":cached_pawn_order_target_controller",
                runtime_character,
                player,
                allow_method_call
            )
            if collection_info ~= nil then
                return collection_info, collection_reason
            end

            return nil, tostring(collection_reason or "meta_cached_order_target_unresolved")
        end

        return nil, tostring(label or "surface") .. "_meta_carrier_present_no_target"
    end

    if root_type_name == "app.AIBlackBoardController" then
        local direct_order_target_controller = present_field(root, ORDER_TARGET_CONTROLLER_FIELDS)
        if is_order_target_controller_obj(direct_order_target_controller) then
            local collection_info, collection_reason = resolve_order_target_controller_collection_info(
                direct_order_target_controller,
                tostring(label or "surface") .. ":order_target_controller",
                runtime_character,
                player,
                allow_method_call
            )
            if collection_info ~= nil then
                return collection_info, collection_reason
            end
            return nil, tostring(collection_reason or "blackboard_order_target_unresolved")
        end

        local ai_meta_controller = present_field(root, AIMETA_CONTROLLER_FIELDS)
        if util.is_valid_obj(ai_meta_controller) then
            return resolve_surface_target_info(
                ai_meta_controller,
                tostring(label or "surface") .. ":ai_meta_controller",
                runtime_character,
                player,
                allow_method_call
            )
        end

        return nil, tostring(label or "surface") .. "_meta_carrier_present_no_target"
    end

    if root_type_name == "app.PawnOrderTargetController" then
        local collection_info, collection_reason = resolve_order_target_controller_collection_info(
            root,
            label,
            runtime_character,
            player,
            allow_method_call
        )
        if collection_info ~= nil then
            return collection_info, collection_reason
        end
    end

    local target = select(1, resolve_target_like_root(root))
    if not is_queryable_obj(target) then
        if type_name_starts_with(root, "app.AITarget") then
            return nil, tostring(label or "surface") .. "_target_character_unresolved"
        end
        return nil, tostring(label or "surface") .. "_target_unresolved"
    end

    local character, character_reason = extract_target_character(target, runtime_character, player, allow_method_call)
    if not util.is_valid_obj(character) then
        return nil, tostring(label or "surface") .. "_" .. tostring(character_reason or "character_unresolved")
    end

    return build_target_info(character, label, target, allow_method_call)
end

is_invalid_target_identity = function(runtime_character, target, player)
    return util.same_object(target, runtime_character)
        or util.same_object(target, player)
end

local function push_target_source_candidate(targets, seen, label, root)
    if type(label) ~= "string" or label == "" then
        return
    end

    if util.is_valid_obj(root) then
        for _, existing in ipairs(seen) do
            if util.same_object(existing, root) then
                return
            end
        end
        seen[#seen + 1] = root
    end

    targets[#targets + 1] = {
        label = label,
        root = root,
    }
end

local function classify_target_identity(runtime_character, character, player)
    if not util.is_valid_obj(character) then
        return "none"
    end
    if util.same_object(character, runtime_character) then
        return "self"
    end
    if util.same_object(character, player) then
        return "player"
    end
    return "other"
end

local function build_target_probe(label, root, target_info, reason, runtime_character, player)
    local character = target_info and target_info.character or nil
    local distance = util.is_valid_obj(character) and compute_distance(runtime_character, character) or nil

    return {
        label = tostring(label or "surface"),
        reason = tostring(reason or "unresolved"),
        root = util.describe_obj(root),
        raw_target = util.describe_obj(target_info and target_info.ai_target),
        character = util.describe_obj(character),
        game_object = util.describe_obj(target_info and target_info.game_object),
        identity = classify_target_identity(runtime_character, character, player),
        distance = distance,
    }
end

local function describe_target_probes(probes)
    if type(probes) ~= "table" or #probes == 0 then
        return "none"
    end

    local parts = {}
    for _, probe in ipairs(probes) do
        parts[#parts + 1] = string.format(
            "%s[reason=%s identity=%s dist=%s root=%s raw=%s char=%s go=%s]",
            tostring(probe.label or "surface"),
            tostring(probe.reason or "unresolved"),
            tostring(probe.identity or "none"),
            tostring(probe.distance),
            tostring(probe.root or "nil"),
            tostring(probe.raw_target or "nil"),
            tostring(probe.character or "nil"),
            tostring(probe.game_object or "nil")
        )
    end

    return table.concat(parts, " ; ")
end

local function collect_target_source_candidates(context)
    local candidates = {}
    local seen = {}
    local human = context.main_pawn and context.main_pawn.human or nil
    local ai_blackboard = context.ai_blackboard
    local ai_meta_controller = present_field(ai_blackboard, AIMETA_CONTROLLER_FIELDS)
    local human_action_selector = present_field(human, HUMAN_SELECTOR_FIELDS)
    local common_action_selector = present_field(human, COMMON_SELECTOR_FIELDS)
    local job_action_ctrl = get_job_action_ctrl(context, context.current_job)
    local lock_on_ctrl = context.main_pawn and context.main_pawn.lock_on_ctrl
        or call_first(context.runtime_character, "get_LockOnCtrl")
    local ai_blackboard_battle_controller = present_field(ai_blackboard, BATTLE_CONTROLLER_FIELDS)
    local ai_blackboard_order_controller = present_field(ai_blackboard, ORDER_CONTROLLER_FIELDS)
    local ai_blackboard_order_target_controller = present_field(ai_blackboard, ORDER_TARGET_CONTROLLER_FIELDS)
    local cached_pawn_order_target_controller = present_field(ai_meta_controller, CACHED_PAWN_ORDER_TARGET_CONTROLLER_FIELDS)
    local human_order_target_controller = present_field(human_action_selector, ORDER_TARGET_CONTROLLER_FIELDS)
    local common_order_target_controller = present_field(common_action_selector, ORDER_TARGET_CONTROLLER_FIELDS)
    local job_action_ctrl_ai_blackboard = present_field(job_action_ctrl, BLACKBOARD_CONTROLLER_FIELDS)
    local pawn_manager = util.safe_singleton("managed", "app.PawnManager")
    local pawn_manager_order_target_controller = field_first(pawn_manager, "<PawnOrderTargetController>k__BackingField")
        or field_first(pawn_manager, "PawnOrderTargetController")
        or call_first(pawn_manager, "get_PawnOrderTargetController")

    push_target_source_candidate(candidates, seen, "cached_pawn_order_target_controller", cached_pawn_order_target_controller)
    push_target_source_candidate(candidates, seen, "pawn_manager_order_target_controller", pawn_manager_order_target_controller)
    push_target_source_candidate(candidates, seen, "ai_blackboard_order_target_controller", ai_blackboard_order_target_controller)
    push_target_source_candidate(candidates, seen, "human_action_selector_order_target_controller", human_order_target_controller)
    push_target_source_candidate(candidates, seen, "common_action_selector_order_target_controller", common_order_target_controller)
    push_target_source_candidate(candidates, seen, "ai_blackboard_controller", ai_blackboard)
    push_target_source_candidate(candidates, seen, "ai_meta_controller", ai_meta_controller)
    push_target_source_candidate(candidates, seen, "ai_blackboard_battle_controller", ai_blackboard_battle_controller)
    push_target_source_candidate(candidates, seen, "ai_blackboard_order_controller", ai_blackboard_order_controller)
    push_target_source_candidate(candidates, seen, "job_action_ctrl_ai_blackboard_controller", job_action_ctrl_ai_blackboard)
    push_target_source_candidate(candidates, seen, "lock_on_ctrl", lock_on_ctrl)

    return candidates
end

local function has_usable_enemy_target(target_info, runtime_character, player)
    local character = target_info and target_info.character or nil
    return util.is_valid_obj(character)
        and not is_invalid_target_identity(runtime_character, character, player)
end

local function clear_cached_target(data)
    if type(data) ~= "table" then
        return
    end

    data.cached_target_info = nil
    data.cached_target_reason = "nil"
    data.cached_target_time = nil
end

local function cache_target_info(data, target_info, reason, now)
    if type(data) ~= "table" then
        return
    end

    local hydrated = hydrate_target_info(target_info, false)
    if type(hydrated) ~= "table" then
        return
    end

    data.cached_target_info = hydrated
    data.cached_target_reason = tostring(reason or "cached_target")
    data.cached_target_time = tonumber(now) or os.clock()
end

local function get_cached_target_info(data, context, runtime, now)
    if type(data) ~= "table" or type(data.cached_target_info) ~= "table" then
        return nil, "cached_target_unresolved"
    end

    local cached_time = tonumber(data.cached_target_time)
    local ttl_seconds = tonumber(fix_config().target_cache_ttl_seconds) or 0.85
    if cached_time == nil or tonumber(now) == nil or (now - cached_time) > ttl_seconds then
        clear_cached_target(data)
        return nil, "cached_target_expired"
    end

    local hydrated = hydrate_target_info(data.cached_target_info, false)
    if not has_usable_enemy_target(hydrated, context.runtime_character, runtime and runtime.player) then
        clear_cached_target(data)
        return nil, "cached_target_invalid"
    end

    data.cached_target_info = hydrated
    return hydrated, tostring(data.cached_target_reason or "cached_target")
end

local function prepare_target_info_for_bridge(data, context, runtime, target_info, now)
    local prepared = hydrate_target_info(target_info, false)
    if type(prepared) ~= "table" then
        return nil, "target_unresolved"
    end

    if util.is_valid_obj(prepared.game_object) then
        cache_target_info(data, prepared, "prepared_target_direct", now)
        return prepared, "prepared_target_direct"
    end

    if type(data) == "table" and type(data.cached_target_info) == "table" then
        local cached = hydrate_target_info(data.cached_target_info, false)
        if type(cached) == "table"
            and util.same_object(cached.character, prepared.character)
            and util.is_valid_obj(cached.game_object) then
            prepared.game_object = cached.game_object
            prepared.transform = prepared.transform or cached.transform
            prepared.context_holder = prepared.context_holder or cached.context_holder
            return prepared, "prepared_target_cached_game_object"
        end
    end

    prepared = hydrate_target_info(prepared, true)
    if util.is_valid_obj(prepared.game_object) then
        cache_target_info(data, prepared, "prepared_target_method_fallback", now)
        return prepared, "prepared_target_method_fallback"
    end

    return prepared, "target_game_object_unresolved"
end

local function should_run_secondary_target_scan(data, now)
    local interval = tonumber(fix_config().secondary_target_scan_interval_seconds) or 0.35
    if type(data) ~= "table" then
        return true
    end

    if data.last_secondary_target_scan_time == nil then
        return true
    end

    return (tonumber(now) or 0.0) - tonumber(data.last_secondary_target_scan_time) >= interval
end

local function resolve_combat_target(context, runtime, data, now, collect_probes)
    local probes = collect_probes and {} or nil
    local target_info, target_reason = resolve_decision_target(
        context.executing_decision,
        context.runtime_character,
        runtime and runtime.player,
        false
    )
    local target = target_info and target_info.character or nil
    if probes ~= nil then
        probes[#probes + 1] = build_target_probe(
            "executing_decision_target",
            context.executing_decision,
            target_info,
            target_reason,
            context.runtime_character,
            runtime and runtime.player
        )
    end
    if has_usable_enemy_target(target_info, context.runtime_character, runtime and runtime.player) then
        cache_target_info(data, target_info, target_reason, now)
        return target_info, target_reason, probes
    end

    local cached_target_info, cached_target_reason = get_cached_target_info(data, context, runtime, now)
    if probes ~= nil then
        probes[#probes + 1] = build_target_probe(
            "cached_target",
            cached_target_info and (cached_target_info.ai_target or cached_target_info.character) or nil,
            cached_target_info,
            cached_target_reason,
            context.runtime_character,
            runtime and runtime.player
        )
    end
    if cached_target_info ~= nil then
        return cached_target_info, "cached_target", probes
    end

    if not should_run_secondary_target_scan(data, now) then
        if util.is_valid_obj(target) and is_invalid_target_identity(context.runtime_character, target, runtime and runtime.player) then
            return target_info, "invalid_target_identity", probes
        end

        return target_info, target_reason, probes
    end

    data.last_secondary_target_scan_time = tonumber(now) or 0.0

    for _, candidate in ipairs(collect_target_source_candidates(context)) do
        local fallback_info, fallback_reason = resolve_surface_target_info(
            candidate.root,
            candidate.label,
            context.runtime_character,
            runtime and runtime.player,
            true
        )
        local fallback_target = fallback_info and fallback_info.character or nil
        if probes ~= nil then
            probes[#probes + 1] = build_target_probe(
                candidate.label,
                candidate.root,
                fallback_info,
                fallback_reason,
                context.runtime_character,
                runtime and runtime.player
            )
        end
        if util.is_valid_obj(fallback_target)
            and not is_invalid_target_identity(context.runtime_character, fallback_target, runtime and runtime.player) then
            cache_target_info(data, fallback_info, fallback_reason, now)
            data.last_secondary_target_reason = tostring(fallback_reason or "secondary_target")
            return fallback_info, fallback_reason, probes
        end
    end

    data.last_secondary_target_reason = tostring(target_reason or "target_unresolved")

    if util.is_valid_obj(target) and is_invalid_target_identity(context.runtime_character, target, runtime and runtime.player) then
        return target_info, "invalid_target_identity", probes
    end

    return target_info, target_reason, probes
end

local function resolve_position(obj)
    if not util.is_valid_obj(obj) then
        return nil
    end

    local transform = call_first(obj, "get_Transform")
    if util.is_valid_obj(transform) then
        local position = util.safe_method(transform, "get_Position")
            or util.safe_method(transform, "get_UniversalPosition")
        if position ~= nil then
            return position
        end
    end

    return util.safe_method(obj, "get_UniversalPosition")
end

compute_distance = function(left, right)
    local left_position = resolve_position(left)
    local right_position = resolve_position(right)
    if left_position == nil or right_position == nil then
        return nil
    end

    local ok, distance = pcall(function()
        return (left_position - right_position):length()
    end)
    return ok and tonumber(distance) or nil
end

local function resolve_context_current_job(main_pawn, runtime_character)
    local human = main_pawn and main_pawn.human or call_first(runtime_character, "get_Human")
    local job_context = main_pawn and main_pawn.job_context

    if not is_queryable_obj(job_context) and util.is_valid_obj(human) then
        job_context = field_first(human, "<JobContext>k__BackingField")
            or field_first(human, "JobContext")
            or call_first(human, "get_JobContext")
    end

    local current_job = decode_small_int(main_pawn and main_pawn.current_job)
        or decode_small_int(main_pawn and main_pawn.job)
        or (is_queryable_obj(job_context) and decode_small_int(
            field_first(job_context, "CurrentJob")
                or call_first(job_context, "get_CurrentJob")
        ))
        or (util.is_valid_obj(human) and decode_small_int(
            field_first(human, "<CurrentJob>k__BackingField")
                or field_first(human, "CurrentJob")
                or call_first(human, "get_CurrentJob")
        ))
        or decode_small_int(call_first(runtime_character, "get_CurrentJob"))
        or decode_small_int(call_first(runtime_character, "get_Job"))
        or decode_small_int(field_first(runtime_character, "Job"))

    return current_job, human, job_context
end

local function resolve_context(runtime)
    local main_pawn, main_pawn_source, main_pawn_age = main_pawn_properties.get_resolved_main_pawn_data(
        runtime,
        "combat_main_pawn_data_unresolved"
    )
    if main_pawn == nil then
        return nil, "main_pawn_data_unresolved"
    end

    local runtime_character = main_pawn.runtime_character
    if not util.is_valid_obj(runtime_character) then
        return nil, "runtime_character_unresolved"
    end

    local current_job, human, job_context = resolve_context_current_job(main_pawn, runtime_character)
    if not hybrid_jobs.is_hybrid_job(current_job) then
        return nil, "main_pawn_not_hybrid_job"
    end

    local profile = hybrid_combat_profiles.get_by_job_id(current_job)
    if profile == nil then
        return nil, "hybrid_profile_unresolved"
    end

    local action_manager = main_pawn.action_manager or call_first(runtime_character, "get_ActionManager")
    if not util.is_valid_obj(action_manager) then
        return nil, "action_manager_unresolved"
    end

    local decision_maker = field_first(runtime_character, "<AIDecisionMaker>k__BackingField")
        or field_first(runtime_character, "AIDecisionMaker")
        or call_first(runtime_character, "get_AIDecisionMaker")
    local decision_module = field_first(decision_maker, "<DecisionModule>k__BackingField")
        or field_first(decision_maker, "DecisionModule")
        or call_first(decision_maker, "get_DecisionModule")
    local decision_executor = field_first(decision_module, "<DecisionExecutor>k__BackingField")
        or field_first(decision_module, "DecisionExecutor")
        or field_first(decision_module, "_DecisionExecutor")
        or call_first(decision_module, "get_DecisionExecutor")
    local executing_decision = field_first(decision_executor, "<ExecutingDecision>k__BackingField")
        or field_first(decision_executor, "ExecutingDecision")
        or field_first(decision_executor, "_ExecutingDecision")
        or call_first(decision_executor, "get_ExecutingDecision")
    local ai_blackboard = field_first(runtime_character, "<AIBlackBoardController>k__BackingField")
        or field_first(runtime_character, "AIBlackBoardController")
        or call_first(runtime_character, "get_AIBlackBoardController")

    local current_action = field_first(action_manager, "CurrentAction")
    local selected_request = field_first(action_manager, "SelectedRequest")

    return {
        main_pawn = main_pawn,
        runtime_character = runtime_character,
        human = human,
        job_context = job_context,
        current_job = current_job,
        job_entry = hybrid_jobs.get_by_id(current_job),
        profile = profile,
        action_manager = action_manager,
        decision_module = decision_module,
        decision_executor = decision_executor,
        executing_decision = executing_decision,
        ai_blackboard = ai_blackboard,
        current_action = current_action,
        selected_request = selected_request,
        current_action_identity = resolve_pack_like_identity(current_action),
        selected_request_identity = resolve_pack_like_identity(selected_request),
        decision_pack_path = resolve_decision_pack_path(decision_module, executing_decision),
        full_node = main_pawn.full_node or get_current_node(action_manager, 0),
        upper_node = main_pawn.upper_node or get_current_node(action_manager, 1),
        context_resolution_source = tostring(main_pawn_source or "runtime_main_pawn_data"),
        context_resolution_reason = tostring(
            main_pawn_source == "stable_main_pawn_data"
                and "combat_main_pawn_data_unresolved"
                or "resolved"
        ),
        context_resolution_age = tonumber(main_pawn_age) or 0.0,
    }, nil
end

local function create_ai_target(target_info)
    if type(target_info) ~= "table" or not util.is_valid_obj(target_info.character) then
        return nil
    end

    local ok, ai_target = pcall(sdk.create_instance, "app.AITargetGameObject", true)
    if not ok or ai_target == nil then
        return nil
    end

    if not util.is_valid_obj(target_info.game_object) then
        return nil
    end

    util.safe_set_field(ai_target, "<GameObject>k__BackingField", target_info.game_object)
    util.safe_set_field(ai_target, "<Character>k__BackingField", target_info.character)
    util.safe_set_field(ai_target, "<Owner>k__BackingField", target_info.game_object)
    util.safe_set_field(ai_target, "<OwnerCharacter>k__BackingField", target_info.character)
    util.safe_set_field(ai_target, "<ContextHolder>k__BackingField", target_info.context_holder)
    util.safe_set_field(ai_target, "<Transform>k__BackingField", target_info.transform)
    return ai_target
end

get_job_action_ctrl = function(context, job_id)
    local human = context and context.main_pawn and context.main_pawn.human or nil
    if not util.is_valid_obj(human) then
        human = call_first(context and context.runtime_character, "get_Human")
    end
    if not util.is_valid_obj(human) then
        return nil
    end

    local numeric_job_id = tonumber(job_id)
    if numeric_job_id == nil then
        return nil
    end

    local ctrl_name = string.format("Job%02dActionCtrl", numeric_job_id)
    return field_first(human, string.format("<%s>k__BackingField", ctrl_name))
        or field_first(human, ctrl_name)
        or call_first(human, "get_" .. ctrl_name)
end

local function describe_candidate_values(values)
    local collected = {}
    for _, value in ipairs(values or {}) do
        if type(value) == "string" and value ~= "" then
            collected[#collected + 1] = value
        end
    end

    if #collected == 0 then
        return "none"
    end

    return table.concat(collected, ",")
end

local function read_action_ctrl_state_field(action_ctrl, field_name)
    if not util.is_valid_obj(action_ctrl) or type(field_name) ~= "string" or field_name == "" then
        return "nil"
    end

    return describe_value(
        field_first(action_ctrl, string.format("<%s>k__BackingField", field_name))
            or field_first(action_ctrl, field_name)
            or call_first(action_ctrl, "get_" .. field_name)
    )
end

local function capture_unsafe_skill_probe_snapshot(context, target_info, target_distance, contract)
    local snapshot = {
        contract = tostring(contract and contract.class or "nil"),
        contract_key = tostring(contract and contract.controller_snapshot_key or "nil"),
        node = tostring(context and context.full_node or "nil"),
        current = tostring(context and context.current_action_identity or "nil"),
        request = tostring(context and context.selected_request_identity or "nil"),
        decision = tostring(context and context.decision_pack_path or "nil"),
        target = tostring(target_info and util.describe_obj(target_info.character) or "nil"),
        distance = tostring(target_distance or "nil"),
    }

    local action_ctrl = get_job_action_ctrl(context, context and context.current_job)
    if util.is_valid_obj(action_ctrl) then
        snapshot.action_ctrl = util.describe_obj(action_ctrl)
    else
        snapshot.action_ctrl = "nil"
    end

    local parts = {
        string.format("contract=%s", tostring(snapshot.contract)),
        string.format("contract_key=%s", tostring(snapshot.contract_key)),
        string.format("node=%s", tostring(snapshot.node)),
        string.format("current=%s", tostring(snapshot.current)),
        string.format("request=%s", tostring(snapshot.request)),
        string.format("decision=%s", tostring(snapshot.decision)),
        string.format("target=%s", tostring(snapshot.target)),
        string.format("dist=%s", tostring(snapshot.distance)),
        string.format("ctrl=%s", tostring(snapshot.action_ctrl)),
    }

    for _, field_name in ipairs(contract and contract.controller_state_fields or {}) do
        parts[#parts + 1] = string.format(
            "%s=%s",
            tostring(field_name),
            tostring(read_action_ctrl_state_field(action_ctrl, field_name))
        )
    end

    return table.concat(parts, " ")
end

local function get_data(runtime)
    runtime.hybrid_combat_fix_data = runtime.hybrid_combat_fix_data or {
        enabled = false,
        apply_count = 0,
        fail_count = 0,
        skip_count = 0,
        observe_only_count = 0,
        last_status = "idle",
        last_reason = "idle",
        last_job = nil,
        last_profile_key = "nil",
        last_phase_key = "nil",
        last_phase_mode = "nil",
        last_phase_selection_role = "nil",
        last_phase_bucket = "nil",
        last_pack_path = "nil",
        last_action_name = "nil",
        last_target = "nil",
        last_target_type = "nil",
        last_target_distance = nil,
        last_output_signature = "nil",
        last_output_text_blob = "nil",
        last_apply_time = nil,
        last_native_output_time = nil,
        last_failure_reason = "nil",
        last_failure_log_time = nil,
        last_observe_only_log_time = nil,
        last_observe_only_job = nil,
        last_phase_block_log_time = nil,
        last_phase_block_signature = "nil",
        last_skip_log_time = nil,
        last_skip_log_signature = "nil",
        last_target_probe_log_time = nil,
        last_target_probe_log_signature = "nil",
        cached_target_info = nil,
        cached_target_reason = "nil",
        cached_target_time = nil,
        last_secondary_target_scan_time = nil,
        last_secondary_target_reason = "nil",
        last_allowed_phase_summary = "none",
        last_blocked_phase_summary = "none",
        last_skill_gate_summary = "none",
        last_selected_phase_note = "nil",
        last_attempt_summary = "none",
        last_admission_mode = "nil",
        last_admission_family = "nil",
        last_combat_stage = "nil",
        synthetic_stall_started_at = nil,
        synthetic_stall_last_seen_at = nil,
        synthetic_stall_family = "nil",
        synthetic_stall_target_signature = "nil",
        synthetic_stall_elapsed = 0.0,
        synthetic_stall_anchor_reason = "nil",
        synthetic_stall_last_reset_reason = "nil",
        synthetic_stall_last_reset_at = nil,
        stable_context_snapshot = nil,
        stable_context_time = nil,
        stable_context_reason = "nil",
        phase_failure_quarantine = {},
        methods = {
            exec_method = nil,
            reqmain_method = nil,
            skip_think_method = nil,
            skip_think_method_source = "unresolved",
        },
    }
    runtime.hybrid_combat_fix_data.enabled = fix_config().enabled == true
    return runtime.hybrid_combat_fix_data
end

local function set_status(data, status, reason)
    data.last_status = tostring(status or "idle")
    data.last_reason = tostring(reason or "idle")
end

local function clone_context_snapshot(context)
    if type(context) ~= "table" then
        return nil
    end

    return {
        main_pawn = context.main_pawn,
        runtime_character = context.runtime_character,
        human = context.human,
        job_context = context.job_context,
        current_job = context.current_job,
        job_entry = context.job_entry,
        profile = context.profile,
        action_manager = context.action_manager,
        decision_module = context.decision_module,
        decision_executor = context.decision_executor,
        executing_decision = context.executing_decision,
        ai_blackboard = context.ai_blackboard,
        current_action = context.current_action,
        selected_request = context.selected_request,
        current_action_identity = context.current_action_identity,
        selected_request_identity = context.selected_request_identity,
        decision_pack_path = context.decision_pack_path,
        full_node = context.full_node,
        upper_node = context.upper_node,
        context_resolution_source = context.context_resolution_source,
        context_resolution_reason = context.context_resolution_reason,
        context_resolution_age = context.context_resolution_age,
    }
end

local function has_bridge_context(context)
    return type(context) == "table"
        and util.is_valid_obj(context.decision_module)
        and util.is_valid_obj(context.ai_blackboard)
end

local function can_reuse_bridge_context(current_snapshot, stable_snapshot)
    return type(current_snapshot) == "table"
        and type(stable_snapshot) == "table"
        and util.same_object(current_snapshot.runtime_character, stable_snapshot.runtime_character)
        and tonumber(current_snapshot.current_job) == tonumber(stable_snapshot.current_job)
        and tostring(current_snapshot.profile and current_snapshot.profile.key or "nil")
            == tostring(stable_snapshot.profile and stable_snapshot.profile.key or "nil")
end

local function hydrate_bridge_context_from_stable(data, context)
    if type(data) ~= "table" or type(context) ~= "table" or has_bridge_context(context) then
        return context
    end

    local stable_snapshot = clone_context_snapshot(data.stable_context_snapshot)
    if not has_bridge_context(stable_snapshot) or not can_reuse_bridge_context(context, stable_snapshot) then
        return context
    end

    context.decision_module = context.decision_module or stable_snapshot.decision_module
    context.decision_executor = context.decision_executor or stable_snapshot.decision_executor
    context.executing_decision = context.executing_decision or stable_snapshot.executing_decision
    context.ai_blackboard = context.ai_blackboard or stable_snapshot.ai_blackboard
    return context
end

local function cache_stable_context(data, context, now)
    if type(data) ~= "table" or type(context) ~= "table" then
        return
    end

    local snapshot = clone_context_snapshot(context)
    local stable_snapshot = clone_context_snapshot(data.stable_context_snapshot)
    if not has_bridge_context(snapshot) and can_reuse_bridge_context(snapshot, stable_snapshot) then
        snapshot.decision_module = stable_snapshot.decision_module
        snapshot.decision_executor = stable_snapshot.decision_executor
        snapshot.executing_decision = snapshot.executing_decision or stable_snapshot.executing_decision
        snapshot.ai_blackboard = stable_snapshot.ai_blackboard
    end

    data.stable_context_snapshot = snapshot
    data.stable_context_time = tonumber(now) or 0.0
    data.stable_context_reason = tostring(context.context_resolution_reason or "resolved")
end

local function get_stable_context(data, now, fallback_reason)
    if type(data) ~= "table" then
        return nil, "stable_context_unavailable"
    end

    local ttl = context_grace_seconds()
    if ttl <= 0.0 then
        return nil, "stable_context_disabled"
    end

    local cached = clone_context_snapshot(data.stable_context_snapshot)
    local cached_time = tonumber(data.stable_context_time)
    if cached == nil or cached_time == nil then
        return nil, "stable_context_unavailable"
    end

    local age = math.max(0.0, (tonumber(now) or 0.0) - cached_time)
    if age > ttl then
        data.stable_context_snapshot = nil
        data.stable_context_time = nil
        data.stable_context_reason = "stable_context_expired"
        return nil, "stable_context_expired"
    end

    if not util.is_valid_obj(cached.runtime_character)
        or not util.is_valid_obj(cached.action_manager)
        or not hybrid_jobs.is_hybrid_job(cached.current_job)
        or type(cached.profile) ~= "table" then
        data.stable_context_snapshot = nil
        data.stable_context_time = nil
        data.stable_context_reason = "stable_context_invalid"
        return nil, "stable_context_invalid"
    end

    cached.context_resolution_source = "stable_context_fallback"
    cached.context_resolution_reason = tostring(fallback_reason or "context_unresolved")
    cached.context_resolution_age = age
    return cached, "stable_context_fallback"
end

local function clear_synthetic_stall_state(data, reason, now)
    if type(data) ~= "table" then
        return
    end

    data.synthetic_stall_anchor_reason = "nil"
    data.synthetic_stall_last_reset_reason = tostring(reason or "state_cleared")
    data.synthetic_stall_last_reset_at = tonumber(now)
    data.synthetic_stall_started_at = nil
    data.synthetic_stall_last_seen_at = nil
    data.synthetic_stall_family = "nil"
    data.synthetic_stall_target_signature = "nil"
    data.synthetic_stall_elapsed = 0.0
end

local function clear_phase_failure_quarantine(data)
    if type(data) ~= "table" then
        return
    end

    data.phase_failure_quarantine = {}
end

local function get_phase_failure_quarantine(data, phase_key, now)
    if type(data) ~= "table" or type(phase_key) ~= "string" or phase_key == "" then
        return nil
    end

    data.phase_failure_quarantine = type(data.phase_failure_quarantine) == "table"
        and data.phase_failure_quarantine
        or {}

    local entry = data.phase_failure_quarantine[phase_key]
    local until_time = type(entry) == "table" and tonumber(entry.until_time) or nil
    if until_time == nil or tonumber(now) == nil or tonumber(now) >= until_time then
        data.phase_failure_quarantine[phase_key] = nil
        return nil
    end

    return {
        until_time = until_time,
        reason = tostring(entry.reason or "phase_bridge_failed"),
    }
end

local function set_phase_failure_quarantine(data, phase_key, reason, now)
    if type(data) ~= "table" or type(phase_key) ~= "string" or phase_key == "" then
        return
    end

    local duration_seconds = phase_failure_quarantine_seconds()
    if duration_seconds <= 0.0 then
        return
    end

    data.phase_failure_quarantine = type(data.phase_failure_quarantine) == "table"
        and data.phase_failure_quarantine
        or {}

    local current_time = tonumber(now) or 0.0
    data.phase_failure_quarantine[phase_key] = {
        until_time = current_time + duration_seconds,
        reason = tostring(reason or "phase_bridge_failed"),
    }
end

local function resolve_contract_probe_mode(contract)
    if type(contract) ~= "table" or contract.probe_required ~= true then
        return "off", "not_required"
    end

    local configured_mode = unsafe_skill_probe_mode()
    if configured_mode ~= "off" then
        if execution_contracts.supports_probe_mode(contract, configured_mode) then
            return configured_mode, "config"
        end
        return nil, "configured_probe_mode_unsupported"
    end

    local preferred_mode = tostring(contract.preferred_probe_mode or "")
    if preferred_mode ~= "" then
        if execution_contracts.supports_probe_mode(contract, preferred_mode) then
            return preferred_mode, "contract_preferred"
        end
        return nil, "preferred_probe_mode_unsupported"
    end

    return nil, "unsafe_probe_disabled"
end

local function ensure_methods(data)
    local methods = data.methods

    if methods.exec_method == nil then
        local extensions_td = util.safe_sdk_typedef("app.AIBlackBoardExtensions")
        if extensions_td ~= nil then
            local ok, method = pcall(function()
                return extensions_td:get_method(ACTINTER_EXECUTE_SIGNATURE)
            end)
            methods.exec_method = ok and method or nil
        end
    end

    if methods.reqmain_method == nil then
        local controller_td = util.safe_sdk_typedef("app.AIBlackBoardController")
        if controller_td ~= nil then
            local ok, method = pcall(function()
                return controller_td:get_method(ACTINTER_REQMAIN_SIGNATURE)
            end)
            methods.reqmain_method = ok and method or nil
        end
    end

    if methods.skip_think_method == nil then
        local decision_module_td = util.safe_sdk_typedef("app.DecisionEvaluationModule")
        if decision_module_td ~= nil then
            local ok, method = pcall(function()
                return decision_module_td:get_method(REQUEST_SKIP_THINK_SIGNATURE)
            end)
            if ok and method ~= nil then
                methods.skip_think_method = method
                methods.skip_think_method_source = "app.DecisionEvaluationModule"
            end
        end
    end

    if methods.skip_think_method == nil then
        local decision_module_td = util.safe_sdk_typedef("app.DecisionModule")
        if decision_module_td ~= nil then
            local ok, method = pcall(function()
                return decision_module_td:get_method(REQUEST_SKIP_THINK_SIGNATURE)
            end)
            if ok and method ~= nil then
                methods.skip_think_method = method
                methods.skip_think_method_source = "app.DecisionModule"
            end
        end
    end

    return methods
end

local function apply_carrier_bridge(data, context, pack_path, target_info)
    local pack_data = util.safe_create_userdata("app.ActInterPackData", pack_path)
    if pack_data == nil then
        return false, {
            reason = "actinter_pack_create_failed",
            pack_path = tostring(pack_path or "nil"),
        }
    end

    local ai_target = create_ai_target(target_info)
    if ai_target == nil then
        return false, {
            reason = "ai_target_create_failed",
            pack_path = tostring(pack_path or "nil"),
        }
    end

    local methods = ensure_methods(data)
    if methods.exec_method == nil or methods.reqmain_method == nil or not util.is_valid_obj(context.ai_blackboard) then
        return false, {
            reason = "carrier_methods_unresolved",
            pack_path = tostring(pack_path or "nil"),
            ai_target = util.describe_obj(ai_target),
            ai_target_type = util.get_type_full_name(ai_target) or "nil",
        }
    end

    local exec_ok, exec_err = pcall(function()
        methods.exec_method:call(nil, context.ai_blackboard, pack_data, ai_target)
    end)
    local reqmain_ok, reqmain_err = pcall(function()
        methods.reqmain_method:call(context.ai_blackboard, pack_data)
    end)

    local skip_think_ok = false
    local skip_think_err = nil
    if fix_config().request_skip_think == true
        and methods.skip_think_method ~= nil
        and util.is_valid_obj(context.decision_module) then
        skip_think_ok, skip_think_err = pcall(function()
            methods.skip_think_method:call(context.decision_module)
        end)
    end

    return exec_ok and reqmain_ok, {
        reason = exec_ok and reqmain_ok and "ok" or "carrier_bridge_call_failed",
        bridge_kind = "carrier",
        pack_path = tostring(pack_path or "nil"),
        ai_target = util.describe_obj(ai_target),
        ai_target_type = util.get_type_full_name(ai_target) or "nil",
        exec_ok = exec_ok,
        exec_err = tostring(exec_err),
        reqmain_ok = reqmain_ok,
        reqmain_err = tostring(reqmain_err),
        skip_think_ok = skip_think_ok,
        skip_think_err = tostring(skip_think_err),
        skip_think_method_source = tostring(methods.skip_think_method_source or "unresolved"),
    }
end

local function apply_action_bridge(context, action_name, action_layer, action_priority)
    if not util.is_valid_obj(context.action_manager) then
        return false, {
            reason = "action_manager_unresolved",
            bridge_kind = "action",
            action_name = tostring(action_name or "nil"),
        }
    end

    if type(action_name) ~= "string" or action_name == "" then
        return false, {
            reason = "action_name_unresolved",
            bridge_kind = "action",
            action_name = tostring(action_name or "nil"),
        }
    end

    local request_ok, request_err = pcall(function()
        context.action_manager:requestActionCore(
            tonumber(action_priority) or 0,
            action_name,
            tonumber(action_layer) or 0
        )
    end)

    return request_ok, {
        reason = request_ok and "ok" or "request_action_failed",
        bridge_kind = "action",
        action_name = tostring(action_name),
        action_layer = tonumber(action_layer) or 0,
        action_priority = tonumber(action_priority) or 0,
        request_ok = request_ok,
        request_err = tostring(request_err),
    }
end

local function resolve_phase_execution_contract(phase_entry)
    return execution_contracts.resolve(phase_entry)
end

local function apply_phase_bridge(data, context, phase_entry, target_info, target_distance)
    local results = {}
    local success = false
    local selected_pack_path = nil
    local selected_action_name = nil
    local contract = resolve_phase_execution_contract(phase_entry)

    local pack_candidates = contract.carrier_candidates
    local action_candidates = contract.action_candidates
    local probe_mode = nil
    local probe_mode_source = "not_required"
    local probe_snapshot = nil

    if contract.probe_required then
        probe_mode, probe_mode_source = resolve_contract_probe_mode(contract)
        if probe_mode == nil then
            local probe_reason = (probe_mode_source == "configured_probe_mode_unsupported"
                    or probe_mode_source == "preferred_probe_mode_unsupported")
                and "unsupported_probe_mode"
                or "unsafe_probe_disabled"
            return false, {
                reason = probe_reason,
                bridge_kind = "hybrid_failed",
                execution_contract_class = contract.class,
                execution_bridge_mode = tostring(contract.bridge_mode or "probe_only"),
                probe_mode = "off",
                probe_mode_source = tostring(probe_mode_source or "unresolved"),
                results = results,
            }
        end
        pack_candidates = #contract.probe_pack_candidates > 0 and contract.probe_pack_candidates or contract.carrier_candidates
        if probe_mode == "action_only" then
            pack_candidates = {}
        elseif probe_mode == "carrier_only" then
            action_candidates = {}
        end

        if fix_config().unsafe_skill_probe_log_details == true then
            probe_snapshot = capture_unsafe_skill_probe_snapshot(context, target_info, target_distance, contract)
            log.warn(string.format(
                "Hybrid unsafe skill probe job=%s phase=%s mode=%s packs=%s actions=%s snapshot=%s",
                tostring(context.current_job),
                tostring(phase_entry.key or "nil"),
                tostring(probe_mode),
                tostring(describe_candidate_values(pack_candidates)),
                tostring(describe_candidate_values(action_candidates)),
                tostring(probe_snapshot)
            ))
        end
    end

    local bridge_mode = tostring(contract.bridge_mode or "action_only")
    if probe_mode ~= nil and probe_mode ~= "off" then
        bridge_mode = probe_mode
    end

    if bridge_mode == "selector_owned" then
        return false, {
            reason = "selector_owned_unbridgeable",
            bridge_kind = "selector_owned",
            execution_contract_class = contract.class,
            execution_bridge_mode = bridge_mode,
            results = results,
        }
    end

    local function attempt_carriers()
        for _, pack_path in ipairs(pack_candidates) do
            local carrier_ok, carrier_info = apply_carrier_bridge(data, context, pack_path, target_info)
            carrier_info.pack_path = tostring(pack_path)
            results[#results + 1] = carrier_info
            if carrier_ok and selected_pack_path == nil then
                selected_pack_path = tostring(pack_path)
            end
            success = success or carrier_ok
        end
    end

    local function attempt_actions()
        for _, action_name in ipairs(action_candidates) do
            local action_ok, action_info = apply_action_bridge(
                context,
                action_name,
                phase_entry.action_layer,
                phase_entry.action_priority
            )
            action_info.action_name = tostring(action_name)
            results[#results + 1] = action_info
            if action_ok and selected_action_name == nil then
                selected_action_name = tostring(action_name)
            end
            success = success or action_ok
        end
    end

    if bridge_mode == "carrier_only" then
        attempt_carriers()
    elseif bridge_mode == "action_only" then
        attempt_actions()
    else
        attempt_carriers()
        attempt_actions()
    end

    if #results == 0 then
        return false, {
            reason = "phase_bridge_undefined",
            bridge_kind = "none",
            pack_path = tostring(phase_entry.pack_path or "nil"),
            action_name = tostring(phase_entry.action_name or "nil"),
            execution_contract_class = contract.class,
            execution_bridge_mode = bridge_mode,
            results = results,
        }
    end

    local failure_parts = {}
    for _, item in ipairs(results) do
        if tostring(item.reason or "ok") ~= "ok" then
            failure_parts[#failure_parts + 1] = string.format(
                "%s=%s",
                tostring(item.bridge_kind or "bridge"),
                tostring(item.reason or "failed")
            )
        end
    end

    return success, {
        reason = success and "ok" or table.concat(failure_parts, ","),
        bridge_kind = success and "hybrid" or "hybrid_failed",
        pack_path = tostring(selected_pack_path or phase_entry.pack_path or "nil"),
        action_name = tostring(selected_action_name or phase_entry.action_name or "nil"),
        execution_contract_class = contract.class,
        execution_bridge_mode = bridge_mode,
        probe_mode = tostring(probe_mode or "off"),
        probe_mode_source = tostring(probe_mode_source or "unresolved"),
        probe_snapshot = probe_snapshot,
        results = results,
    }
end

local function build_output_texts(context)
    return {
        tostring(context.decision_pack_path or "nil"),
        tostring(context.current_action_identity or "nil"),
        tostring(context.selected_request_identity or "nil"),
        tostring(context.full_node or "nil"),
        tostring(context.upper_node or "nil"),
    }
end

local function build_output_text_blob(context)
    return table.concat(build_output_texts(context), " | ")
end

local function has_profile_output(context)
    return contains_any_text(build_output_text_blob(context), context.profile.output_tokens)
end

local function is_utility_locked_output(context)
    return contains_any_text(build_output_text_blob(context), UTILITY_TOKENS)
end

local function is_damage_recovery_output(context)
    return contains_any_text(build_output_text_blob(context), DAMAGE_RECOVERY_TOKENS)
end

local function is_special_skip_output(context)
    return contains_any_text(build_output_text_blob(context), SPECIAL_SKIP_TOKENS)
end

local function is_special_recovery_output(context)
    return contains_any_text(build_output_text_blob(context), SPECIAL_RECOVERY_TOKENS)
end

local function is_support_recovery_output(context)
    return contains_any_text(build_output_text_blob(context), SUPPORT_RECOVERY_TOKENS)
end

local function evaluate_support_recovery_guard(context)
    local hp_ratio, hp_source = resolve_actor_hp_ratio(context and context.runtime_character)
    local threshold = synthetic_support_recovery_hp_ratio()
    if threshold <= 0.0 then
        return false, {
            reason = "support_recovery_guard_disabled",
            support_guard_hp_ratio = hp_ratio,
            support_guard_hp_source = hp_source,
        }
    end

    if hp_ratio == nil or hp_ratio > threshold then
        return false, {
            reason = "support_recovery_guard_hp_above_threshold",
            support_guard_hp_ratio = hp_ratio,
            support_guard_hp_source = hp_source,
            support_guard_hp_threshold = threshold,
        }
    end

    local decision_target_type, decision_target_source = resolve_decision_target_type(context and context.executing_decision)
    local support_navigation_output = is_support_recovery_output(context)
    local support_position_target = tostring(decision_target_type or "nil") == "app.AITargetPosition"

    if not support_navigation_output and not support_position_target then
        return false, {
            reason = "support_recovery_guard_no_support_signal",
            support_guard_hp_ratio = hp_ratio,
            support_guard_hp_source = hp_source,
            support_guard_hp_threshold = threshold,
            support_guard_target_type = decision_target_type,
            support_guard_target_source = decision_target_source,
        }
    end

    return true, {
        reason = support_position_target and "support_recovery_position_target_low_hp" or "support_recovery_navigation_low_hp",
        support_guard_hp_ratio = hp_ratio,
        support_guard_hp_source = hp_source,
        support_guard_hp_threshold = threshold,
        support_guard_target_type = decision_target_type,
        support_guard_target_source = decision_target_source,
        support_guard_output = support_navigation_output,
    }
end

local function get_recoverable_output_family(context, special_recovery_allowed)
    if special_recovery_allowed == true then
        return "special_recovery"
    end
    if is_damage_recovery_output(context) then
        return "damage_recovery"
    end
    if is_utility_locked_output(context) then
        return "utility"
    end

    return nil
end

local function resolve_bridge_admission_mode(data, context, runtime, target_info, now, special_recovery_allowed)
    local recoverable_output_family = get_recoverable_output_family(context, special_recovery_allowed)
    if recoverable_output_family == nil then
        clear_synthetic_stall_state(data, "nonrecoverable_output_family", now)
        return nil, {
            reason = "nonrecoverable_output_family",
            recoverable_output_family = "none",
        }
    end

    if not has_usable_enemy_target(target_info, context.runtime_character, runtime and runtime.player) then
        clear_synthetic_stall_state(data, "synthetic_target_missing", now)
        return nil, {
            reason = "synthetic_target_missing",
            recoverable_output_family = recoverable_output_family,
        }
    end

    local backoff_seconds = synthetic_native_output_backoff_seconds()
    if data.last_native_output_time ~= nil and backoff_seconds > 0.0 then
        local backoff_remaining = backoff_seconds - (now - data.last_native_output_time)
        if backoff_remaining > 0.0 then
            clear_synthetic_stall_state(data, "native_output_backoff_active", now)
            return nil, {
                reason = "native_output_backoff_active",
                recoverable_output_family = recoverable_output_family,
                synthetic_backoff_remaining = backoff_remaining,
            }
        end
    end

    local target_signature = util.describe_obj(target_info and target_info.character)
    local stall_signature = table.concat({
        tostring(context.current_job or "nil"),
        tostring(target_signature or "nil"),
    }, " | ")

    local stall_anchor_reason = nil
    if data.synthetic_stall_started_at == nil then
        data.synthetic_stall_started_at = now
        if tostring(data.synthetic_stall_last_reset_reason or "nil") ~= "nil" then
            stall_anchor_reason = "after_reset:" .. tostring(data.synthetic_stall_last_reset_reason)
        else
            stall_anchor_reason = "initial_window"
        end
    elseif data.synthetic_stall_target_signature ~= stall_signature then
        data.synthetic_stall_started_at = now
        stall_anchor_reason = "target_signature_changed"
    end
    if stall_anchor_reason ~= nil then
        data.synthetic_stall_anchor_reason = stall_anchor_reason
    end

    data.synthetic_stall_last_seen_at = now
    data.synthetic_stall_family = tostring(recoverable_output_family or "nil")
    data.synthetic_stall_target_signature = stall_signature
    data.synthetic_stall_elapsed = math.max(0.0, now - data.synthetic_stall_started_at)

    local required_mode = recoverable_output_family == "utility"
        and "synthetic_initiator"
        or "synthetic_stall"
    local required_window = recoverable_output_family == "utility"
        and synthetic_initiator_window_seconds()
        or synthetic_stall_window_seconds()
    local pending_reason = required_mode == "synthetic_initiator"
        and "synthetic_initiator_not_ready"
        or "synthetic_stall_not_ready"
    local ready_reason = required_mode == "synthetic_initiator"
        and "synthetic_initiator_ready"
        or "synthetic_stall_ready"

    if data.synthetic_stall_elapsed < required_window then
        return nil, {
            reason = pending_reason,
            synthetic_admission_mode = required_mode,
            recoverable_output_family = recoverable_output_family,
            synthetic_stall_elapsed = data.synthetic_stall_elapsed,
            synthetic_stall_window = required_window,
            synthetic_stall_anchor_reason = data.synthetic_stall_anchor_reason,
            synthetic_stall_reset_reason = data.synthetic_stall_last_reset_reason,
        }
    end

    return required_mode, {
        reason = ready_reason,
        synthetic_admission_mode = required_mode,
        recoverable_output_family = recoverable_output_family,
        synthetic_stall_elapsed = data.synthetic_stall_elapsed,
        synthetic_stall_window = required_window,
        synthetic_stall_anchor_reason = data.synthetic_stall_anchor_reason,
        synthetic_stall_reset_reason = data.synthetic_stall_last_reset_reason,
    }
end

local function describe_skill_ids(ids)
    local values = {}
    for _, value in ipairs(ids or {}) do
        values[#values + 1] = tostring(value)
    end

    if #values == 0 then
        return "none"
    end

    return table.concat(values, ",")
end

local function is_unmapped_phase_allowed(phase_entry, contract)
    if phase_entry.block_if_unmapped == false then
        return true, "phase_opted_out"
    end
    if fix_config().allow_unmapped_skill_phases ~= true then
        return false, "config_disabled"
    end
    if contract ~= nil and contract.class == "selector_owned" then
        return false, "selector_owned_unbridgeable"
    end
    return true, "config_enabled"
end

local function get_collection_count(obj)
    if obj == nil then
        return nil
    end

    local count = util.safe_method(obj, "get_Count()")
        or util.safe_method(obj, "get_count()")
        or util.safe_method(obj, "get_Size()")
        or util.safe_method(obj, "get_size()")
        or field_first(obj, "Count")
        or field_first(obj, "count")
        or field_first(obj, "_size")
        or field_first(obj, "size")

    return tonumber(count)
end

local function get_collection_item(obj, index)
    if obj == nil then
        return nil
    end

    local item = util.safe_method(obj, "get_Item(System.Int32)", index)
        or util.safe_method(obj, "get_Item(System.UInt32)", index)
        or util.safe_method(obj, "get_Item", index)
    if item ~= nil then
        return item
    end

    local ok, raw_item = pcall(function()
        return obj[index]
    end)
    return ok and raw_item or nil
end

local function resolve_job_equip_list(skill_context, job_id)
    if skill_context == nil or job_id == nil then
        return nil
    end

    local equip_list = util.safe_direct_method(skill_context, "getEquipList", job_id)
        or util.safe_method(skill_context, "getEquipList(System.Int32)", job_id)
        or util.safe_method(skill_context, "getEquipList(app.Character.JobEnum)", job_id)
        or util.safe_method(skill_context, "getEquipList", job_id)
    if is_present_value(equip_list) then
        return equip_list
    end

    local equipped_root = present_field(skill_context, EQUIPPED_SKILLS_FIELDS)
    local indexed = get_collection_item(equipped_root, job_id)
    if is_present_value(indexed) then
        return indexed
    end

    local indexed_minus_one = get_collection_item(equipped_root, job_id - 1)
    if is_present_value(indexed_minus_one) then
        return indexed_minus_one
    end

    return nil
end

local function build_equipped_skill_snapshot(skill_context, job_id)
    local equipped_skill_ids = {}
    local equipped_skill_map = {}

    local equip_list = resolve_job_equip_list(skill_context, job_id)
    local skills_root = present_field(equip_list, SKILLS_LIST_FIELDS)
    local skill_count = get_collection_count(skills_root)
    local max_slots = skill_count ~= nil and math.min(skill_count, 8) or 4

    for slot = 0, max_slots - 1 do
        local item = get_collection_item(skills_root, slot)
        local skill_id = decode_small_int(item)
        if skill_id == nil then
            skill_id = decode_small_int(field_first(item, "value__"))
        end
        if skill_id ~= nil and skill_id ~= 0 and not equipped_skill_map[skill_id] then
            equipped_skill_map[skill_id] = true
            equipped_skill_ids[#equipped_skill_ids + 1] = skill_id
        end
    end

    table.sort(equipped_skill_ids)
    return equipped_skill_ids, equipped_skill_map
end

local function describe_required_skill_cache(cache)
    local skill_ids = {}
    for skill_id, _ in pairs(cache or {}) do
        skill_ids[#skill_ids + 1] = skill_id
    end

    table.sort(skill_ids)

    local values = {}
    for _, skill_id in ipairs(skill_ids) do
        local item = cache[skill_id] or {}
        values[#values + 1] = string.format(
            "%s(stage=%s,lv=%s,learn=%s,eq=%s,list=%s,en=%s,av=%s)",
            tostring(skill_id),
            tostring(item.stage),
            tostring(item.current_skill_level),
            tostring(item.learned),
            tostring(item.equipped),
            tostring(item.listed),
            tostring(item.enabled),
            tostring(item.available)
        )
    end

    if #values == 0 then
        return "none"
    end

    return table.concat(values, ",")
end

local function resolve_current_job_level(runtime, context)
    local progression = runtime.progression_state_data and runtime.progression_state_data.main_pawn or nil
    if progression ~= nil then
        local direct = decode_small_int(progression.current_job_level)
        if direct ~= nil then
            return direct, "progression.current_job_level"
        end

        local key = context.profile and context.profile.key or nil
        local job_item = key and progression.job_diagnostic_table and progression.job_diagnostic_table[key] or nil
        local item_level = job_item and decode_small_int(job_item.job_level) or nil
        if item_level ~= nil then
            return item_level, "progression.job_diagnostic_table"
        end
    end

    local current_job = decode_small_int(context.current_job)
    if current_job ~= nil and context.profile ~= nil then
        return 0, "assumed_minimum_job_level"
    end

    return nil, "unresolved"
end

local function call_has_equipped_skill(skill_context, job_id, skill_id)
    if skill_context == nil or job_id == nil or skill_id == nil then
        return nil
    end

    return util.safe_direct_method(skill_context, "hasEquipedSkill", job_id, skill_id)
        or util.safe_method(skill_context, "hasEquipedSkill(app.Character.JobEnum, app.HumanCustomSkillID)", job_id, skill_id)
        or util.safe_method(skill_context, "hasEquipedSkill", job_id, skill_id)
end

local function call_is_custom_skill_enable(skill_context, skill_id)
    if skill_context == nil or skill_id == nil then
        return nil
    end

    return util.safe_direct_method(skill_context, "isCustomSkillEnable", skill_id)
        or util.safe_method(skill_context, "isCustomSkillEnable(app.HumanCustomSkillID)", skill_id)
        or util.safe_method(skill_context, "isCustomSkillEnable", skill_id)
end

local function call_is_custom_skill_available(skill_availability, skill_id)
    if skill_availability == nil or skill_id == nil then
        return nil
    end

    return util.safe_direct_method(skill_availability, "isCustomSkillAvailable", skill_id)
        or util.safe_method(skill_availability, "isCustomSkillAvailable(app.HumanCustomSkillID)", skill_id)
        or util.safe_method(skill_availability, "isCustomSkillAvailable", skill_id)
end

local function call_get_custom_skill_level(skill_context, skill_id)
    if skill_context == nil or skill_id == nil then
        return nil
    end

    return util.safe_direct_method(skill_context, "getCustomSkillLevel", skill_id)
        or util.safe_method(skill_context, "getCustomSkillLevel(app.HumanCustomSkillID)", skill_id)
        or util.safe_method(skill_context, "getCustomSkillLevel", skill_id)
end

local function build_skill_gate_state(runtime, context)
    local progression = runtime.progression_state_data and runtime.progression_state_data.main_pawn or nil
    local skill_context = progression and progression.skill_context or context.main_pawn.skill_context or nil
    local equipped_skill_ids, equipped_skill_map = build_equipped_skill_snapshot(skill_context, context.current_job)
    local current_job_level, current_job_level_source = resolve_current_job_level(runtime, context)
    return {
        current_job = context.current_job,
        current_job_level = current_job_level,
        current_job_level_source = current_job_level_source,
        skill_context = skill_context,
        skill_availability = progression and progression.skill_availability or nil,
        custom_skill_state = progression and progression.custom_skill_state or context.main_pawn.skill_state or nil,
        current_job_skill_lifecycle = progression and progression.current_job_skill_lifecycle or nil,
        equipped_skill_ids = equipped_skill_ids,
        equipped_skill_map = equipped_skill_map,
        required_skill_state_cache = {},
    }
end

local function resolve_required_skill_state(gate_state, required_skill_id)
    if required_skill_id == nil then
        return {
            listed = nil,
            equipped = nil,
            enabled = nil,
            available = nil,
        }
    end

    local cache = gate_state.required_skill_state_cache or {}
    gate_state.required_skill_state_cache = cache

    if cache[required_skill_id] ~= nil then
        return cache[required_skill_id]
    end

    local lifecycle = gate_state.current_job_skill_lifecycle
    local lifecycle_item = lifecycle and lifecycle.skills_by_id and lifecycle.skills_by_id[required_skill_id] or nil
    if lifecycle_item ~= nil then
        local item = {
            listed = lifecycle_item.equipped,
            learned = lifecycle_item.learned,
            equipped = lifecycle_item.equipped,
            enabled = lifecycle_item.enabled,
            available = lifecycle_item.available,
            combat_ready = lifecycle_item.combat_ready,
            current_skill_level = lifecycle_item.current_skill_level,
            stage = lifecycle_item.stage,
        }
        cache[required_skill_id] = item
        return item
    end

    local listed = gate_state.equipped_skill_map[required_skill_id] == true
    local equipped = decode_truthy(call_has_equipped_skill(gate_state.skill_context, gate_state.current_job, required_skill_id))
    if equipped == nil then
        equipped = listed
    end
    local current_skill_level = decode_small_int(call_get_custom_skill_level(gate_state.skill_context, required_skill_id))
    local learned = current_skill_level ~= nil and current_skill_level > 0 or nil

    local item = {
        listed = listed,
        learned = learned,
        equipped = equipped,
        enabled = decode_truthy(call_is_custom_skill_enable(gate_state.skill_context, required_skill_id)),
        available = decode_truthy(call_is_custom_skill_available(gate_state.skill_availability, required_skill_id)),
        combat_ready = learned == true and equipped == true
            and decode_truthy(call_is_custom_skill_enable(gate_state.skill_context, required_skill_id)) == true
            and decode_truthy(call_is_custom_skill_available(gate_state.skill_availability, required_skill_id)) ~= false,
        current_skill_level = current_skill_level,
    }
    if item.learned == true and item.equipped == true and item.enabled == true and item.available ~= false then
        item.stage = "combat_ready"
    elseif item.learned == true and item.equipped == true then
        item.stage = "equipped"
    elseif item.learned == true then
        item.stage = "learned"
    else
        item.stage = "potential"
    end

    cache[required_skill_id] = item
    return item
end

local function evaluate_phase_gate(phase_entry, gate_state)
    local contract = resolve_phase_execution_contract(phase_entry)
    local probe_mode, probe_mode_source = resolve_contract_probe_mode(contract)
    local meta = {
        phase_key = tostring(phase_entry.key or "nil"),
        execution_contract_class = tostring(contract.class or "nil"),
        execution_bridge_mode = tostring(contract.bridge_mode or "nil"),
        probe_mode = tostring(probe_mode or "off"),
        probe_mode_source = tostring(probe_mode_source or "unresolved"),
        current_job_level = gate_state.current_job_level,
        current_job_level_source = tostring(gate_state.current_job_level_source or "unresolved"),
        required_skill_name = tostring(phase_entry.required_skill_name or "nil"),
        required_skill_id = decode_small_int(phase_entry.required_skill_id),
        skill_context = util.describe_obj(gate_state.skill_context),
        skill_availability = util.describe_obj(gate_state.skill_availability),
        equipped_skill_ids = describe_skill_ids(gate_state.equipped_skill_ids),
    }

    local min_job_level = decode_small_int(phase_entry.min_job_level)
    if min_job_level ~= nil then
        if gate_state.current_job_level == nil then
            return false, "job_level_unresolved", meta
        end
    end
    if min_job_level ~= nil then
        if gate_state.current_job_level < min_job_level then
            return false, "job_level_too_low", meta
        end
    end

    if contract.class == "selector_owned" then
        local unmapped_allowed = is_unmapped_phase_allowed(phase_entry, contract)
        return false, unmapped_allowed
                and "execution_contract_unmapped_unbridgeable"
                or "selector_owned_contract_unimplemented", meta
    end

    if contract.probe_required and probe_mode == nil then
        local probe_reason = (probe_mode_source == "configured_probe_mode_unsupported"
                or probe_mode_source == "preferred_probe_mode_unsupported")
            and "unsupported_probe_mode"
            or "unsafe_probe_disabled"
        return false, probe_reason, meta
    end

    if contract.probe_required and not execution_contracts.supports_probe_mode(contract, probe_mode) then
        return false, "unsupported_probe_mode", meta
    end

    local max_job_level = decode_small_int(phase_entry.max_job_level)
    if max_job_level ~= nil and gate_state.current_job_level ~= nil and gate_state.current_job_level > max_job_level then
        return false, "job_level_too_high", meta
    end

    local requires_learned = phase_entry.requires_learned_skill == true
    local requires_equipped = phase_entry.requires_equipped_skill == true
    local requires_enabled = phase_entry.requires_enabled_skill == true
    local requires_available = phase_entry.requires_available_skill == true
    if fix_config().enforce_skill_loadout_gate ~= true
        or (not requires_learned and not requires_equipped and not requires_enabled and not requires_available) then
        return true, "phase_gate_passed", meta
    end

    local required_skill_id = meta.required_skill_id
    if required_skill_id == nil then
        local unmapped_allowed = is_unmapped_phase_allowed(phase_entry, contract)
        if unmapped_allowed then
            return true, "skill_mapping_unresolved_but_allowed", meta
        end

        return false, "skill_mapping_unresolved", meta
    end

    local skill_state = resolve_required_skill_state(gate_state, required_skill_id)
    meta.required_skill_listed = skill_state.listed
    meta.required_skill_learned = skill_state.learned
    meta.required_skill_equipped = skill_state.equipped
    meta.required_skill_enabled = skill_state.enabled
    meta.required_skill_available = skill_state.available
    meta.required_skill_combat_ready = skill_state.combat_ready
    meta.required_skill_stage = skill_state.stage
    meta.required_skill_level = skill_state.current_skill_level

    if requires_learned then
        if skill_state.learned ~= true then
            return false, "skill_not_learned", meta
        end
    end

    if requires_equipped then
        if skill_state.equipped ~= true then
            return false, "skill_not_equipped", meta
        end
    end

    if requires_enabled then
        if skill_state.enabled ~= nil and skill_state.enabled ~= true then
            return false, "skill_not_enabled", meta
        end
    end

    if requires_available then
        if skill_state.available ~= nil and skill_state.available ~= true then
            return false, "skill_not_available", meta
        end
    end

    return true, "skill_gate_passed", meta
end

local function collect_phase_candidates(profile, target_distance)
    local candidates = {}
    for _, phase in ipairs(profile.phases or {}) do
        local min_distance = tonumber(phase.min_distance) or 0.0
        local max_distance = tonumber(phase.max_distance)
        local in_range = type(target_distance) == "number" and target_distance >= min_distance
        if in_range and max_distance ~= nil then
            in_range = target_distance <= max_distance
        end
        if in_range then
            candidates[#candidates + 1] = phase
        end
    end

    return candidates
end

local function evaluate_phase_stability_gate(phase)
    local stability = tostring(phase and phase.stability or "stable")
    if stability == "crash_prone" and not crash_prone_skill_phases_enabled() then
        return false, "phase_crash_prone_disabled", {
            phase_stability = stability,
            phase_stability_source = "runtime_phase",
        }
    end

    return true, "phase_stability_passed", {
        phase_stability = stability,
        phase_stability_source = "runtime_phase",
    }
end

local function filter_phase_candidates(candidates, gate_state)
    local allowed = {}
    local blocked = {}

    for _, phase in ipairs(candidates or {}) do
        local stability_ok, stability_reason, stability_meta = evaluate_phase_stability_gate(phase)
        if not stability_ok then
            blocked[#blocked + 1] = {
                key = tostring(phase.key or "nil"),
                reason = tostring(stability_reason or "blocked"),
                mode = tostring(phase.mode or "nil"),
                selection_role = tostring(resolve_phase_selection_role(phase)),
                synthetic_bucket = tostring(resolve_phase_synthetic_bucket(phase)),
                required_skill_name = tostring(phase.required_skill_name or "nil"),
                required_skill_id = tonumber(phase.required_skill_id),
                required_skill_stage = tostring(phase.required_skill_stage or "nil"),
                required_skill_level = nil,
                required_skill_combat_ready = nil,
                required_skill_learned = nil,
                required_skill_equipped = nil,
                required_skill_enabled = nil,
                required_skill_available = nil,
                min_job_level = phase.min_job_level,
                current_job_level = gate_state and gate_state.current_job_level or nil,
                current_job_level_source = gate_state and gate_state.current_job_level_source or "nil",
                execution_contract = phase.execution_contract,
                execution_contract_class = phase.execution_contract_class,
                execution_bridge_mode = phase.execution_bridge_mode,
                probe_mode = tostring(phase.probe_mode or "off"),
                probe_mode_source = stability_meta and stability_meta.phase_stability_source or "runtime_phase",
                action_name = phase.action_name,
                pack_path = phase.pack_path,
            }
        else
        local gate_ok, gate_reason, gate_meta = evaluate_phase_gate(phase, gate_state)
        if gate_ok then
            allowed[#allowed + 1] = phase
        else
            blocked[#blocked + 1] = {
                key = tostring(phase.key or "nil"),
                reason = tostring(gate_reason or "blocked"),
                mode = tostring(phase.mode or "nil"),
                selection_role = tostring(resolve_phase_selection_role(phase)),
                synthetic_bucket = tostring(resolve_phase_synthetic_bucket(phase)),
                required_skill_name = gate_meta and gate_meta.required_skill_name or "nil",
                required_skill_id = gate_meta and gate_meta.required_skill_id or nil,
                required_skill_stage = gate_meta and gate_meta.required_skill_stage or "nil",
                required_skill_level = gate_meta and gate_meta.required_skill_level or nil,
                required_skill_combat_ready = gate_meta and gate_meta.required_skill_combat_ready or nil,
                required_skill_learned = gate_meta and gate_meta.required_skill_learned or nil,
                required_skill_equipped = gate_meta and gate_meta.required_skill_equipped or nil,
                required_skill_enabled = gate_meta and gate_meta.required_skill_enabled or nil,
                required_skill_available = gate_meta and gate_meta.required_skill_available or nil,
                min_job_level = phase.min_job_level,
                current_job_level = gate_meta and gate_meta.current_job_level or nil,
                current_job_level_source = gate_meta and gate_meta.current_job_level_source or "nil",
                execution_contract = phase.execution_contract,
                execution_contract_class = gate_meta and gate_meta.execution_contract_class or phase.execution_contract_class,
                execution_bridge_mode = gate_meta and gate_meta.execution_bridge_mode or phase.execution_bridge_mode,
                probe_mode = gate_meta and gate_meta.probe_mode or "off",
                probe_mode_source = gate_meta and gate_meta.probe_mode_source or "unresolved",
                action_name = phase.action_name,
                pack_path = phase.pack_path,
            }
        end
        end
    end

    return allowed, blocked
end

resolve_phase_selection_role = function(phase)
    return tostring(phase and phase.selection_role or phase and phase.mode or "unknown")
end

resolve_phase_synthetic_bucket = function(phase)
    local explicit_bucket = phase and phase.synthetic_bucket or nil
    if type(explicit_bucket) == "string" and explicit_bucket ~= "" then
        return explicit_bucket
    end

    local role = resolve_phase_selection_role(phase)
    if role == "gapclose" or role == "gapclose_skill" or role == "engage_basic" then
        return "opener"
    end
    if role == "defense_skill" then
        return "defense"
    end
    if role == "ranged_skill" then
        return "ranged"
    end
    if role == "core_advanced" then
        return "burst"
    end
    if role == "basic_attack" or role == "melee_skill" then
        return "sustain"
    end

    return "sustain"
end

local function resolve_combat_stage(data, target_distance, admission_mode, now)
    local distance = tonumber(target_distance)
    local age = data and data.last_apply_time ~= nil
        and math.max(0.0, (tonumber(now) or 0.0) - tonumber(data.last_apply_time))
        or nil
    local last_bucket = tostring(data and data.last_phase_bucket or "nil")
    local last_role = tostring(data and data.last_phase_selection_role or "nil")

    if admission_mode == "synthetic_stall" then
        if age ~= nil
            and age <= 1.6
            and distance ~= nil
            and distance <= 3.75
            and (last_bucket == "opener" or last_bucket == "sustain" or last_role == "engage_basic") then
            return "follow_through"
        end

        return "recovery"
    end

    if admission_mode == "synthetic_initiator" then
        if age ~= nil
            and age <= 1.6
            and distance ~= nil
            and distance <= 3.75
            and (last_bucket == "opener" or last_role == "gapclose" or last_role == "engage_basic") then
            return "follow_through"
        end

        return "initiator"
    end

    return "default"
end

local function is_phase_allowed_for_stage(phase, combat_stage, target_distance)
    if type(phase) ~= "table" or type(combat_stage) ~= "string" or combat_stage == "default" then
        return true, "combat_stage_default"
    end

    local bucket = resolve_phase_synthetic_bucket(phase)
    local distance = tonumber(target_distance)

    if combat_stage == "initiator" then
        if bucket == "opener" or bucket == "defense" then
            return true, "combat_stage_initiator"
        end
        if bucket == "sustain" then
            return distance == nil or distance <= 3.50, "combat_stage_initiator"
        end
        if bucket == "burst" then
            return distance ~= nil and distance <= 3.50, "combat_stage_initiator"
        end
        if bucket == "ranged" then
            return distance == nil or distance >= 2.25, "combat_stage_initiator"
        end
        return true, "combat_stage_initiator"
    end

    if combat_stage == "follow_through" then
        if bucket == "sustain" or bucket == "defense" then
            return true, "combat_stage_follow_through"
        end
        if bucket == "burst" then
            return distance == nil or distance <= 3.75, "combat_stage_follow_through"
        end
        if bucket == "ranged" then
            return distance == nil or distance >= 2.50, "combat_stage_follow_through"
        end
        if bucket == "opener" then
            return distance ~= nil and distance > 4.25, "combat_stage_follow_through"
        end
        return true, "combat_stage_follow_through"
    end

    if combat_stage == "recovery" then
        if bucket == "sustain" or bucket == "defense" then
            return true, "combat_stage_recovery"
        end
        if bucket == "burst" then
            return distance == nil or distance <= 3.25, "combat_stage_recovery"
        end
        if bucket == "ranged" then
            return distance ~= nil and distance >= 2.75, "combat_stage_recovery"
        end
        if bucket == "opener" then
            return distance ~= nil and distance > 4.25, "combat_stage_recovery"
        end
        return true, "combat_stage_recovery"
    end

    return true, "combat_stage_default"
end

local function merge_phase_blocked_lists(primary, secondary)
    local merged = {}
    for _, item in ipairs(primary or {}) do
        merged[#merged + 1] = item
    end
    for _, item in ipairs(secondary or {}) do
        merged[#merged + 1] = item
    end
    return merged
end

local function apply_combat_stage_gate(candidates, combat_stage, target_distance)
    if type(combat_stage) ~= "string" or combat_stage == "default" then
        return candidates or {}, {}, false
    end

    local allowed = {}
    local blocked = {}

    for _, phase in ipairs(candidates or {}) do
        local stage_ok, stage_reason = is_phase_allowed_for_stage(phase, combat_stage, target_distance)
        if stage_ok then
            allowed[#allowed + 1] = phase
        else
            local contract = resolve_phase_execution_contract(phase)
            blocked[#blocked + 1] = {
                key = tostring(phase.key or "nil"),
                reason = tostring(stage_reason or "combat_stage_disallowed"),
                mode = tostring(phase.mode or "nil"),
                selection_role = tostring(resolve_phase_selection_role(phase)),
                synthetic_bucket = tostring(resolve_phase_synthetic_bucket(phase)),
                execution_contract = phase.execution_contract,
                execution_contract_class = phase.execution_contract_class or contract.class,
                execution_bridge_mode = phase.execution_bridge_mode or contract.bridge_mode,
                probe_mode = tostring(phase.probe_mode or "off"),
                probe_mode_source = tostring(phase.probe_mode_source or "combat_stage_gate"),
                min_job_level = phase.min_job_level,
                current_job_level = nil,
                current_job_level_source = "combat_stage_gate",
                action_name = phase.action_name,
                pack_path = phase.pack_path,
            }
        end
    end

    if #allowed == 0 then
        return candidates or {}, blocked, true
    end

    return allowed, blocked, false
end

local function compute_phase_stage_score_bias(bucket, role, combat_stage)
    if combat_stage == "initiator" then
        if bucket == "opener" then
            return 4
        elseif bucket == "sustain" or bucket == "ranged" then
            return 1
        elseif bucket == "burst" then
            return -4
        elseif bucket == "defense" then
            return -1
        end
    elseif combat_stage == "follow_through" then
        if bucket == "sustain" then
            return 6
        elseif bucket == "burst" then
            return 3
        elseif bucket == "defense" then
            return 2
        elseif bucket == "opener" then
            return -8
        elseif bucket == "ranged" then
            return 1
        end
    elseif combat_stage == "recovery" then
        if bucket == "sustain" then
            return 5
        elseif bucket == "defense" then
            return 4
        elseif bucket == "burst" then
            return 2
        elseif bucket == "opener" then
            return -6
        end
    end

    if role == "basic_attack" then
        return 1
    end

    return 0
end

local function compute_phase_distance_fit_bonus(phase, target_distance)
    local distance = tonumber(target_distance)
    local min_distance = tonumber(phase and phase.min_distance)
    local max_distance = tonumber(phase and phase.max_distance)
    if distance == nil or min_distance == nil or max_distance == nil or max_distance < min_distance then
        return 0
    end

    if distance < min_distance or distance > max_distance then
        return -8
    end

    local center = (min_distance + max_distance) * 0.5
    local half_width = math.max(0.05, (max_distance - min_distance) * 0.5)
    local closeness = math.max(0.0, 1.0 - math.abs(distance - center) / half_width)
    return math.floor(closeness * 6 + 0.5)
end

local function compute_phase_sequence_bias(phase, data, target_distance, now, combat_stage)
    if type(data) ~= "table" then
        return 0
    end

    local last_apply_time = tonumber(data.last_apply_time)
    if last_apply_time == nil then
        return 0
    end

    local age = math.max(0.0, (tonumber(now) or 0.0) - last_apply_time)
    if age > 2.0 then
        return 0
    end

    local phase_key = tostring(phase and phase.key or "nil")
    local bucket = resolve_phase_synthetic_bucket(phase)
    local role = resolve_phase_selection_role(phase)
    local last_key = tostring(data.last_phase_key or "nil")
    local last_bucket = tostring(data.last_phase_bucket or "nil")
    local last_role = tostring(data.last_phase_selection_role or "nil")
    local distance = tonumber(target_distance)
    local score = 0

    if phase_key == last_key then
        score = score - 12
    end

    if distance ~= nil and distance <= 3.25 then
        if last_bucket == "opener" then
            if bucket == "sustain" then
                score = score + 10
            elseif bucket == "opener" then
                score = score - 8
            end
        end

        if last_role == "gapclose" or last_role == "engage_basic" then
            if role == "basic_attack" then
                score = score + 10
            elseif bucket == "burst" then
                score = score + 4
            elseif role == "gapclose" or role == "engage_basic" then
                score = score - 6
            end
        end

        if combat_stage == "recovery" then
            if role == "basic_attack" then
                score = score + 8
            elseif role == "gapclose" then
                score = score - 6
            end
        end
    end

    if last_key == "skill_spiral_close" or last_key == "skill_spiral_mid" then
        if bucket == "burst" then
            score = score - 8
        elseif role == "basic_attack" then
            score = score + 6
        end
    end

    if last_key == "core_bind_close" or last_key == "core_bind_mid" then
        if role == "basic_attack" then
            score = score + 8
        elseif phase_key == "skill_spiral_close" or phase_key == "skill_spiral_mid" then
            score = score + 4
        end
    end

    return score
end

local function compute_phase_selection_score(phase, data, target_distance, now, combat_stage)
    local score = tonumber(phase and phase.priority) or 0
    local bucket = resolve_phase_synthetic_bucket(phase)
    local role = resolve_phase_selection_role(phase)

    score = score + compute_phase_stage_score_bias(bucket, role, combat_stage)
    score = score + compute_phase_distance_fit_bonus(phase, target_distance)
    score = score + compute_phase_sequence_bias(phase, data, target_distance, now, combat_stage)

    local contract = resolve_phase_execution_contract(phase)
    if combat_stage == "initiator"
        and (contract.class == "controller_stateful" or contract.class == "selector_owned") then
        score = score - 10
    end

    return score
end

local function sort_allowed_phase_candidates(candidates, gate_state, data, target_distance, now, combat_stage)
    for _, phase in ipairs(candidates or {}) do
        phase.selection_role = resolve_phase_selection_role(phase)
        phase.synthetic_bucket = resolve_phase_synthetic_bucket(phase)
        phase.selection_score = compute_phase_selection_score(phase, data, target_distance, now, combat_stage)
    end

    table.sort(candidates, function(left, right)
        local left_score = tonumber(left.selection_score) or 0
        local right_score = tonumber(right.selection_score) or 0
        if left_score ~= right_score then
            return left_score > right_score
        end

        local left_priority = tonumber(left.priority) or 0
        local right_priority = tonumber(right.priority) or 0
        if left_priority ~= right_priority then
            return left_priority > right_priority
        end

        return tostring(left.key or "") < tostring(right.key or "")
    end)

    return candidates
end

local function describe_phase_candidates(candidates)
    local values = {}
    for _, phase in ipairs(candidates or {}) do
        local contract = resolve_phase_execution_contract(phase)
        values[#values + 1] = string.format(
            "%s:%s:%s:%s:%s:%s:lvl%s:prio%s:score%s",
            tostring(phase.key or "nil"),
            tostring(phase.mode or "nil"),
            tostring(resolve_phase_selection_role(phase)),
            tostring(resolve_phase_synthetic_bucket(phase)),
            tostring(contract.class or "nil"),
            tostring(contract.bridge_mode or "nil"),
            tostring(phase.min_job_level or 0),
            tostring(phase.priority or 0),
            tostring(phase.selection_score or "nil")
        )
    end

    if #values == 0 then
        return "none"
    end

    return table.concat(values, ",")
end

local function describe_blocked_phases(blocked)
    local values = {}
    for _, phase in ipairs(blocked or {}) do
        local contract = resolve_phase_execution_contract(phase)
        values[#values + 1] = string.format(
            "%s:%s:%s:%s:%s:%s:%s:%s:%s:%s",
            tostring(phase.key or "nil"),
            tostring(phase.reason or "blocked"),
            tostring(phase.selection_role or "nil"),
            tostring(phase.synthetic_bucket or "nil"),
            tostring(contract.class or "nil"),
            tostring(phase.probe_mode or "off"),
            tostring(phase.probe_mode_source or "unresolved"),
            tostring(phase.required_skill_name or "nil"),
            tostring(phase.required_skill_stage or "nil"),
            tostring(phase.current_job_level or "nil"),
            tostring(phase.min_job_level or "nil")
        )
    end

    if #values == 0 then
        return "none"
    end

    return table.concat(values, ",")
end

local function apply_phase_summaries(data, selected_phase, allowed_phase_candidates, blocked_phase_candidates, gate_state)
    data.last_allowed_phase_summary = describe_phase_candidates(allowed_phase_candidates)
    data.last_blocked_phase_summary = describe_blocked_phases(blocked_phase_candidates)
    data.last_skill_gate_summary = describe_required_skill_cache(gate_state and gate_state.required_skill_state_cache)
    data.last_selected_phase_note = selected_phase ~= nil and tostring(selected_phase.note or "nil") or "nil"
end

local function describe_attempt_results(results)
    local values = {}
    for _, item in ipairs(results or {}) do
        values[#values + 1] = string.format(
            "%s:%s:%s:%s:%s",
            tostring(item.key or "nil"),
            tostring(item.reason or "nil"),
            tostring(item.bridge or "nil"),
            tostring(item.contract or "nil"),
            tostring(item.bridge_mode or "nil")
        )
    end

    if #values == 0 then
        return "none"
    end

    return table.concat(values, ",")
end

local function build_output_signature(context, target, phase_key)
    return table.concat({
        tostring(context.current_job or "nil"),
        tostring(context.decision_pack_path or "nil"),
        tostring(context.current_action_identity or "nil"),
        tostring(context.selected_request_identity or "nil"),
        tostring(context.full_node or "nil"),
        tostring(context.upper_node or "nil"),
        tostring(util.get_address(target) or "nil"),
        tostring(phase_key or "nil"),
    }, " | ")
end

local function maybe_log_phase_blocked(data, context, gate_state, phase_candidates, blocked_phase_candidates, target_distance)
    local now = tonumber(state.runtime.game_time or os.clock()) or 0.0
    local interval = tonumber(fix_config().phase_blocked_log_interval_seconds) or 5.0
    local signature = table.concat({
        tostring(context.current_job or "nil"),
        tostring(target_distance or "nil"),
        tostring(describe_phase_candidates(phase_candidates)),
        tostring(describe_blocked_phases(blocked_phase_candidates)),
        tostring(describe_required_skill_cache(gate_state and gate_state.required_skill_state_cache)),
        tostring(data.last_output_text_blob or "nil"),
    }, " | ")

    if data.last_phase_block_signature == signature
        and data.last_phase_block_log_time ~= nil
        and (now - data.last_phase_block_log_time) < interval then
        return
    end

    data.last_phase_block_signature = signature
    data.last_phase_block_log_time = now

    log.info(string.format(
        "Hybrid combat fix blocked job=%s profile=%s stage=%s lvl=%s src=%s dist=%s candidates=%s blocked=%s skills=%s output=%s",
        tostring(context.current_job),
        tostring(context.profile and context.profile.key or "nil"),
        tostring(data.last_combat_stage or "nil"),
        tostring(gate_state and gate_state.current_job_level or "nil"),
        tostring(gate_state and gate_state.current_job_level_source or "nil"),
        tostring(target_distance),
        tostring(describe_phase_candidates(phase_candidates)),
        tostring(describe_blocked_phases(blocked_phase_candidates)),
        tostring(describe_required_skill_cache(gate_state and gate_state.required_skill_state_cache)),
        tostring(data.last_output_text_blob or "nil")
    ))
end

local function maybe_log_phase_attempt_failure(data, context, gate_state, attempted_results, blocked_phase_candidates, target_distance)
    local now = tonumber(state.runtime.game_time or os.clock()) or 0.0
    local interval = tonumber(fix_config().phase_blocked_log_interval_seconds) or 5.0
    local signature = table.concat({
        tostring(context.current_job or "nil"),
        tostring(target_distance or "nil"),
        tostring(describe_attempt_results(attempted_results)),
        tostring(describe_blocked_phases(blocked_phase_candidates)),
        tostring(describe_required_skill_cache(gate_state and gate_state.required_skill_state_cache)),
        tostring(data.last_output_text_blob or "nil"),
    }, " | ")

    if data.last_phase_block_signature == signature
        and data.last_phase_block_log_time ~= nil
        and (now - data.last_phase_block_log_time) < interval then
        return
    end

    data.last_phase_block_signature = signature
    data.last_phase_block_log_time = now

    log.warn(string.format(
        "Hybrid combat fix attempted but all phases failed job=%s profile=%s lvl=%s src=%s dist=%s attempts=%s blocked=%s skills=%s output=%s",
        tostring(context.current_job),
        tostring(context.profile and context.profile.key or "nil"),
        tostring(gate_state and gate_state.current_job_level or "nil"),
        tostring(gate_state and gate_state.current_job_level_source or "nil"),
        tostring(target_distance),
        tostring(describe_attempt_results(attempted_results)),
        tostring(describe_blocked_phases(blocked_phase_candidates)),
        tostring(describe_required_skill_cache(gate_state and gate_state.required_skill_state_cache)),
        tostring(data.last_output_text_blob or "nil")
    ))
end

local function should_log_failure(data, reason, now)
    local failure_reason = tostring(reason or "nil")
    if data.last_failure_reason ~= failure_reason then
        data.last_failure_reason = failure_reason
        data.last_failure_log_time = now
        return true
    end

    if data.last_failure_log_time == nil or (now - data.last_failure_log_time) >= 5.0 then
        data.last_failure_log_time = now
        return true
    end

    return false
end

local function maybe_log_observe_only(data, context, target_distance)
    local now = tonumber(state.runtime.game_time or os.clock()) or 0.0
    local interval = tonumber(fix_config().observe_only_log_interval_seconds) or 6.0
    if data.last_observe_only_job == context.current_job
        and data.last_observe_only_log_time ~= nil
        and (now - data.last_observe_only_log_time) < interval then
        return
    end

    data.observe_only_count = data.observe_only_count + 1
    data.last_observe_only_job = context.current_job
    data.last_observe_only_log_time = now
    log.info(string.format(
        "Hybrid combat profile pending job=%s profile=%s current=%s action=%s request=%s node=%s dist=%s",
        tostring(context.current_job),
        tostring(context.profile and context.profile.key or "nil"),
        tostring(context.decision_pack_path or "nil"),
        tostring(context.current_action_identity or "nil"),
        tostring(context.selected_request_identity or "nil"),
        tostring(context.full_node or "nil"),
        tostring(target_distance)
    ))
end

local function resolve_profile_runtime_mode(profile)
    if type(profile) ~= "table" then
        return "observe_only", "profile_unresolved"
    end
    if profile.telemetry_only == true then
        return "observe_only", tostring(profile.pending_reason or "profile_telemetry_only")
    end
    if profile.active ~= true then
        return "observe_only", tostring(profile.pending_reason or "profile_pending_research")
    end
    return "active", nil
end

local function describe_skip_log_extra(extra)
    if type(extra) ~= "table" then
        return tostring(extra or "none")
    end

    local values = {}
    for _, key in ipairs({
        "context_reason",
        "context_resolution_source",
        "context_resolution_reason",
        "context_resolution_age",
        "target_reason",
        "admission_reason",
        "synthetic_admission_mode",
        "recoverable_output_family",
        "synthetic_stall_elapsed",
        "synthetic_stall_window",
        "synthetic_stall_anchor_reason",
        "synthetic_stall_reset_reason",
        "synthetic_backoff_remaining",
        "support_guard_hp_ratio",
        "support_guard_hp_source",
        "support_guard_hp_threshold",
        "support_guard_target_type",
        "support_guard_target_source",
        "support_guard_output",
        "decision_module",
        "ai_blackboard",
        "target",
        "target_game_object",
        "runtime_character",
        "main_pawn",
    }) do
        local value = extra[key]
        if value ~= nil then
            values[#values + 1] = string.format("%s=%s", tostring(key), tostring(value))
        end
    end

    if #values == 0 then
        return "none"
    end

    return table.concat(values, ",")
end

local function maybe_log_skip(data, runtime, context, reason, target_distance, extra)
    if not skip_logging_enabled() then
        return
    end

    if type(extra) ~= "table" then
        extra = {}
    end
    if type(context) == "table" then
        if extra.context_resolution_source == nil then
            extra.context_resolution_source = context.context_resolution_source
        end
        if extra.context_resolution_reason == nil then
            extra.context_resolution_reason = context.context_resolution_reason
        end
        if extra.context_resolution_age == nil then
            extra.context_resolution_age = context.context_resolution_age
        end
    end

    local now = tonumber(runtime and runtime.game_time or os.clock()) or 0.0
    local interval = tonumber(fix_config().skip_log_interval_seconds) or 0.0
    local actor = runtime and main_pawn_properties.get_resolved_main_pawn_data(runtime, "combat_skip_log_main_pawn_data_unresolved") or nil
    local job = context and context.current_job or actor and (actor.current_job or actor.job) or nil
    local profile_key = context and context.profile and context.profile.key or data.last_profile_key or "nil"
    local output_blob = context and build_output_text_blob(context)
        or data.last_output_text_blob
        or table.concat({
            tostring(actor and actor.full_node or "nil"),
            tostring(actor and actor.upper_node or "nil"),
        }, " | ")
    local extra_text = describe_skip_log_extra(extra)
    local signature = table.concat({
        tostring(job or "nil"),
        tostring(profile_key or "nil"),
        tostring(reason or "nil"),
        tostring(target_distance or "nil"),
        tostring(output_blob or "nil"),
        tostring(extra_text or "none"),
    }, " | ")

    if data.last_skip_log_signature == signature
        and data.last_skip_log_time ~= nil
        and (now - data.last_skip_log_time) < interval then
        return
    end

    data.last_skip_log_signature = signature
    data.last_skip_log_time = now

    log.info(string.format(
        "Hybrid combat fix skipped job=%s profile=%s reason=%s dist=%s current=%s action=%s request=%s node=%s upper=%s extra=%s",
        tostring(job or "nil"),
        tostring(profile_key or "nil"),
        tostring(reason or "nil"),
        tostring(target_distance),
        tostring(context and context.decision_pack_path or "nil"),
        tostring(context and context.current_action_identity or "nil"),
        tostring(context and context.selected_request_identity or "nil"),
        tostring(context and context.full_node or actor and actor.full_node or "nil"),
        tostring(context and context.upper_node or actor and actor.upper_node or "nil"),
        tostring(extra_text)
    ))
end

local function maybe_log_target_probes(data, runtime, context, reason, probes)
    if not target_probe_logging_enabled() then
        return
    end

    local now = tonumber(runtime and runtime.game_time or os.clock()) or 0.0
    local interval = tonumber(fix_config().target_source_log_interval_seconds) or 0.0
    local actor = runtime and main_pawn_properties.get_resolved_main_pawn_data(runtime, "combat_target_log_main_pawn_data_unresolved") or nil
    local job = context and context.current_job or actor and (actor.current_job or actor.job) or nil
    local profile_key = context and context.profile and context.profile.key or data.last_profile_key or "nil"
    local probe_text = describe_target_probes(probes)
    local signature = table.concat({
        tostring(job or "nil"),
        tostring(profile_key or "nil"),
        tostring(reason or "nil"),
        tostring(probe_text or "none"),
    }, " | ")

    if data.last_target_probe_log_signature == signature
        and data.last_target_probe_log_time ~= nil
        and (now - data.last_target_probe_log_time) < interval then
        return
    end

    data.last_target_probe_log_signature = signature
    data.last_target_probe_log_time = now

    log.info(string.format(
        "Hybrid combat fix target sources job=%s profile=%s reason=%s probes=%s",
        tostring(job or "nil"),
        tostring(profile_key or "nil"),
        tostring(reason or "nil"),
        tostring(probe_text)
    ))
end

function hybrid_combat_fix.update()
    local runtime = state.runtime
    local data = get_data(runtime)
    if fix_config().enabled ~= true then
        set_status(data, "disabled", "config_disabled")
        return data
    end

    local now = tonumber(runtime and runtime.game_time or os.clock()) or 0.0
    local context, context_reason = resolve_context(runtime)
    local using_stable_context = false
    if context == nil then
        local stable_context, stable_reason = get_stable_context(data, now, context_reason)
        if stable_context ~= nil then
            context = stable_context
            context_reason = stable_reason
            using_stable_context = true
        end
    end
    if context == nil then
        local resolved_actor = main_pawn_properties.get_resolved_main_pawn_data(
            runtime,
            "combat_update_main_pawn_data_unresolved"
        )
        clear_synthetic_stall_state(data, context_reason, now)
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", context_reason)
        maybe_log_skip(data, runtime, nil, context_reason, nil, {
            context_reason = context_reason,
            runtime_character = util.describe_obj(resolved_actor and resolved_actor.runtime_character),
            main_pawn = util.describe_obj(resolved_actor and (resolved_actor.pawn or resolved_actor.runtime_character)),
        })
        return data
    end

    if not using_stable_context then
        context.context_resolution_source = tostring(context.context_resolution_source or "runtime_main_pawn_data")
        context.context_resolution_reason = tostring(context.context_resolution_reason or "resolved")
        context.context_resolution_age = tonumber(context.context_resolution_age) or 0.0
        context = hydrate_bridge_context_from_stable(data, context)
        cache_stable_context(data, context, now)
    end

    if tonumber(data.last_job) ~= tonumber(context.current_job)
        or tostring(data.last_profile_key or "nil") ~= tostring(context.profile and context.profile.key or "nil") then
        clear_phase_failure_quarantine(data)
    end

    data.last_job = context.current_job
    data.last_profile_key = tostring(context.profile and context.profile.key or "nil")
    data.last_output_text_blob = build_output_text_blob(context)

    if has_profile_output(context) then
        data.last_native_output_time = now
        data.last_admission_mode = "native_hybrid_output"
        data.last_admission_family = tostring(get_recoverable_output_family(context, false) or "nil")
        clear_synthetic_stall_state(data, "native_hybrid_output", now)
        set_status(data, "native_hybrid_output", "job_output_already_present")
        return data
    end

    if is_special_skip_output(context) and not is_special_recovery_output(context) then
        clear_synthetic_stall_state(data, "special_output_state", now)
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", "special_output_state")
        maybe_log_skip(data, runtime, context, "special_output_state", nil, {
            target_reason = "special_skip_pre_target",
            special_recovery_output = false,
        })
        return data
    end

    local target_info, target_reason, target_probes = resolve_combat_target(
        context,
        runtime,
        data,
        now,
        target_probe_logging_enabled()
    )
    local target = target_info and target_info.character or nil
    local target_distance = util.is_valid_obj(target) and compute_distance(context.runtime_character, target) or nil
    local special_recovery_allowed = false

    if is_special_skip_output(context) then
        special_recovery_allowed = is_special_recovery_output(context)
            and has_usable_enemy_target(target_info, context.runtime_character, runtime and runtime.player)

        if not special_recovery_allowed then
            clear_synthetic_stall_state(data, "special_output_state", now)
            data.skip_count = data.skip_count + 1
            set_status(data, "skipped", "special_output_state")
            maybe_log_skip(data, runtime, context, "special_output_state", target_distance, {
                target_reason = target_reason,
                target = util.describe_obj(target),
                special_recovery_output = is_special_recovery_output(context),
            })
            maybe_log_target_probes(data, runtime, context, "special_output_state", target_probes)
            return data
        end
    end

    local profile_runtime_mode, profile_runtime_reason = resolve_profile_runtime_mode(context.profile)
    if profile_runtime_mode ~= "active" then
        clear_synthetic_stall_state(data, profile_runtime_reason or "profile_pending_research", now)
        set_status(data, "observe_only", profile_runtime_reason or "profile_pending_research")
        maybe_log_observe_only(data, context, target_distance)
        return data
    end

    if not util.is_valid_obj(context.decision_module) or not util.is_valid_obj(context.ai_blackboard) then
        clear_synthetic_stall_state(data, "decision_bridge_context_unresolved", now)
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", "decision_bridge_context_unresolved")
        maybe_log_skip(data, runtime, context, "decision_bridge_context_unresolved", target_distance, {
            decision_module = util.describe_obj(context.decision_module),
            ai_blackboard = util.describe_obj(context.ai_blackboard),
        })
        return data
    end

    if type(target_info) ~= "table" or not util.is_valid_obj(target) then
        clear_synthetic_stall_state(data, target_reason, now)
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", target_reason)
        maybe_log_skip(data, runtime, context, target_reason, target_distance, {
            target_reason = target_reason,
            target = util.describe_obj(target),
        })
        maybe_log_target_probes(data, runtime, context, target_reason, target_probes)
        return data
    end

    local target_prepare_reason = nil
    target_info, target_prepare_reason = prepare_target_info_for_bridge(data, context, runtime, target_info, now)
    if target_info ~= nil then
        target = target_info.character
        target_distance = util.is_valid_obj(target) and compute_distance(context.runtime_character, target) or nil
    end

    if not util.is_valid_obj(target_info.game_object) then
        clear_synthetic_stall_state(data, target_prepare_reason or "target_game_object_unresolved", now)
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", target_prepare_reason or "target_game_object_unresolved")
        maybe_log_skip(data, runtime, context, "target_game_object_unresolved", target_distance, {
            target = util.describe_obj(target),
            target_game_object = util.describe_obj(target_info.game_object),
            target_reason = target_prepare_reason,
        })
        maybe_log_target_probes(data, runtime, context, "target_game_object_unresolved", target_probes)
        return data
    end

    if is_invalid_target_identity(context.runtime_character, target, runtime.player) then
        clear_synthetic_stall_state(data, "invalid_target_identity", now)
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", "invalid_target_identity")
        maybe_log_skip(data, runtime, context, "invalid_target_identity", target_distance, {
            target = util.describe_obj(target),
            runtime_character = util.describe_obj(context.runtime_character),
        })
        maybe_log_target_probes(data, runtime, context, "invalid_target_identity", target_probes)
        return data
    end

    local bridge_admission_mode, admission_meta = resolve_bridge_admission_mode(
        data,
        context,
        runtime,
        target_info,
        now,
        special_recovery_allowed
    )

    local support_recovery_guard, support_guard_meta = evaluate_support_recovery_guard(context)
    if support_recovery_guard and bridge_admission_mode == "synthetic_initiator" then
        local support_guard_reason = support_guard_meta and support_guard_meta.reason or "support_recovery_guard_active"
        clear_synthetic_stall_state(data, support_guard_reason, now)
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", support_guard_reason)
        maybe_log_skip(data, runtime, context, support_guard_reason, target_distance, support_guard_meta)
        return data
    end

    data.last_admission_mode = tostring(bridge_admission_mode or "nil")
    data.last_admission_family = tostring(admission_meta and admission_meta.recoverable_output_family or "nil")

    if bridge_admission_mode == nil then
        local admission_reason = admission_meta and admission_meta.reason or "output_not_in_confirmed_bridge_window"
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", admission_reason)
        maybe_log_skip(data, runtime, context, admission_reason, target_distance, admission_meta)
        return data
    end

    local gate_state = build_skill_gate_state(runtime, context)
    local phase_candidates = collect_phase_candidates(context.profile, target_distance)
    local allowed_phase_candidates, blocked_phase_candidates = filter_phase_candidates(phase_candidates, gate_state)
    local combat_stage = resolve_combat_stage(data, target_distance, bridge_admission_mode, now)
    local stage_allowed_phase_candidates, stage_blocked_phase_candidates, stage_gate_fallback = apply_combat_stage_gate(
        allowed_phase_candidates,
        combat_stage,
        target_distance
    )
    data.last_combat_stage = stage_gate_fallback
        and string.format("%s:fallback_all", tostring(combat_stage))
        or tostring(combat_stage)
    if not stage_gate_fallback then
        allowed_phase_candidates = stage_allowed_phase_candidates
        blocked_phase_candidates = merge_phase_blocked_lists(blocked_phase_candidates, stage_blocked_phase_candidates)
    end
    local selected_phase = nil
    local bridge_info = nil
    local attempted_results = {}
    if #allowed_phase_candidates > 0 then
        allowed_phase_candidates = sort_allowed_phase_candidates(
            allowed_phase_candidates,
            gate_state,
            data,
            target_distance,
            now,
            combat_stage
        )
    end
    apply_phase_summaries(data, nil, allowed_phase_candidates, blocked_phase_candidates, gate_state)

    if #allowed_phase_candidates == 0 then
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", #blocked_phase_candidates > 0 and "phase_blocked" or "phase_unresolved")
        if #phase_candidates > 0 then
            maybe_log_phase_blocked(data, context, gate_state, phase_candidates, blocked_phase_candidates, target_distance)
        end
        return data
    end

    for _, phase_entry in ipairs(allowed_phase_candidates) do
        local phase_key = tostring(phase_entry.key or "nil")
        local output_signature = build_output_signature(context, target, phase_entry.key)
        local cooldown_seconds = tonumber(phase_entry.cooldown_seconds) or tonumber(fix_config().cooldown_seconds) or 2.5
        local quarantine_entry = get_phase_failure_quarantine(data, phase_key, now)

        if quarantine_entry ~= nil then
            attempted_results[#attempted_results + 1] = {
                key = phase_key,
                reason = string.format(
                    "failure_quarantine_active:%s:%.2f",
                    tostring(quarantine_entry.reason or "phase_bridge_failed"),
                    math.max(0.0, quarantine_entry.until_time - now)
                ),
                bridge = "skipped",
                contract = tostring(phase_entry.execution_contract_class or "nil"),
                bridge_mode = tostring(phase_entry.execution_bridge_mode or "nil"),
            }
        elseif data.last_output_signature == output_signature
            and data.last_apply_time ~= nil
            and (now - data.last_apply_time) < cooldown_seconds then
            attempted_results[#attempted_results + 1] = {
                key = phase_key,
                reason = "cooldown_active",
                bridge = "skipped",
                contract = tostring(phase_entry.execution_contract_class or "nil"),
                bridge_mode = tostring(phase_entry.execution_bridge_mode or "nil"),
            }
        else
            local bridge_ok, candidate_bridge_info = apply_phase_bridge(data, context, phase_entry, target_info, target_distance)
            attempted_results[#attempted_results + 1] = {
                key = phase_key,
                reason = tostring(candidate_bridge_info and candidate_bridge_info.reason or "phase_bridge_failed"),
                bridge = tostring(candidate_bridge_info and candidate_bridge_info.bridge_kind or "nil"),
                contract = tostring(candidate_bridge_info and candidate_bridge_info.execution_contract_class or phase_entry.execution_contract_class or "nil"),
                bridge_mode = tostring(candidate_bridge_info and candidate_bridge_info.execution_bridge_mode or phase_entry.execution_bridge_mode or "nil"),
            }

            if bridge_ok then
                selected_phase = phase_entry
                bridge_info = candidate_bridge_info
                data.last_output_signature = output_signature
                data.phase_failure_quarantine[phase_key] = nil
                break
            elseif tostring(candidate_bridge_info and candidate_bridge_info.bridge_kind or "nil") ~= "skipped" then
                set_phase_failure_quarantine(
                    data,
                    phase_key,
                    candidate_bridge_info and candidate_bridge_info.reason or "phase_bridge_failed",
                    now
                )
            end
        end
    end

    data.last_attempt_summary = describe_attempt_results(attempted_results)
    apply_phase_summaries(data, selected_phase, allowed_phase_candidates, blocked_phase_candidates, gate_state)

    if selected_phase == nil then
        local had_bridge_failure = false
        local had_attempt_skip = false
        for _, item in ipairs(attempted_results) do
            if item.bridge == "hybrid_failed" then
                had_bridge_failure = true
            elseif item.bridge == "skipped" then
                had_attempt_skip = true
            end
        end

        if had_bridge_failure then
            data.fail_count = data.fail_count + 1
            set_status(data, "failed", "all_allowed_phase_bridges_failed")
            maybe_log_phase_attempt_failure(data, context, gate_state, attempted_results, blocked_phase_candidates, target_distance)
        else
            data.skip_count = data.skip_count + 1
            set_status(data, "skipped", had_attempt_skip and "phase_attempts_skipped" or "phase_bridge_unresolved")
        end
        return data
    end

    if not (bridge_info and tostring(bridge_info.reason or "ok") == "ok") then
        data.fail_count = data.fail_count + 1
        set_status(data, "failed", bridge_info and bridge_info.reason or "phase_bridge_failed")
        if should_log_failure(data, data.last_reason, now) then
            log.warn(string.format(
                "Hybrid combat fix failed job=%s profile=%s phase=%s contract=%s bridge_mode=%s reason=%s pack=%s action=%s current=%s target=%s attempts=%s",
                tostring(context.current_job),
                tostring(context.profile.key),
                tostring(selected_phase.key),
                tostring(bridge_info and bridge_info.execution_contract_class or selected_phase.execution_contract_class or "nil"),
                tostring(bridge_info and bridge_info.execution_bridge_mode or selected_phase.execution_bridge_mode or "nil"),
                tostring(data.last_reason),
                tostring(bridge_info and bridge_info.pack_path or selected_phase.pack_path or "nil"),
                tostring(bridge_info and bridge_info.action_name or selected_phase.action_name or "nil"),
                tostring(context.decision_pack_path or "nil"),
                tostring(util.describe_obj(target)),
                tostring(data.last_attempt_summary)
            ))
        end
        return data
    end

    data.apply_count = data.apply_count + 1
    data.last_apply_time = now
    data.last_phase_key = tostring(selected_phase.key or "nil")
    data.last_phase_mode = tostring(selected_phase.mode or "nil")
    data.last_phase_selection_role = tostring(selected_phase.selection_role or resolve_phase_selection_role(selected_phase))
    data.last_phase_bucket = tostring(selected_phase.synthetic_bucket or resolve_phase_synthetic_bucket(selected_phase))
    data.last_execution_contract_class = tostring(bridge_info and bridge_info.execution_contract_class or selected_phase.execution_contract_class or "nil")
    data.last_execution_bridge_mode = tostring(bridge_info and bridge_info.execution_bridge_mode or selected_phase.execution_bridge_mode or "nil")
    data.last_pack_path = tostring(bridge_info and bridge_info.pack_path or selected_phase.pack_path or "nil")
    data.last_action_name = tostring(bridge_info and bridge_info.action_name or selected_phase.action_name or "nil")
    data.last_target = util.describe_obj(target)
    data.last_target_type = util.get_type_full_name(target) or "nil"
    data.last_target_distance = target_distance
    clear_synthetic_stall_state(data, "bridge_applied", now)
    set_status(
        data,
        "applied",
        bridge_admission_mode == "synthetic_initiator"
            and "synthetic_initiator_output_bridged_to_hybrid_profile"
            or bridge_admission_mode == "synthetic_stall"
            and "synthetic_stall_output_bridged_to_hybrid_profile"
            or "hybrid_output_bridged_to_hybrid_profile"
    )

    log.info(string.format(
        "Hybrid combat fix applied job=%s profile=%s phase=%s mode=%s admission=%s stage=%s family=%s contract=%s bridge_mode=%s lvl=%s src=%s pack=%s action=%s current=%s dist=%s target=%s allowed=%s blocked=%s attempts=%s skills=%s",
        tostring(context.current_job),
        tostring(context.profile.key),
        tostring(selected_phase.key),
        tostring(selected_phase.mode or "nil"),
        tostring(bridge_admission_mode or "nil"),
        tostring(data.last_combat_stage or "nil"),
        tostring(data.last_admission_family or "nil"),
        tostring(data.last_execution_contract_class or "nil"),
        tostring(data.last_execution_bridge_mode or "nil"),
        tostring(gate_state.current_job_level),
        tostring(gate_state.current_job_level_source or "nil"),
        tostring(bridge_info and bridge_info.pack_path or selected_phase.pack_path or "nil"),
        tostring(bridge_info and bridge_info.action_name or selected_phase.action_name or "nil"),
        tostring(context.decision_pack_path or "nil"),
        tostring(target_distance),
        tostring(data.last_target),
        tostring(describe_phase_candidates(allowed_phase_candidates)),
        tostring(describe_blocked_phases(blocked_phase_candidates)),
        tostring(data.last_attempt_summary),
        tostring(data.last_skill_gate_summary ~= "none" and data.last_skill_gate_summary or describe_skill_ids(gate_state.equipped_skill_ids))
    ))

    return data
end

return hybrid_combat_fix

-- Purpose:
-- Capture a timed burst of target-publication state for main_pawn.
-- This complements main_pawn_target_surface_screen.lua by sampling transitions over time,
-- so combat-like stalls can be separated from utility or talking transitions
-- even when they look identical by eye in-game.
--
-- Output:
--   reframework/data/ce_dump/main_pawn_target_publication_burst_<job>_<trace_label>_<timestamp>.json

local GLOBAL_KEY = "__main_pawn_target_publication_burst_state_v1"
local TRACE_LABEL = "main_pawn_target_publication_auto"
local EXPECTED_JOB = nil
local SAMPLE_INTERVAL_SECONDS = 0.4
local DURATION_SECONDS = 12.0
local MAX_SAMPLES = 30
local COLLECTION_SAMPLE_LIMIT = 3
local MAX_MAIN_DECISION_SCAN = 40

local CHARACTER_COMPONENT_TYPE = sdk.typeof("app.Character")

local MAIN_DECISIONS_FIELDS = {
    "<MainDecisions>k__BackingField", "_MainDecisions", "MainDecisions",
}
local MAIN_DECISIONS_METHODS = {
    "get_MainDecisions()",
}
local TARGET_FIELDS = {
    "<Target>k__BackingField", "_Target", "Target", "CurrentTarget", "AttackTarget", "LockOnTarget", "OrderTarget",
}
local TARGET_METHODS = {
    "get_Target()", "get_CurrentTarget()", "get_AttackTarget()", "get_LockOnTarget()", "get_OrderTarget()",
}
local CHARACTER_FIELDS = {
    "<Character>k__BackingField", "<OwnerCharacter>k__BackingField", "<TargetCharacter>k__BackingField",
    "<CachedCharacter>k__BackingField", "Character", "OwnerCharacter", "TargetCharacter", "CachedCharacter", "TargetChara", "Chara",
}
local CHARACTER_METHODS = {
    "get_Character()", "get_OwnerCharacter()", "get_TargetCharacter()", "get_Chara()",
}
local GAMEOBJECT_FIELDS = {
    "<GameObject>k__BackingField", "_GameObject", "GameObject", "<Obj>k__BackingField", "Obj", "<Owner>k__BackingField", "_Owner", "Owner",
}
local GAMEOBJECT_METHODS = {
    "get_GameObject()", "get_Owner()",
}
local ACTION_PACK_FIELDS = {
    "<ActionPackData>k__BackingField", "_ActionPackData", "ActionPackData", "<ActInterPackData>k__BackingField", "_ActInterPackData", "ActInterPackData",
    "<PackData>k__BackingField", "_PackData", "PackData", "<ActionPack>k__BackingField", "_ActionPack", "ActionPack",
}
local ACTION_PACK_METHODS = {
    "get_ActionPackData()", "get_ActInterPackData()", "get_PackData()", "get_ActionPack()",
}

local function try_eval(fn)
    local ok, value = pcall(fn)
    return ok, value
end

local function round3(value)
    local number = tonumber(value) or 0.0
    return math.floor(number * 1000 + 0.5) / 1000
end

local function is_present(value)
    return value ~= nil and tostring(value) ~= "nil"
end

local function describe(value)
    if value == nil then
        return "nil"
    end

    local value_type = type(value)
    if value_type == "userdata" then
        return tostring(value)
    end
    if value_type == "table" then
        return "<table>"
    end

    return tostring(value)
end

local function get_type_name(obj)
    if obj == nil then
        return "nil"
    end

    local ok, value = try_eval(function()
        return obj:get_type_definition():get_full_name()
    end)
    if ok and value ~= nil then
        return tostring(value)
    end

    return type(obj)
end

local function serialize_object(value, source)
    return {
        present = is_present(value),
        description = describe(value),
        type_name = get_type_name(value),
        source = source or "unresolved",
    }
end

local function serialize_scalar(value, source)
    return {
        present = value ~= nil,
        description = describe(value),
        type_name = type(value),
        source = source or "unresolved",
        value = value,
    }
end

local function contains_text(value, needle)
    if value == nil or needle == nil then
        return false
    end

    return string.find(string.lower(tostring(value)), string.lower(tostring(needle)), 1, true) ~= nil
end

local function contains_any_text(value, needles)
    for _, needle in ipairs(needles or {}) do
        if contains_text(value, needle) then
            return true
        end
    end
    return false
end

local function bump(counter, key)
    local normalized = tostring(key or "nil")
    counter[normalized] = (counter[normalized] or 0) + 1
end

local function sorted_counter_keys(counter)
    local keys = {}
    for key, _ in pairs(counter or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function counter_keys(counter)
    local result = {}
    for _, key in ipairs(sorted_counter_keys(counter)) do
        result[#result + 1] = key
    end
    return result
end

local function safe_call_method0(obj, methods)
    if obj == nil then
        return nil, "root_nil"
    end

    for _, method_name in ipairs(methods or {}) do
        local ok, value = try_eval(function()
            return obj:call(method_name)
        end)
        if ok then
            return value, method_name
        end
    end

    return nil, "unresolved"
end

local function safe_call_method1(obj, methods, arg1)
    if obj == nil then
        return nil, "root_nil"
    end

    for _, method_name in ipairs(methods or {}) do
        local ok, value = try_eval(function()
            return obj:call(method_name, arg1)
        end)
        if ok then
            return value, method_name
        end
    end

    return nil, "unresolved"
end

local function safe_field(obj, fields)
    if obj == nil then
        return nil, "root_nil"
    end

    for _, field_name in ipairs(fields or {}) do
        local ok, value = try_eval(function()
            return obj[field_name]
        end)
        if ok then
            return value, field_name
        end
    end

    return nil, "unresolved"
end

local function safe_reflect_field(obj, fields)
    if obj == nil then
        return nil, "root_nil"
    end

    local ok_td, td = try_eval(function()
        return obj:get_type_definition()
    end)
    if not ok_td or td == nil then
        return nil, "type_definition_unresolved"
    end

    local ok_fields, reflected_fields = try_eval(function()
        return td:get_fields()
    end)
    if not ok_fields or reflected_fields == nil then
        return nil, "fields_unresolved"
    end

    for _, wanted_name in ipairs(fields or {}) do
        for _, field in ipairs(reflected_fields) do
            local ok_name, field_name = try_eval(function()
                return field:get_name()
            end)
            if ok_name and tostring(field_name) == tostring(wanted_name) then
                local ok_value, value = try_eval(function()
                    return field:get_data(obj)
                end)
                if ok_value then
                    return value, "reflect:" .. tostring(wanted_name)
                end
            end
        end
    end

    return nil, "unresolved"
end

local function safe_named_field(obj, fields)
    local value, source = safe_field(obj, fields)
    if is_present(value) then
        return value, source
    end

    local reflected_value, reflected_source = safe_reflect_field(obj, fields)
    if reflected_value ~= nil then
        return reflected_value, reflected_source
    end

    return value, source
end

local function safe_present_field(obj, fields)
    local last_source = "unresolved"
    for _, field_name in ipairs(fields or {}) do
        local value, source = safe_named_field(obj, { field_name })
        last_source = source
        if is_present(value) then
            return value, source
        end
    end

    return nil, last_source
end

local function resolve_string_field_or_method(obj, fields, methods)
    local field_value, field_source = safe_present_field(obj, fields)
    if type(field_value) == "string" then
        return field_value, field_source
    end
    if field_value ~= nil then
        local text = tostring(field_value)
        if text ~= "nil" then
            return text, field_source
        end
    end

    local method_value, method_source = safe_call_method0(obj, methods)
    if type(method_value) == "string" then
        return method_value, method_source
    end
    if method_value ~= nil then
        local text = tostring(method_value)
        if text ~= "nil" then
            return text, method_source
        end
    end

    return nil, "unresolved"
end

local function get_collection_count(obj)
    local count, count_source = safe_call_method0(obj, {
        "get_Count()",
        "get_count()",
        "get_Size()",
        "get_size()",
    })
    if count ~= nil then
        return tonumber(count), count_source
    end

    local field_count, field_count_source = safe_named_field(obj, {
        "Count",
        "count",
        "_size",
        "size",
    })
    if field_count ~= nil then
        return tonumber(field_count), field_count_source
    end

    return nil, "unresolved"
end

local function get_collection_item(obj, index)
    return safe_call_method1(obj, {
        "get_Item(System.Int32)",
        "get_Item(System.UInt32)",
        "get_Item",
    }, index)
end

local function resolve_main_pawn()
    local character_manager = sdk.get_managed_singleton("app.CharacterManager")
    local pawn_manager = sdk.get_managed_singleton("app.PawnManager")
    local candidates = {
        { source = "PawnManager:get_MainPawn()", value = function() return pawn_manager:call("get_MainPawn()") end },
        { source = "PawnManager._MainPawn", value = function() return pawn_manager["_MainPawn"] end },
        { source = "PawnManager.<MainPawn>k__BackingField", value = function() return pawn_manager["<MainPawn>k__BackingField"] end },
        { source = "CharacterManager:get_MainPawn()", value = function() return character_manager:call("get_MainPawn()") end },
        { source = "CharacterManager.<MainPawn>k__BackingField", value = function() return character_manager["<MainPawn>k__BackingField"] end },
        { source = "CharacterManager:get_ManualPlayerPawn()", value = function() return character_manager:call("get_ManualPlayerPawn()") end },
        { source = "CharacterManager:get_ManualPlayerMainPawn()", value = function() return character_manager:call("get_ManualPlayerMainPawn()") end },
    }

    for _, candidate in ipairs(candidates) do
        local ok, value = try_eval(candidate.value)
        if ok and is_present(value) then
            return value, candidate.source
        end
    end

    return nil, "unresolved"
end

local function resolve_runtime_character(main_pawn)
    if main_pawn == nil then
        return nil, "main_pawn_nil"
    end
    if get_type_name(main_pawn) == "app.Character" then
        return main_pawn, "main_pawn_is_character"
    end

    local value, source = safe_call_method0(main_pawn, {
        "get_CachedCharacter()",
        "get_Character()",
        "get_Chara()",
        "get_PawnCharacter()",
    })
    if is_present(value) then
        return value, source
    end

    local field_value, field_source = safe_named_field(main_pawn, {
        "<CachedCharacter>k__BackingField", "<Character>k__BackingField", "<Chara>k__BackingField", "Character", "Chara",
    })
    if is_present(field_value) then
        return field_value, field_source
    end

    return nil, "unresolved"
end

local function resolve_player()
    local character_manager = sdk.get_managed_singleton("app.CharacterManager")
    local player, source = safe_named_field(character_manager, {
        "<ManualPlayer>k__BackingField", "_ManualPlayer",
    })
    if is_present(player) then
        return player, source
    end

    return safe_call_method0(character_manager, { "get_ManualPlayer()" })
end

local function resolve_current_job(human, runtime_character)
    local current_job, current_job_source = safe_named_field(human, {
        "<CurrentJob>k__BackingField", "CurrentJob",
    })
    if current_job ~= nil then
        return current_job, current_job_source
    end

    local job_context, job_context_source = safe_named_field(human, {
        "<JobContext>k__BackingField", "JobContext",
    })
    if is_present(job_context) then
        local context_job, context_job_source = safe_named_field(job_context, { "CurrentJob" })
        if context_job ~= nil then
            return context_job, "job_context:" .. tostring(context_job_source)
        end
        return nil, "job_context:" .. tostring(job_context_source)
    end

    return safe_call_method0(runtime_character, { "get_CurrentJob()", "get_Job()" })
end

local function resolve_game_object(source)
    if source == nil then
        return nil, "source_nil"
    end
    if get_type_name(source) == "via.GameObject" then
        return source, "direct"
    end

    local field_value, field_source = safe_named_field(source, GAMEOBJECT_FIELDS)
    if is_present(field_value) then
        return field_value, "field:" .. tostring(field_source)
    end

    local method_value, method_source = safe_call_method0(source, GAMEOBJECT_METHODS)
    if is_present(method_value) then
        return method_value, "method:" .. tostring(method_source)
    end

    return nil, "unresolved"
end

local function resolve_character_candidate(source)
    if source == nil then
        return nil, "source_nil"
    end
    if get_type_name(source) == "app.Character" then
        return source, "direct_character"
    end

    local field_value, field_source = safe_named_field(source, CHARACTER_FIELDS)
    if is_present(field_value) then
        return field_value, "field:" .. tostring(field_source)
    end

    local method_value, method_source = safe_call_method0(source, CHARACTER_METHODS)
    if is_present(method_value) then
        return method_value, "method:" .. tostring(method_source)
    end

    local game_object, game_object_source = resolve_game_object(source)
    if is_present(game_object) and CHARACTER_COMPONENT_TYPE ~= nil then
        local component, component_source = safe_call_method1(game_object, {
            "getComponent(System.Type)",
            "getComponent",
        }, CHARACTER_COMPONENT_TYPE)
        if is_present(component) then
            return component, "component:" .. tostring(game_object_source) .. ":" .. tostring(component_source)
        end
    end

    return nil, "unresolved"
end

local function classify_identity(runtime_character, player, candidate)
    if not is_present(candidate) then
        return "none"
    end
    if runtime_character ~= nil and tostring(candidate) == tostring(runtime_character) then
        return "self"
    end
    if player ~= nil and tostring(candidate) == tostring(player) then
        return "player"
    end
    return "other"
end

local function resolve_target_like(root)
    if not is_present(root) then
        return nil, "root_nil"
    end

    local type_name = get_type_name(root)
    if type_name == "app.AITargetGameObject" or type_name == "app.Character" or type_name == "via.GameObject" then
        return root, "root_direct"
    end

    local field_value, field_source = safe_named_field(root, TARGET_FIELDS)
    if is_present(field_value) then
        return field_value, "field:" .. tostring(field_source)
    end

    local method_value, method_source = safe_call_method0(root, TARGET_METHODS)
    if is_present(method_value) then
        return method_value, "method:" .. tostring(method_source)
    end

    return nil, "target_unresolved"
end

local function capture_target_probe(label, root, runtime_character, player)
    local target_like, target_like_source = resolve_target_like(root)
    local probe_target = is_present(target_like) and target_like or root
    local probe_source = is_present(target_like) and target_like_source or "root_direct"
    local chosen_character, chosen_source = resolve_character_candidate(probe_target)
    local chosen_identity = classify_identity(runtime_character, player, chosen_character)
    local game_object, game_object_source = resolve_game_object(probe_target)

    return {
        label = label,
        root = serialize_object(root, label .. ":root"),
        target_like = serialize_object(target_like, target_like_source),
        probe_target = serialize_object(probe_target, probe_source),
        chosen_character = serialize_object(chosen_character, chosen_source),
        chosen_identity = chosen_identity,
        game_object = serialize_object(game_object, game_object_source),
    }
end

local function capture_collection_probe(field_name, root, runtime_character, player)
    local collection, collection_source = safe_named_field(root, { field_name })
    local count, count_source = get_collection_count(collection)
    local limit = math.min(tonumber(count) or 0, COLLECTION_SAMPLE_LIMIT)
    local entries = {}
    local first_other_index = nil
    local other_count = 0

    for index = 0, limit - 1 do
        local item, item_source = get_collection_item(collection, index)
        local target_like, target_like_source = resolve_target_like(item)
        local probe_target = is_present(target_like) and target_like or item
        local probe_source = is_present(target_like) and target_like_source or "item_direct"
        local chosen_character, chosen_source = resolve_character_candidate(probe_target)
        local chosen_identity = classify_identity(runtime_character, player, chosen_character)
        local game_object, game_object_source = resolve_game_object(probe_target)

        if chosen_identity == "other" then
            other_count = other_count + 1
            if first_other_index == nil then
                first_other_index = index
            end
        end

        entries[#entries + 1] = {
            index = index,
            item = serialize_object(item, item_source),
            probe_target = serialize_object(probe_target, probe_source),
            chosen_character = serialize_object(chosen_character, chosen_source),
            chosen_identity = chosen_identity,
            game_object = serialize_object(game_object, game_object_source),
        }
    end

    return {
        field_name = field_name,
        collection = serialize_object(collection, collection_source),
        count = serialize_scalar(count, count_source),
        other_count = other_count,
        first_other_index = first_other_index,
        entries = entries,
    }
end

local function capture_pack_identity(root, root_source)
    local pack_object, pack_object_source = safe_present_field(root, ACTION_PACK_FIELDS)
    if not is_present(pack_object) then
        pack_object, pack_object_source = safe_call_method0(root, ACTION_PACK_METHODS)
    end

    local target = is_present(pack_object) and pack_object or root
    local path, path_source = resolve_string_field_or_method(target, { "<Path>k__BackingField", "_Path", "Path" }, { "get_Path()" })
    local name, name_source = resolve_string_field_or_method(target, { "<Name>k__BackingField", "_Name", "Name" }, { "get_Name()" })
    local identity = path or name or describe(target)

    return {
        object = serialize_object(root, root_source),
        pack_object = serialize_object(pack_object, pack_object_source),
        path = serialize_scalar(path, path_source),
        name = serialize_scalar(name, name_source),
        identity = identity,
    }
end

local function contains_attackish_text(value)
    return contains_any_text(value, {
        "attack",
        "slash",
        "stab",
        "dash",
        "heavy",
        "blink",
        "fullmoon",
        "violent",
        "guard",
    })
end

local function is_generic_attack_identity(identity)
    return contains_text(identity, "/genericjob/") and contains_attackish_text(identity)
end

local function is_job_pack_identity(identity, current_job_number)
    if current_job_number == nil then
        return false
    end

    return contains_text(identity, string.format("job%02d", current_job_number))
end

local function is_utility_identity(identity)
    return contains_any_text(identity, {
        "/common/",
        "/ch1/",
        "movetoposition",
        "moveapproach",
        "keepdistance",
        "drawweapon",
        "carry",
        "cling",
        "talk",
    })
end

local function analyze_main_decisions(decision_module, current_job_number)
    local list_obj, list_source = safe_named_field(decision_module, MAIN_DECISIONS_FIELDS)
    if not is_present(list_obj) then
        list_obj, list_source = safe_call_method0(decision_module, MAIN_DECISIONS_METHODS)
    end

    local count, count_source = get_collection_count(list_obj)
    local scanned_items = 0
    local total_pack_count = 0
    local current_job_pack_count = 0
    local generic_attack_pack_count = 0
    local attackish_pack_count = 0
    local utility_pack_count = 0
    local pack_identity_counts = {}
    local current_job_pack_identity_counts = {}
    local generic_attack_identity_counts = {}
    local utility_identity_counts = {}

    if count ~= nil then
        local max_items = math.min(tonumber(count) or 0, MAX_MAIN_DECISION_SCAN)
        for index = 0, max_items - 1 do
            local item, item_source = get_collection_item(list_obj, index)
            local pack_capture = capture_pack_identity(item, item_source)
            local identity = tostring(pack_capture.identity or "nil")

            scanned_items = scanned_items + 1
            if pack_capture.pack_object.present then
                total_pack_count = total_pack_count + 1
                bump(pack_identity_counts, identity)

                if is_job_pack_identity(identity, current_job_number) then
                    current_job_pack_count = current_job_pack_count + 1
                    bump(current_job_pack_identity_counts, identity)
                end
                if is_generic_attack_identity(identity) then
                    generic_attack_pack_count = generic_attack_pack_count + 1
                    bump(generic_attack_identity_counts, identity)
                end
                if contains_attackish_text(identity) then
                    attackish_pack_count = attackish_pack_count + 1
                end
                if is_utility_identity(identity) then
                    utility_pack_count = utility_pack_count + 1
                    bump(utility_identity_counts, identity)
                end
            end
        end
    end

    local population_mode = "population_unresolved"
    if count ~= nil then
        if total_pack_count == 0 then
            population_mode = "no_pack_population"
        elseif current_job_pack_count > 0 or generic_attack_pack_count > 0 or attackish_pack_count > 0 then
            population_mode = "attack_populated"
        elseif utility_pack_count > 0 then
            population_mode = "utility_only_population"
        else
            population_mode = "other_nonattack_population"
        end
    end

    return {
        collection = serialize_object(list_obj, list_source),
        count = serialize_scalar(count, count_source),
        scanned_items = scanned_items,
        total_pack_count = total_pack_count,
        current_job_pack_count = current_job_pack_count,
        generic_attack_pack_count = generic_attack_pack_count,
        attackish_pack_count = attackish_pack_count,
        utility_pack_count = utility_pack_count,
        population_mode = population_mode,
        pack_identities = counter_keys(pack_identity_counts),
        current_job_pack_identities = counter_keys(current_job_pack_identity_counts),
        generic_attack_pack_identities = counter_keys(generic_attack_identity_counts),
        utility_pack_identities = counter_keys(utility_identity_counts),
    }
end

local function get_fsm_node_name(action_manager, layer_index)
    local fsm, fsm_source = safe_named_field(action_manager, { "Fsm" })
    if not is_present(fsm) then
        return nil, "fsm:" .. tostring(fsm_source)
    end

    local node_name, node_source = safe_call_method1(fsm, {
        "getCurrentNodeName(System.UInt32)",
        "getCurrentNodeName",
    }, layer_index)
    if type(node_name) == "string" then
        return node_name, "fsm:" .. tostring(node_source)
    end
    if node_name ~= nil then
        return tostring(node_name), "fsm:" .. tostring(node_source)
    end

    return nil, "fsm_unresolved"
end

local function classify_output_mode(current_job_number, decision_pack_path, full_node, current_action_identity, selected_request_identity)
    local texts = {
        decision_pack_path,
        full_node,
        current_action_identity,
        selected_request_identity,
    }

    if current_job_number ~= nil then
        local token = string.format("job%02d", current_job_number)
        for _, text in ipairs(texts) do
            if contains_text(text, token) then
                return "job_specific_output_candidate"
            end
        end
    end

    for _, text in ipairs(texts) do
        if contains_any_text(text, { "talk", "highfive", "hightfive", "humanturn_target_talking" }) then
            return "talking_or_special_output"
        end
    end

    for _, text in ipairs(texts) do
        if contains_text(text, "/genericjob/") and contains_any_text(text, { "attack", "slash", "stab", "dash", "heavy" }) then
            return "generic_attack_output_candidate"
        end
    end

    for _, text in ipairs(texts) do
        if contains_any_text(text, { "/common/", "/ch1/", "movetoposition", "moveapproach", "keepdistance", "drawweapon", "carry", "talk" }) then
            return "common_utility_output"
        end
    end

    return "output_unresolved"
end

local function classify_publication_mode(executing_decision_probe, enemy_list_probe, front_target_probe, in_camera_probe, sensor_probe)
    if executing_decision_probe.chosen_identity == "other" then
        return "executing_decision_other", "executing_decision"
    end
    if enemy_list_probe.first_other_index ~= nil then
        return "enemy_list_other", "enemy_list"
    end
    if front_target_probe.first_other_index ~= nil then
        return "front_target_list_other", "front_target_list"
    end
    if in_camera_probe.first_other_index ~= nil then
        return "in_camera_target_list_other", "in_camera_target_list"
    end
    if sensor_probe.first_other_index ~= nil then
        return "sensor_hit_result_other", "sensor_hit_result"
    end

    local enemy_count = tonumber(enemy_list_probe.count.value) or 0
    local front_count = tonumber(front_target_probe.count.value) or 0
    local camera_count = tonumber(in_camera_probe.count.value) or 0
    local sensor_count = tonumber(sensor_probe.count.value) or 0
    local total_count = enemy_count + front_count + camera_count + sensor_count

    if executing_decision_probe.chosen_identity == "self" then
        if sensor_count > 0 and enemy_count == 0 and front_count == 0 and camera_count == 0 then
            return "executing_decision_self_sensor_only", "executing_decision"
        end
        if total_count > 0 then
            return "executing_decision_self_with_collections", "executing_decision"
        end
        return "executing_decision_self_no_collections", "executing_decision"
    end

    if sensor_count > 0 and enemy_count == 0 and front_count == 0 and camera_count == 0 then
        return "sensor_only_no_enemy", "sensor_hit_result"
    end
    if total_count > 0 then
        return "collections_populated_no_enemy", "collections"
    end

    return "no_target_signal", "none"
end

local function capture_sample(now, started_at, recorder)
    local main_pawn, main_pawn_source = resolve_main_pawn()
    local runtime_character, runtime_character_source = resolve_runtime_character(main_pawn)
    local player, player_source = resolve_player()
    local human, human_source = safe_call_method0(runtime_character, { "get_Human()" })
    local action_manager, action_manager_source = safe_call_method0(runtime_character, { "get_ActionManager()" })
    local current_job, current_job_source = resolve_current_job(human, runtime_character)
    local current_job_number = tonumber(current_job)

    local ai_blackboard, ai_blackboard_source = safe_call_method0(runtime_character, { "get_AIBlackBoardController()" })
    local decision_maker, decision_maker_source = safe_named_field(runtime_character, { "<AIDecisionMaker>k__BackingField", "AIDecisionMaker" })
    if not is_present(decision_maker) then
        decision_maker, decision_maker_source = safe_call_method0(runtime_character, { "get_AIDecisionMaker()" })
    end

    local decision_module, decision_module_source = safe_named_field(decision_maker, { "<DecisionModule>k__BackingField", "DecisionModule" })
    if not is_present(decision_module) then
        decision_module, decision_module_source = safe_call_method0(decision_maker, { "get_DecisionModule()" })
    end

    local decision_executor, decision_executor_source = safe_named_field(decision_module, { "<DecisionExecutor>k__BackingField", "DecisionExecutor" })
    if not is_present(decision_executor) then
        decision_executor, decision_executor_source = safe_call_method0(decision_module, { "get_DecisionExecutor()" })
    end

    local executing_decision, executing_decision_source = safe_named_field(decision_executor, { "<ExecutingDecision>k__BackingField", "ExecutingDecision" })
    if not is_present(executing_decision) then
        executing_decision, executing_decision_source = safe_call_method0(decision_executor, { "get_ExecutingDecision()" })
    end

    local ai_meta_controller, ai_meta_controller_source = safe_named_field(ai_blackboard, { "<AIMetaController>k__BackingField", "AIMetaController" })
    local order_target_controller, order_target_controller_source = safe_named_field(ai_meta_controller, { "<CachedPawnOrderTargetController>k__BackingField", "CachedPawnOrderTargetController" })
    local selected_request, selected_request_source = safe_named_field(action_manager, { "SelectedRequest" })
    local current_action, current_action_source = safe_named_field(action_manager, { "CurrentAction" })

    local executing_decision_probe = capture_target_probe("executing_decision", executing_decision, runtime_character, player)
    local enemy_list_probe = capture_collection_probe("_EnemyList", order_target_controller, runtime_character, player)
    local front_target_probe = capture_collection_probe("_FrontTargetList", order_target_controller, runtime_character, player)
    local in_camera_probe = capture_collection_probe("_InCameraTargetList", order_target_controller, runtime_character, player)
    local sensor_probe = capture_collection_probe("_SensorHitResult", order_target_controller, runtime_character, player)

    local publication_mode, preferred_source = classify_publication_mode(
        executing_decision_probe,
        enemy_list_probe,
        front_target_probe,
        in_camera_probe,
        sensor_probe
    )

    local decision_pack_path, decision_pack_path_source = resolve_string_field_or_method(executing_decision, { "<Path>k__BackingField", "_Path", "Path" }, { "get_Path()" })
    if decision_pack_path == nil then
        decision_pack_path, decision_pack_path_source = resolve_string_field_or_method(decision_module, { "_ExecuteActInter", "<ExecuteActInter>k__BackingField" }, { "get_ExecuteActInter()" })
    end
    local full_node, full_node_source = get_fsm_node_name(action_manager, 0)
    local upper_node, upper_node_source = get_fsm_node_name(action_manager, 1)
    local current_action_capture = capture_pack_identity(current_action, current_action_source)
    local selected_request_capture = capture_pack_identity(selected_request, selected_request_source)
    local main_decisions = analyze_main_decisions(decision_module, current_job_number)
    local output_mode = classify_output_mode(
        current_job_number,
        decision_pack_path,
        full_node,
        current_action_capture.identity,
        selected_request_capture.identity
    )

    local signature = table.concat({
        tostring(current_job_number or "job_nil"),
        tostring(publication_mode),
        tostring(preferred_source),
        tostring(main_decisions.population_mode or "population_mode_nil"),
        tostring(output_mode),
        tostring(full_node or "full_node_nil"),
    }, " | ")

    return {
        elapsed_seconds = round3(now - started_at),
        current_job = serialize_scalar(current_job, current_job_source),
        unexpected_job = recorder.expected_job ~= nil and current_job_number ~= nil and current_job_number ~= tonumber(recorder.expected_job),
        actor = {
            main_pawn = serialize_object(main_pawn, main_pawn_source),
            runtime_character = serialize_object(runtime_character, runtime_character_source),
            player = serialize_object(player, player_source),
            human = serialize_object(human, human_source),
            action_manager = serialize_object(action_manager, action_manager_source),
            ai_blackboard = serialize_object(ai_blackboard, ai_blackboard_source),
            ai_meta_controller = serialize_object(ai_meta_controller, ai_meta_controller_source),
            order_target_controller = serialize_object(order_target_controller, order_target_controller_source),
        },
        decision_chain = {
            decision_maker = serialize_object(decision_maker, decision_maker_source),
            decision_module = serialize_object(decision_module, decision_module_source),
            decision_executor = serialize_object(decision_executor, decision_executor_source),
            executing_decision = serialize_object(executing_decision, executing_decision_source),
        },
        main_decisions = main_decisions,
        target = {
            publication_mode = publication_mode,
            preferred_source = preferred_source,
            executing_decision = executing_decision_probe,
            enemy_list = enemy_list_probe,
            front_target_list = front_target_probe,
            in_camera_target_list = in_camera_probe,
            sensor_hit_result = sensor_probe,
        },
        output = {
            decision_pack_path = serialize_scalar(decision_pack_path, decision_pack_path_source),
            full_node = serialize_scalar(full_node, full_node_source),
            upper_node = serialize_scalar(upper_node, upper_node_source),
            current_action = current_action_capture,
            selected_request = selected_request_capture,
            output_mode = output_mode,
        },
        signature = signature,
    }
end

local function get_observed_job_suffix(samples)
    local counts = {}
    for _, sample in ipairs(samples or {}) do
        local value = tonumber(sample.current_job.value)
        local key = value ~= nil and string.format("job%02d", value) or "job_unknown"
        counts[key] = (counts[key] or 0) + 1
    end

    local best_key = "job_unknown"
    local best_count = -1
    for key, count in pairs(counts) do
        if count > best_count then
            best_key = key
            best_count = count
        end
    end
    return best_key
end

local function build_summary(samples, recorder, finish_reason)
    local publication_modes = {}
    local preferred_sources = {}
    local output_modes = {}
    local main_decision_population_modes = {}
    local current_jobs = {}
    local full_nodes = {}
    local upper_nodes = {}
    local selected_request_identities = {}
    local current_action_identities = {}
    local transitions = {}
    local previous_signature = nil

    for index, sample in ipairs(samples or {}) do
        bump(publication_modes, sample.target.publication_mode)
        bump(preferred_sources, sample.target.preferred_source)
        bump(output_modes, sample.output.output_mode)
        bump(main_decision_population_modes, sample.main_decisions.population_mode)
        bump(current_jobs, sample.current_job.value)
        bump(full_nodes, sample.output.full_node.value)
        bump(upper_nodes, sample.output.upper_node.value)
        bump(selected_request_identities, sample.output.selected_request.identity)
        bump(current_action_identities, sample.output.current_action.identity)

        if previous_signature ~= nil and previous_signature ~= sample.signature then
            transitions[#transitions + 1] = {
                sample_index = index,
                elapsed_seconds = sample.elapsed_seconds,
                from_signature = previous_signature,
                to_signature = sample.signature,
            }
        end
        previous_signature = sample.signature
    end

    return {
        trace_label = recorder.trace_label,
        expected_job = recorder.expected_job,
        finish_reason = finish_reason,
        sample_count = #(samples or {}),
        publication_modes = publication_modes,
        preferred_sources = preferred_sources,
        output_modes = output_modes,
        main_decision_population_modes = main_decision_population_modes,
        current_jobs = current_jobs,
        full_nodes = full_nodes,
        upper_nodes = upper_nodes,
        selected_request_identities = selected_request_identities,
        current_action_identities = current_action_identities,
        transitions = transitions,
    }
end

local state = rawget(_G, GLOBAL_KEY) or { hook_installed = false, recorder = nil, last_output_path = nil }
rawset(_G, GLOBAL_KEY, state)

local function finalize_recorder(reason)
    local recorder = state.recorder
    if recorder == nil then
        return nil
    end

    local output = {
        tag = "main_pawn_target_publication_burst",
        generated_at = os.date("%Y-%m-%d %H:%M:%S"),
        config = {
            trace_label = recorder.trace_label,
            expected_job = recorder.expected_job,
            sample_interval_seconds = recorder.sample_interval_seconds,
            duration_seconds = recorder.duration_seconds,
            max_samples = recorder.max_samples,
            collection_sample_limit = COLLECTION_SAMPLE_LIMIT,
            max_main_decision_scan = MAX_MAIN_DECISION_SCAN,
        },
        started_at = recorder.started_at_real,
        summary = build_summary(recorder.samples, recorder, reason),
        samples = recorder.samples,
    }

    local output_path = string.format(
        "ce_dump/main_pawn_target_publication_burst_%s_%s_%s.json",
        tostring(get_observed_job_suffix(recorder.samples)),
        tostring(recorder.trace_label),
        os.date("%Y%m%d_%H%M%S")
    )
    json.dump_file(output_path, output)
    state.last_output_path = output_path
    state.recorder = nil
    print("[main_pawn_target_publication_burst] wrote " .. output_path)
    return output_path
end

if not state.hook_installed then
    re.on_application_entry("LateUpdateBehavior", function()
        local recorder = state.recorder
        if recorder == nil then
            return
        end

        local now = tonumber(os.clock()) or 0.0
        if recorder.started_at == nil then
            recorder.started_at = now
            recorder.next_sample_at = now
        end

        while recorder.next_sample_at ~= nil and now >= recorder.next_sample_at and #recorder.samples < recorder.max_samples do
            recorder.samples[#recorder.samples + 1] = capture_sample(now, recorder.started_at, recorder)
            recorder.next_sample_at = recorder.next_sample_at + recorder.sample_interval_seconds
        end

        if (now - recorder.started_at) >= recorder.duration_seconds or #recorder.samples >= recorder.max_samples then
            finalize_recorder(#recorder.samples >= recorder.max_samples and "max_samples_reached" or "duration_elapsed")
        end
    end)
    state.hook_installed = true
end

if state.recorder ~= nil then
    finalize_recorder("restarted")
end

state.recorder = {
    trace_label = TRACE_LABEL,
    expected_job = EXPECTED_JOB,
    started_at = nil,
    next_sample_at = nil,
    started_at_real = os.date("%Y-%m-%d %H:%M:%S"),
    sample_interval_seconds = SAMPLE_INTERVAL_SECONDS,
    duration_seconds = DURATION_SECONDS,
    max_samples = MAX_SAMPLES,
    samples = {},
}

print(string.format(
    "[main_pawn_target_publication_burst] started trace=%s expected_job=%s interval=%.2fs duration=%.2fs max_samples=%d",
    tostring(TRACE_LABEL),
    tostring(EXPECTED_JOB),
    SAMPLE_INTERVAL_SECONDS,
    DURATION_SECONDS,
    MAX_SAMPLES
))
print("[main_pawn_target_publication_burst] keep playing; result will be written to ce_dump automatically")
return "main_pawn_target_publication_burst_started"

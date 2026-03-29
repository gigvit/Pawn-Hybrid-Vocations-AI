-- Purpose:
-- Dump current main_pawn output/admission classifications and token matches.
-- Output:
--   reframework/data/ce_dump/main_pawn_output_classification_screen_job<job>_<timestamp>.json

local COLLECTION_SAMPLE_LIMIT = 3

local UTILITY_TOKENS = { "/common/", "/ch1/", "movetoposition", "moveapproach", "keepdistance", "strafe", "locomotion.", "normallocomotion", "drawweapon" }
local DAMAGE_RECOVERY_TOKENS = { "dmgshrink", "damage.damage_root.dmgshrink" }
local SPECIAL_SKIP_TOKENS = { "talk", "greeting", "highfive", "lookat", "sortitem", "treasurebox", "carry", "cling", "catch", "winbattle" }
local SPECIAL_RECOVERY_TOKENS = { "humanturn_target_talking" }
local ATTACKISH_TOKENS = { "attack", "slash", "stab", "dash", "heavy", "blink", "fullmoon", "violent", "guard" }

local CHARACTER_COMPONENT_TYPE = sdk.typeof("app.Character")

local function try_eval(fn) local ok, value = pcall(fn); return ok, value end
local function is_present(v) return v ~= nil and tostring(v) ~= "nil" end
local function describe(v) if v == nil then return "nil" end local t = type(v); if t == "userdata" then return tostring(v) end if t == "table" then return "<table>" end return tostring(v) end
local function get_type_name(v) if v == nil then return "nil" end local ok, value = try_eval(function() return v:get_type_definition():get_full_name() end); if ok and value ~= nil then return tostring(value) end return type(v) end
local function ser_obj(v, source) return { present = is_present(v), description = describe(v), type_name = get_type_name(v), source = source or "unresolved" } end
local function ser_scalar(v, source) return { present = v ~= nil, description = describe(v), type_name = type(v), source = source or "unresolved", value = v } end

local function contains_text(value, needle)
    if value == nil or needle == nil then return false end
    return string.find(string.lower(tostring(value)), string.lower(tostring(needle)), 1, true) ~= nil
end

local function contains_any_text(value, needles)
    for _, needle in ipairs(needles or {}) do
        if contains_text(value, needle) then return true end
    end
    return false
end

local function match_tokens(value, needles)
    local matches = {}
    for _, needle in ipairs(needles or {}) do
        if contains_text(value, needle) then matches[#matches + 1] = needle end
    end
    return matches
end

local function call0(obj, methods)
    if obj == nil then return nil, "root_nil" end
    for _, method_name in ipairs(methods or {}) do
        local ok, value = try_eval(function() return obj:call(method_name) end)
        if ok then return value, method_name end
    end
    return nil, "unresolved"
end

local function call1(obj, methods, arg1)
    if obj == nil then return nil, "root_nil" end
    for _, method_name in ipairs(methods or {}) do
        local ok, value = try_eval(function() return obj:call(method_name, arg1) end)
        if ok then return value, method_name end
    end
    return nil, "unresolved"
end

local function field(obj, fields)
    if obj == nil then return nil, "root_nil" end
    for _, field_name in ipairs(fields or {}) do
        local ok, value = try_eval(function() return obj[field_name] end)
        if ok then return value, field_name end
    end
    return nil, "unresolved"
end

local function first_present(obj, fields)
    local last_source = "unresolved"
    for _, field_name in ipairs(fields or {}) do
        local value, source = field(obj, { field_name })
        last_source = source
        if is_present(value) then return value, source end
    end
    return nil, last_source
end

local function resolve_string(obj, fields, methods)
    local value, source = first_present(obj, fields or {})
    if type(value) == "string" then return value, source end
    if value ~= nil and tostring(value) ~= "nil" then return tostring(value), source end
    value, source = call0(obj, methods or {})
    if type(value) == "string" then return value, source end
    if value ~= nil and tostring(value) ~= "nil" then return tostring(value), source end
    return nil, "unresolved"
end

local function get_count(obj)
    local count, source = call0(obj, { "get_Count()", "get_count()", "get_Size()", "get_size()" })
    if count ~= nil then return tonumber(count), source end
    count, source = field(obj, { "Count", "count", "_size", "size" })
    if count ~= nil then return tonumber(count), source end
    return nil, "unresolved"
end

local function get_item(obj, index)
    return call1(obj, { "get_Item(System.Int32)", "get_Item(System.UInt32)", "get_Item" }, index)
end

local function resolve_main_pawn()
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    local pm = sdk.get_managed_singleton("app.PawnManager")
    local candidates = {
        { "PawnManager:get_MainPawn()", function() return pm:call("get_MainPawn()") end },
        { "PawnManager._MainPawn", function() return pm["_MainPawn"] end },
        { "CharacterManager:get_MainPawn()", function() return cm:call("get_MainPawn()") end },
        { "CharacterManager.<MainPawn>k__BackingField", function() return cm["<MainPawn>k__BackingField"] end },
        { "CharacterManager:get_ManualPlayerMainPawn()", function() return cm:call("get_ManualPlayerMainPawn()") end },
    }
    for _, candidate in ipairs(candidates) do
        local ok, value = try_eval(candidate[2])
        if ok and is_present(value) then return value, candidate[1] end
    end
    return nil, "unresolved"
end

local function resolve_runtime_character(main_pawn)
    if main_pawn == nil then return nil, "main_pawn_nil" end
    if get_type_name(main_pawn) == "app.Character" then return main_pawn, "main_pawn_is_character" end
    local value, source = call0(main_pawn, { "get_CachedCharacter()", "get_Character()", "get_Chara()", "get_PawnCharacter()" })
    if is_present(value) then return value, source end
    value, source = field(main_pawn, { "<CachedCharacter>k__BackingField", "<Character>k__BackingField", "<Chara>k__BackingField", "Character", "Chara" })
    if is_present(value) then return value, source end
    return nil, "unresolved"
end

local function resolve_current_job(human, runtime_character)
    local value, source = field(human, { "<CurrentJob>k__BackingField", "CurrentJob" })
    if value ~= nil then return value, source end
    local job_context = select(1, field(human, { "<JobContext>k__BackingField", "JobContext" }))
    if is_present(job_context) then
        value, source = field(job_context, { "CurrentJob" })
        if value ~= nil then return value, "job_context:" .. tostring(source) end
    end
    return call0(runtime_character, { "get_CurrentJob()", "get_Job()" })
end

local function resolve_game_object(source)
    if source == nil then return nil, "source_nil" end
    if get_type_name(source) == "via.GameObject" then return source, "direct" end
    local value, src = field(source, { "<GameObject>k__BackingField", "_GameObject", "GameObject", "<Obj>k__BackingField", "Obj", "<Owner>k__BackingField", "_Owner", "Owner" })
    if is_present(value) then return value, "field:" .. tostring(src) end
    value, src = call0(source, { "get_GameObject()", "get_Owner()" })
    if is_present(value) then return value, "method:" .. tostring(src) end
    return nil, "unresolved"
end

local function resolve_character(source)
    if source == nil then return nil, "source_nil" end
    if get_type_name(source) == "app.Character" then return source, "direct_character" end
    local value, src = field(source, { "<Character>k__BackingField", "<OwnerCharacter>k__BackingField", "<TargetCharacter>k__BackingField", "<CachedCharacter>k__BackingField", "Character", "OwnerCharacter", "TargetCharacter", "CachedCharacter", "TargetChara", "Chara" })
    if is_present(value) then return value, "field:" .. tostring(src) end
    value, src = call0(source, { "get_Character()", "get_OwnerCharacter()", "get_TargetCharacter()", "get_Chara()" })
    if is_present(value) then return value, "method:" .. tostring(src) end
    local game_object, game_object_source = resolve_game_object(source)
    if is_present(game_object) and CHARACTER_COMPONENT_TYPE ~= nil then
        value, src = call1(game_object, { "getComponent(System.Type)", "getComponent" }, CHARACTER_COMPONENT_TYPE)
        if is_present(value) then return value, "component:" .. tostring(game_object_source) .. ":" .. tostring(src) end
    end
    return nil, "unresolved"
end

local function classify_identity(runtime_character, player, candidate)
    if not is_present(candidate) then return "none" end
    if runtime_character ~= nil and tostring(candidate) == tostring(runtime_character) then return "self" end
    if player ~= nil and tostring(candidate) == tostring(player) then return "player" end
    return "other"
end

local function resolve_target_like(root)
    if not is_present(root) then return nil, "root_nil" end
    local type_name = get_type_name(root)
    if type_name == "app.AITargetGameObject" or type_name == "app.Character" or type_name == "via.GameObject" then return root, "root_direct" end
    local value, src = field(root, { "<Target>k__BackingField", "_Target", "Target", "CurrentTarget", "AttackTarget", "LockOnTarget", "OrderTarget" })
    if is_present(value) then return value, "field:" .. tostring(src) end
    value, src = call0(root, { "get_Target()", "get_CurrentTarget()", "get_AttackTarget()", "get_LockOnTarget()", "get_OrderTarget()" })
    if is_present(value) then return value, "method:" .. tostring(src) end
    return nil, "target_unresolved"
end

local function probe_target(label, root, runtime_character, player)
    local target_like, target_like_source = resolve_target_like(root)
    local probe_target = is_present(target_like) and target_like or root
    local chosen_character, chosen_source = resolve_character(probe_target)
    return {
        label = label,
        root = ser_obj(root, label .. ":root"),
        target_like = ser_obj(target_like, target_like_source),
        probe_target = ser_obj(probe_target, target_like_source),
        chosen_character = ser_obj(chosen_character, chosen_source),
        chosen_identity = classify_identity(runtime_character, player, chosen_character),
        game_object = ser_obj(resolve_game_object(probe_target)),
    }
end

local function probe_collection(field_name, root, runtime_character, player)
    local collection, collection_source = field(root, { field_name })
    local count, count_source = get_count(collection)
    local entries, first_other_index = {}, nil
    for index = 0, math.min(tonumber(count) or 0, COLLECTION_SAMPLE_LIMIT) - 1 do
        local item, item_source = get_item(collection, index)
        local target_like, target_like_source = resolve_target_like(item)
        local probe_target = is_present(target_like) and target_like or item
        local chosen_character, chosen_source = resolve_character(probe_target)
        local chosen_identity = classify_identity(runtime_character, player, chosen_character)
        if chosen_identity == "other" and first_other_index == nil then first_other_index = index end
        entries[#entries + 1] = {
            index = index,
            item = ser_obj(item, item_source),
            probe_target = ser_obj(probe_target, target_like_source),
            chosen_character = ser_obj(chosen_character, chosen_source),
            chosen_identity = chosen_identity,
        }
    end
    return { field_name = field_name, collection = ser_obj(collection, collection_source), count = ser_scalar(count, count_source), first_other_index = first_other_index, entries = entries }
end

local function capture_pack(root, root_source)
    local pack_object, pack_source = first_present(root, { "<ActionPackData>k__BackingField", "_ActionPackData", "ActionPackData", "<ActInterPackData>k__BackingField", "_ActInterPackData", "ActInterPackData", "<PackData>k__BackingField", "_PackData", "PackData", "<ActionPack>k__BackingField", "_ActionPack", "ActionPack" })
    if not is_present(pack_object) then pack_object, pack_source = call0(root, { "get_ActionPackData()", "get_ActInterPackData()", "get_PackData()", "get_ActionPack()" }) end
    local target = is_present(pack_object) and pack_object or root
    local path, path_source = resolve_string(target, { "<Path>k__BackingField", "_Path", "Path" }, { "get_Path()" })
    local name, name_source = resolve_string(target, { "<Name>k__BackingField", "_Name", "Name" }, { "get_Name()" })
    return { object = ser_obj(root, root_source), pack_object = ser_obj(pack_object, pack_source), path = ser_scalar(path, path_source), name = ser_scalar(name, name_source), identity = path or name or describe(target) }
end

local function get_node(action_manager, layer_index)
    local fsm, fsm_source = field(action_manager, { "Fsm" })
    if not is_present(fsm) then return nil, "fsm:" .. tostring(fsm_source) end
    local node_name, node_source = call1(fsm, { "getCurrentNodeName(System.UInt32)", "getCurrentNodeName" }, layer_index)
    if node_name ~= nil then return tostring(node_name), "fsm:" .. tostring(node_source) end
    return nil, "fsm_unresolved"
end

local function contains_attackish_text(value) return contains_any_text(value, ATTACKISH_TOKENS) end

local function classify_output_mode(current_job_number, decision_pack_path, full_node, current_action_identity, selected_request_identity)
    local texts = { decision_pack_path, full_node, current_action_identity, selected_request_identity }
    if current_job_number ~= nil then
        local token = string.format("job%02d", current_job_number)
        for _, text in ipairs(texts) do if contains_text(text, token) then return "job_specific_output_candidate" end end
    end
    for _, text in ipairs(texts) do if contains_any_text(text, { "talk", "highfive", "hightfive", "humanturn_target_talking" }) then return "talking_or_special_output" end end
    for _, text in ipairs(texts) do if contains_text(text, "/genericjob/") and contains_attackish_text(text) then return "generic_attack_output_candidate" end end
    for _, text in ipairs(texts) do if contains_any_text(text, { "/common/", "/ch1/", "movetoposition", "moveapproach", "keepdistance", "drawweapon", "carry", "talk" }) then return "common_utility_output" end end
    return "output_unresolved"
end

local function compute_family(raw_matches, special_recovery_allowed, utility_first)
    if special_recovery_allowed == true then return "special_recovery" end
    if utility_first == true then
        if #raw_matches.utility > 0 then return "utility" end
        if #raw_matches.damage_recovery > 0 then return "damage_recovery" end
        return nil
    end
    if #raw_matches.damage_recovery > 0 then return "damage_recovery" end
    if #raw_matches.utility > 0 then return "utility" end
    return nil
end

local main_pawn, main_pawn_source = resolve_main_pawn()
local runtime_character, runtime_character_source = resolve_runtime_character(main_pawn)
local cm = sdk.get_managed_singleton("app.CharacterManager")
local player = select(1, field(cm, { "<ManualPlayer>k__BackingField", "_ManualPlayer" })) or select(1, call0(cm, { "get_ManualPlayer()" }))
local human, human_source = call0(runtime_character, { "get_Human()" })
local action_manager, action_manager_source = call0(runtime_character, { "get_ActionManager()" })
local current_job, current_job_source = resolve_current_job(human, runtime_character)
local current_job_number = tonumber(current_job)
local ai_blackboard, ai_blackboard_source = call0(runtime_character, { "get_AIBlackBoardController()" })
local decision_maker, decision_maker_source = field(runtime_character, { "<AIDecisionMaker>k__BackingField", "AIDecisionMaker" }); if not is_present(decision_maker) then decision_maker, decision_maker_source = call0(runtime_character, { "get_AIDecisionMaker()" }) end
local decision_module, decision_module_source = field(decision_maker, { "<DecisionModule>k__BackingField", "DecisionModule" }); if not is_present(decision_module) then decision_module, decision_module_source = call0(decision_maker, { "get_DecisionModule()" }) end
local decision_executor, decision_executor_source = field(decision_module, { "<DecisionExecutor>k__BackingField", "DecisionExecutor" }); if not is_present(decision_executor) then decision_executor, decision_executor_source = call0(decision_module, { "get_DecisionExecutor()" }) end
local executing_decision, executing_decision_source = field(decision_executor, { "<ExecutingDecision>k__BackingField", "ExecutingDecision" }); if not is_present(executing_decision) then executing_decision, executing_decision_source = call0(decision_executor, { "get_ExecutingDecision()" }) end
local ai_meta_controller, ai_meta_controller_source = field(ai_blackboard, { "<AIMetaController>k__BackingField", "AIMetaController" })
local order_target_controller, order_target_controller_source = field(ai_meta_controller, { "<CachedPawnOrderTargetController>k__BackingField", "CachedPawnOrderTargetController" })
local selected_request, selected_request_source = field(action_manager, { "SelectedRequest" })
local current_action, current_action_source = field(action_manager, { "CurrentAction" })

local executing_decision_probe = probe_target("executing_decision", executing_decision, runtime_character, player)
local enemy_list_probe = probe_collection("_EnemyList", order_target_controller, runtime_character, player)
local front_target_probe = probe_collection("_FrontTargetList", order_target_controller, runtime_character, player)
local in_camera_probe = probe_collection("_InCameraTargetList", order_target_controller, runtime_character, player)
local sensor_probe = probe_collection("_SensorHitResult", order_target_controller, runtime_character, player)

local publication_mode, preferred_source = "no_target_signal", "none"
if executing_decision_probe.chosen_identity == "other" then publication_mode, preferred_source = "executing_decision_other", "executing_decision"
elseif enemy_list_probe.first_other_index ~= nil then publication_mode, preferred_source = "enemy_list_other", "enemy_list"
elseif front_target_probe.first_other_index ~= nil then publication_mode, preferred_source = "front_target_list_other", "front_target_list"
elseif in_camera_probe.first_other_index ~= nil then publication_mode, preferred_source = "in_camera_target_list_other", "in_camera_target_list"
elseif sensor_probe.first_other_index ~= nil then publication_mode, preferred_source = "sensor_hit_result_other", "sensor_hit_result" end

local decision_pack_path, decision_pack_path_source = resolve_string(executing_decision, { "<Path>k__BackingField", "_Path", "Path" }, { "get_Path()" })
if decision_pack_path == nil then decision_pack_path, decision_pack_path_source = resolve_string(decision_module, { "_ExecuteActInter", "<ExecuteActInter>k__BackingField" }, { "get_ExecuteActInter()" }) end
local full_node, full_node_source = get_node(action_manager, 0)
local upper_node, upper_node_source = get_node(action_manager, 1)
local current_action_capture = capture_pack(current_action, current_action_source)
local selected_request_capture = capture_pack(selected_request, selected_request_source)
local output_mode = classify_output_mode(current_job_number, decision_pack_path, full_node, current_action_capture.identity, selected_request_capture.identity)

local output_texts = { tostring(decision_pack_path or "nil"), tostring(current_action_capture.identity or "nil"), tostring(selected_request_capture.identity or "nil"), tostring(full_node or "nil"), tostring(upper_node or "nil") }
local output_text_blob = table.concat(output_texts, " | ")
local raw_matches = {
    utility = match_tokens(output_text_blob, UTILITY_TOKENS),
    damage_recovery = match_tokens(output_text_blob, DAMAGE_RECOVERY_TOKENS),
    special_skip = match_tokens(output_text_blob, SPECIAL_SKIP_TOKENS),
    special_recovery = match_tokens(output_text_blob, SPECIAL_RECOVERY_TOKENS),
    generic_attackish = match_tokens(output_text_blob, ATTACKISH_TOKENS),
}
local special_recovery_allowed = #raw_matches.special_recovery > 0 and preferred_source ~= "none"

local payload = {
    tag = "main_pawn_output_classification_screen",
    generated_at = os.date("%Y-%m-%d %H:%M:%S"),
    actor = {
        main_pawn = ser_obj(main_pawn, main_pawn_source),
        runtime_character = ser_obj(runtime_character, runtime_character_source),
        human = ser_obj(human, human_source),
        action_manager = ser_obj(action_manager, action_manager_source),
        ai_blackboard = ser_obj(ai_blackboard, ai_blackboard_source),
        ai_meta_controller = ser_obj(ai_meta_controller, ai_meta_controller_source),
        order_target_controller = ser_obj(order_target_controller, order_target_controller_source),
        current_job = ser_scalar(current_job, current_job_source),
    },
    decision_chain = {
        decision_maker = ser_obj(decision_maker, decision_maker_source),
        decision_module = ser_obj(decision_module, decision_module_source),
        decision_executor = ser_obj(decision_executor, decision_executor_source),
        executing_decision = ser_obj(executing_decision, executing_decision_source),
    },
    target = {
        publication_mode = publication_mode,
        preferred_source = preferred_source,
        usable_enemy_target = preferred_source ~= "none",
        executing_decision = executing_decision_probe,
        enemy_list = enemy_list_probe,
        front_target_list = front_target_probe,
        in_camera_target_list = in_camera_probe,
        sensor_hit_result = sensor_probe,
    },
    output = {
        decision_pack_path = ser_scalar(decision_pack_path, decision_pack_path_source),
        full_node = ser_scalar(full_node, full_node_source),
        upper_node = ser_scalar(upper_node, upper_node_source),
        current_action = current_action_capture,
        selected_request = selected_request_capture,
        output_mode = output_mode,
        output_texts = output_texts,
        output_text_blob = output_text_blob,
    },
    classification = {
        catalog = {
            utility_tokens = UTILITY_TOKENS,
            damage_recovery_tokens = DAMAGE_RECOVERY_TOKENS,
            special_skip_tokens = SPECIAL_SKIP_TOKENS,
            special_recovery_tokens = SPECIAL_RECOVERY_TOKENS,
            attackish_tokens = ATTACKISH_TOKENS,
        },
        raw_matches = raw_matches,
        booleans = {
            utility_locked_output = #raw_matches.utility > 0,
            damage_recovery_output = #raw_matches.damage_recovery > 0,
            special_skip_output = #raw_matches.special_skip > 0,
            special_recovery_output = #raw_matches.special_recovery > 0,
            special_recovery_allowed = special_recovery_allowed,
            attackish_output = #raw_matches.generic_attackish > 0,
            current_job_output_candidate = current_job_number ~= nil and contains_text(output_text_blob, string.format("job%02d", current_job_number)) or false,
            generic_attack_output_candidate = contains_text(output_text_blob, "/genericjob/") and contains_attackish_text(output_text_blob),
        },
        precedence = {
            recoverable_output_family_current = compute_family(raw_matches, special_recovery_allowed, false),
            recoverable_output_family_legacy_utility_first = compute_family(raw_matches, special_recovery_allowed, true),
        },
    },
}

local job_suffix = current_job_number ~= nil and string.format("job%02d", current_job_number) or "job_unknown"
local output_path = string.format("ce_dump/main_pawn_output_classification_screen_%s_%s.json", job_suffix, os.date("%Y%m%d_%H%M%S"))
json.dump_file(output_path, payload)
print("[main_pawn_output_classification_screen] wrote " .. output_path)
return output_path

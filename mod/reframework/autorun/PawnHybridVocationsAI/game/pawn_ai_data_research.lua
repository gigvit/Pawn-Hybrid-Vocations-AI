local state = require("PawnHybridVocationsAI/state")
local config = require("PawnHybridVocationsAI/config")
local util = require("PawnHybridVocationsAI/core/util")
local log = require("PawnHybridVocationsAI/core/log")

local pawn_ai_data_research = {}

local BLACKBOARD_COLLECTION_TYPES = {
    common = "app.AIBlackBoardCommonCollection",
    action = "app.AIBlackBoardActionCollection",
    formation = "app.AIBlackBoardFormationCollection",
    npc = "app.AIBlackBoardNpcCollection",
    situation = "app.AIBlackBoardSituationCollection",
}

local JOB_GOAL_CATEGORY_TYPE = "app.goalplanning.AIGoalCategoryJob"
local INTERESTING_FIELD_PATTERNS = {
    "job",
    "decision",
    "pack",
    "actinter",
    "target",
    "order",
    "goal",
    "state",
    "mode",
    "combat",
    "action",
    "battle",
    "situation",
    "formation",
    "phase",
    "request",
    "selector",
}
local SOCIAL_PACK_PATTERNS = {
    "HighFive",
    "Chilling",
    "Talking",
    "Treasure",
    "SortItem",
}

local function research_config()
    return config.pawn_ai_data_research or {}
end

local function research_enabled()
    return research_config().enabled == true
end

local function get_data(runtime)
    runtime.pawn_ai_data_research_data = runtime.pawn_ai_data_research_data or {
        enabled = false,
        installed = false,
        last_summary_signature = nil,
        last_domain_signatures = {},
        last_comparison_signature = nil,
        last_phase_signature = nil,
        last_phase_comparison_signatures = {},
        job_cache = {},
        phase_cache = {},
        phase_state = {
            current_phase = "idle",
            last_job = nil,
            last_combat_time_seconds = nil,
            last_phase_change_seconds = nil,
        },
        stats = {
            summary_emits = 0,
            domain_emits = 0,
            comparison_emits = 0,
            phase_emits = 0,
            phase_comparison_emits = 0,
        },
        summary = {
            current_job = nil,
            tracked_job = false,
            observed_phase = "idle",
            phase_reason = "unresolved",
            phase_pack_path = "nil",
            phase_pack_family = "nil",
            phase_nodes = "nil|nil",
            phase_request_action = "nil",
            phase_target = "nil",
            pawn_ai_game_object = "nil",
            pawn_update_controller = "nil",
            pawn_battle_controller = "nil",
            pawn_order_controller = "nil",
            ai_blackboard_controller = "nil",
            goal_action_data = "nil",
            battle_ai_data = "nil",
            order_data = "nil",
            job_goal_category = "nil",
            job_decisions = "nil",
            job_decisions_branch_count = 0,
            job07_branch_present = false,
            blackboard_common = "nil",
            blackboard_action = "nil",
            blackboard_formation = "nil",
            blackboard_npc = "nil",
            blackboard_situation = "nil",
            job_parameter = "nil",
        },
    }
    runtime.pawn_ai_data_research_data.enabled = research_enabled()
    return runtime.pawn_ai_data_research_data
end

local function to_number(value)
    if value == nil then
        return nil
    end

    local direct = tonumber(value)
    if direct ~= nil then
        return direct
    end

    return util.decode_numeric_like(value)
end

local function nil_like(value)
    local text = tostring(value or "nil")
    return text == "nil" or text == "none" or text == "unknown" or text == ""
end

local function contains_text(text, needle)
    if type(text) ~= "string" or type(needle) ~= "string" then
        return false
    end
    return string.find(text, needle, 1, true) ~= nil
end

local function matches_any(text, patterns)
    local haystack = tostring(text or "")
    for _, pattern in ipairs(patterns or {}) do
        if contains_text(haystack, tostring(pattern)) then
            return true
        end
    end
    return false
end

local function normalize_job_id(value)
    local numeric = to_number(value)
    if numeric == nil then
        return nil
    end
    return math.floor(numeric)
end

local function tracked_job_set()
    local values = {}
    for _, job_id in ipairs(research_config().tracked_jobs or {}) do
        local normalized = normalize_job_id(job_id)
        if normalized ~= nil then
            values[normalized] = true
        end
    end
    return values
end

local function is_tracked_job(job_id)
    local normalized = normalize_job_id(job_id)
    if normalized == nil then
        return false
    end
    return tracked_job_set()[normalized] == true
end

local function safe_index(container, key)
    if container == nil then
        return nil
    end

    local ok, value = pcall(function()
        return container[key]
    end)
    if ok then
        return value
    end

    return nil
end

local function sorted_keys(map)
    local keys = {}
    for key in pairs(map or {}) do
        table.insert(keys, key)
    end
    table.sort(keys, function(left, right)
        return tostring(left) < tostring(right)
    end)
    return keys
end

local function field_is_interesting(name)
    local lower_name = string.lower(tostring(name or ""))
    for _, pattern in ipairs(INTERESTING_FIELD_PATTERNS) do
        if string.find(lower_name, pattern, 1, true) ~= nil then
            return true
        end
    end
    return false
end

local function select_interesting_fields(fields, limit)
    local selected = {}
    local max_items = tonumber(limit) or 8
    local count = 0
    for _, key in ipairs(sorted_keys(fields or {})) do
        if field_is_interesting(key) then
            selected[key] = fields[key]
            count = count + 1
            if count >= max_items then
                break
            end
        end
    end
    return selected
end

local function summarize_field_map(fields)
    local parts = {}
    for _, key in ipairs(sorted_keys(fields or {})) do
        table.insert(parts, tostring(key) .. "=" .. tostring(fields[key]))
    end
    return #parts > 0 and table.concat(parts, ";") or "none"
end

local function stable_serialize(value, depth)
    depth = depth or 0
    if depth > 6 then
        return "<max-depth>"
    end

    local kind = type(value)
    if kind == "nil" then
        return "nil"
    end

    if kind == "boolean" or kind == "number" then
        return tostring(value)
    end

    if kind == "string" then
        return value
    end

    if kind == "table" then
        local is_array = true
        local count = 0
        for key in pairs(value) do
            count = count + 1
            if type(key) ~= "number" then
                is_array = false
            end
        end

        local parts = {}
        if is_array then
            for index = 1, count do
                table.insert(parts, stable_serialize(value[index], depth + 1))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        end

        for _, key in ipairs(sorted_keys(value)) do
            table.insert(parts, tostring(key) .. "=" .. stable_serialize(value[key], depth + 1))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end

    return tostring(value)
end

local function snapshot_fields_map(obj, limit)
    local results = {}
    for _, entry in ipairs(util.get_fields_snapshot(obj, limit or 16)) do
        results[entry.name] = entry.value
    end
    return results
end

local function make_object_snapshot(obj, limit)
    local interesting_limit = tonumber(research_config().interesting_field_limit) or 8
    local snapshot = {
        present = util.is_valid_obj(obj),
        description = util.describe_obj(obj),
        type_name = util.get_type_full_name(obj) or "nil",
        field_count = util.get_type_field_count(obj) or 0,
        collection_count = util.get_collection_count(obj) or 0,
        fields = {},
        interesting_fields = {},
        field_summary = "none",
    }

    if snapshot.present then
        snapshot.fields = snapshot_fields_map(obj, limit)
        snapshot.interesting_fields = select_interesting_fields(snapshot.fields, interesting_limit)
        snapshot.field_summary = summarize_field_map(snapshot.interesting_fields)
    end

    return snapshot
end

local function append_domain_event(runtime, data, key, event_name, payload, line)
    local signature = stable_serialize(payload)
    if data.last_domain_signatures[key] == signature then
        return false
    end

    data.last_domain_signatures[key] = signature
    data.stats.domain_emits = data.stats.domain_emits + 1
    log.session_marker(runtime, "ai_data", event_name, payload, line)
    return true
end

local function append_summary_event(runtime, data, payload)
    local signature = stable_serialize(payload)
    if data.last_summary_signature == signature then
        return false
    end

    data.last_summary_signature = signature
    data.stats.summary_emits = data.stats.summary_emits + 1
    log.session_marker(runtime, "ai_data", "main_pawn_ai_data_summary_changed", payload, string.format(
        "job=%s tracked=%s phase=%s goal=%s battle=%s order=%s branches=%s job07=%s",
        tostring(payload.current_job),
        tostring(payload.tracked_job),
        tostring(payload.observed_phase),
        tostring(payload.goal_action_data),
        tostring(payload.battle_ai_data),
        tostring(payload.order_data),
        tostring(payload.job_decisions_branch_count),
        tostring(payload.job07_branch_present)
    ))
    return true
end

local function append_compare_event(runtime, data, payload)
    local signature = stable_serialize(payload)
    if data.last_comparison_signature == signature then
        return false
    end

    data.last_comparison_signature = signature
    data.stats.comparison_emits = data.stats.comparison_emits + 1
    log.session_marker(runtime, "ai_data", "main_pawn_job01_job07_ai_compare_changed", payload, string.format(
        "job_decisions_same=%s battle_same=%s order_same=%s blackboard_same=%s",
        tostring(payload.job_decisions_same),
        tostring(payload.battle_ai_same),
        tostring(payload.order_data_same),
        tostring(payload.blackboard_same)
    ))
    return true
end

local function append_phase_event(runtime, data, payload)
    local signature = stable_serialize({
        current_job = payload.current_job,
        observed_phase = payload.observed_phase,
        phase_reason = payload.phase_reason,
    })
    if data.last_phase_signature == signature then
        return false
    end

    data.last_phase_signature = signature
    data.stats.phase_emits = data.stats.phase_emits + 1
    log.session_marker(runtime, "ai_data", "main_pawn_ai_data_phase_changed", payload, string.format(
        "job=%s phase=%s reason=%s pack=%s target=%s",
        tostring(payload.current_job),
        tostring(payload.observed_phase),
        tostring(payload.phase_reason),
        tostring(payload.phase_pack_path),
        tostring(payload.phase_target)
    ))
    return true
end

local function append_phase_compare_event(runtime, data, phase, payload)
    local signature = stable_serialize(payload)
    if data.last_phase_comparison_signatures[phase] == signature then
        return false
    end

    data.last_phase_comparison_signatures[phase] = signature
    data.stats.phase_comparison_emits = data.stats.phase_comparison_emits + 1
    log.session_marker(runtime, "ai_data", "main_pawn_job01_job07_phase_ai_compare_changed", payload, string.format(
        "phase=%s job_decisions_same=%s battle_same=%s order_same=%s blackboard_same=%s",
        tostring(phase),
        tostring(payload.job_decisions_same),
        tostring(payload.battle_ai_same),
        tostring(payload.order_data_same),
        tostring(payload.blackboard_same)
    ))
    return true
end

local function build_sources(main_pawn_data)
    local sources = {}
    local function push(label, obj)
        if util.is_valid_obj(obj) then
            table.insert(sources, {
                label = label,
                object = obj,
            })
        end
    end

    push("main_pawn_data.pawn_ai_fields.cached_game_object", main_pawn_data and main_pawn_data.pawn_ai_fields and main_pawn_data.pawn_ai_fields.cached_game_object or nil)
    push("main_pawn_data.pawn.<CachedGameObject>k__BackingField", main_pawn_data and util.safe_field(main_pawn_data.pawn, "<CachedGameObject>k__BackingField") or nil)
    push("main_pawn_data.pawn:get_GameObject()", main_pawn_data and util.safe_method(main_pawn_data.pawn, "get_GameObject") or nil)
    push("main_pawn_data.object", main_pawn_data and main_pawn_data.object or nil)
    push("main_pawn_data.runtime_character", main_pawn_data and main_pawn_data.runtime_character or nil)

    return sources
end

local function resolve_component_from_sources(sources, type_name)
    for _, source in ipairs(sources or {}) do
        if util.is_a(source.object, type_name) then
            return source.object, source.label
        end

        local component = util.safe_get_component(source.object, type_name)
        if util.is_valid_obj(component) then
            return component, source.label
        end
    end

    return nil, "unresolved"
end

local function resolve_ai_controllers(main_pawn_data)
    local sources = build_sources(main_pawn_data)
    local pawn_ai_game_object = nil
    local pawn_ai_game_object_source = "unresolved"
    for _, source in ipairs(sources) do
        if util.get_type_full_name(source.object) == "via.GameObject" then
            pawn_ai_game_object = source.object
            pawn_ai_game_object_source = source.label
            break
        end
    end

    local update_controller, update_source = resolve_component_from_sources(sources, "app.PawnUpdateController")
    local battle_controller, battle_source = resolve_component_from_sources(sources, "app.PawnBattleController")
    local order_controller, order_source = resolve_component_from_sources(sources, "app.PawnOrderController")
    local order_target_controller, order_target_source = resolve_component_from_sources(sources, "app.PawnOrderTargetController")
    local ai_meta_controller, ai_meta_source = resolve_component_from_sources(sources, "app.AIMetaController")
    local blackboard_controller = main_pawn_data and main_pawn_data.runtime_character and util.safe_method(main_pawn_data.runtime_character, "get_AIBlackBoardController") or nil
    local blackboard_source = blackboard_controller ~= nil and "runtime_character:get_AIBlackBoardController()" or "unresolved"

    return {
        pawn_ai_game_object = pawn_ai_game_object,
        pawn_ai_game_object_source = pawn_ai_game_object_source,
        pawn_update_controller = update_controller,
        pawn_update_controller_source = update_source,
        pawn_battle_controller = battle_controller,
        pawn_battle_controller_source = battle_source,
        pawn_order_controller = order_controller,
        pawn_order_controller_source = order_source,
        pawn_order_target_controller = order_target_controller,
        pawn_order_target_controller_source = order_target_source,
        ai_meta_controller = ai_meta_controller,
        ai_meta_controller_source = ai_meta_source,
        ai_blackboard_controller = blackboard_controller,
        ai_blackboard_controller_source = blackboard_source,
    }
end

local function field_or_method(obj, field_name, method_name)
    return util.safe_field(obj, field_name)
        or util.safe_field(obj, "_" .. field_name)
        or util.safe_method(obj, tostring(method_name or ("get_" .. field_name)))
        or util.safe_method(obj, tostring(method_name or ("get_" .. field_name)) .. "()")
end

local function enumerate_array_like(obj, limit)
    if obj == nil then
        return {}, 0
    end

    local source = util.safe_direct_method(obj, "get_elements")
        or util.safe_method(obj, "get_elements()")
        or util.safe_method(obj, "get_elements")
        or obj

    local items = util.collection_to_lua(source, limit or 12)
    local count = util.get_collection_count(source) or #items
    return items, count
end

local function extract_job_decision_branches(job_decisions, limit)
    local items, count = enumerate_array_like(job_decisions, limit)
    local branch_jobs = {}
    local branch_entries = {}
    local has_job07_branch = false
    local has_job01_branch = false
    local field_limit = tonumber(research_config().snapshot_field_limit) or 16

    for _, item in ipairs(items) do
        local jobs_obj = util.safe_field(item, "_Job")
        local jobs, _ = enumerate_array_like(jobs_obj, limit)
        local labels = {}
        for _, job_item in ipairs(jobs) do
            local numeric = normalize_job_id(safe_index(job_item, "m_value") or safe_index(job_item, "value__") or job_item)
            if numeric ~= nil then
                table.insert(labels, tostring(numeric))
                if numeric == 7 then
                    has_job07_branch = true
                elseif numeric == 1 then
                    has_job01_branch = true
                end
            end
        end

        if #labels == 0 then
            table.insert(branch_jobs, "nil")
        else
            table.insert(branch_jobs, table.concat(labels, "|"))
        end

        local branch_snapshot = make_object_snapshot(item, field_limit)
        table.insert(branch_entries, {
            description = branch_snapshot.description,
            type_name = branch_snapshot.type_name,
            jobs = #labels > 0 and table.concat(labels, "|") or "nil",
            interesting_fields = branch_snapshot.interesting_fields,
            field_summary = branch_snapshot.field_summary,
        })
    end

    return {
        branch_count = count,
        branch_jobs = branch_jobs,
        branch_entries = branch_entries,
        has_job07_branch = has_job07_branch,
        has_job01_branch = has_job01_branch,
    }
end

local function scan_for_types(root, wanted, depth, field_limit, results, seen)
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
    if wanted_key ~= nil and results[wanted_key] == nil then
        results[wanted_key] = root
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

    local max_items = field_limit or 16
    for index, field in ipairs(fields) do
        if index > max_items then
            break
        end

        local ok_value, value = pcall(field.get_data, field, root)
        if ok_value and util.is_valid_obj(value) then
            scan_for_types(value, wanted, depth - 1, field_limit, results, seen)
        end
    end
end

local function resolve_job_goal_category(main_pawn_data, goal_action_data)
    local field_limit = tonumber(research_config().recursive_scan_field_limit) or 16
    local depth = tonumber(research_config().recursive_scan_depth) or 2
    local roots = {
        { label = "main_pawn_data.ai_goal_planning", object = main_pawn_data and main_pawn_data.ai_goal_planning or nil },
        { label = "main_pawn_data.decision_evaluation_module", object = main_pawn_data and main_pawn_data.decision_evaluation_module or nil },
        { label = "main_pawn_data.decision_maker", object = main_pawn_data and main_pawn_data.decision_maker or nil },
        { label = "goal_action_data", object = goal_action_data },
    }

    for _, root in ipairs(roots) do
        if util.is_valid_obj(root.object) then
            local results = {}
            scan_for_types(root.object, {
                [JOB_GOAL_CATEGORY_TYPE] = "job_goal_category",
            }, depth, field_limit, results, {})
            if util.is_valid_obj(results.job_goal_category) then
                return results.job_goal_category, root.label
            end
        end
    end

    return nil, "unresolved"
end

local function resolve_blackboard_collections(blackboard_controller)
    local field_limit = tonumber(research_config().recursive_scan_field_limit) or 16
    local depth = tonumber(research_config().recursive_scan_depth) or 2
    local wanted = {}
    for key, type_name in pairs(BLACKBOARD_COLLECTION_TYPES) do
        wanted[type_name] = key
    end

    local results = {}
    scan_for_types(blackboard_controller, wanted, depth, field_limit, results, {})
    return results
end

local function resolve_job_parameter(job_id)
    local character_manager = util.safe_singleton("managed", "app.CharacterManager")
    local human_param = character_manager and util.safe_method(character_manager, "get_HumanParam") or nil
    local job_param = human_param and util.safe_field(human_param, "JobParam") or nil
    local normalized = normalize_job_id(job_id)
    if job_param == nil or normalized == nil or normalized < 1 then
        return nil, "unresolved"
    end

    local field_name = string.format("Job%02dParameter", normalized)
    return util.safe_field(job_param, field_name), field_name
end

local function build_blackboard_snapshot(collections)
    local field_limit = tonumber(research_config().snapshot_field_limit) or 16
    local snapshot = {}
    for key, _ in pairs(BLACKBOARD_COLLECTION_TYPES) do
        snapshot[key] = make_object_snapshot(collections[key], field_limit)
    end
    return snapshot
end

local function classify_pack_family(path)
    local text = tostring(path or "nil")
    if text == "nil" then
        return "nil"
    end
    if contains_text(text, "Job01_Fighter/") or contains_text(text, "Job07/") then
        return "job_specific"
    end
    if contains_text(text, "GenericJob/") then
        return "genericjob"
    end
    if contains_text(text, "Common/") then
        return "common"
    end
    if contains_text(text, "ch1/") then
        return "ch1"
    end
    if contains_text(text, "NPC/") then
        return "npc"
    end
    return "other"
end

local function has_job_node(nodes)
    local text = tostring(nodes or "")
    return contains_text(text, "Job01_")
        or contains_text(text, "Job07_")
        or contains_text(text, "GenericJob_")
end

local function is_combat_action_name(action_name)
    local text = tostring(action_name or "")
    if nil_like(text) then
        return false
    end
    return contains_text(text, "Attack")
        or contains_text(text, "Slash")
        or contains_text(text, "SkyDive")
        or contains_text(text, "ViolentStab")
        or contains_text(text, "BlinkStrike")
        or contains_text(text, "Dash")
end

local function build_phase_context(runtime, data, current_job)
    local action_data = runtime.action_research_data or {}
    local action_summary = action_data.summary or {}
    local state_info = data.phase_state or {
        current_phase = "idle",
        last_job = nil,
        last_combat_time_seconds = nil,
        last_phase_change_seconds = nil,
    }

    if state_info.last_job ~= current_job then
        state_info.current_phase = "idle"
        state_info.last_combat_time_seconds = nil
        state_info.last_phase_change_seconds = nil
        state_info.last_job = current_job
    end

    local pack_path = action_summary.main_pawn_current_execute_actinter_pack_path
    if nil_like(pack_path) then
        pack_path = action_summary.main_pawn_last_observed_actinter_pack_path
    end
    if nil_like(pack_path) then
        pack_path = action_summary.main_pawn_last_decision_snapshot_pack_path
    end

    local full_node = tostring(action_summary.main_pawn_full_node or "nil")
    local upper_node = tostring(action_summary.main_pawn_upper_node or "nil")
    local nodes = full_node .. "|" .. upper_node
    local action_name = tostring(action_summary.main_pawn_last_requested_action or "nil")
    local target = action_summary.main_pawn_executing_decision_target
    if nil_like(target) then
        target = action_summary.last_actinter_target
    end
    if nil_like(target) then
        target = action_summary.last_decision_probe_decision_target
    end
    target = tostring(target or "nil")

    local pack_family = classify_pack_family(pack_path)
    local combat_runtime = pack_family == "job_specific"
        or pack_family == "genericjob"
        or has_job_node(nodes)
        or is_combat_action_name(action_name)
    local social_signal = matches_any(pack_path, SOCIAL_PACK_PATTERNS)
    local has_target = not nil_like(target)
    local now = tonumber(runtime.game_time) or tonumber(os.clock()) or 0.0
    local post_window = tonumber(research_config().phase_post_combat_window_seconds) or 2.5

    local phase = "idle"
    local reason = "no_combat_signal"
    if combat_runtime and not social_signal then
        phase = "during_combat"
        reason = "combat_runtime_signal"
        state_info.last_combat_time_seconds = now
    elseif has_target and not social_signal then
        phase = "pre_combat"
        reason = "target_without_combat_runtime"
    elseif state_info.last_combat_time_seconds ~= nil and (now - state_info.last_combat_time_seconds) <= post_window then
        phase = "post_combat"
        reason = "recent_combat_window"
    elseif social_signal then
        phase = "idle"
        reason = "social_runtime"
    end

    local changed = phase ~= state_info.current_phase
    if changed then
        state_info.current_phase = phase
        state_info.last_phase_change_seconds = now
    end
    data.phase_state = state_info

    return {
        observed_phase = phase,
        phase_reason = reason,
        phase_pack_path = tostring(pack_path or "nil"),
        phase_pack_family = pack_family,
        phase_nodes = nodes,
        phase_request_action = action_name,
        phase_target = target,
        phase_has_target = has_target,
        phase_combat_runtime = combat_runtime,
        phase_social_signal = social_signal,
        phase_changed = changed,
    }
end

local function build_job_cache_entry(current_job, goal_action_snapshot, battle_snapshot, order_snapshot, job_decisions_snapshot, blackboard_snapshot, job_param_snapshot, phase_context)
    return {
        job = current_job,
        phase = phase_context and phase_context.observed_phase or "idle",
        phase_pack_family = phase_context and phase_context.phase_pack_family or "nil",
        phase_nodes = phase_context and phase_context.phase_nodes or "nil|nil",
        phase_target = phase_context and phase_context.phase_target or "nil",
        goal_action_signature = stable_serialize(goal_action_snapshot),
        battle_ai_signature = stable_serialize(battle_snapshot),
        order_data_signature = stable_serialize(order_snapshot),
        job_decisions_signature = stable_serialize(job_decisions_snapshot),
        blackboard_signature = stable_serialize(blackboard_snapshot),
        job_parameter_signature = stable_serialize(job_param_snapshot),
        job07_branch_present = job_decisions_snapshot.has_job07_branch == true,
        branch_jobs = table.concat(job_decisions_snapshot.branch_jobs or {}, ","),
    }
end

local function maybe_emit_job_compare(runtime, data)
    if research_config().comparison_enabled ~= true then
        return
    end

    local job01 = data.job_cache["1"]
    local job07 = data.job_cache["7"]
    if job01 == nil or job07 == nil then
        return
    end

    append_compare_event(runtime, data, {
        job01_cached = true,
        job07_cached = true,
        goal_action_data_same = job01.goal_action_signature == job07.goal_action_signature,
        battle_ai_same = job01.battle_ai_signature == job07.battle_ai_signature,
        order_data_same = job01.order_data_signature == job07.order_data_signature,
        job_decisions_same = job01.job_decisions_signature == job07.job_decisions_signature,
        blackboard_same = job01.blackboard_signature == job07.blackboard_signature,
        job_parameter_same = job01.job_parameter_signature == job07.job_parameter_signature,
        job01_job07_branch_present = job01.job07_branch_present,
        job07_job07_branch_present = job07.job07_branch_present,
        job01_branch_jobs = job01.branch_jobs,
        job07_branch_jobs = job07.branch_jobs,
    })
end

local function maybe_emit_phase_compare(runtime, data, phase)
    if research_config().comparison_enabled ~= true then
        return
    end

    local job01_phase = data.phase_cache["1"] and data.phase_cache["1"][phase] or nil
    local job07_phase = data.phase_cache["7"] and data.phase_cache["7"][phase] or nil
    if job01_phase == nil or job07_phase == nil then
        return
    end

    append_phase_compare_event(runtime, data, phase, {
        phase = phase,
        job01_cached = true,
        job07_cached = true,
        goal_action_data_same = job01_phase.goal_action_signature == job07_phase.goal_action_signature,
        battle_ai_same = job01_phase.battle_ai_signature == job07_phase.battle_ai_signature,
        order_data_same = job01_phase.order_data_signature == job07_phase.order_data_signature,
        job_decisions_same = job01_phase.job_decisions_signature == job07_phase.job_decisions_signature,
        blackboard_same = job01_phase.blackboard_signature == job07_phase.blackboard_signature,
        job_parameter_same = job01_phase.job_parameter_signature == job07_phase.job_parameter_signature,
        job01_job07_branch_present = job01_phase.job07_branch_present,
        job07_job07_branch_present = job07_phase.job07_branch_present,
        job01_branch_jobs = job01_phase.branch_jobs,
        job07_branch_jobs = job07_phase.branch_jobs,
        job01_phase_pack_family = job01_phase.phase_pack_family,
        job07_phase_pack_family = job07_phase.phase_pack_family,
        job01_phase_nodes = job01_phase.phase_nodes,
        job07_phase_nodes = job07_phase.phase_nodes,
        job01_phase_target = job01_phase.phase_target,
        job07_phase_target = job07_phase.phase_target,
    })
end

function pawn_ai_data_research.install(runtime)
    local data = get_data(runtime)
    data.installed = true
    data.enabled = research_enabled()
    return data
end

function pawn_ai_data_research.update(runtime)
    local data = get_data(runtime)
    if not data.enabled then
        return data
    end

    local main_pawn_data = runtime.main_pawn_data
    local current_job = normalize_job_id(main_pawn_data and (main_pawn_data.current_job or main_pawn_data.job) or nil)
    local tracked_job = is_tracked_job(current_job)
    local controllers = resolve_ai_controllers(main_pawn_data or {})
    local goal_action_data = field_or_method(controllers.pawn_update_controller, "AIGoalActionData")
    local battle_ai_data = field_or_method(controllers.pawn_battle_controller, "_BattleAIData", "get_BattleAIData")
    local order_data = field_or_method(controllers.pawn_order_controller, "OrderData")
    local job_goal_category, job_goal_category_source = resolve_job_goal_category(main_pawn_data, goal_action_data)
    local job_decisions = util.safe_field(job_goal_category, "_JobDecisions")
    local blackboard_collections = resolve_blackboard_collections(controllers.ai_blackboard_controller)
    local job_parameter, job_parameter_source = resolve_job_parameter(current_job)

    local field_limit = tonumber(research_config().snapshot_field_limit) or 16
    local branch_limit = tonumber(research_config().branch_limit) or 12

    local goal_action_snapshot = make_object_snapshot(goal_action_data, field_limit)
    local battle_snapshot = make_object_snapshot(battle_ai_data, field_limit)
    local order_snapshot = make_object_snapshot(order_data, field_limit)
    local job_param_snapshot = make_object_snapshot(job_parameter, field_limit)
    local blackboard_snapshot = build_blackboard_snapshot(blackboard_collections)
    local phase_context = build_phase_context(runtime, data, current_job)
    local job_decision_details = extract_job_decision_branches(job_decisions, branch_limit)
    local job_decisions_snapshot = {
        category = make_object_snapshot(job_goal_category, field_limit),
        source = job_goal_category_source,
        job_decisions = make_object_snapshot(job_decisions, field_limit),
        branch_count = job_decision_details.branch_count,
        branch_jobs = job_decision_details.branch_jobs,
        branch_entries = job_decision_details.branch_entries,
        has_job07_branch = job_decision_details.has_job07_branch,
        has_job01_branch = job_decision_details.has_job01_branch,
    }

    local summary = {
        current_job = current_job,
        tracked_job = tracked_job,
        observed_phase = phase_context.observed_phase,
        phase_reason = phase_context.phase_reason,
        phase_pack_path = phase_context.phase_pack_path,
        phase_pack_family = phase_context.phase_pack_family,
        phase_nodes = phase_context.phase_nodes,
        phase_request_action = phase_context.phase_request_action,
        phase_target = phase_context.phase_target,
        pawn_ai_game_object = util.describe_obj(controllers.pawn_ai_game_object),
        pawn_ai_game_object_source = controllers.pawn_ai_game_object_source,
        pawn_update_controller = util.describe_obj(controllers.pawn_update_controller),
        pawn_update_controller_source = controllers.pawn_update_controller_source,
        pawn_battle_controller = util.describe_obj(controllers.pawn_battle_controller),
        pawn_battle_controller_source = controllers.pawn_battle_controller_source,
        pawn_order_controller = util.describe_obj(controllers.pawn_order_controller),
        pawn_order_controller_source = controllers.pawn_order_controller_source,
        ai_blackboard_controller = util.describe_obj(controllers.ai_blackboard_controller),
        ai_blackboard_controller_source = controllers.ai_blackboard_controller_source,
        goal_action_data = goal_action_snapshot.description,
        battle_ai_data = battle_snapshot.description,
        order_data = order_snapshot.description,
        job_goal_category = job_decisions_snapshot.category.description,
        job_goal_category_source = job_goal_category_source,
        job_decisions = job_decisions_snapshot.job_decisions.description,
        job_decisions_branch_count = job_decisions_snapshot.branch_count,
        job07_branch_present = job_decisions_snapshot.has_job07_branch == true,
        blackboard_common = blackboard_snapshot.common.description,
        blackboard_action = blackboard_snapshot.action.description,
        blackboard_formation = blackboard_snapshot.formation.description,
        blackboard_npc = blackboard_snapshot.npc.description,
        blackboard_situation = blackboard_snapshot.situation.description,
        job_parameter = job_param_snapshot.description,
        job_parameter_source = job_parameter_source,
    }

    data.summary = summary
    append_summary_event(runtime, data, summary)
    if phase_context.phase_changed then
        append_phase_event(runtime, data, summary)
    end

    if not tracked_job then
        return data
    end

    append_domain_event(runtime, data, "goal_action:" .. tostring(current_job) .. ":" .. tostring(phase_context.observed_phase), "main_pawn_goal_action_data_snapshot_changed", {
        actor = "main_pawn",
        current_job = current_job,
        observed_phase = phase_context.observed_phase,
        phase_reason = phase_context.phase_reason,
        controller = util.describe_obj(controllers.pawn_update_controller),
        controller_source = controllers.pawn_update_controller_source,
        snapshot = goal_action_snapshot,
    }, string.format("job=%s phase=%s goal=%s", tostring(current_job), tostring(phase_context.observed_phase), tostring(goal_action_snapshot.description)))

    append_domain_event(runtime, data, "battle_ai:" .. tostring(current_job) .. ":" .. tostring(phase_context.observed_phase), "main_pawn_battle_ai_data_snapshot_changed", {
        actor = "main_pawn",
        current_job = current_job,
        observed_phase = phase_context.observed_phase,
        phase_reason = phase_context.phase_reason,
        controller = util.describe_obj(controllers.pawn_battle_controller),
        controller_source = controllers.pawn_battle_controller_source,
        snapshot = battle_snapshot,
    }, string.format("job=%s phase=%s battle=%s", tostring(current_job), tostring(phase_context.observed_phase), tostring(battle_snapshot.description)))

    append_domain_event(runtime, data, "order_data:" .. tostring(current_job) .. ":" .. tostring(phase_context.observed_phase), "main_pawn_order_data_snapshot_changed", {
        actor = "main_pawn",
        current_job = current_job,
        observed_phase = phase_context.observed_phase,
        phase_reason = phase_context.phase_reason,
        controller = util.describe_obj(controllers.pawn_order_controller),
        controller_source = controllers.pawn_order_controller_source,
        snapshot = order_snapshot,
    }, string.format("job=%s phase=%s order=%s", tostring(current_job), tostring(phase_context.observed_phase), tostring(order_snapshot.description)))

    append_domain_event(runtime, data, "job_decisions:" .. tostring(current_job) .. ":" .. tostring(phase_context.observed_phase), "main_pawn_job_decisions_snapshot_changed", {
        actor = "main_pawn",
        current_job = current_job,
        observed_phase = phase_context.observed_phase,
        phase_reason = phase_context.phase_reason,
        category = job_decisions_snapshot.category,
        category_source = job_decisions_snapshot.source,
        job_decisions = job_decisions_snapshot.job_decisions,
        branch_count = job_decisions_snapshot.branch_count,
        branch_jobs = job_decisions_snapshot.branch_jobs,
        branch_entries = job_decisions_snapshot.branch_entries,
        has_job07_branch = job_decisions_snapshot.has_job07_branch,
        has_job01_branch = job_decisions_snapshot.has_job01_branch,
    }, string.format(
        "job=%s phase=%s branches=%s job07=%s",
        tostring(current_job),
        tostring(phase_context.observed_phase),
        tostring(job_decisions_snapshot.branch_count),
        tostring(job_decisions_snapshot.has_job07_branch)
    ))

    append_domain_event(runtime, data, "blackboard:" .. tostring(current_job) .. ":" .. tostring(phase_context.observed_phase), "main_pawn_blackboard_snapshot_changed", {
        actor = "main_pawn",
        current_job = current_job,
        observed_phase = phase_context.observed_phase,
        phase_reason = phase_context.phase_reason,
        controller = util.describe_obj(controllers.ai_blackboard_controller),
        controller_source = controllers.ai_blackboard_controller_source,
        collections = blackboard_snapshot,
    }, string.format(
        "job=%s phase=%s common=%s action=%s formation=%s npc=%s situation=%s",
        tostring(current_job),
        tostring(phase_context.observed_phase),
        tostring(blackboard_snapshot.common.description),
        tostring(blackboard_snapshot.action.description),
        tostring(blackboard_snapshot.formation.description),
        tostring(blackboard_snapshot.npc.description),
        tostring(blackboard_snapshot.situation.description)
    ))

    append_domain_event(runtime, data, "job_param:" .. tostring(current_job) .. ":" .. tostring(phase_context.observed_phase), "main_pawn_job_parameter_snapshot_changed", {
        actor = "main_pawn",
        current_job = current_job,
        observed_phase = phase_context.observed_phase,
        phase_reason = phase_context.phase_reason,
        source = job_parameter_source,
        snapshot = job_param_snapshot,
    }, string.format("job=%s phase=%s param=%s", tostring(current_job), tostring(phase_context.observed_phase), tostring(job_param_snapshot.description)))

    data.job_cache[tostring(current_job)] = build_job_cache_entry(
        current_job,
        goal_action_snapshot,
        battle_snapshot,
        order_snapshot,
        job_decisions_snapshot,
        blackboard_snapshot,
        job_param_snapshot,
        phase_context
    )
    data.phase_cache[tostring(current_job)] = data.phase_cache[tostring(current_job)] or {}
    data.phase_cache[tostring(current_job)][tostring(phase_context.observed_phase)] = build_job_cache_entry(
        current_job,
        goal_action_snapshot,
        battle_snapshot,
        order_snapshot,
        job_decisions_snapshot,
        blackboard_snapshot,
        job_param_snapshot,
        phase_context
    )
    maybe_emit_job_compare(runtime, data)
    maybe_emit_phase_compare(runtime, data, tostring(phase_context.observed_phase))

    return data
end

return pawn_ai_data_research

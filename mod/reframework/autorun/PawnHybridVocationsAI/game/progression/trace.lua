local state = require("PawnHybridVocationsAI/state")
local config = require("PawnHybridVocationsAI/config")
local util = require("PawnHybridVocationsAI/core/util")
local log = require("PawnHybridVocationsAI/core/log")
local hybrid_jobs = require("PawnHybridVocationsAI/data/hybrid_jobs")

local progression_trace = {}

local HOOK_TYPES = {
    JOB_CONTEXT = "job_context",
    JOB_CHANGER = "job_changer",
}

local function get_trace(runtime)
    runtime.progression_trace_data = runtime.progression_trace_data or {
        hooks_installed = false,
        installed_methods = {},
        registration_errors = {},
        recent_events = {},
        latest_check_matrix = {},
        last_event_signatures = {},
        stats = {
            qualification_checks = 0,
            qualification_writes = 0,
            job_change_requests = 0,
            qualification_true = 0,
            qualification_false = 0,
            qualification_unknown = 0,
            qualification_probe_attempts = 0,
            qualification_probe_applied = 0,
        },
        mirror_probe = {
            enabled = config.progression_research.enable_runtime_qualification_mirror_probe == true,
            attempted = 0,
            applied = 0,
            last_reason = "not_attempted",
            last_target = "none",
            last_job_id = nil,
            last_before_code = nil,
            last_after_code = nil,
        },
    }
    return runtime.progression_trace_data
end

local function normalize_result(value)
    local decoded = util.decode_qualification_value(value)
    return decoded and decoded.normalized_bool or nil
end

local function to_managed(args, index)
    if args == nil then
        return nil
    end
    return sdk.to_managed_object(args[index])
end

local function to_job_id(value)
    if value == nil then
        return nil
    end

    local as_number = tonumber(value)
    if as_number ~= nil then
        return as_number
    end

    local ok, converted = pcall(function()
        return tonumber(sdk.to_int64(value))
    end)
    if ok then
        return converted
    end

    return nil
end

local function is_hybrid_job(job_id)
    return hybrid_jobs.is_hybrid_job(job_id)
end

local function resolve_target_from_instance(runtime, instance, hook_type)
    local progression = runtime.progression_state_data
    if progression == nil or instance == nil then
        return "unknown"
    end

    local player = progression.player
    local main_pawn = progression.main_pawn

    if hook_type == HOOK_TYPES.JOB_CONTEXT then
        if player ~= nil and util.same_object(instance, player.job_context) then
            return "player"
        end
        if main_pawn ~= nil and util.same_object(instance, main_pawn.job_context) then
            return "main_pawn"
        end
    elseif hook_type == HOOK_TYPES.JOB_CHANGER then
        if player ~= nil and util.same_object(instance, player.job_changer) then
            return "player"
        end
        if main_pawn ~= nil and util.same_object(instance, main_pawn.job_changer) then
            return "main_pawn"
        end
    end

    return "unknown"
end

local function extract_actor_state(runtime, target)
    local progression = runtime.progression_state_data
    if progression == nil then
        return nil
    end
    if target == "player" then
        return progression.player
    end
    if target == "main_pawn" then
        return progression.main_pawn
    end
    return nil
end

local function find_hybrid_key(job_id)
    return hybrid_jobs.find_key_by_id(job_id)
end

local function append_event(runtime, event)
    local trace = get_trace(runtime)
    table.insert(trace.recent_events, 1, event)
    while #trace.recent_events > (config.progression_research.trace_history_limit or 24) do
        table.remove(trace.recent_events)
    end

    if event.name == "qualification_check_observed" then
        local matrix_key = string.format("%s:%s", tostring(event.target), tostring(event.job_id))
        trace.latest_check_matrix[matrix_key] = {
            target = event.target,
            job_id = event.job_id,
            method = event.method,
            result = event.result_bool,
            result_code = event.result_code,
            result_hex = event.result_hex,
            raw_retval = event.raw_retval,
            snapshot_direct = event.snapshot_direct_is_job_qualified,
            snapshot_direct_code = event.snapshot_direct_code,
            snapshot_direct_hex = event.snapshot_direct_hex,
            snapshot_bit = event.snapshot_qualified_bit,
            snapshot_job_level = event.snapshot_job_level,
        }
    end

    local signature = table.concat({
        tostring(event.name),
        tostring(event.target),
        tostring(event.job_id),
        tostring(event.method),
        tostring(event.result_code ~= nil and event.result_code or (event.result_bool ~= nil and event.result_bool or event.result)),
    }, "|")

    if trace.last_event_signatures[event.name] == signature then
        return
    end
    trace.last_event_signatures[event.name] = signature

    log.session_marker(runtime, "progression", event.name or "runtime_event", event, string.format(
        "source=%s target=%s job_id=%s method=%s result=%s code=%s hex=%s",
        tostring(event.source),
        tostring(event.target),
        tostring(event.job_id),
        tostring(event.method),
        tostring(event.result_bool ~= nil and event.result_bool or event.result),
        tostring(event.result_code),
        tostring(event.result_hex)
    ))
end

local function maybe_apply_runtime_mirror_probe(runtime, target, job_id, decoded)
    local trace = get_trace(runtime)
    local probe = trace.mirror_probe
    if probe == nil or probe.enabled ~= true then
        return nil, "probe_disabled"
    end

    trace.stats.qualification_probe_attempts = trace.stats.qualification_probe_attempts + 1
    probe.attempted = probe.attempted + 1
    probe.last_target = tostring(target)
    probe.last_job_id = job_id
    probe.last_before_code = decoded and decoded.numeric or nil

    if target ~= "main_pawn" then
        probe.last_reason = "target_not_main_pawn"
        return nil, probe.last_reason
    end

    local player_state = extract_actor_state(runtime, "player")
    local pawn_state = extract_actor_state(runtime, "main_pawn")
    local hybrid_key = find_hybrid_key(job_id)
    local player_hybrid = player_state and player_state.hybrid_gate_status and hybrid_key and player_state.hybrid_gate_status[hybrid_key] or nil
    local pawn_hybrid = pawn_state and pawn_state.hybrid_gate_status and hybrid_key and pawn_state.hybrid_gate_status[hybrid_key] or nil
    if hybrid_key == nil or player_hybrid == nil or pawn_hybrid == nil then
        probe.last_reason = "hybrid_state_unresolved"
        return nil, probe.last_reason
    end

    if not (player_hybrid.qualified_bits and player_hybrid.qualified_bits.bit_job_minus_one) then
        probe.last_reason = "player_not_qualified"
        return nil, probe.last_reason
    end

    if pawn_hybrid.qualified_bits and pawn_hybrid.qualified_bits.bit_job_minus_one then
        probe.last_reason = "pawn_already_qualified"
        return nil, probe.last_reason
    end

    local matrix_item = trace.latest_check_matrix[string.format("player:%s", tostring(job_id))]
    local override_retval = matrix_item and matrix_item.raw_retval or (player_hybrid.direct and player_hybrid.direct.is_job_qualified) or nil
    if override_retval == nil then
        probe.last_reason = "player_result_unavailable"
        return nil, probe.last_reason
    end

    local override_decoded = util.decode_qualification_value(override_retval)
    if override_decoded.numeric ~= nil and decoded ~= nil and override_decoded.numeric == decoded.numeric then
        probe.last_reason = "already_matching"
        return nil, probe.last_reason
    end

    probe.applied = probe.applied + 1
    probe.last_reason = "player_runtime_mirror"
    probe.last_after_code = override_decoded and override_decoded.numeric or nil
    trace.stats.qualification_probe_applied = trace.stats.qualification_probe_applied + 1
    return override_retval, probe.last_reason
end

local function register_hook(type_name, candidate_methods, hook_type, build_event)
    local runtime = state.runtime
    local trace = get_trace(runtime)
    local td = util.safe_sdk_typedef(type_name)
    if td == nil then
        local reason = string.format("%s typedef missing", tostring(type_name))
        table.insert(trace.registration_errors, reason)
        log.warn("Progression hook skipped: " .. reason)
        return false
    end

    local method = nil
    local method_name = nil
    for _, candidate in ipairs(candidate_methods) do
        local ok, resolved = pcall(function()
            return td:get_method(candidate)
        end)
        if ok and resolved ~= nil then
            method = resolved
            method_name = candidate
            break
        end
    end

    if method == nil then
        local observed = table.concat(candidate_methods, ", ")
        local reason = string.format("%s methods missing (%s)", tostring(type_name), tostring(observed))
        table.insert(trace.registration_errors, reason)
        log.warn("Progression hook skipped: " .. reason)
        return false
    end

    local ok, err = pcall(function()
        sdk.hook(
            method,
            function(args)
                local storage = thread.get_hook_storage()
                storage.instance = to_managed(args, 2)
                storage.job_id = to_job_id(args[3])
                storage.method_name = method_name
                storage.hook_type = hook_type
            end,
            function(retval)
                local storage = thread.get_hook_storage()
                local job_id = storage.job_id
                if not is_hybrid_job(job_id) then
                    return retval
                end

                local event = build_event(
                    runtime,
                    storage.instance,
                    storage.method_name,
                    storage.hook_type,
                    job_id,
                    retval
                )
                if event ~= nil then
                    append_event(runtime, event)
                    if event.override_applied and event.override_retval ~= nil then
                        retval = event.override_retval
                    end
                end
                return retval
            end
        )
    end)

    if not ok then
        local reason = string.format("%s::%s (%s)", tostring(type_name), tostring(method_name), tostring(err))
        table.insert(trace.registration_errors, reason)
        log.error("Progression hook registration failed: " .. reason)
        return false
    end

    table.insert(trace.installed_methods, string.format("%s::%s", tostring(type_name), tostring(method_name)))
    log.info(string.format("Progression hook registered: %s::%s", tostring(type_name), tostring(method_name)))
    return true
end

local function build_qualification_check_event(runtime, instance, method_name, hook_type, job_id, retval)
    local target = resolve_target_from_instance(runtime, instance, hook_type)
    local trace = get_trace(runtime)
    trace.stats.qualification_checks = trace.stats.qualification_checks + 1
    local decoded = util.decode_qualification_value(retval)
    local result_bool = normalize_result(retval)
    if result_bool == true then
        trace.stats.qualification_true = trace.stats.qualification_true + 1
    elseif result_bool == false then
        trace.stats.qualification_false = trace.stats.qualification_false + 1
    else
        trace.stats.qualification_unknown = trace.stats.qualification_unknown + 1
    end

    local actor_state = extract_actor_state(runtime, target)
    local hybrid_key = find_hybrid_key(job_id)
    local hybrid_state = actor_state and actor_state.hybrid_gate_status and hybrid_key and actor_state.hybrid_gate_status[hybrid_key] or nil
    local snapshot_decoded = util.decode_qualification_value(hybrid_state and hybrid_state.direct and hybrid_state.direct.is_job_qualified or nil)
    local override_retval, override_reason = maybe_apply_runtime_mirror_probe(runtime, target, job_id, decoded)
    local override_decoded = util.decode_qualification_value(override_retval)

    return {
        name = "qualification_check_observed",
        source = HOOK_TYPES.JOB_CONTEXT,
        target = target,
        method = method_name,
        hook_type = hook_type,
        job_id = job_id,
        result = retval,
        raw_retval = retval,
        result_bool = result_bool,
        result_code = decoded and decoded.numeric or nil,
        result_hex = decoded and decoded.hex or nil,
        result_has_basic_flag = decoded and decoded.has_basic_flag or nil,
        result_has_0x100_flag = decoded and decoded.has_0x100_flag or nil,
        result_has_0x200_flag = decoded and decoded.has_0x200_flag or nil,
        snapshot_direct_is_job_qualified = hybrid_state and hybrid_state.direct and hybrid_state.direct.is_job_qualified or nil,
        snapshot_direct_code = snapshot_decoded and snapshot_decoded.numeric or nil,
        snapshot_direct_hex = snapshot_decoded and snapshot_decoded.hex or nil,
        snapshot_job_level = hybrid_state and hybrid_state.direct and hybrid_state.direct.job_level or nil,
        snapshot_qualified_bit = hybrid_state and hybrid_state.qualified_bits and hybrid_state.qualified_bits.bit_job_minus_one or nil,
        override_applied = override_retval ~= nil,
        override_reason = override_reason,
        override_result_code = override_decoded and override_decoded.numeric or nil,
        override_result_hex = override_decoded and override_decoded.hex or nil,
        override_retval = override_retval,
        instance = util.describe_obj(instance),
    }
end

local function build_qualification_write_event(runtime, instance, method_name, hook_type, job_id, _retval)
    local target = resolve_target_from_instance(runtime, instance, hook_type)
    local trace = get_trace(runtime)
    trace.stats.qualification_writes = trace.stats.qualification_writes + 1

    return {
        name = "qualification_write_observed",
        source = HOOK_TYPES.JOB_CONTEXT,
        target = target,
        method = method_name,
        hook_type = hook_type,
        job_id = job_id,
        instance = util.describe_obj(instance),
    }
end

local function build_job_change_request_event(runtime, instance, method_name, hook_type, job_id, _retval)
    local target = resolve_target_from_instance(runtime, instance, hook_type)
    local trace = get_trace(runtime)
    trace.stats.job_change_requests = trace.stats.job_change_requests + 1

    return {
        name = "job_change_request_observed",
        source = HOOK_TYPES.JOB_CHANGER,
        target = target,
        method = method_name,
        hook_type = hook_type,
        job_id = job_id,
        instance = util.describe_obj(instance),
    }
end

function progression_trace.install_hooks(runtime)
    local trace = get_trace(runtime)
    if trace.hooks_installed then
        return true
    end
    if not config.progression_research
        or config.progression_research.enabled ~= true
        or config.progression_research.enable_runtime_hooks ~= true then
        return false
    end

    register_hook(
        "app.JobContext",
        {
            "isJobQualified(System.Int32)",
            "isJobQualified(app.Character.JobEnum)",
            "isJobQualified",
        },
        HOOK_TYPES.JOB_CONTEXT,
        build_qualification_check_event
    )

    register_hook(
        "app.JobContext",
        {
            "setJobQualified(System.Int32)",
            "setJobQualified(app.Character.JobEnum)",
            "setJobQualified",
        },
        HOOK_TYPES.JOB_CONTEXT,
        build_qualification_write_event
    )

    register_hook(
        "app.JobChanger",
        {
            "requestChangeJob(System.Int32)",
            "requestChangeJob(app.Character.JobEnum)",
            "requestChangeJob",
        },
        HOOK_TYPES.JOB_CHANGER,
        build_job_change_request_event
    )

    trace.hooks_installed = true
    log.session_marker(runtime, "system", "progression_hooks_ready", {
        installed_methods = trace.installed_methods,
        registration_errors = trace.registration_errors,
    }, string.format("hooks=%s errors=%s", tostring(#trace.installed_methods), tostring(#trace.registration_errors)))
    return true
end

function progression_trace.update(runtime)
    local trace = get_trace(runtime)
    local matrix = {}
    for _, item in pairs(trace.latest_check_matrix or {}) do
        table.insert(matrix, string.format(
            "%s job=%s result=%s code=%s direct=%s direct_code=%s bit=%s level=%s method=%s",
            tostring(item.target),
            tostring(item.job_id),
            tostring(item.result),
            tostring(item.result_hex or item.result_code),
            tostring(item.snapshot_direct),
            tostring(item.snapshot_direct_hex or item.snapshot_direct_code),
            tostring(item.snapshot_bit),
            tostring(item.snapshot_job_level),
            tostring(item.method)
        ))
    end
    table.sort(matrix)

    trace.summary = {
        hooks_installed = trace.hooks_installed,
        installed_count = #(trace.installed_methods or {}),
        registration_error_count = #(trace.registration_errors or {}),
        recent_event_count = #(trace.recent_events or {}),
        qualification_checks = trace.stats.qualification_checks,
        qualification_writes = trace.stats.qualification_writes,
        job_change_requests = trace.stats.job_change_requests,
        qualification_true = trace.stats.qualification_true,
        qualification_false = trace.stats.qualification_false,
        qualification_unknown = trace.stats.qualification_unknown,
        qualification_probe_attempts = trace.stats.qualification_probe_attempts,
        qualification_probe_applied = trace.stats.qualification_probe_applied,
        mirror_probe = trace.mirror_probe,
        latest_check_matrix = matrix,
    }
    return trace
end

return progression_trace

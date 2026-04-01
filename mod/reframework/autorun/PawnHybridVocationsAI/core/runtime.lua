local runtime = {
    initialized = false,
    runtime = {
        main_pawn = nil,
        main_pawn_data = nil,
        main_pawn_data_stable = nil,
        main_pawn_data_stable_time = nil,
        main_pawn_data_resolution_source = "unresolved",
        main_pawn_data_resolution_reason = "unresolved",
        main_pawn_data_resolution_age = nil,
        player = nil,
        progression_state_data = nil,
        hybrid_unlock_data = nil,
        game_time = 0.0,
        delta_time = 0.0,
        scheduler = {},
        scheduler_errors = {},
    },
}

local function capture_traceback(err)
    if type(debug) == "table" and type(debug.traceback) == "function" then
        return debug.traceback(tostring(err), 2)
    end

    return tostring(err)
end

function runtime.now(runtime_state)
    local current = runtime_state or runtime.runtime
    return tonumber(current and current.game_time or os.clock()) or 0.0
end

function runtime.begin_frame(runtime_state)
    local current = runtime_state or runtime.runtime
    local previous_time = tonumber(current.game_time) or 0.0

    current.game_time = os.clock()
    current.delta_time = previous_time == 0 and 0 or (current.game_time - previous_time)
    return current
end

function runtime.record_error(label, message, runtime_state)
    local current = runtime_state or runtime.runtime
    current.scheduler_errors = current.scheduler_errors or {}
    current.scheduler_errors[tostring(label or "unknown")] = {
        at = runtime.now(current),
        message = tostring(message or "unknown"),
    }
end

function runtime.clear_error(label, runtime_state)
    local current = runtime_state or runtime.runtime
    if current.scheduler_errors ~= nil then
        current.scheduler_errors[tostring(label or "unknown")] = nil
    end
end

function runtime.run_guarded(label, fn, on_error)
    if type(fn) ~= "function" then
        return nil, nil
    end

    local ok, result_or_error = xpcall(fn, capture_traceback)
    if not ok then
        runtime.record_error(label, result_or_error)
        if type(on_error) == "function" then
            on_error(tostring(label), tostring(result_or_error))
        end
        return nil, tostring(result_or_error)
    end

    runtime.clear_error(label)
    return result_or_error, nil
end

function runtime.should_run(key, interval_seconds, runtime_state)
    local current = runtime_state or runtime.runtime
    if key == nil then
        return true
    end

    local interval = tonumber(interval_seconds) or 0.0
    if interval <= 0 then
        return true
    end

    current.scheduler = current.scheduler or {}
    local last_time = tonumber(current.scheduler[key]) or -math.huge
    return (runtime.now(current) - last_time) >= interval
end

function runtime.mark(key, runtime_state)
    local current = runtime_state or runtime.runtime
    if key == nil then
        return
    end

    current.scheduler = current.scheduler or {}
    current.scheduler[key] = runtime.now(current)
end

function runtime.run_scheduled(key, interval_seconds, fn, on_error, runtime_state)
    local current = runtime_state or runtime.runtime
    if type(fn) ~= "function" then
        return false, nil, nil
    end

    if not runtime.should_run(key, interval_seconds, current) then
        return false, nil, nil
    end

    local result, err = runtime.run_guarded(key, fn, on_error)
    if err ~= nil then
        return true, nil, err
    end

    runtime.mark(key, current)
    runtime.clear_error(key, current)
    return true, result, nil
end

function runtime.reset_schedule(key, runtime_state)
    local current = runtime_state or runtime.runtime
    if key == nil or current.scheduler == nil then
        return
    end

    current.scheduler[key] = nil
end

return runtime

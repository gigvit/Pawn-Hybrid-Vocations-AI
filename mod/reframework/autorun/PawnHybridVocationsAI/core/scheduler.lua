local scheduler = {}

local function get_store(runtime)
    -- Store last-run timestamps per scheduled key.
    runtime.scheduler = runtime.scheduler or {}
    return runtime.scheduler
end

local function capture_traceback(err)
    if type(debug) == "table" and type(debug.traceback) == "function" then
        return debug.traceback(tostring(err), 2)
    end

    return tostring(err)
end

function scheduler.should_run(runtime, key, interval_seconds)
    if runtime == nil or key == nil then
        return true
    end

    local interval = tonumber(interval_seconds) or 0
    if interval <= 0 then
        return true
    end

    local now = runtime.game_time or os.clock()
    local store = get_store(runtime)
    local last_time = tonumber(store[key]) or -math.huge
    return (now - last_time) >= interval
end

function scheduler.mark(runtime, key)
    if runtime == nil or key == nil then
        return
    end

    local store = get_store(runtime)
    store[key] = runtime.game_time or os.clock()
end

function scheduler.run(runtime, key, interval_seconds, fn)
    if type(fn) ~= "function" then
        return false, nil, nil
    end

    if not scheduler.should_run(runtime, key, interval_seconds) then
        return false, nil, nil
    end

    local ok, result_or_error = xpcall(fn, capture_traceback)
    if not ok then
        if runtime ~= nil and key ~= nil then
            runtime.scheduler_errors = runtime.scheduler_errors or {}
            runtime.scheduler_errors[key] = {
                at = runtime.game_time or os.clock(),
                message = tostring(result_or_error),
            }
        end
        return true, nil, tostring(result_or_error)
    end

    scheduler.mark(runtime, key)
    if runtime ~= nil and key ~= nil and runtime.scheduler_errors ~= nil then
        runtime.scheduler_errors[key] = nil
    end
    return true, result_or_error, nil
end

function scheduler.reset(runtime, key)
    if runtime == nil or key == nil or runtime.scheduler == nil then
        return
    end

    runtime.scheduler[key] = nil
end

return scheduler

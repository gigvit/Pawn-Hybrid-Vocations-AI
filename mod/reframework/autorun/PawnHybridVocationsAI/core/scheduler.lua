local scheduler = {}

local function get_store(runtime)
    -- Store last-run timestamps per scheduled key.
    runtime.scheduler = runtime.scheduler or {}
    return runtime.scheduler
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
        return false, nil
    end

    if not scheduler.should_run(runtime, key, interval_seconds) then
        return false, nil
    end

    scheduler.mark(runtime, key)
    return true, fn()
end

function scheduler.reset(runtime, key)
    if runtime == nil or key == nil or runtime.scheduler == nil then
        return
    end

    runtime.scheduler[key] = nil
end

return scheduler

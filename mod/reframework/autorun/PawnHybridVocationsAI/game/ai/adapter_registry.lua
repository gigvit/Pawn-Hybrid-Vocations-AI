local adapter_registry = {
    entries = {},
    order = {},
}

function adapter_registry.register(spec)
    local key = tostring(spec and spec.key or "unknown_ai_adapter")
    if adapter_registry.entries[key] ~= nil then
        return adapter_registry.entries[key]
    end

    local entry = {
        key = key,
        title = tostring(spec.title or key),
        stage = tostring(spec.stage or "experimental"),
        target_jobs = spec.target_jobs or {},
        mode = tostring(spec.mode or "unspecified"),
        apply = spec.apply,
        is_enabled = spec.is_enabled,
    }

    adapter_registry.entries[key] = entry
    table.insert(adapter_registry.order, key)
    return entry
end

function adapter_registry.get(key)
    return adapter_registry.entries[key]
end

function adapter_registry.each()
    local index = 0
    return function()
        index = index + 1
        local key = adapter_registry.order[index]
        if key == nil then
            return nil
        end

        return adapter_registry.entries[key]
    end
end

function adapter_registry.count()
    return #adapter_registry.order
end

return adapter_registry

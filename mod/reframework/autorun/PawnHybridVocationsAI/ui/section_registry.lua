local section_registry = {
    entries = {},
    order = {},
}

function section_registry.register(spec)
    local key = tostring(spec and spec.key or "unknown_ui_section")
    if section_registry.entries[key] ~= nil then
        return section_registry.entries[key]
    end

    local entry = {
        key = key,
        title = tostring(spec.title or key),
        draw = spec.draw,
        is_visible = spec.is_visible,
    }

    section_registry.entries[key] = entry
    table.insert(section_registry.order, key)
    return entry
end

function section_registry.each()
    local index = 0
    return function()
        index = index + 1
        local key = section_registry.order[index]
        if key == nil then
            return nil
        end

        return section_registry.entries[key]
    end
end

function section_registry.count()
    return #section_registry.order
end

return section_registry

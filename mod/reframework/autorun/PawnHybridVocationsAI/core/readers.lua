local util = require("PawnHybridVocationsAI/core/util")

local readers = {}

local reflected_field_cache = {}

local function normalize_names(value)
    if type(value) == "table" then
        return value
    end
    if type(value) == "string" and value ~= "" then
        return { value }
    end
    return {}
end

function readers.reflected_field_first(obj, field_name)
    if obj == nil or type(obj) ~= "userdata" or type(field_name) ~= "string" or field_name == "" then
        return nil
    end

    local ok_td, td = pcall(function()
        return obj:get_type_definition()
    end)
    if not ok_td or td == nil then
        return nil
    end

    local ok_type_name, type_name = pcall(function()
        return td:get_full_name()
    end)
    if not ok_type_name or type_name == nil then
        type_name = tostring(td)
    end
    type_name = tostring(type_name)

    local type_cache = reflected_field_cache[type_name]
    if type_cache == nil then
        type_cache = {}
        reflected_field_cache[type_name] = type_cache
    end

    local reflected_field = type_cache[field_name]
    if reflected_field == false then
        return nil
    end

    if reflected_field == nil then
        local ok_fields, fields = pcall(function()
            return td:get_fields()
        end)
        if not ok_fields or type(fields) ~= "table" then
            type_cache[field_name] = false
            return nil
        end

        for _, field in ipairs(fields) do
            local ok_name, name = pcall(function()
                return field:get_name()
            end)
            if ok_name and tostring(name) == field_name then
                reflected_field = field
                type_cache[field_name] = field
                break
            end
        end

        if reflected_field == nil then
            type_cache[field_name] = false
            return nil
        end
    end

    local ok_value, value = pcall(function()
        return reflected_field:get_data(obj)
    end)
    return ok_value and value or nil
end

function readers.field_first(obj, field_names)
    if obj == nil then
        return nil
    end

    for _, field_name in ipairs(normalize_names(field_names)) do
        local value = util.safe_field(obj, field_name)
        if value ~= nil then
            return value
        end

        value = readers.reflected_field_first(obj, field_name)
        if value ~= nil then
            return value
        end
    end

    return nil
end

local function call_one(obj, method_name, ...)
    if obj == nil or type(method_name) ~= "string" or method_name == "" then
        return nil
    end

    if string.find(method_name, "(", 1, true) ~= nil then
        return util.safe_method(obj, method_name, ...)
            or util.safe_direct_method(obj, method_name, ...)
    end

    return util.safe_direct_method(obj, method_name, ...)
        or util.safe_method(obj, method_name .. "()", ...)
        or util.safe_method(obj, method_name, ...)
end

function readers.call_first(obj, methods, ...)
    if obj == nil then
        return nil
    end

    for _, method_name in ipairs(normalize_names(methods)) do
        local value = call_one(obj, method_name, ...)
        if value ~= nil then
            return value
        end
    end

    return nil
end

function readers.resolve_string_field_or_method(obj, fields, methods)
    local value = readers.field_first(obj, fields)
    if value ~= nil and tostring(value) ~= "nil" then
        return tostring(value)
    end

    value = readers.call_first(obj, methods)
    if value ~= nil and tostring(value) ~= "nil" then
        return tostring(value)
    end

    return nil
end

return readers

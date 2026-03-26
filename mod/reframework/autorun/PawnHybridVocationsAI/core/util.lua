local util = {}
local typedef_cache = {}
local singleton_cache = {
    managed = {},
    native = {},
}

local function safe_index(obj, key)
    if obj == nil then
        return nil
    end

    local ok, value = pcall(function()
        return obj[key]
    end)
    return ok and value or nil
end

function util.is_valid_obj(obj)
    if obj == nil or type(obj) ~= "userdata" then
        return false
    end

    local get_valid = safe_index(obj, "get_Valid")
    if type(get_valid) == "function" then
        local ok, value = pcall(get_valid, obj)
        if ok and value ~= nil then
            return value
        end
    end

    local ok, address = pcall(function()
        return obj:get_address()
    end)
    return ok and address ~= nil
end

function util.safe_field(obj, field_name)
    if obj == nil then
        return nil
    end

    local ok, value = pcall(function()
        return obj[field_name]
    end)
    return ok and value or nil
end

function util.safe_set_field(obj, field_name, value)
    if obj == nil then
        return false
    end

    local ok = pcall(function()
        obj[field_name] = value
    end)
    return ok
end

function util.safe_method(obj, method_name, ...)
    if obj == nil then
        return nil
    end

    local args = { ... }
    local ok, value = pcall(function()
        return obj:call(method_name, table.unpack(args))
    end)
    return ok and value or nil
end

function util.safe_direct_method(obj, method_name, ...)
    local method = safe_index(obj, method_name)
    if type(method) ~= "function" then
        return nil
    end

    local args = { ... }
    local ok, value = pcall(function()
        return method(obj, table.unpack(args))
    end)
    return ok and value or nil
end

function util.safe_sdk_typedef(type_name)
    if typedef_cache[type_name] ~= nil then
        return typedef_cache[type_name] or nil
    end

    local ok, typedef = pcall(sdk.find_type_definition, type_name)
    typedef_cache[type_name] = ok and typedef or false
    return typedef_cache[type_name] or nil
end

function util.safe_singleton(kind, name)
    local cache = singleton_cache[kind]
    if cache ~= nil and util.is_valid_obj(cache[name]) then
        return cache[name]
    end

    local getter = kind == "managed" and sdk.get_managed_singleton or sdk.get_native_singleton
    local ok, instance = pcall(getter, name)
    instance = ok and instance or nil

    if cache ~= nil then
        cache[name] = instance
    end

    return instance
end

function util.safe_create_userdata(type_name, resource_path)
    if type(type_name) ~= "string" or type_name == "" then
        return nil
    end
    if type(resource_path) ~= "string" or resource_path == "" then
        return nil
    end

    local ok, instance = pcall(sdk.create_userdata, type_name, resource_path)
    return ok and instance or nil
end

function util.resolve_game_object(source, allow_method_call)
    if source == nil then
        return nil
    end

    if util.is_a(source, "via.GameObject") then
        return source
    end

    local resolved = util.safe_field(source, "<GameObject>k__BackingField")
        or util.safe_field(source, "GameObject")
        or util.safe_field(source, "<Owner>k__BackingField")
        or util.safe_field(source, "Owner")
    if util.is_valid_obj(resolved) then
        return resolved
    end

    if allow_method_call == true then
        resolved = util.safe_direct_method(source, "get_GameObject")
            or util.safe_method(source, "get_GameObject()")
            or util.safe_method(source, "get_GameObject")
            or util.safe_direct_method(source, "get_Owner")
            or util.safe_method(source, "get_Owner()")
            or util.safe_method(source, "get_Owner")
        if util.is_valid_obj(resolved) then
            return resolved
        end
    end

    return nil
end

function util.get_type_full_name(obj)
    if obj == nil then
        return nil
    end

    local ok_td, td = pcall(function()
        return obj:get_type_definition()
    end)
    if not ok_td or td == nil then
        return nil
    end

    local ok_name, name = pcall(td.get_full_name, td)
    if not ok_name or name == nil or name == "" then
        return nil
    end

    return tostring(name)
end

function util.get_address(obj)
    if obj == nil then
        return nil
    end

    local ok, address = pcall(function()
        return obj:get_address()
    end)
    return ok and address or nil
end

function util.describe_obj(obj)
    if obj == nil then
        return "nil"
    end

    local type_name = util.get_type_full_name(obj)
    local address = util.get_address(obj)

    if type_name ~= nil and address ~= nil then
        return string.format("%s @ 0x%X", type_name, address)
    end
    if type_name ~= nil then
        return type_name
    end

    return tostring(obj)
end

function util.same_object(left, right)
    local left_addr = util.get_address(left)
    local right_addr = util.get_address(right)
    if left_addr == nil or right_addr == nil then
        return false
    end

    return left_addr == right_addr
end

function util.is_a(obj, type_name)
    if obj == nil then
        return false
    end

    local ok_td, td = pcall(function()
        return obj:get_type_definition()
    end)
    if not ok_td or td == nil then
        return false
    end

    local ok_is_a, value = pcall(function()
        return td:is_a(type_name)
    end)
    if ok_is_a then
        return value
    end

    return util.get_type_full_name(obj) == type_name
end

function util.safe_get_component(source, component_type_name)
    if source == nil or type(component_type_name) ~= "string" or component_type_name == "" then
        return nil
    end

    local game_object = util.resolve_game_object(source, false) or source

    local component_type = sdk.typeof(component_type_name)
    if component_type == nil then
        return nil
    end

    return util.safe_method(game_object, "getComponent(System.Type)", component_type)
        or util.safe_method(game_object, "getComponent", component_type)
end

function util.has_bit(mask, bit_index)
    if type(mask) ~= "number" or type(bit_index) ~= "number" or bit_index < 0 then
        return false
    end

    local divisor = 2 ^ bit_index
    return math.floor(mask / divisor) % 2 == 1
end

return util

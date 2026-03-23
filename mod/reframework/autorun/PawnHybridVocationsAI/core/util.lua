local util = {}
local typedef_cache = {}
local singleton_cache = {
    managed = {},
    native = {},
}

local function safe_index(obj, key)
    if obj == nil then
        return false, nil
    end

    local ok, value = pcall(function()
        return obj[key]
    end)

    if not ok then
        return false, nil
    end

    return true, value
end

function util.try_call(fn, ...)
    local ok, result_a, result_b, result_c = pcall(fn, ...)
    if ok then
        return true, result_a, result_b, result_c
    end

    return false, result_a
end

function util.is_valid_obj(obj)
    if obj == nil then
        return false
    end

    if type(obj) ~= "userdata" then
        return false
    end

    local ok_method, get_valid = safe_index(obj, "get_Valid")
    if ok_method and type(get_valid) == "function" then
        local ok, valid = pcall(get_valid, obj)
        if ok then
            return valid
        end
    end

    local ok_call, valid = pcall(function()
        return obj:call("get_Valid()")
    end)
    if ok_call and valid ~= nil then
        return valid
    end

    local ok_addr, addr = pcall(function()
        return obj:get_address()
    end)
    if ok_addr and addr ~= nil then
        return true
    end

    return true
end

function util.safe_field(obj, field_name)
    if obj == nil then
        return nil
    end

    local ok, value = pcall(function()
        return obj[field_name]
    end)

    if not ok then
        return nil
    end

    return value
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

    local args = {...}
    local ok, value = pcall(function()
        return obj:call(method_name, table.unpack(args))
    end)

    if not ok then
        return nil
    end

    return value
end

function util.safe_direct_method(obj, method_name, ...)
    if obj == nil then
        return nil
    end

    local ok_method, method = safe_index(obj, method_name)
    if not ok_method then
        return nil
    end
    if type(method) ~= "function" then
        return nil
    end

    local args = {...}
    local ok, value = pcall(function()
        return method(obj, table.unpack(args))
    end)

    if not ok then
        return nil
    end

    return value
end

function util.try_method(obj, method_name, ...)
    if obj == nil then
        return false
    end

    local args = {...}
    local ok = pcall(function()
        return obj:call(method_name, table.unpack(args))
    end)

    return ok
end

function util.try_method_value(obj, method_name, ...)
    if obj == nil then
        return false, nil
    end

    local args = {...}
    local ok, value = pcall(function()
        return obj:call(method_name, table.unpack(args))
    end)

    if not ok then
        return false, nil
    end

    return true, value
end

function util.try_direct_method(obj, method_name, ...)
    if obj == nil then
        return false
    end

    local ok_method, method = safe_index(obj, method_name)
    if not ok_method then
        return false
    end
    if type(method) ~= "function" then
        return false
    end

    local args = {...}
    local ok = pcall(function()
        return method(obj, table.unpack(args))
    end)

    return ok
end

function util.try_direct_method_value(obj, method_name, ...)
    if obj == nil then
        return false, nil
    end

    local ok_method, method = safe_index(obj, method_name)
    if not ok_method then
        return false, nil
    end
    if type(method) ~= "function" then
        return false, nil
    end

    local args = {...}
    local ok, value = pcall(function()
        return method(obj, table.unpack(args))
    end)

    if not ok then
        return false, nil
    end

    return true, value
end

function util.safe_sdk_typedef(type_name)
    if typedef_cache[type_name] ~= nil then
        return typedef_cache[type_name] or nil
    end

    local ok, td = pcall(sdk.find_type_definition, type_name)
    typedef_cache[type_name] = ok and td or false
    return typedef_cache[type_name] or nil
end

function util.safe_singleton(kind, name)
    local cache = singleton_cache[kind]
    if cache ~= nil and cache[name] ~= nil and util.is_valid_obj(cache[name]) then
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

function util.safe_create_instance(type_name)
    if type(type_name) ~= "string" or type_name == "" then
        return nil
    end

    local ok, instance = pcall(sdk.create_instance, type_name)
    if not ok or instance == nil then
        return nil
    end

    local ok_add_ref, add_ref = safe_index(instance, "add_ref")
    if ok_add_ref and type(add_ref) == "function" then
        local ok_ref, ref_value = pcall(add_ref, instance)
        if ok_ref and ref_value ~= nil then
            instance = ref_value
        end
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
    if not ok then
        return nil
    end

    return instance
end

function util.safe_call_native_singleton(singleton_name, type_name, method_name, ...)
    local singleton = util.safe_singleton("native", singleton_name)
    if singleton == nil then
        return nil
    end

    local typedef = util.safe_sdk_typedef(type_name)
    if typedef == nil then
        return nil
    end

    local args = {...}
    local ok, value = pcall(function()
        return sdk.call_native_func(singleton, typedef, method_name, table.unpack(args))
    end)
    if not ok then
        return nil
    end

    return value
end

function util.safe_find_game_object(scene, object_name)
    if scene == nil or type(object_name) ~= "string" or object_name == "" then
        return nil
    end

    return util.safe_method(scene, "findGameObject(System.String)", object_name)
        or util.safe_method(scene, "findGameObject", object_name)
end

function util.safe_get_component(source, component_type_name)
    if source == nil or type(component_type_name) ~= "string" or component_type_name == "" then
        return nil
    end

    local game_object = source
    if util.try_direct_method_value(source, "get_GameObject") then
        local ok_value, value = util.try_direct_method_value(source, "get_GameObject")
        game_object = ok_value and value or source
    elseif util.try_method_value(source, "get_GameObject()") then
        local ok_value, value = util.try_method_value(source, "get_GameObject()")
        game_object = ok_value and value or source
    elseif util.try_method_value(source, "get_GameObject") then
        local ok_value, value = util.try_method_value(source, "get_GameObject")
        game_object = ok_value and value or source
    end

    local component_type = sdk.typeof(component_type_name)
    if component_type == nil then
        return nil
    end

    return util.safe_method(game_object, "getComponent(System.Type)", component_type)
        or util.safe_method(game_object, "getComponent", component_type)
end

function util.safe_add_ref(obj)
    if obj == nil then
        return obj
    end

    local ok_add_ref, add_ref = safe_index(obj, "add_ref")
    if not ok_add_ref or type(add_ref) ~= "function" then
        return obj
    end

    local ok, value = pcall(add_ref, obj)
    if ok and value ~= nil then
        return value
    end

    return obj
end

function util.describe_obj(obj)
    if obj == nil then
        return "nil"
    end

    local parts = {}
    local td = nil

    local ok_td, value_td = pcall(function()
        return obj:get_type_definition()
    end)
    if ok_td then
        td = value_td
    end

    if td ~= nil then
        local ok_name, full_name = pcall(td.get_full_name, td)
        if ok_name and full_name ~= nil then
            table.insert(parts, full_name)
        end
    end

    local ok_addr, addr = pcall(function()
        return obj:get_address()
    end)
    if ok_addr and addr ~= nil then
        table.insert(parts, string.format("0x%X", addr))
    end

    return #parts > 0 and table.concat(parts, " @ ") or tostring(obj)
end

local function parse_hex_string(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end

    local value = 0
    for index = 1, #text do
        local byte = string.byte(text, index)
        local digit = nil
        if byte >= 48 and byte <= 57 then
            digit = byte - 48
        elseif byte >= 65 and byte <= 70 then
            digit = byte - 55
        elseif byte >= 97 and byte <= 102 then
            digit = byte - 87
        else
            return nil
        end
        value = value * 16 + digit
    end

    return value
end

function util.decode_numeric_like(value)
    if value == nil then
        return nil
    end

    if type(value) == "number" then
        return value
    end

    if type(value) == "boolean" then
        return value and 1 or 0
    end

    local direct = tonumber(value)
    if direct ~= nil then
        return direct
    end

    local text = tostring(value)
    local hex = text:match("^0x([0-9A-Fa-f]+)$")
        or text:match("userdata:%s*([0-9A-Fa-f]+)$")
    if hex ~= nil then
        return parse_hex_string(hex)
    end

    return nil
end

function util.decode_qualification_value(value)
    local numeric = util.decode_numeric_like(value)
    local raw = tostring(value)
    local normalized_bool = nil

    if type(value) == "boolean" then
        normalized_bool = value
    elseif numeric == 0 then
        normalized_bool = false
    elseif numeric == 1 then
        normalized_bool = true
    end

    return {
        raw = raw,
        numeric = numeric,
        normalized_bool = normalized_bool,
        is_zero = numeric == 0,
        is_nonzero = numeric ~= nil and numeric ~= 0 or false,
        hex = numeric ~= nil and string.format("0x%X", numeric) or nil,
        has_basic_flag = numeric ~= nil and (numeric % 2 == 1) or false,
        has_0x100_flag = numeric ~= nil and math.floor(numeric / 0x100) % 2 == 1 or false,
        has_0x200_flag = numeric ~= nil and math.floor(numeric / 0x200) % 2 == 1 or false,
    }
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

    local ok_name, full_name = pcall(td.get_full_name, td)
    if not ok_name or full_name == nil or full_name == "" then
        return nil
    end

    return tostring(full_name)
end

function util.get_address(obj)
    if obj == nil then
        return nil
    end

    local ok_addr, addr = pcall(function()
        return obj:get_address()
    end)

    return ok_addr and addr or nil
end

function util.get_type_method_names(obj, name_patterns, limit)
    if obj == nil then
        return {}
    end

    local td = nil
    local ok_td, value_td = pcall(function()
        return obj:get_type_definition()
    end)
    if not ok_td or value_td == nil then
        return {}
    end
    td = value_td

    local ok_methods, methods = pcall(function()
        return td:get_methods()
    end)
    if not ok_methods or methods == nil then
        return {}
    end

    local pattern_list = {}
    if type(name_patterns) == "table" then
        pattern_list = name_patterns
    elseif type(name_patterns) == "string" and name_patterns ~= "" then
        pattern_list = {name_patterns}
    end

    local max_count = tonumber(limit) or 64
    local results = {}
    local seen = {}
    for _, method in ipairs(methods) do
        if #results >= max_count then
            break
        end

        local name = nil
        local ok_name, value_name = pcall(function()
            return method:get_name()
        end)
        if ok_name and value_name ~= nil then
            name = tostring(value_name)
        end

        if name ~= nil and name ~= "" and not seen[name] then
            local include = #pattern_list == 0
            if not include then
                local lower_name = string.lower(name)
                for _, pattern in ipairs(pattern_list) do
                    local lower_pattern = string.lower(tostring(pattern))
                    if string.find(lower_name, lower_pattern, 1, true) ~= nil then
                        include = true
                        break
                    end
                end
            end

            if include then
                seen[name] = true
                table.insert(results, name)
            end
        end
    end

    table.sort(results)
    return results
end

function util.get_type_field_count(obj)
    if obj == nil then
        return 0
    end

    local ok_td, td = pcall(function()
        return obj:get_type_definition()
    end)
    if not ok_td or td == nil then
        return 0
    end

    local ok_fields, fields = pcall(function()
        return td:get_fields()
    end)
    if not ok_fields or fields == nil then
        return 0
    end

    return #fields
end

function util.get_type_member_summary(obj, method_patterns, method_limit)
    return {
        type_name = util.get_type_full_name(obj) or "nil",
        field_count = util.get_type_field_count(obj),
        methods = util.get_type_method_names(obj, method_patterns, method_limit or 16),
    }
end

function util.same_object(left, right)
    local left_addr = util.get_address(left)
    local right_addr = util.get_address(right)

    if left_addr == nil or right_addr == nil then
        return false
    end

    return left_addr == right_addr
end

function util.has_bit(mask, bit_index)
    if type(mask) ~= "number" or type(bit_index) ~= "number" or bit_index < 0 then
        return false
    end

    local divisor = 2 ^ bit_index
    return math.floor(mask / divisor) % 2 == 1
end

function util.array_to_lua(array_obj, limit)
    local results = {}
    if array_obj == nil then
        return results
    end

    local count = 0
    local limit_value = limit or 64

    local ok_count, array_count = pcall(function()
        return array_obj:get_Count()
    end)

    if ok_count and array_count ~= nil then
        count = array_count
        for i = 0, math.min(count - 1, limit_value - 1) do
            local ok_item, item = pcall(function()
                return array_obj[i]
            end)
            if ok_item then
                table.insert(results, item)
            end
        end
        return results
    end

    local ok_elements, elements = pcall(function()
        return array_obj:get_elements()
    end)
    if ok_elements and elements ~= nil then
        for i, item in pairs(elements) do
            if i > limit_value then
                break
            end
            table.insert(results, item)
        end
    end

    return results
end

function util.collection_to_lua(collection_obj, limit)
    return util.array_to_lua(collection_obj, limit)
end

function util.dictionary_values(dictionary_obj, limit)
    local results = {}
    if dictionary_obj == nil then
        return results
    end

    local enumerator = util.safe_method(dictionary_obj, "System.Collections.IDictionary.GetEnumerator()")
        or util.safe_method(dictionary_obj, "GetEnumerator()")
        or util.safe_method(dictionary_obj, "GetEnumerator")
    if enumerator == nil then
        return results
    end

    local max_items = tonumber(limit) or 256
    local index = 0
    while true do
        local moved = util.safe_direct_method(enumerator, "MoveNext")
        if moved ~= true then
            break
        end

        local current = util.safe_direct_method(enumerator, "get_Current")
            or util.safe_method(enumerator, "get_Current()")
            or util.safe_method(enumerator, "get_Current")
        local value = util.safe_field(current, "_value")
            or util.safe_field(current, "Value")
            or current
        table.insert(results, value)

        index = index + 1
        if index >= max_items then
            break
        end
    end

    return results
end

function util.get_collection_count(collection_obj)
    if collection_obj == nil then
        return nil
    end

    local count = util.safe_direct_method(collection_obj, "get_Count")
        or util.safe_method(collection_obj, "get_Count")
        or util.safe_field(collection_obj, "_size")
        or util.safe_field(collection_obj, "Count")

    if type(count) == "number" then
        return count
    end

    local items = util.collection_to_lua(collection_obj, 256)
    if #items > 0 then
        return #items
    end

    return nil
end

function util.get_array_element_type_name(array_obj)
    local type_name = util.get_type_full_name(array_obj)
    if type(type_name) ~= "string" then
        return nil
    end

    return type_name:gsub("%[%]$", "")
end

function util.clone_managed_array(array_obj, new_size)
    if not util.is_valid_obj(array_obj) then
        return nil, "array_unresolved"
    end

    local element_type = util.get_array_element_type_name(array_obj)
    if element_type == nil then
        return nil, "element_type_unresolved"
    end

    local size = new_size or util.get_collection_count(array_obj)
    if type(size) ~= "number" or size < 0 then
        return nil, "size_unresolved"
    end

    local new_array = sdk.create_managed_array(element_type, size)
    if not util.is_valid_obj(new_array) then
        return nil, "create_managed_array_failed"
    end

    local ok_add_ref, add_ref = safe_index(new_array, "add_ref")
    if ok_add_ref and type(add_ref) == "function" then
        local ok_ref, ref_value = pcall(add_ref, new_array)
        if ok_ref and ref_value ~= nil then
            new_array = ref_value
        end
    end

    local source_items = util.collection_to_lua(array_obj, size)
    for index = 0, math.min(size - 1, #source_items - 1) do
        local item = source_items[index + 1]
        local ok_set = pcall(function()
            new_array[index] = item
        end)
        if not ok_set then
            return nil, "array_copy_failed"
        end
    end

    return new_array, "cloned"
end

function util.insert_into_managed_array(array_obj, insert_index, values)
    if not util.is_valid_obj(array_obj) then
        return nil, "array_unresolved"
    end

    local source_items = util.collection_to_lua(array_obj, 256)
    local insert_items = {}

    if type(values) == "table" then
        for _, value in ipairs(values) do
            table.insert(insert_items, value)
        end
    elseif values ~= nil then
        table.insert(insert_items, values)
    end

    if #insert_items == 0 then
        return nil, "insert_values_unresolved"
    end

    local source_count = #source_items
    local normalized_index = tonumber(insert_index)
    if normalized_index == nil then
        normalized_index = source_count
    end
    normalized_index = math.max(0, math.min(normalized_index, source_count))

    local new_array, reason = util.clone_managed_array(array_obj, source_count + #insert_items)
    if not util.is_valid_obj(new_array) then
        return nil, reason
    end

    local write_index = 0
    for source_index = 0, source_count do
        if source_index == normalized_index then
            for _, item in ipairs(insert_items) do
                local ok_set = pcall(function()
                    new_array[write_index] = item
                end)
                if not ok_set then
                    return nil, "insert_write_failed"
                end
                write_index = write_index + 1
            end
        end

        local source_item = source_items[source_index + 1]
        if source_item ~= nil then
            local ok_set = pcall(function()
                new_array[write_index] = source_item
            end)
            if not ok_set then
                return nil, "copy_write_failed"
            end
            write_index = write_index + 1
        end
    end

    return new_array, "inserted"
end

function util.replace_generic_list_items(list_obj, source_list_obj)
    if not util.is_valid_obj(list_obj) then
        return false, "list_unresolved"
    end

    if not util.is_valid_obj(source_list_obj) then
        return false, "source_list_unresolved"
    end

    local source_items = util.safe_field(source_list_obj, "_items")
    local source_size = util.safe_field(source_list_obj, "_size") or util.get_collection_count(source_list_obj)
    if not util.is_valid_obj(source_items) or type(source_size) ~= "number" then
        return false, "source_backing_array_unresolved"
    end

    local cloned_items, reason = util.clone_managed_array(source_items, source_size)
    if not util.is_valid_obj(cloned_items) then
        return false, reason
    end

    local items_ok = util.safe_set_field(list_obj, "_items", cloned_items)
    local size_ok = util.safe_set_field(list_obj, "_size", source_size)

    if not items_ok then
        return false, "target_items_write_failed"
    end

    if not size_ok then
        return false, "target_size_write_failed"
    end

    return true, "backing_array_replaced"
end

function util.append_to_generic_list(list_obj, item)
    if not util.is_valid_obj(list_obj) or item == nil then
        return false, "invalid_args"
    end

    if util.try_direct_method(list_obj, "Add", item) or util.try_method(list_obj, "Add", item) then
        return true, "Add"
    end

    local current_items = util.safe_field(list_obj, "_items")
    local current_size = util.safe_field(list_obj, "_size") or util.get_collection_count(list_obj) or 0
    if not util.is_valid_obj(current_items) then
        return false, "backing_array_unresolved"
    end

    local new_items, reason = util.insert_into_managed_array(current_items, current_size, item)
    if not util.is_valid_obj(new_items) then
        return false, reason
    end

    local items_ok = util.safe_set_field(list_obj, "_items", new_items)
    local size_ok = util.safe_set_field(list_obj, "_size", current_size + 1)
    if items_ok and size_ok then
        return true, "backing_array_append"
    end

    return false, "backing_array_write_failed"
end

function util.get_typedef_name(obj)
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
    return ok_name and name or nil
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

    local ok_is_a, result = pcall(function()
        return td:is_a(type_name)
    end)
    if ok_is_a then
        return result
    end

    local ok_name, full_name = pcall(td.get_full_name, td)
    return ok_name and full_name == type_name or false
end

function util.get_fields_snapshot(obj, limit)
    local results = {}
    if obj == nil then
        return results
    end

    local ok_td, td = pcall(function()
        return obj:get_type_definition()
    end)
    if not ok_td or td == nil then
        return results
    end

    local ok_fields, fields = pcall(td.get_fields, td)
    if not ok_fields or fields == nil then
        return results
    end

    local max_items = limit or 32
    for index, field in ipairs(fields) do
        if index > max_items then
            break
        end

        local ok_name, field_name = pcall(field.get_name, field)
        local ok_value, value = pcall(field.get_data, field, obj)
        if ok_name then
            table.insert(results, {
                name = field_name,
                value = ok_value and util.describe_obj(value) or "<unreadable>",
            })
        end
    end

    return results
end

return util

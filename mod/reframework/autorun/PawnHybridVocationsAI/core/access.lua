local access = {}

local typedef_cache = {}
local singleton_cache = {
    managed = {},
    native = {},
}
local reflected_field_cache = {}

local ACTION_PACK_FIELDS = {
    "<ActionPackData>k__BackingField",
    "_ActionPackData",
    "ActionPackData",
    "<ActInterPackData>k__BackingField",
    "_ActInterPackData",
    "ActInterPackData",
    "<PackData>k__BackingField",
    "_PackData",
    "PackData",
    "<ActionPack>k__BackingField",
    "_ActionPack",
    "ActionPack",
}

local ACTION_PACK_METHODS = {
    "get_ActionPackData()",
    "get_ActInterPackData()",
    "get_PackData()",
    "get_ActionPack()",
}

local PATH_FIELDS = {
    "<Path>k__BackingField",
    "_Path",
    "Path",
    "<ResourcePath>k__BackingField",
    "_ResourcePath",
    "ResourcePath",
    "<FilePath>k__BackingField",
    "_FilePath",
    "FilePath",
}

local PATH_METHODS = {
    "get_Path()",
    "get_ResourcePath()",
    "get_FilePath()",
}

local NAME_FIELDS = {
    "<Name>k__BackingField",
    "_Name",
    "Name",
    "<ResourceName>k__BackingField",
    "_ResourceName",
    "ResourceName",
}

local NAME_METHODS = {
    "get_Name()",
    "get_ResourceName()",
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

local function normalize_names(value)
    if type(value) == "table" then
        return value
    end
    if type(value) == "string" and value ~= "" then
        return { value }
    end
    return {}
end

local function is_present_value(value)
    if value == nil then
        return false
    end
    if type(value) == "userdata" then
        return access.is_valid_obj(value)
    end

    return tostring(value) ~= "nil"
end

local function to_string_or_nil(value)
    if value == nil then
        return nil
    end

    local value_type = type(value)
    if value_type == "string" or value_type == "number" or value_type == "boolean" then
        return tostring(value)
    end

    return nil
end

local function call_one(obj, method_name, ...)
    if obj == nil or type(method_name) ~= "string" or method_name == "" then
        return nil
    end

    if string.find(method_name, "(", 1, true) ~= nil then
        return access.safe_method(obj, method_name, ...)
            or access.safe_direct_method(obj, method_name, ...)
    end

    return access.safe_direct_method(obj, method_name, ...)
        or access.safe_method(obj, method_name .. "()", ...)
        or access.safe_method(obj, method_name, ...)
end

function access.is_valid_obj(obj)
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

function access.safe_field(obj, field_name)
    if obj == nil then
        return nil
    end

    local ok, value = pcall(function()
        return obj[field_name]
    end)
    return ok and value or nil
end

function access.safe_reflected_field(obj, field_name)
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

function access.safe_set_field(obj, field_name, value)
    if obj == nil then
        return false
    end

    local ok = pcall(function()
        obj[field_name] = value
    end)
    return ok
end

function access.safe_method(obj, method_name, ...)
    if obj == nil then
        return nil
    end

    local args = { ... }
    local ok, value = pcall(function()
        return obj:call(method_name, table.unpack(args))
    end)
    return ok and value or nil
end

function access.safe_direct_method(obj, method_name, ...)
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

function access.safe_sdk_typedef(type_name)
    if typedef_cache[type_name] ~= nil then
        return typedef_cache[type_name] or nil
    end

    local ok, typedef = pcall(sdk.find_type_definition, type_name)
    typedef_cache[type_name] = ok and typedef or false
    return typedef_cache[type_name] or nil
end

function access.safe_singleton(kind, name)
    local cache = singleton_cache[kind]
    if cache ~= nil and access.is_valid_obj(cache[name]) then
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

function access.safe_create_userdata(type_name, resource_path)
    if type(type_name) ~= "string" or type_name == "" then
        return nil
    end
    if type(resource_path) ~= "string" or resource_path == "" then
        return nil
    end

    local ok, instance = pcall(sdk.create_userdata, type_name, resource_path)
    return ok and instance or nil
end

function access.resolve_game_object(source, allow_method_call)
    if source == nil then
        return nil
    end

    if access.is_a(source, "via.GameObject") then
        return source
    end

    local resolved = access.safe_field(source, "<GameObject>k__BackingField")
        or access.safe_field(source, "GameObject")
        or access.safe_field(source, "<Obj>k__BackingField")
        or access.safe_field(source, "Obj")
        or access.safe_field(source, "<Owner>k__BackingField")
        or access.safe_field(source, "Owner")
        or access.safe_reflected_field(source, "<GameObject>k__BackingField")
        or access.safe_reflected_field(source, "GameObject")
        or access.safe_reflected_field(source, "<Obj>k__BackingField")
        or access.safe_reflected_field(source, "Obj")
        or access.safe_reflected_field(source, "<Owner>k__BackingField")
        or access.safe_reflected_field(source, "Owner")
    if access.is_valid_obj(resolved) then
        return resolved
    end

    if allow_method_call == true and not access.is_a(source, "via.Component") then
        resolved = access.safe_direct_method(source, "get_GameObject")
            or access.safe_method(source, "get_GameObject()")
            or access.safe_method(source, "get_GameObject")
            or access.safe_direct_method(source, "get_Owner")
            or access.safe_method(source, "get_Owner()")
            or access.safe_method(source, "get_Owner")
        if access.is_valid_obj(resolved) then
            return resolved
        end
    end

    return nil
end

function access.get_type_full_name(obj)
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

function access.get_address(obj)
    if obj == nil then
        return nil
    end

    local ok, address = pcall(function()
        return obj:get_address()
    end)
    return ok and address or nil
end

function access.describe_obj(obj)
    if obj == nil then
        return "nil"
    end

    local type_name = access.get_type_full_name(obj)
    local address = access.get_address(obj)

    if type_name ~= nil and address ~= nil then
        return string.format("%s @ 0x%X", type_name, address)
    end
    if type_name ~= nil then
        return type_name
    end

    return tostring(obj)
end

function access.same_object(left, right)
    local left_addr = access.get_address(left)
    local right_addr = access.get_address(right)
    if left_addr == nil or right_addr == nil then
        return false
    end

    return left_addr == right_addr
end

function access.is_a(obj, type_name)
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

    return access.get_type_full_name(obj) == type_name
end

function access.safe_get_component(source, component_type_name, allow_method_call)
    if source == nil or type(component_type_name) ~= "string" or component_type_name == "" then
        return nil
    end

    local game_object = access.resolve_game_object(source, allow_method_call ~= false)
    if not access.is_valid_obj(game_object) or not access.is_a(game_object, "via.GameObject") then
        return nil
    end

    local component_type = sdk.typeof(component_type_name)
    if component_type == nil then
        return nil
    end

    return access.safe_method(game_object, "getComponent(System.Type)", component_type)
        or access.safe_method(game_object, "getComponent", component_type)
end

function access.has_bit(mask, bit_index)
    if type(mask) ~= "number" or type(bit_index) ~= "number" or bit_index < 0 then
        return false
    end

    local divisor = 2 ^ bit_index
    return math.floor(mask / divisor) % 2 == 1
end

function access.field_first(obj, field_names)
    if obj == nil then
        return nil
    end

    for _, field_name in ipairs(normalize_names(field_names)) do
        local value = access.safe_field(obj, field_name)
        if value ~= nil then
            return value
        end

        value = access.safe_reflected_field(obj, field_name)
        if value ~= nil then
            return value
        end
    end

    return nil
end

function access.call_first(obj, methods, ...)
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

function access.resolve_string_field_or_method(obj, fields, methods)
    local value = access.field_first(obj, fields)
    if value ~= nil and tostring(value) ~= "nil" then
        return tostring(value)
    end

    value = access.call_first(obj, methods)
    if value ~= nil and tostring(value) ~= "nil" then
        return tostring(value)
    end

    return nil
end

function access.present_field(obj, fields)
    for _, field_name in ipairs(fields or {}) do
        local value = access.field_first(obj, field_name)
        if is_present_value(value) then
            return value
        end
    end

    return nil
end

function access.present_method(obj, methods)
    for _, method_name in ipairs(methods or {}) do
        local value = access.call_first(obj, method_name)
        if is_present_value(value) then
            return value
        end
    end

    return nil
end

function access.resolve_pack_path(pack_data)
    return access.resolve_string_field_or_method(pack_data, PATH_FIELDS, PATH_METHODS)
end

function access.resolve_pack_name(pack_data)
    return access.resolve_string_field_or_method(pack_data, NAME_FIELDS, NAME_METHODS)
end

function access.resolve_pack_like_identity(root)
    local direct = to_string_or_nil(root)
    if direct ~= nil then
        return direct
    end

    local pack_object = access.present_field(root, ACTION_PACK_FIELDS)
    if not is_present_value(pack_object) then
        pack_object = access.present_method(root, ACTION_PACK_METHODS)
    end

    local target = is_present_value(pack_object) and pack_object or root
    local path = access.resolve_pack_path(target)
    if path ~= nil then
        return path
    end

    local name = access.resolve_pack_name(target)
    if name ~= nil then
        return name
    end

    local text = to_string_or_nil(access.call_first(target, "ToString"))
    if text ~= nil then
        return text
    end

    return access.get_type_full_name(target) or access.describe_obj(target)
end

function access.get_current_node(action_manager, layer_index)
    local fsm = access.field_first(action_manager, "Fsm")
    if not access.is_valid_obj(fsm) then
        return nil
    end

    local node_name = access.safe_method(fsm, "getCurrentNodeName(System.UInt32)", layer_index)
        or access.safe_method(fsm, "getCurrentNodeName", layer_index)
    if type(node_name) == "string" then
        return node_name
    end

    local text = node_name and access.call_first(node_name, "ToString") or nil
    return type(text) == "string" and text or nil
end

function access.resolve_decision_pack_path(decision_module, executing_decision)
    local execute_actinter = access.present_field(decision_module, {
        "_ExecuteActInter",
        "<ExecuteActInter>k__BackingField",
        "ExecuteActInter",
    })
    local execute_pack = access.call_first(execute_actinter, "get_ActInterPackData")
    if not is_present_value(execute_pack) then
        execute_pack = access.present_field(execute_actinter, {
            "<ActInterPackData>k__BackingField",
            "_ActInterPackData",
            "ActInterPackData",
        })
    end

    local execute_pack_path = access.resolve_pack_path(execute_pack)
    if execute_pack_path ~= nil then
        return execute_pack_path
    end

    local decision_pack = access.present_field(executing_decision, {
        "<ActionPackData>k__BackingField",
        "_ActionPackData",
        "ActionPackData",
    })
    if not is_present_value(decision_pack) then
        decision_pack = access.present_method(executing_decision, {
            "get_ActionPackData()",
            "get_ActionPackData",
        })
    end

    local decision_pack_path = access.resolve_pack_path(decision_pack)
    if decision_pack_path ~= nil then
        return decision_pack_path
    end

    return nil
end

function access.read_collection_count(obj)
    if obj == nil then
        return nil
    end

    return tonumber(access.call_first(obj, "get_Count"))
        or tonumber(access.call_first(obj, "get_count"))
        or tonumber(access.call_first(obj, "get_Size"))
        or tonumber(access.call_first(obj, "get_size"))
        or tonumber(access.field_first(obj, "Count"))
        or tonumber(access.field_first(obj, "count"))
        or tonumber(access.field_first(obj, "_size"))
        or tonumber(access.field_first(obj, "size"))
end

function access.read_collection_item(obj, index)
    if obj == nil or type(index) ~= "number" then
        return nil
    end

    return access.safe_method(obj, "get_Item(System.Int32)", index)
        or access.safe_method(obj, "get_Item(System.UInt32)", index)
        or access.safe_method(obj, "get_Item", index)
end

function access.decode_small_int(value)
    if type(value) == "number" then
        return value
    end

    local direct = tonumber(value)
    if direct ~= nil then
        return direct
    end

    local text = tostring(value or "")
    local hex_value = text:match("userdata:%s*(%x+)")
    if hex_value == nil then
        return nil
    end

    local parsed = tonumber(hex_value, 16)
    if parsed == nil or parsed < 0 or parsed > 4096 then
        return nil
    end

    return parsed
end

function access.decode_truthy(value)
    if type(value) == "boolean" then
        return value
    end

    local numeric = access.decode_small_int(value)
    if numeric ~= nil then
        return numeric ~= 0
    end

    local text = tostring(value or "")
    if text == "true" then
        return true
    end
    if text == "false" then
        return false
    end

    return nil
end

function access.resolve_skill_availability(skill_context)
    if skill_context == nil then
        return nil, "skill_availability_unresolved"
    end

    local direct = access.call_first(skill_context, "get_Availability")
    if direct ~= nil then
        return direct, "skill_context:get_Availability"
    end

    local method = access.safe_method(skill_context, "get_SkillAvailability()")
        or access.safe_method(skill_context, "get_SkillAvailability")
    if method ~= nil then
        return method, "skill_context:get_SkillAvailability"
    end

    local field = access.field_first(skill_context, {
        "<Availability>k__BackingField",
        "Availability",
        "<SkillAvailability>k__BackingField",
        "SkillAvailability",
    })
    if field ~= nil then
        return field, "skill_context:Availability"
    end

    return nil, "skill_availability_unresolved"
end

function access.call_is_job_qualified(job_context, job_id)
    if job_context == nil then
        return nil
    end

    return access.safe_direct_method(job_context, "isJobQualified", job_id)
        or access.safe_method(job_context, "isJobQualified(System.Int32)", job_id)
        or access.safe_method(job_context, "isJobQualified(app.Character.JobEnum)", job_id)
        or access.safe_method(job_context, "isJobQualified", job_id)
end

function access.call_get_job_level(job_context, job_id)
    if job_context == nil then
        return nil
    end

    return access.safe_direct_method(job_context, "getJobLevel", job_id)
        or access.safe_method(job_context, "getJobLevel(System.Int32)", job_id)
        or access.safe_method(job_context, "getJobLevel(app.Character.JobEnum)", job_id)
        or access.safe_method(job_context, "getJobLevel", job_id)
end

function access.call_get_custom_skill_level(skill_context, skill_id)
    if skill_context == nil or skill_id == nil then
        return nil
    end

    return access.safe_direct_method(skill_context, "getCustomSkillLevel", skill_id)
        or access.safe_method(skill_context, "getCustomSkillLevel(app.HumanCustomSkillID)", skill_id)
        or access.safe_method(skill_context, "getCustomSkillLevel", skill_id)
end

function access.call_has_equipped_skill(skill_context, job_id, skill_id)
    if skill_context == nil or job_id == nil or skill_id == nil then
        return nil
    end

    return access.safe_direct_method(skill_context, "hasEquipedSkill", job_id, skill_id)
        or access.safe_method(skill_context, "hasEquipedSkill(app.Character.JobEnum, app.HumanCustomSkillID)", job_id, skill_id)
        or access.safe_method(skill_context, "hasEquipedSkill", job_id, skill_id)
end

function access.call_is_custom_skill_enable(skill_context, skill_id)
    if skill_context == nil or skill_id == nil then
        return nil
    end

    return access.safe_direct_method(skill_context, "isCustomSkillEnable", skill_id)
        or access.safe_method(skill_context, "isCustomSkillEnable(app.HumanCustomSkillID)", skill_id)
        or access.safe_method(skill_context, "isCustomSkillEnable", skill_id)
end

function access.call_is_custom_skill_available(skill_availability, skill_id)
    if skill_availability == nil or skill_id == nil then
        return nil
    end

    return access.safe_direct_method(skill_availability, "isCustomSkillAvailable", skill_id)
        or access.safe_method(skill_availability, "isCustomSkillAvailable(app.HumanCustomSkillID)", skill_id)
        or access.safe_method(skill_availability, "isCustomSkillAvailable", skill_id)
end

return access

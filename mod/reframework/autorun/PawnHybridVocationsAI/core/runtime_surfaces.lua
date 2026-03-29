local util = require("PawnHybridVocationsAI/core/util")
local readers = require("PawnHybridVocationsAI/core/readers")

local runtime_surfaces = {}

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

local field_first = readers.field_first
local call_first = readers.call_first

local function is_present_value(value)
    if value == nil then
        return false
    end
    if type(value) == "userdata" then
        return util.is_valid_obj(value)
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

function runtime_surfaces.present_field(obj, fields)
    for _, field_name in ipairs(fields or {}) do
        local value = field_first(obj, field_name)
        if is_present_value(value) then
            return value
        end
    end

    return nil
end

function runtime_surfaces.present_method(obj, methods)
    for _, method_name in ipairs(methods or {}) do
        local value = call_first(obj, method_name)
        if is_present_value(value) then
            return value
        end
    end

    return nil
end

function runtime_surfaces.resolve_string_field_or_method(obj, fields, methods)
    return readers.resolve_string_field_or_method(obj, fields, methods)
end

function runtime_surfaces.resolve_pack_path(pack_data)
    return runtime_surfaces.resolve_string_field_or_method(pack_data, PATH_FIELDS, PATH_METHODS)
end

function runtime_surfaces.resolve_pack_name(pack_data)
    return runtime_surfaces.resolve_string_field_or_method(pack_data, NAME_FIELDS, NAME_METHODS)
end

function runtime_surfaces.resolve_pack_like_identity(root)
    local direct = to_string_or_nil(root)
    if direct ~= nil then
        return direct
    end

    local pack_object = runtime_surfaces.present_field(root, ACTION_PACK_FIELDS)
    if not is_present_value(pack_object) then
        pack_object = runtime_surfaces.present_method(root, ACTION_PACK_METHODS)
    end

    local target = is_present_value(pack_object) and pack_object or root
    local path = runtime_surfaces.resolve_pack_path(target)
    if path ~= nil then
        return path
    end

    local name = runtime_surfaces.resolve_pack_name(target)
    if name ~= nil then
        return name
    end

    local text = to_string_or_nil(call_first(target, "ToString"))
    if text ~= nil then
        return text
    end

    return util.get_type_full_name(target) or util.describe_obj(target)
end

function runtime_surfaces.get_current_node(action_manager, layer_index)
    local fsm = field_first(action_manager, "Fsm")
    if not util.is_valid_obj(fsm) then
        return nil
    end

    local node_name = util.safe_method(fsm, "getCurrentNodeName(System.UInt32)", layer_index)
        or util.safe_method(fsm, "getCurrentNodeName", layer_index)
    if type(node_name) == "string" then
        return node_name
    end

    local text = node_name and call_first(node_name, "ToString") or nil
    return type(text) == "string" and text or nil
end

function runtime_surfaces.resolve_decision_pack_path(decision_module, executing_decision)
    local execute_actinter = runtime_surfaces.present_field(decision_module, {
        "_ExecuteActInter",
        "<ExecuteActInter>k__BackingField",
        "ExecuteActInter",
    })
    local execute_pack = call_first(execute_actinter, "get_ActInterPackData")
    if not is_present_value(execute_pack) then
        execute_pack = runtime_surfaces.present_field(execute_actinter, {
            "<ActInterPackData>k__BackingField",
            "_ActInterPackData",
            "ActInterPackData",
        })
    end

    local execute_pack_path = runtime_surfaces.resolve_pack_path(execute_pack)
    if execute_pack_path ~= nil then
        return execute_pack_path
    end

    local decision_pack = runtime_surfaces.present_field(executing_decision, {
        "<ActionPackData>k__BackingField",
        "_ActionPackData",
        "ActionPackData",
    })
    if not is_present_value(decision_pack) then
        decision_pack = runtime_surfaces.present_method(executing_decision, {
            "get_ActionPackData()",
            "get_ActionPackData",
        })
    end

    local decision_pack_path = runtime_surfaces.resolve_pack_path(decision_pack)
    if decision_pack_path ~= nil then
        return decision_pack_path
    end

    return nil
end

function runtime_surfaces.read_collection_count(obj)
    if obj == nil then
        return nil
    end

    return tonumber(call_first(obj, "get_Count"))
        or tonumber(call_first(obj, "get_count"))
        or tonumber(call_first(obj, "get_Size"))
        or tonumber(call_first(obj, "get_size"))
        or tonumber(field_first(obj, "Count"))
        or tonumber(field_first(obj, "count"))
        or tonumber(field_first(obj, "_size"))
        or tonumber(field_first(obj, "size"))
end

function runtime_surfaces.read_collection_item(obj, index)
    if obj == nil or type(index) ~= "number" then
        return nil
    end

    return util.safe_method(obj, "get_Item(System.Int32)", index)
        or util.safe_method(obj, "get_Item(System.UInt32)", index)
        or util.safe_method(obj, "get_Item", index)
end

return runtime_surfaces

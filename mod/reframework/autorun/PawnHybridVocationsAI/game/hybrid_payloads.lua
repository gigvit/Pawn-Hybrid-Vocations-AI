local config = require("PawnHybridVocationsAI/config")
local access = require("PawnHybridVocationsAI/core/access")

local hybrid_payloads = {}

local ACTINTER_EXECUTE_SIGNATURE = "setBBValuesToExecuteActInter(app.AIBlackBoardController, app.ActInterPackData, app.AITarget)"
local ACTINTER_REQMAIN_SIGNATURE = "set_ReqMainActInterPackData(app.ActInterPackData)"
local REQUEST_SKIP_THINK_SIGNATURE = "requestSkipThink()"

local method_cache = {
    exec_method = nil,
    reqmain_method = nil,
    skip_think_method = nil,
}

local function merge_into(target, extra)
    if type(extra) ~= "table" then
        return target
    end

    for key, value in pairs(extra) do
        target[key] = value
    end

    return target
end

local function combat_config()
    return config.combat or {}
end

local function ensure_methods()
    if method_cache.exec_method == nil then
        local extensions_td = access.safe_sdk_typedef("app.AIBlackBoardExtensions")
        if extensions_td ~= nil then
            local ok, method = pcall(function()
                return extensions_td:get_method(ACTINTER_EXECUTE_SIGNATURE)
            end)
            method_cache.exec_method = ok and method or false
        else
            method_cache.exec_method = false
        end
    end

    if method_cache.reqmain_method == nil then
        local controller_td = access.safe_sdk_typedef("app.AIBlackBoardController")
        if controller_td ~= nil then
            local ok, method = pcall(function()
                return controller_td:get_method(ACTINTER_REQMAIN_SIGNATURE)
            end)
            method_cache.reqmain_method = ok and method or false
        else
            method_cache.reqmain_method = false
        end
    end

    if method_cache.skip_think_method == nil then
        local decision_eval_td = access.safe_sdk_typedef("app.DecisionEvaluationModule")
        if decision_eval_td ~= nil then
            local ok, method = pcall(function()
                return decision_eval_td:get_method(REQUEST_SKIP_THINK_SIGNATURE)
            end)
            if ok and method ~= nil then
                method_cache.skip_think_method = method
            end
        end
        if method_cache.skip_think_method == nil then
            local decision_td = access.safe_sdk_typedef("app.DecisionModule")
            if decision_td ~= nil then
                local ok, method = pcall(function()
                    return decision_td:get_method(REQUEST_SKIP_THINK_SIGNATURE)
                end)
                method_cache.skip_think_method = ok and method or false
            else
                method_cache.skip_think_method = false
            end
        end
    end
end

local function create_ai_target(target_info)
    if type(target_info) ~= "table" or not access.is_valid_obj(target_info.character) then
        return nil
    end

    local game_object = access.resolve_game_object(target_info.game_object or target_info.character, true)
    if not access.is_valid_obj(game_object) then
        return nil
    end

    local ok, ai_target = pcall(sdk.create_instance, "app.AITargetGameObject", true)
    if not ok or ai_target == nil then
        return nil
    end

    local transform = target_info.transform
        or access.call_first(target_info.character, "get_Transform")
        or access.call_first(game_object, "get_Transform")
    local context_holder = target_info.context_holder
        or access.field_first(target_info.character, {
            "<Context>k__BackingField",
            "Context",
        })
        or access.call_first(target_info.character, "get_Context")

    access.safe_set_field(ai_target, "<GameObject>k__BackingField", game_object)
    access.safe_set_field(ai_target, "<Character>k__BackingField", target_info.character)
    access.safe_set_field(ai_target, "<Owner>k__BackingField", game_object)
    access.safe_set_field(ai_target, "<OwnerCharacter>k__BackingField", target_info.character)
    access.safe_set_field(ai_target, "<ContextHolder>k__BackingField", context_holder)
    access.safe_set_field(ai_target, "<Transform>k__BackingField", transform)
    return ai_target
end

function hybrid_payloads.request_skip_think(context)
    ensure_methods()

    if combat_config().request_skip_think ~= true then
        return false, {
            reason = "skip_think_disabled",
        }
    end
    if method_cache.skip_think_method == false or not access.is_valid_obj(context and context.decision_module) then
        return false, {
            reason = "skip_think_unresolved",
        }
    end

    local ok, err = pcall(function()
        method_cache.skip_think_method:call(context.decision_module)
    end)

    return ok, {
        reason = ok and "ok" or "skip_think_failed",
        error = tostring(err),
    }
end

function hybrid_payloads.apply_carrier(context, target_info, pack_path)
    if type(pack_path) ~= "string" or pack_path == "" then
        return false, {
            reason = "pack_path_unresolved",
            bridge_kind = "carrier",
        }
    end

    local pack_data = access.safe_create_userdata("app.ActInterPackData", pack_path)
    if pack_data == nil then
        return false, {
            reason = "actinter_pack_create_failed",
            bridge_kind = "carrier",
            pack_path = tostring(pack_path),
        }
    end

    local ai_target = create_ai_target(target_info)
    if ai_target == nil then
        return false, {
            reason = "ai_target_create_failed",
            bridge_kind = "carrier",
            pack_path = tostring(pack_path),
        }
    end

    ensure_methods()
    if method_cache.exec_method == false
        or method_cache.reqmain_method == false
        or not access.is_valid_obj(context and context.ai_blackboard) then
        return false, {
            reason = "carrier_methods_unresolved",
            bridge_kind = "carrier",
            pack_path = tostring(pack_path),
        }
    end

    local exec_ok, exec_err = pcall(function()
        method_cache.exec_method:call(nil, context.ai_blackboard, pack_data, ai_target)
    end)
    local reqmain_ok, reqmain_err = pcall(function()
        method_cache.reqmain_method:call(context.ai_blackboard, pack_data)
    end)

    return exec_ok and reqmain_ok, {
        reason = exec_ok and reqmain_ok and "ok" or "carrier_bridge_call_failed",
        bridge_kind = "carrier",
        pack_path = tostring(pack_path),
        exec_ok = exec_ok,
        exec_err = tostring(exec_err),
        reqmain_ok = reqmain_ok,
        reqmain_err = tostring(reqmain_err),
        ai_target = access.describe_obj(ai_target),
    }
end

function hybrid_payloads.apply_action(context, action_name, action_layer, action_priority)
    if not access.is_valid_obj(context and context.action_manager) then
        return false, {
            reason = "action_manager_unresolved",
            bridge_kind = "action",
            action_name = tostring(action_name or "nil"),
        }
    end
    if type(action_name) ~= "string" or action_name == "" then
        return false, {
            reason = "action_name_unresolved",
            bridge_kind = "action",
            action_name = tostring(action_name or "nil"),
        }
    end

    local ok, err = pcall(function()
        context.action_manager:requestActionCore(
            tonumber(action_priority) or 0,
            action_name,
            tonumber(action_layer) or 0
        )
    end)

    return ok, {
        reason = ok and "ok" or "request_action_failed",
        bridge_kind = "action",
        action_name = tostring(action_name),
        action_layer = tonumber(action_layer) or 0,
        action_priority = tonumber(action_priority) or 0,
        request_err = tostring(err),
    }
end

function hybrid_payloads.apply_entry(context, target_info, entry)
    local info = {
        reason = "entry_unresolved",
        bridge_kind = "none",
        results = {},
        pack_path = tostring(entry and entry.pack_path or "nil"),
        action_name = tostring(entry and entry.action_name or "nil"),
    }
    if type(entry) ~= "table" then
        return false, info
    end

    local success = true
    local attempted = false

    if type(entry.pack_path) == "string" and entry.pack_path ~= "" then
        attempted = true
        local carrier_ok, carrier_info = hybrid_payloads.apply_carrier(context, target_info, entry.pack_path)
        info.results[#info.results + 1] = carrier_info
        success = success and carrier_ok
        info.bridge_kind = type(entry.action_name) == "string" and entry.action_name ~= "" and "hybrid" or "carrier"
    end

    if type(entry.action_name) == "string" and entry.action_name ~= "" then
        attempted = true
        local action_ok, action_info = hybrid_payloads.apply_action(
            context,
            entry.action_name,
            entry.action_layer,
            entry.action_priority
        )
        info.results[#info.results + 1] = action_info
        success = success and action_ok
        if info.bridge_kind == "none" then
            info.bridge_kind = "action"
        end
    end

    if combat_config().request_skip_think == true then
        local skip_ok, skip_info = hybrid_payloads.request_skip_think(context)
        info.results[#info.results + 1] = merge_into({
            bridge_kind = "skip_think",
        }, skip_info)
        if not attempted then
            success = success and skip_ok
        end
    end

    if not attempted then
        info.reason = "entry_empty"
        return false, info
    end

    if success then
        info.reason = "ok"
        return true, info
    end

    local failure_reasons = {}
    for _, item in ipairs(info.results) do
        if tostring(item.reason or "ok") ~= "ok" then
            failure_reasons[#failure_reasons + 1] = string.format(
                "%s=%s",
                tostring(item.bridge_kind or "bridge"),
                tostring(item.reason or "failed")
            )
        end
    end
    info.reason = #failure_reasons > 0 and table.concat(failure_reasons, ",") or "entry_failed"
    return false, info
end

return hybrid_payloads

local config = require("PawnHybridVocationsAI/config")
local state = require("PawnHybridVocationsAI/state")
local util = require("PawnHybridVocationsAI/core/util")
local discovery = require("PawnHybridVocationsAI/game/discovery")

local guild_flow_research = {}

local field_keywords = {
    "job",
    "vocation",
    "guild",
    "menu",
    "gui",
    "shop",
    "list",
    "select",
    "pawn",
    "skill",
    "flow",
}

local method_candidates = {
    "get_CurrentScene",
    "get_CurrentSceneName",
    "get_SceneName",
    "get_CurrentState",
    "get_CurrentGuiState",
    "get_CurrentMenu",
    "get_CurrentWindow",
    "get_CurrentWindowName",
    "get_FocusedWindow",
    "get_FocusedControl",
    "get_IsOpen",
    "get_IsVisible",
    "getMode",
    "ToString",
}

local confirmed_removed_hybrid_names = {
    ["Mystic Spearhand"] = true,
    ["Magick Archer"] = true,
    ["Trickster"] = true,
    ["Warfarer"] = true,
    ["Мистический копейщик"] = true,
    ["Маг-лучник"] = true,
    ["Иллюзионист"] = true,
    ["Ратник"] = true,
}

local hook_specs = {
    {
        type_name = "app.ui040101_00",
        methods = {
            { name = "setupContents(System.Int32)", extra = "slot_or_page" },
            { name = "setupCustomSkillInfoWindow" },
            { name = "setupNormalSkillInfoWindow" },
            { name = "setupJobMenu" },
            { name = "setupJobMenuContentsInfo" },
            { name = "updateJobMenu" },
            { name = "getJobInfoParam" },
            { name = "addNormalContentsList" },
            { name = "setupDisableJobs" },
            { name = "setupChara" },
            { name = "setupJobInfoWindow" },
            { name = "setupJobWeapon" },
        },
    },
    {
        type_name = "app.ui041503",
        methods = {
            { name = "setFlowId", extra = "flow_id" },
            { name = "setNowBuffSkill" },
            { name = "setSkillDetailLvReset" },
        },
    },
    {
        type_name = "app.ui060601_01",
        methods = {
            { name = "setupKeyGuide" },
            { name = "mouseSkillCtrlSelectionChanged" },
        },
    },
}

local context_owner_fields = {
    "_Owner",
    "Owner",
    "<Owner>k__BackingField",
    "_OwnerUI",
    "OwnerUI",
    "_Parent",
    "Parent",
    "_ParentWindow",
    "ParentWindow",
    "_RefUI",
    "RefUI",
    "_Gui",
    "Gui",
    "_Main",
    "Main",
    "_MainUI",
    "MainUI",
}

local context_owner_methods = {
    "get_Owner",
    "get_Parent",
    "get_ParentWindow",
    "get_RefUI",
    "get_Gui",
    "get_Main",
    "get_MainUI",
}

local last_signature = nil
local hooks_registered = false
local registration_errors = {}
local registered_hooks = {}
local skipped_hooks = {}
local get_collection_count

local source_allowlisted_ui040101_hooks = {
    getJobInfoParam = true,
    addNormalContentsList = true,
}

local function contains_keyword(text)
    if type(text) ~= "string" then
        return false
    end

    local lowered = text:lower()
    for _, keyword in ipairs(field_keywords) do
        if lowered:find(keyword, 1, true) ~= nil then
            return true
        end
    end

    return false
end

local function take_recent_tail(list, limit)
    local result = {}
    if list == nil then
        return result
    end

    local start_index = math.max(1, #list - (limit or #list) + 1)
    for index = start_index, #list do
        table.insert(result, list[index])
    end

    return result
end

local function take_recent_matching_tail(list, limit, predicate)
    local result = {}
    if list == nil then
        return result
    end

    for index = #list, 1, -1 do
        local item = list[index]
        if predicate == nil or predicate(item) then
            table.insert(result, 1, item)
            if #result >= (limit or #list) then
                break
            end
        end
    end

    return result
end

local function trim_history(list, limit)
    while #list > limit do
        table.remove(list, 1)
    end
end

local function snapshot_keyword_fields(obj)
    local matched = {}
    local count = 0

    for _, entry in ipairs(util.get_fields_snapshot(obj, config.guild_research.snapshot_limit)) do
        local field_name = tostring(entry.name)
        local value_text = tostring(entry.value)
        if contains_keyword(field_name) or contains_keyword(value_text) then
            matched[field_name] = value_text
            count = count + 1
            if count >= config.guild_research.tracked_field_limit then
                break
            end
        end
    end

    return matched
end

local function take_keyword_field_lines(obj, limit)
    local lines = {}
    local fields = snapshot_keyword_fields(obj)
    local keys = {}

    for key, _ in pairs(fields) do
        table.insert(keys, key)
    end
    table.sort(keys)

    for index, key in ipairs(keys) do
        if index > (limit or 8) then
            break
        end
        table.insert(lines, tostring(key) .. "=" .. tostring(fields[key]))
    end

    return lines
end

local function take_field_snapshot_lines(obj, limit)
    local lines = {}
    for index, entry in ipairs(util.get_fields_snapshot(obj, limit or 16)) do
        table.insert(lines, string.format("%02d:%s=%s", index, tostring(entry.name), tostring(entry.value)))
    end
    return lines
end

local function take_method_inventory_lines(obj, limit)
    local lines = {}
    if obj == nil then
        return lines
    end

    local ok_td, td = pcall(function()
        return obj:get_type_definition()
    end)
    if not ok_td or td == nil then
        return lines
    end

    local ok_methods, methods = pcall(td.get_methods, td)
    if not ok_methods or methods == nil then
        return lines
    end

    local filtered = {}
    for _, method in ipairs(methods) do
        local ok_name, method_name = pcall(method.get_name, method)
        if ok_name and contains_keyword(method_name) then
            table.insert(filtered, method_name)
        end
    end

    table.sort(filtered)
    for index, method_name in ipairs(filtered) do
        if index > (limit or 24) then
            break
        end
        table.insert(lines, string.format("%02d:%s", index, tostring(method_name)))
    end

    return lines
end

local function describe_hook_value(value)
    if value == nil then
        return "nil"
    end

    local value_type = type(value)
    if value_type == "userdata" then
        return util.describe_obj(value)
    end

    return tostring(value)
end

local function resolve_hook_retval(retval)
    if retval == nil then
        return nil, "nil"
    end

    local ok_obj, managed_obj = pcall(sdk.to_managed_object, retval)
    if ok_obj and util.is_valid_obj(managed_obj) then
        return managed_obj, util.describe_obj(managed_obj)
    end

    if util.is_valid_obj(retval) then
        return retval, util.describe_obj(retval)
    end

    return nil, describe_hook_value(retval)
end

local function summarize_hook_args(args, start_index, max_count)
    local parts = {}
    local index = start_index or 3
    local limit = max_count or 4

    while #parts < limit do
        local ok_value, value = pcall(function()
            return args[index]
        end)
        if not ok_value then
            break
        end

        if value == nil then
            break
        end

        table.insert(parts, string.format("arg%d=%s", index - 2, describe_hook_value(value)))
        index = index + 1
    end

    return table.concat(parts, ", ")
end

local function capture_source_arg_descriptions(args, start_index, max_count)
    local lines = {}
    local index = start_index or 3
    local limit = max_count or 3

    while #lines < limit do
        local ok_value, value = pcall(function()
            return args[index]
        end)
        if not ok_value or value == nil then
            break
        end

        local resolved_obj = nil
        local ok_obj, managed_obj = pcall(sdk.to_managed_object, value)
        if ok_obj and util.is_valid_obj(managed_obj) then
            resolved_obj = managed_obj
        elseif util.is_valid_obj(value) then
            resolved_obj = value
        end

        if resolved_obj ~= nil then
            table.insert(lines, string.format(
                "arg%d=%s",
                index - 2,
                util.describe_obj(resolved_obj)
            ))
        else
            table.insert(lines, string.format(
                "arg%d=%s",
                index - 2,
                describe_hook_value(value)
            ))
        end

        index = index + 1
    end

    return lines
end

local function find_first_field(obj, candidates)
    for _, field_name in ipairs(candidates) do
        local value = util.safe_field(obj, field_name)
        if value ~= nil then
            return value, field_name
        end
    end

    return nil, "unresolved"
end

local function try_assign_first_field(obj, candidates, value)
    if not util.is_valid_obj(obj) then
        return false, "invalid_object"
    end

    for _, field_name in ipairs(candidates) do
        if util.safe_set_field(obj, field_name, value) then
            return true, field_name
        end
    end

    return false, "write_failed"
end

local function take_first_collection_entry(collection_obj)
    local items = util.collection_to_lua(collection_obj, 1)
    return items[1]
end

local function take_last_collection_entry(collection_obj, limit)
    local items = util.collection_to_lua(collection_obj, limit or 32)
    return items[#items]
end

local function take_collection_entry_at(collection_obj, index)
    if collection_obj == nil or type(index) ~= "number" or index < 0 then
        return nil
    end

    local item = util.safe_direct_method(collection_obj, "get_Item", index)
        or util.safe_method(collection_obj, "get_Item", index)
    if item ~= nil then
        return item
    end

    local items = util.collection_to_lua(collection_obj, index + 1)
    return items[index + 1]
end

local function read_list_ctrl_index(list_ctrl)
    if not util.is_valid_obj(list_ctrl) then
        return nil, "list_ctrl_unresolved"
    end

    local candidates = {
        { source = "_CurrentIndex", value = util.safe_field(list_ctrl, "_CurrentIndex") },
        { source = "CurrentIndex", value = util.safe_field(list_ctrl, "CurrentIndex") },
        { source = "_SelectIndex", value = util.safe_field(list_ctrl, "_SelectIndex") },
        { source = "SelectIndex", value = util.safe_field(list_ctrl, "SelectIndex") },
        { source = "_CursorIndex", value = util.safe_field(list_ctrl, "_CursorIndex") },
        { source = "CursorIndex", value = util.safe_field(list_ctrl, "CursorIndex") },
        { source = "_SelectedIndex", value = util.safe_field(list_ctrl, "_SelectedIndex") },
        { source = "SelectedIndex", value = util.safe_field(list_ctrl, "SelectedIndex") },
        { source = "_DecideIndex", value = util.safe_field(list_ctrl, "_DecideIndex") },
        { source = "DecideIndex", value = util.safe_field(list_ctrl, "DecideIndex") },
        { source = "_NowIndex", value = util.safe_field(list_ctrl, "_NowIndex") },
        { source = "NowIndex", value = util.safe_field(list_ctrl, "NowIndex") },
        { source = "get_CurrentIndex", value = util.safe_direct_method(list_ctrl, "get_CurrentIndex") or util.safe_method(list_ctrl, "get_CurrentIndex") },
        { source = "get_SelectIndex", value = util.safe_direct_method(list_ctrl, "get_SelectIndex") or util.safe_method(list_ctrl, "get_SelectIndex") },
        { source = "get_CursorIndex", value = util.safe_direct_method(list_ctrl, "get_CursorIndex") or util.safe_method(list_ctrl, "get_CursorIndex") },
        { source = "get_SelectedIndex", value = util.safe_direct_method(list_ctrl, "get_SelectedIndex") or util.safe_method(list_ctrl, "get_SelectedIndex") },
        { source = "get_DecideIndex", value = util.safe_direct_method(list_ctrl, "get_DecideIndex") or util.safe_method(list_ctrl, "get_DecideIndex") },
        { source = "get_NowIndex", value = util.safe_direct_method(list_ctrl, "get_NowIndex") or util.safe_method(list_ctrl, "get_NowIndex") },
    }

    for _, candidate in ipairs(candidates) do
        local index = tonumber(candidate.value)
        if index ~= nil and index >= 0 and index < 64 then
            return index, candidate.source
        end
    end

    return nil, "index_unresolved"
end

local function is_selected_item_flag(value)
    if value == true then
        return true
    end

    if type(value) == "number" then
        return value ~= 0
    end

    local text = tostring(value or ""):lower()
    return text == "true" or text == "1"
end

local function find_index_for_item_reference(item_list, target_item, limit)
    if not util.is_valid_obj(item_list) or not util.is_valid_obj(target_item) then
        return nil
    end

    local items = util.collection_to_lua(item_list, limit or 24)
    for index, item in ipairs(items) do
        if util.same_object(item, target_item) then
            return index - 1
        end
    end

    return nil
end

local function resolve_selected_item_index(item_list, list_ctrl)
    local list_ctrl_item_candidates = {
        "_CurrentItem",
        "CurrentItem",
        "_SelectItem",
        "SelectItem",
        "_SelectedItem",
        "SelectedItem",
        "_CursorItem",
        "CursorItem",
        "_FocusItem",
        "FocusItem",
    }

    for _, field_name in ipairs(list_ctrl_item_candidates) do
        local item = util.safe_field(list_ctrl, field_name)
        local index = find_index_for_item_reference(item_list, item, 24)
        if index ~= nil then
            return index, "list_ctrl." .. field_name
        end
    end

    local list_ctrl_item_methods = {
        "get_CurrentItem",
        "get_SelectItem",
        "get_SelectedItem",
        "get_CursorItem",
        "get_FocusItem",
    }

    for _, method_name in ipairs(list_ctrl_item_methods) do
        local item = util.safe_direct_method(list_ctrl, method_name)
            or util.safe_method(list_ctrl, method_name)
        local index = find_index_for_item_reference(item_list, item, 24)
        if index ~= nil then
            return index, "list_ctrl." .. method_name
        end
    end

    local items = util.collection_to_lua(item_list, 24)
    local selected_fields = {
        "_IsSelected",
        "IsSelected",
        "_IsSelect",
        "IsSelect",
        "_IsFocus",
        "IsFocus",
        "_IsCursor",
        "IsCursor",
        "_IsCurrent",
        "IsCurrent",
        "_Selected",
        "Selected",
    }
    local selected_methods = {
        "get_IsSelected",
        "get_IsSelect",
        "get_IsFocus",
        "get_IsCursor",
        "get_IsCurrent",
    }

    for index, item in ipairs(items) do
        if util.is_valid_obj(item) then
            for _, field_name in ipairs(selected_fields) do
                if is_selected_item_flag(util.safe_field(item, field_name)) then
                    return index - 1, "item." .. field_name
                end
            end

            for _, method_name in ipairs(selected_methods) do
                local value = util.safe_direct_method(item, method_name)
                    or util.safe_method(item, method_name)
                if is_selected_item_flag(value) then
                    return index - 1, "item." .. method_name
                end
            end
        end
    end

    return nil, "selected_item_unresolved"
end

local function read_job_id_from_job_info(job_info)
    if not util.is_valid_obj(job_info) then
        return nil
    end

    return util.safe_field(job_info, "_JobID")
        or util.safe_field(job_info, "JobID")
        or util.safe_field(job_info, "_Id")
        or util.safe_field(job_info, "Id")
        or util.safe_direct_method(job_info, "get_JobID")
        or util.safe_method(job_info, "get_JobID")
        or util.safe_direct_method(job_info, "get_Id")
        or util.safe_method(job_info, "get_Id")
end

local function build_info_entry_probe_summary(entry)
    if not util.is_valid_obj(entry) then
        return nil
    end

    local job_info = util.safe_field(entry, "Job")

    return {
        name = util.safe_field(entry, "Name"),
        panel_state = util.safe_field(entry, "PanelState"),
        job_rank = util.safe_field(entry, "JobRank"),
        is_prohibit = util.safe_field(entry, "isProhibit"),
        is_equip = util.safe_field(entry, "isEquip"),
        contents_type = util.safe_field(entry, "ContenstsType"),
        job_id = read_job_id_from_job_info(job_info),
        job = util.describe_obj(job_info),
    }
end

local function format_info_entry_probe_summary(summary)
    if summary == nil then
        return nil
    end

    return string.format(
        "name=%s | rank=%s | state=%s | prohibit=%s | equip=%s | type=%s | job_id=%s | job=%s",
        tostring(summary.name),
        tostring(summary.job_rank),
        tostring(summary.panel_state),
        tostring(summary.is_prohibit),
        tostring(summary.is_equip),
        tostring(summary.contents_type),
        tostring(summary.job_id),
        tostring(summary.job)
    )
end

local function describe_collection_entries(collection_obj, limit)
    local lines = {}
    local index = 0

    for _, item in ipairs(util.collection_to_lua(collection_obj, limit or 8)) do
        index = index + 1
        local parts = {
            string.format("#%d", index),
            util.describe_obj(item),
        }

        local field_lines = take_field_snapshot_lines(item, 16)
        if #field_lines > 0 then
            table.insert(parts, table.concat(field_lines, "; "))
        end

        table.insert(lines, table.concat(parts, " | "))
    end

    return lines
end

local function build_info_entry_names(info_list, limit)
    local names = {}
    for _, item in ipairs(util.collection_to_lua(info_list, limit or 16)) do
        local name = util.safe_field(item, "Name")
        local job_rank = util.safe_field(item, "JobRank")
        local panel_state = util.safe_field(item, "PanelState")
        local is_prohibit = util.safe_field(item, "isProhibit")
        local is_equip = util.safe_field(item, "isEquip")
        table.insert(names, string.format(
            "%s | rank=%s | state=%s | prohibit=%s | equip=%s",
            tostring(name),
            tostring(job_rank),
            tostring(panel_state),
            tostring(is_prohibit),
            tostring(is_equip)
        ))
    end
    return names
end

local function extract_info_entry_job_names(info_name_lines)
    local names = {}
    local seen = {}

    for _, line in ipairs(info_name_lines or {}) do
        local name = tostring(line):match("^(.-)%s*|")
        if name ~= nil then
            name = name:match("^%s*(.-)%s*$")
            if name ~= "" and not seen[name] then
                seen[name] = true
                table.insert(names, name)
            end
        end
    end

    table.sort(names)
    return names
end

local function build_missing_name_lines(reference_names, candidate_names)
    local lines = {}
    local candidate_lookup = {}

    for _, name in ipairs(candidate_names or {}) do
        candidate_lookup[tostring(name)] = true
    end

    for _, name in ipairs(reference_names or {}) do
        if not candidate_lookup[tostring(name)] then
            table.insert(lines, tostring(name))
        end
    end

    return lines
end

local function build_removed_info_names(previous_info_name_lines, current_info_name_lines)
    local previous_names = extract_info_entry_job_names(previous_info_name_lines)
    local current_names = extract_info_entry_job_names(current_info_name_lines)

    local removed_names = build_missing_name_lines(previous_names, current_names)
    if #removed_names > 0 then
        return removed_names
    end

    if type(previous_info_name_lines) ~= "table" or type(current_info_name_lines) ~= "table" then
        return nil
    end

    local current_lookup = {}
    for _, line in ipairs(current_info_name_lines) do
        current_lookup[tostring(line)] = true
    end

    local removed_lines = {}
    for _, line in ipairs(previous_info_name_lines) do
        local key = tostring(line)
        if not current_lookup[key] then
            table.insert(removed_lines, key)
        end
    end

    if #removed_lines > 0 then
        return removed_lines
    end

    return nil
end

local function should_attempt_prune_bypass(snapshot)
    if config.guild_research.enable_prune_bypass_probe ~= true then
        return false, "probe_disabled"
    end

    if snapshot == nil then
        return false, "snapshot_unresolved"
    end

    if tonumber(snapshot.delta_info_count) ~= -4 then
        return false, "delta_mismatch"
    end

    if tonumber(snapshot.previous_info_count) ~= 10 or tonumber(snapshot.info_count) ~= 6 then
        return false, "count_mismatch"
    end

    if type(snapshot.removed_info_names) ~= "table" or #snapshot.removed_info_names ~= 4 then
        return false, "removed_entries_unresolved"
    end

    for _, name in ipairs(snapshot.removed_info_names) do
        if not confirmed_removed_hybrid_names[tostring(name)] then
            return false, "removed_entries_unexpected"
        end
    end

    if not util.is_valid_obj(snapshot.list_ctrl_ref) then
        return false, "list_ctrl_unresolved"
    end

    if not util.is_valid_obj(snapshot.previous_info_list_ref) then
        return false, "previous_info_list_unresolved"
    end

    return true, "ready"
end

local function is_confirmed_vocation_prune_snapshot(snapshot)
    if snapshot == nil then
        return false
    end

    if tonumber(snapshot.delta_info_count) ~= -4 then
        return false
    end

    if tonumber(snapshot.previous_info_count) ~= 10 or tonumber(snapshot.info_count) ~= 6 then
        return false
    end

    if type(snapshot.removed_info_names) ~= "table" or #snapshot.removed_info_names ~= 4 then
        return false
    end

    for _, name in ipairs(snapshot.removed_info_names) do
        if not confirmed_removed_hybrid_names[tostring(name)] then
            return false
        end
    end

    return true
end

local function attempt_prune_bypass(snapshot)
    local ok, reason = should_attempt_prune_bypass(snapshot)
    local result = {
        enabled = config.guild_research.enable_prune_bypass_probe == true,
        attempted = false,
        ok = false,
        reason = reason,
        target = snapshot and snapshot.event_target_name or "unknown",
        time = snapshot and snapshot.time or "0",
        selected_chara_id = snapshot and snapshot.selected_chara_id or nil,
        previous_info_count = snapshot and snapshot.previous_info_count or nil,
        info_count = snapshot and snapshot.info_count or nil,
        removed_info_names = snapshot and snapshot.removed_info_names or nil,
        info_field = nil,
        item_field = nil,
    }

    if not ok then
        return result
    end

    result.attempted = true

    local info_ok, info_field = try_assign_first_field(snapshot.list_ctrl_ref, {
        "_InfoList",
        "_InfoDataList",
        "_ItemInfoList",
        "_ItemDataList",
        "_List",
        "InfoList",
    }, snapshot.previous_info_list_ref)
    result.info_field = info_field

    local item_ok = true
    local item_field = "not_attempted"
    if util.is_valid_obj(snapshot.previous_item_list_ref) then
        item_ok, item_field = try_assign_first_field(snapshot.list_ctrl_ref, {
            "_ItemList",
            "_ItemCtrlList",
            "ItemList",
        }, snapshot.previous_item_list_ref)
    end
    result.item_field = item_field

    result.ok = info_ok and item_ok
    result.reason = result.ok and "previous_lists_reassigned" or "reassign_failed"
    return result
end

local function build_name_to_index_map(info_name_lines)
    local map = {}
    local names = extract_info_entry_job_names(info_name_lines)
    for index, name in ipairs(names) do
        if map[tostring(name)] == nil then
            map[tostring(name)] = index - 1
        end
    end
    return map
end

local function collection_contains_object(collection_obj, target_obj, limit)
    if not util.is_valid_obj(collection_obj) or not util.is_valid_obj(target_obj) then
        return false
    end

    for _, item in ipairs(util.collection_to_lua(collection_obj, limit or 32)) do
        if util.same_object(item, target_obj) then
            return true
        end
    end

    return false
end

local function try_add_collection_entry(collection_obj, entry)
    if not util.is_valid_obj(collection_obj) or not util.is_valid_obj(entry) then
        return false, "invalid_args"
    end

    if util.try_direct_method(collection_obj, "Add", entry) then
        return true, "Add"
    end

    if util.try_method(collection_obj, "Add", entry) then
        return true, "Add"
    end

    local append_ok, append_method = util.append_to_generic_list(collection_obj, entry)
    if append_ok then
        return true, append_method
    end

    local count = get_collection_count(collection_obj)
    if type(count) == "number" then
        if util.try_direct_method(collection_obj, "Insert", count, entry) then
            return true, "Insert"
        end
        if util.try_method(collection_obj, "Insert", count, entry) then
            return true, "Insert"
        end
    end

    return false, "add_failed"
end

local function try_bulk_rebuild_info_list(snapshot)
    if snapshot == nil then
        return false, "snapshot_unresolved"
    end

    if not util.is_valid_obj(snapshot.current_info_list_ref) or not util.is_valid_obj(snapshot.previous_info_list_ref) then
        return false, "info_lists_unresolved"
    end

    return util.replace_generic_list_items(snapshot.current_info_list_ref, snapshot.previous_info_list_ref)
end

local function try_bulk_rebuild_item_array(snapshot)
    if snapshot == nil then
        return false, "snapshot_unresolved"
    end

    if not util.is_valid_obj(snapshot.list_ctrl_ref) then
        return false, "list_ctrl_unresolved"
    end

    if not util.is_valid_obj(snapshot.previous_item_list_ref) then
        return false, "previous_item_list_unresolved"
    end

    local cloned_array, clone_reason = util.clone_managed_array(snapshot.previous_item_list_ref)
    if not util.is_valid_obj(cloned_array) then
        return false, clone_reason
    end

    local ok, field_name = try_assign_first_field(snapshot.list_ctrl_ref, {
        "_ItemList",
        "_ItemCtrlList",
        "ItemList",
    }, cloned_array)

    if ok then
        snapshot.current_item_list_ref = cloned_array
        return true, "array_reassigned:" .. tostring(field_name)
    end

    return false, "item_array_write_failed"
end

local function try_refresh_after_reinjection(snapshot)
    local atomic_window = nil
    local tried_methods = {}
    local successful_methods = {}
    local function capture_atomic_detail(target_label, method_name)
        if target_label ~= "ui" or method_name ~= "updateJobMenu" then
            return nil
        end
        local detail = build_light_ui_detail(snapshot and snapshot.ui_ref or nil)
        if detail == nil then
            return nil
        end
        return {
            info_count = detail.info_count,
            item_count = detail.item_count,
            current_index = detail.current_index,
            current_index_source = detail.current_index_source,
            selected_index_source = detail.selected_index_source,
            flow_now = detail.flow_now,
            info_name_lines = detail.info_name_lines or {},
            ui_field_lines = take_keyword_field_lines(detail.ui_ref, 12),
            list_ctrl_field_lines = take_keyword_field_lines(detail.main_contents_list_ctrl, 12),
        }
    end
    local function finalize_atomic_window(target_label, method_name, before_detail)
        if before_detail == nil then
            return
        end
        local after_detail = capture_atomic_detail(target_label, method_name)
        if after_detail == nil then
            return
        end
        local removed_entries, added_entries = build_line_set_diff(before_detail.info_name_lines, after_detail.info_name_lines)
        local removed_ui_fields, added_ui_fields = build_line_set_diff(before_detail.ui_field_lines, after_detail.ui_field_lines)
        local removed_list_fields, added_list_fields = build_line_set_diff(before_detail.list_ctrl_field_lines, after_detail.list_ctrl_field_lines)
        atomic_window = {
            method = method_name,
            info_before = before_detail.info_count,
            info_after = after_detail.info_count,
            item_before = before_detail.item_count,
            item_after = after_detail.item_count,
            current_index_before = before_detail.current_index,
            current_index_after = after_detail.current_index,
            current_index_source_before = before_detail.current_index_source,
            current_index_source_after = after_detail.current_index_source,
            flow_now_before = before_detail.flow_now,
            flow_now_after = after_detail.flow_now,
            removed_entries = removed_entries,
            added_entries = added_entries,
            before_entries = before_detail.info_name_lines,
            after_entries = after_detail.info_name_lines,
            removed_ui_fields = removed_ui_fields,
            added_ui_fields = added_ui_fields,
            removed_list_ctrl_fields = removed_list_fields,
            added_list_ctrl_fields = added_list_fields,
        }
    end
    local function record_try(target_label, method_name, arg_label)
        table.insert(tried_methods, string.format(
            "%s:%s%s",
            tostring(target_label),
            tostring(method_name),
            arg_label and ("(" .. tostring(arg_label) .. ")") or "()"
        ))
    end
    local function record_success(target_label, method_name, arg_label)
        table.insert(successful_methods, string.format(
            "%s:%s%s",
            tostring(target_label),
            tostring(method_name),
            arg_label and ("(" .. tostring(arg_label) .. ")") or "()"
        ))
    end

    local targets = {
        { label = "ui", obj = snapshot and snapshot.ui_ref or nil },
        { label = "list_ctrl", obj = snapshot and snapshot.list_ctrl_ref or nil },
    }

    local list_ctrl_no_arg_methods = {
        "update",
        "updateList",
        "updateContents",
        "updateSelect",
    }

    local ui_no_arg_methods = {
        "updateJobMenu",
        "update",
        "updateFlow",
    }

    local touched = {}
    for _, target_info in ipairs(targets) do
        local target = target_info.obj
        local target_label = target_info.label
        if util.is_valid_obj(target) and not touched[util.get_address(target)] then
            touched[util.get_address(target)] = true
            local methods = target_label == "ui" and ui_no_arg_methods or list_ctrl_no_arg_methods
            for _, method_name in ipairs(methods) do
                record_try(target_label, method_name, nil)
                local before_detail = capture_atomic_detail(target_label, method_name)
                if util.try_direct_method(target, method_name) or util.try_method(target, method_name) then
                    finalize_atomic_window(target_label, method_name, before_detail)
                    record_success(target_label, method_name, nil)
                    return true, table.concat(successful_methods, " -> "), tried_methods, atomic_window
                end
            end
        end
    end

    if util.is_valid_obj(snapshot and snapshot.list_ctrl_ref or nil) then
        local list_ctrl = snapshot.list_ctrl_ref
        local arg_candidates = {
            { method = "setItemAll", arg = snapshot and snapshot.current_item_list_ref or nil, label = "item_list" },
            { method = "setItemAll", arg = snapshot and snapshot.current_info_list_ref or nil, label = "info_list" },
            { method = "setContents", arg = snapshot and snapshot.current_info_list_ref or nil, label = "info_list" },
            { method = "setContents", arg = snapshot and snapshot.current_item_list_ref or nil, label = "item_list" },
            { method = "updateContents", arg = snapshot and snapshot.current_info_list_ref or nil, label = "info_list" },
            { method = "updateContents", arg = snapshot and snapshot.current_item_list_ref or nil, label = "item_list" },
        }

        for _, candidate in ipairs(arg_candidates) do
            if candidate.arg ~= nil then
                record_try("list_ctrl", candidate.method, candidate.label)
                if util.try_direct_method(list_ctrl, candidate.method, candidate.arg)
                    or util.try_method(list_ctrl, candidate.method, candidate.arg)
                then
                    record_success("list_ctrl", candidate.method, candidate.label)
                    return true, table.concat(successful_methods, " -> "), tried_methods, atomic_window
                end
            end
        end
    end

    if util.is_valid_obj(snapshot and snapshot.ui_ref or nil) then
        local ui_ref = snapshot.ui_ref
        local flow_now = tonumber(snapshot and snapshot.flow_now or nil)
        if flow_now ~= nil then
            record_try("ui", "setupContents", "flow_now")
            if util.try_direct_method(ui_ref, "setupContents", flow_now)
                or util.try_method(ui_ref, "setupContents(System.Int32)", flow_now)
                or util.try_method(ui_ref, "setupContents", flow_now)
            then
                record_success("ui", "setupContents", "flow_now")
                return true, table.concat(successful_methods, " -> "), tried_methods, atomic_window
            end
        end

        local ui_arg_candidates = {
            { method = "setupJobMenuContentsInfo", arg = snapshot and snapshot.current_info_list_ref or nil, label = "info_list" },
        }
        for _, candidate in ipairs(ui_arg_candidates) do
            if candidate.arg ~= nil then
                record_try("ui", candidate.method, candidate.label)
                if util.try_direct_method(ui_ref, candidate.method, candidate.arg)
                    or util.try_method(ui_ref, candidate.method, candidate.arg)
                then
                    record_success("ui", candidate.method, candidate.label)
                    return true, table.concat(successful_methods, " -> "), tried_methods, atomic_window
                end
            end
        end
    end

    return false, "refresh_unresolved", tried_methods, atomic_window
end

local function attempt_post_prune_reinjection(snapshot)
    local result = {
        enabled = config.guild_research.enable_post_prune_reinjection == true,
        attempted = false,
        ok = false,
        reason = "not_attempted",
        target = snapshot and snapshot.event_target_name or "unknown",
        time = snapshot and snapshot.time or "0",
        selected_chara_id = snapshot and snapshot.selected_chara_id or nil,
        before_info_count = snapshot and snapshot.info_count or nil,
        after_info_count = snapshot and snapshot.info_count or nil,
        before_item_count = snapshot and snapshot.item_count or nil,
        after_item_count = snapshot and snapshot.item_count or nil,
        removed_info_names = snapshot and snapshot.removed_info_names or nil,
        reinserted_entries = {},
        info_add_ok = false,
        item_add_ok = false,
        info_add_method = "not_attempted",
        item_add_method = "not_attempted",
        refresh_attempted = false,
        refresh_ok = false,
        refresh_method = "not_attempted",
        refresh_candidates = {},
        refresh_success_chain = "",
        atomic_refresh_window = nil,
        after_info_names = {},
    }

    if config.guild_research.enable_post_prune_reinjection ~= true then
        result.reason = "reinjection_disabled"
        return result
    end

    if snapshot == nil then
        result.reason = "snapshot_unresolved"
        return result
    end

    if type(snapshot.removed_info_names) ~= "table" or #snapshot.removed_info_names ~= 4 then
        result.reason = "removed_entries_unresolved"
        return result
    end

    if not util.is_valid_obj(snapshot.previous_info_list_ref) or not util.is_valid_obj(snapshot.current_info_list_ref) then
        result.reason = "info_lists_unresolved"
        return result
    end

    result.attempted = true
    local previous_name_to_index = build_name_to_index_map(snapshot.previous_info_name_lines)

    for _, name in ipairs(snapshot.removed_info_names) do
        local source_index = previous_name_to_index[tostring(name)]
        table.insert(result.reinserted_entries, string.format(
            "%s(info=%s,item=%s,index=%s)",
            tostring(name),
            "pending",
            "pending",
            tostring(source_index or "unresolved")
        ))
    end

    local info_any_ok, info_method = try_bulk_rebuild_info_list(snapshot)
    local item_any_ok, item_method = try_bulk_rebuild_item_array(snapshot)

    result.info_add_ok = info_any_ok
    result.item_add_ok = item_any_ok
    result.info_add_method = info_method
    result.item_add_method = item_method
    if info_any_ok or item_any_ok then
        result.refresh_attempted = true
        result.refresh_ok, result.refresh_method, result.refresh_candidates, result.atomic_refresh_window = try_refresh_after_reinjection(snapshot)
        result.refresh_success_chain = result.refresh_method
    end

    if type(result.refresh_candidates) ~= "table" then
        result.refresh_candidates = {}
    end

    result.list_ctrl_refresh_methods = util.get_type_method_names(snapshot.list_ctrl_ref, {
        "update",
        "refresh",
        "setitem",
        "setcontents",
        "rebuild",
        "reset",
    }, 24)
    result.ui_refresh_methods = util.get_type_method_names(snapshot.ui_ref, {
        "setup",
        "update",
        "refresh",
        "setcontents",
        "rebuild",
        "reset",
    }, 24)

    result.after_info_count = get_collection_count(snapshot.current_info_list_ref) or result.before_info_count
    result.after_item_count = get_collection_count(snapshot.current_item_list_ref) or result.before_item_count
    result.after_info_names = build_info_entry_names(snapshot.current_info_list_ref, 16)

    local after_name_lookup = {}
    for _, name in ipairs(extract_info_entry_job_names(result.after_info_names)) do
        after_name_lookup[tostring(name)] = true
    end

    local visible_restored = 0
    for _, name in ipairs(snapshot.removed_info_names or {}) do
        if after_name_lookup[tostring(name)] then
            visible_restored = visible_restored + 1
        end
    end

    result.ok = visible_restored > 0
    result.reason = result.ok and "removed_entries_visible_after_reinjection" or "reinjection_no_visible_growth"
    result.reinserted_entries = {}
    for _, name in ipairs(snapshot.removed_info_names or {}) do
        local visible = after_name_lookup[tostring(name)] == true
        table.insert(result.reinserted_entries, string.format(
            "%s(info=%s,item=%s,visible=%s)",
            tostring(name),
            tostring(info_any_ok),
            tostring(item_any_ok),
            tostring(visible)
        ))
    end
    return result
end

local function build_prune_recent_events(data, snapshot, target_name)
    local snapshot_time = tonumber(snapshot and snapshot.time) or 0
    local snapshot_chara_id = snapshot and snapshot.chara_id or nil

    return take_recent_matching_tail(data.recent_events, 8, function(item)
        if item == nil or item.ui_type ~= "app.ui040101_00" then
            return false
        end

        local item_time = tonumber(item.time)
        if item_time == nil or item_time > snapshot_time + 0.001 or item_time < snapshot_time - 0.75 then
            return false
        end

        local resolved_target = item.target_match and item.target_match.resolved_target or item.target_role or "unknown"
        if resolved_target == target_name then
            return true
        end

        return snapshot_chara_id ~= nil and item.chara_id ~= nil and item.chara_id == snapshot_chara_id
    end)
end

local function build_prune_recent_field_sets(data, snapshot)
    local snapshot_time = tonumber(snapshot and snapshot.time) or 0
    local allowed_methods = {
        addNormalContentsList = true,
        setupJobMenuContentsInfo = true,
        setupJobInfoWindow = true,
        setupJobWeapon = true,
        setupDisableJobs = true,
    }

    return take_recent_matching_tail(data.recent_field_sets, 6, function(item)
        if item == nil or item.ui_type ~= "app.ui040101_00" then
            return false
        end

        if not allowed_methods[item.method] then
            return false
        end

        local item_time = tonumber(item.time)
        if item_time == nil or item_time > snapshot_time + 0.001 or item_time < snapshot_time - 0.75 then
            return false
        end

        return true
    end)
end

local function read_selected_chara(chara_tab_obj)
    if not util.is_valid_obj(chara_tab_obj) then
        return nil, nil
    end

    local selected_chara_id = util.safe_direct_method(chara_tab_obj, "get_SelectedCharaID")
        or util.safe_method(chara_tab_obj, "get_SelectedCharaID")
        or util.safe_method(chara_tab_obj, "get_SelectedCharaID()")
    local selected_chara = util.safe_direct_method(chara_tab_obj, "get_SelectedChara")
        or util.safe_method(chara_tab_obj, "get_SelectedChara")
        or util.safe_method(chara_tab_obj, "get_SelectedChara()")

    return selected_chara_id, selected_chara
end

local function build_selected_chara_detail(selected_chara)
    if not util.is_valid_obj(selected_chara) then
        return nil
    end

    local job_context = util.safe_direct_method(selected_chara, "get_JobContext")
        or util.safe_method(selected_chara, "get_JobContext")
        or util.safe_method(selected_chara, "get_JobContext()")
    local human = util.safe_direct_method(selected_chara, "get_Human")
        or util.safe_method(selected_chara, "get_Human")
        or util.safe_method(selected_chara, "get_Human()")

    local detail = {
        chara = util.describe_obj(selected_chara),
        chara_type = util.get_type_full_name(selected_chara),
        job_context = util.describe_obj(job_context),
        job_context_type = util.get_type_full_name(job_context),
        human = util.describe_obj(human),
        human_type = util.get_type_full_name(human),
        current_job = job_context and util.safe_field(job_context, "CurrentJob") or nil,
        job_context_fields = take_keyword_field_lines(job_context, 12),
        chara_fields = take_keyword_field_lines(selected_chara, 12),
        human_fields = take_keyword_field_lines(human, 12),
        chara_collections = build_related_collection_lines(selected_chara, 4),
        job_context_collections = build_related_collection_lines(job_context, 4),
    }

    return detail
end

local function build_collection_preview_lines(collection_obj, limit)
    local lines = {}
    local count = 0

    for _, item in ipairs(util.collection_to_lua(collection_obj, limit or 8)) do
        count = count + 1
        local name = util.safe_field(item, "Name")
            or util.safe_field(item, "_Name")
            or util.safe_field(item, "Id")
            or util.safe_field(item, "_Id")
        table.insert(lines, string.format("#%d | %s | key=%s", count, util.describe_obj(item), tostring(name)))
    end

    return lines
end

local function build_related_collection_lines(obj, limit)
    local lines = {}
    if not util.is_valid_obj(obj) then
        return lines
    end

    for _, entry in ipairs(util.get_fields_snapshot(obj, config.guild_research.snapshot_limit)) do
        local field_name = tostring(entry.name)
        local value = util.safe_field(obj, field_name)
        if util.is_valid_obj(value) and contains_keyword(field_name) then
            local count = get_collection_count(value)
            if count ~= nil then
                table.insert(lines, string.format(
                    "%s=%s | count=%s | type=%s",
                    tostring(field_name),
                    util.describe_obj(value),
                    tostring(count),
                    tostring(util.get_type_full_name(value))
                ))

                for _, preview in ipairs(build_collection_preview_lines(value, limit or 6)) do
                    table.insert(lines, string.format("%s -> %s", tostring(field_name), tostring(preview)))
                end
            end
        end
    end

    return lines
end

local function build_selected_chara_lines(chara_tab_obj)
    local lines = {}
    if not util.is_valid_obj(chara_tab_obj) then
        return lines
    end

    local selected_chara_id, selected_chara = read_selected_chara(chara_tab_obj)

    table.insert(lines, string.format("selected_chara_id=%s", tostring(selected_chara_id)))
    table.insert(lines, string.format("selected_chara=%s", util.describe_obj(selected_chara)))

    if util.is_valid_obj(selected_chara) then
        for _, line in ipairs(take_keyword_field_lines(selected_chara, 12)) do
            table.insert(lines, "selected_chara_field:" .. tostring(line))
        end
    end

    return lines
end

function get_collection_count(collection_obj)
    if collection_obj == nil then
        return nil
    end

    return util.safe_direct_method(collection_obj, "get_Count")
        or util.safe_method(collection_obj, "get_Count")
        or util.safe_field(collection_obj, "_Count")
end

local function build_ui040101_detail(this_obj, detail_mode)
    if not util.is_valid_obj(this_obj) then
        return nil
    end

    local detail = {
        ui_type = "app.ui040101_00",
        ui_ref = this_obj,
        flow_now = util.safe_field(this_obj, "_FlowNow") or util.safe_field(this_obj, "FlowNow"),
        chara_tab = util.describe_obj(util.safe_field(this_obj, "_CharaTab") or util.safe_field(this_obj, "CharaTab")),
    }

    if detail_mode == "deep" then
        detail.ui_fields = take_keyword_field_lines(this_obj, 12)
        detail.ui_methods = take_method_inventory_lines(this_obj, 24)
    end

    detail.main_contents_list_ctrl, detail.main_contents_list_ctrl_source = find_first_field(this_obj, {
        "_Main_ContentsListCtrl",
        "MainContentsListCtrl",
    })

    detail.sub_menu, detail.sub_menu_source = find_first_field(this_obj, {
        "_SubMenu",
        "SubMenu",
    })

    detail.chara_tab_obj, detail.chara_tab_source = find_first_field(this_obj, {
        "_CharaTab",
        "CharaTab",
    })

    if detail.chara_tab_obj ~= nil then
        detail.chara_tab_type = util.get_type_full_name(detail.chara_tab_obj)
        detail.chara_tab_selected = build_selected_chara_lines(detail.chara_tab_obj)
        detail.selected_chara_id, detail.selected_chara = read_selected_chara(detail.chara_tab_obj)
        if detail_mode == "deep" then
            detail.chara_tab_fields = take_keyword_field_lines(detail.chara_tab_obj, 16)
            detail.chara_tab_methods = take_method_inventory_lines(detail.chara_tab_obj, 24)
            detail.chara_tab_related_collections = build_related_collection_lines(detail.chara_tab_obj, 6)
            detail.selected_chara_detail = build_selected_chara_detail(detail.selected_chara)
        end

        detail.chara_tab_list_ctrl, detail.chara_tab_list_ctrl_source = find_first_field(detail.chara_tab_obj, {
            "_ListCtrl",
            "ListCtrl",
        })
        if detail.chara_tab_list_ctrl ~= nil then
            detail.chara_tab_list_ctrl_type = util.get_type_full_name(detail.chara_tab_list_ctrl)
            if detail_mode == "deep" then
                detail.chara_tab_list_ctrl_fields = take_keyword_field_lines(detail.chara_tab_list_ctrl, 16)
                detail.chara_tab_list_ctrl_methods = take_method_inventory_lines(detail.chara_tab_list_ctrl, 24)
                detail.chara_tab_list_ctrl_related_collections = build_related_collection_lines(detail.chara_tab_list_ctrl, 6)
            end
        end
    end

    if detail.main_contents_list_ctrl ~= nil then
        detail.main_contents_list_ctrl_type = util.get_type_full_name(detail.main_contents_list_ctrl)
        if detail_mode == "deep" then
            detail.list_ctrl_fields = take_keyword_field_lines(detail.main_contents_list_ctrl, 12)
            detail.list_ctrl_methods = take_method_inventory_lines(detail.main_contents_list_ctrl, 24)
        end

        detail.info_list, detail.info_list_source = find_first_field(detail.main_contents_list_ctrl, {
            "_InfoList",
            "_InfoDataList",
            "_ItemInfoList",
            "_ItemDataList",
            "_List",
            "InfoList",
        })

        detail.item_list, detail.item_list_source = find_first_field(detail.main_contents_list_ctrl, {
            "_ItemList",
            "_ItemCtrlList",
            "ItemList",
        })

        detail.current_index, detail.current_index_source = read_list_ctrl_index(detail.main_contents_list_ctrl)

        detail.item_num = util.safe_direct_method(detail.main_contents_list_ctrl, "get_ItemNum")
            or util.safe_method(detail.main_contents_list_ctrl, "get_ItemNum")
            or util.safe_field(detail.main_contents_list_ctrl, "_ItemNum")
            or util.safe_direct_method(detail.main_contents_list_ctrl, "get_Count")
            or util.safe_method(detail.main_contents_list_ctrl, "get_Count")

        detail.count = util.safe_direct_method(detail.main_contents_list_ctrl, "get_Count")
            or util.safe_method(detail.main_contents_list_ctrl, "get_Count")

        detail.visible_start_index = util.safe_field(detail.main_contents_list_ctrl, "_ViewTopIndex")
            or util.safe_field(detail.main_contents_list_ctrl, "_VisibleStartIndex")

        detail.visible_end_index = util.safe_field(detail.main_contents_list_ctrl, "_ViewBottomIndex")
            or util.safe_field(detail.main_contents_list_ctrl, "_VisibleEndIndex")

        detail.info_count = get_collection_count(detail.info_list)
        detail.item_count = get_collection_count(detail.item_list)
        detail.info_list_type = util.get_type_full_name(detail.info_list)
        detail.item_list_type = util.get_type_full_name(detail.item_list)
        detail.first_info_entry = take_first_collection_entry(detail.info_list)
        detail.first_item_entry = take_first_collection_entry(detail.item_list)
        detail.first_info_entry_type = util.get_type_full_name(detail.first_info_entry)
        detail.first_item_entry_type = util.get_type_full_name(detail.first_item_entry)
        local selected_info_entry = nil
        local selected_index = tonumber(detail.current_index)
        if selected_index == nil then
            selected_index, detail.selected_index_source = resolve_selected_item_index(detail.item_list, detail.main_contents_list_ctrl)
            detail.current_index = selected_index
        else
            detail.selected_index_source = detail.current_index_source
        end
        if selected_index ~= nil then
            selected_info_entry = take_collection_entry_at(detail.info_list, selected_index)
        end
        if selected_info_entry == nil then
            selected_info_entry = detail.first_info_entry
            if detail.selected_index_source == nil then
                detail.selected_index_source = "first_info_fallback"
            end
        end
        local selected_info_summary = build_info_entry_probe_summary(selected_info_entry)
        detail.selected_info_entry = selected_info_entry
        detail.selected_info_entry_summary = format_info_entry_probe_summary(selected_info_summary)
        detail.selected_info_entry_name = selected_info_summary and selected_info_summary.name or nil
        detail.selected_info_entry_job_id = selected_info_summary and selected_info_summary.job_id or nil
        if detail_mode == "deep" then
            detail.info_name_lines = build_info_entry_names(detail.info_list, 16)
            detail.info_entries = describe_collection_entries(detail.info_list, 16)
            detail.item_entries = describe_collection_entries(detail.item_list, 16)
        end
    end

    return detail
end

local function build_targeted_ui_detail(ui_type, this_obj, detail_mode)
    if ui_type == "app.ui040101_00" then
        return build_ui040101_detail(this_obj, detail_mode)
    end

    return nil
end

local function wants_deep_targeted_detail(ui_type, method_name)
    if ui_type ~= "app.ui040101_00" then
        return false
    end

    return method_name == "setupJobMenuContentsInfo"
        or method_name == "setupJobMenu"
        or method_name == "setupContents(System.Int32)"
        or method_name == "setupDisableJobs"
        or method_name == "getJobInfoParam"
        or method_name == "addNormalContentsList"
end

local function new_source_probe_state()
    return {
        enabled = config.guild_research.enable_source_probe_once == true,
        armed = config.guild_research.enable_source_probe_once == true,
        captured_targets = {},
        captured_target_job_keys = {},
        method_capture_counts = {},
        method_sequences = {},
        method_passes = {},
        capture_count = 0,
        capture_limit_per_target = config.guild_research.source_probe_job_capture_limit or 8,
        capture_limit_get_job_info = config.guild_research.source_probe_get_job_info_limit or 8,
        capture_limit_add_normal = config.guild_research.source_probe_add_normal_limit or 16,
        capture_limit_get_job_info_player = config.guild_research.source_probe_get_job_info_player_limit or 8,
        capture_limit_get_job_info_main_pawn = config.guild_research.source_probe_get_job_info_main_pawn_limit or 8,
        capture_limit_add_normal_player = config.guild_research.source_probe_add_normal_player_limit or 8,
        capture_limit_add_normal_main_pawn = config.guild_research.source_probe_add_normal_main_pawn_limit or 8,
        last_method = "none",
        last_target = "none",
        last_reason = "not_attempted",
        last_time = "0",
        last_flow_now = "unknown",
        last_capture_job_id = "unknown",
    }
end

local function compute_configured_source_probe_total_limit()
    local limits = {
        config.guild_research.source_probe_add_normal_player_limit or 8,
        config.guild_research.source_probe_add_normal_main_pawn_limit or 8,
        config.guild_research.source_probe_get_job_info_player_limit or 8,
        config.guild_research.source_probe_get_job_info_main_pawn_limit or 8,
    }

    local total = 0
    for _, limit in ipairs(limits) do
        if type(limit) == "number" and limit > 0 then
            total = total + limit
        end
    end

    if total > 0 then
        return total
    end

    return (config.guild_research.source_probe_job_capture_limit or 8) * 2
end

local function call_candidate_methods(obj)
    local results = {}

    for _, method_name in ipairs(method_candidates) do
        local value = util.safe_direct_method(obj, method_name)
            or util.safe_method(obj, method_name)
            or util.safe_method(obj, method_name .. "()")

        if value ~= nil then
            results[method_name] = tostring(value)
        end
    end

    return results
end

local function first_present(map, keys)
    for _, key in ipairs(keys) do
        local value = map[key]
        if value ~= nil then
            return value
        end
    end

    return nil
end

local function current_clock()
    return state.runtime.game_time or os.clock()
end

local resolve_effective_flow_now

local function new_aggressive_hook_session_state()
    return {
        enabled = config.guild_research.enable_aggressive_hook_session == true,
        auto_enabled = config.guild_research.enable_auto_aggressive_hook_session == true,
        active = config.guild_research.enable_aggressive_hook_session == true,
        full_enabled = config.guild_research.enable_aggressive_hook_session == true,
        started_at = 0,
        expires_at = config.guild_research.enable_aggressive_hook_session == true and math.huge or 0,
        duration_seconds = config.guild_research.aggressive_hook_session_duration_seconds or 20.0,
        event_limit = config.guild_research.aggressive_hook_session_event_limit or 96,
        auto_cooldown_seconds = config.guild_research.aggressive_hook_session_auto_cooldown_seconds or 20.0,
        event_count = 0,
        target = config.guild_research.enable_aggressive_hook_session == true and "full_session" or "none",
        trigger_method = config.guild_research.enable_aggressive_hook_session == true and "config_default" or "none",
        last_reason = config.guild_research.enable_aggressive_hook_session == true and "full_capture_default" or "not_started",
        last_time = "0",
        last_auto_arm_time = 0,
        last_auto_arm_target = "none",
    }
end

local function get_aggressive_hook_session(data)
    data.aggressive_hook_session = data.aggressive_hook_session or new_aggressive_hook_session_state()
    local session = data.aggressive_hook_session
    session.enabled = config.guild_research.enable_aggressive_hook_session == true
    session.auto_enabled = config.guild_research.enable_auto_aggressive_hook_session == true
    session.duration_seconds = config.guild_research.aggressive_hook_session_duration_seconds or 20.0
    session.event_limit = config.guild_research.aggressive_hook_session_event_limit or 96
    session.auto_cooldown_seconds = config.guild_research.aggressive_hook_session_auto_cooldown_seconds or 20.0
    if session.enabled == true and session.full_enabled ~= true then
        session.full_enabled = true
        session.active = true
        session.started_at = current_clock()
        session.expires_at = math.huge
        session.target = "full_session"
        session.trigger_method = "config_default"
        session.last_reason = "full_capture_default"
        session.last_time = string.format("%.3f", current_clock())
    elseif session.enabled ~= true then
        session.active = false
        session.full_enabled = false
        session.expires_at = 0
        if session.target == "full_session" then
            session.target = "none"
        end
    end
    return session
end

local function arm_aggressive_hook_session(session, target_name, trigger_method, reason)
    local now = current_clock()
    session.active = true
    session.started_at = now
    session.expires_at = session.full_enabled == true and math.huge or (now + (session.duration_seconds or 20.0))
    session.event_count = 0
    session.target = tostring(target_name or "manual")
    session.trigger_method = tostring(trigger_method or "manual_arm")
    session.last_reason = tostring(reason or "armed_manual")
    session.last_time = string.format("%.3f", now)
end

local function get_player_chara_id()
    return util.safe_method(state.runtime.player, "get_CharaID")
end

local function get_main_pawn_chara_id()
    local main_pawn_data = state.runtime.main_pawn_data
    return main_pawn_data and main_pawn_data.chara_id or nil
end

local function read_context_from_object(obj)
    if not util.is_valid_obj(obj) then
        return nil, "unresolved", nil, "unresolved"
    end

    local chara_id = nil
    local chara_id_source = "unresolved"
    chara_id = util.safe_direct_method(obj, "getCharaId")
    if chara_id ~= nil then
        chara_id_source = "getCharaId"
    else
        chara_id = util.safe_method(obj, "getCharaId()")
        if chara_id ~= nil then
            chara_id_source = "getCharaId()"
        else
            chara_id = util.safe_method(obj, "getCharaId")
            if chara_id ~= nil then
                chara_id_source = "getCharaId via call"
            end
        end
    end

    local job_context = nil
    local job_context_source = "unresolved"
    job_context = util.safe_direct_method(obj, "getJobContext")
    if job_context ~= nil then
        job_context_source = "getJobContext"
    else
        job_context = util.safe_method(obj, "getJobContext()")
        if job_context ~= nil then
            job_context_source = "getJobContext()"
        else
            job_context = util.safe_method(obj, "getJobContext")
            if job_context ~= nil then
                job_context_source = "getJobContext via call"
            end
        end
    end

    return chara_id, chara_id_source, job_context, job_context_source
end

local function collect_related_context_objects(obj, related)
    related = related or {}
    if not util.is_valid_obj(obj) then
        return related
    end

    for _, field_name in ipairs(context_owner_fields) do
        local value = util.safe_field(obj, field_name)
        if util.is_valid_obj(value) then
            table.insert(related, {
                obj = value,
                source = "field:" .. tostring(field_name),
            })
        end
    end

    for _, method_name in ipairs(context_owner_methods) do
        local value = util.safe_direct_method(obj, method_name)
            or util.safe_method(obj, method_name)
            or util.safe_method(obj, method_name .. "()")
        if util.is_valid_obj(value) then
            table.insert(related, {
                obj = value,
                source = "method:" .. tostring(method_name),
            })
        end
    end

    return related
end

local function resolve_event_context(this_obj)
    local queue = {
        {
            obj = this_obj,
            source = "self",
            depth = 0,
        },
    }
    local visited = {}
    local index = 1

    while queue[index] ~= nil and index <= 12 do
        local current = queue[index]
        index = index + 1

        if util.is_valid_obj(current.obj) then
            local address = util.get_address(current.obj)
            local visit_key = address ~= nil and tostring(address) or util.describe_obj(current.obj)
            if not visited[visit_key] then
                visited[visit_key] = true

                local chara_id, chara_id_source, job_context, job_context_source = read_context_from_object(current.obj)
                if chara_id ~= nil or job_context ~= nil then
                    return {
                        chara_id = chara_id,
                        chara_id_source = current.source .. ":" .. chara_id_source,
                        job_context = job_context,
                        job_context_source = current.source .. ":" .. job_context_source,
                        context_object = current.obj,
                        context_source = current.source,
                    }
                end

                if current.depth < 2 then
                    for _, related in ipairs(collect_related_context_objects(current.obj)) do
                        table.insert(queue, {
                            obj = related.obj,
                            source = current.source .. "->" .. tostring(related.source),
                            depth = current.depth + 1,
                        })
                    end
                end
            end
        end
    end

    return {
        chara_id = nil,
        chara_id_source = "unresolved",
        job_context = nil,
        job_context_source = "unresolved",
        context_object = nil,
        context_source = "unresolved",
    }
end

local function resolve_target_role(chara_id, job_context)
    local player_id = get_player_chara_id()
    if chara_id ~= nil and player_id ~= nil and chara_id == player_id then
        return "player"
    end

    local main_pawn_data = state.runtime.main_pawn_data
    if chara_id ~= nil and main_pawn_data ~= nil and main_pawn_data.chara_id ~= nil and chara_id == main_pawn_data.chara_id then
        return "main_pawn"
    end

    local progression = state.runtime.progression_gate_data
    if job_context ~= nil and progression ~= nil and util.same_object(job_context, progression.job_context) then
        return "player_job_context"
    end

    if job_context ~= nil and main_pawn_data ~= nil and util.same_object(job_context, main_pawn_data.job_context) then
        return "main_pawn_job_context"
    end

    return "unknown"
end

local function resolve_target_name_for_chara_id(chara_id)
    local player_id = get_player_chara_id()
    if chara_id ~= nil and player_id ~= nil and chara_id == player_id then
        return "player"
    end

    local main_pawn_id = get_main_pawn_chara_id()
    if chara_id ~= nil and main_pawn_id ~= nil and chara_id == main_pawn_id then
        return "main_pawn"
    end

    return "unknown"
end

local function build_target_match(job_context, chara_id)
    local progression = state.runtime.progression_gate_data
    local main_pawn_data = state.runtime.main_pawn_data
    local player_id = get_player_chara_id()
    local main_pawn_id = get_main_pawn_chara_id()

    local match = {
        matches_player_chara_id = chara_id ~= nil and player_id ~= nil and chara_id == player_id or false,
        matches_main_pawn_chara_id = chara_id ~= nil and main_pawn_id ~= nil and chara_id == main_pawn_id or false,
        matches_player_job_context = job_context ~= nil and progression ~= nil and util.same_object(job_context, progression.job_context) or false,
        matches_main_pawn_job_context = job_context ~= nil and main_pawn_data ~= nil and util.same_object(job_context, main_pawn_data.job_context) or false,
    }

    if match.matches_player_chara_id or match.matches_player_job_context then
        match.resolved_target = "player"
    elseif match.matches_main_pawn_chara_id or match.matches_main_pawn_job_context then
        match.resolved_target = "main_pawn"
    else
        match.resolved_target = "unknown"
    end

    return match
end

local function summarize_context_alignment()
    local progression = state.runtime.progression_gate_data
    local main_pawn_data = state.runtime.main_pawn_data

    return {
        player_chara_id = get_player_chara_id(),
        main_pawn_chara_id = get_main_pawn_chara_id(),
        player_job_context = progression and util.describe_obj(progression.job_context) or "nil",
        main_pawn_job_context = main_pawn_data and util.describe_obj(main_pawn_data.job_context) or "nil",
        player_current_job = progression and progression.current_job or nil,
        main_pawn_current_job = main_pawn_data and (main_pawn_data.current_job or main_pawn_data.job) or nil,
    }
end

local function collect_target_stats(recent_events)
    local stats = {
        player = 0,
        main_pawn = 0,
        unknown = 0,
        player_job_context = 0,
        main_pawn_job_context = 0,
    }

    for _, item in ipairs(recent_events or {}) do
        local resolved = item.target_match and item.target_match.resolved_target or item.target_role or "unknown"
        stats[resolved] = (stats[resolved] or 0) + 1
    end

    return stats
end

local function collect_ui_role_matrix(recent_events)
    local matrix = {}

    for _, item in ipairs(recent_events or {}) do
        local ui_type = item.ui_type or "unknown_ui"
        local resolved = item.target_match and item.target_match.resolved_target or item.target_role or "unknown"
        local bucket = matrix[ui_type]
        if bucket == nil then
            bucket = {
                player = false,
                main_pawn = false,
                unknown = false,
                flow_ids = {},
            }
            matrix[ui_type] = bucket
        end

        if resolved == "player" or resolved == "main_pawn" or resolved == "unknown" then
            bucket[resolved] = true
        else
            bucket.unknown = true
        end

        if item.flow_id ~= nil then
            bucket.flow_ids[tostring(item.flow_id)] = true
        end
    end

    return matrix
end

local function matrix_flow_ids(bucket)
    local ids = {}
    for value, _ in pairs(bucket.flow_ids or {}) do
        table.insert(ids, value)
    end
    table.sort(ids)
    return table.concat(ids, ",")
end

local function build_trace_assessment(data)
    local source_events = {}
    if data.unique_events ~= nil and #data.unique_events > 0 then
        for _, item in ipairs(data.unique_events) do
            table.insert(source_events, {
                ui_type = item.ui_type,
                target_match = {
                    resolved_target = item.resolved_target,
                },
                target_role = item.resolved_target,
                flow_id = item.flow_id,
            })
        end
    else
        source_events = data.recent_events or {}
    end

    local stats = collect_target_stats(source_events)
    local matrix = collect_ui_role_matrix(source_events)
    local paired_ui_types = {}
    local player_only_ui_types = {}
    local main_pawn_only_ui_types = {}
    local unknown_ui_types = {}

    for ui_type, bucket in pairs(matrix) do
        if bucket.player and bucket.main_pawn then
            table.insert(paired_ui_types, ui_type)
        elseif bucket.player then
            table.insert(player_only_ui_types, ui_type)
        elseif bucket.main_pawn then
            table.insert(main_pawn_only_ui_types, ui_type)
        else
            table.insert(unknown_ui_types, ui_type)
        end
    end

    table.sort(paired_ui_types)
    table.sort(player_only_ui_types)
    table.sort(main_pawn_only_ui_types)
    table.sort(unknown_ui_types)

    local summary_lines = {}
    for ui_type, bucket in pairs(matrix) do
        table.insert(summary_lines, string.format(
            "%s player=%s main_pawn=%s unknown=%s flow_ids=%s",
            tostring(ui_type),
            tostring(bucket.player),
            tostring(bucket.main_pawn),
            tostring(bucket.unknown),
            matrix_flow_ids(bucket)
        ))
    end
    table.sort(summary_lines)

    return {
        target_stats = stats,
        paired_ui_types = paired_ui_types,
        player_only_ui_types = player_only_ui_types,
        main_pawn_only_ui_types = main_pawn_only_ui_types,
        unknown_ui_types = unknown_ui_types,
        paired_trace_ready = #paired_ui_types > 0,
        summary_lines = summary_lines,
    }
end

local function ensure_runtime_data()
    local runtime = state.runtime
    local data = runtime.guild_flow_research_data

    if data == nil then
        data = {
            enabled = true,
            registration_errors = {},
            registered_hooks = {},
            skipped_hooks = {},
            recent_events = {},
            active_ui = {},
            recent_field_sets = {},
            unique_events = {},
            unique_event_keys = {},
            unique_ui_observations = {},
            targeted_ui_details = {},
            targeted_ui_details_by_target = {},
            setup_job_menu_contents_info_snapshots = {},
            source_method_snapshots = {},
            job_info_player_cache = {},
            source_sequence_state = {},
            prune_windows = {},
            prune_followups = {},
            source_rebuild_windows = {},
            source_rebuild_pending = {},
            source_state_windows = {},
            source_state_pending = {},
            active_prune_probe = nil,
            vocation_flow_windows = {},
            prune_bypass_probe = {
                enabled = config.guild_research.enable_prune_bypass_probe == true,
                attempted = false,
                ok = false,
                reason = "not_attempted",
                target = "unknown",
                time = "0",
            },
            post_prune_reinjection = {
                enabled = config.guild_research.enable_post_prune_reinjection == true,
                attempted = false,
                ok = false,
                reason = "not_attempted",
                target = "unknown",
                time = "0",
            },
            manual_prune_rewrite = {
                enabled = config.guild_research.enable_manual_prune_rewrite == true,
                attempted = false,
                ok = false,
                reason = "not_attempted",
                target = "unknown",
                time = "0",
            },
            multi_intervention_attempts = {},
            multi_intervention_latest = {},
            setup_job_menu_comparison = {},
            source_probe_once = new_source_probe_state(),
            aggressive_hook_session = new_aggressive_hook_session_state(),
            player_job_list_override = {
                enabled = config.guild_research.enable_player_job_list_override == true,
                copy_item_list = config.guild_research.copy_player_item_list_for_main_pawn == true,
                source_ready = false,
                source_full_ready = false,
                source_info_count = 0,
                source_item_count = 0,
                last_result = "not_attempted",
                last_reason = "not_attempted",
                last_target = "unknown",
                last_time = "0",
            },
            event_count = 0,
            trace_dirty = false,
            guild_ui_hint = false,
        }
        runtime.guild_flow_research_data = data
    end

    data.enabled = true
    data.registration_errors = registration_errors
    data.registered_hooks = registered_hooks
    data.skipped_hooks = skipped_hooks
    data.recent_events = data.recent_events or {}
    data.active_ui = data.active_ui or {}
    data.recent_field_sets = data.recent_field_sets or {}
    data.unique_events = data.unique_events or {}
    data.unique_event_keys = data.unique_event_keys or {}
    data.unique_ui_observations = data.unique_ui_observations or {}
    data.targeted_ui_details = data.targeted_ui_details or {}
    data.targeted_ui_details_by_target = data.targeted_ui_details_by_target or {}
    data.setup_job_menu_contents_info_snapshots = data.setup_job_menu_contents_info_snapshots or {}
    data.source_method_snapshots = data.source_method_snapshots or {}
    data.source_sequence_state = data.source_sequence_state or {}
    data.prune_windows = data.prune_windows or {}
    data.prune_followups = data.prune_followups or {}
    data.source_rebuild_windows = data.source_rebuild_windows or {}
    data.source_rebuild_pending = data.source_rebuild_pending or {}
    data.source_state_windows = data.source_state_windows or {}
    data.source_state_pending = data.source_state_pending or {}
    data.prune_bypass_probe = data.prune_bypass_probe or {}
    data.prune_bypass_probe.enabled = config.guild_research.enable_prune_bypass_probe == true
    data.post_prune_reinjection = data.post_prune_reinjection or {}
    data.post_prune_reinjection.enabled = config.guild_research.enable_post_prune_reinjection == true
    data.manual_prune_rewrite = data.manual_prune_rewrite or {}
    data.manual_prune_rewrite.enabled = config.guild_research.enable_manual_prune_rewrite == true
    data.job_info_pawn_override = data.job_info_pawn_override or {}
    data.job_info_pawn_override.enabled = config.guild_research.enable_job_info_pawn_override == true
    data.multi_intervention_attempts = data.multi_intervention_attempts or {}
    data.multi_intervention_latest = data.multi_intervention_latest or {}
    data.setup_job_menu_comparison = data.setup_job_menu_comparison or {}
    data.source_probe_once = data.source_probe_once or new_source_probe_state()
    data.source_probe_once.enabled = config.guild_research.enable_source_probe_once == true
    if data.source_probe_once.enabled ~= true then
        data.source_probe_once.armed = false
    elseif (data.source_probe_once.capture_count or 0) < compute_configured_source_probe_total_limit() then
        data.source_probe_once.armed = true
    end
    data.source_probe_once.capture_limit_per_target = config.guild_research.source_probe_job_capture_limit or 8
    data.source_probe_once.capture_limit_get_job_info = config.guild_research.source_probe_get_job_info_limit or 8
    data.source_probe_once.capture_limit_add_normal = config.guild_research.source_probe_add_normal_limit or 16
    data.source_probe_once.capture_limit_get_job_info_player = config.guild_research.source_probe_get_job_info_player_limit or 8
    data.source_probe_once.capture_limit_get_job_info_main_pawn = config.guild_research.source_probe_get_job_info_main_pawn_limit or 8
    data.source_probe_once.capture_limit_add_normal_player = config.guild_research.source_probe_add_normal_player_limit or 8
    data.source_probe_once.capture_limit_add_normal_main_pawn = config.guild_research.source_probe_add_normal_main_pawn_limit or 8
    data.source_probe_once.captured_targets = data.source_probe_once.captured_targets or {}
    data.source_probe_once.captured_target_job_keys = data.source_probe_once.captured_target_job_keys or {}
    data.source_probe_once.method_capture_counts = data.source_probe_once.method_capture_counts or {}
    data.source_probe_once.method_sequences = data.source_probe_once.method_sequences or {}
    data.aggressive_hook_session = data.aggressive_hook_session or new_aggressive_hook_session_state()
    get_aggressive_hook_session(data)
    data.player_job_list_override = data.player_job_list_override or {}
    data.player_job_list_override.enabled = config.guild_research.enable_player_job_list_override == true
    data.player_job_list_override.copy_item_list = config.guild_research.copy_player_item_list_for_main_pawn == true
    return data
end

local function build_line_set_diff(before_lines, after_lines)
    local before_lookup = {}
    local after_lookup = {}
    local removed = {}
    local added = {}

    for _, line in ipairs(before_lines or {}) do
        before_lookup[tostring(line)] = true
    end
    for _, line in ipairs(after_lines or {}) do
        after_lookup[tostring(line)] = true
    end

    for _, line in ipairs(before_lines or {}) do
        line = tostring(line)
        if not after_lookup[line] then
            table.insert(removed, line)
        end
    end
    for _, line in ipairs(after_lines or {}) do
        line = tostring(line)
        if not before_lookup[line] then
            table.insert(added, line)
        end
    end

    return removed, added
end

local function build_source_rebuild_snapshot(event, targeted_ui_detail)
    if event == nil or targeted_ui_detail == nil then
        return nil
    end

    return {
        time = event.time,
        method = event.method,
        phase = event.phase,
        target = event.target_match and event.target_match.resolved_target or event.target_role or "unknown",
        chara_id = event.chara_id,
        selected_chara_id = targeted_ui_detail.selected_chara_id,
        flow_now = targeted_ui_detail.flow_now,
        info_count = targeted_ui_detail.info_count,
        item_count = targeted_ui_detail.item_count,
        current_index = targeted_ui_detail.current_index,
        current_index_source = targeted_ui_detail.current_index_source,
        selected_index_source = targeted_ui_detail.selected_index_source,
        info_name_lines = targeted_ui_detail.info_name_lines or {},
        ui_field_lines = take_keyword_field_lines(targeted_ui_detail.ui_ref, 12),
        list_ctrl_field_lines = take_keyword_field_lines(targeted_ui_detail.main_contents_list_ctrl, 12),
    }
end

local function build_source_state_snapshot(event, targeted_ui_detail)
    if event == nil or targeted_ui_detail == nil then
        return nil
    end

    local list_ctrl_ref = targeted_ui_detail.main_contents_list_ctrl
    local info_list_ref = targeted_ui_detail.info_list
    local item_list_ref = targeted_ui_detail.item_list
    local chara_tab_ref = targeted_ui_detail.chara_tab_obj
    local sub_menu_ref = targeted_ui_detail.sub_menu

    return {
        time = event.time,
        method = event.method,
        phase = event.phase,
        target = event.target_match and event.target_match.resolved_target or event.target_role or "unknown",
        chara_id = event.chara_id,
        selected_chara_id = targeted_ui_detail.selected_chara_id,
        flow_now = targeted_ui_detail.flow_now,
        info_count = targeted_ui_detail.info_count,
        item_count = targeted_ui_detail.item_count,
        current_index = targeted_ui_detail.current_index,
        current_index_source = targeted_ui_detail.current_index_source,
        selected_index_source = targeted_ui_detail.selected_index_source,
        info_name_lines = targeted_ui_detail.info_name_lines or {},
        ui_ref = targeted_ui_detail.ui_ref,
        list_ctrl_ref = list_ctrl_ref,
        info_list_ref = info_list_ref,
        item_list_ref = item_list_ref,
        chara_tab_ref = chara_tab_ref,
        sub_menu_ref = sub_menu_ref,
        source_refs = {
            "_Main_ContentsListCtrl=" .. tostring(util.describe_obj(list_ctrl_ref)),
            "InfoList=" .. tostring(util.describe_obj(info_list_ref)),
            "ItemList=" .. tostring(util.describe_obj(item_list_ref)),
            "_CharaTab=" .. tostring(util.describe_obj(chara_tab_ref)),
            "_SubMenu=" .. tostring(util.describe_obj(sub_menu_ref)),
        },
        ui_field_lines = take_keyword_field_lines(targeted_ui_detail.ui_ref, 16),
        list_ctrl_field_lines = take_keyword_field_lines(list_ctrl_ref, 16),
        chara_tab_field_lines = take_keyword_field_lines(chara_tab_ref, 12),
        ui_collection_lines = build_related_collection_lines(targeted_ui_detail.ui_ref, 6),
        list_ctrl_collection_lines = build_related_collection_lines(list_ctrl_ref, 6),
    }
end

local function build_scalar_change_lines(before_snapshot, after_snapshot)
    local checks = {
        { label = "flow_now", before = before_snapshot and before_snapshot.flow_now, after = after_snapshot and after_snapshot.flow_now },
        { label = "info_count", before = before_snapshot and before_snapshot.info_count, after = after_snapshot and after_snapshot.info_count },
        { label = "item_count", before = before_snapshot and before_snapshot.item_count, after = after_snapshot and after_snapshot.item_count },
        { label = "current_index", before = before_snapshot and before_snapshot.current_index, after = after_snapshot and after_snapshot.current_index },
        { label = "current_index_source", before = before_snapshot and before_snapshot.current_index_source, after = after_snapshot and after_snapshot.current_index_source },
        { label = "selected_index_source", before = before_snapshot and before_snapshot.selected_index_source, after = after_snapshot and after_snapshot.selected_index_source },
        { label = "selected_chara_id", before = before_snapshot and before_snapshot.selected_chara_id, after = after_snapshot and after_snapshot.selected_chara_id },
    }

    local lines = {}
    for _, item in ipairs(checks) do
        if tostring(item.before) ~= tostring(item.after) then
            table.insert(lines, string.format("%s:%s->%s", tostring(item.label), tostring(item.before), tostring(item.after)))
        end
    end
    return lines
end

resolve_effective_flow_now = function(data, target_name, targeted_ui_detail)
    local raw_flow = targeted_ui_detail and tonumber(targeted_ui_detail.flow_now) or nil
    local windows = data and data.vocation_flow_windows or nil
    if windows == nil then
        return raw_flow, "raw"
    end

    local key = tostring(target_name or "unknown")
    local now = current_clock()
    local window = windows[key] or {}
    windows[key] = window

    if raw_flow == 2 then
        window.last_flow_two_at = now
        return 2, "raw"
    end

    local elapsed = now - tonumber(window.last_flow_two_at or 0)
    if raw_flow == 24 and elapsed >= 0 and elapsed <= 2.0 then
        local info_count = targeted_ui_detail and tonumber(targeted_ui_detail.info_count) or nil
        local item_count = targeted_ui_detail and tonumber(targeted_ui_detail.item_count) or nil
        if info_count ~= nil and info_count > 0 and item_count ~= nil and item_count >= info_count then
            return 2, "window_from_24"
        end
    end

    return raw_flow, "raw"
end

local function maybe_capture_source_state_window(data, event, targeted_ui_detail)
    if data == nil or event == nil or targeted_ui_detail == nil then
        return
    end

    if event.ui_type ~= "app.ui040101_00" then
        return
    end

    local tracked_methods = {
        setupJobMenu = true,
        setupJobMenuContentsInfo = true,
        updateJobMenu = true,
    }
    if not tracked_methods[event.method] then
        return
    end

    local target_name = event.target_match and event.target_match.resolved_target or event.target_role or "unknown"
    if target_name ~= "main_pawn" then
        return
    end

    local effective_flow = resolve_effective_flow_now(data, target_name, targeted_ui_detail)
    if tonumber(effective_flow) ~= 2 then
        return
    end

    if event.phase == "pre" then
        data.source_state_pending[event.method] = build_source_state_snapshot(event, targeted_ui_detail)
        return
    end

    local before = data.source_state_pending[event.method]
    data.source_state_pending[event.method] = nil
    if before == nil then
        return
    end

    local after = build_source_state_snapshot(event, targeted_ui_detail)
    if after == nil then
        return
    end

    local removed_entries, added_entries = build_line_set_diff(before.info_name_lines, after.info_name_lines)
    local removed_refs, added_refs = build_line_set_diff(before.source_refs, after.source_refs)
    local removed_ui_fields, added_ui_fields = build_line_set_diff(before.ui_field_lines, after.ui_field_lines)
    local removed_list_fields, added_list_fields = build_line_set_diff(before.list_ctrl_field_lines, after.list_ctrl_field_lines)
    local removed_tab_fields, added_tab_fields = build_line_set_diff(before.chara_tab_field_lines, after.chara_tab_field_lines)
    local removed_ui_collections, added_ui_collections = build_line_set_diff(before.ui_collection_lines, after.ui_collection_lines)
    local removed_list_collections, added_list_collections = build_line_set_diff(before.list_ctrl_collection_lines, after.list_ctrl_collection_lines)

    table.insert(data.source_state_windows, {
        time = event.time,
        method = event.method,
        target = target_name,
        chara_id = event.chara_id,
        selected_chara_id = after.selected_chara_id,
        scalar_changes = build_scalar_change_lines(before, after),
        before_info_name_lines = before.info_name_lines,
        after_info_name_lines = after.info_name_lines,
        removed_entries = removed_entries,
        added_entries = added_entries,
        removed_refs = removed_refs,
        added_refs = added_refs,
        removed_ui_fields = removed_ui_fields,
        added_ui_fields = added_ui_fields,
        removed_list_ctrl_fields = removed_list_fields,
        added_list_ctrl_fields = added_list_fields,
        removed_chara_tab_fields = removed_tab_fields,
        added_chara_tab_fields = added_tab_fields,
        removed_ui_collections = removed_ui_collections,
        added_ui_collections = added_ui_collections,
        removed_list_ctrl_collections = removed_list_collections,
        added_list_ctrl_collections = added_list_collections,
    })
    trim_history(data.source_state_windows, 24)
    data.trace_dirty = true
end

local function maybe_capture_source_rebuild_window(data, event, targeted_ui_detail)
    if data == nil or event == nil or targeted_ui_detail == nil then
        return
    end

    if event.ui_type ~= "app.ui040101_00" then
        return
    end

    local tracked_methods = {
        setupJobMenu = true,
        setupJobMenuContentsInfo = true,
        updateJobMenu = true,
    }
    if not tracked_methods[event.method] then
        return
    end

    local probe = data.active_prune_probe
    if probe == nil or probe.target ~= "main_pawn" then
        return
    end

    local now = current_clock()
    local effective_flow = resolve_effective_flow_now(data, "main_pawn", targeted_ui_detail)
    if tonumber(effective_flow) ~= 2 then
        return
    end

    if probe.started_at ~= nil and (now - tonumber(probe.started_at or 0)) > 1.5 then
        return
    end

    local target_name = event.target_match and event.target_match.resolved_target or event.target_role or "unknown"
    if target_name ~= "main_pawn" then
        return
    end

    local key = string.format(
        "%s|%s|%s",
        tostring(event.method),
        tostring(event.chara_id),
        tostring(event.phase == "pre" and event.time or event.time)
    )

    if event.phase == "pre" then
        data.source_rebuild_pending[event.method] = build_source_rebuild_snapshot(event, targeted_ui_detail)
        return
    end

    local before = data.source_rebuild_pending[event.method]
    local after = build_source_rebuild_snapshot(event, targeted_ui_detail)
    data.source_rebuild_pending[event.method] = nil
    if before == nil or after == nil then
        return
    end

    local removed_entries, added_entries = build_line_set_diff(before.info_name_lines, after.info_name_lines)
    local removed_ui_fields, added_ui_fields = build_line_set_diff(before.ui_field_lines, after.ui_field_lines)
    local removed_list_fields, added_list_fields = build_line_set_diff(before.list_ctrl_field_lines, after.list_ctrl_field_lines)

    table.insert(data.source_rebuild_windows, {
        method = event.method,
        target = target_name,
        time = event.time,
        chara_id = event.chara_id,
        selected_chara_id = after.selected_chara_id,
        flow_now = after.flow_now,
        before_info_count = before.info_count,
        after_info_count = after.info_count,
        before_item_count = before.item_count,
        after_item_count = after.item_count,
        before_current_index = before.current_index,
        after_current_index = after.current_index,
        before_current_index_source = before.current_index_source,
        after_current_index_source = after.current_index_source,
        before_selected_index_source = before.selected_index_source,
        after_selected_index_source = after.selected_index_source,
        before_info_name_lines = before.info_name_lines,
        after_info_name_lines = after.info_name_lines,
        removed_entries = removed_entries,
        added_entries = added_entries,
        removed_ui_fields = removed_ui_fields,
        added_ui_fields = added_ui_fields,
        removed_list_ctrl_fields = removed_list_fields,
        added_list_ctrl_fields = added_list_fields,
    })
    trim_history(data.source_rebuild_windows, 18)
    data.trace_dirty = true

    probe.remaining = math.max(0, tonumber(probe.remaining or 0) - 1)
    if probe.remaining <= 0 then
        data.active_prune_probe = nil
    end
end

local function capture_setup_job_menu_contents_info_snapshot(data, event, targeted_ui_detail)
    if event == nil or targeted_ui_detail == nil then
        return
    end

    if event.ui_type ~= "app.ui040101_00" or event.method ~= "setupJobMenuContentsInfo" then
        return
    end

    local target_name = event.target_match and event.target_match.resolved_target or event.target_role or "unknown"
    local phase_name = event.phase or "unknown"
    local bucket = data.setup_job_menu_contents_info_snapshots[target_name]
    if bucket == nil then
        bucket = {}
        data.setup_job_menu_contents_info_snapshots[target_name] = bucket
    end

    bucket[phase_name] = {
        time = event.time,
        chara_id = event.chara_id,
        current_job = event.current_job,
        info_count = targeted_ui_detail.info_count,
        item_count = targeted_ui_detail.item_count,
        flow_now = targeted_ui_detail.flow_now,
        chara_tab = targeted_ui_detail.chara_tab,
        chara_tab_type = targeted_ui_detail.chara_tab_type,
        chara_tab_fields = targeted_ui_detail.chara_tab_fields,
        chara_tab_selected = targeted_ui_detail.chara_tab_selected,
        chara_tab_related_collections = targeted_ui_detail.chara_tab_related_collections,
        chara_tab_list_ctrl = util.describe_obj(targeted_ui_detail.chara_tab_list_ctrl),
        chara_tab_list_ctrl_type = targeted_ui_detail.chara_tab_list_ctrl_type,
        chara_tab_list_ctrl_fields = targeted_ui_detail.chara_tab_list_ctrl_fields,
        chara_tab_list_ctrl_related_collections = targeted_ui_detail.chara_tab_list_ctrl_related_collections,
        selected_chara_id = targeted_ui_detail.selected_chara_id,
        selected_chara_detail = targeted_ui_detail.selected_chara_detail,
        info_name_lines = targeted_ui_detail.info_name_lines,
        info_entries = targeted_ui_detail.info_entries,
    }
end

local function update_setup_job_menu_comparison(data)
    if data == nil then
        return
    end

    local player_snapshot = data.setup_job_menu_contents_info_snapshots.player
    local main_pawn_snapshot = data.setup_job_menu_contents_info_snapshots.main_pawn
    if player_snapshot == nil or main_pawn_snapshot == nil then
        return
    end

    local player_post = player_snapshot.post or player_snapshot.pre
    local main_pawn_post = main_pawn_snapshot.post or main_pawn_snapshot.pre
    if player_post == nil or main_pawn_post == nil then
        return
    end

    local player_job_names = extract_info_entry_job_names(player_post.info_name_lines)
    local main_pawn_job_names = extract_info_entry_job_names(main_pawn_post.info_name_lines)

    data.setup_job_menu_comparison = {
        player_info_count = player_post.info_count,
        main_pawn_info_count = main_pawn_post.info_count,
        player_item_count = player_post.item_count,
        main_pawn_item_count = main_pawn_post.item_count,
        player_chara_id = player_post.chara_id,
        main_pawn_chara_id = main_pawn_post.chara_id,
        player_selected_chara_id = player_post.selected_chara_id,
        main_pawn_selected_chara_id = main_pawn_post.selected_chara_id,
        player_job_names = player_job_names,
        main_pawn_job_names = main_pawn_job_names,
        missing_for_main_pawn = build_missing_name_lines(player_job_names, main_pawn_job_names),
        extra_for_main_pawn = build_missing_name_lines(main_pawn_job_names, player_job_names),
        player_selected_chara_detail = player_post.selected_chara_detail,
        main_pawn_selected_chara_detail = main_pawn_post.selected_chara_detail,
        player_flow_now = player_post.flow_now,
        main_pawn_flow_now = main_pawn_post.flow_now,
    }
end

local function cache_player_job_menu_source(data, event, targeted_ui_detail)
    if data == nil or event == nil or targeted_ui_detail == nil then
        return
    end

    if event.ui_type ~= "app.ui040101_00" then
        return
    end

    if event.phase ~= "post" then
        return
    end

    if (event.target_match and event.target_match.resolved_target) ~= "player" then
        return
    end

    local effective_flow = resolve_effective_flow_now(data, "player", targeted_ui_detail)
    if tonumber(effective_flow) ~= 2 then
        return
    end

    local allowed_methods = {
        setupJobMenu = true,
        setupJobMenuContentsInfo = true,
        updateJobMenu = true,
        setupJobInfoWindow = true,
        setupJobWeapon = true,
    }
    if not allowed_methods[event.method] then
        return
    end

    local bucket = data.player_job_list_override or {}
    local info_count = tonumber(targeted_ui_detail.info_count) or 0
    local item_count = tonumber(targeted_ui_detail.item_count) or 0
    local is_full_player_source = info_count >= 10 and item_count >= 11 and util.is_valid_obj(targeted_ui_detail.info_list)

    if bucket.source_full_ready == true and not is_full_player_source then
        data.player_job_list_override = bucket
        return
    end

    bucket.source_ready = util.is_valid_obj(targeted_ui_detail.info_list)
    bucket.source_full_ready = is_full_player_source
    bucket.source_time = tostring(event.time)
    bucket.source_target = "player"
    bucket.source_method = tostring(event.method)
    bucket.source_chara_id = tostring(event.chara_id)
    bucket.source_job = tostring(event.current_job)
    bucket.source_info_count = targeted_ui_detail.info_count or 0
    bucket.source_item_count = targeted_ui_detail.item_count or 0
    bucket.source_info_list = targeted_ui_detail.info_list
    bucket.source_item_list = targeted_ui_detail.item_list
    bucket.source_info_list_type = targeted_ui_detail.info_list_type
    bucket.source_item_list_type = targeted_ui_detail.item_list_type
    bucket.source_list_ctrl = targeted_ui_detail.main_contents_list_ctrl
    bucket.source_list_ctrl_type = targeted_ui_detail.main_contents_list_ctrl_type
    data.player_job_list_override = bucket
end

local function maybe_apply_player_job_list_override(this_obj, extra)
    local data = ensure_runtime_data()
    local bucket = data.player_job_list_override or {}
    data.player_job_list_override = bucket
    bucket.last_time = string.format("%.3f", current_clock())

    if not config.guild_research.enable_player_job_list_override then
        bucket.last_result = "skipped"
        bucket.last_reason = "override_disabled"
        bucket.last_target = "unknown"
        return "override_disabled"
    end

    local context = resolve_event_context(this_obj)
    local target_match = build_target_match(context.job_context, context.chara_id)
    local target_name = target_match.resolved_target or "unknown"
    bucket.last_target = target_name

    local targeted_ui_detail = build_targeted_ui_detail("app.ui040101_00", this_obj, "deep")
    if targeted_ui_detail == nil then
        bucket.last_result = "skipped"
        bucket.last_reason = "detail_unresolved"
        return "detail_unresolved"
    end

    local effective_flow = resolve_effective_flow_now(data, target_name, targeted_ui_detail)
    bucket.last_flow_now = tostring(effective_flow)
    if tonumber(effective_flow) ~= 2 then
        bucket.last_result = "skipped"
        bucket.last_reason = "not_vocation_flow"
        return "not_vocation_flow"
    end

    if target_name == "player" then
        cache_player_job_menu_source(data, {
            ui_type = "app.ui040101_00",
            method = "setupJobMenuContentsInfo",
            phase = "post",
            target_match = target_match,
            chara_id = context.chara_id,
            current_job = context.job_context and util.safe_field(context.job_context, "CurrentJob") or nil,
            time = string.format("%.3f", current_clock()),
        }, targeted_ui_detail)
        bucket.last_result = "cached"
        bucket.last_reason = "player_source_captured"
        return string.format(
            "player_source_cached(info=%s,item=%s)",
            tostring(targeted_ui_detail.info_count),
            tostring(targeted_ui_detail.item_count)
        )
    end

    if target_name ~= "main_pawn" then
        bucket.last_result = "skipped"
        bucket.last_reason = "target_not_main_pawn"
        return "target_not_main_pawn"
    end

    if not bucket.source_ready or not util.is_valid_obj(bucket.source_info_list) then
        bucket.last_result = "skipped"
        bucket.last_reason = "player_source_missing"
        return "player_source_missing"
    end

    local list_ctrl = targeted_ui_detail.main_contents_list_ctrl
    if not util.is_valid_obj(list_ctrl) then
        bucket.last_result = "failed"
        bucket.last_reason = "list_ctrl_unresolved"
        return "list_ctrl_unresolved"
    end

    bucket.last_before_info_count = tostring(targeted_ui_detail.info_count)
    bucket.last_before_item_count = tostring(targeted_ui_detail.item_count)

    local ok_info, info_field = try_assign_first_field(list_ctrl, {
        "_InfoList",
        "_InfoDataList",
        "_ItemInfoList",
        "_ItemDataList",
        "_List",
        "InfoList",
    }, bucket.source_info_list)

    local ok_item = false
    local item_field = "skipped"
    if bucket.copy_item_list and util.is_valid_obj(bucket.source_item_list) then
        ok_item, item_field = try_assign_first_field(list_ctrl, {
            "_ItemList",
            "_ItemCtrlList",
            "ItemList",
        }, bucket.source_item_list)
    end

    local after_detail = build_targeted_ui_detail("app.ui040101_00", this_obj, "deep")
    bucket.last_after_info_count = tostring(after_detail and after_detail.info_count or targeted_ui_detail.info_count)
    bucket.last_after_item_count = tostring(after_detail and after_detail.item_count or targeted_ui_detail.item_count)
    bucket.last_info_field = tostring(info_field)
    bucket.last_item_field = tostring(item_field)
    bucket.last_source_info_count = tostring(bucket.source_info_count)
    bucket.last_source_item_count = tostring(bucket.source_item_count)
    bucket.last_result = ok_info and "applied" or "failed"
    bucket.last_reason = ok_info and "player_source_assigned" or "info_assign_failed"

    if extra ~= nil then
        extra.override_after_info_count = bucket.last_after_info_count
        extra.override_after_item_count = bucket.last_after_item_count
    end

    return string.format(
        "%s(info_field=%s,item_field=%s,before=%s/%s,after=%s/%s,source=%s/%s,item_ok=%s)",
        tostring(bucket.last_reason),
        tostring(info_field),
        tostring(item_field),
        tostring(bucket.last_before_info_count),
        tostring(bucket.last_before_item_count),
        tostring(bucket.last_after_info_count),
        tostring(bucket.last_after_item_count),
        tostring(bucket.source_info_count),
        tostring(bucket.source_item_count),
        tostring(ok_item)
    )
end

local function attempt_manual_prune_rewrite(data, event, targeted_ui_detail)
    local result = {
        enabled = config.guild_research.enable_manual_prune_rewrite == true,
        attempted = false,
        ok = false,
        reason = "not_attempted",
        target = event and (event.target_match and event.target_match.resolved_target or event.target_role) or "unknown",
        time = event and event.time or "0",
        selected_chara_id = targeted_ui_detail and targeted_ui_detail.selected_chara_id or nil,
        before_info_count = targeted_ui_detail and targeted_ui_detail.info_count or nil,
        before_item_count = targeted_ui_detail and targeted_ui_detail.item_count or nil,
        after_info_count = targeted_ui_detail and targeted_ui_detail.info_count or nil,
        after_item_count = targeted_ui_detail and targeted_ui_detail.item_count or nil,
        source_info_count = nil,
        source_item_count = nil,
        info_add_ok = false,
        item_add_ok = false,
        info_add_method = "not_attempted",
        item_add_method = "not_attempted",
        after_info_names = {},
    }

    if config.guild_research.enable_manual_prune_rewrite ~= true then
        result.reason = "rewrite_disabled"
        return result
    end

    if data == nil or event == nil or targeted_ui_detail == nil then
        result.reason = "context_unresolved"
        return result
    end

    if event.ui_type ~= "app.ui040101_00" or event.method ~= "setupJobMenuContentsInfo" or event.phase ~= "post" then
        result.reason = "method_mismatch"
        return result
    end

    local target_name = event.target_match and event.target_match.resolved_target or event.target_role or "unknown"
    if target_name ~= "main_pawn" then
        result.reason = "target_not_main_pawn"
        return result
    end

    local effective_flow = resolve_effective_flow_now(data, target_name, targeted_ui_detail)
    if tonumber(effective_flow) ~= 2 then
        result.reason = "not_vocation_flow"
        return result
    end

    if tonumber(targeted_ui_detail.info_count) ~= 6 then
        result.reason = "main_pawn_not_pruned"
        return result
    end

    local source_bucket = data.player_job_list_override or {}
    result.source_info_count = source_bucket.source_info_count
    result.source_item_count = source_bucket.source_item_count
    if source_bucket.source_full_ready ~= true or not source_bucket.source_ready or not util.is_valid_obj(source_bucket.source_info_list) then
        result.reason = "player_source_missing"
        return result
    end

    if tonumber(source_bucket.source_info_count) ~= 10 then
        result.reason = "player_source_not_full"
        return result
    end

    if not util.is_valid_obj(targeted_ui_detail.info_list) then
        result.reason = "current_info_list_unresolved"
        return result
    end

    result.attempted = true
    local info_ok, info_method = util.replace_generic_list_items(targeted_ui_detail.info_list, source_bucket.source_info_list)
    result.info_add_ok = info_ok
    result.info_add_method = info_method

    local item_ok = false
    local item_method = "not_attempted"
    if util.is_valid_obj(targeted_ui_detail.main_contents_list_ctrl) and util.is_valid_obj(source_bucket.source_item_list) then
        local cloned_array, clone_reason = util.clone_managed_array(source_bucket.source_item_list)
        if util.is_valid_obj(cloned_array) then
            local assigned, assigned_field = try_assign_first_field(targeted_ui_detail.main_contents_list_ctrl, {
                "_ItemList",
                "_ItemCtrlList",
                "ItemList",
            }, cloned_array)
            item_ok = assigned
            item_method = assigned and ("array_reassigned:" .. tostring(assigned_field)) or "item_assign_failed"
        else
            item_method = clone_reason or "clone_failed"
        end
    end
    result.item_add_ok = item_ok
    result.item_add_method = item_method

    local after_detail = build_targeted_ui_detail("app.ui040101_00", targeted_ui_detail.ui_ref, "deep")
    result.after_info_count = after_detail and after_detail.info_count or result.before_info_count
    result.after_item_count = after_detail and after_detail.item_count or result.before_item_count
    result.after_info_names = after_detail and after_detail.info_name_lines or {}

    local after_names = extract_info_entry_job_names(result.after_info_names)
    local restored = 0
    for _, name in ipairs(after_names) do
        if confirmed_removed_hybrid_names[tostring(name)] then
            restored = restored + 1
        end
    end

    result.ok = restored > 0
    if result.ok then
        result.reason = "rewrite_visible_growth"
    elseif info_ok or item_ok then
        result.reason = "rewrite_applied_no_visible_growth"
    else
        result.reason = "rewrite_apply_failed"
    end

    return result
end

local function attempt_stage_source_rewrite(data, event, targeted_ui_detail, stage_name)
    local result = {
        enabled = config.guild_research.enable_multi_intervention_probe == true,
        stage = tostring(stage_name or "unknown"),
        attempted = false,
        ok = false,
        reason = "not_attempted",
        target = event and (event.target_match and event.target_match.resolved_target or event.target_role) or "unknown",
        time = event and event.time or "0",
        selected_chara_id = targeted_ui_detail and targeted_ui_detail.selected_chara_id or nil,
        before_info_count = targeted_ui_detail and targeted_ui_detail.info_count or nil,
        after_info_count = targeted_ui_detail and targeted_ui_detail.info_count or nil,
        before_item_count = targeted_ui_detail and targeted_ui_detail.item_count or nil,
        after_item_count = targeted_ui_detail and targeted_ui_detail.item_count or nil,
        source_info_count = nil,
        source_item_count = nil,
        info_add_ok = false,
        item_add_ok = false,
        info_add_method = "not_attempted",
        item_add_method = "not_attempted",
        after_info_names = {},
    }

    if config.guild_research.enable_multi_intervention_probe ~= true then
        result.reason = "multi_intervention_disabled"
        return result
    end

    if data == nil or event == nil or targeted_ui_detail == nil then
        result.reason = "context_unresolved"
        return result
    end

    if event.ui_type ~= "app.ui040101_00" or event.phase ~= "post" then
        result.reason = "method_phase_mismatch"
        return result
    end

    local allowed_methods = {
        setupJobMenu = true,
        setupJobMenuContentsInfo = true,
        updateJobMenu = true,
        setupDisableJobs = true,
    }
    if not allowed_methods[event.method] then
        result.reason = "method_not_tracked"
        return result
    end

    local target_name = event.target_match and event.target_match.resolved_target or event.target_role or "unknown"
    if target_name ~= "main_pawn" then
        result.reason = "target_not_main_pawn"
        return result
    end

    local effective_flow = resolve_effective_flow_now(data, target_name, targeted_ui_detail)
    if tonumber(effective_flow) ~= 2 then
        result.reason = "not_vocation_flow"
        return result
    end

    local source_bucket = data.player_job_list_override or {}
    result.source_info_count = source_bucket.source_info_count
    result.source_item_count = source_bucket.source_item_count
    if source_bucket.source_full_ready ~= true or not source_bucket.source_ready or not util.is_valid_obj(source_bucket.source_info_list) then
        result.reason = "player_source_missing"
        return result
    end

    if tonumber(source_bucket.source_info_count) ~= 10 then
        result.reason = "player_source_not_full"
        return result
    end

    if not util.is_valid_obj(targeted_ui_detail.info_list) then
        result.reason = "current_info_list_unresolved"
        return result
    end

    local current_names = extract_info_entry_job_names(targeted_ui_detail.info_name_lines or {})
    local current_hybrid = 0
    for _, name in ipairs(current_names) do
        if confirmed_removed_hybrid_names[tostring(name)] then
            current_hybrid = current_hybrid + 1
        end
    end
    if current_hybrid >= 4 then
        result.reason = "already_full_or_hybrid_present"
        return result
    end

    result.attempted = true
    local info_ok, info_method = util.replace_generic_list_items(targeted_ui_detail.info_list, source_bucket.source_info_list)
    result.info_add_ok = info_ok
    result.info_add_method = info_method

    local item_ok = false
    local item_method = "not_attempted"
    if util.is_valid_obj(targeted_ui_detail.main_contents_list_ctrl) and util.is_valid_obj(source_bucket.source_item_list) then
        local cloned_array, clone_reason = util.clone_managed_array(source_bucket.source_item_list)
        if util.is_valid_obj(cloned_array) then
            local assigned, assigned_field = try_assign_first_field(targeted_ui_detail.main_contents_list_ctrl, {
                "_ItemList",
                "_ItemCtrlList",
                "ItemList",
            }, cloned_array)
            item_ok = assigned
            item_method = assigned and ("array_reassigned:" .. tostring(assigned_field)) or "item_assign_failed"
        else
            item_method = clone_reason or "clone_failed"
        end
    end
    result.item_add_ok = item_ok
    result.item_add_method = item_method

    local after_detail = build_targeted_ui_detail("app.ui040101_00", targeted_ui_detail.ui_ref, "deep")
    result.after_info_count = after_detail and after_detail.info_count or result.before_info_count
    result.after_item_count = after_detail and after_detail.item_count or result.before_item_count
    result.after_info_names = after_detail and after_detail.info_name_lines or {}

    local after_names = extract_info_entry_job_names(result.after_info_names)
    local restored = 0
    for _, name in ipairs(after_names) do
        if confirmed_removed_hybrid_names[tostring(name)] then
            restored = restored + 1
        end
    end

    result.ok = restored > 0
    if result.ok then
        result.reason = "stage_visible_growth"
    elseif info_ok or item_ok then
        result.reason = "stage_applied_no_visible_growth"
    else
        result.reason = "stage_apply_failed"
    end

    return result
end

local function record_multi_intervention_attempt(data, result)
    if data == nil or result == nil then
        return
    end

    data.multi_intervention_attempts = data.multi_intervention_attempts or {}
    table.insert(data.multi_intervention_attempts, result)
    trim_history(data.multi_intervention_attempts, 40)

    data.multi_intervention_latest = data.multi_intervention_latest or {}
    data.multi_intervention_latest[tostring(result.stage or "unknown")] = result
    data.trace_dirty = true
end

local function capture_source_method_snapshot(data, event, targeted_ui_detail, extra)
    if data == nil or event == nil then
        return
    end

    local tracked_methods = {
        getJobInfoParam = true,
        addNormalContentsList = true,
    }

    if event.ui_type ~= "app.ui040101_00" or not tracked_methods[event.method] then
        return
    end

    local target_name = event.target_match and event.target_match.resolved_target or event.target_role or "unknown"
    local method_bucket = data.source_method_snapshots[event.method]
    if method_bucket == nil then
        method_bucket = {}
        data.source_method_snapshots[event.method] = method_bucket
    end

    local capture_job_id = extra and extra.capture_job_id or event.current_job
    local capture_label = extra and extra.capture_label or tostring(capture_job_id or "unknown")
    local target_bucket = method_bucket[target_name]
    if target_bucket == nil then
        target_bucket = {}
        method_bucket[target_name] = target_bucket
    end

    local retval_obj = extra and extra.retval_obj or nil
    local retval_field_lines = {}
    local retval_keyword_lines = {}
    local retval_collection_lines = {}

    if util.is_valid_obj(retval_obj) then
        retval_field_lines = take_field_snapshot_lines(retval_obj, 16)
        retval_keyword_lines = take_keyword_field_lines(retval_obj, 16)
        retval_collection_lines = build_related_collection_lines(retval_obj, 6)
    end

    local snapshot = {
        time = event.time,
        chara_id = event.chara_id,
        current_job = event.current_job,
        capture_job_id = capture_job_id,
        capture_label = capture_label,
        capture_pass = extra and extra.capture_pass or nil,
        capture_sequence = extra and extra.capture_sequence or nil,
        flow_now = targeted_ui_detail and targeted_ui_detail.flow_now or nil,
        info_count = targeted_ui_detail and targeted_ui_detail.info_count or nil,
        item_count = targeted_ui_detail and targeted_ui_detail.item_count or nil,
        last_info_entry_name = targeted_ui_detail and targeted_ui_detail.last_info_entry_name or nil,
        last_info_entry_summary = targeted_ui_detail and targeted_ui_detail.last_info_entry_summary or nil,
        selected_chara_id = extra and extra.selected_chara_id or targeted_ui_detail and targeted_ui_detail.selected_chara_id or nil,
        selected_target_name = extra and extra.selected_target_name or targeted_ui_detail and targeted_ui_detail.selected_target or nil,
        event_target_name = extra and extra.event_target_name or target_name,
        context_drift = extra and extra.context_drift or false,
        argument_summary = extra and extra.argument_summary or nil,
        argument_details = extra and extra.argument_details or nil,
        return_summary = extra and extra.retval_summary or nil,
        return_type = util.get_type_full_name(retval_obj),
        return_fields = retval_field_lines,
        return_keyword_fields = retval_keyword_lines,
        return_collections = retval_collection_lines,
        current_info_name_lines = targeted_ui_detail and targeted_ui_detail.info_name_lines or nil,
        list_ctrl_ref = targeted_ui_detail and targeted_ui_detail.main_contents_list_ctrl or nil,
        current_info_list_ref = targeted_ui_detail and targeted_ui_detail.info_list or nil,
        current_item_list_ref = targeted_ui_detail and targeted_ui_detail.item_list or nil,
        ui_ref = targeted_ui_detail and targeted_ui_detail.ui_ref or nil,
    }

    local sequence_state_key = tostring(event.method) .. ":" .. tostring(target_name)
    local previous_state = data.source_sequence_state and data.source_sequence_state[sequence_state_key] or nil
    if previous_state ~= nil then
        snapshot.previous_capture_label = previous_state.capture_label
        snapshot.previous_info_count = previous_state.info_count
        snapshot.previous_item_count = previous_state.item_count
        snapshot.previous_last_info_name = previous_state.last_info_entry_name
        snapshot.previous_info_name_lines = previous_state.info_name_lines
        snapshot.previous_info_list_ref = previous_state.info_list_ref
        snapshot.previous_item_list_ref = previous_state.item_list_ref
        snapshot.previous_list_ctrl_ref = previous_state.list_ctrl_ref

        local current_info = tonumber(snapshot.info_count)
        local previous_info = tonumber(previous_state.info_count)
        if current_info ~= nil and previous_info ~= nil then
            snapshot.delta_info_count = current_info - previous_info
        end

        local current_item = tonumber(snapshot.item_count)
        local previous_item = tonumber(previous_state.item_count)
        if current_item ~= nil and previous_item ~= nil then
            snapshot.delta_item_count = current_item - previous_item
        end

        snapshot.transition_summary = string.format(
            "%s -> %s | info:%s->%s | item:%s->%s | prev_entry=%s | current_entry=%s",
            tostring(previous_state.capture_label),
            tostring(snapshot.capture_label),
            tostring(previous_state.info_count),
            tostring(snapshot.info_count),
            tostring(previous_state.item_count),
            tostring(snapshot.item_count),
            tostring(previous_state.last_info_entry_name),
            tostring(snapshot.last_info_entry_name)
        )

        local removed_names = build_removed_info_names(previous_state.info_name_lines, snapshot.current_info_name_lines)
        if removed_names ~= nil and #removed_names > 0 then
            snapshot.removed_info_names = removed_names
        end
    end

    if event.method == "addNormalContentsList"
        and target_name == "main_pawn"
        and is_confirmed_vocation_prune_snapshot(snapshot)
    then
        data.prune_windows = data.prune_windows or {}
        local prune_bypass_result = attempt_prune_bypass(snapshot)
        local post_prune_reinjection_result = attempt_post_prune_reinjection(snapshot)
        data.prune_bypass_probe = prune_bypass_result
        data.post_prune_reinjection = post_prune_reinjection_result
        table.insert(data.prune_windows, {
            time = snapshot.time,
            method = event.method,
            target = target_name,
            selected_target_name = snapshot.selected_target_name,
            event_target_name = snapshot.event_target_name,
            selected_chara_id = snapshot.selected_chara_id,
            capture_label = snapshot.capture_label,
            capture_pass = snapshot.capture_pass,
            capture_sequence = snapshot.capture_sequence,
            previous_capture_label = snapshot.previous_capture_label,
            previous_info_count = snapshot.previous_info_count,
            previous_item_count = snapshot.previous_item_count,
            info_count = snapshot.info_count,
            item_count = snapshot.item_count,
            delta_info_count = snapshot.delta_info_count,
            delta_item_count = snapshot.delta_item_count,
            transition_summary = snapshot.transition_summary,
            current_entry_summary = snapshot.last_info_entry_summary,
            removed_info_names = snapshot.removed_info_names,
            previous_info_name_lines = snapshot.previous_info_name_lines,
            current_info_name_lines = snapshot.current_info_name_lines,
            prune_bypass_result = prune_bypass_result,
            post_prune_reinjection_result = post_prune_reinjection_result,
            recent_events = build_prune_recent_events(data, snapshot, target_name),
            recent_field_sets = build_prune_recent_field_sets(data, snapshot),
        })
        trim_history(data.prune_windows, 6)
        data.trace_dirty = true
        data.active_prune_probe = {
            target = target_name,
            started_at = current_clock(),
            remaining = 8,
            seen_keys = {},
        }
    end

    if event.phase == "post" then
        data.source_sequence_state[sequence_state_key] = {
            capture_label = snapshot.capture_label,
            capture_pass = snapshot.capture_pass,
            info_count = snapshot.info_count,
            item_count = snapshot.item_count,
            last_info_entry_name = snapshot.last_info_entry_name,
            info_name_lines = targeted_ui_detail and targeted_ui_detail.info_name_lines or nil,
            info_list_ref = targeted_ui_detail and targeted_ui_detail.info_list or nil,
            item_list_ref = targeted_ui_detail and targeted_ui_detail.item_list or nil,
            list_ctrl_ref = targeted_ui_detail and targeted_ui_detail.main_contents_list_ctrl or nil,
            capture_sequence = snapshot.capture_sequence,
            time = snapshot.time,
        }
    end

    snapshot.phase = event.phase or "unknown"
    table.insert(target_bucket, snapshot)
    local history_limit = config.guild_research.source_snapshot_history_limit or 24
    if history_limit > 0 then
        while #target_bucket > history_limit do
            table.remove(target_bucket, 1)
        end
    end
end

local function build_light_ui_detail(this_obj)
    if not util.is_valid_obj(this_obj) then
        return nil
    end

    local detail = {
        ui_ref = this_obj,
        flow_now = util.safe_field(this_obj, "_FlowNow") or util.safe_field(this_obj, "FlowNow"),
    }

    local list_ctrl = util.safe_field(this_obj, "_Main_ContentsListCtrl")
        or util.safe_field(this_obj, "MainContentsListCtrl")
    if not util.is_valid_obj(list_ctrl) then
        local chara_tab_obj = util.safe_field(this_obj, "_CharaTab")
            or util.safe_field(this_obj, "CharaTab")
        if util.is_valid_obj(chara_tab_obj) then
            local selected_chara_id = read_selected_chara(chara_tab_obj)
            detail.selected_chara_id = selected_chara_id
            detail.selected_target = resolve_target_name_for_chara_id(selected_chara_id)
        end
        return detail
    end

    detail.main_contents_list_ctrl = list_ctrl
    detail.main_contents_list_ctrl_type = util.get_type_full_name(list_ctrl)

    local chara_tab_obj = util.safe_field(this_obj, "_CharaTab")
        or util.safe_field(this_obj, "CharaTab")
    if util.is_valid_obj(chara_tab_obj) then
        local selected_chara_id = read_selected_chara(chara_tab_obj)
        detail.selected_chara_id = selected_chara_id
        detail.selected_target = resolve_target_name_for_chara_id(selected_chara_id)
    end

    local info_list = find_first_field(list_ctrl, {
        "_InfoList",
        "_InfoDataList",
        "_ItemInfoList",
        "_ItemDataList",
        "_List",
        "InfoList",
    })
    local item_list = find_first_field(list_ctrl, {
        "_ItemList",
        "_ItemCtrlList",
        "ItemList",
    })

    detail.info_list = info_list
    detail.item_list = item_list
    detail.info_list_type = util.get_type_full_name(info_list)
    detail.item_list_type = util.get_type_full_name(item_list)

    detail.info_count = get_collection_count(info_list)
    detail.item_count = get_collection_count(item_list)
    detail.info_name_lines = build_info_entry_names(info_list, 16)

    local current_index, current_index_source = read_list_ctrl_index(list_ctrl)
    detail.current_index = current_index
    detail.current_index_source = current_index_source

    local last_info_entry = take_last_collection_entry(info_list, 24)
    local last_info_summary = build_info_entry_probe_summary(last_info_entry)
    detail.last_info_entry_name = last_info_summary and last_info_summary.name or nil
    detail.last_info_entry_summary = format_info_entry_probe_summary(last_info_summary)

    local selected_info_entry = nil
    local selected_index = tonumber(current_index)
    if selected_index == nil then
        selected_index, detail.selected_index_source = resolve_selected_item_index(item_list, list_ctrl)
        detail.current_index = selected_index
    else
        detail.selected_index_source = current_index_source
    end
    if selected_index ~= nil then
        selected_info_entry = take_collection_entry_at(info_list, selected_index)
    end
    if selected_info_entry == nil then
        selected_info_entry = last_info_entry
        if detail.selected_index_source == nil then
            detail.selected_index_source = "last_info_fallback"
        end
    end
    local selected_info_summary = build_info_entry_probe_summary(selected_info_entry)
    detail.selected_info_entry_name = selected_info_summary and selected_info_summary.name or nil
    detail.selected_info_entry_summary = format_info_entry_probe_summary(selected_info_summary)
    detail.selected_info_entry_job_id = selected_info_summary and selected_info_summary.job_id or nil

    return detail
end

local function try_parse_small_int_from_userdata_text(text)
    if type(text) ~= "string" then
        return nil
    end

    local hex_value = text:match("userdata:%s*(%x+)")
    if hex_value == nil then
        return nil
    end

    local number = tonumber(hex_value, 16)
    if number == nil or number < 0 or number > 1024 then
        return nil
    end

    return number
end

local function read_source_probe_job_id(extra, this_obj)
    if extra == nil then
        return nil
    end

    if extra.capture_job_id ~= nil then
        return extra.capture_job_id
    end

    local summary = tostring(extra.argument_summary or "")
    local first_arg = summary:match("arg1=([^,]+)")
    local parsed = try_parse_small_int_from_userdata_text(first_arg)
    if parsed ~= nil then
        extra.capture_job_id = parsed
        return parsed
    end

    local retval_obj = extra.retval_obj
    if util.is_valid_obj(retval_obj) then
        local retval_job_id = util.safe_field(retval_obj, "_JobID") or util.safe_field(retval_obj, "JobID")
        if type(retval_job_id) == "number" and retval_job_id >= 1 and retval_job_id <= 32 then
            extra.capture_job_id = retval_job_id
            return retval_job_id
        end
    end

    if util.is_valid_obj(this_obj) then
        local context = resolve_event_context(this_obj)
        local current_job = context and context.current_job or nil
        if type(current_job) == "number" and current_job >= 1 and current_job <= 32 then
            extra.capture_job_id = current_job
            return current_job
        end
    end

    return nil
end

local function try_apply_job_info_pawn_override(this_obj, extra)
    local data = ensure_runtime_data()
    local result = data.job_info_pawn_override or {}
    data.job_info_pawn_override = result
    result.enabled = config.guild_research.enable_job_info_pawn_override == true
    result.time = string.format("%.3f", current_clock())
    result.attempted = false
    result.ok = false
    result.reason = "not_attempted"

    if config.guild_research.enable_job_info_pawn_override ~= true then
        result.reason = "override_disabled"
        return "override_disabled"
    end

    if not util.is_valid_obj(this_obj) or extra == nil or not util.is_valid_obj(extra.retval_obj) then
        result.reason = "context_unresolved"
        return "context_unresolved"
    end

    local context = resolve_event_context(this_obj)
    local target_role = resolve_target_role(context and context.chara_id or nil, context and context.job_context or nil)
    result.target = tostring(target_role)

    local light_detail = build_light_ui_detail(this_obj)
    local effective_flow, effective_flow_source = resolve_effective_flow_now(data, "job_info", light_detail or {
        flow_now = util.safe_field(this_obj, "_FlowNow") or util.safe_field(this_obj, "FlowNow"),
    })
    result.flow_now = tostring(effective_flow)
    result.flow_now_source = tostring(effective_flow_source)
    if tonumber(effective_flow) ~= 2 then
        result.reason = "not_vocation_flow"
        return "not_vocation_flow"
    end

    local capture_job_id = read_source_probe_job_id(extra, this_obj)
    result.job_id = capture_job_id
    if capture_job_id == nil then
        result.reason = "job_id_unresolved"
        return "job_id_unresolved"
    end

    if capture_job_id < 7 or capture_job_id > 10 then
        result.reason = "job_not_hybrid_range"
        return "job_not_hybrid_range"
    end

    local before_enable = util.safe_field(extra.retval_obj, "_EnablePawn")
    result.before_enable_pawn = tostring(before_enable)
    result.attempted = true

    data.job_info_player_cache = data.job_info_player_cache or {}
    if target_role == "player" then
        data.job_info_player_cache[capture_job_id] = {
            raw_retval = extra.raw_retval,
            retval_obj = extra.retval_obj,
            enable_pawn = before_enable,
            summary = extra.retval_summary,
            cached_at = result.time,
        }
        result.reason = "player_job_info_cached"
        result.cached = true
        data.trace_dirty = true
        return "player_job_info_cached"
    end

    if target_role ~= "main_pawn" then
        result.reason = "target_not_main_pawn"
        return "target_not_main_pawn"
    end

    local progression = state.runtime.progression_state_data
    local pawn_state = progression and progression.main_pawn or nil
    local player_state = progression and progression.player or nil
    local hybrid_key = nil
    for key, value in pairs(config.jobs or {}) do
        if tonumber(value) == tonumber(capture_job_id) then
            hybrid_key = key
            break
        end
    end
    local pawn_hybrid = pawn_state and pawn_state.hybrid_gate_status and hybrid_key and pawn_state.hybrid_gate_status[hybrid_key] or nil
    local player_hybrid = player_state and player_state.hybrid_gate_status and hybrid_key and player_state.hybrid_gate_status[hybrid_key] or nil
    if hybrid_key == nil or pawn_hybrid == nil or player_hybrid == nil then
        result.reason = "hybrid_progression_unresolved"
        return "hybrid_progression_unresolved"
    end

    local pawn_ready = (pawn_hybrid.qualified_bits and pawn_hybrid.qualified_bits.bit_job_minus_one)
        or (pawn_hybrid.direct and pawn_hybrid.direct.is_job_qualified)
    if not pawn_ready then
        result.reason = "pawn_not_qualified_after_probe"
        return "pawn_not_qualified_after_probe"
    end

    local player_cache = data.job_info_player_cache[capture_job_id]
    result.player_cache_available = player_cache ~= nil
    if player_cache == nil then
        result.reason = "player_cache_missing"
        return "player_cache_missing"
    end

    if before_enable == true then
        result.after_enable_pawn = "true"
    end

    local set_ok = util.safe_set_field(extra.retval_obj, "_EnablePawn", true)
    local after_enable = util.safe_field(extra.retval_obj, "_EnablePawn")
    local override_retval = player_cache and player_cache.raw_retval or nil
    result.ok = (set_ok and after_enable == true) or override_retval ~= nil
    result.after_enable_pawn = tostring(after_enable)
    result.override_mode = override_retval ~= nil and "player_job_info_retval_mirror" or "enable_pawn_field_only"
    result.reason = result.ok and result.override_mode or "enable_pawn_override_failed"
    result.override_retval = override_retval
    data.trace_dirty = true
    return result.reason
end

local function build_source_capture_label(method_name, extra, capture_job_id, targeted_ui_detail)
    if method_name == "getJobInfoParam" then
        return tostring(capture_job_id or "unknown")
    end

    local last_info_name = targeted_ui_detail and targeted_ui_detail.last_info_entry_name or nil
    if last_info_name ~= nil and tostring(last_info_name) ~= "" and tostring(last_info_name) ~= "nil" then
        return "entry=" .. tostring(last_info_name)
    end

    local retval_obj = extra and extra.retval_obj or nil
    if util.is_valid_obj(retval_obj) then
        local mode = util.safe_field(retval_obj, "Mode")
        local name = util.safe_field(retval_obj, "Name")
        local msg_id = util.safe_field(retval_obj, "MsgID")
        local parts = {
            "mode=" .. tostring(mode),
            "name=" .. tostring(name),
            "msg=" .. tostring(msg_id),
        }
        return table.concat(parts, "|")
    end

    local summary = tostring(extra and extra.argument_summary or "unknown")
    if #summary > 96 then
        summary = summary:sub(1, 96)
    end

    return summary
end

local function get_source_probe_method_limit(probe, method_name)
    if method_name == "addNormalContentsList" then
        return probe.capture_limit_add_normal or 16
    end

    if method_name == "getJobInfoParam" then
        return probe.capture_limit_get_job_info or 8
    end

    return probe.capture_limit_per_target or 8
end

local function get_source_probe_method_target_limit(probe, method_name, target_name)
    if method_name == "addNormalContentsList" then
        if target_name == "player" then
            return probe.capture_limit_add_normal_player or probe.capture_limit_add_normal or 16
        end
        if target_name == "main_pawn" then
            return probe.capture_limit_add_normal_main_pawn or probe.capture_limit_add_normal or 16
        end
    end

    if method_name == "getJobInfoParam" then
        if target_name == "player" then
            return probe.capture_limit_get_job_info_player or probe.capture_limit_get_job_info or 8
        end
        if target_name == "main_pawn" then
            return probe.capture_limit_get_job_info_main_pawn or probe.capture_limit_get_job_info or 8
        end
    end

    return get_source_probe_method_limit(probe, method_name)
end

local function get_source_probe_total_limit(probe)
    local limits = {
        probe.capture_limit_add_normal_player,
        probe.capture_limit_add_normal_main_pawn,
        probe.capture_limit_get_job_info_player,
        probe.capture_limit_get_job_info_main_pawn,
    }

    local total = 0
    for _, limit in ipairs(limits) do
        if type(limit) == "number" and limit > 0 then
            total = total + limit
        end
    end

    if total > 0 then
        return total
    end

    local per_target = probe.capture_limit_per_target or 8
    return per_target * 2
end

local function source_probe_is_saturated(probe)
    local checks = {
        { method = "addNormalContentsList", target = "player" },
        { method = "addNormalContentsList", target = "main_pawn" },
        { method = "getJobInfoParam", target = "player" },
        { method = "getJobInfoParam", target = "main_pawn" },
    }

    local any_active_limit = false
    for _, check in ipairs(checks) do
        local limit = get_source_probe_method_target_limit(probe, check.method, check.target)
        if type(limit) == "number" and limit > 0 then
            any_active_limit = true
            local key = tostring(check.method) .. ":" .. tostring(check.target)
            local current = probe.method_capture_counts and probe.method_capture_counts[key] or 0
            if current < limit then
                return false
            end
        end
    end

    if any_active_limit then
        return true
    end

    return (probe.capture_count or 0) >= get_source_probe_total_limit(probe)
end

local function is_source_method_name(method_name)
    return method_name == "getJobInfoParam" or method_name == "addNormalContentsList"
end

local function maybe_capture_source_probe_once(method_name, this_obj, extra)
    local data = ensure_runtime_data()
    local probe = data.source_probe_once or {}

    probe.last_method = tostring(method_name)
    probe.last_time = string.format("%.3f", current_clock())
    probe.last_flow_now = "unknown"

    if probe.enabled ~= true then
        probe.last_reason = "probe_disabled"
        return
    end

    if probe.armed ~= true then
        probe.last_reason = "probe_disarmed"
        return
    end

    local context = resolve_event_context(this_obj)
    local target_match = build_target_match(context.job_context, context.chara_id)
    local event_target_name = target_match.resolved_target or "unknown"
    local capture_job_id = read_source_probe_job_id(extra, this_obj)
    local targeted_ui_detail = build_light_ui_detail(this_obj)
    local selected_target_name = targeted_ui_detail and targeted_ui_detail.selected_target or "unknown"
    local target_name = selected_target_name ~= "unknown" and selected_target_name or event_target_name
    local context_drift = selected_target_name ~= "unknown" and event_target_name ~= "unknown" and selected_target_name ~= event_target_name or false
    probe.last_target = target_name
    local capture_label = build_source_capture_label(method_name, extra, capture_job_id, targeted_ui_detail)
    probe.last_capture_job_id = tostring(capture_job_id)

    if target_name ~= "player" and target_name ~= "main_pawn" then
        probe.last_reason = "target_untracked"
        return
    end

    local method_target_key = tostring(method_name) .. ":" .. tostring(target_name)
    local captured_for_method_target = probe.method_capture_counts and probe.method_capture_counts[method_target_key] or 0
    local method_limit = get_source_probe_method_target_limit(probe, method_name, target_name)
    if captured_for_method_target >= method_limit then
        probe.last_reason = "method_target_limit_reached"
        return
    end

    local flow_now, flow_now_source = resolve_effective_flow_now(data, target_name, targeted_ui_detail)
    probe.last_flow_now = tostring(flow_now)
    if flow_now ~= nil and flow_now ~= 2 then
        probe.last_reason = "flow_filtered:" .. tostring(flow_now_source) .. ":" .. tostring(flow_now)
        return
    end

    probe.method_passes = probe.method_passes or {}
    probe.method_sequences = probe.method_sequences or {}
    local sequence_key = tostring(method_name) .. ":" .. tostring(target_name)
    local current_pass = probe.method_passes[sequence_key] or 1
    local previous_state = data.source_sequence_state and data.source_sequence_state[sequence_key] or nil
    local current_info_count = targeted_ui_detail and tonumber(targeted_ui_detail.info_count) or nil
    local previous_info_count = previous_state and tonumber(previous_state.info_count) or nil
    if method_name == "addNormalContentsList"
        and current_info_count ~= nil
        and previous_info_count ~= nil
        and current_info_count > previous_info_count
    then
        current_pass = current_pass + 1
        probe.method_passes[sequence_key] = current_pass
        probe.method_sequences[sequence_key] = 0
        if data.source_sequence_state ~= nil then
            data.source_sequence_state[sequence_key] = nil
        end
    else
        probe.method_passes[sequence_key] = current_pass
    end

    local dedupe_key = tostring(capture_label)
    if method_name == "addNormalContentsList" then
        dedupe_key = string.format(
            "pass=%s|seq=%s|label=%s|info=%s|item=%s",
            tostring(current_pass),
            tostring((probe.method_sequences[sequence_key] or 0) + 1),
            tostring(capture_label),
            tostring(current_info_count),
            tostring(targeted_ui_detail and targeted_ui_detail.item_count or "unknown")
        )
    end

    local capture_key = tostring(target_name) .. ":" .. tostring(method_name) .. ":" .. tostring(dedupe_key)
    if probe.captured_target_job_keys ~= nil and probe.captured_target_job_keys[capture_key] then
        probe.last_reason = "job_already_captured"
        return
    end

    local event = {
        time = string.format("%.3f", current_clock()),
        ui_type = "app.ui040101_00",
        method = method_name,
        phase = "post",
        chara_id = context.chara_id,
        current_job = context.job_context and util.safe_field(context.job_context, "CurrentJob") or nil,
        target_role = target_name,
        target_match = target_match,
    }

    extra = extra or {}
    extra.capture_job_id = capture_job_id
    extra.capture_label = capture_label
    extra.capture_pass = current_pass
    extra.selected_chara_id = targeted_ui_detail and targeted_ui_detail.selected_chara_id or nil
    extra.selected_target_name = selected_target_name
    extra.event_target_name = event_target_name
    extra.context_drift = context_drift
    local next_sequence = (probe.method_sequences[sequence_key] or 0) + 1
    probe.method_sequences[sequence_key] = next_sequence
    extra.capture_sequence = next_sequence
    capture_source_method_snapshot(data, event, targeted_ui_detail, extra)

    probe.captured_targets = probe.captured_targets or {}
    probe.captured_target_job_keys = probe.captured_target_job_keys or {}
    probe.method_capture_counts = probe.method_capture_counts or {}
    probe.captured_targets[target_name] = (probe.captured_targets[target_name] or 0) + 1
    probe.captured_target_job_keys[capture_key] = true
    probe.method_capture_counts[method_target_key] = captured_for_method_target + 1
    probe.capture_count = (probe.capture_count or 0) + 1
    probe.last_reason = context_drift and "captured_with_context_drift" or "captured"
    if source_probe_is_saturated(probe) or probe.capture_count >= get_source_probe_total_limit(probe) then
        probe.armed = false
    end

    data.trace_dirty = true
end

local function maybe_capture_prune_followup(data, event, targeted_ui_detail)
    if data == nil or event == nil or targeted_ui_detail == nil then
        return
    end

    local probe = data.active_prune_probe
    if probe == nil or probe.target ~= "main_pawn" then
        return
    end

    local elapsed = current_clock() - (probe.started_at or 0)
    if elapsed > 2.0 or (probe.remaining or 0) <= 0 then
        data.active_prune_probe = nil
        return
    end

    local resolved_target = event.target_match and event.target_match.resolved_target or event.target_role or "unknown"
    if resolved_target ~= "main_pawn" or event.ui_type ~= "app.ui040101_00" then
        return
    end

    local tracked_methods = {
        setupJobInfoWindow = true,
        setupJobWeapon = true,
        setupDisableJobs = true,
        setupJobMenuContentsInfo = true,
    }
    if not tracked_methods[event.method] then
        return
    end

    probe.seen_keys = probe.seen_keys or {}
    local followup_key = table.concat({
        tostring(event.method),
        tostring(event.phase),
        tostring(event.chara_id),
        tostring(targeted_ui_detail.selected_chara_id),
        tostring(targeted_ui_detail.flow_now),
        tostring(targeted_ui_detail.info_count),
        tostring(targeted_ui_detail.item_count),
    }, "|")
    if probe.seen_keys[followup_key] then
        return
    end
    probe.seen_keys[followup_key] = true

    table.insert(data.prune_followups, {
        time = event.time,
        method = event.method,
        phase = event.phase,
        target = resolved_target,
        chara_id = event.chara_id,
        current_job = event.current_job,
        flow_now = targeted_ui_detail.flow_now,
        info_count = targeted_ui_detail.info_count,
        item_count = targeted_ui_detail.item_count,
        last_info_name = targeted_ui_detail.last_info_entry_name,
        selected_chara_id = targeted_ui_detail.selected_chara_id,
        summary = event.summary,
    })
    trim_history(data.prune_followups, 24)

    probe.remaining = (probe.remaining or 0) - 1
    if probe.remaining <= 0 then
        data.active_prune_probe = nil
    end
end

local function record_field_snapshot(data, ui_type, method_name, keyword_fields)
    if keyword_fields == nil then
        return
    end

    local compact = {}
    local shown = 0
    for key, value in pairs(keyword_fields) do
        if shown >= config.guild_research.field_history_limit then
            break
        end
        compact[key] = value
        shown = shown + 1
    end

    table.insert(data.recent_field_sets, {
        time = string.format("%.3f", current_clock()),
        ui_type = ui_type,
        method = method_name,
        fields = compact,
    })
    trim_history(data.recent_field_sets, config.guild_research.field_history_limit)
end

local function refresh_aggressive_hook_session(data, event, targeted_ui_detail)
    local session = get_aggressive_hook_session(data)
    local now = current_clock()

    if session.active and session.full_enabled ~= true and now >= tonumber(session.expires_at or 0) then
        session.active = false
        session.last_reason = "expired"
        session.last_time = string.format("%.3f", now)
    end

    if session.active and session.full_enabled ~= true and (session.event_count or 0) >= (session.event_limit or 96) then
        session.active = false
        session.last_reason = "event_limit_reached"
        session.last_time = string.format("%.3f", now)
    end

    if session.enabled ~= true or session.auto_enabled ~= true or event == nil or targeted_ui_detail == nil then
        return session
    end

    if event.ui_type ~= "app.ui040101_00" then
        return session
    end

    local target_name = event.target_match and event.target_match.resolved_target or event.target_role or "unknown"
    if target_name ~= "player" and target_name ~= "main_pawn" then
        return session
    end

    if event.phase ~= "post" then
        return session
    end

    local auto_arm_methods = {
        setupJobMenu = true,
        setupJobMenuContentsInfo = true,
        updateJobMenu = true,
        setupDisableJobs = true,
    }
    if not auto_arm_methods[event.method] then
        return session
    end

    local effective_flow = resolve_effective_flow_now(data, target_name, targeted_ui_detail)
    local info_count = tonumber(targeted_ui_detail.info_count or 0) or 0
    local item_count = tonumber(targeted_ui_detail.item_count or 0) or 0
    local should_arm = tonumber(effective_flow) == 2 and info_count > 0 and item_count >= info_count
    if not should_arm then
        return session
    end

    local cooldown = tonumber(session.auto_cooldown_seconds or 20.0) or 20.0
    local same_target = tostring(session.last_auto_arm_target or "none") == tostring(target_name)
    if session.active == true and tostring(session.target or "none") == tostring(target_name) then
        return session
    end
    if same_target and (now - tonumber(session.last_auto_arm_time or 0)) < cooldown then
        session.last_reason = "auto_arm_cooldown"
        session.last_time = string.format("%.3f", now)
        return session
    end

    arm_aggressive_hook_session(
        session,
        target_name,
        tostring(event.method or "unknown"),
        "armed_auto"
    )
    session.last_auto_arm_time = now
    session.last_auto_arm_target = tostring(target_name)
    return session
end

local function should_force_aggressive_source_hook(this_obj, method_name)
    if method_name ~= "getJobInfoParam" and method_name ~= "addNormalContentsList" then
        return false
    end

    local data = ensure_runtime_data()
    local session = get_aggressive_hook_session(data)
    local now = current_clock()

    if session.active and session.full_enabled ~= true and now >= tonumber(session.expires_at or 0) then
        session.active = false
        session.last_reason = "expired"
        session.last_time = string.format("%.3f", now)
        return false
    end

    if session.active and session.full_enabled ~= true and (session.event_count or 0) >= (session.event_limit or 96) then
        session.active = false
        session.last_reason = "event_limit_reached"
        session.last_time = string.format("%.3f", now)
        return false
    end

    if session.enabled ~= true or session.active ~= true then
        return false
    end

    local context = resolve_event_context(this_obj)
    local target_match = build_target_match(context.job_context, context.chara_id)
    local target_name = target_match and target_match.resolved_target or "unknown"
    if target_name ~= "player" and target_name ~= "main_pawn" then
        return false
    end

    session.event_count = (session.event_count or 0) + 1
    session.last_reason = "capturing"
    session.last_time = string.format("%.3f", now)
    return true
end

local function record_event(ui_type, method_name, phase, this_obj, extra)
    local data = ensure_runtime_data()
    local runtime = state.runtime

    runtime.guild_trace_event_id = (runtime.guild_trace_event_id or 0) + 1

    local context = resolve_event_context(this_obj)
    local chara_id = context.chara_id
    local chara_id_source = context.chara_id_source
    local job_context = context.job_context
    local job_context_source = context.job_context_source

    local role = resolve_target_role(chara_id, job_context)
    local target_match = build_target_match(job_context, chara_id)
    local keyword_fields = snapshot_keyword_fields(this_obj)
    local method_results = call_candidate_methods(this_obj)
    local current_job = job_context and util.safe_field(job_context, "CurrentJob") or nil
    local is_pawn = util.safe_field(this_obj, "IsPawn")
    local is_pawn_source = is_pawn ~= nil and "field:IsPawn" or "unresolved"
    local is_open = first_present(method_results, { "get_IsOpen" })
    local is_visible = first_present(method_results, { "get_IsVisible" })
    local targeted_ui_detail = build_targeted_ui_detail(
        ui_type,
        this_obj,
        wants_deep_targeted_detail(ui_type, method_name) and "deep" or "basic"
    )
    local argument_summary = extra and extra.argument_summary or nil
    local override_summary = extra and extra.override_summary or nil

    local event = {
        id = runtime.guild_trace_event_id,
        time = string.format("%.3f", current_clock()),
        ui_type = ui_type,
        method = method_name,
        phase = phase,
        chara_id = chara_id,
        chara_id_source = chara_id_source,
        target_role = role,
        job_context = util.describe_obj(job_context),
        job_context_source = job_context_source,
        context_object = util.describe_obj(context.context_object),
        context_source = context.context_source,
        flow_id = extra and extra.flow_id or nil,
        argument = extra and extra.argument or nil,
        argument_summary = argument_summary,
        object = util.describe_obj(this_obj),
        current_job = current_job,
        is_pawn = is_pawn,
        is_pawn_source = is_pawn_source,
        is_open = is_open,
        is_visible = is_visible,
        target_match = target_match,
        current_window = first_present(method_results, { "get_CurrentWindowName", "get_CurrentWindow" }),
        focused_window = first_present(method_results, { "get_FocusedWindow", "get_FocusedControl" }),
        targeted_ui_detail = targeted_ui_detail,
        override_summary = override_summary,
    }

    refresh_aggressive_hook_session(data, event, targeted_ui_detail)

    event.summary = string.format(
        "%s %s %s chara_id=%s role=%s target=%s job=%s is_pawn=%s flow_id=%s args=%s override=%s",
        tostring(ui_type),
        tostring(method_name),
        tostring(phase),
        tostring(event.chara_id),
        tostring(event.target_role),
        tostring(target_match.resolved_target),
        tostring(event.current_job),
        tostring(event.is_pawn),
        tostring(event.flow_id),
        tostring(event.argument_summary),
        tostring(event.override_summary)
    )

    local last_event = data.recent_events[#data.recent_events]
    if last_event ~= nil
        and last_event.ui_type == event.ui_type
        and last_event.method == event.method
        and last_event.phase == event.phase
        and last_event.chara_id == event.chara_id
        and tostring(last_event.flow_id) == tostring(event.flow_id)
        and tostring(last_event.current_job) == tostring(event.current_job)
        and tostring(last_event.target_match and last_event.target_match.resolved_target) == tostring(target_match.resolved_target) then
        last_event.repeat_count = (last_event.repeat_count or 1) + 1
        last_event.time = event.time
        last_event.summary = event.summary .. " x" .. tostring(last_event.repeat_count)
        event = last_event
    else
        event.repeat_count = 1
        table.insert(data.recent_events, event)
        trim_history(data.recent_events, config.guild_research.event_history_limit)
    end

    data.event_count = data.event_count + 1
    data.last_event = event
    data.last_event_summary = event.summary
    data.guild_ui_hint = true
    data.trace_dirty = true

    data.active_ui[ui_type] = {
        object = event.object,
        method = method_name,
        phase = phase,
        chara_id = chara_id,
        target_role = role,
        flow_id = event.flow_id,
        argument = event.argument,
        job_context = event.job_context,
        current_job = event.current_job,
        is_pawn = event.is_pawn,
        chara_id_source = event.chara_id_source,
        job_context_source = event.job_context_source,
        is_pawn_source = event.is_pawn_source,
        is_open = event.is_open,
        is_visible = event.is_visible,
        target_match = target_match,
        method_results = method_results,
        keyword_fields = keyword_fields,
        current_window = event.current_window,
        focused_window = event.focused_window,
        updated_at = event.time,
        targeted_ui_detail = targeted_ui_detail,
    }

    record_field_snapshot(data, ui_type, method_name, keyword_fields)

    local unique_key = table.concat({
        tostring(ui_type),
        tostring(method_name),
        tostring(phase),
        tostring(target_match.resolved_target),
        tostring(chara_id),
        tostring(current_job),
        tostring(event.flow_id),
        tostring(is_pawn),
        tostring(job_context_source),
    }, "|")

    if not data.unique_event_keys[unique_key] then
        data.unique_event_keys[unique_key] = true
        table.insert(data.unique_events, {
            key = unique_key,
            time = event.time,
            ui_type = ui_type,
            method = method_name,
            phase = phase,
            resolved_target = target_match.resolved_target,
            chara_id = chara_id,
            current_job = current_job,
            flow_id = event.flow_id,
            is_pawn = is_pawn,
            chara_id_source = chara_id_source,
            job_context_source = job_context_source,
            summary = event.summary,
        })
        trim_history(data.unique_events, 48)
    end

    local observation_bucket = data.unique_ui_observations[ui_type]
    if observation_bucket == nil then
        observation_bucket = {}
        data.unique_ui_observations[ui_type] = observation_bucket
    end

    local observation_key = table.concat({
        tostring(target_match.resolved_target),
        tostring(chara_id),
        tostring(current_job),
        tostring(event.flow_id),
        tostring(is_pawn),
    }, "|")

    observation_bucket[observation_key] = string.format(
        "target=%s chara_id=%s job=%s flow_id=%s is_pawn=%s chara_src=%s job_ctx_src=%s",
        tostring(target_match.resolved_target),
        tostring(chara_id),
        tostring(current_job),
        tostring(event.flow_id),
        tostring(is_pawn),
        tostring(chara_id_source),
        tostring(job_context_source)
    )

    if targeted_ui_detail ~= nil then
        data.targeted_ui_details[ui_type] = targeted_ui_detail
        local target_bucket = data.targeted_ui_details_by_target[ui_type]
        if target_bucket == nil then
            target_bucket = {}
            data.targeted_ui_details_by_target[ui_type] = target_bucket
        end
        target_bucket[target_match.resolved_target] = targeted_ui_detail
        capture_setup_job_menu_contents_info_snapshot(data, event, targeted_ui_detail)
        update_setup_job_menu_comparison(data)
        cache_player_job_menu_source(data, event, targeted_ui_detail)
        if event.phase == "post" then
            local allowed_intervention_methods = {
                setupJobMenu = true,
                setupJobMenuContentsInfo = true,
                updateJobMenu = true,
                setupDisableJobs = true,
            }
            if allowed_intervention_methods[event.method] then
                local stage_result = attempt_stage_source_rewrite(data, event, targeted_ui_detail, event.method)
                record_multi_intervention_attempt(data, stage_result)
                if event.method == "setupJobMenuContentsInfo" then
                    data.manual_prune_rewrite = stage_result
                end
            end
        end
        maybe_capture_prune_followup(data, event, targeted_ui_detail)
        maybe_capture_source_rebuild_window(data, event, targeted_ui_detail)
        maybe_capture_source_state_window(data, event, targeted_ui_detail)
    end

    capture_source_method_snapshot(data, event, targeted_ui_detail, extra)
end

local function read_extra_argument(args, spec)
    if spec.extra == nil then
        return nil
    end

    local raw = args[3]
    if raw == nil then
        return nil
    end

    return tostring(raw)
end

local function is_hook_enabled(type_name, spec)
    if type_name == "app.ui040101_00" then
        if config.guild_research.enable_job_menu_ui_hooks == true then
            return true
        end

        if source_allowlisted_ui040101_hooks[spec.name] == true then
            return config.guild_research.enable_source_method_hooks == true
                or config.guild_research.enable_source_probe_once == true
        end

        return false
    end

    return true
end

local function try_register_hook(type_name, spec)
    if not is_hook_enabled(type_name, spec) then
        table.insert(skipped_hooks, type_name .. "::" .. spec.name .. " skipped=disabled_by_config")
        return
    end

    local td = util.safe_sdk_typedef(type_name)
    if td == nil then
        table.insert(registration_errors, type_name .. " missing")
        return
    end

    local ok_method, method = pcall(td.get_method, td, spec.name)
    if not ok_method or method == nil then
        table.insert(registration_errors, type_name .. "::" .. spec.name .. " missing")
        return
    end

    local ok_hook, err = pcall(function()
        sdk.hook(
            method,
            function(args)
                local ok_this, this_obj = pcall(sdk.to_managed_object, args[2])
                if not ok_this then
                    this_obj = nil
                end
                local storage = thread.get_hook_storage()
                storage.this_obj = this_obj
                storage.extra = {
                    argument = read_extra_argument(args, spec),
                    argument_summary = summarize_hook_args(args, 3, 4),
                    argument_details = is_source_method_name(spec.name) and capture_source_arg_descriptions(args, 3, 3) or nil,
                }
                if spec.extra == "flow_id" then
                    storage.extra.flow_id = storage.extra.argument
                end
                if is_source_method_name(spec.name) then
                    if config.guild_research.enable_source_method_hooks == true
                        or should_force_aggressive_source_hook(this_obj, spec.name) then
                        record_event(type_name, spec.name, "pre", this_obj, storage.extra)
                    end
                else
                    record_event(type_name, spec.name, "pre", this_obj, storage.extra)
                end
            end,
            function(retval)
                local storage = thread.get_hook_storage()
                storage.extra = storage.extra or {}
                storage.extra.raw_retval = retval
                storage.extra.retval_obj, storage.extra.retval_summary = resolve_hook_retval(retval)
                if type_name == "app.ui040101_00" and spec.name == "getJobInfoParam" then
                    storage.extra.job_info_override_summary = try_apply_job_info_pawn_override(storage.this_obj, storage.extra)
                end
                if type_name == "app.ui040101_00" and spec.name == "setupJobMenuContentsInfo" then
                    storage.extra.override_summary = maybe_apply_player_job_list_override(storage.this_obj, storage.extra)
                end
                if is_source_method_name(spec.name) then
                    if config.guild_research.enable_source_method_hooks == true
                        or should_force_aggressive_source_hook(storage.this_obj, spec.name) then
                        record_event(type_name, spec.name, "post", storage.this_obj, storage.extra)
                    else
                        maybe_capture_source_probe_once(spec.name, storage.this_obj, storage.extra)
                    end
                else
                    record_event(type_name, spec.name, "post", storage.this_obj, storage.extra)
                end
                if type_name == "app.ui040101_00"
                    and spec.name == "getJobInfoParam"
                    and storage.extra ~= nil
                    and type(storage.extra.job_info_override_summary) == "string"
                then
                    local data = ensure_runtime_data()
                    local override_state = data and data.job_info_pawn_override or nil
                    if override_state ~= nil
                        and override_state.override_retval ~= nil
                        and tostring(override_state.reason) == "player_job_info_retval_mirror"
                    then
                        storage.extra.override_retval = override_state.override_retval
                        retval = override_state.override_retval
                    end
                end

                return retval
            end
        )
    end)

    if not ok_hook then
        table.insert(registration_errors, type_name .. "::" .. spec.name .. " hook_failed=" .. tostring(err))
        return
    end

    table.insert(registered_hooks, type_name .. "::" .. spec.name)
end

local function ensure_hooks_registered()
    if hooks_registered then
        return
    end

    hooks_registered = true
    registration_errors = {}
    registered_hooks = {}
    skipped_hooks = {}

    for _, hook_group in ipairs(hook_specs) do
        for _, method_spec in ipairs(hook_group.methods) do
            try_register_hook(hook_group.type_name, method_spec)
        end
    end
end

local function build_signature(data)
    local parts = {
        tostring(data.guild_ui_hint),
        tostring(data.gui_manager),
        tostring(data.current_scene_name),
        tostring(data.current_state),
        tostring(data.current_menu),
        tostring(data.current_window),
        tostring(data.focused_window),
        tostring(data.main_pawn_job),
        tostring(data.player_job),
        tostring(data.event_count),
        tostring(data.last_event_summary),
    }

    local active_keys = {}
    for key, _ in pairs(data.active_ui or {}) do
        table.insert(active_keys, key)
    end
    table.sort(active_keys)

    for _, key in ipairs(active_keys) do
        local item = data.active_ui[key]
        table.insert(parts, key .. "=" .. tostring(item.method) .. ":" .. tostring(item.target_role) .. ":" .. tostring(item.flow_id))
    end

    local gui_keys = {}
    for key, _ in pairs(data.method_results or {}) do
        table.insert(gui_keys, key)
    end
    table.sort(gui_keys)

    for _, key in ipairs(gui_keys) do
        table.insert(parts, key .. "=" .. tostring(data.method_results[key]))
    end

    return table.concat(parts, "|")
end

local function detect_guild_ui_hint(method_results, keyword_fields, active_ui)
    if active_ui ~= nil then
        for _, item in pairs(active_ui) do
            if item ~= nil then
                return true
            end
        end
    end

    for _, value in pairs(method_results or {}) do
        if contains_keyword(tostring(value)) then
            return true
        end
    end

    for key, value in pairs(keyword_fields or {}) do
        if contains_keyword(tostring(key)) or contains_keyword(tostring(value)) then
            return true
        end
    end

    return false
end

function guild_flow_research.update()
    local runtime = state.runtime
    if not config.guild_research.enabled then
        runtime.guild_flow_research_data = nil
        return nil
    end

    ensure_hooks_registered()

    local data = ensure_runtime_data()
    local now = runtime.game_time or os.clock()
    local last_refresh = runtime.last_guild_flow_refresh or 0
    if now - last_refresh < config.guild_research.refresh_interval_seconds then
        return runtime.guild_flow_research_data
    end

    runtime.last_guild_flow_refresh = now
    discovery.refresh(false)

    local gui_manager = discovery.get_manager("GuiManager")
    local main_pawn_data = runtime.main_pawn_data
    local progression = runtime.progression_gate_data
    local method_results = call_candidate_methods(gui_manager)
    local keyword_fields = snapshot_keyword_fields(gui_manager)

    data.gui_manager = util.describe_obj(gui_manager)
    data.gui_manager_raw = gui_manager
    data.player_job = progression and progression.current_job or nil
    data.player_chara_id = get_player_chara_id()
    data.main_pawn_job = main_pawn_data and (main_pawn_data.current_job or main_pawn_data.job) or nil
    data.main_pawn_name = main_pawn_data and main_pawn_data.name or nil
    data.main_pawn_chara_id = get_main_pawn_chara_id()
    data.main_pawn_job_context = main_pawn_data and util.describe_obj(main_pawn_data.job_context) or nil
    data.player_job_context = progression and util.describe_obj(progression.job_context) or nil
    data.method_results = method_results
    data.keyword_fields = keyword_fields
    data.current_scene_name = first_present(method_results, {
        "get_CurrentSceneName",
        "get_CurrentScene",
        "get_SceneName",
    })
    data.current_state = first_present(method_results, {
        "get_CurrentGuiState",
        "get_CurrentState",
        "getMode",
    })
    data.current_menu = first_present(method_results, {
        "get_CurrentMenu",
    })
    data.current_window = first_present(method_results, {
        "get_CurrentWindowName",
        "get_CurrentWindow",
    })
    data.focused_window = first_present(method_results, {
        "get_FocusedWindow",
        "get_FocusedControl",
    })
    data.guild_ui_hint = detect_guild_ui_hint(method_results, keyword_fields, data.active_ui)
    data.context_alignment = summarize_context_alignment()
    data.trace_assessment = build_trace_assessment(data)
    data.signature = build_signature(data)
    data.signature_changed = data.signature ~= last_signature
    data.recent_events_for_log = take_recent_tail(data.recent_events, 10)
    data.recent_field_sets_for_log = take_recent_tail(data.recent_field_sets, 4)
    data.unique_events_for_log = take_recent_tail(data.unique_events, 24)

    last_signature = data.signature
    runtime.guild_flow_research_data = data
    return data
end

function guild_flow_research.get_capture_session_status()
    local data = ensure_runtime_data()
    local session = get_aggressive_hook_session(data)
    local now = current_clock()
    local remaining = 0
    if session.active == true then
        remaining = math.max(0, (tonumber(session.expires_at or 0) or 0) - now)
    end

    return {
        enabled = session.enabled == true,
        auto_enabled = session.auto_enabled == true,
        active = session.active == true,
        full_enabled = session.full_enabled == true,
        target = session.target,
        trigger_method = session.trigger_method,
        last_reason = session.last_reason,
        last_time = session.last_time,
        event_count = session.event_count or 0,
        event_limit = session.event_limit or 0,
        duration_seconds = session.duration_seconds or 0,
        auto_cooldown_seconds = session.auto_cooldown_seconds or 0,
        remaining_seconds = remaining,
    }
end

function guild_flow_research.arm_capture_session(target_name)
    local data = ensure_runtime_data()
    local session = get_aggressive_hook_session(data)
    if session.enabled ~= true then
        session.last_reason = "manual_arm_ignored_disabled"
        session.last_time = string.format("%.3f", current_clock())
        return false
    end

    arm_aggressive_hook_session(session, target_name or "manual", "manual_arm", "armed_manual")
    return true
end

function guild_flow_research.set_full_capture_enabled(enabled)
    local data = ensure_runtime_data()
    local session = get_aggressive_hook_session(data)
    local now = current_clock()
    session.full_enabled = enabled == true

    if session.full_enabled == true then
        session.active = session.enabled == true
        session.started_at = now
        session.expires_at = math.huge
        session.event_count = 0
        session.target = "full_session"
        session.trigger_method = "manual_full_toggle"
        session.last_reason = session.enabled == true and "full_capture_enabled" or "full_capture_enabled_but_disabled"
        session.last_time = string.format("%.3f", now)
        return session.enabled == true
    end

    session.active = false
    session.expires_at = 0
    session.target = "none"
    session.trigger_method = "manual_full_toggle"
    session.last_reason = "full_capture_disabled"
    session.last_time = string.format("%.3f", now)
    return true
end

return guild_flow_research

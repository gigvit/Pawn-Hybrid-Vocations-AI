local config = require("PawnHybridVocationsAI/config")
local state = require("PawnHybridVocationsAI/state")
local util = require("PawnHybridVocationsAI/core/util")
local hybrid_jobs = require("PawnHybridVocationsAI/data/hybrid_jobs")

local hybrid_unlock = {}

local ui_hook_installed = false
local player_job_info_cache = {}

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

local function current_actor_job(actor_state)
    if actor_state ~= nil then
        return actor_state.current_job or actor_state.raw_job
    end
    return nil
end

local function resolve_reason(target_supported, progression_allowed, runtime_ready, main_pawn_job, target_job)
    if not target_supported then
        return "unsupported_target_job"
    end
    if not progression_allowed then
        return "progression_gate_not_passed"
    end
    if not runtime_ready then
        return "main_pawn_runtime_not_ready"
    end
    if tonumber(main_pawn_job) == tonumber(target_job) then
        return "already_on_target_job"
    end
    return "ready_for_manual_runtime_write"
end

local function build_target_vocations(player_state, main_pawn_state)
    local result = {}

    for _, job in hybrid_jobs.each() do
        local player_entry = player_state and player_state.hybrid_gate_status and player_state.hybrid_gate_status[job.key] or nil
        local progression_allowed = player_entry and player_entry.qualified_bits and player_entry.qualified_bits.bit_job_minus_one or false
        local runtime_ready = main_pawn_state ~= nil
            and main_pawn_state.runtime_character ~= nil
            and main_pawn_state.job_context ~= nil
        local current_main_pawn_job = main_pawn_state and main_pawn_state.current_job or nil
        local reason = resolve_reason(true, progression_allowed, runtime_ready, current_main_pawn_job, job.id)

        result[job.key] = {
            job_id = job.id,
            label = job.label,
            target_supported = true,
            progression_rule = "player.QualifiedJobBits -> bit(job-1)",
            progression_allowed = progression_allowed,
            player_current_job = player_state and player_state.current_job or nil,
            main_pawn_current_job = current_main_pawn_job,
            runtime_ready = runtime_ready,
            ready_for_manual_runtime_write = reason == "ready_for_manual_runtime_write",
            reason = reason,
            direct_player_is_job_qualified = player_entry and player_entry.direct and player_entry.direct.is_job_qualified or nil,
            player_job_level = player_entry and player_entry.direct and player_entry.direct.job_level or nil,
        }
    end

    return result
end

local function decode_small_int(value)
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
    if parsed == nil or parsed < 0 or parsed > 1024 then
        return nil
    end

    return parsed
end

local function get_player_chara_id()
    return util.safe_direct_method(state.runtime.player, "get_CharaID")
        or util.safe_method(state.runtime.player, "get_CharaID()")
        or util.safe_method(state.runtime.player, "get_CharaID")
end

local function get_main_pawn_chara_id()
    local main_pawn_data = state.runtime.main_pawn_data
    return main_pawn_data and main_pawn_data.chara_id or nil
end

local function read_job_context_from_actor_state(actor_state)
    return actor_state and actor_state.job_context or nil
end

local function read_selected_chara_id(ui_obj)
    local chara_tab = util.safe_field(ui_obj, "_CharaTab")
        or util.safe_field(ui_obj, "CharaTab")
    if not util.is_valid_obj(chara_tab) then
        return nil
    end

    return util.safe_direct_method(chara_tab, "get_SelectedCharaID")
        or util.safe_method(chara_tab, "get_SelectedCharaID()")
        or util.safe_method(chara_tab, "get_SelectedCharaID")
end

local function read_context_from_object(obj)
    if not util.is_valid_obj(obj) then
        return nil, nil
    end

    local chara_id = util.safe_direct_method(obj, "getCharaId")
        or util.safe_method(obj, "getCharaId()")
        or util.safe_method(obj, "getCharaId")
    local job_context = util.safe_direct_method(obj, "getJobContext")
        or util.safe_method(obj, "getJobContext()")
        or util.safe_method(obj, "getJobContext")

    return chara_id, job_context
end

local function collect_related_context_objects(obj)
    local related = {}
    if not util.is_valid_obj(obj) then
        return related
    end

    for _, field_name in ipairs(context_owner_fields) do
        local value = util.safe_field(obj, field_name)
        if util.is_valid_obj(value) then
            table.insert(related, value)
        end
    end

    for _, method_name in ipairs(context_owner_methods) do
        local value = util.safe_direct_method(obj, method_name)
            or util.safe_method(obj, method_name .. "()")
            or util.safe_method(obj, method_name)
        if util.is_valid_obj(value) then
            table.insert(related, value)
        end
    end

    return related
end

local function resolve_target_role(ui_obj)
    local selected_chara_id = read_selected_chara_id(ui_obj)
    local player_chara_id = get_player_chara_id()
    local main_pawn_chara_id = get_main_pawn_chara_id()

    if selected_chara_id ~= nil then
        if player_chara_id ~= nil and tonumber(selected_chara_id) == tonumber(player_chara_id) then
            return "player"
        end
        if main_pawn_chara_id ~= nil and tonumber(selected_chara_id) == tonumber(main_pawn_chara_id) then
            return "main_pawn"
        end
    end

    local player_job_context = read_job_context_from_actor_state(state.runtime.progression_state_data and state.runtime.progression_state_data.player or nil)
    local main_pawn_job_context = read_job_context_from_actor_state(state.runtime.progression_state_data and state.runtime.progression_state_data.main_pawn or nil)
        or (state.runtime.main_pawn_data and state.runtime.main_pawn_data.job_context or nil)

    local queue = { ui_obj }
    local visited = {}
    local index = 1

    while queue[index] ~= nil and index <= 12 do
        local current = queue[index]
        index = index + 1

        if util.is_valid_obj(current) then
            local address = util.get_address(current)
            local visit_key = tostring(address or current)
            if not visited[visit_key] then
                visited[visit_key] = true

                local chara_id, job_context = read_context_from_object(current)
                if chara_id ~= nil then
                    if player_chara_id ~= nil and tonumber(chara_id) == tonumber(player_chara_id) then
                        return "player"
                    end
                    if main_pawn_chara_id ~= nil and tonumber(chara_id) == tonumber(main_pawn_chara_id) then
                        return "main_pawn"
                    end
                end

                if job_context ~= nil then
                    if player_job_context ~= nil and util.same_object(job_context, player_job_context) then
                        return "player"
                    end
                    if main_pawn_job_context ~= nil and util.same_object(job_context, main_pawn_job_context) then
                        return "main_pawn"
                    end
                end

                for _, related in ipairs(collect_related_context_objects(current)) do
                    table.insert(queue, related)
                end
            end
        end
    end

    return "unknown"
end

local function is_vocation_flow(ui_obj)
    local flow_now = util.safe_field(ui_obj, "_FlowNow")
        or util.safe_field(ui_obj, "FlowNow")
    local flow_value = tonumber(flow_now)
    return flow_value == 2 or flow_value == 24
end

local function read_job_id_from_job_info(retval_obj, raw_arg)
    local job_id = util.safe_field(retval_obj, "_JobID")
        or util.safe_field(retval_obj, "JobID")
        or util.safe_field(retval_obj, "_Id")
        or util.safe_field(retval_obj, "Id")
    if type(job_id) == "number" then
        return job_id
    end

    return decode_small_int(raw_arg)
end

local function is_main_pawn_hybrid_job_ready(job_id)
    local job = hybrid_jobs.get_by_id(job_id)
    if job == nil then
        return false
    end

    local progression = state.runtime.progression_state_data
    local pawn_state = progression and progression.main_pawn or nil
    local entry = pawn_state and pawn_state.hybrid_gate_status and pawn_state.hybrid_gate_status[job.key] or nil
    if entry == nil then
        return false
    end

    return entry.qualified_bits and entry.qualified_bits.bit_job_minus_one
        or entry.direct and entry.direct.is_job_qualified
        or false
end

local function try_enable_pawn_in_job_info(job_info)
    if not util.is_valid_obj(job_info) then
        return false
    end

    for _, field_name in ipairs({ "_EnablePawn", "EnablePawn" }) do
        if util.safe_set_field(job_info, field_name, true) then
            local value = util.safe_field(job_info, field_name)
            if value == true then
                return true
            end
        end
    end

    return false
end

function hybrid_unlock.install_hooks()
    if ui_hook_installed then
        return true
    end

    if config.hybrid_unlock.enable_guild_job_info_pawn_override ~= true then
        return false
    end

    local ok_td, td = pcall(sdk.find_type_definition, "app.ui040101_00")
    if not ok_td or td == nil then
        return false
    end

    local ok_method, method = pcall(td.get_method, td, "getJobInfoParam")
    if not ok_method or method == nil then
        return false
    end

    sdk.hook(
        method,
        function(args)
            local storage = thread.get_hook_storage()
            local ok_this, this_obj = pcall(sdk.to_managed_object, args[2])
            storage.this_obj = ok_this and this_obj or nil
            storage.raw_arg = args[3]
        end,
        function(retval)
            local storage = thread.get_hook_storage()
            local this_obj = storage and storage.this_obj or nil
            local raw_arg = storage and storage.raw_arg or nil

            local retval_obj = nil
            local ok_retval, managed_retval = pcall(sdk.to_managed_object, retval)
            if ok_retval and util.is_valid_obj(managed_retval) then
                retval_obj = managed_retval
            elseif util.is_valid_obj(retval) then
                retval_obj = retval
            end

            if not util.is_valid_obj(this_obj) or not util.is_valid_obj(retval_obj) then
                return retval
            end

            if not is_vocation_flow(this_obj) then
                return retval
            end

            local job_id = read_job_id_from_job_info(retval_obj, raw_arg)
            if type(job_id) ~= "number" or hybrid_jobs.get_by_id(job_id) == nil then
                return retval
            end

            local target_role = resolve_target_role(this_obj)
            if target_role == "player" then
                player_job_info_cache[job_id] = retval
                return retval
            end

            if target_role ~= "main_pawn" or not is_main_pawn_hybrid_job_ready(job_id) then
                return retval
            end

            if try_enable_pawn_in_job_info(retval_obj) then
                return retval
            end

            return player_job_info_cache[job_id] or retval
        end
    )

    ui_hook_installed = true
    return true
end

local function add_missing_bit(source_mask, target_mask, bit_index)
    if type(source_mask) ~= "number" or type(target_mask) ~= "number" or type(bit_index) ~= "number" or bit_index < 0 then
        return target_mask, false
    end

    if not util.has_bit(source_mask, bit_index) or util.has_bit(target_mask, bit_index) then
        return target_mask, false
    end

    return target_mask + (2 ^ bit_index), true
end

local function apply_progression_mirror(runtime, player_state, main_pawn_state)
    local result = {
        enabled = config.hybrid_unlock.auto_mirror_player_hybrid_bits == true,
        attempted = false,
        applied = false,
        reason = "not_attempted",
        before_qualified_job_bits = main_pawn_state and main_pawn_state.qualified_job_bits or nil,
        after_qualified_job_bits = main_pawn_state and main_pawn_state.qualified_job_bits or nil,
        changed_job_ids = {},
    }

    if result.enabled ~= true then
        result.reason = "mirror_disabled"
        return result
    end

    local player_context = player_state and player_state.job_context or nil
    local pawn_context = main_pawn_state and main_pawn_state.job_context or nil
    local player_bits = player_state and player_state.qualified_job_bits or nil
    local pawn_bits = main_pawn_state and main_pawn_state.qualified_job_bits or nil

    if player_state == nil or main_pawn_state == nil or player_context == nil or pawn_context == nil then
        result.reason = "state_unresolved"
        return result
    end

    if type(player_bits) ~= "number" or type(pawn_bits) ~= "number" then
        result.reason = "qualified_bits_unresolved"
        return result
    end

    result.attempted = true

    local after_bits = pawn_bits
    for _, job in hybrid_jobs.each() do
        local bit_index = job.id - 1
        local next_bits, changed = add_missing_bit(player_bits, after_bits, bit_index)
        after_bits = next_bits
        if changed then
            table.insert(result.changed_job_ids, job.id)
        end
    end

    result.after_qualified_job_bits = after_bits

    if #result.changed_job_ids == 0 then
        result.reason = "no_missing_hybrid_access_bits"
        return result
    end

    if not util.safe_set_field(pawn_context, "QualifiedJobBits", after_bits) then
        result.reason = "qualified_bits_write_failed"
        return result
    end

    main_pawn_state.qualified_job_bits = after_bits
    if type(main_pawn_state.qualified_job_map) == "table" then
        for _, job in hybrid_jobs.each() do
            local item = main_pawn_state.qualified_job_map[job.key]
            if item ~= nil then
                item.bit_job_minus_one = util.has_bit(after_bits, job.id - 1)
                item.bit_job = util.has_bit(after_bits, job.id)
            end
        end
    end
    if type(main_pawn_state.hybrid_gate_status) == "table" then
        for _, job in hybrid_jobs.each() do
            local item = main_pawn_state.hybrid_gate_status[job.key]
            if item ~= nil and type(item.qualified_bits) == "table" then
                item.qualified_bits.bit_job_minus_one = util.has_bit(after_bits, job.id - 1)
                item.qualified_bits.bit_job = util.has_bit(after_bits, job.id)
            end
        end
    end

    result.applied = true
    result.reason = "hybrid_access_bit_mirror_applied"
    return result
end

function hybrid_unlock.update()
    hybrid_unlock.install_hooks()

    local runtime = state.runtime
    local progression = runtime.progression_state_data
    local player_state = progression and progression.player or nil
    local main_pawn_state = progression and progression.main_pawn or nil
    local mirror = apply_progression_mirror(runtime, player_state, main_pawn_state)
    local target_job = config.hybrid_unlock.target_job
    local target = hybrid_jobs.get_by_id(target_job)
    local target_vocations = build_target_vocations(player_state, main_pawn_state)
    local target_status = target and target_vocations[target.key] or nil

    local data = {
        current_player_job = current_actor_job(player_state),
        current_main_pawn_job = current_actor_job(main_pawn_state),
        target_job = target_job,
        target_job_label = target and target.label or nil,
        target_supported = target ~= nil,
        target_progression_allowed = target_status and target_status.progression_allowed or false,
        runtime_ready = target_status and target_status.runtime_ready or false,
        ready_for_manual_runtime_write = target_status and target_status.ready_for_manual_runtime_write or false,
        reason = target_status and target_status.reason or "unsupported_target_job",
        target_vocations = target_vocations,
        mirror = mirror,
        ui = {
            guild_job_info_override_enabled = config.hybrid_unlock.enable_guild_job_info_pawn_override == true,
            guild_job_info_hook_installed = ui_hook_installed,
            cached_player_job_info_entries = (function()
                local count = 0
                for _, _ in pairs(player_job_info_cache) do
                    count = count + 1
                end
                return count
            end)(),
        },
    }

    runtime.hybrid_unlock_data = data
    return data
end

return hybrid_unlock

local state = require("PawnHybridVocationsAI/state")
local config = require("PawnHybridVocationsAI/config")
local util = require("PawnHybridVocationsAI/core/util")
local log = require("PawnHybridVocationsAI/core/log")
local hybrid_jobs = require("PawnHybridVocationsAI/data/hybrid_jobs")

local combat_research = {}

local HOOK_TYPES = {
    SKILL_CONTEXT = "skill_context",
    SKILL_AVAILABILITY = "skill_availability",
}

local function get_data(runtime)
    runtime.combat_research_data = runtime.combat_research_data or {
        hooks_installed = false,
        installed_methods = {},
        registration_errors = {},
        recent_events = {},
        last_event_signatures = {},
        latest_check_matrix = {},
        last_summary_signature = nil,
        stats = {
            availability_checks = 0,
            context_checks = 0,
            main_pawn_events = 0,
            player_events = 0,
        },
        summary = {
            main_pawn_ready = false,
            player_ready = false,
            main_pawn_job = nil,
            main_pawn_weapon_job = nil,
            player_job = nil,
            player_weapon_job = nil,
            main_pawn_skill_context = "nil",
            main_pawn_skill_availability = "nil",
            main_pawn_custom_skill_state = "nil",
            player_skill_context = "nil",
            player_skill_availability = "nil",
            player_custom_skill_state = "nil",
            player_full_node = "nil",
            player_upper_node = "nil",
            main_pawn_full_node = "nil",
            main_pawn_upper_node = "nil",
            main_pawn_current_job_skills = "",
            player_current_job_skills = "",
            player_baseline_mode = "general",
            main_pawn_baseline_mode = "general",
        },
    }
    return runtime.combat_research_data
end

local function to_managed(args, index)
    if args == nil then
        return nil
    end
    return sdk.to_managed_object(args[index])
end

local function to_number(value)
    if value == nil then
        return nil
    end
    local direct = tonumber(value)
    if direct ~= nil then
        return direct
    end
    return util.decode_numeric_like(value)
end

local function safe_index(container, index)
    if container == nil or index == nil then
        return nil
    end

    local ok, value = pcall(function()
        return container[index]
    end)
    if ok then
        return value
    end

    return nil
end

local function is_hybrid_job(job_id)
    return hybrid_jobs.is_hybrid_job(job_id)
end

local function allow_general_baseline(current_job, weapon_job)
    if is_hybrid_job(current_job) or is_hybrid_job(weapon_job) then
        return true
    end
    return config.combat_research.enable_general_combat_baseline == true
end

local function list_to_string(values)
    if values == nil or #values == 0 then
        return ""
    end
    local parts = {}
    for _, value in ipairs(values) do
        table.insert(parts, tostring(value))
    end
    return table.concat(parts, ",")
end

local function collect_skill_ids(skill_list_obj, limit)
    local ids = {}
    for _, item in ipairs(util.array_to_lua(skill_list_obj, limit or 8)) do
        local value = to_number(item and item.value__ or item)
        if value ~= nil then
            table.insert(ids, value)
        end
    end
    return ids
end

local function extract_equipped_skills(skill_context, current_job)
    if skill_context == nil or current_job == nil then
        return {}
    end

    local equipped = util.safe_field(skill_context, "EquipedSkills")
        or util.safe_field(skill_context, "EquippedSkills")
    if equipped == nil then
        return {}
    end

    local job_bucket = safe_index(equipped, current_job)
    if job_bucket == nil then
        job_bucket = safe_index(equipped, current_job - 1)
    end

    local skills = job_bucket and (util.safe_field(job_bucket, "Skills") or util.safe_field(job_bucket, "<Skills>k__BackingField")) or nil
    return collect_skill_ids(skills, 8)
end

local function resolve_target(instance, hook_type)
    local progression = state.runtime.progression_state_data
    if progression == nil or instance == nil then
        return "unknown", nil
    end

    local player = progression.player
    local pawn = progression.main_pawn

    if hook_type == HOOK_TYPES.SKILL_CONTEXT then
        if player ~= nil and util.same_object(instance, player.skill_context) then
            return "player", player
        end
        if pawn ~= nil and util.same_object(instance, pawn.skill_context) then
            return "main_pawn", pawn
        end
    elseif hook_type == HOOK_TYPES.SKILL_AVAILABILITY then
        if player ~= nil and util.same_object(instance, player.skill_availability) then
            return "player", player
        end
        if pawn ~= nil and util.same_object(instance, pawn.skill_availability) then
            return "main_pawn", pawn
        end
    end

    return "unknown", nil
end

local function append_event(runtime, event)
    local data = get_data(runtime)
    local signature = table.concat({
        tostring(event.name),
        tostring(event.target),
        tostring(event.method),
        tostring(event.skill_id),
        tostring(event.result_code ~= nil and event.result_code or event.result),
    }, "|")

    if data.last_event_signatures[event.name] == signature then
        return
    end
    data.last_event_signatures[event.name] = signature

    table.insert(data.recent_events, 1, event)
    while #data.recent_events > (config.combat_research.trace_history_limit or 24) do
        table.remove(data.recent_events)
    end

    if event.target == "main_pawn" then
        data.stats.main_pawn_events = data.stats.main_pawn_events + 1
    elseif event.target == "player" then
        data.stats.player_events = data.stats.player_events + 1
    end

    if event.hook_type == HOOK_TYPES.SKILL_AVAILABILITY then
        data.stats.availability_checks = data.stats.availability_checks + 1
    elseif event.hook_type == HOOK_TYPES.SKILL_CONTEXT then
        data.stats.context_checks = data.stats.context_checks + 1
    end

    if event.skill_id ~= nil then
        data.latest_check_matrix[string.format("%s:%s:%s", tostring(event.target), tostring(event.method), tostring(event.skill_id))] = {
            target = event.target,
            method = event.method,
            skill_id = event.skill_id,
            baseline_mode = event.baseline_mode,
            result = event.result,
            result_code = event.result_code,
            result_hex = event.result_hex,
            current_job = event.current_job,
            weapon_job = event.weapon_job,
            action_prefix = event.action_prefix,
        }
    end

    log.session_marker(runtime, "skill", event.name, event, string.format(
        "target=%s mode=%s job=%s method=%s skill=%s result=%s code=%s",
        tostring(event.target),
        tostring(event.baseline_mode),
        tostring(event.current_job),
        tostring(event.method),
        tostring(event.skill_id),
        tostring(event.result),
        tostring(event.result_hex or event.result_code)
    ))
end

local function build_event(instance, method_name, hook_type, arg_job, arg_skill, retval)
    local runtime = state.runtime
    local target, actor = resolve_target(instance, hook_type)
    if target == "unknown" or actor == nil then
        return nil
    end

    local current_job = actor.current_job or actor.raw_job
    local weapon_job = actor.weapon_job
    if not allow_general_baseline(current_job, weapon_job) then
        return nil
    end

    local decoded = util.decode_qualification_value(retval)
    local result = decoded and decoded.normalized_bool
    if result == nil then
        result = retval
    end

    return {
        name = "combat_skill_check_observed",
        source = "combat_research",
        hook_type = hook_type,
        method = method_name,
        target = target,
        current_job = current_job,
        weapon_job = weapon_job,
        action_prefix = hybrid_jobs.get_action_prefix(current_job),
        baseline_mode = is_hybrid_job(current_job) and "hybrid" or "general",
        job_arg = arg_job,
        skill_id = arg_skill,
        result = result,
        result_code = decoded and decoded.numeric or nil,
        result_hex = decoded and decoded.hex or nil,
        raw_retval = tostring(retval),
        equipped_current_job_skills = extract_equipped_skills(actor.skill_context, current_job),
        custom_skill_state = util.describe_obj(actor.custom_skill_state),
    }
end

local function register_hook(type_name, candidate_methods, hook_type, arg_map)
    local runtime = state.runtime
    local data = get_data(runtime)
    local td = util.safe_sdk_typedef(type_name)
    if td == nil then
        table.insert(data.registration_errors, string.format("%s typedef missing", tostring(type_name)))
        return false
    end

    local method = nil
    local method_name = nil
    for _, candidate in ipairs(candidate_methods) do
        local ok, resolved = pcall(function()
            return td:get_method(candidate)
        end)
        if ok and resolved ~= nil then
            method = resolved
            method_name = candidate
            break
        end
    end

    if method == nil then
        table.insert(data.registration_errors, string.format("%s method missing: %s", tostring(type_name), table.concat(candidate_methods, " | ")))
        return false
    end

    sdk.hook(
        method,
        function(args)
            local storage = thread.get_hook_storage()
            storage.instance = to_managed(args, 2)
            storage.arg_job = arg_map and arg_map.job and to_number(args[arg_map.job]) or nil
            storage.arg_skill = arg_map and arg_map.skill and to_number(args[arg_map.skill]) or nil
            storage.method_name = method_name
            storage.hook_type = hook_type
        end,
        function(retval)
            local storage = thread.get_hook_storage()
            local event = build_event(
                storage.instance,
                storage.method_name,
                storage.hook_type,
                storage.arg_job,
                storage.arg_skill,
                retval
            )
            if event ~= nil then
                append_event(runtime, event)
            end
            return retval
        end
    )

    table.insert(data.installed_methods, string.format("%s::%s", tostring(type_name), tostring(method_name)))
    return true
end

local function build_summary(runtime)
    local progression = runtime.progression_state_data
    local main_pawn_data = runtime.main_pawn_data
    local player = progression and progression.player or nil
    local pawn = progression and progression.main_pawn or nil

    return {
        player_ready = player ~= nil,
        main_pawn_ready = pawn ~= nil and main_pawn_data ~= nil,
        player_job = player and (player.current_job or player.raw_job) or nil,
        player_weapon_job = player and player.weapon_job or nil,
        main_pawn_job = pawn and (pawn.current_job or pawn.raw_job) or nil,
        main_pawn_weapon_job = pawn and pawn.weapon_job or (main_pawn_data and main_pawn_data.weapon_job or nil),
        player_skill_context = player and util.describe_obj(player.skill_context) or "nil",
        player_skill_availability = player and util.describe_obj(player.skill_availability) or "nil",
        player_custom_skill_state = player and util.describe_obj(player.custom_skill_state) or "nil",
        main_pawn_skill_context = pawn and util.describe_obj(pawn.skill_context) or "nil",
        main_pawn_skill_availability = pawn and util.describe_obj(pawn.skill_availability) or "nil",
        main_pawn_custom_skill_state = pawn and util.describe_obj(pawn.custom_skill_state) or "nil",
        player_current_job_skills = list_to_string(player and extract_equipped_skills(player.skill_context, player.current_job or player.raw_job) or {}),
        player_baseline_mode = player and (is_hybrid_job(player.current_job or player.raw_job) and "hybrid" or "general") or "general",
        main_pawn_current_job_skills = list_to_string(pawn and extract_equipped_skills(pawn.skill_context, pawn.current_job or pawn.raw_job) or {}),
        main_pawn_baseline_mode = pawn and (is_hybrid_job(pawn.current_job or pawn.raw_job) and "hybrid" or "general") or "general",
        player_full_node = player and player.full_node or "nil",
        player_upper_node = player and player.upper_node or "nil",
        main_pawn_full_node = main_pawn_data and main_pawn_data.full_node or "nil",
        main_pawn_upper_node = main_pawn_data and main_pawn_data.upper_node or "nil",
        main_pawn_action_manager = main_pawn_data and util.describe_obj(main_pawn_data.action_manager) or "nil",
    }
end

function combat_research.install_hooks(runtime)
    local data = get_data(runtime)
    if data.hooks_installed or not config.combat_research.enabled or not config.combat_research.enable_runtime_hooks then
        return
    end

    register_hook("app.HumanSkillAvailability", {
        "isCustomSkillAvailable(app.HumanCustomSkillID)",
        "isCustomSkillAvailable",
    }, HOOK_TYPES.SKILL_AVAILABILITY, { skill = 3 })

    register_hook("app.HumanSkillAvailability", {
        "hasItemNeededByCustomSkill(app.HumanCustomSkillID)",
        "hasItemNeededByCustomSkill",
    }, HOOK_TYPES.SKILL_AVAILABILITY, { skill = 3 })

    register_hook("app.HumanSkillAvailability", {
        "isEquipCurrentJobWeapon()",
        "isEquipCurrentJobWeapon",
    }, HOOK_TYPES.SKILL_AVAILABILITY, {})

    register_hook("app.HumanSkillContext", {
        "isCustomSkillEnable(app.HumanCustomSkillID)",
        "isCustomSkillEnable",
    }, HOOK_TYPES.SKILL_CONTEXT, { skill = 3 })

    register_hook("app.HumanSkillContext", {
        "hasEquipedSkill(app.Character.JobEnum, app.HumanCustomSkillID)",
        "hasEquipedSkill",
    }, HOOK_TYPES.SKILL_CONTEXT, { job = 3, skill = 4 })

    register_hook("app.HumanSkillContext", {
        "getCustomSkillLevel(app.HumanCustomSkillID)",
        "getCustomSkillLevel",
    }, HOOK_TYPES.SKILL_CONTEXT, { skill = 3 })

    register_hook("app.HumanSkillContext", {
        "isCustomSkillReachLevel(app.HumanCustomSkillID, app.HumanCustomSkillLevelNo)",
        "isCustomSkillReachLevel",
    }, HOOK_TYPES.SKILL_CONTEXT, { skill = 3 })

    data.hooks_installed = true
    data.summary = build_summary(runtime)
end

function combat_research.update(runtime)
    local data = get_data(runtime)
    data.summary = build_summary(runtime)

    local signature = table.concat({
        tostring(data.summary.player_job),
        tostring(data.summary.main_pawn_job),
        tostring(data.summary.main_pawn_weapon_job),
        tostring(data.summary.player_current_job_skills),
        tostring(data.summary.main_pawn_current_job_skills),
        tostring(data.summary.player_full_node),
        tostring(data.summary.player_upper_node),
        tostring(data.summary.main_pawn_full_node),
        tostring(data.summary.main_pawn_upper_node),
    }, "|")

    if data.last_summary_signature ~= signature then
        data.last_summary_signature = signature
        log.session_marker(runtime, "skill", "combat_runtime_summary_changed", data.summary, string.format(
            "player_job=%s/%s nodes=%s|%s main_pawn_job=%s/%s nodes=%s|%s pawn_skills=%s",
            tostring(data.summary.player_job),
            tostring(data.summary.player_weapon_job),
            tostring(data.summary.player_full_node),
            tostring(data.summary.player_upper_node),
            tostring(data.summary.main_pawn_job),
            tostring(data.summary.main_pawn_weapon_job),
            tostring(data.summary.main_pawn_full_node),
            tostring(data.summary.main_pawn_upper_node),
            tostring(data.summary.main_pawn_current_job_skills)
        ))
    end

    return data
end

return combat_research

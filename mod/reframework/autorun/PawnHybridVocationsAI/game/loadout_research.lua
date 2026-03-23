local state = require("PawnHybridVocationsAI/state")
local config = require("PawnHybridVocationsAI/config")
local util = require("PawnHybridVocationsAI/core/util")
local log = require("PawnHybridVocationsAI/core/log")
local hybrid_jobs = require("PawnHybridVocationsAI/data/hybrid_jobs")

local loadout_research = {}

local function get_vocation_data(runtime)
    runtime.vocation_research_data = runtime.vocation_research_data or {
        hooks_installed = false,
        installed_methods = {},
        registration_errors = {},
        recent_events = {},
        last_event_signatures = {},
        last_summary_signature = nil,
        stats = {
            purchase_events = 0,
            skill_set_events = 0,
        },
        summary = {
            purchase_policy = "per_character_required",
            player_job = nil,
            player_weapon_job = nil,
            player_access_current_job = nil,
            player_current_job_level = nil,
            player_current_job_skills = "",
            player_current_job_skill_levels = "",
            player_has_current_job_weapon = nil,
            player_purchase_like_ready = false,
            player_runtime_ready = false,
            main_pawn_job = nil,
            main_pawn_weapon_job = nil,
            main_pawn_access_current_job = nil,
            main_pawn_current_job_level = nil,
            main_pawn_current_job_skills = "",
            main_pawn_current_job_skill_levels = "",
            main_pawn_has_current_job_weapon = nil,
            main_pawn_purchase_like_ready = false,
            main_pawn_runtime_ready = false,
            access_gap = "unresolved",
            purchase_gap = "unresolved",
            current_job_gap = "unresolved",
        },
    }
    return runtime.vocation_research_data
end

local function get_ability_data(runtime)
    runtime.ability_research_data = runtime.ability_research_data or {
        hooks_installed = false,
        installed_methods = {},
        registration_errors = {},
        recent_events = {},
        last_summary_signature = nil,
        stats = {
            summary_changes = 0,
        },
        summary = {
            purchase_policy = "per_character_required",
            player_job = nil,
            player_ability_context = "nil",
            player_current_job_abilities = "",
            player_current_job_ability_count = 0,
            player_augment_ready = false,
            player_bucket_source = "nil",
            main_pawn_job = nil,
            main_pawn_ability_context = "nil",
            main_pawn_current_job_abilities = "",
            main_pawn_current_job_ability_count = 0,
            main_pawn_augment_ready = false,
            main_pawn_bucket_source = "nil",
            current_job_gap = "unresolved",
        },
    }
    return runtime.ability_research_data
end

local function get_loadout_data(runtime)
    runtime.loadout_research_data = runtime.loadout_research_data or {
        vocation = nil,
        ability = nil,
        summary = {
            player_job = nil,
            main_pawn_job = nil,
            skill_gap = "unresolved",
            ability_gap = "unresolved",
        },
    }
    return runtime.loadout_research_data
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

local function is_hybrid_job(job_id)
    return hybrid_jobs.is_hybrid_job(job_id)
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

local function collect_ability_ids(abilities_obj, limit)
    local ids = {}
    for _, item in ipairs(util.array_to_lua(abilities_obj, limit or 16)) do
        local value = to_number(item and item.value__ or item)
        if value ~= nil then
            table.insert(ids, value)
        end
    end
    return ids
end

local function resolve_actor_from_skill_context(instance)
    local progression = state.runtime.progression_state_data
    if progression == nil or instance == nil then
        return "unknown", nil
    end

    if progression.player ~= nil and util.same_object(instance, progression.player.skill_context) then
        return "player", progression.player
    end

    if progression.main_pawn ~= nil and util.same_object(instance, progression.main_pawn.skill_context) then
        return "main_pawn", progression.main_pawn
    end

    return "unknown", nil
end

local function call_get_equip_list(skill_context, job_id)
    if skill_context == nil or job_id == nil then
        return nil
    end

    return util.safe_direct_method(skill_context, "getEquipList", job_id)
        or util.safe_method(skill_context, "getEquipList(System.Int32)", job_id)
        or util.safe_method(skill_context, "getEquipList(app.Character.JobEnum)", job_id)
        or util.safe_method(skill_context, "getEquipList", job_id)
end

local function extract_equipped_skills(skill_context, current_job)
    if skill_context == nil or current_job == nil then
        return {}
    end

    local equip_list = call_get_equip_list(skill_context, current_job)
    local skills = equip_list and (util.safe_field(equip_list, "Skills") or util.safe_field(equip_list, "<Skills>k__BackingField")) or nil
    if skills ~= nil then
        return collect_skill_ids(skills, 8)
    end

    local equipped = util.safe_field(skill_context, "EquipedSkills") or util.safe_field(skill_context, "EquippedSkills")
    local bucket = nil
    if equipped ~= nil then
        bucket = equipped[current_job] or equipped[current_job - 1]
    end
    skills = bucket and (util.safe_field(bucket, "Skills") or util.safe_field(bucket, "<Skills>k__BackingField")) or nil
    return collect_skill_ids(skills, 8)
end

local function call_get_custom_skill_level(skill_context, skill_id)
    if skill_context == nil or skill_id == nil then
        return nil, nil
    end

    local retval = util.safe_direct_method(skill_context, "getCustomSkillLevel", skill_id)
        or util.safe_method(skill_context, "getCustomSkillLevel(app.HumanCustomSkillID)", skill_id)
        or util.safe_method(skill_context, "getCustomSkillLevel", skill_id)

    local decoded = util.decode_qualification_value(retval)
    return decoded and decoded.numeric or nil, decoded and decoded.hex or nil
end

local function build_skill_levels_string(skill_context, skill_ids)
    if skill_context == nil or skill_ids == nil or #skill_ids == 0 then
        return ""
    end

    local parts = {}
    for _, skill_id in ipairs(skill_ids) do
        local code, hex = call_get_custom_skill_level(skill_context, skill_id)
        table.insert(parts, string.format("%s=%s", tostring(skill_id), tostring(hex or code or "nil")))
    end
    return table.concat(parts, ",")
end

local function call_is_equip_current_job_weapon(skill_availability)
    if skill_availability == nil then
        return nil
    end

    local retval = util.safe_direct_method(skill_availability, "isEquipCurrentJobWeapon")
        or util.safe_method(skill_availability, "isEquipCurrentJobWeapon()")
        or util.safe_method(skill_availability, "isEquipCurrentJobWeapon")

    local decoded = util.decode_qualification_value(retval)
    if decoded ~= nil then
        return decoded.normalized_bool
    end
    return retval
end

local function get_access_current_job(actor)
    if actor == nil then
        return nil
    end

    local current_job = actor.current_job or actor.raw_job
    if current_job == nil then
        return nil
    end

    local diagnostics = actor.job_diagnostic_table or {}
    for _, item in pairs(diagnostics) do
        if item.id == current_job then
            return item.is_job_qualified
        end
    end

    return nil
end

local function get_current_job_level(actor)
    if actor == nil then
        return nil
    end

    local current_job = actor.current_job or actor.raw_job
    if current_job == nil then
        return nil
    end

    local diagnostics = actor.job_diagnostic_table or {}
    for _, item in pairs(diagnostics) do
        if item.id == current_job then
            return item.job_level
        end
    end

    return nil
end

local function summarize_vocation_actor(actor)
    if actor == nil then
        return {
            job = nil,
            weapon_job = nil,
            access_current_job = nil,
            current_job_level = nil,
            current_job_skills = "",
            current_job_skill_levels = "",
            has_current_job_weapon = nil,
            purchase_like_ready = false,
            runtime_ready = false,
        }
    end

    local current_job = actor.current_job or actor.raw_job
    local skills = extract_equipped_skills(actor.skill_context, current_job)
    local skill_levels = build_skill_levels_string(actor.skill_context, skills)
    local has_weapon = call_is_equip_current_job_weapon(actor.skill_availability)
    local access_current_job = get_access_current_job(actor)
    local current_job_level = get_current_job_level(actor)
    local purchase_like_ready = (current_job_level ~= nil and current_job_level > 0) or (#skills > 0)
    local runtime_ready = purchase_like_ready and has_weapon == true and #skills > 0

    return {
        job = current_job,
        weapon_job = actor.weapon_job,
        access_current_job = access_current_job,
        current_job_level = current_job_level,
        current_job_skills = list_to_string(skills),
        current_job_skill_levels = skill_levels,
        has_current_job_weapon = has_weapon,
        purchase_like_ready = purchase_like_ready,
        runtime_ready = runtime_ready,
    }
end

local function compute_vocation_gap(player_summary, pawn_summary)
    if player_summary.job == nil or pawn_summary.job == nil then
        return "unresolved"
    end
    if player_summary.job ~= pawn_summary.job then
        return "job_mismatch"
    end
    if player_summary.access_current_job and not pawn_summary.access_current_job then
        return "pawn_access_missing"
    end
    if player_summary.purchase_like_ready and not pawn_summary.purchase_like_ready then
        return "pawn_purchase_like_missing"
    end
    if player_summary.has_current_job_weapon == true and pawn_summary.has_current_job_weapon ~= true then
        return "pawn_weapon_not_ready"
    end
    if player_summary.runtime_ready and not pawn_summary.runtime_ready then
        return "pawn_runtime_not_ready"
    end
    return "aligned_or_other"
end

local function compute_access_gap(player_summary, pawn_summary)
    if player_summary.job == nil or pawn_summary.job == nil then
        return "unresolved"
    end
    if player_summary.job ~= pawn_summary.job then
        return "job_mismatch"
    end
    if player_summary.access_current_job and not pawn_summary.access_current_job then
        return "pawn_access_missing"
    end
    if pawn_summary.access_current_job and not player_summary.access_current_job then
        return "player_access_missing"
    end
    return "aligned_or_other"
end

local function compute_purchase_gap(player_summary, pawn_summary)
    if player_summary.job == nil or pawn_summary.job == nil then
        return "unresolved"
    end
    if player_summary.job ~= pawn_summary.job then
        return "job_mismatch"
    end
    if player_summary.purchase_like_ready and not pawn_summary.purchase_like_ready then
        return "pawn_purchase_missing"
    end
    if pawn_summary.purchase_like_ready and not player_summary.purchase_like_ready then
        return "player_purchase_missing"
    end
    if player_summary.current_job_skills ~= pawn_summary.current_job_skills then
        return "skill_loadout_diverges"
    end
    return "aligned_or_other"
end

local function append_vocation_event(runtime, event)
    local data = get_vocation_data(runtime)
    local signature = table.concat({
        tostring(event.name),
        tostring(event.target),
        tostring(event.method),
        tostring(event.job_id),
        tostring(event.skill_id),
        tostring(event.slot_index),
    }, "|")

    if data.last_event_signatures[event.name] == signature then
        return
    end
    data.last_event_signatures[event.name] = signature

    table.insert(data.recent_events, 1, event)
    while #data.recent_events > (config.vocation_research.trace_history_limit or 24) do
        table.remove(data.recent_events)
    end

    if event.name == "vocation_purchase_event_observed" then
        data.stats.purchase_events = data.stats.purchase_events + 1
    elseif event.name == "vocation_skill_set_event_observed" then
        data.stats.skill_set_events = data.stats.skill_set_events + 1
    end

    log.session_marker(runtime, "skill", event.name, event, string.format(
        "target=%s method=%s job=%s skill=%s slot=%s",
        tostring(event.target),
        tostring(event.method),
        tostring(event.job_id),
        tostring(event.skill_id),
        tostring(event.slot_index)
    ))
end

local function register_vocation_skill_hook(type_name, candidate_methods, event_builder)
    local runtime = state.runtime
    local data = get_vocation_data(runtime)
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
            storage.method_name = method_name
            storage.skill_id = to_number(args[3])
            storage.job_id = nil
            storage.slot_index = to_number(args[5])
            if string.find(method_name, "setSkill", 1, true) ~= nil then
                storage.job_id = to_number(args[3])
                storage.skill_id = to_number(args[4])
                storage.slot_index = to_number(args[5])
            else
                storage.job_id = nil
            end
        end,
        function(retval)
            local storage = thread.get_hook_storage()
            local event = event_builder(storage.instance, storage.method_name, storage.job_id, storage.skill_id, storage.slot_index, retval)
            if event ~= nil then
                append_vocation_event(runtime, event)
            end
            return retval
        end
    )

    table.insert(data.installed_methods, string.format("%s::%s", tostring(type_name), tostring(method_name)))
    return true
end

local function build_purchase_event(instance, method_name, job_id, skill_id, slot_index)
    local target, actor = resolve_actor_from_skill_context(instance)
    if target == "unknown" or actor == nil then
        return nil
    end

    local current_job = actor.current_job or actor.raw_job
    local relevant_job = job_id or current_job
    if not is_hybrid_job(relevant_job) and not is_hybrid_job(current_job) then
        return nil
    end

    return {
        name = "vocation_purchase_event_observed",
        source = "loadout_research",
        target = target,
        method = method_name,
        current_job = current_job,
        weapon_job = actor.weapon_job,
        job_id = job_id,
        skill_id = skill_id,
        slot_index = slot_index,
        current_job_level = get_current_job_level(actor),
        current_job_skills = extract_equipped_skills(actor.skill_context, current_job),
    }
end

local function build_skill_set_event(instance, method_name, job_id, skill_id, slot_index)
    local target, actor = resolve_actor_from_skill_context(instance)
    if target == "unknown" or actor == nil then
        return nil
    end

    local current_job = actor.current_job or actor.raw_job
    local relevant_job = job_id or current_job
    if not is_hybrid_job(relevant_job) and not is_hybrid_job(current_job) then
        return nil
    end

    return {
        name = "vocation_skill_set_event_observed",
        source = "loadout_research",
        target = target,
        method = method_name,
        current_job = current_job,
        weapon_job = actor.weapon_job,
        job_id = job_id,
        skill_id = skill_id,
        slot_index = slot_index,
        has_current_job_weapon = call_is_equip_current_job_weapon(actor.skill_availability),
        current_job_skills = extract_equipped_skills(actor.skill_context, relevant_job),
    }
end

local function build_vocation_summary(runtime)
    local progression = runtime.progression_state_data
    local player_summary = summarize_vocation_actor(progression and progression.player or nil)
    local pawn_summary = summarize_vocation_actor(progression and progression.main_pawn or nil)

    return {
        purchase_policy = "per_character_required",
        player_job = player_summary.job,
        player_weapon_job = player_summary.weapon_job,
        player_access_current_job = player_summary.access_current_job,
        player_current_job_level = player_summary.current_job_level,
        player_current_job_skills = player_summary.current_job_skills,
        player_current_job_skill_levels = player_summary.current_job_skill_levels,
        player_has_current_job_weapon = player_summary.has_current_job_weapon,
        player_purchase_like_ready = player_summary.purchase_like_ready,
        player_runtime_ready = player_summary.runtime_ready,
        main_pawn_job = pawn_summary.job,
        main_pawn_weapon_job = pawn_summary.weapon_job,
        main_pawn_access_current_job = pawn_summary.access_current_job,
        main_pawn_current_job_level = pawn_summary.current_job_level,
        main_pawn_current_job_skills = pawn_summary.current_job_skills,
        main_pawn_current_job_skill_levels = pawn_summary.current_job_skill_levels,
        main_pawn_has_current_job_weapon = pawn_summary.has_current_job_weapon,
        main_pawn_purchase_like_ready = pawn_summary.purchase_like_ready,
        main_pawn_runtime_ready = pawn_summary.runtime_ready,
        access_gap = compute_access_gap(player_summary, pawn_summary),
        purchase_gap = compute_purchase_gap(player_summary, pawn_summary),
        current_job_gap = compute_vocation_gap(player_summary, pawn_summary),
    }
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

local function resolve_current_job_bucket(ability_context, current_job)
    if ability_context == nil or current_job == nil then
        return nil, "missing_context_or_job"
    end

    local equipped = util.safe_field(ability_context, "EquipedAbilities")
        or util.safe_field(ability_context, "EquippedAbilities")
        or util.safe_field(ability_context, "<EquipedAbilities>k__BackingField")
        or util.safe_field(ability_context, "<EquippedAbilities>k__BackingField")
    if equipped == nil then
        return nil, "equipped_abilities_missing"
    end

    local bucket = safe_index(equipped, current_job)
    if bucket ~= nil then
        return bucket, "equipped[" .. tostring(current_job) .. "]"
    end

    bucket = safe_index(equipped, current_job - 1)
    if bucket ~= nil then
        return bucket, "equipped[" .. tostring(current_job - 1) .. "]"
    end

    return nil, "bucket_missing"
end

local function extract_current_job_abilities(ability_context, current_job)
    local bucket, bucket_source = resolve_current_job_bucket(ability_context, current_job)
    if bucket == nil then
        return {}, bucket_source
    end

    local abilities = util.safe_field(bucket, "Abilities")
        or util.safe_field(bucket, "<Abilities>k__BackingField")
    if abilities == nil then
        return {}, bucket_source .. ":abilities_missing"
    end

    return collect_ability_ids(abilities, 16), bucket_source
end

local function summarize_ability_actor(actor)
    if actor == nil then
        return {
            job = nil,
            ability_context = "nil",
            current_job_abilities = "",
            current_job_ability_count = 0,
            augment_ready = false,
            bucket_source = "nil",
        }
    end

    local current_job = actor.current_job or actor.raw_job
    local abilities, bucket_source = extract_current_job_abilities(actor.ability_context, current_job)

    return {
        job = current_job,
        ability_context = util.describe_obj(actor.ability_context),
        current_job_abilities = list_to_string(abilities),
        current_job_ability_count = #abilities,
        augment_ready = #abilities > 0,
        bucket_source = bucket_source,
    }
end

local function compute_ability_gap(player_summary, pawn_summary)
    if player_summary.job == nil or pawn_summary.job == nil then
        return "unresolved"
    end
    if player_summary.job ~= pawn_summary.job then
        return "job_mismatch"
    end
    if player_summary.augment_ready and not pawn_summary.augment_ready then
        return "pawn_augment_missing"
    end
    if player_summary.current_job_abilities ~= pawn_summary.current_job_abilities then
        return "augment_loadout_diverges"
    end
    return "aligned_or_other"
end

local function append_ability_event(runtime, event)
    local data = get_ability_data(runtime)
    table.insert(data.recent_events, 1, event)
    while #data.recent_events > (config.ability_research.trace_history_limit or 24) do
        table.remove(data.recent_events)
    end
    data.stats.summary_changes = (data.stats.summary_changes or 0) + 1

    log.session_marker(runtime, "skill", "ability_state_summary_changed", event, string.format(
        "player_job=%s abilities=%s pawn_job=%s abilities=%s gap=%s",
        tostring(event.player_job),
        tostring(event.player_current_job_abilities),
        tostring(event.main_pawn_job),
        tostring(event.main_pawn_current_job_abilities),
        tostring(event.current_job_gap)
    ))
end

local function build_ability_summary(runtime)
    local progression = runtime.progression_state_data
    local player_summary = summarize_ability_actor(progression and progression.player or nil)
    local pawn_summary = summarize_ability_actor(progression and progression.main_pawn or nil)

    return {
        purchase_policy = "per_character_required",
        player_job = player_summary.job,
        player_ability_context = player_summary.ability_context,
        player_current_job_abilities = player_summary.current_job_abilities,
        player_current_job_ability_count = player_summary.current_job_ability_count,
        player_augment_ready = player_summary.augment_ready,
        player_bucket_source = player_summary.bucket_source,
        main_pawn_job = pawn_summary.job,
        main_pawn_ability_context = pawn_summary.ability_context,
        main_pawn_current_job_abilities = pawn_summary.current_job_abilities,
        main_pawn_current_job_ability_count = pawn_summary.current_job_ability_count,
        main_pawn_augment_ready = pawn_summary.augment_ready,
        main_pawn_bucket_source = pawn_summary.bucket_source,
        current_job_gap = compute_ability_gap(player_summary, pawn_summary),
    }
end

local function refresh_combined_summary(runtime)
    local data = get_loadout_data(runtime)
    data.vocation = runtime.vocation_research_data
    data.ability = runtime.ability_research_data

    local vocation_summary = data.vocation and data.vocation.summary or {}
    local ability_summary = data.ability and data.ability.summary or {}
    data.summary = {
        player_job = vocation_summary.player_job or ability_summary.player_job,
        main_pawn_job = vocation_summary.main_pawn_job or ability_summary.main_pawn_job,
        skill_gap = vocation_summary.current_job_gap or "unresolved",
        ability_gap = ability_summary.current_job_gap or "unresolved",
    }

    return data
end

function loadout_research.install_hooks(runtime)
    local vocation_data = get_vocation_data(runtime)
    local ability_data = get_ability_data(runtime)
    get_loadout_data(runtime)

    if config.vocation_research.enabled and config.vocation_research.enable_runtime_hooks and not vocation_data.hooks_installed then
        register_vocation_skill_hook("app.HumanSkillContext", {
            "setCustomSkillLevelUp(app.HumanCustomSkillID)",
            "setCustomSkillLevelUp",
        }, build_purchase_event)

        register_vocation_skill_hook("app.HumanSkillContext", {
            "setSkill(app.Character.JobEnum, app.HumanCustomSkillID, System.Int32)",
            "setSkill(System.Int32, app.HumanCustomSkillID, System.Int32)",
            "setSkill",
        }, build_skill_set_event)

        vocation_data.hooks_installed = true
    end

    if config.ability_research.enabled and not ability_data.hooks_installed then
        ability_data.hooks_installed = true
    end

    if config.vocation_research.enabled then
        vocation_data.summary = build_vocation_summary(runtime)
    end
    if config.ability_research.enabled then
        ability_data.summary = build_ability_summary(runtime)
    end

    refresh_combined_summary(runtime)
end

function loadout_research.update(runtime)
    local vocation_data = get_vocation_data(runtime)
    local ability_data = get_ability_data(runtime)

    if config.vocation_research.enabled then
        vocation_data.summary = build_vocation_summary(runtime)

        local vocation_summary = vocation_data.summary or {}
        local vocation_signature = table.concat({
            tostring(vocation_summary.player_job),
            tostring(vocation_summary.player_current_job_level),
            tostring(vocation_summary.player_current_job_skills),
            tostring(vocation_summary.player_has_current_job_weapon),
            tostring(vocation_summary.access_gap),
            tostring(vocation_summary.purchase_gap),
            tostring(vocation_summary.main_pawn_job),
            tostring(vocation_summary.main_pawn_current_job_level),
            tostring(vocation_summary.main_pawn_current_job_skills),
            tostring(vocation_summary.main_pawn_has_current_job_weapon),
            tostring(vocation_summary.current_job_gap),
        }, "|")

        if vocation_data.last_summary_signature ~= vocation_signature then
            vocation_data.last_summary_signature = vocation_signature
            log.session_marker(runtime, "skill", "vocation_state_summary_changed", vocation_summary, string.format(
                "player=%s lvl=%s skills=%s weapon=%s pawn=%s lvl=%s skills=%s weapon=%s access_gap=%s purchase_gap=%s gap=%s",
                tostring(vocation_summary.player_job),
                tostring(vocation_summary.player_current_job_level),
                tostring(vocation_summary.player_current_job_skills),
                tostring(vocation_summary.player_has_current_job_weapon),
                tostring(vocation_summary.main_pawn_job),
                tostring(vocation_summary.main_pawn_current_job_level),
                tostring(vocation_summary.main_pawn_current_job_skills),
                tostring(vocation_summary.main_pawn_has_current_job_weapon),
                tostring(vocation_summary.access_gap),
                tostring(vocation_summary.purchase_gap),
                tostring(vocation_summary.current_job_gap)
            ))
        end
    end

    if config.ability_research.enabled then
        ability_data.summary = build_ability_summary(runtime)

        local ability_summary = ability_data.summary or {}
        local ability_signature = table.concat({
            tostring(ability_summary.player_job),
            tostring(ability_summary.player_current_job_abilities),
            tostring(ability_summary.main_pawn_job),
            tostring(ability_summary.main_pawn_current_job_abilities),
            tostring(ability_summary.current_job_gap),
        }, "|")

        if ability_data.last_summary_signature ~= ability_signature then
            ability_data.last_summary_signature = ability_signature
            append_ability_event(runtime, ability_summary)
        end
    end

    return refresh_combined_summary(runtime)
end

return loadout_research

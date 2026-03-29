local state = require("PawnHybridVocationsAI/state")
local util = require("PawnHybridVocationsAI/core/util")
local readers = require("PawnHybridVocationsAI/core/readers")
local main_pawn_properties = require("PawnHybridVocationsAI/game/main_pawn_properties")
local hybrid_jobs = require("PawnHybridVocationsAI/data/hybrid_jobs")
local vocation_skill_matrix = require("PawnHybridVocationsAI/data/vocation_skill_matrix")

local progression_state = {}

local ordered_jobs = {}

for _, job in vocation_skill_matrix.each() do
    table.insert(ordered_jobs, {
        id = tonumber(job.job_id),
        key = job.key,
        label = job.label,
    })
end

local call_first = readers.call_first
local field_first = readers.field_first

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
    if parsed == nil or parsed < 0 or parsed > 4096 then
        return nil
    end

    return parsed
end

local function decode_truthy(value)
    if type(value) == "boolean" then
        return value
    end

    local numeric = decode_small_int(value)
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

local function resolve_human(character)
    if character == nil then
        return nil, "unresolved"
    end

    if util.is_a(character, "app.Human") then
        return character, "direct_human"
    end

    local human = call_first(character, "get_Human") or field_first(character, "<Human>k__BackingField")
    return human, human ~= nil and "character" or "unresolved"
end

local function resolve_context(human, getter_name, field_name, unresolved_label)
    if human == nil then
        return nil, unresolved_label
    end

    local direct = call_first(human, getter_name)
    if direct ~= nil then
        return direct, "human:" .. getter_name
    end

    local field = field_first(human, field_name)
    if field ~= nil then
        return field, "human." .. field_name
    end

    return nil, unresolved_label
end

local function resolve_skill_availability(skill_context)
    if skill_context == nil then
        return nil, "skill_availability_unresolved"
    end

    local direct = call_first(skill_context, "get_Availability")
    if direct ~= nil then
        return direct, "skill_context:get_Availability"
    end

    local method = util.safe_method(skill_context, "get_SkillAvailability()")
        or util.safe_method(skill_context, "get_SkillAvailability")
    if method ~= nil then
        return method, "skill_context:get_SkillAvailability"
    end

    local field = field_first(skill_context, "<Availability>k__BackingField")
        or field_first(skill_context, "Availability")
        or field_first(skill_context, "<SkillAvailability>k__BackingField")
        or field_first(skill_context, "SkillAvailability")
    if field ~= nil then
        return field, "skill_context:Availability"
    end

    return nil, "skill_availability_unresolved"
end

local function call_is_job_qualified(job_context, job_id)
    if job_context == nil then
        return nil
    end

    return util.safe_direct_method(job_context, "isJobQualified", job_id)
        or util.safe_method(job_context, "isJobQualified(System.Int32)", job_id)
        or util.safe_method(job_context, "isJobQualified(app.Character.JobEnum)", job_id)
        or util.safe_method(job_context, "isJobQualified", job_id)
end

local function call_get_job_level(job_context, job_id)
    if job_context == nil then
        return nil
    end

    return util.safe_direct_method(job_context, "getJobLevel", job_id)
        or util.safe_method(job_context, "getJobLevel(System.Int32)", job_id)
        or util.safe_method(job_context, "getJobLevel(app.Character.JobEnum)", job_id)
        or util.safe_method(job_context, "getJobLevel", job_id)
end

local function call_get_custom_skill_level(skill_context, skill_id)
    if skill_context == nil or skill_id == nil then
        return nil
    end

    return util.safe_direct_method(skill_context, "getCustomSkillLevel", skill_id)
        or util.safe_method(skill_context, "getCustomSkillLevel(app.HumanCustomSkillID)", skill_id)
        or util.safe_method(skill_context, "getCustomSkillLevel", skill_id)
end

local function call_has_equipped_skill(skill_context, job_id, skill_id)
    if skill_context == nil or job_id == nil or skill_id == nil then
        return nil
    end

    return util.safe_direct_method(skill_context, "hasEquipedSkill", job_id, skill_id)
        or util.safe_method(skill_context, "hasEquipedSkill(app.Character.JobEnum, app.HumanCustomSkillID)", job_id, skill_id)
        or util.safe_method(skill_context, "hasEquipedSkill", job_id, skill_id)
end

local function call_is_custom_skill_enable(skill_context, skill_id)
    if skill_context == nil or skill_id == nil then
        return nil
    end

    return util.safe_direct_method(skill_context, "isCustomSkillEnable", skill_id)
        or util.safe_method(skill_context, "isCustomSkillEnable(app.HumanCustomSkillID)", skill_id)
        or util.safe_method(skill_context, "isCustomSkillEnable", skill_id)
end

local function call_is_custom_skill_available(skill_availability, skill_id)
    if skill_availability == nil or skill_id == nil then
        return nil
    end

    return util.safe_direct_method(skill_availability, "isCustomSkillAvailable", skill_id)
        or util.safe_method(skill_availability, "isCustomSkillAvailable(app.HumanCustomSkillID)", skill_id)
        or util.safe_method(skill_availability, "isCustomSkillAvailable", skill_id)
end

local function get_current_node(action_manager, layer_index)
    local fsm = field_first(action_manager, "Fsm")
    if fsm == nil then
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

local function build_bit_map(mask)
    local map = {}
    for _, job in ipairs(ordered_jobs) do
        map[job.key] = {
            id = job.id,
            label = job.label,
            bit_job = util.has_bit(mask, job.id),
            bit_job_minus_one = util.has_bit(mask, job.id - 1),
        }
    end
    return map
end

local function build_job_diagnostic_table(job_context)
    local diagnostics = {}
    for _, job in ipairs(ordered_jobs) do
        diagnostics[job.key] = {
            id = job.id,
            label = job.label,
            is_job_qualified = call_is_job_qualified(job_context, job.id),
            job_level = call_get_job_level(job_context, job.id),
        }
    end
    return diagnostics
end

local function build_hybrid_gate_status(job_context, qualified_bits, viewed_bits, changed_bits)
    local result = {}

    for _, key in ipairs(hybrid_jobs.keys) do
        local job = hybrid_jobs.get_by_key(key)
        result[key] = {
            id = job.id,
            qualified_bits = {
                bit_job = util.has_bit(qualified_bits, job.id),
                bit_job_minus_one = util.has_bit(qualified_bits, job.id - 1),
            },
            viewed_bits = {
                bit_job = util.has_bit(viewed_bits, job.id),
                bit_job_minus_one = util.has_bit(viewed_bits, job.id - 1),
            },
            changed_bits = {
                bit_job = util.has_bit(changed_bits, job.id),
                bit_job_minus_one = util.has_bit(changed_bits, job.id - 1),
            },
            direct = {
                is_job_qualified = call_is_job_qualified(job_context, job.id),
                job_level = call_get_job_level(job_context, job.id),
            },
        }
    end

    return result
end

local function collect_job_custom_skills(job_entry)
    local skills = {}
    for _, skill in ipairs(job_entry and job_entry.custom_skills or {}) do
        skills[#skills + 1] = skill
    end
    for _, skill in ipairs(job_entry and job_entry.special_custom_skills or {}) do
        skills[#skills + 1] = skill
    end
    return skills
end

local function resolve_skill_job_level_requirement(skill_entry)
    local progression = type(skill_entry and skill_entry.progression) == "table" and skill_entry.progression or nil
    local direct_requirement = progression and tonumber(progression.job_level_requirement) or nil
    if direct_requirement ~= nil then
        return direct_requirement, "progression.job_level_requirement"
    end

    local runtime_phase = type(skill_entry and skill_entry.runtime_phase) == "table" and skill_entry.runtime_phase or nil
    local runtime_requirement = runtime_phase and tonumber(runtime_phase.min_job_level) or nil
    if runtime_requirement ~= nil then
        return runtime_requirement, "runtime_phase.min_job_level"
    end

    return nil, "unresolved"
end

local function classify_skill_stage(entry)
    if entry.learned == true
        and entry.equipped == true
        and entry.enabled == true
        and entry.available ~= false then
        return "combat_ready"
    end
    if entry.learned == true and entry.equipped == true then
        return "equipped"
    end
    if entry.learned == true then
        return "learned"
    end
    if entry.unlockable == true then
        return "unlockable"
    end
    return "potential"
end

local function build_current_job_skill_lifecycle(actor_state)
    local current_job = decode_small_int(actor_state and actor_state.current_job)
    local job_entry = vocation_skill_matrix.get_job(current_job)
    if job_entry == nil then
        return nil
    end

    local current_job_level = decode_small_int(actor_state and actor_state.current_job_level)
    local skills_by_id = {}
    local groups = {
        potential = {},
        unlockable = {},
        learned = {},
        equipped = {},
        combat_ready = {},
    }

    for _, skill_entry in ipairs(collect_job_custom_skills(job_entry)) do
        local skill_id = tonumber(skill_entry and skill_entry.id)
        if skill_id ~= nil then
            local current_skill_level = decode_small_int(call_get_custom_skill_level(actor_state.skill_context, skill_id))
            local learned = current_skill_level ~= nil and current_skill_level > 0 or nil
            local equipped = decode_truthy(call_has_equipped_skill(actor_state.skill_context, current_job, skill_id))
            local enabled = decode_truthy(call_is_custom_skill_enable(actor_state.skill_context, skill_id))
            local available = decode_truthy(call_is_custom_skill_available(actor_state.skill_availability, skill_id))
            local job_level_requirement, job_level_requirement_source = resolve_skill_job_level_requirement(skill_entry)

            local unlockable = nil
            if learned == true then
                unlockable = true
            elseif current_job_level ~= nil and job_level_requirement ~= nil then
                unlockable = current_job_level >= job_level_requirement
            end

            local item = {
                id = skill_id,
                name = tostring(skill_entry.name or ("skill_" .. tostring(skill_id))),
                job_id = tonumber(skill_entry.job_id or current_job),
                job_key = tostring(skill_entry.job_key or job_entry.key or "unknown"),
                progression_layer = skill_entry.progression and skill_entry.progression.layer or "custom_skill",
                current_job_level = current_job_level,
                job_level_requirement = job_level_requirement,
                job_level_requirement_source = job_level_requirement_source,
                current_skill_level = current_skill_level,
                learned = learned,
                equipped = equipped,
                enabled = enabled,
                available = available,
                unlockable = unlockable,
            }
            item.stage = classify_skill_stage(item)
            item.combat_ready = item.stage == "combat_ready"

            skills_by_id[skill_id] = item
            groups[item.stage][#groups[item.stage] + 1] = skill_id
        end
    end

    for _, values in pairs(groups) do
        table.sort(values)
    end

    return {
        job_id = current_job,
        job_key = tostring(job_entry.key or "unknown"),
        current_job_level = current_job_level,
        skills_by_id = skills_by_id,
        groups = groups,
    }
end

local function build_actor_state(label, runtime_character, fallback_human)
    if runtime_character == nil and fallback_human == nil then
        return nil
    end

    local human, human_source = resolve_human(runtime_character)
    if human == nil then
        human = fallback_human
        human_source = human ~= nil and "fallback_human" or "unresolved"
    end

    local job_context, job_context_source = resolve_context(human, "get_JobContext", "<JobContext>k__BackingField", "job_context_unresolved")
    local skill_context, skill_context_source = resolve_context(human, "get_SkillContext", "<SkillContext>k__BackingField", "skill_context_unresolved")
    local ability_context, ability_context_source = resolve_context(human, "get_AbilityContext", "<AbilityContext>k__BackingField", "ability_context_unresolved")
    local skill_availability, skill_availability_source = resolve_skill_availability(skill_context)
    local job_changer, job_changer_source = resolve_context(human, "get_JobChanger", "<JobChanger>k__BackingField", "job_changer_unresolved")
    local action_manager = runtime_character and call_first(runtime_character, "get_ActionManager") or nil
    local object = runtime_character and util.resolve_game_object(runtime_character, false) or nil

    local qualified_bits = job_context and field_first(job_context, "QualifiedJobBits") or nil
    local viewed_bits = job_context and field_first(job_context, "ViewedNewJobBits") or nil
    local changed_bits = job_context and field_first(job_context, "ChangedJobBits") or nil
    local raw_job = runtime_character and field_first(runtime_character, "Job") or nil
    local current_job = job_context and field_first(job_context, "CurrentJob") or raw_job
    local custom_skill_state = human and field_first(human, "<CustomSkillState>k__BackingField") or nil
    local current_job_level = call_get_job_level(job_context, current_job)
    local current_job_skill_lifecycle = build_current_job_skill_lifecycle({
        current_job = current_job,
        current_job_level = current_job_level,
        skill_context = skill_context,
        skill_availability = skill_availability,
    })

    return {
        label = label,
        runtime_character = runtime_character,
        human = human,
        human_source = human_source,
        object = object,
        name = object and call_first(object, "get_Name") or nil,
        chara_id = runtime_character and call_first(runtime_character, "get_CharaID") or nil,
        raw_job = raw_job,
        weapon_job = runtime_character and field_first(runtime_character, "WeaponJob") or nil,
        current_job = current_job,
        current_job_level = current_job_level,
        job_context = job_context,
        job_context_source = job_context_source,
        skill_context = skill_context,
        skill_context_source = skill_context_source,
        ability_context = ability_context,
        ability_context_source = ability_context_source,
        skill_availability = skill_availability,
        skill_availability_source = skill_availability_source,
        custom_skill_state = custom_skill_state,
        current_job_skill_lifecycle = current_job_skill_lifecycle,
        job_changer = job_changer,
        job_changer_source = job_changer_source,
        action_manager = action_manager,
        full_node = get_current_node(action_manager, 0),
        upper_node = get_current_node(action_manager, 1),
        qualified_job_bits = qualified_bits,
        viewed_new_job_bits = viewed_bits,
        changed_job_bits = changed_bits,
        qualified_job_map = build_bit_map(qualified_bits),
        viewed_job_map = build_bit_map(viewed_bits),
        changed_job_map = build_bit_map(changed_bits),
        job_diagnostic_table = build_job_diagnostic_table(job_context),
        hybrid_gate_status = build_hybrid_gate_status(job_context, qualified_bits, viewed_bits, changed_bits),
    }
end

local function build_alignment(player_state, main_pawn_state)
    if player_state == nil or main_pawn_state == nil then
        return nil
    end

    local qualified_match = true
    local viewed_match = true
    local changed_match = true
    local hybrid = {}

    for _, key in ipairs(hybrid_jobs.keys) do
        local player_entry = player_state.hybrid_gate_status[key]
        local pawn_entry = main_pawn_state.hybrid_gate_status[key]
        local item = {
            player_qualified = player_entry.qualified_bits.bit_job_minus_one,
            pawn_qualified = pawn_entry.qualified_bits.bit_job_minus_one,
            player_viewed = player_entry.viewed_bits.bit_job_minus_one,
            pawn_viewed = pawn_entry.viewed_bits.bit_job_minus_one,
            player_changed = player_entry.changed_bits.bit_job_minus_one,
            pawn_changed = pawn_entry.changed_bits.bit_job_minus_one,
            player_is_job_qualified = player_entry.direct.is_job_qualified,
            pawn_is_job_qualified = pawn_entry.direct.is_job_qualified,
            player_job_level = player_entry.direct.job_level,
            pawn_job_level = pawn_entry.direct.job_level,
        }

        item.qualified_match = item.player_qualified == item.pawn_qualified
        item.viewed_match = item.player_viewed == item.pawn_viewed
        item.changed_match = item.player_changed == item.pawn_changed

        qualified_match = qualified_match and item.qualified_match
        viewed_match = viewed_match and item.viewed_match
        changed_match = changed_match and item.changed_match
        hybrid[key] = item
    end

    local dominant_gap = "no_hybrid_gap"
    if not qualified_match and viewed_match then
        dominant_gap = "qualified_diverges_first"
    elseif not qualified_match and not viewed_match then
        dominant_gap = "qualified_and_viewed_diverge"
    elseif qualified_match and not viewed_match then
        dominant_gap = "viewed_diverges_first"
    elseif not changed_match then
        dominant_gap = "changed_diverges"
    end

    return {
        player_job = player_state.current_job,
        main_pawn_job = main_pawn_state.current_job,
        main_pawn_weapon_job = main_pawn_state.weapon_job,
        qualified_match = qualified_match,
        viewed_match = viewed_match,
        changed_match = changed_match,
        dominant_gap = dominant_gap,
        hybrid = hybrid,
    }
end

local function build_summary(player_state, main_pawn_state, alignment)
    return {
        player_ready = player_state ~= nil,
        main_pawn_ready = main_pawn_state ~= nil,
        player_current_job = player_state and player_state.current_job or nil,
        main_pawn_current_job = main_pawn_state and main_pawn_state.current_job or nil,
        qualified_match = alignment and alignment.qualified_match or nil,
        viewed_match = alignment and alignment.viewed_match or nil,
        changed_match = alignment and alignment.changed_match or nil,
        dominant_gap = alignment and alignment.dominant_gap or "unresolved",
        player_job_context_source = player_state and player_state.job_context_source or "unresolved",
        main_pawn_job_context_source = main_pawn_state and main_pawn_state.job_context_source or "unresolved",
        player_job_changer_source = player_state and player_state.job_changer_source or "unresolved",
        main_pawn_job_changer_source = main_pawn_state and main_pawn_state.job_changer_source or "unresolved",
    }
end

function progression_state.update()
    local runtime = state.runtime
    local main_pawn_data, main_pawn_resolution_source, main_pawn_resolution_age = main_pawn_properties.get_resolved_main_pawn_data(
        runtime,
        "progression_main_pawn_data_unresolved"
    )

    local player_state = build_actor_state("player", runtime.player, nil)
    local main_pawn_state = build_actor_state(
        "main_pawn",
        main_pawn_data and main_pawn_data.runtime_character or nil,
        main_pawn_data and main_pawn_data.human or nil
    )
    local alignment = build_alignment(player_state, main_pawn_state)

    local data = {
        player = player_state,
        main_pawn = main_pawn_state,
        alignment = alignment,
        summary = build_summary(player_state, main_pawn_state, alignment),
        main_pawn_context_resolution_source = main_pawn_resolution_source,
        main_pawn_context_resolution_age = main_pawn_resolution_age,
    }

    data.summary.main_pawn_context_resolution_source = main_pawn_resolution_source
    data.summary.main_pawn_context_resolution_age = main_pawn_resolution_age

    runtime.progression_state_data = data
    return data
end

return progression_state

local state = require("PawnHybridVocationsAI/state")
local util = require("PawnHybridVocationsAI/core/util")
local hybrid_jobs = require("PawnHybridVocationsAI/data/hybrid_jobs")

local progression_state = {}

local ordered_jobs = {
    { id = 1, key = "fighter", label = "Fighter" },
    { id = 2, key = "archer", label = "Archer" },
    { id = 3, key = "mage", label = "Mage" },
    { id = 4, key = "thief", label = "Thief" },
    { id = 5, key = "warrior", label = "Warrior" },
    { id = 6, key = "sorcerer", label = "Sorcerer" },
}

for _, job in hybrid_jobs.each() do
    table.insert(ordered_jobs, { id = job.id, key = job.key, label = job.label })
end

local function call_first(obj, method_name)
    return util.safe_direct_method(obj, method_name)
        or util.safe_method(obj, method_name .. "()")
        or util.safe_method(obj, method_name)
end

local function field_first(obj, field_name)
    return util.safe_field(obj, field_name)
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
    local object = runtime_character and call_first(runtime_character, "get_GameObject") or nil

    local qualified_bits = job_context and field_first(job_context, "QualifiedJobBits") or nil
    local viewed_bits = job_context and field_first(job_context, "ViewedNewJobBits") or nil
    local changed_bits = job_context and field_first(job_context, "ChangedJobBits") or nil
    local raw_job = runtime_character and field_first(runtime_character, "Job") or nil
    local current_job = job_context and field_first(job_context, "CurrentJob") or raw_job
    local custom_skill_state = human and field_first(human, "<CustomSkillState>k__BackingField") or nil
    local current_job_level = call_get_job_level(job_context, current_job)

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
    local main_pawn_data = runtime.main_pawn_data

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
    }

    runtime.progression_state_data = data
    return data
end

return progression_state

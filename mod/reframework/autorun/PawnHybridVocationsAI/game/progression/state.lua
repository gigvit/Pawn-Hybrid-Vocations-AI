local state = require("PawnHybridVocationsAI/state")
local config = require("PawnHybridVocationsAI/config")
local util = require("PawnHybridVocationsAI/core/util")
local log = require("PawnHybridVocationsAI/core/log")
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

local function snapshot_fields(obj, limit)
    local snapshot = {}
    for _, entry in ipairs(util.get_fields_snapshot(obj, limit or config.debug.targeted_snapshot_limit)) do
        snapshot[entry.name] = entry.value
    end
    return snapshot
end

local function first_non_nil(...)
    for _, value in ipairs({...}) do
        if value ~= nil then
            return value
        end
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

    local direct = util.safe_direct_method(character, "get_Human")
    if direct ~= nil then
        return direct, "character:get_Human()"
    end

    local method = util.safe_method(character, "get_Human")
    if method ~= nil then
        return method, "character:get_Human"
    end

    local field = util.safe_field(character, "<Human>k__BackingField")
    if field ~= nil then
        return field, "character.<Human>k__BackingField"
    end

    return nil, "unresolved"
end

local function resolve_context(human, direct_name, method_name, field_name, unresolved_label)
    if human == nil then
        return nil, unresolved_label or "unresolved"
    end

    local direct = util.safe_direct_method(human, direct_name)
    if direct ~= nil then
        return direct, "human:" .. tostring(method_name or direct_name) .. "()"
    end

    local method = util.safe_method(human, method_name or direct_name)
    if method ~= nil then
        return method, "human:" .. tostring(method_name or direct_name)
    end

    local field = util.safe_field(human, field_name)
    if field ~= nil then
        return field, "human." .. tostring(field_name)
    end

    return nil, unresolved_label or "unresolved"
end

local function resolve_job_context(human)
    return resolve_context(human, "get_JobContext", "get_JobContext()", "<JobContext>k__BackingField", "job_context_unresolved")
end

local function resolve_skill_context(human)
    return resolve_context(human, "get_SkillContext", "get_SkillContext()", "<SkillContext>k__BackingField", "skill_context_unresolved")
end

local function resolve_ability_context(human)
    return resolve_context(human, "get_AbilityContext", "get_AbilityContext()", "<AbilityContext>k__BackingField", "ability_context_unresolved")
end

local function resolve_skill_availability(skill_context)
    if skill_context == nil then
        return nil, "skill_availability_unresolved"
    end

    local direct = util.safe_direct_method(skill_context, "get_Availability")
    if direct ~= nil then
        return direct, "skill_context:get_Availability()"
    end

    local method = util.safe_method(skill_context, "get_Availability()")
        or util.safe_method(skill_context, "get_Availability")
        or util.safe_method(skill_context, "get_SkillAvailability()")
        or util.safe_method(skill_context, "get_SkillAvailability")
    if method ~= nil then
        return method, "skill_context:get_Availability"
    end

    local field = util.safe_field(skill_context, "<Availability>k__BackingField")
        or util.safe_field(skill_context, "Availability")
        or util.safe_field(skill_context, "<SkillAvailability>k__BackingField")
        or util.safe_field(skill_context, "SkillAvailability")
    if field ~= nil then
        return field, "skill_context.Availability"
    end

    return nil, "skill_availability_unresolved"
end

local function resolve_job_changer(human)
    return resolve_context(human, "get_JobChanger", "get_JobChanger()", "<JobChanger>k__BackingField", "job_changer_unresolved")
end

local function call_is_job_qualified(job_context, job_id)
    if job_context == nil then
        return nil
    end

    return first_non_nil(
        util.safe_direct_method(job_context, "isJobQualified", job_id),
        util.safe_method(job_context, "isJobQualified(System.Int32)", job_id),
        util.safe_method(job_context, "isJobQualified(app.Character.JobEnum)", job_id),
        util.safe_method(job_context, "isJobQualified", job_id)
    )
end

local function build_actor_progression_signature(actor_state)
    if actor_state == nil then
        return "nil"
    end

    return table.concat({
        tostring(actor_state.current_job or actor_state.raw_job),
        tostring(actor_state.qualified_job_bits),
        tostring(actor_state.viewed_new_job_bits),
        tostring(actor_state.changed_job_bits),
    }, "|")
end

local function build_actor_hybrid_bit_summary(actor_state)
    if actor_state == nil then
        return {}
    end

    local map = {}
    for _, key in ipairs(hybrid_jobs.keys) do
        local item = actor_state.hybrid_gate_status and actor_state.hybrid_gate_status[key] or nil
        map[key] = string.format(
            "q=%s v=%s c=%s direct=%s",
            tostring(item and item.qualified_bits and item.qualified_bits.bit_job_minus_one or nil),
            tostring(item and item.viewed_bits and item.viewed_bits.bit_job_minus_one or nil),
            tostring(item and item.changed_bits and item.changed_bits.bit_job_minus_one or nil),
            tostring(item and item.direct and item.direct.is_job_qualified or nil)
        )
    end
    return map
end

local function emit_actor_progression_change(runtime, actor_label, actor_state)
    local signature_key = string.format("last_%s_progression_bits_signature", tostring(actor_label))
    local last_signature = runtime[signature_key]
    local next_signature = build_actor_progression_signature(actor_state)
    if last_signature == next_signature then
        return
    end

    runtime[signature_key] = next_signature
    log.session_marker(runtime, "progression", "actor_progression_bits_changed", {
        actor = actor_label,
        current_job = actor_state and (actor_state.current_job or actor_state.raw_job) or nil,
        qualified_job_bits = actor_state and actor_state.qualified_job_bits or nil,
        viewed_new_job_bits = actor_state and actor_state.viewed_new_job_bits or nil,
        changed_job_bits = actor_state and actor_state.changed_job_bits or nil,
        hybrid_summary = build_actor_hybrid_bit_summary(actor_state),
        job_context_source = actor_state and actor_state.job_context_source or nil,
        job_changer_source = actor_state and actor_state.job_changer_source or nil,
    }, string.format(
        "actor=%s job=%s qualified=%s viewed=%s changed=%s",
        tostring(actor_label),
        tostring(actor_state and (actor_state.current_job or actor_state.raw_job) or nil),
        tostring(actor_state and actor_state.qualified_job_bits or nil),
        tostring(actor_state and actor_state.viewed_new_job_bits or nil),
        tostring(actor_state and actor_state.changed_job_bits or nil)
    ))
end

local function call_get_job_level(job_context, job_id)
    if job_context == nil then
        return nil
    end

    return first_non_nil(
        util.safe_direct_method(job_context, "getJobLevel", job_id),
        util.safe_method(job_context, "getJobLevel(System.Int32)", job_id),
        util.safe_method(job_context, "getJobLevel(app.Character.JobEnum)", job_id),
        util.safe_method(job_context, "getJobLevel", job_id)
    )
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

local function get_current_node(action_manager, layer_index)
    local fsm = util.safe_field(action_manager, "Fsm")
    if fsm == nil then
        return nil
    end

    local node_name = util.safe_method(fsm, "getCurrentNodeName(System.UInt32)", layer_index)
        or util.safe_method(fsm, "getCurrentNodeName", layer_index)
    if type(node_name) == "string" then
        return node_name:match("([^%.]+)$") or node_name
    end

    local as_string = node_name and util.safe_method(node_name, "ToString")
    if type(as_string) == "string" then
        return as_string:match("([^%.]+)$") or as_string
    end

    return nil
end

local function build_hybrid_gate_status(job_context, qualified_bits, viewed_bits, changed_bits)
    local data = {}

    for _, key in ipairs(hybrid_jobs.keys) do
        local job_id = hybrid_jobs.by_key[key] and hybrid_jobs.by_key[key].id or nil
        data[key] = {
            id = job_id,
            qualified_bits = {
                bit_job = util.has_bit(qualified_bits, job_id),
                bit_job_minus_one = util.has_bit(qualified_bits, job_id - 1),
            },
            viewed_bits = {
                bit_job = util.has_bit(viewed_bits, job_id),
                bit_job_minus_one = util.has_bit(viewed_bits, job_id - 1),
            },
            changed_bits = {
                bit_job = util.has_bit(changed_bits, job_id),
                bit_job_minus_one = util.has_bit(changed_bits, job_id - 1),
            },
            direct = {
                is_job_qualified = call_is_job_qualified(job_context, job_id),
                job_level = call_get_job_level(job_context, job_id),
            },
        }
    end

    return data
end

local function build_actor_state(label, runtime_character, fallback_human, source_label)
    if runtime_character == nil and fallback_human == nil then
        return nil
    end

    local human, human_source = resolve_human(runtime_character)
    if human == nil then
        human = fallback_human
        if human ~= nil then
            human_source = source_label or "fallback_human"
        end
    end

    local job_context, job_context_source = resolve_job_context(human)
    local skill_context, skill_context_source = resolve_skill_context(human)
    local ability_context, ability_context_source = resolve_ability_context(human)
    local skill_availability, skill_availability_source = resolve_skill_availability(skill_context)
    local job_changer, job_changer_source = resolve_job_changer(human)
    local action_manager = runtime_character and util.safe_method(runtime_character, "get_ActionManager") or nil
    local motion = runtime_character and util.safe_method(runtime_character, "get_Motion") or nil
    local object = runtime_character and util.safe_method(runtime_character, "get_GameObject") or nil
    local qualified_bits = job_context and util.safe_field(job_context, "QualifiedJobBits") or nil
    local viewed_bits = job_context and util.safe_field(job_context, "ViewedNewJobBits") or nil
    local changed_bits = job_context and util.safe_field(job_context, "ChangedJobBits") or nil
    local custom_skill_state = human and util.safe_field(human, "<CustomSkillState>k__BackingField") or nil

    return {
        label = label,
        runtime_character = runtime_character,
        human = human,
        human_source = human_source,
        object = object,
        name = object and util.safe_method(object, "get_Name") or nil,
        chara_id = runtime_character and util.safe_method(runtime_character, "get_CharaID") or nil,
        raw_job = runtime_character and util.safe_field(runtime_character, "Job") or nil,
        weapon_job = runtime_character and util.safe_field(runtime_character, "WeaponJob") or nil,
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
        motion = motion,
        full_node = get_current_node(action_manager, 0),
        upper_node = get_current_node(action_manager, 1),
        current_job = job_context and util.safe_field(job_context, "CurrentJob") or nil,
        qualified_job_bits = qualified_bits,
        viewed_new_job_bits = viewed_bits,
        changed_job_bits = changed_bits,
        qualified_job_map = build_bit_map(qualified_bits),
        viewed_job_map = build_bit_map(viewed_bits),
        changed_job_map = build_bit_map(changed_bits),
        job_diagnostic_table = build_job_diagnostic_table(job_context),
        hybrid_gate_status = build_hybrid_gate_status(job_context, qualified_bits, viewed_bits, changed_bits),
        job_context_fields = snapshot_fields(job_context),
        skill_context_fields = snapshot_fields(skill_context),
        ability_context_fields = snapshot_fields(ability_context),
        skill_availability_fields = snapshot_fields(skill_availability),
        custom_skill_state_fields = snapshot_fields(custom_skill_state),
    }
end

local function hybrid_entry_diff(player_entry, pawn_entry)
    return {
        player_is_job_qualified = player_entry and player_entry.direct and player_entry.direct.is_job_qualified or nil,
        pawn_is_job_qualified = pawn_entry and pawn_entry.direct and pawn_entry.direct.is_job_qualified or nil,
        player_job_level = player_entry and player_entry.direct and player_entry.direct.job_level or nil,
        pawn_job_level = pawn_entry and pawn_entry.direct and pawn_entry.direct.job_level or nil,
        qualified_match = (player_entry and player_entry.qualified_bits and player_entry.qualified_bits.bit_job_minus_one or false)
            == (pawn_entry and pawn_entry.qualified_bits and pawn_entry.qualified_bits.bit_job_minus_one or false),
        viewed_match = (player_entry and player_entry.viewed_bits and player_entry.viewed_bits.bit_job_minus_one or false)
            == (pawn_entry and pawn_entry.viewed_bits and pawn_entry.viewed_bits.bit_job_minus_one or false),
        changed_match = (player_entry and player_entry.changed_bits and player_entry.changed_bits.bit_job_minus_one or false)
            == (pawn_entry and pawn_entry.changed_bits and pawn_entry.changed_bits.bit_job_minus_one or false),
        player_qualified = player_entry and player_entry.qualified_bits and player_entry.qualified_bits.bit_job_minus_one or false,
        pawn_qualified = pawn_entry and pawn_entry.qualified_bits and pawn_entry.qualified_bits.bit_job_minus_one or false,
        player_viewed = player_entry and player_entry.viewed_bits and player_entry.viewed_bits.bit_job_minus_one or false,
        pawn_viewed = pawn_entry and pawn_entry.viewed_bits and pawn_entry.viewed_bits.bit_job_minus_one or false,
        player_changed = player_entry and player_entry.changed_bits and player_entry.changed_bits.bit_job_minus_one or false,
        pawn_changed = pawn_entry and pawn_entry.changed_bits and pawn_entry.changed_bits.bit_job_minus_one or false,
    }
end

local function build_alignment(player_state, main_pawn_state)
    if player_state == nil or main_pawn_state == nil then
        return nil
    end

    local hybrid = {}
    local qualified_match = true
    local viewed_match = true
    local changed_match = true

    for _, key in ipairs(hybrid_jobs.keys) do
        hybrid[key] = hybrid_entry_diff(
            player_state.hybrid_gate_status and player_state.hybrid_gate_status[key] or nil,
            main_pawn_state.hybrid_gate_status and main_pawn_state.hybrid_gate_status[key] or nil
        )
        qualified_match = qualified_match and hybrid[key].qualified_match
        viewed_match = viewed_match and hybrid[key].viewed_match
        changed_match = changed_match and hybrid[key].changed_match
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
        player_job = player_state.current_job or player_state.raw_job,
        main_pawn_job = main_pawn_state.current_job or main_pawn_state.raw_job,
        main_pawn_weapon_job = main_pawn_state.weapon_job,
        qualified_match = qualified_match,
        viewed_match = viewed_match,
        changed_match = changed_match,
        dominant_gap = dominant_gap,
        player_job_context = util.describe_obj(player_state.job_context),
        main_pawn_job_context = util.describe_obj(main_pawn_state.job_context),
        player_job_changer = util.describe_obj(player_state.job_changer),
        main_pawn_job_changer = util.describe_obj(main_pawn_state.job_changer),
        hybrid = hybrid,
    }
end

local function build_summary(player_state, main_pawn_state, alignment)
    return {
        player_ready = player_state ~= nil,
        main_pawn_ready = main_pawn_state ~= nil,
        player_current_job = player_state and (player_state.current_job or player_state.raw_job) or nil,
        main_pawn_current_job = main_pawn_state and (main_pawn_state.current_job or main_pawn_state.raw_job) or nil,
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

local function build_legacy_progression_gate(player_state)
    if player_state == nil then
        return nil
    end

    local legacy_hybrid_status = {}
    local direct_hybrid_status = {}
    for _, key in ipairs(hybrid_jobs.keys) do
        local item = player_state.hybrid_gate_status[key]
        legacy_hybrid_status[key] = {
            qualified = {
                bit_job_index = item.qualified_bits.bit_job,
                bit_job_minus_one = item.qualified_bits.bit_job_minus_one,
            },
            viewed = {
                bit_job_index = item.viewed_bits.bit_job,
                bit_job_minus_one = item.viewed_bits.bit_job_minus_one,
            },
            changed = {
                bit_job_index = item.changed_bits.bit_job,
                bit_job_minus_one = item.changed_bits.bit_job_minus_one,
            },
        }
        direct_hybrid_status[key] = item.direct
    end

    return {
        player = state.runtime.player,
        object = player_state.object,
        name = player_state.name,
        human = player_state.human,
        job_context = player_state.job_context,
        job_context_source = player_state.job_context_source,
        skill_context = player_state.skill_context,
        skill_context_source = player_state.skill_context_source,
        current_job = player_state.current_job,
        qualified_job_bits = player_state.qualified_job_bits,
        viewed_new_job_bits = player_state.viewed_new_job_bits,
        changed_job_bits = player_state.changed_job_bits,
        job_context_fields = player_state.job_context_fields,
        skill_context_fields = player_state.skill_context_fields,
        hybrid_gate_status = legacy_hybrid_status,
        direct_hybrid_status = direct_hybrid_status,
        qualified_job_map = player_state.qualified_job_map,
        viewed_job_map = player_state.viewed_job_map,
        changed_job_map = player_state.changed_job_map,
        job_diagnostic_table = player_state.job_diagnostic_table,
    }
end

function progression_state.update()
    local runtime = state.runtime
    local player_state = build_actor_state("player", runtime.player, nil, "runtime.player")
    local main_pawn_data = runtime.main_pawn_data
    local main_pawn_state = build_actor_state(
        "main_pawn",
        main_pawn_data and main_pawn_data.runtime_character or nil,
        main_pawn_data and main_pawn_data.human or nil,
        "runtime.main_pawn_data"
    )
    local alignment = build_alignment(player_state, main_pawn_state)

    local data = {
        player = player_state,
        main_pawn = main_pawn_state,
        alignment = alignment,
        summary = build_summary(player_state, main_pawn_state, alignment),
    }

    runtime.progression_state_data = data
    runtime.progression_gate_data = build_legacy_progression_gate(player_state)
    emit_actor_progression_change(runtime, "player", player_state)
    emit_actor_progression_change(runtime, "main_pawn", main_pawn_state)

    local summary_signature = table.concat({
        tostring(data.summary.player_current_job),
        tostring(data.summary.main_pawn_current_job),
        tostring(data.summary.qualified_match),
        tostring(data.summary.viewed_match),
        tostring(data.summary.changed_match),
        tostring(data.summary.dominant_gap),
    }, "|")

    if runtime.last_progression_state_signature ~= summary_signature then
        runtime.last_progression_state_signature = summary_signature
        log.session_marker(runtime, "progression", "player_main_pawn_progression_diff", {
            player_current_job = data.summary.player_current_job,
            main_pawn_current_job = data.summary.main_pawn_current_job,
            qualified_match = data.summary.qualified_match,
            viewed_match = data.summary.viewed_match,
            changed_match = data.summary.changed_match,
            dominant_gap = data.summary.dominant_gap,
            player_job_context_source = data.summary.player_job_context_source,
            main_pawn_job_context_source = data.summary.main_pawn_job_context_source,
            player_job_changer_source = data.summary.player_job_changer_source,
            main_pawn_job_changer_source = data.summary.main_pawn_job_changer_source,
        }, string.format(
            "player_job=%s main_pawn_job=%s gap=%s",
            tostring(data.summary.player_current_job),
            tostring(data.summary.main_pawn_current_job),
            tostring(data.summary.dominant_gap)
        ))
    end

    return data
end

return progression_state

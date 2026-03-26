local hybrid_jobs = require("PawnHybridVocationsAI/data/hybrid_jobs")
local vocation_skill_matrix = require("PawnHybridVocationsAI/data/vocation_skill_matrix")

local hybrid_combat_profiles = {}

local profiles = {}

local function default_output_tokens(job_id)
    return {
        string.format("/job%02d/", job_id),
        string.format("job%02d_", job_id),
    }
end

local function build_placeholder_profile(job)
    return {
        job_id = job.id,
        key = job.key,
        label = job.label,
        active = false,
        telemetry_only = true,
        output_tokens = default_output_tokens(job.id),
        phases = {},
        pending_reason = "profile_pending_research",
    }
end

local function append_phase(list, phase)
    if type(phase) == "table" then
        list[#list + 1] = phase
    end
end

local function clone_string_list(values)
    local result = {}
    for _, value in ipairs(values or {}) do
        if type(value) == "string" and value ~= "" then
            result[#result + 1] = value
        end
    end

    return result
end

local function collect_named_candidates(primary_value, extra_values)
    local values = {}
    local seen = {}

    local function push(value)
        if type(value) ~= "string" or value == "" or seen[value] then
            return
        end

        seen[value] = true
        values[#values + 1] = value
    end

    push(primary_value)
    for _, value in ipairs(extra_values or {}) do
        push(value)
    end

    return values
end

local function execution_contract(class, extra)
    local contract = {
        class = class,
        bridge_mode = "action_only",
        confidence = "pending",
    }

    if type(extra) == "table" then
        for key, value in pairs(extra) do
            contract[key] = value
        end
    end

    return contract
end

local function direct_safe_contract(extra)
    return execution_contract("direct_safe", extra)
end

local function carrier_required_contract(extra)
    return execution_contract("carrier_required", merge_into({
        bridge_mode = "carrier_then_action",
        confidence = "working_assumption",
    }, extra))
end

local function resolve_execution_contract_definition(runtime_phase, skill_entry)
    local source = type(runtime_phase and runtime_phase.execution_contract) == "table"
        and runtime_phase.execution_contract
        or type(skill_entry and skill_entry.execution_contract) == "table"
            and skill_entry.execution_contract
            or {}

    local action_candidates = clone_string_list(source.action_candidates)
    if #action_candidates == 0 then
        action_candidates = collect_named_candidates(runtime_phase.action_name, runtime_phase.action_candidates)
    end

    local carrier_candidates = clone_string_list(source.carrier_candidates)
    if #carrier_candidates == 0 then
        carrier_candidates = collect_named_candidates(runtime_phase.pack_path, runtime_phase.pack_candidates)
    end

    local probe_pack_candidates = clone_string_list(source.probe_pack_candidates)
    if #probe_pack_candidates == 0 then
        probe_pack_candidates = clone_string_list(runtime_phase.probe_pack_candidates)
    end

    local contract_class = tostring(source.class or "")
    if contract_class == "" then
        if runtime_phase.unsafe_direct_action == true then
            contract_class = "controller_stateful"
        elseif #carrier_candidates > 0 then
            contract_class = "carrier_required"
        elseif #action_candidates > 0 then
            contract_class = "direct_safe"
        else
            contract_class = "selector_owned"
        end
    end

    local bridge_mode = tostring(source.bridge_mode or "")
    if bridge_mode == "" then
        if runtime_phase.unsafe_direct_action == true then
            bridge_mode = "probe_only"
        elseif contract_class == "selector_owned" then
            bridge_mode = "selector_owned"
        elseif #carrier_candidates > 0 and #action_candidates > 0 then
            bridge_mode = "carrier_then_action"
        elseif #carrier_candidates > 0 then
            bridge_mode = "carrier_only"
        else
            bridge_mode = "action_only"
        end
    end

    return {
        class = contract_class,
        bridge_mode = bridge_mode,
        confidence = tostring(source.confidence or "legacy_inferred"),
        action_candidates = action_candidates,
        carrier_candidates = carrier_candidates,
        probe_pack_candidates = probe_pack_candidates,
        probe_required = source.probe_required == true or runtime_phase.unsafe_direct_action == true,
        supported_probe_modes = clone_string_list(source.supported_probe_modes),
        controller_snapshot_key = source.controller_snapshot_key,
        controller_state_fields = clone_string_list(source.controller_state_fields),
        note = source.note,
    }
end

local function apply_execution_contract(phase, contract)
    if type(phase) ~= "table" or type(contract) ~= "table" then
        return phase
    end

    phase.execution_contract = contract
    phase.execution_contract_class = contract.class
    phase.execution_bridge_mode = contract.bridge_mode
    phase.execution_confidence = contract.confidence

    if #contract.carrier_candidates > 0 then
        phase.pack_path = contract.carrier_candidates[1]
        phase.pack_candidates = contract.carrier_candidates
    end
    if #contract.action_candidates > 0 then
        phase.action_name = contract.action_candidates[1]
        phase.action_candidates = contract.action_candidates
    end
    if #contract.probe_pack_candidates > 0 then
        phase.probe_pack_candidates = contract.probe_pack_candidates
    end
    if contract.probe_required then
        phase.unsafe_direct_action = true
    end

    return phase
end

local function phase_with_contract(phase, contract)
    return apply_execution_contract(phase, contract)
end

local function build_custom_skill_phase(skill_entry)
    local runtime_phase = skill_entry and skill_entry.runtime_phase or nil
    if type(runtime_phase) ~= "table" then
        return nil
    end
    if runtime_phase.disabled == true then
        return nil
    end

    local phase = {
        key = tostring(runtime_phase.key or skill_entry.name or ("skill_" .. tostring(skill_entry.id or "nil"))),
        mode = "skill",
        selection_role = tostring(runtime_phase.selection_role or "skill"),
        min_distance = tonumber(runtime_phase.min_distance) or 0.0,
        max_distance = tonumber(runtime_phase.max_distance),
        min_job_level = tonumber(runtime_phase.min_job_level) or 0,
        priority = tonumber(runtime_phase.priority) or 0,
        required_skill_name = tostring(skill_entry.name or "nil"),
        required_skill_id = tonumber(skill_entry.id),
        requires_equipped_skill = runtime_phase.requires_equipped_skill ~= false,
        requires_enabled_skill = runtime_phase.requires_enabled_skill ~= false,
        block_if_unmapped = runtime_phase.block_if_unmapped == true,
        note = runtime_phase.note,
    }

    local contract = resolve_execution_contract_definition(runtime_phase, skill_entry)
    apply_execution_contract(phase, contract)

    if runtime_phase.action_layer ~= nil then
        phase.action_layer = runtime_phase.action_layer
    end
    if runtime_phase.action_priority ~= nil then
        phase.action_priority = runtime_phase.action_priority
    end
    if runtime_phase.cooldown_seconds ~= nil then
        phase.cooldown_seconds = runtime_phase.cooldown_seconds
    end

    return phase
end

local function build_job07_phases()
    local phases = {
        phase_with_contract({
            key = "core_bind_close",
            mode = "core",
            selection_role = "engage_basic",
            min_distance = 0.00,
            max_distance = 2.25,
            min_job_level = 0,
            priority = 20,
            note = "base close-range Job07 fallback",
        }, carrier_required_contract({
            carrier_candidates = {
                "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_MagicBindLeap.user",
            },
            action_candidates = { "Job07_MagicBindJustLeap" },
            confidence = "grounded_observed_pack_and_action",
        })),
        phase_with_contract({
            key = "core_short_attack_close",
            mode = "core",
            action_layer = 0,
            action_priority = 0,
            selection_role = "basic_attack",
            min_distance = 0.00,
            max_distance = 2.10,
            min_job_level = 0,
            priority = 19,
            note = "basic close-range direct action fallback for low-complexity Job07 pressure",
        }, direct_safe_contract({
            action_candidates = { "Job07_ShortRangeAttack" },
            confidence = "grounded_observed_action",
        })),
        phase_with_contract({
            key = "skill_spiral_close",
            mode = "core",
            selection_role = "core_advanced",
            min_distance = 0.00,
            max_distance = 2.75,
            min_job_level = 3,
            priority = 50,
            note = "advanced close-range core pressure; treated as non-custom until contrary CE evidence appears",
        }, carrier_required_contract({
            carrier_candidates = {
                "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_SpiralSlash.user",
            },
            action_candidates = { "Job07_SpiralSlash" },
            confidence = "grounded_observed_pack_and_action",
        })),
        phase_with_contract({
            key = "core_bind_mid",
            mode = "core",
            selection_role = "engage_basic",
            min_distance = 2.25,
            max_distance = 4.75,
            min_job_level = 0,
            priority = 18,
            note = "base mid-range pressure",
        }, carrier_required_contract({
            carrier_candidates = {
                "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_MagicBindLeap.user",
            },
            action_candidates = { "Job07_MagicBindJustLeap" },
            confidence = "grounded_observed_pack_and_action",
        })),
        phase_with_contract({
            key = "core_short_attack_mid",
            mode = "core",
            action_layer = 0,
            action_priority = 0,
            selection_role = "basic_attack",
            min_distance = 1.50,
            max_distance = 3.40,
            min_job_level = 0,
            priority = 17,
            note = "basic mid-range direct action fallback when higher-pressure phases do not stick",
        }, direct_safe_contract({
            action_candidates = { "Job07_ShortRangeAttack" },
            confidence = "grounded_observed_action",
        })),
        phase_with_contract({
            key = "skill_spiral_mid",
            mode = "core",
            selection_role = "core_advanced",
            min_distance = 1.75,
            max_distance = 4.25,
            min_job_level = 4,
            priority = 42,
            note = "advanced mid-range core pressure; treated as non-custom until contrary CE evidence appears",
        }, carrier_required_contract({
            carrier_candidates = {
                "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_SpiralSlash.user",
            },
            action_candidates = { "Job07_SpiralSlash" },
            confidence = "grounded_observed_pack_and_action",
        })),
        phase_with_contract({
            key = "core_gapclose_far",
            mode = "core",
            selection_role = "gapclose",
            min_distance = 4.25,
            max_distance = 7.50,
            min_job_level = 0,
            priority = 16,
            note = "base far gap-close fallback",
        }, carrier_required_contract({
            carrier_candidates = {
                "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_Run_Blade4.user",
            },
            confidence = "grounded_observed_pack",
        })),
    }

    local job07 = vocation_skill_matrix.get_job(7)
    for _, skill_entry in ipairs(job07 and job07.custom_skills or {}) do
        append_phase(phases, build_custom_skill_phase(skill_entry))
    end

    return phases
end

profiles[7] = {
    job_id = 7,
    key = "mystic_spearhand",
    label = "Mystic Spearhand",
    active = true,
    telemetry_only = false,
    output_tokens = {
        "/job07/",
        "job07_",
        "ch300_job07_",
    },
    phases = build_job07_phases(),
}

for _, job in hybrid_jobs.each() do
    if profiles[job.id] == nil then
        profiles[job.id] = build_placeholder_profile(job)
    end
end

function hybrid_combat_profiles.get_by_job_id(job_id)
    return profiles[tonumber(job_id)]
end

function hybrid_combat_profiles.each()
    return pairs(profiles)
end

return hybrid_combat_profiles

local hybrid_jobs = require("PawnHybridVocationsAI/data/hybrid_jobs")
local vocation_skill_matrix = require("PawnHybridVocationsAI/data/vocation_skill_matrix")
local execution_contracts = require("PawnHybridVocationsAI/core/execution_contracts")

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

local function phase_with_contract(phase, contract)
    return execution_contracts.apply_to_phase(phase, contract)
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
        synthetic_bucket = type(runtime_phase.synthetic_bucket) == "string"
            and runtime_phase.synthetic_bucket
            or nil,
        stability = type(runtime_phase.stability) == "string"
            and runtime_phase.stability
            or nil,
        min_distance = tonumber(runtime_phase.min_distance) or 0.0,
        max_distance = tonumber(runtime_phase.max_distance),
        min_job_level = tonumber(runtime_phase.min_job_level) or 0,
        priority = tonumber(runtime_phase.priority) or 0,
        required_skill_name = tostring(skill_entry.name or "nil"),
        required_skill_id = tonumber(skill_entry.id),
        requires_learned_skill = runtime_phase.requires_learned_skill ~= false,
        requires_equipped_skill = runtime_phase.requires_equipped_skill ~= false,
        requires_enabled_skill = runtime_phase.requires_enabled_skill ~= false,
        block_if_unmapped = runtime_phase.block_if_unmapped == true,
        note = runtime_phase.note,
    }

    local contract = execution_contracts.resolve(runtime_phase, skill_entry)
    execution_contracts.apply_to_phase(phase, contract)

    if runtime_phase.action_layer ~= nil then
        phase.action_layer = runtime_phase.action_layer
    end
    if runtime_phase.action_priority ~= nil then
        phase.action_priority = runtime_phase.action_priority
    end
    if runtime_phase.cooldown_seconds ~= nil then
        phase.cooldown_seconds = runtime_phase.cooldown_seconds
    end
    if runtime_phase.synthetic_initiator_priority ~= nil then
        phase.synthetic_initiator_priority = tonumber(runtime_phase.synthetic_initiator_priority)
    end

    return phase
end

local function build_job07_phases()
    local phases = {
        phase_with_contract({
            key = "core_bind_close",
            mode = "core",
            selection_role = "engage_basic",
            synthetic_bucket = "opener",
            min_distance = 0.00,
            max_distance = 2.25,
            min_job_level = 0,
            priority = 20,
            synthetic_initiator_priority = 145,
            note = "base close-range Job07 fallback",
        }, execution_contracts.carrier_required({
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
            synthetic_bucket = "sustain",
            min_distance = 0.00,
            max_distance = 2.10,
            min_job_level = 0,
            priority = 19,
            synthetic_initiator_priority = 150,
            note = "basic close-range direct action fallback for low-complexity Job07 pressure",
        }, execution_contracts.direct_safe({
            action_candidates = { "Job07_ShortRangeAttack" },
            confidence = "grounded_observed_action",
        })),
        phase_with_contract({
            key = "skill_spiral_close",
            mode = "core",
            selection_role = "core_advanced",
            synthetic_bucket = "burst",
            min_distance = 0.00,
            max_distance = 2.75,
            min_job_level = 3,
            priority = 50,
            note = "advanced close-range core pressure; treated as non-custom until contrary CE evidence appears",
        }, execution_contracts.carrier_required({
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
            synthetic_bucket = "opener",
            min_distance = 2.25,
            max_distance = 4.75,
            min_job_level = 0,
            priority = 18,
            synthetic_initiator_priority = 160,
            note = "base mid-range pressure",
        }, execution_contracts.carrier_required({
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
            synthetic_bucket = "sustain",
            min_distance = 1.50,
            max_distance = 3.40,
            min_job_level = 0,
            priority = 17,
            synthetic_initiator_priority = 135,
            note = "basic mid-range direct action fallback when higher-pressure phases do not stick",
        }, execution_contracts.direct_safe({
            action_candidates = { "Job07_ShortRangeAttack" },
            confidence = "grounded_observed_action",
        })),
        phase_with_contract({
            key = "skill_spiral_mid",
            mode = "core",
            selection_role = "core_advanced",
            synthetic_bucket = "burst",
            min_distance = 1.75,
            max_distance = 4.25,
            min_job_level = 4,
            priority = 42,
            note = "advanced mid-range core pressure; treated as non-custom until contrary CE evidence appears",
        }, execution_contracts.carrier_required({
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
            synthetic_bucket = "opener",
            min_distance = 4.25,
            max_distance = 7.50,
            min_job_level = 0,
            priority = 16,
            synthetic_initiator_priority = 170,
            note = "base far gap-close fallback",
            }, execution_contracts.carrier_required({
            carrier_candidates = {
                "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_Run_Blade4.user",
            },
            confidence = "grounded_observed_pack",
        })),
        phase_with_contract({
            key = "core_run_attack_far",
            mode = "core",
            selection_role = "gapclose",
            synthetic_bucket = "opener",
            min_distance = 3.75,
            max_distance = 6.75,
            min_job_level = 0,
            priority = 15,
            synthetic_initiator_priority = 165,
            note = "Sigurd-observed far engage follow-through; pack-only until a stable action mapping is grounded",
        }, execution_contracts.carrier_required({
            carrier_candidates = {
                "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_RunAttackNormal.user",
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

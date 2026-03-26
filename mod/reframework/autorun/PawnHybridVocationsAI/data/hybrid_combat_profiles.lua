local hybrid_jobs = require("PawnHybridVocationsAI/data/hybrid_jobs")

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
    phases = {
        {
            key = "core_bind_close",
            mode = "core",
            pack_path = "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_MagicBindLeap.user",
            min_distance = 0.00,
            max_distance = 2.25,
            min_job_level = 1,
            priority = 20,
            note = "base close-range Job07 fallback",
        },
        {
            key = "skill_spiral_close",
            mode = "core",
            pack_path = "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_SpiralSlash.user",
            min_distance = 0.00,
            max_distance = 2.75,
            min_job_level = 3,
            priority = 50,
            note = "advanced close-range core pressure; treated as non-custom until contrary CE evidence appears",
        },
        {
            key = "core_bind_mid",
            mode = "core",
            pack_path = "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_MagicBindLeap.user",
            min_distance = 2.25,
            max_distance = 4.75,
            min_job_level = 1,
            priority = 18,
            note = "base mid-range pressure",
        },
        {
            key = "skill_spiral_mid",
            mode = "core",
            pack_path = "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_SpiralSlash.user",
            min_distance = 1.75,
            max_distance = 4.25,
            min_job_level = 4,
            priority = 42,
            note = "advanced mid-range core pressure; treated as non-custom until contrary CE evidence appears",
        },
        {
            key = "core_gapclose_far",
            mode = "core",
            pack_path = "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_Run_Blade4.user",
            min_distance = 4.25,
            max_distance = 7.50,
            min_job_level = 1,
            priority = 16,
            note = "base far gap-close fallback",
        },
        {
            key = "skill_skydive_far",
            mode = "skill",
            pack_path = "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_SkyDive.user",
            min_distance = 4.75,
            max_distance = 7.50,
            min_job_level = 6,
            priority = 48,
            required_skill_name = "Job07_SkyDive",
            required_skill_id = 76,
            requires_equipped_skill = true,
            requires_enabled_skill = true,
            block_if_unmapped = false,
            note = "advanced far-range dive gated by confirmed HumanCustomSkillID 76",
        },
    },
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

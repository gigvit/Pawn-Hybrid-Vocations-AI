local common = require("PawnHybridVocationsAI/data/job_graph_common")

return common.graph({
    job_id = 10,
    key = "warfarer",
    label = "Warfarer",
    action_prefix = "Job10",
    native_output_override_tokens = {
        "job10_00",
        "job10",
    },
    moves = {
        common.core({
            key = "job10_weapon_action",
            family = "job10_weapon",
            label = "Current Weapon Action",
            action = "Job10_00",
            role = "weapon_skill",
            bucket = "sustain",
            min_distance = 0.00,
            max_distance = 12.00,
            priority = 120,
            cooldown = 1.10,
            hold_seconds = 0.65,
            damage_kind = "warfarer_weapon",
        }),
        common.custom({
            key = "job10_rearmament",
            family = "job10_rearmament",
            label = "Rearmament",
            skill_id = 100,
            action = "Job10_00",
            role = "weapon_swap_skill",
            bucket = "support",
            min_distance = 0.00,
            max_distance = 12.00,
            priority = 92,
            cooldown = 3.50,
            hold_seconds = 0.75,
            damage_kind = "utility_weapon_swap",
            requires_target_match = false,
        }),
    },
})

local job07_moves = {}

local function merge_into(target, extra)
    if type(extra) ~= "table" then
        return target
    end

    for key, value in pairs(extra) do
        target[key] = value
    end

    return target
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

local function clone_sequence(sequence)
    local result = {}
    for _, step in ipairs(sequence or {}) do
        result[#result + 1] = step
    end
    return result
end

local function bridge_step(extra)
    return merge_into({
        kind = "bridge",
    }, extra)
end

local function wait_output_step(tokens, timeout_seconds, extra)
    return merge_into({
        kind = "wait_output",
        tokens = clone_string_list(tokens),
        timeout_seconds = timeout_seconds,
        allow_continue_on_timeout = true,
    }, extra)
end

local function hold_target_step(duration_seconds, max_distance, extra)
    return merge_into({
        kind = "hold_target",
        duration_seconds = duration_seconds,
        max_distance = max_distance,
        reissue_entry = true,
    }, extra)
end

local function wait_damage_step(duration_seconds, max_distance, extra)
    return merge_into({
        kind = "wait_damage",
        duration_seconds = duration_seconds,
        max_distance = max_distance,
        abort_on_out_of_range = false,
        complete_on_damage = false,
    }, extra)
end

local function end_step(extra)
    return merge_into({
        kind = "end",
    }, extra)
end

local function make_move(definition)
    local move = merge_into({
        key = "job07_move",
        family = "job07_misc",
        label = "Job07 Move",
        cooldown_seconds = 1.10,
        failure_cooldown_seconds = 0.55,
        stability = "stable",
        output_tokens = {},
        availability = {
            kind = "core",
        },
        damage = {
            kind = "none",
            assist = false,
            requires_target_match = true,
        },
        selection = {},
        execution = {
            interrupt_policy = "guarded_owned",
        },
        entry = {},
        sequence = {},
    }, definition)

    move.output_tokens = clone_string_list(move.output_tokens)
    move.sequence = clone_sequence(move.sequence)
    return move
end

local ordered = {
    make_move({
        key = "job07_magic_bind_bolt",
        family = "job07_bind",
        label = "Magic Bind Bolt",
        cooldown_seconds = 10.50,
        failure_cooldown_seconds = 1.10,
        brain = {
            lockout_key = "job07_magic_bind_bolt_reopen",
            lockout_seconds = 10.50,
        },
        output_tokens = {
            "Job07_MagicBindComplete",
            "Job07_MagicBind",
            "MagicBindComplete",
        },
        selection = {
            role = "ranged_control",
            bucket = "opener",
            min_distance = 2.50,
            max_distance = 8.50,
            priority = 78,
            min_job_level = 0,
            forbidden_chain_phase = {
                "bolt_released",
                "bolt_hit",
                "bind_confirmed",
            },
        },
        damage = {
            kind = "control_shell",
            assist = false,
            requires_target_match = true,
        },
        entry = {
            action_name = "Job07_MagicBindComplete",
            action_layer = 0,
            action_priority = 0,
        },
        sequence = {
            bridge_step(),
            wait_output_step({
                "Job07_MagicBindComplete",
                "Job07_MagicBind",
                "MagicBindComplete",
            }, 0.30, {
                allow_continue_on_timeout = false,
            }),
            hold_target_step(0.45, 9.00, {
                reissue_entry = false,
                expected_output_tokens = {
                    "Job07_MagicBindComplete",
                    "Job07_MagicBind",
                    "MagicBindComplete",
                },
            }),
            end_step(),
        },
    }),
    make_move({
        key = "job07_magic_bind_just_explosion",
        family = "job07_bind",
        label = "Magic Bind Just Explosion",
        cooldown_seconds = 0.35,
        failure_cooldown_seconds = 0.25,
        output_tokens = {
            "Job07_MagicBindJustExplosion",
            "MagicBindJustExplosion",
            "JustExplosion",
        },
        selection = {
            role = "ranged_control_followup",
            bucket = "follow_through",
            min_distance = 0.75,
            max_distance = 9.00,
            priority = 220,
            min_job_level = 0,
            required_chain_phase = {
                "bolt_hit",
            },
            required_chain_target = true,
            required_chain_min_age_seconds = 0.22,
        },
        damage = {
            kind = "control_followup",
            assist = false,
            requires_target_match = true,
        },
        entry = {
            action_name = "Job07_MagicBindJustExplosion",
            action_layer = 0,
            action_priority = 0,
        },
        sequence = {
            bridge_step(),
            wait_output_step({
                "Job07_MagicBindJustExplosion",
                "MagicBindJustExplosion",
                "JustExplosion",
            }, 0.22, {
                allow_continue_on_timeout = false,
            }),
            hold_target_step(0.26, 9.00, {
                reissue_entry = false,
                expected_output_tokens = {
                    "Job07_MagicBindJustExplosion",
                    "MagicBindJustExplosion",
                    "JustExplosion",
                },
            }),
            end_step(),
        },
        chain = {
            grant_on_completed = "bind_confirmed",
            grant_duration_seconds = 1.20,
        },
    }),
    make_move({
        key = "job07_magic_bind_leap",
        family = "job07_bind",
        label = "Magic Bind Just Leap",
        cooldown_seconds = 2.05,
        failure_cooldown_seconds = 0.55,
        output_tokens = {
            "Job07_MagicBindJustLeap",
            "Job07_JustLeap",
            "MagicBindJustLeap",
            "JustLeap",
        },
        selection = {
            role = "gapclose_followup",
            bucket = "follow_through",
            min_distance = 1.35,
            max_distance = 8.50,
            priority = 218,
            min_job_level = 0,
            required_chain_phase = {
                "bind_confirmed",
            },
            required_chain_target = true,
            required_chain_min_age_seconds = 0.12,
        },
        damage = {
            kind = "mobility_followup",
            assist = false,
            requires_target_match = true,
        },
        entry = {
            pack_path = "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_MagicBindLeap.user",
            action_name = "Job07_MagicBindJustLeap",
            action_layer = 0,
            action_priority = 0,
        },
        sequence = {
            bridge_step(),
            wait_output_step({ "Job07_MagicBindJustLeap", "Job07_JustLeap", "MagicBindJustLeap", "JustLeap" }, 0.30, {
                allow_continue_on_timeout = false,
            }),
            hold_target_step(0.75, 9.00, {
                reissue_entry = false,
                expected_output_tokens = { "Job07_MagicBindJustLeap", "Job07_JustLeap", "MagicBindJustLeap", "JustLeap" },
            }),
            end_step(),
        },
        chain = {
            clear_on_completed = true,
        },
    }),
    make_move({
        key = "job07_short_attack",
        family = "job07_short_attack",
        label = "Short Range Attack",
        cooldown_seconds = 0.92,
        output_tokens = {
            "Job07_ShortRangeAttack",
            "Job07_NormalAttack",
            "ShortRangeAttack",
            "NormalAttack",
        },
        selection = {
            role = "basic_attack",
            bucket = "sustain",
            min_distance = 0.00,
            max_distance = 2.05,
            priority = 150,
            min_job_level = 0,
        },
        damage = {
            kind = "melee_core",
            assist = true,
            minimum_damage = 64.0,
            direct_fallback = true,
            direct_fallback_damage = 64.0,
            direct_fallback_max_distance = 3.20,
            wrong_target_cooldown_seconds = 1.20,
            requires_target_match = true,
        },
        entry = {
            action_name = "Job07_NormalAttack",
            action_layer = 0,
            action_priority = 0,
        },
        sequence = {
            bridge_step(),
            wait_output_step({ "Job07_ShortRangeAttack", "Job07_NormalAttack", "ShortRangeAttack", "NormalAttack" }, 0.28),
            hold_target_step(0.58, 3.05, {
                abort_on_out_of_range = false,
                reissue_entry = false,
                expected_output_tokens = { "Job07_ShortRangeAttack", "Job07_NormalAttack", "ShortRangeAttack", "NormalAttack" },
            }),
            wait_damage_step(0.62, 3.20),
            end_step(),
        },
    }),
    make_move({
        key = "job07_heavy_attack",
        family = "job07_heavy_attack",
        label = "Short Range Heavy Attack",
        cooldown_seconds = 1.35,
        output_tokens = {
            "Job07_ShortRangeHeavyAttack",
            "Job07_HeavyAttack",
            "ShortRangeHeavyAttack",
            "HeavyAttack",
        },
        selection = {
            role = "core_advanced",
            bucket = "burst",
            min_distance = 0.00,
            max_distance = 2.65,
            priority = 132,
            min_job_level = 0,
        },
        damage = {
            kind = "melee_core",
            assist = true,
            minimum_damage = 92.0,
            direct_fallback = true,
            direct_fallback_damage = 92.0,
            direct_fallback_max_distance = 3.35,
            wrong_target_cooldown_seconds = 1.45,
            requires_target_match = true,
        },
        entry = {
            action_name = "Job07_HeavyAttack",
            action_layer = 0,
            action_priority = 0,
        },
        sequence = {
            bridge_step(),
            wait_output_step({ "Job07_ShortRangeHeavyAttack", "Job07_HeavyAttack", "ShortRangeHeavyAttack", "HeavyAttack" }, 0.30),
            hold_target_step(0.74, 3.20, {
                abort_on_out_of_range = false,
                reissue_entry = false,
                expected_output_tokens = { "Job07_ShortRangeHeavyAttack", "Job07_HeavyAttack", "ShortRangeHeavyAttack", "HeavyAttack" },
            }),
            wait_damage_step(0.76, 3.35),
            end_step(),
        },
    }),
    make_move({
        key = "job07_spiral_slash",
        family = "job07_spiral",
        label = "Spiral Slash",
        cooldown_seconds = 2.80,
        output_tokens = {
            "Job07_SpiralSlash",
            "SpiralSlash",
        },
        selection = {
            role = "core_advanced",
            bucket = "burst",
            min_distance = 0.00,
            max_distance = 2.60,
            priority = 126,
            min_job_level = 3,
            allow_unresolved_job_level = true,
        },
        damage = {
            kind = "melee_core",
            assist = true,
            minimum_damage = 110.0,
            direct_fallback = true,
            direct_fallback_damage = 110.0,
            direct_fallback_max_distance = 3.50,
            wrong_target_cooldown_seconds = 1.70,
            requires_target_match = true,
        },
        entry = {
            pack_path = "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_SpiralSlash.user",
            action_name = "Job07_SpiralSlash",
            action_layer = 0,
            action_priority = 0,
        },
        sequence = {
            bridge_step(),
            wait_output_step({ "Job07_SpiralSlash", "SpiralSlash" }, 0.35),
            hold_target_step(1.25, 3.25, {
                abort_on_out_of_range = false,
                reissue_entry = false,
                expected_output_tokens = { "Job07_SpiralSlash", "SpiralSlash" },
            }),
            wait_damage_step(0.80, 3.50),
            end_step(),
        },
    }),
    make_move({
        key = "job07_gapclose_run_blade",
        family = "job07_gapclose",
        label = "Run Blade Gapclose",
        cooldown_seconds = 1.25,
        output_tokens = {
            "Run_Blade4",
            "job07",
        },
        selection = {
            role = "gapclose",
            bucket = "opener",
            min_distance = 3.25,
            max_distance = 35.00,
            priority = 122,
            min_job_level = 0,
        },
        damage = {
            kind = "gapclose_core",
            assist = false,
            requires_target_match = true,
        },
        entry = {
            pack_path = "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_Run_Blade4.user",
        },
        sequence = {
            bridge_step(),
            wait_output_step({ "Run_Blade4", "job07" }, 0.35),
            hold_target_step(0.60, 35.50, {
                expected_output_tokens = { "Run_Blade4", "job07" },
            }),
            end_step(),
        },
    }),
    make_move({
        key = "job07_gapclose_run_attack",
        family = "job07_gapclose",
        label = "Run Attack Gapclose",
        cooldown_seconds = 1.15,
        output_tokens = {
            "RunAttackNormal",
            "job07",
        },
        selection = {
            role = "gapclose",
            bucket = "opener",
            min_distance = 3.00,
            max_distance = 24.00,
            priority = 118,
            min_job_level = 0,
        },
        damage = {
            kind = "gapclose_core",
            assist = false,
            requires_target_match = true,
        },
        entry = {
            pack_path = "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_RunAttackNormal.user",
        },
        sequence = {
            bridge_step(),
            wait_output_step({ "RunAttackNormal", "job07" }, 0.35),
            hold_target_step(0.52, 24.50, {
                expected_output_tokens = { "RunAttackNormal", "job07" },
            }),
            end_step(),
        },
    }),
    make_move({
        key = "job07_dragon_stinger",
        family = "job07_dragon_stinger",
        label = "Dragon Stinger",
        cooldown_seconds = 2.20,
        failure_cooldown_seconds = 1.20,
        stability = "crash_prone",
        output_tokens = {
            "Job07_DragonStinger",
            "DragonStinger",
        },
        selection = {
            role = "gapclose_skill",
            bucket = "opener",
            min_distance = 2.35,
            max_distance = 7.50,
            priority = 188,
            min_job_level = 0,
            required_skill_id = 73,
        },
        availability = {
            kind = "custom_skill",
            skill_id = 73,
        },
        damage = {
            kind = "custom_melee",
            assist = false,
            requires_target_match = true,
        },
        entry = {
            pack_path = "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_DragonStinger.user",
            action_name = "Job07_DragonStinger",
            action_layer = 0,
            action_priority = 0,
        },
        sequence = {
            bridge_step(),
            wait_output_step({ "Job07_DragonStinger", "DragonStinger" }, 0.30),
            hold_target_step(0.45, 8.00, {
                reissue_entry = false,
                expected_output_tokens = { "Job07_DragonStinger", "DragonStinger" },
            }),
            end_step(),
        },
    }),
    make_move({
        key = "job07_energy_drain",
        family = "job07_energy_drain",
        label = "Energy Drain",
        cooldown_seconds = 1.85,
        output_tokens = {
            "Job07_EnergyDrain",
            "EnergyDrain",
        },
        selection = {
            role = "melee_skill",
            bucket = "sustain",
            min_distance = 0.00,
            max_distance = 2.85,
            priority = 168,
            min_job_level = 0,
            required_skill_id = 72,
        },
        availability = {
            kind = "custom_skill",
            skill_id = 72,
        },
        damage = {
            kind = "custom_melee",
            assist = false,
            requires_target_match = true,
        },
        entry = {
            action_name = "Job07_EnergyDrain",
            action_layer = 0,
            action_priority = 0,
        },
        sequence = {
            bridge_step(),
            wait_output_step({ "Job07_EnergyDrain", "EnergyDrain" }, 0.25),
            hold_target_step(0.55, 2.95, {
                expected_output_tokens = { "Job07_EnergyDrain", "EnergyDrain" },
            }),
            end_step(),
        },
    }),
    make_move({
        key = "job07_quick_shield",
        family = "job07_quick_shield",
        label = "Quick Shield",
        cooldown_seconds = 4.50,
        failure_cooldown_seconds = 1.20,
        output_tokens = {
            "Job07_QuickShield",
            "QuickShield",
        },
        selection = {
            role = "defense_skill",
            bucket = "defense",
            min_distance = 1.25,
            max_distance = 4.75,
            priority = 104,
            min_job_level = 0,
            required_skill_id = 74,
        },
        availability = {
            kind = "custom_skill",
            skill_id = 74,
        },
        damage = {
            kind = "utility_defense",
            assist = false,
            requires_target_match = false,
        },
        entry = {
            action_name = "Job07_QuickShield",
            action_layer = 0,
            action_priority = 0,
        },
        sequence = {
            bridge_step(),
            wait_output_step({ "Job07_QuickShield", "QuickShield" }, 0.30),
            hold_target_step(0.55, 5.25, {
                reissue_entry = false,
                expected_output_tokens = { "Job07_QuickShield", "QuickShield" },
            }),
            end_step(),
        },
    }),
    make_move({
        key = "job07_two_seconds",
        family = "job07_two_seconds",
        label = "Two Seconds",
        cooldown_seconds = 4.80,
        failure_cooldown_seconds = 1.25,
        output_tokens = {
            "Job07_TwoSeconds",
            "TwoSeconds",
        },
        selection = {
            role = "defense_skill",
            bucket = "defense",
            min_distance = 0.00,
            max_distance = 6.50,
            priority = 100,
            min_job_level = 0,
            required_skill_id = 78,
        },
        availability = {
            kind = "custom_skill",
            skill_id = 78,
        },
        damage = {
            kind = "utility_counter",
            assist = false,
            requires_target_match = false,
        },
        entry = {
            action_name = "Job07_TwoSeconds",
            action_layer = 0,
            action_priority = 0,
        },
        sequence = {
            bridge_step(),
            wait_output_step({ "Job07_TwoSeconds", "TwoSeconds" }, 0.30),
            hold_target_step(0.55, 6.75, {
                reissue_entry = false,
                expected_output_tokens = { "Job07_TwoSeconds", "TwoSeconds" },
            }),
            end_step(),
        },
    }),
    make_move({
        key = "job07_dance_of_death",
        family = "job07_dance_of_death",
        label = "Dance Of Death",
        cooldown_seconds = 2.15,
        output_tokens = {
            "Job07_DanceOfDeath",
            "DanceOfDeath",
        },
        selection = {
            role = "melee_skill",
            bucket = "burst",
            min_distance = 0.00,
            max_distance = 2.65,
            priority = 162,
            min_job_level = 0,
            required_skill_id = 79,
        },
        availability = {
            kind = "custom_skill",
            skill_id = 79,
        },
        damage = {
            kind = "custom_melee",
            assist = false,
            requires_target_match = true,
        },
        entry = {
            action_name = "Job07_DanceOfDeath",
            action_layer = 0,
            action_priority = 0,
        },
        sequence = {
            bridge_step(),
            wait_output_step({ "Job07_DanceOfDeath", "DanceOfDeath" }, 0.25),
            hold_target_step(0.55, 3.00, {
                expected_output_tokens = { "Job07_DanceOfDeath", "DanceOfDeath" },
            }),
            end_step(),
        },
    }),
    make_move({
        key = "job07_blade_shoot",
        family = "job07_blade_shoot",
        label = "Blade Shoot",
        cooldown_seconds = 1.80,
        output_tokens = {
            "Job07_BladeShoot",
            "Job07_Blade",
            "BladeShoot",
        },
        selection = {
            role = "ranged_skill",
            bucket = "ranged",
            min_distance = 3.25,
            max_distance = 8.25,
            priority = 146,
            min_job_level = 0,
            required_skill_id = 75,
        },
        availability = {
            kind = "custom_skill",
            skill_id = 75,
        },
        damage = {
            kind = "custom_ranged",
            assist = false,
            requires_target_match = true,
        },
        entry = {
            action_name = "Job07_BladeShoot",
            action_layer = 0,
            action_priority = 0,
        },
        sequence = {
            bridge_step(),
            wait_output_step({ "Job07_BladeShoot", "Job07_Blade", "BladeShoot" }, 0.30),
            hold_target_step(0.40, 8.50, {
                expected_output_tokens = { "Job07_BladeShoot", "Job07_Blade", "BladeShoot" },
            }),
            end_step(),
        },
    }),
    make_move({
        key = "job07_psycho_shoot",
        family = "job07_psycho_shoot",
        label = "Psycho Shoot",
        cooldown_seconds = 1.80,
        output_tokens = {
            "Job07_PsychoShoot",
            "PsychoShoot",
        },
        selection = {
            role = "ranged_skill",
            bucket = "ranged",
            min_distance = 4.75,
            max_distance = 9.50,
            priority = 140,
            min_job_level = 0,
            required_skill_id = 70,
        },
        availability = {
            kind = "custom_skill",
            skill_id = 70,
        },
        damage = {
            kind = "custom_ranged",
            assist = false,
            requires_target_match = true,
        },
        entry = {
            action_name = "Job07_PsychoShoot",
            action_layer = 0,
            action_priority = 0,
        },
        sequence = {
            bridge_step(),
            wait_output_step({ "Job07_PsychoShoot", "PsychoShoot" }, 0.30),
            hold_target_step(0.35, 9.75, {
                expected_output_tokens = { "Job07_PsychoShoot", "PsychoShoot" },
            }),
            end_step(),
        },
    }),
    make_move({
        key = "job07_far_throw",
        family = "job07_far_throw",
        label = "Far Throw",
        cooldown_seconds = 1.80,
        output_tokens = {
            "Job07_FarThrow",
            "FarThrow",
        },
        selection = {
            role = "ranged_skill",
            bucket = "ranged",
            min_distance = 5.00,
            max_distance = 9.50,
            priority = 138,
            min_job_level = 0,
            required_skill_id = 71,
        },
        availability = {
            kind = "custom_skill",
            skill_id = 71,
        },
        damage = {
            kind = "custom_ranged",
            assist = false,
            requires_target_match = true,
        },
        entry = {
            action_name = "Job07_FarThrow",
            action_layer = 0,
            action_priority = 0,
        },
        sequence = {
            bridge_step(),
            wait_output_step({ "Job07_FarThrow", "FarThrow" }, 0.30),
            hold_target_step(0.35, 9.75, {
                expected_output_tokens = { "Job07_FarThrow", "FarThrow" },
            }),
            end_step(),
        },
    }),
    make_move({
        key = "job07_skydive",
        family = "job07_skydive",
        label = "Sky Dive",
        cooldown_seconds = 2.10,
        output_tokens = {
            "Job07_SkyDive",
            "SkyDive",
        },
        selection = {
            role = "gapclose_skill",
            bucket = "opener",
            min_distance = 4.75,
            max_distance = 7.50,
            priority = 152,
            min_job_level = 0,
            required_skill_id = 76,
        },
        availability = {
            kind = "custom_skill",
            skill_id = 76,
        },
        damage = {
            kind = "custom_gapclose",
            assist = false,
            requires_target_match = true,
        },
        entry = {
            action_name = "Job07_SkyDive",
            action_layer = 0,
            action_priority = 0,
        },
        sequence = {
            bridge_step(),
            wait_output_step({ "Job07_SkyDive", "SkyDive" }, 0.30),
            hold_target_step(0.55, 6.50, {
                expected_output_tokens = { "Job07_SkyDive", "SkyDive" },
            }),
            end_step(),
        },
    }),
    make_move({
        key = "job07_gungnir",
        family = "job07_gungnir",
        label = "Gungnir",
        cooldown_seconds = 2.00,
        output_tokens = {
            "Job07_Gungnir",
            "Gungnir",
        },
        selection = {
            role = "ranged_skill",
            bucket = "ranged",
            min_distance = 4.50,
            max_distance = 9.00,
            priority = 144,
            min_job_level = 0,
            required_skill_id = 77,
        },
        availability = {
            kind = "custom_skill",
            skill_id = 77,
        },
        damage = {
            kind = "custom_ranged",
            assist = false,
            requires_target_match = true,
        },
        entry = {
            action_name = "Job07_Gungnir",
            action_layer = 0,
            action_priority = 0,
        },
        sequence = {
            bridge_step(),
            wait_output_step({ "Job07_Gungnir", "Gungnir" }, 0.30),
            hold_target_step(0.45, 9.25, {
                expected_output_tokens = { "Job07_Gungnir", "Gungnir" },
            }),
            end_step(),
        },
    }),
}

local by_key = {}
for _, move in ipairs(ordered) do
    by_key[move.key] = move
end

job07_moves.ordered = ordered
job07_moves.by_key = by_key
job07_moves.job_id = 7
job07_moves.key = "mystic_spearhand"
job07_moves.label = "Mystic Spearhand"
job07_moves.action_prefix = "Job07"
job07_moves.native_output_override_tokens = {
    "job07_shortrangeattack",
    "job07_shortrangeheavyattack",
    "job07_longrangeheavyattack",
    "runattacknormal",
    "run_blade4",
}

function job07_moves.each()
    return ipairs(ordered)
end

function job07_moves.get(key)
    return by_key[tostring(key or "")]
end

return job07_moves

local config = {
    mod_name = "Pawn Hybrid Vocations AI",
    version = "0.9.0-ce-first-cleanup",
    debug = {
        log_level = "INFO",
        file_logging_enabled = true,
        file_log_directory = "PawnHybridVocationsAI/logs",
        file_log_prefix = "PawnHybridVocationsAI.session",
        max_file_logs = 20,
    },
    discovery = {
        refresh_interval_seconds = 2.0,
    },
    runtime = {
        progression_refresh_interval_seconds = 0.25,
        hybrid_unlock_refresh_interval_seconds = 0.25,
        hybrid_combat_fix_refresh_interval_seconds = 0.10,
    },
    hybrid_unlock = {
        target_job = 7,
        auto_mirror_player_hybrid_bits = true,
        enable_guild_job_info_pawn_override = true,
    },
    hybrid_combat_fix = {
        enabled = true,
        cooldown_seconds = 2.5,
        request_skip_think = true,
        enforce_skill_loadout_gate = true,
        allow_unmapped_skill_phases = true,
        phase_blocked_log_interval_seconds = 5.0,
        observe_only_log_interval_seconds = 6.0,
    },
}

return config

local config = {
    mod_name = "Pawn Hybrid Vocations AI",
    version = "0.9.1-runtime-research-externalized",
    debug = {
        log_level = "INFO",
        file_logging_enabled = true,
        file_log_directory = "PawnHybridVocationsAI/logs",
        file_log_prefix = "PawnHybridVocationsAI.session",
        max_file_logs = 10,
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
        unsafe_skill_probe_mode = "off",
        unsafe_skill_probe_log_details = false,
        phase_blocked_log_interval_seconds = 5.0,
        observe_only_log_interval_seconds = 6.0,
        skip_log_interval_seconds = 4.0,
        target_source_log_interval_seconds = 6.0,
        target_cache_ttl_seconds = 0.85,
        secondary_target_scan_interval_seconds = 0.35,
    },
}

return config

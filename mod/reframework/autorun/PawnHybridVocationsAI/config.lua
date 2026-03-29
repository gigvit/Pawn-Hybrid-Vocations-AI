local config = {
    mod_name = "Pawn Hybrid Vocations AI",
    version = "0.9.1-runtime-research-externalized",
    debug = {
        log_level = "INFO",
        file_logging_enabled = true,
        file_log_directory = "PawnHybridVocationsAI/logs",
        file_log_prefix = "PawnHybridVocationsAI.session",
        max_file_logs = 10,
        nickcore_trace_enabled = true,
        nickcore_trace_directory = "PawnHybridVocationsAI/logs",
        nickcore_trace_prefix = "PawnHybridVocationsAI.nicktrace",
        nickcore_trace_summary_prefix = "PawnHybridVocationsAI.nicktrace_summary",
        nickcore_trace_max_files = 8,
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
        synthetic_initiator_window_seconds = 0.0,
        synthetic_stall_window_seconds = 0.75,
        synthetic_native_output_backoff_seconds = 1.25,
        synthetic_support_recovery_hp_ratio = 0.70,
        phase_failure_quarantine_seconds = 1.5,
        request_skip_think = true,
        enforce_skill_loadout_gate = true,
        -- This only relaxes unmapped custom-skill phases that still have a bridgeable
        -- execution path. It does not make selector-owned contracts executable.
        allow_unmapped_skill_phases = true,
        enable_crash_prone_skill_phases = false,
        unsafe_skill_probe_mode = "off",
        unsafe_skill_probe_log_details = false,
        phase_blocked_log_interval_seconds = 5.0,
        observe_only_log_interval_seconds = 6.0,
        skip_log_interval_seconds = 4.0,
        target_source_log_interval_seconds = 6.0,
        target_cache_ttl_seconds = 0.85,
        context_grace_seconds = 0.75,
        secondary_target_scan_interval_seconds = 0.35,
    },
}

return config

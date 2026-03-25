local config = {
    mod_name = "Pawn Hybrid Vocations AI",
    version = "0.9.0-ce-first-cleanup",
    debug = {
        log_level = "INFO",
    },
    discovery = {
        refresh_interval_seconds = 2.0,
    },
    runtime = {
        progression_refresh_interval_seconds = 0.25,
        hybrid_unlock_refresh_interval_seconds = 0.25,
    },
    hybrid_unlock = {
        target_job = 7,
    },
}

return config

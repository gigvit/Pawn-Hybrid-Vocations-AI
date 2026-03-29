local state = {
    initialized = false,
    runtime = {
        main_pawn = nil,
        main_pawn_data = nil,
        main_pawn_data_stable = nil,
        main_pawn_data_stable_time = nil,
        main_pawn_data_resolution_source = "unresolved",
        main_pawn_data_resolution_reason = "unresolved",
        main_pawn_data_resolution_age = nil,
        player = nil,
        progression_state_data = nil,
        hybrid_unlock_data = nil,
        game_time = 0.0,
        delta_time = 0.0,
        scheduler = {},
        scheduler_errors = {},
    },
}

return state

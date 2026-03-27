local state = {
    initialized = false,
    runtime = {
        main_pawn = nil,
        main_pawn_data = nil,
        player = nil,
        progression_state_data = nil,
        hybrid_unlock_data = nil,
        game_time = 0.0,
        delta_time = 0.0,
        scheduler = {},
    },
}

return state

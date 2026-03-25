local state = {
    initialized = false,
    last_discovery_refresh = 0.0,
    discovery = {
        managers = {},
        type_defs = {},
        main_pawn = {
            source = "unresolved",
            candidate_count = 0,
            errors = {},
            character_source = "unresolved",
            candidate_paths = {},
        },
    },
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

local state = require("PawnHybridVocationsAI/state")

local accessors = {}

local runtime_field_accessors = {
    main_pawn_data = "main_pawn_data",
    progression_gate_data = "progression_gate_data",
    progression_state_data = "progression_state_data",
    progression_trace_data = "progression_trace_data",
    job_gate_correlation_data = "job_gate_correlation_data",
    hybrid_unlock_data = "hybrid_unlock_data",
    hybrid_unlock_research_data = "hybrid_unlock_research_data",
    hybrid_unlock_prototype_data = "hybrid_unlock_prototype_data",
    guild_flow_research_data = "guild_flow_research_data",
    loadout_research_data = "loadout_research_data",
    vocation_research_data = "vocation_research_data",
    ability_research_data = "ability_research_data",
    combat_research_data = "combat_research_data",
    action_research_data = "action_research_data",
    synthetic_job07_adapter_data = "synthetic_job07_adapter_data",
    pawn_ai_data_research_data = "pawn_ai_data_research_data",
    npc_spawn_prototype_data = "npc_spawn_prototype_data",
}

function accessors.get_runtime()
    return state.runtime
end

function accessors.get_discovery()
    return state.discovery
end

for accessor_name, runtime_field in pairs(runtime_field_accessors) do
    accessors["get_" .. accessor_name] = function()
        return state.runtime[runtime_field]
    end
end

function accessors.get_sigurd_observer_data()
    return state.runtime.sigurd_observer_data or state.runtime.npc_spawn_prototype_data
end

return accessors

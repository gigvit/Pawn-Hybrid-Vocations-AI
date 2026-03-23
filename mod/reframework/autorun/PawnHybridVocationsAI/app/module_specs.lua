local config = require("PawnHybridVocationsAI/config")
local log = require("PawnHybridVocationsAI/core/log")
local talk_event_trace = require("PawnHybridVocationsAI/game/talk_event_trace")
local progression_trace = require("PawnHybridVocationsAI/game/progression/trace")
local loadout_research = require("PawnHybridVocationsAI/game/loadout_research")
local action_research = require("PawnHybridVocationsAI/game/action_research")
local synthetic_job07_adapter = require("PawnHybridVocationsAI/game/ai/synthetic_job07_adapter")
local pawn_ai_data_research = require("PawnHybridVocationsAI/game/pawn_ai_data_research")
local combat_research = require("PawnHybridVocationsAI/game/combat_research")
local npc_spawn_prototype = require("PawnHybridVocationsAI/game/npc_spawn_prototype")
local progression_gate = require("PawnHybridVocationsAI/game/progression_gate")
local progression_probe = require("PawnHybridVocationsAI/game/progression/probe")
local job_gate_correlation = require("PawnHybridVocationsAI/game/progression/correlation")
local hybrid_unlock = require("PawnHybridVocationsAI/game/hybrid_unlock")
local guild_flow_research = require("PawnHybridVocationsAI/game/guild_flow_research")

local module_specs = {}

local function synthetic_job07_adapter_enabled()
    return config.ai ~= nil
        and config.ai.enable_runtime_adapters == true
        and config.ai.enable_synthetic_layer == true
        and config.synthetic_job07_adapter ~= nil
        and config.synthetic_job07_adapter.enabled == true
end

function module_specs.get_install_specs()
    local specs = {
        {
            key = "talk_event_trace",
            install = function()
                talk_event_trace.install_hooks()
            end,
        },
        {
            key = "progression_trace",
            dependencies = { "talk_event_trace" },
            install = function(runtime)
                if config.progression_research.enable_runtime_hooks then
                    progression_trace.install_hooks(runtime)
                end
            end,
        },
        {
            key = "loadout_research",
            dependencies = { "progression_trace" },
            install = function(runtime)
                if config.vocation_research.enabled or config.ability_research.enabled then
                    loadout_research.install_hooks(runtime)
                end
            end,
        },
        {
            key = "action_research",
            dependencies = { "progression_trace", "loadout_research" },
            install = function(runtime)
                if config.action_research.enabled then
                    action_research.install_hooks(runtime)
                end
            end,
        },
        {
            key = "synthetic_job07_adapter",
            dependencies = { "action_research" },
            install = function(runtime)
                if synthetic_job07_adapter_enabled() then
                    synthetic_job07_adapter.install(runtime)
                end
            end,
        },
        {
            key = "pawn_ai_data_research",
            dependencies = { "action_research", "synthetic_job07_adapter" },
            install = function(runtime)
                if config.pawn_ai_data_research.enabled then
                    pawn_ai_data_research.install(runtime)
                end
            end,
        },
        {
            key = "combat_research",
            dependencies = { "progression_trace", "loadout_research", "action_research", "synthetic_job07_adapter", "pawn_ai_data_research" },
            install = function(runtime)
                if config.combat_research.enabled and config.combat_research.enable_runtime_hooks then
                    combat_research.install_hooks(runtime)
                end
            end,
        },
    }

    return specs
end

function module_specs.get_update_specs()
    local specs = {
        {
            schedule_key = "progression_gate.update",
            interval_seconds = config.runtime.progression_refresh_interval_seconds,
            key = "progression_state",
            update = progression_gate.update,
        },
        {
            schedule_key = "progression_probe.update",
            interval_seconds = config.runtime.progression_refresh_interval_seconds,
            key = "progression_probe",
            update = progression_probe.update,
        },
        {
            schedule_key = "progression_trace.update",
            interval_seconds = config.runtime.progression_refresh_interval_seconds,
            key = "progression_trace",
            dependencies = { "talk_event_trace" },
            update = progression_trace.update,
        },
        {
            schedule_key = "job_gate_correlation.update",
            interval_seconds = config.runtime.progression_correlation_refresh_interval_seconds,
            key = "job_gate_correlation",
            update = job_gate_correlation.update,
        },
        {
            schedule_key = "loadout_research.update",
            interval_seconds = config.runtime.progression_refresh_interval_seconds,
            key = "loadout_research",
            dependencies = { "progression_trace" },
            update = loadout_research.update,
        },
        {
            schedule_key = "action_research.update",
            interval_seconds = config.runtime.progression_refresh_interval_seconds,
            key = "action_research",
            dependencies = { "progression_trace", "loadout_research" },
            update = action_research.update,
        },
        {
            schedule_key = "synthetic_job07_adapter.update",
            interval_seconds = config.runtime.progression_refresh_interval_seconds,
            key = "synthetic_job07_adapter",
            dependencies = { "action_research" },
            update = function(runtime)
                if not synthetic_job07_adapter_enabled() then
                    return runtime.synthetic_job07_adapter_data
                end

                return synthetic_job07_adapter.update(runtime)
            end,
        },
        {
            schedule_key = "pawn_ai_data_research.update",
            interval_seconds = config.runtime.ai_data_refresh_interval_seconds,
            key = "pawn_ai_data_research",
            dependencies = { "action_research", "synthetic_job07_adapter" },
            update = pawn_ai_data_research.update,
        },
        {
            schedule_key = "combat_research.update",
            interval_seconds = config.runtime.progression_refresh_interval_seconds,
            key = "combat_research",
            dependencies = { "progression_trace", "loadout_research", "action_research", "synthetic_job07_adapter", "pawn_ai_data_research" },
            update = combat_research.update,
        },
        {
            schedule_key = "npc_spawn_prototype.update",
            interval_seconds = config.runtime.progression_refresh_interval_seconds,
            key = "npc_spawn_prototype",
            update = npc_spawn_prototype.update,
        },
        {
            schedule_key = "hybrid_unlock.update",
            interval_seconds = config.runtime.hybrid_unlock_refresh_interval_seconds,
            key = "hybrid_unlock",
            update = hybrid_unlock.update,
        },
        {
            schedule_key = "guild_flow_research.update",
            interval_seconds = config.guild_research.refresh_interval_seconds,
            key = "guild_flow_research",
            update = guild_flow_research.update,
        },
    }

    return specs
end

function module_specs.get_log_specs()
    return {
        {
            schedule_key = "log.discovery_snapshot",
            interval_seconds = config.debug.discovery_snapshot_interval_seconds,
            callback = function(runtime, discovery_state, data)
                log.discovery_snapshot(runtime, discovery_state, data)
            end,
        },
        {
            schedule_key = "log.guild_trace",
            interval_seconds = config.debug.guild_trace_log_interval_seconds,
            callback = function(runtime, discovery_state)
                log.guild_trace(runtime, discovery_state)
            end,
        },
    }
end

return module_specs

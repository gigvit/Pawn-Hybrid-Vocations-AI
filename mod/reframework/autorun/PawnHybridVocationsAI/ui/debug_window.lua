local config = require("PawnHybridVocationsAI/config")
local accessors = require("PawnHybridVocationsAI/game/accessors")
local log = require("PawnHybridVocationsAI/core/log")
local section_registry = require("PawnHybridVocationsAI/ui/section_registry")
local adapter_registry = require("PawnHybridVocationsAI/game/ai/adapter_registry")

local debug_window = {}

local function build_context()
    local runtime = accessors.get_runtime()
    return {
        runtime = runtime,
        discovery = accessors.get_discovery(),
        main_pawn_data = accessors.get_main_pawn_data(),
        progression = accessors.get_progression_gate_data(),
        hybrid_unlock = accessors.get_hybrid_unlock_data(),
        hybrid_unlock_research = runtime.hybrid_unlock_research_data,
        hybrid_unlock_prototype = runtime.hybrid_unlock_prototype_data,
        guild_flow = accessors.get_guild_flow_research_data(),
        npc_spawn = accessors.get_npc_spawn_prototype_data(),
        file_status = log.get_file_status(),
        session_status = log.get_session_status(),
        adapter_registry = adapter_registry,
    }
end

local function draw_sections(context)
    for entry in section_registry.each() do
        local is_visible = entry.is_visible == nil or entry.is_visible(context)
        if is_visible and imgui.tree_node(entry.title) then
            entry.draw(context)
            imgui.tree_pop()
        end
    end
end

function debug_window.draw_menu()
    if not config.debug.enabled then
        return
    end

    if imgui.tree_node(config.mod_name) then
        local changed, value = imgui.checkbox("Show inline debug details", config.debug.show_window)
        if changed then
            config.debug.show_window = value
        end

        if config.debug.show_window then
            local context = build_context()
            draw_sections(context)
            imgui.text("Detailed analysis is written to the discovery/session log files.")
        end

        imgui.tree_pop()
    end
end

function debug_window.draw()
end

return debug_window

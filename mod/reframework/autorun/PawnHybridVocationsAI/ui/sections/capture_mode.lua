local config = require("PawnHybridVocationsAI/config")
local guild_flow_research = require("PawnHybridVocationsAI/game/guild_flow_research")
local common = require("PawnHybridVocationsAI/ui/common")

local section = {}

function section.spec()
    return {
        key = "capture_mode",
        title = "Capture Mode",
        draw = function()
            local status = guild_flow_research.get_capture_session_status()

            local changed_enabled, enabled_value = imgui.checkbox("Always-on capture enabled", config.guild_research.enable_aggressive_hook_session)
            if changed_enabled then
                config.guild_research.enable_aggressive_hook_session = enabled_value
                guild_flow_research.set_full_capture_enabled(enabled_value)
            end

            local changed_auto, auto_value = imgui.checkbox("Auto-arm on guild events", config.guild_research.enable_auto_aggressive_hook_session)
            if changed_auto then
                config.guild_research.enable_auto_aggressive_hook_session = auto_value
            end

            common.draw_field("Mode", status.full_enabled and "always-on" or "session")
            common.draw_field("Capture active", common.bool_text(status.active))

            if status.full_enabled then
                if imgui.button("Restart always-on capture") then
                    guild_flow_research.set_full_capture_enabled(false)
                    guild_flow_research.set_full_capture_enabled(true)
                end
            elseif imgui.button("Enable always-on capture") then
                guild_flow_research.set_full_capture_enabled(true)
            end
        end,
    }
end

return section

local accessors = require("PawnHybridVocationsAI/game/accessors")
local npc_spawn_prototype = require("PawnHybridVocationsAI/game/npc_spawn_prototype")
local common = require("PawnHybridVocationsAI/ui/common")

local section = {}

function section.spec()
    return {
        key = "npc_tools",
        title = "NPC Tools",
        draw = function()
            local npc_spawn = accessors.get_sigurd_observer_data()
            common.draw_field("Sigurd resolved", common.bool_text(npc_spawn and npc_spawn.sigurd_character_obj ~= nil))
            common.draw_field("Sigurd status", npc_spawn and npc_spawn.sigurd_last_status or "<unresolved>")
            common.draw_field("Sigurd name", npc_spawn and npc_spawn.sigurd_last_seen_name or "<none>")
            common.draw_field("Sigurd source", npc_spawn and npc_spawn.sigurd_last_seen_source or "<none>")

            if imgui.button("Find Sigurd (Loaded Characters)") then
                npc_spawn_prototype.lookup_sigurd_loaded()
            end

            if imgui.button("Find Sigurd (NPCManager)") then
                npc_spawn_prototype.lookup_sigurd_npc_manager()
            end

            if imgui.button("Dump NPCManager Holders") then
                npc_spawn_prototype.dump_npc_manager_holders()
            end

            if imgui.button("Clear Sigurd Tracking") then
                npc_spawn_prototype.clear_sigurd_tracking()
            end
        end,
    }
end

return section

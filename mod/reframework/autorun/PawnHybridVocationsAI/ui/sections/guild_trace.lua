local common = require("PawnHybridVocationsAI/ui/common")

local section = {}

function section.spec()
    return {
        key = "guild_trace",
        title = "Guild Trace",
        draw = function(context)
            local guild_flow = context.guild_flow
            local ui040101 = guild_flow and guild_flow.targeted_ui_details_by_target and guild_flow.targeted_ui_details_by_target["app.ui040101_00"] or nil
            local ui040101_pawn = ui040101 and ui040101.main_pawn or nil

            common.draw_field("Trace dirty", guild_flow and common.bool_text(guild_flow.trace_dirty) or "<unresolved>")
            common.draw_field("Current index", ui040101_pawn and ui040101_pawn.current_index or "<unresolved>")
            common.draw_field("Index source", ui040101_pawn and ui040101_pawn.current_index_source or "<unresolved>")
            common.draw_field("Prune bypass", guild_flow and guild_flow.prune_bypass_probe and guild_flow.prune_bypass_probe.reason or "<unresolved>")
            common.draw_field("Reinjection", guild_flow and guild_flow.post_prune_reinjection and guild_flow.post_prune_reinjection.reason or "<unresolved>")
            common.draw_field("Refresh method", guild_flow and guild_flow.post_prune_reinjection and guild_flow.post_prune_reinjection.refresh_method or "<unresolved>")
        end,
    }
end

return section

local accessors = require("PawnHybridVocationsAI/game/accessors")
local common = require("PawnHybridVocationsAI/ui/common")

local section = {}

function section.spec()
    return {
        key = "progression_state",
        title = "Progression State",
        draw = function()
            local progression_state = accessors.get_progression_state_data()
            local progression_trace = accessors.get_progression_trace_data()
            local correlation = accessors.get_job_gate_correlation_data()

            common.draw_field("Player current job", progression_state and progression_state.summary and progression_state.summary.player_current_job or "<unresolved>")
            common.draw_field("Main pawn current job", progression_state and progression_state.summary and progression_state.summary.main_pawn_current_job or "<unresolved>")
            common.draw_field("Qualified match", progression_state and progression_state.summary and common.bool_text(progression_state.summary.qualified_match) or "<unresolved>")
            common.draw_field("Viewed match", progression_state and progression_state.summary and common.bool_text(progression_state.summary.viewed_match) or "<unresolved>")
            common.draw_field("Changed match", progression_state and progression_state.summary and common.bool_text(progression_state.summary.changed_match) or "<unresolved>")
            common.draw_field("Dominant gap", correlation and correlation.summary and correlation.summary.dominant_gap or "<unresolved>")
            common.draw_field("Latest talk event", correlation and correlation.summary and correlation.summary.latest_talk_event_label or "<unresolved>")
            common.draw_field("Job info hint", correlation and correlation.summary and correlation.summary.latest_job_info_hint or "<unresolved>")
            common.draw_field("Qualification checks", progression_trace and progression_trace.stats and progression_trace.stats.qualification_checks or 0)
            common.draw_field("Qualification writes", progression_trace and progression_trace.stats and progression_trace.stats.qualification_writes or 0)
            common.draw_field("Job change requests", progression_trace and progression_trace.stats and progression_trace.stats.job_change_requests or 0)
        end,
    }
end

return section

local config = require("PawnHybridVocationsAI/config")
local common = require("PawnHybridVocationsAI/ui/common")

local section = {}

function section.spec()
    return {
        key = "status",
        title = "Status",
        draw = function(context)
            local data = context.main_pawn_data
            local file_status = context.file_status
            local session_status = context.session_status

            common.draw_field("Version", config.version)
            common.draw_field("Main pawn resolved", common.bool_text(data ~= nil))
            common.draw_field("Main pawn job", data and (data.current_job or data.job) or "<unresolved>")
            common.draw_field("Log write success", common.bool_text(file_status.ok))
            common.draw_field("Log path", file_status.last_success_path or file_status.path or config.debug.discovery_log_path)
            common.draw_field("Session logging", common.bool_text(session_status and session_status.enabled))
            common.draw_field("Session ID", session_status and session_status.session_id or "<unresolved>")
            common.draw_field("Session last error", session_status and session_status.last_error or "<none>")
        end,
    }
end

return section

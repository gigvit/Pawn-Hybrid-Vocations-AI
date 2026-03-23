local status = require("PawnHybridVocationsAI/ui/sections/status")
local npc_tools = require("PawnHybridVocationsAI/ui/sections/npc_tools")
local capture_mode = require("PawnHybridVocationsAI/ui/sections/capture_mode")

local builtin_sections = {}

function builtin_sections.install(section_registry)
    local sections = {
        status,
        npc_tools,
        capture_mode,
    }

    for _, module in ipairs(sections) do
        section_registry.register(module.spec())
    end
end

return builtin_sections

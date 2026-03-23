local progression_state = require("PawnHybridVocationsAI/game/progression/state")

local progression_gate = {}

function progression_gate.update()
    return progression_state.update()
end

return progression_gate

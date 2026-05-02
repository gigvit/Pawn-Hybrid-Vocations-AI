local attack_graphs = {}

local graphs = {
    [1] = require("PawnHybridVocationsAI/data/job01_moves"),
    [2] = require("PawnHybridVocationsAI/data/job02_moves"),
    [3] = require("PawnHybridVocationsAI/data/job03_moves"),
    [4] = require("PawnHybridVocationsAI/data/job04_moves"),
    [5] = require("PawnHybridVocationsAI/data/job05_moves"),
    [6] = require("PawnHybridVocationsAI/data/job06_moves"),
    [7] = require("PawnHybridVocationsAI/data/job07_moves"),
    [8] = require("PawnHybridVocationsAI/data/job08_moves"),
    [9] = require("PawnHybridVocationsAI/data/job09_moves"),
    [10] = require("PawnHybridVocationsAI/data/job10_moves"),
}

local move_by_key = {}
local ordered_job_ids = {}

for job_id, graph in pairs(graphs) do
    ordered_job_ids[#ordered_job_ids + 1] = tonumber(job_id)
    for _, move in graph.each() do
        if type(move) == "table" and type(move.key) == "string" then
            move.job_id = tonumber(move.job_id) or tonumber(job_id)
            move.job_key = tostring(move.job_key or graph.key or ("job" .. tostring(job_id)))
            move_by_key[move.key] = move
        end
    end
end

table.sort(ordered_job_ids)

attack_graphs.graphs = graphs
attack_graphs.ordered_job_ids = ordered_job_ids
attack_graphs.move_by_key = move_by_key

function attack_graphs.get(job_id)
    return graphs[tonumber(job_id)]
end

function attack_graphs.has(job_id)
    return graphs[tonumber(job_id)] ~= nil
end

function attack_graphs.get_move(move_key)
    return move_by_key[tostring(move_key or "")]
end

function attack_graphs.each()
    local index = 0
    return function()
        index = index + 1
        local job_id = ordered_job_ids[index]
        if job_id == nil then
            return nil
        end
        return job_id, graphs[job_id]
    end
end

return attack_graphs

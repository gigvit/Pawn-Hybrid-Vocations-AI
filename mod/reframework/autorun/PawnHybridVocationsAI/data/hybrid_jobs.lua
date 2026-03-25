local hybrid_jobs = {}

local ordered = {
    {
        id = 7,
        key = "mystic_spearhand",
        label = "Mystic Spearhand",
        action_prefix = "Job07",
        controller_getter = "get_Job07ActionCtrl",
        controller_field = "<Job07ActionCtrl>k__BackingField",
        input_processor = "app.Job07InputProcessor",
    },
    {
        id = 8,
        key = "magick_archer",
        label = "Magick Archer",
        action_prefix = "Job08",
        controller_getter = "get_Job08ActionCtrl",
        controller_field = "<Job08ActionCtrl>k__BackingField",
        input_processor = nil,
    },
    {
        id = 9,
        key = "trickster",
        label = "Trickster",
        action_prefix = "Job09",
        controller_getter = nil,
        controller_field = "<Job09ActionCtrl>k__BackingField",
        input_processor = nil,
    },
    {
        id = 10,
        key = "warfarer",
        label = "Warfarer",
        action_prefix = "Job10",
        controller_getter = nil,
        controller_field = nil,
        input_processor = "app.PlayerInputProcessorDetail",
    },
}

local by_key = {}
local by_id = {}
local keys = {}
local ids = {}

for _, entry in ipairs(ordered) do
    by_key[entry.key] = entry
    by_id[entry.id] = entry
    table.insert(keys, entry.key)
    table.insert(ids, entry.id)
end

hybrid_jobs.ordered = ordered
hybrid_jobs.by_key = by_key
hybrid_jobs.by_id = by_id
hybrid_jobs.keys = keys
hybrid_jobs.ids = ids

function hybrid_jobs.each()
    return ipairs(ordered)
end

function hybrid_jobs.get_by_key(key)
    return by_key[key]
end

function hybrid_jobs.get_by_id(job_id)
    return by_id[tonumber(job_id)]
end

function hybrid_jobs.find_key_by_id(job_id)
    local item = hybrid_jobs.get_by_id(job_id)
    return item and item.key or nil
end

function hybrid_jobs.is_hybrid_job(job_id)
    return hybrid_jobs.get_by_id(job_id) ~= nil
end

function hybrid_jobs.get_action_prefix(job_id)
    local item = hybrid_jobs.get_by_id(job_id)
    return item and item.action_prefix or nil
end

function hybrid_jobs.get_controller_getter(job_id)
    local item = hybrid_jobs.get_by_id(job_id)
    return item and item.controller_getter or nil
end

function hybrid_jobs.get_controller_field(job_id)
    local item = hybrid_jobs.get_by_id(job_id)
    return item and item.controller_field or nil
end

function hybrid_jobs.get_input_processor(job_id)
    local item = hybrid_jobs.get_by_id(job_id)
    return item and item.input_processor or nil
end

return hybrid_jobs

local scheduler = require("PawnHybridVocationsAI/core/scheduler")
local module_system = require("PawnHybridVocationsAI/core/module_system")

local runtime_driver = {}

local function schedule_module_update(runtime, spec)
    scheduler.run(runtime, spec.schedule_key, spec.interval_seconds, function()
        module_system.run_update(runtime, {
            key = spec.key,
            dependencies = spec.dependencies or {},
            update = spec.update,
        })
    end)
end

function runtime_driver.run(runtime, data, update_specs, log_specs, discovery_state)
    for _, spec in ipairs(update_specs or {}) do
        schedule_module_update(runtime, spec)
    end

    for _, spec in ipairs(log_specs or {}) do
        scheduler.run(runtime, spec.schedule_key, spec.interval_seconds, function()
            spec.callback(runtime, discovery_state, data)
        end)
    end
end

return runtime_driver

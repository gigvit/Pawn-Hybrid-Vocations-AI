local config = require("PawnHybridVocationsAI/config")

local builtin_adapters = {}

local function register(adapter_registry, spec)
    if adapter_registry == nil then
        return
    end

    adapter_registry.register(spec)
end

function builtin_adapters.install(adapter_registry)
    register(adapter_registry, {
        key = "unlock.direct_job_context",
        title = "Direct JobContext Unlock",
        stage = "baseline",
        target_jobs = { 7, 8, 9, 10 },
        mode = "direct_unlock_path",
        is_enabled = function()
            return config.hybrid_unlock ~= nil
        end,
    })

    register(adapter_registry, {
        key = "ai.job07.native_input_probe",
        title = "Job07 Native Input Probe",
        stage = "experimental",
        target_jobs = { 7 },
        mode = "native_probe",
    })

    register(adapter_registry, {
        key = "ai.job07.actinter_bridge",
        title = "Job07 ActInter Bridge",
        stage = "experimental",
        target_jobs = { 7 },
        mode = "soft_compatibility_path",
    })

    register(adapter_registry, {
        key = "ai.job07.decision_pack_copy",
        title = "Job07 Decision Pack Copy",
        stage = "experimental",
        target_jobs = { 7 },
        mode = "donor_decision_path",
    })

    register(adapter_registry, {
        key = "ai.job07.synthetic_carrier_adapter",
        title = "Job07 Synthetic Carrier Adapter",
        stage = "prototype",
        target_jobs = { 7 },
        mode = "synthetic_carrier_layer",
        is_enabled = function()
            return config.synthetic_job07_adapter ~= nil
                and config.synthetic_job07_adapter.enabled == true
                and config.ai ~= nil
                and config.ai.enable_synthetic_layer == true
        end,
    })
end

return builtin_adapters

local execution_contracts = {}

local function merge_into(target, extra)
    if type(extra) ~= "table" then
        return target
    end

    for key, value in pairs(extra) do
        target[key] = value
    end

    return target
end

local function clone_string_list(values)
    local result = {}
    for _, value in ipairs(values or {}) do
        if type(value) == "string" and value ~= "" then
            result[#result + 1] = value
        end
    end

    return result
end

function execution_contracts.collect_named_candidates(primary_value, extra_values)
    local values = {}
    local seen = {}

    local function push(value)
        if type(value) ~= "string" or value == "" or seen[value] then
            return
        end

        seen[value] = true
        values[#values + 1] = value
    end

    push(primary_value)
    for _, value in ipairs(extra_values or {}) do
        push(value)
    end

    return values
end

function execution_contracts.make(class, extra)
    return merge_into({
        class = class,
        bridge_mode = "action_only",
        confidence = "pending",
    }, extra)
end

function execution_contracts.direct_safe(extra)
    return execution_contracts.make("direct_safe", extra)
end

function execution_contracts.carrier_required(extra)
    return execution_contracts.make("carrier_required", merge_into({
        bridge_mode = "carrier_then_action",
        confidence = "working_assumption",
    }, extra))
end

function execution_contracts.controller_stateful(extra)
    return execution_contracts.make("controller_stateful", merge_into({
        bridge_mode = "probe_only",
        probe_required = true,
        supported_probe_modes = {
            "action_only",
            "carrier_only",
            "carrier_then_action",
        },
    }, extra))
end

function execution_contracts.selector_owned(extra)
    return execution_contracts.make("selector_owned", merge_into({
        bridge_mode = "selector_owned",
    }, extra))
end

function execution_contracts.resolve(primary_source, secondary_source)
    local primary = type(primary_source) == "table" and primary_source or {}
    local secondary = type(secondary_source) == "table" and secondary_source or {}
    local source = type(primary.execution_contract) == "table"
        and primary.execution_contract
        or type(secondary.execution_contract) == "table"
            and secondary.execution_contract
            or {}

    local action_candidates = clone_string_list(source.action_candidates)
    if #action_candidates == 0 then
        action_candidates = execution_contracts.collect_named_candidates(primary.action_name, primary.action_candidates)
    end

    local carrier_candidates = clone_string_list(source.carrier_candidates)
    if #carrier_candidates == 0 then
        carrier_candidates = execution_contracts.collect_named_candidates(primary.pack_path, primary.pack_candidates)
    end

    local probe_pack_candidates = clone_string_list(source.probe_pack_candidates)
    if #probe_pack_candidates == 0 then
        probe_pack_candidates = clone_string_list(primary.probe_pack_candidates)
    end

    local preferred_probe_mode = type(source.preferred_probe_mode) == "string"
        and source.preferred_probe_mode ~= ""
        and source.preferred_probe_mode
        or type(primary.preferred_probe_mode) == "string"
        and primary.preferred_probe_mode ~= ""
        and primary.preferred_probe_mode
        or nil

    local legacy_probe_required = primary.unsafe_direct_action == true
    local contract_class = tostring(source.class or source.kind or "")
    if contract_class == "" then
        if legacy_probe_required then
            contract_class = "controller_stateful"
        elseif #carrier_candidates > 0 then
            contract_class = "carrier_required"
        elseif #action_candidates > 0 then
            contract_class = "direct_safe"
        else
            contract_class = "selector_owned"
        end
    end

    local bridge_mode = tostring(source.bridge_mode or "")
    if bridge_mode == "" then
        if legacy_probe_required or source.probe_required == true then
            bridge_mode = "probe_only"
        elseif contract_class == "selector_owned" then
            bridge_mode = "selector_owned"
        elseif #carrier_candidates > 0 and #action_candidates > 0 then
            bridge_mode = "carrier_then_action"
        elseif #carrier_candidates > 0 then
            bridge_mode = "carrier_only"
        else
            bridge_mode = "action_only"
        end
    end

    return {
        class = contract_class,
        bridge_mode = bridge_mode,
        confidence = tostring(source.confidence or primary.execution_confidence or "legacy_inferred"),
        action_candidates = action_candidates,
        carrier_candidates = carrier_candidates,
        probe_pack_candidates = probe_pack_candidates,
        probe_required = source.probe_required == true or legacy_probe_required,
        preferred_probe_mode = preferred_probe_mode,
        supported_probe_modes = clone_string_list(source.supported_probe_modes),
        controller_snapshot_key = source.controller_snapshot_key,
        controller_state_fields = clone_string_list(source.controller_state_fields),
        note = source.note,
    }
end

function execution_contracts.apply_to_phase(phase, contract)
    if type(phase) ~= "table" or type(contract) ~= "table" then
        return phase
    end

    local normalized = execution_contracts.resolve({
        execution_contract = contract,
    })

    phase.execution_contract = normalized
    phase.execution_contract_class = normalized.class
    phase.execution_bridge_mode = normalized.bridge_mode
    phase.execution_confidence = normalized.confidence

    if #normalized.carrier_candidates > 0 then
        phase.pack_path = normalized.carrier_candidates[1]
        phase.pack_candidates = normalized.carrier_candidates
    end
    if #normalized.action_candidates > 0 then
        phase.action_name = normalized.action_candidates[1]
        phase.action_candidates = normalized.action_candidates
    end
    if #normalized.probe_pack_candidates > 0 then
        phase.probe_pack_candidates = normalized.probe_pack_candidates
    end
    if normalized.probe_required then
        phase.unsafe_direct_action = true
    end
    if type(normalized.preferred_probe_mode) == "string" and normalized.preferred_probe_mode ~= "" then
        phase.preferred_probe_mode = normalized.preferred_probe_mode
    end

    return phase
end

function execution_contracts.supports_probe_mode(contract, probe_mode)
    if type(contract) ~= "table" then
        return false
    end
    if type(probe_mode) ~= "string" or probe_mode == "" or probe_mode == "off" then
        return true
    end

    local supported = contract.supported_probe_modes or {}
    if #supported == 0 then
        return true
    end

    for _, value in ipairs(supported) do
        if tostring(value) == probe_mode then
            return true
        end
    end

    return false
end

return execution_contracts

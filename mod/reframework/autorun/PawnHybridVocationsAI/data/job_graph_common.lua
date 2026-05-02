local common = {}

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

local function bridge_step(extra)
    return merge_into({
        kind = "bridge",
    }, extra)
end

local function wait_output_step(tokens, timeout_seconds, extra)
    return merge_into({
        kind = "wait_output",
        tokens = clone_string_list(tokens),
        timeout_seconds = timeout_seconds,
        allow_continue_on_timeout = true,
    }, extra)
end

local function hold_target_step(duration_seconds, max_distance, extra)
    return merge_into({
        kind = "hold_target",
        duration_seconds = duration_seconds,
        max_distance = max_distance,
        reissue_entry = false,
    }, extra)
end

local function end_step(extra)
    return merge_into({
        kind = "end",
    }, extra)
end

local function default_damage_kind(role, bucket)
    role = tostring(role or "")
    bucket = tostring(bucket or "")
    if role:find("defense", 1, true) or bucket == "defense" then
        return "utility_defense"
    end
    if role:find("support", 1, true) or bucket == "support" then
        return "support"
    end
    if bucket == "ranged" or role:find("ranged", 1, true) then
        return "ranged"
    end
    if bucket == "opener" or role:find("gapclose", 1, true) then
        return "gapclose"
    end
    return "melee"
end

local function default_tokens(action_name, extra_tokens)
    local tokens = {}
    if type(action_name) == "string" and action_name ~= "" then
        tokens[#tokens + 1] = action_name
        local family = action_name:match("Job%d+_(.+)")
        if family ~= nil and family ~= "" then
            tokens[#tokens + 1] = family
        end
    end
    for _, token in ipairs(extra_tokens or {}) do
        tokens[#tokens + 1] = token
    end
    return clone_string_list(tokens)
end

function common.action_move(definition)
    local action_name = definition.action_name or definition.action
    local output_tokens = default_tokens(action_name, definition.output_tokens)
    local selection = merge_into({
        role = definition.role or "attack",
        bucket = definition.bucket or "sustain",
        min_distance = definition.min_distance or 0.0,
        max_distance = definition.max_distance or 2.75,
        priority = definition.priority or 100,
        min_job_level = definition.min_job_level or 0,
    }, definition.selection)
    local availability = merge_into({
        kind = definition.skill_id ~= nil and "custom_skill" or "core",
        skill_id = definition.skill_id,
    }, definition.availability)
    local damage = merge_into({
        kind = definition.damage_kind or default_damage_kind(selection.role, selection.bucket),
        assist = definition.damage_assist == true,
        minimum_damage = definition.minimum_damage,
        wrong_target_cooldown_seconds = definition.wrong_target_cooldown_seconds,
        requires_target_match = definition.requires_target_match ~= false,
    }, definition.damage)
    local animation = merge_into({
        action = action_name,
        pack_path = definition.pack_path,
        duration_seconds = definition.duration_seconds or definition.hold_seconds or 0.45,
        source = definition.animation_source or "attack_graph_profile",
    }, definition.animation)
    local entry = merge_into({
        pack_path = definition.pack_path,
        action_name = action_name,
        action_layer = definition.action_layer or 0,
        action_priority = definition.action_priority or 0,
    }, definition.entry)
    local sequence = definition.sequence or {
        bridge_step(),
        wait_output_step(output_tokens, definition.wait_seconds or 0.30, {
            allow_continue_on_timeout = definition.allow_continue_on_timeout ~= false,
        }),
        hold_target_step(
            definition.hold_seconds or 0.45,
            definition.hold_max_distance or ((tonumber(selection.max_distance) or 2.75) + 0.50),
            {
                reissue_entry = definition.reissue_entry == true,
                expected_output_tokens = output_tokens,
            }
        ),
        end_step(),
    }

    return {
        key = definition.key,
        family = definition.family,
        label = definition.label or action_name or definition.key,
        cooldown_seconds = definition.cooldown_seconds or definition.cooldown or 1.10,
        failure_cooldown_seconds = definition.failure_cooldown_seconds or 0.55,
        stability = definition.stability or (selection and selection.stability) or "stable",
        output_tokens = output_tokens,
        availability = availability,
        selection = selection,
        damage = damage,
        animation = animation,
        flow = definition.flow or {
            follows = definition.follows or {},
            opens = definition.opens or {},
        },
        execution = definition.execution or {
            interrupt_policy = "guarded_owned",
        },
        entry = entry,
        sequence = sequence,
        chain = definition.chain,
    }
end

function common.core(definition)
    definition = merge_into({
        cooldown = 0.95,
        failure_cooldown_seconds = 0.45,
    }, definition)
    definition.availability = merge_into({
        kind = "core",
    }, definition.availability)
    return common.action_move(definition)
end

function common.custom(definition)
    definition = merge_into({
        cooldown = 1.60,
        failure_cooldown_seconds = 0.75,
    }, definition)
    definition.availability = merge_into({
        kind = "custom_skill",
        skill_id = definition.skill_id,
    }, definition.availability)
    definition.selection = merge_into({
        required_skill_id = definition.skill_id,
    }, definition.selection)
    return common.action_move(definition)
end

function common.graph(definition)
    local graph = {
        job_id = definition.job_id,
        key = definition.key,
        label = definition.label,
        action_prefix = definition.action_prefix,
        native_output_override_tokens = clone_string_list(definition.native_output_override_tokens),
        ordered = definition.moves or {},
        by_key = {},
    }

    for _, move in ipairs(graph.ordered) do
        if type(move) == "table" and type(move.key) == "string" then
            move.job_id = graph.job_id
            move.job_key = graph.key
            graph.by_key[move.key] = move
        end
    end

    function graph.each()
        return ipairs(graph.ordered)
    end

    function graph.get(key)
        return graph.by_key[tostring(key or "")]
    end

    return graph
end

return common

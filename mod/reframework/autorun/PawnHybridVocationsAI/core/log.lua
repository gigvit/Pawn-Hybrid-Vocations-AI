local config = require("PawnHybridVocationsAI/config")
local util = require("PawnHybridVocationsAI/core/util")
local hybrid_jobs = require("PawnHybridVocationsAI/data/hybrid_jobs")

local log = {}
local extract_actor_vocation_payload
local last_discovery_snapshot = nil
local last_guild_trace_signature = nil
local cached_candidate_paths = nil
local session_seed = os.date("%Y%m%d_%H%M%S")
local last_file_status = {
    enabled = false,
    attempted = false,
    ok = false,
    path = nil,
    reason = "not_attempted",
    gate = "not_attempted",
    last_success_path = nil,
    last_success_reason = "none",
    last_discovery_gate = "not_attempted",
    last_discovery_reason = "not_attempted",
    last_guild_event_reason = "not_attempted",
    last_guild_event_ok = false,
}
local last_session_status = {
    enabled = false,
    session_id = nil,
    text_path = nil,
    jsonl_path = nil,
    event_count = 0,
    last_flush_reason = "not_started",
    last_event = "none",
    last_error = "none",
}
local ensured_directories = {}
local level_order = {
    DEBUG = 10,
    INFO = 20,
    WARN = 30,
    ERROR = 40,
}
local default_discovery_log_path = "PawnHybridVocationsAI\\logs\\PawnHybridVocationsAI.discovery.log"
local default_session_log_directory = "PawnHybridVocationsAI\\logs"
local legacy_discovery_log_paths = {
    "logs\\PawnHybridVocationsAI.discovery.log",
    "data\\PawnHybridVocationsAI.discovery.log",
    "data\\logs\\PawnHybridVocationsAI.discovery.log",
}

local compact_candidate_paths
local compact_party_snapshot
local queue_first_seen_event

local function prefix(level)
    return string.format("[%s][%s] ", config.mod_name, level)
end

local function current_log_level()
    local configured = tostring(config.debug.log_level or (config.debug.verbose_logging and "DEBUG" or "INFO"))
    configured = string.upper(configured)
    if level_order[configured] == nil then
        return "INFO"
    end
    return configured
end

local function should_emit(level)
    local target = level_order[string.upper(tostring(level or "INFO"))] or level_order.INFO
    local minimum = level_order[current_log_level()] or level_order.INFO
    return target >= minimum
end

local function emit(level, message)
    if should_emit(level) then
        print(prefix(level) .. tostring(message))
    end
end

local function normalize_path(path)
    if type(path) ~= "string" then
        return nil
    end

    path = path:gsub("/", "\\")
    path = path:gsub("\\+", "\\")
    return path
end

local function ensure_parent_directory(path)
    if type(path) ~= "string" then
        return false, "invalid_path"
    end

    local directory = path:match("^(.*)[/\\][^/\\]+$")
    if directory == nil or directory == "" then
        return true, "no_parent_directory"
    end

    directory = normalize_path(directory)
    if ensured_directories[directory] then
        return true, "cached"
    end

    local command = string.format('mkdir "%s" 2>nul', directory)
    local ok = pcall(os.execute, command)
    if not ok then
        return false, "mkdir_failed"
    end

    ensured_directories[directory] = true
    return true, "ready"
end

local function append_file(path, text)
    local ok, result = pcall(function()
        ensure_parent_directory(path)
        local file = io.open(path, "a")
        if file == nil then
            return false, "open_failed"
        end

        file:write(text)
        file:close()
        return true, nil
    end)

    if not ok then
        return false, tostring(result)
    end

    return result
end

local function candidate_log_paths()
    if cached_candidate_paths ~= nil then
        return cached_candidate_paths
    end

    local paths = {}
    local seen = {}

    local function add_path(path)
        path = normalize_path(path)
        if path ~= nil and not seen[path] then
            seen[path] = true
            table.insert(paths, path)
        end
    end

    add_path(config.debug.discovery_log_path)
    add_path(default_discovery_log_path)
    for _, path in ipairs(legacy_discovery_log_paths) do
        add_path(path)
    end
    cached_candidate_paths = paths
    return cached_candidate_paths
end

local function update_file_status(values)
    for key, value in pairs(values) do
        last_file_status[key] = value
    end
end

local function sanitize_session_text(value)
    if type(value) ~= "string" then
        value = tostring(value)
    end

    value = value:gsub("[\r\n]+", " ")
    value = value:gsub("%s%s+", " ")
    return value
end

local function json_escape(value)
    value = tostring(value or "")
    value = value:gsub("\\", "\\\\")
    value = value:gsub('"', '\\"')
    value = value:gsub("\r", "\\r")
    value = value:gsub("\n", "\\n")
    value = value:gsub("\t", "\\t")
    return value
end

local function json_encode_scalar(value)
    local value_type = type(value)
    if value == nil then
        return "null"
    end
    if value_type == "boolean" then
        return value and "true" or "false"
    end
    if value_type == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return "null"
        end
        return tostring(value)
    end
    return '"' .. json_escape(value) .. '"'
end

local function stable_pairs(map)
    local keys = {}
    for key, _ in pairs(map or {}) do
        table.insert(keys, tostring(key))
    end
    table.sort(keys)
    local index = 0
    return function()
        index = index + 1
        local key = keys[index]
        if key == nil then
            return nil
        end
        return key, map[key]
    end
end

local function mark_json_object(value)
    if type(value) ~= "table" then
        return value
    end

    local meta = getmetatable(value)
    if meta ~= nil and meta.__json_force_object == true then
        return value
    end

    return setmetatable(value, {
        __json_force_object = true,
    })
end

local function normalize_event_payload(payload)
    if type(payload) ~= "table" then
        return mark_json_object({})
    end

    local has_entries = false
    for _, _ in pairs(payload) do
        has_entries = true
        break
    end

    if not has_entries then
        return mark_json_object(payload)
    end

    return payload
end

local function json_encode_simple(value, depth)
    depth = depth or 0
    if depth > 3 then
        return json_encode_scalar(util.describe_obj(value))
    end

    local value_type = type(value)
    if value_type ~= "table" then
        return json_encode_scalar(value)
    end

    local meta = getmetatable(value)
    local force_object = meta ~= nil and meta.__json_force_object == true
    local is_array = not force_object
    local count = 0
    for key, _ in pairs(value) do
        count = count + 1
        if type(key) ~= "number" then
            is_array = false
            break
        end
    end

    if count == 0 and force_object then
        return "{}"
    end

    if is_array then
        local parts = {}
        for index = 1, math.min(#value, 32) do
            table.insert(parts, json_encode_simple(value[index], depth + 1))
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end

    local parts = {}
    local emitted = 0
    for key, item in stable_pairs(value) do
        emitted = emitted + 1
        if emitted > 48 then
            break
        end
        table.insert(parts, '"' .. json_escape(key) .. '":' .. json_encode_simple(item, depth + 1))
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function get_session_state(runtime)
    runtime.session_log_data = runtime.session_log_data or {
        initialized = false,
        session_id = session_seed,
        started_at = os.date("%Y-%m-%d %H:%M:%S"),
        text_path = nil,
        jsonl_path = nil,
        queued_lines = {},
        queued_events = {},
        event_count = 0,
        last_flush_time = 0.0,
        last_discovery_signature = nil,
        last_progression_signature = nil,
        last_character_signature = nil,
        last_character_type_signature = nil,
        last_main_pawn_baseline_signature = nil,
        last_main_pawn_resolution_signature = nil,
        last_party_signature = nil,
        last_player_main_pawn_alignment_signature = nil,
        last_guild_signature = nil,
        last_scene_signature = nil,
        last_job_definition_signature = nil,
        last_skill_signature = nil,
        last_equipment_signature = nil,
        last_inventory_signature = nil,
        last_quest_signature = nil,
        last_dialogue_signature = nil,
        last_talk_event_signature = nil,
        last_weapon_signature = nil,
        last_prototype_signature = nil,
        npc_seen = {},
        npc_vocation_signatures = {},
        first_seen = {},
    }
    return runtime.session_log_data
end

local function resolve_session_paths(runtime)
    local session = get_session_state(runtime)
    if session.text_path ~= nil and session.jsonl_path ~= nil then
        return session.text_path, session.jsonl_path
    end

    local discovery_path = last_file_status.last_success_path or last_file_status.path

    local base_dir = nil
    if discovery_path ~= nil then
        base_dir = discovery_path:match("^(.*)[/\\][^/\\]+$")
    end

    if base_dir == nil then
        for _, path in ipairs(candidate_log_paths()) do
            if type(path) == "string" and string.find(string.lower(path), "pawnhybridvocationsai.discovery.log", 1, true) ~= nil then
                base_dir = path:match("^(.*)[/\\][^/\\]+$")
                if base_dir ~= nil then
                    break
                end
            end
        end
    end

    if base_dir == nil then
        base_dir = normalize_path(config.debug.session_log_directory or default_session_log_directory)
    end

    if base_dir == nil then
        base_dir = normalize_path(default_session_log_directory)
    end

    if base_dir == nil then
        base_dir = normalize_path("logs")
    end

    session.text_path = normalize_path(base_dir .. "\\PawnHybridVocationsAI.session_" .. session.session_id .. ".log")
    session.jsonl_path = normalize_path(base_dir .. "\\PawnHybridVocationsAI.session_" .. session.session_id .. ".jsonl")
    return session.text_path, session.jsonl_path
end

local function queue_session_line(runtime, line)
    local session = get_session_state(runtime)
    table.insert(session.queued_lines, sanitize_session_text(line))
    local cap = tonumber(config.debug.session_event_history_limit) or 256
    while #session.queued_lines > cap do
        table.remove(session.queued_lines, 1)
    end
end

local function build_event_record(runtime, category, name, payload)
    local session = get_session_state(runtime)
    session.event_count = session.event_count + 1

    local main_pawn_data = runtime.main_pawn_data
    local progression = runtime.progression_gate_data
    local guild_flow = runtime.guild_flow_research_data

    return {
        seq = session.event_count,
        session_id = session.session_id,
        time_real = os.date("%Y-%m-%d %H:%M:%S"),
        time_game = runtime.game_time or os.clock(),
        delta_time = runtime.delta_time or 0.0,
        event_category = category,
        event_name = name,
        scene = guild_flow and guild_flow.active_ui and tostring(guild_flow.active_ui.type_name or guild_flow.active_ui.type_full_name or "nil") or "nil",
        ui_type = guild_flow and tostring(guild_flow.active_ui_type or guild_flow.ui_type or "nil") or "nil",
        target = guild_flow and tostring(guild_flow.last_target or "unknown") or "unknown",
        chara_id = main_pawn_data and main_pawn_data.chara_id or nil,
        player_job = progression and progression.current_job or nil,
        main_pawn_job = main_pawn_data and (main_pawn_data.current_job or main_pawn_data.job) or nil,
        flow_now = guild_flow and guild_flow.flow_now or nil,
        source = "session_logger",
        payload = normalize_event_payload(payload),
    }
end

local function queue_session_event(runtime, category, name, payload, line)
    if not config.debug.session_logging_enabled then
        return
    end

    local session = get_session_state(runtime)
    local record = build_event_record(runtime, category, name, payload)
    table.insert(session.queued_events, record)
    local cap = tonumber(config.debug.session_event_history_limit) or 256
    while #session.queued_events > cap do
        table.remove(session.queued_events, 1)
    end
    if line ~= nil then
        queue_session_line(runtime, string.format("[%s/%s] %s", category, name, line))
    end
    last_session_status.event_count = session.event_count
    last_session_status.last_event = category .. ":" .. name
end

local function flush_session_logs(runtime, reason, force)
    if not config.debug.session_logging_enabled then
        last_session_status.enabled = false
        return
    end

    local session = get_session_state(runtime)
    local text_path, jsonl_path = resolve_session_paths(runtime)
    local now = runtime.game_time or os.clock()
    local flush_interval = tonumber(config.debug.session_flush_interval_seconds) or 0.5
    local should_flush = force == true
        or #session.queued_lines >= 16
        or #session.queued_events >= 16
        or (now - (session.last_flush_time or 0.0)) >= flush_interval

    if not should_flush then
        return
    end

    if not session.initialized then
        local header = table.concat({
            string.format("session_id=%s", session.session_id),
            string.format("started_at=%s", session.started_at),
            string.format("version=%s", tostring(config.version)),
            string.format("mod_name=%s", tostring(config.mod_name)),
            "",
        }, "\n")
        local ok, err = append_file(text_path, header)
        if not ok then
            last_session_status.enabled = false
            last_session_status.last_flush_reason = reason or "header_failed"
            last_session_status.last_error = tostring(err or "header_failed")
            return
        end
        session.initialized = true
    end

    if #session.queued_lines > 0 then
        local ok, err = append_file(text_path, table.concat(session.queued_lines, "\n") .. "\n")
        if ok then
            session.queued_lines = {}
        else
            last_session_status.enabled = false
            last_session_status.last_flush_reason = reason or "text_flush_failed"
            last_session_status.last_error = tostring(err or "text_flush_failed")
            return
        end
    end

    if config.debug.session_jsonl_enabled and #session.queued_events > 0 then
        local rows = {}
        for _, record in ipairs(session.queued_events) do
            table.insert(rows, json_encode_simple(record))
        end
        local ok, err = append_file(jsonl_path, table.concat(rows, "\n") .. "\n")
        if ok then
            session.queued_events = {}
        else
            last_session_status.enabled = false
            last_session_status.last_flush_reason = reason or "jsonl_flush_failed"
            last_session_status.last_error = tostring(err or "jsonl_flush_failed")
            return
        end
    elseif #session.queued_events > 0 then
        session.queued_events = {}
    end

    session.last_flush_time = now
    last_session_status.enabled = true
    last_session_status.session_id = session.session_id
    last_session_status.text_path = text_path
    last_session_status.jsonl_path = config.debug.session_jsonl_enabled and jsonl_path or nil
    last_session_status.last_flush_reason = reason or "flush"
    last_session_status.last_error = "none"
end

local function record_character_domain(runtime)
    if not config.debug.session_domain_character then
        return
    end

    local session = get_session_state(runtime)
    local main_pawn_data = runtime.main_pawn_data
    local progression = runtime.progression_gate_data
    local signature = table.concat({
        tostring(runtime.player ~= nil),
        tostring(main_pawn_data and main_pawn_data.chara_id or "nil"),
        tostring(main_pawn_data and (main_pawn_data.current_job or main_pawn_data.job) or "nil"),
        tostring(progression and progression.current_job or "nil"),
    }, "|")

    if signature == session.last_character_signature then
        return
    end
    session.last_character_signature = signature

    local payload = {
        player = util.describe_obj(runtime.player),
        player_job = progression and progression.current_job or nil,
        main_pawn_name = main_pawn_data and main_pawn_data.name or nil,
        main_pawn_chara_id = main_pawn_data and main_pawn_data.chara_id or nil,
        main_pawn_job = main_pawn_data and (main_pawn_data.current_job or main_pawn_data.job) or nil,
        main_pawn_weapon_job = main_pawn_data and main_pawn_data.weapon_job or nil,
        player_name = progression and progression.name or nil,
    }

    queue_session_event(
        runtime,
        "character",
        "party_state_changed",
        payload,
        string.format(
            "player_job=%s main_pawn=%s job=%s chara_id=%s",
            tostring(payload.player_job),
            tostring(payload.main_pawn_name),
            tostring(payload.main_pawn_job),
            tostring(payload.main_pawn_chara_id)
        )
    )
end

local function record_main_pawn_resolution_domain(runtime, discovery)
    if not config.debug.session_domain_character then
        return
    end

    local session = get_session_state(runtime)
    local main_pawn_data = runtime.main_pawn_data
    local payload = {
        player = util.describe_obj(runtime.player),
        main_pawn = util.describe_obj(runtime.main_pawn),
        main_pawn_data_ready = main_pawn_data ~= nil,
        source = discovery.main_pawn and discovery.main_pawn.source or nil,
        character_source = discovery.main_pawn and discovery.main_pawn.character_source or nil,
        candidate_count = discovery.main_pawn and discovery.main_pawn.candidate_count or 0,
        errors = discovery.main_pawn and discovery.main_pawn.errors or {},
        candidate_paths = compact_candidate_paths(discovery.main_pawn and discovery.main_pawn.candidate_paths or {}, 8),
        chara_id = main_pawn_data and main_pawn_data.chara_id or nil,
        name = main_pawn_data and main_pawn_data.name or nil,
        current_job = main_pawn_data and (main_pawn_data.current_job or main_pawn_data.job) or nil,
        weapon_job = main_pawn_data and main_pawn_data.weapon_job or nil,
        runtime_character = main_pawn_data and util.describe_obj(main_pawn_data.runtime_character) or nil,
        object = main_pawn_data and util.describe_obj(main_pawn_data.object) or nil,
        human = main_pawn_data and util.describe_obj(main_pawn_data.human) or nil,
        action_manager = main_pawn_data and util.describe_obj(main_pawn_data.action_manager) or nil,
        stamina_manager = main_pawn_data and util.describe_obj(main_pawn_data.stamina_manager) or nil,
        hit_controller = main_pawn_data and util.describe_obj(main_pawn_data.hit_controller) or nil,
        lock_on_ctrl = main_pawn_data and util.describe_obj(main_pawn_data.lock_on_ctrl) or nil,
        motion = main_pawn_data and util.describe_obj(main_pawn_data.motion) or nil,
        full_node = main_pawn_data and main_pawn_data.full_node or nil,
        upper_node = main_pawn_data and main_pawn_data.upper_node or nil,
        party_size = main_pawn_data and main_pawn_data.party_snapshot and #main_pawn_data.party_snapshot or #(discovery.party or {}),
    }

    local signature = json_encode_simple(payload)
    if signature == session.last_main_pawn_resolution_signature then
        return
    end
    session.last_main_pawn_resolution_signature = signature

    queue_session_event(
        runtime,
        "character",
        "main_pawn_resolution_changed",
        payload,
        string.format(
            "source=%s character_source=%s data_ready=%s chara_id=%s job=%s party=%s",
            tostring(payload.source),
            tostring(payload.character_source),
            tostring(payload.main_pawn_data_ready),
            tostring(payload.chara_id),
            tostring(payload.current_job),
            tostring(payload.party_size)
        )
    )
end

local function compact_named_fields(map, keys)
    local payload = {}
    for _, key in ipairs(keys or {}) do
        if map ~= nil and map[key] ~= nil then
            payload[key] = map[key]
        end
    end
    return payload
end

compact_candidate_paths = function(candidate_paths, limit)
    local compact = {}
    for index, item in ipairs(candidate_paths or {}) do
        if index > (limit or 8) then
            break
        end
        table.insert(compact, {
            source = item.source,
            result = item.result,
            type_name = item.type_name,
        })
    end
    return compact
end

compact_party_snapshot = function(party_snapshot, limit)
    local compact = {}
    for index, item in ipairs(party_snapshot or {}) do
        if index > (limit or 4) then
            break
        end
        table.insert(compact, {
            index = item.index,
            role = item.role,
            name = item.name,
            description = item.description,
            object = util.describe_obj(item.object),
        })
    end
    return compact
end

local function record_main_pawn_baseline_domain(runtime)
    if not config.debug.session_domain_character then
        return
    end

    local session = get_session_state(runtime)
    local main_pawn_data = runtime.main_pawn_data
    if main_pawn_data == nil then
        return
    end

    local progression = runtime.progression_gate_data
    local payload = {
        name = main_pawn_data.name,
        chara_id = main_pawn_data.chara_id,
        current_job = main_pawn_data.current_job or main_pawn_data.job,
        weapon_job = main_pawn_data.weapon_job,
        player_job = progression and progression.current_job or nil,
        player_job_matches_main_pawn = progression ~= nil
            and tostring(progression.current_job) == tostring(main_pawn_data.current_job or main_pawn_data.job)
            or nil,
        weapon_job_matches_main_pawn_job = tostring(main_pawn_data.weapon_job) == tostring(main_pawn_data.current_job or main_pawn_data.job),
        job_context = util.describe_obj(main_pawn_data.job_context),
        skill_context = util.describe_obj(main_pawn_data.skill_context),
        human = util.describe_obj(main_pawn_data.human),
        runtime_character = util.describe_obj(main_pawn_data.runtime_character),
        object = util.describe_obj(main_pawn_data.object),
        party_size = main_pawn_data.party_snapshot and #main_pawn_data.party_snapshot or 0,
        job_context_fields = compact_named_fields(
            main_pawn_data.job_context_fields,
            {"CurrentJob", "QualifiedJobBits", "ViewedNewJobBits", "ChangedJobBits"}
        ),
        skill_context_fields = compact_named_fields(
            main_pawn_data.skill_context_fields,
            {"CustomSkillSet", "LearnedCustomSkillBits", "SkillSet", "WeaponSkillSet"}
        ),
        player_progression_bits = progression ~= nil and {
            current_job = progression.current_job,
            qualified_job_bits = progression.qualified_job_bits,
            viewed_new_job_bits = progression.viewed_new_job_bits,
            changed_job_bits = progression.changed_job_bits,
        } or nil,
    }

    local signature = json_encode_simple(payload)
    if signature == session.last_main_pawn_baseline_signature then
        return
    end
    session.last_main_pawn_baseline_signature = signature

    queue_session_event(
        runtime,
        "character",
        "main_pawn_baseline_captured",
        payload,
        string.format(
            "name=%s chara_id=%s job=%s weapon_job=%s player_job=%s",
            tostring(payload.name),
            tostring(payload.chara_id),
            tostring(payload.current_job),
            tostring(payload.weapon_job),
            tostring(payload.player_job)
        )
    )
end

local function record_player_main_pawn_alignment_domain(runtime)
    if not config.debug.session_domain_character then
        return
    end

    local session = get_session_state(runtime)
    local progression = runtime.progression_gate_data
    local main_pawn_data = runtime.main_pawn_data
    if progression == nil or main_pawn_data == nil then
        return
    end

    local player_bits = {
        qualified_job_bits = progression.qualified_job_bits,
        viewed_new_job_bits = progression.viewed_new_job_bits,
        changed_job_bits = progression.changed_job_bits,
    }
    local main_pawn_bits = compact_named_fields(
        main_pawn_data.job_context_fields,
        {"QualifiedJobBits", "ViewedNewJobBits", "ChangedJobBits"}
    )
    local payload = {
        player_name = progression.name,
        player_job = progression.current_job,
        player_object = util.describe_obj(progression.object),
        player_human = util.describe_obj(progression.human),
        player_job_context = util.describe_obj(progression.job_context),
        player_skill_context = util.describe_obj(progression.skill_context),
        player_job_context_source = progression.job_context_source,
        player_skill_context_source = progression.skill_context_source,
        player_job_context_fields = compact_named_fields(
            progression.job_context_fields,
            {"CurrentJob", "QualifiedJobBits", "ViewedNewJobBits", "ChangedJobBits"}
        ),
        player_skill_context_fields = compact_named_fields(
            progression.skill_context_fields,
            {"CustomSkillSet", "LearnedCustomSkillBits", "SkillSet", "WeaponSkillSet"}
        ),
        main_pawn_name = main_pawn_data.name,
        main_pawn_chara_id = main_pawn_data.chara_id,
        main_pawn_job = main_pawn_data.current_job or main_pawn_data.job,
        main_pawn_weapon_job = main_pawn_data.weapon_job,
        main_pawn_object = util.describe_obj(main_pawn_data.object),
        main_pawn_human = util.describe_obj(main_pawn_data.human),
        main_pawn_job_context = util.describe_obj(main_pawn_data.job_context),
        main_pawn_skill_context = util.describe_obj(main_pawn_data.skill_context),
        main_pawn_human_context_fields = compact_named_fields(
            main_pawn_data.human_context_fields,
            {"job_context", "skill_context", "ability_context", "status_context", "track"}
        ),
        main_pawn_job_context_fields = compact_named_fields(
            main_pawn_data.job_context_fields,
            {"CurrentJob", "QualifiedJobBits", "ViewedNewJobBits", "ChangedJobBits"}
        ),
        main_pawn_skill_context_fields = compact_named_fields(
            main_pawn_data.skill_context_fields,
            {"CustomSkillSet", "LearnedCustomSkillBits", "SkillSet", "WeaponSkillSet"}
        ),
        jobs_match = tostring(progression.current_job) == tostring(main_pawn_data.current_job or main_pawn_data.job),
        weapon_matches_main_pawn_job = tostring(main_pawn_data.weapon_job) == tostring(main_pawn_data.current_job or main_pawn_data.job),
        qualified_bits_match = tostring(player_bits.qualified_job_bits) == tostring(main_pawn_bits.QualifiedJobBits),
        viewed_bits_match = tostring(player_bits.viewed_new_job_bits) == tostring(main_pawn_bits.ViewedNewJobBits),
        changed_bits_match = tostring(player_bits.changed_job_bits) == tostring(main_pawn_bits.ChangedJobBits),
    }

    local signature = json_encode_simple(payload)
    if signature == session.last_player_main_pawn_alignment_signature then
        return
    end
    session.last_player_main_pawn_alignment_signature = signature

    queue_session_event(
        runtime,
        "character",
        "player_main_pawn_alignment_changed",
        payload,
        string.format(
            "player_job=%s main_pawn_job=%s weapon_job=%s qualified_match=%s viewed_match=%s changed_match=%s",
            tostring(payload.player_job),
            tostring(payload.main_pawn_job),
            tostring(payload.main_pawn_weapon_job),
            tostring(payload.qualified_bits_match),
            tostring(payload.viewed_bits_match),
            tostring(payload.changed_bits_match)
        )
    )
end

local function record_party_snapshot_domain(runtime, discovery)
    if not config.debug.session_domain_character_type then
        return
    end

    local session = get_session_state(runtime)
    local main_pawn_data = runtime.main_pawn_data
    local party_snapshot = main_pawn_data and main_pawn_data.party_snapshot or {}
    local payload = {
        discovery_party_count = #(discovery.party or {}),
        runtime_party_count = #party_snapshot,
        party = compact_party_snapshot(party_snapshot, 4),
        main_pawn_name = main_pawn_data and main_pawn_data.name or nil,
        main_pawn_chara_id = main_pawn_data and main_pawn_data.chara_id or nil,
        source = discovery.main_pawn and discovery.main_pawn.source or nil,
        character_source = discovery.main_pawn and discovery.main_pawn.character_source or nil,
    }

    local signature = json_encode_simple(payload)
    if signature == session.last_party_signature then
        return
    end
    session.last_party_signature = signature

    queue_session_event(
        runtime,
        "character_type",
        "party_snapshot_changed",
        payload,
        string.format(
            "discovery_party=%s runtime_party=%s main_pawn=%s chara_id=%s",
            tostring(payload.discovery_party_count),
            tostring(payload.runtime_party_count),
            tostring(payload.main_pawn_name),
            tostring(payload.main_pawn_chara_id)
        )
    )
end

local function record_progression_domain(runtime)
    if not config.debug.session_domain_progression then
        return
    end

    local session = get_session_state(runtime)
    local progression = runtime.progression_gate_data
    if progression == nil then
        return
    end

    local signature = table.concat({
        tostring(progression.current_job),
        tostring(progression.qualified_job_bits),
        tostring(progression.viewed_new_job_bits),
        tostring(progression.changed_job_bits),
    }, "|")
    if signature == session.last_progression_signature then
        return
    end
    session.last_progression_signature = signature

    local payload = {
        current_job = progression.current_job,
        qualified_job_bits = progression.qualified_job_bits,
        viewed_new_job_bits = progression.viewed_new_job_bits,
        changed_job_bits = progression.changed_job_bits,
    }
    for _, key in ipairs(hybrid_jobs.keys) do
        payload[key] = progression.direct_hybrid_status and progression.direct_hybrid_status[key] or nil
    end

    queue_session_event(
        runtime,
        "progression",
        "job_bits_changed",
        payload,
        string.format(
            "current_job=%s qualified=%s viewed=%s changed=%s",
            tostring(payload.current_job),
            tostring(payload.qualified_job_bits),
            tostring(payload.viewed_new_job_bits),
            tostring(payload.changed_job_bits)
        )
    )
end

local function record_guild_domain(runtime)
    if not config.debug.session_domain_guild then
        return
    end

    local session = get_session_state(runtime)
    local guild_flow = runtime.guild_flow_research_data
    if guild_flow == nil then
        return
    end

    local detail = guild_flow.targeted_ui_details or {}
    local signature = table.concat({
        tostring(guild_flow.guild_ui_hint),
        tostring(detail.target_name or "nil"),
        tostring(detail.flow_now or "nil"),
        tostring(detail.info_count or "nil"),
        tostring(detail.item_count or "nil"),
        tostring(detail.current_index or "nil"),
    }, "|")
    if signature == session.last_guild_signature then
        return
    end
    session.last_guild_signature = signature

    local payload = {
        guild_ui_hint = guild_flow.guild_ui_hint == true,
        detail_ready = detail.target_name ~= nil
            or detail.flow_now ~= nil
            or detail.info_count ~= nil
            or detail.item_count ~= nil
            or detail.current_index ~= nil,
        ui_type = tostring(guild_flow.active_ui_type or "nil"),
        current_scene_name = tostring(guild_flow.current_scene_name or "nil"),
        current_state = tostring(guild_flow.current_state or "nil"),
        current_menu = tostring(guild_flow.current_menu or "nil"),
        current_window = tostring(guild_flow.current_window or "nil"),
        focused_window = tostring(guild_flow.focused_window or "nil"),
        target = tostring(detail.target_name or guild_flow.last_target or "unknown"),
        flow_now = tostring(detail.flow_now or guild_flow.flow_now or "nil"),
        info_count = detail.info_count,
        item_count = detail.item_count,
        current_index = detail.current_index,
        current_index_source = tostring(detail.current_index_source or "nil"),
        selected_job_name = tostring(detail.current_item_name or detail.current_job_name or "nil"),
        selected_job_id = detail.current_item_job_id or detail.current_job_id,
        last_event_summary = tostring(guild_flow.last_event_summary or "none"),
        trace_dirty = guild_flow.trace_dirty == true,
        paired_trace_ready = guild_flow.trace_assessment ~= nil
            and guild_flow.trace_assessment.paired_trace_ready == true
            or false,
        event_count = guild_flow.event_count or 0,
    }

    queue_session_event(
        runtime,
        "guild_ui",
        "state_changed",
        payload,
        string.format(
            "target=%s flow=%s info=%s item=%s index=%s",
            tostring(payload.target),
            tostring(payload.flow_now),
            tostring(payload.info_count),
            tostring(payload.item_count),
            tostring(payload.current_index)
        )
    )
end

local function record_scene_domain(runtime)
    if not config.debug.session_domain_scene then
        return
    end

    local session = get_session_state(runtime)
    local guild_flow = runtime.guild_flow_research_data
    local signature = table.concat({
        tostring(guild_flow and guild_flow.current_scene_name or "nil"),
        tostring(guild_flow and guild_flow.current_state or "nil"),
        tostring(guild_flow and guild_flow.current_menu or "nil"),
        tostring(guild_flow and guild_flow.current_window or "nil"),
        tostring(guild_flow and guild_flow.focused_window or "nil"),
        tostring(guild_flow and guild_flow.active_ui_type or "nil"),
    }, "|")
    if signature == session.last_scene_signature then
        return
    end
    session.last_scene_signature = signature

    local payload = {
        current_scene_name = guild_flow and guild_flow.current_scene_name or nil,
        current_state = guild_flow and guild_flow.current_state or nil,
        current_menu = guild_flow and guild_flow.current_menu or nil,
        current_window = guild_flow and guild_flow.current_window or nil,
        focused_window = guild_flow and guild_flow.focused_window or nil,
        active_ui_type = guild_flow and guild_flow.active_ui_type or nil,
    }

    queue_session_event(
        runtime,
        "world",
        "scene_context_changed",
        payload,
        string.format(
            "scene=%s state=%s menu=%s window=%s ui=%s",
            tostring(payload.current_scene_name),
            tostring(payload.current_state),
            tostring(payload.current_menu),
            tostring(payload.current_window),
            tostring(payload.active_ui_type)
        )
    )
end

local function record_character_type_domain(runtime)
    if not config.debug.session_domain_character_type then
        return
    end

    local session = get_session_state(runtime)
    local main_pawn_data = runtime.main_pawn_data
    local party_snapshot = main_pawn_data and main_pawn_data.party_snapshot or {}
    local other_pawn_count = 0
    for _, item in ipairs(party_snapshot) do
        if item.role == "other_pawn" then
            other_pawn_count = other_pawn_count + 1
        end
    end

    local signature = table.concat({
        tostring(runtime.player ~= nil),
        tostring(main_pawn_data ~= nil),
        tostring(other_pawn_count),
    }, "|")
    if signature == session.last_character_type_signature then
        return
    end
    session.last_character_type_signature = signature

    local payload = {
        player_role = runtime.player ~= nil and "Arisen" or nil,
        main_pawn_role = main_pawn_data ~= nil and "MainPawn" or nil,
        support_pawn_count = other_pawn_count,
        party_roles = party_snapshot,
    }

    queue_session_event(
        runtime,
        "character",
        "character_type_context_changed",
        payload,
        string.format(
            "player=%s main_pawn=%s support_pawns=%s",
            tostring(payload.player_role),
            tostring(payload.main_pawn_role),
            tostring(payload.support_pawn_count)
        )
    )
end

local function extract_job_definition_payload(progression)
    if progression == nil then
        return {}
    end

    local payload = {
        current_job = progression.current_job,
        qualified_job_bits = progression.qualified_job_bits,
        viewed_new_job_bits = progression.viewed_new_job_bits,
        changed_job_bits = progression.changed_job_bits,
    }

    for _, key in ipairs(hybrid_jobs.keys) do
        payload[key] = progression.direct_hybrid_status and progression.direct_hybrid_status[key] or nil
        payload[key .. "_bits"] = progression.hybrid_gate_status and progression.hybrid_gate_status[key] or nil
    end

    return payload
end

local function record_job_definition_domain(runtime)
    if not config.debug.session_domain_job_definitions then
        return
    end

    local session = get_session_state(runtime)
    local progression = runtime.progression_gate_data
    if progression == nil then
        return
    end

    local payload = extract_job_definition_payload(progression)
    local signature = json_encode_simple(payload)
    if signature == session.last_job_definition_signature then
        return
    end
    session.last_job_definition_signature = signature

    queue_session_event(
        runtime,
        "job_info",
        "job_definition_snapshot",
        payload,
        (function()
            local bit_values = {}
            for _, key in ipairs(hybrid_jobs.keys) do
                local item = payload[key .. "_bits"]
                table.insert(bit_values, tostring(item and item.qualified and item.qualified.bit_job_minus_one or nil))
            end
            return string.format(
                "current_job=%s hybrid_bits=%s",
                tostring(payload.current_job),
                table.concat(bit_values, "/")
            )
        end)()
    )
end

local function summarize_field_subset(field_map, preferred_keys, limit)
    local normalized = field_map
    if type(field_map) == "table" and field_map[1] ~= nil and type(field_map[1]) == "table" and field_map[1].name ~= nil then
        normalized = {}
        for _, entry in ipairs(field_map) do
            normalized[entry.name] = entry.value
        end
    end

    local result = {}
    local emitted = 0
    for _, key in ipairs(preferred_keys or {}) do
        local value = normalized and normalized[key] or nil
        if value ~= nil then
            result[key] = util.describe_obj(value)
            emitted = emitted + 1
            if emitted >= (limit or 8) then
                return result
            end
        end
    end
    return result
end

local function record_skill_domain(runtime)
    if not config.debug.session_domain_skills then
        return
    end

    local session = get_session_state(runtime)
    local progression = runtime.progression_gate_data
    local main_pawn_data = runtime.main_pawn_data
    local payload = {
        player_skill_context = progression and util.describe_obj(progression.skill_context) or nil,
        player_skill_context_source = progression and progression.skill_context_source or nil,
        player_skill_availability = runtime.progression_state_data and runtime.progression_state_data.player and util.describe_obj(runtime.progression_state_data.player.skill_availability) or nil,
        player_skill_fields = summarize_field_subset(
            progression and progression.skill_context_fields or nil,
            {"CustomSkillSet", "LearnedCustomSkillBits", "SkillSet", "WeaponSkillSet", "Availability"},
            6
        ),
        main_pawn_skill_context = main_pawn_data and util.describe_obj(main_pawn_data.skill_context) or nil,
        main_pawn_skill_availability = runtime.progression_state_data and runtime.progression_state_data.main_pawn and util.describe_obj(runtime.progression_state_data.main_pawn.skill_availability) or nil,
        main_pawn_skill_fields = summarize_field_subset(
            main_pawn_data and main_pawn_data.skill_context_fields or nil,
            {"CustomSkillSet", "LearnedCustomSkillBits", "SkillSet", "WeaponSkillSet", "Availability"},
            6
        ),
        player_ability_fields = summarize_field_subset(
            runtime.progression_state_data and runtime.progression_state_data.player and runtime.progression_state_data.player.ability_context_fields or nil,
            {"EquipedAbilities", "EquippedAbilities", "Abilities"},
            6
        ),
        main_pawn_ability_fields = summarize_field_subset(
            runtime.progression_state_data and runtime.progression_state_data.main_pawn and runtime.progression_state_data.main_pawn.ability_context_fields or nil,
            {"EquipedAbilities", "EquippedAbilities", "Abilities"},
            6
        ),
        main_pawn_skill_state = main_pawn_data and util.describe_obj(main_pawn_data.skill_state) or nil,
        vocation_summary = runtime.vocation_research_data and runtime.vocation_research_data.summary or nil,
        ability_summary = runtime.ability_research_data and runtime.ability_research_data.summary or nil,
        combat_summary = runtime.combat_research_data and runtime.combat_research_data.summary or nil,
    }

    local signature = json_encode_simple(payload)
    if signature == session.last_skill_signature then
        return
    end
    session.last_skill_signature = signature

    queue_session_event(
        runtime,
        "skill",
        "skill_context_changed",
        payload,
        string.format(
            "player_skill_ctx=%s main_pawn_skill_ctx=%s",
            tostring(payload.player_skill_context),
            tostring(payload.main_pawn_skill_context)
        )
    )
end

local function combat_research_map(runtime)
    local data = runtime.combat_research_data
    if data == nil then
        return {}
    end

    local summary = data.summary or {}
    return {
        hooks_installed = tostring(data.hooks_installed),
        installed_methods = table.concat(data.installed_methods or {}, ", "),
        registration_error_count = tostring(#(data.registration_errors or {})),
        recent_event_count = tostring(#(data.recent_events or {})),
        availability_checks = tostring(data.stats and data.stats.availability_checks or 0),
        context_checks = tostring(data.stats and data.stats.context_checks or 0),
        main_pawn_events = tostring(data.stats and data.stats.main_pawn_events or 0),
        player_events = tostring(data.stats and data.stats.player_events or 0),
        player_job = tostring(summary.player_job or "nil"),
        player_weapon_job = tostring(summary.player_weapon_job or "nil"),
        main_pawn_job = tostring(summary.main_pawn_job or "nil"),
        main_pawn_weapon_job = tostring(summary.main_pawn_weapon_job or "nil"),
        player_current_job_skills = tostring(summary.player_current_job_skills or ""),
        main_pawn_current_job_skills = tostring(summary.main_pawn_current_job_skills or ""),
        player_full_node = tostring(summary.player_full_node or "nil"),
        player_upper_node = tostring(summary.player_upper_node or "nil"),
        main_pawn_full_node = tostring(summary.main_pawn_full_node or "nil"),
        main_pawn_upper_node = tostring(summary.main_pawn_upper_node or "nil"),
    }
end

local function ability_research_map(runtime)
    local data = runtime.ability_research_data
    if data == nil then
        return {}
    end

    local summary = data.summary or {}
    return {
        hooks_installed = tostring(data.hooks_installed),
        installed_methods = table.concat(data.installed_methods or {}, ", "),
        registration_error_count = tostring(#(data.registration_errors or {})),
        recent_event_count = tostring(#(data.recent_events or {})),
        summary_changes = tostring(data.stats and data.stats.summary_changes or 0),
        purchase_policy = tostring(summary.purchase_policy or "per_character_required"),
        player_job = tostring(summary.player_job or "nil"),
        player_current_job_abilities = tostring(summary.player_current_job_abilities or ""),
        player_current_job_ability_count = tostring(summary.player_current_job_ability_count or 0),
        player_augment_ready = tostring(summary.player_augment_ready),
        player_bucket_source = tostring(summary.player_bucket_source or "nil"),
        main_pawn_job = tostring(summary.main_pawn_job or "nil"),
        main_pawn_current_job_abilities = tostring(summary.main_pawn_current_job_abilities or ""),
        main_pawn_current_job_ability_count = tostring(summary.main_pawn_current_job_ability_count or 0),
        main_pawn_augment_ready = tostring(summary.main_pawn_augment_ready),
        main_pawn_bucket_source = tostring(summary.main_pawn_bucket_source or "nil"),
        current_job_gap = tostring(summary.current_job_gap or "unresolved"),
    }
end

local function ability_research_recent_events_map(runtime)
    local data = runtime.ability_research_data
    if data == nil then
        return {}
    end

    local map = {}
    for index, item in ipairs(data.recent_events or {}) do
        map[index] = string.format(
            "player_job=%s | player_abilities=%s | pawn_job=%s | pawn_abilities=%s | gap=%s",
            tostring(item.player_job),
            tostring(item.player_current_job_abilities),
            tostring(item.main_pawn_job),
            tostring(item.main_pawn_current_job_abilities),
            tostring(item.current_job_gap)
        )
    end
    return map
end

local function ability_research_registration_errors_map(runtime)
    local data = runtime.ability_research_data
    if data == nil then
        return {}
    end

    local map = {}
    for index, item in ipairs(data.registration_errors or {}) do
        map[index] = tostring(item)
    end
    return map
end

local function action_research_map(runtime)
    local data = runtime.action_research_data
    if data == nil then
        return {}
    end

    local summary = data.summary or {}
    return {
        hooks_installed = tostring(data.hooks_installed),
        installed_methods = table.concat(data.installed_methods or {}, ", "),
        registration_error_count = tostring(#(data.registration_errors or {})),
        recent_event_count = tostring(#(data.recent_events or {})),
        summary_changes = tostring(data.stats and data.stats.summary_changes or 0),
        actinter_requests = tostring(data.stats and data.stats.actinter_requests or 0),
       reqmain_pack_requests = tostring(data.stats and data.stats.reqmain_pack_requests or 0),
       request_action_calls = tostring(data.stats and data.stats.request_action_calls or 0),
       decision_probe_hits = tostring(data.stats and data.stats.decision_probe_hits or 0),
       decision_snapshot_hits = tostring(data.stats and data.stats.decision_snapshot_hits or 0),
        ai_decision_snapshot_hits = tostring(summary.ai_decision_snapshot_hits or 0),
        ai_target_snapshot_hits = tostring(summary.ai_target_snapshot_hits or 0),
        decision_actionpack_snapshot_hits = tostring(summary.decision_actionpack_snapshot_hits or 0),
        decision_producer_snapshot_hits = tostring(summary.decision_producer_snapshot_hits or 0),
       player_job = tostring(summary.player_job or "nil"),
       player_human_address = tostring(summary.player_human_address or "nil"),
        player_runtime_character_address = tostring(summary.player_runtime_character_address or "nil"),
        player_action_manager = tostring(summary.player_action_manager or "nil"),
        player_action_manager_address = tostring(summary.player_action_manager_address or "nil"),
        player_action_manager_source = tostring(summary.player_action_manager_source or "unresolved"),
       player_current_job_action_ctrl = tostring(summary.player_current_job_action_ctrl or "nil"),
        player_current_job_action_ctrl_source = tostring(summary.player_current_job_action_ctrl_source or "unresolved"),
       player_common_action_selector = tostring(summary.player_common_action_selector or "nil"),
       player_common_action_selector_source = tostring(summary.player_common_action_selector_source or "unresolved"),
       player_ai_blackboard_controller = tostring(summary.player_ai_blackboard_controller or "nil"),
       player_ai_blackboard_address = tostring(summary.player_ai_blackboard_address or "nil"),
       player_ai_blackboard_source = tostring(summary.player_ai_blackboard_source or "unresolved"),
       player_ai_decision_maker = tostring(summary.player_ai_decision_maker or "nil"),
       player_decision_module = tostring(summary.player_decision_module or "nil"),
       player_decision_executor = tostring(summary.player_decision_executor or "nil"),
       player_executing_decision = tostring(summary.player_executing_decision or "nil"),
       player_executing_decision_target = tostring(summary.player_executing_decision_target or "nil"),
       player_current_execute_actinter = tostring(summary.player_current_execute_actinter or "nil"),
       player_current_execute_actinter_pack = tostring(summary.player_current_execute_actinter_pack or "nil"),
       player_current_execute_actinter_pack_path = tostring(summary.player_current_execute_actinter_pack_path or "nil"),
       player_actinter_requests = tostring(summary.player_actinter_requests or 0),
        player_request_action_calls = tostring(summary.player_request_action_calls or 0),
        player_last_requested_action = tostring(summary.player_last_requested_action or "nil"),
        player_last_requested_priority = tostring(summary.player_last_requested_priority or "nil"),
        player_observed_request_action_count = tostring(summary.player_observed_request_action_count or 0),
        player_full_node = tostring(summary.player_full_node or "nil"),
        player_upper_node = tostring(summary.player_upper_node or "nil"),
        player_in_job_action_node = tostring(summary.player_in_job_action_node),
       main_pawn_job = tostring(summary.main_pawn_job or "nil"),
       main_pawn_human_address = tostring(summary.main_pawn_human_address or "nil"),
       main_pawn_runtime_character_address = tostring(summary.main_pawn_runtime_character_address or "nil"),
       main_pawn_pawn_address = tostring(summary.main_pawn_pawn_address or "nil"),
        main_pawn_action_manager = tostring(summary.main_pawn_action_manager or "nil"),
        main_pawn_action_manager_address = tostring(summary.main_pawn_action_manager_address or "nil"),
        main_pawn_action_manager_source = tostring(summary.main_pawn_action_manager_source or "unresolved"),
       main_pawn_current_job_action_ctrl = tostring(summary.main_pawn_current_job_action_ctrl or "nil"),
        main_pawn_current_job_action_ctrl_source = tostring(summary.main_pawn_current_job_action_ctrl_source or "unresolved"),
       main_pawn_common_action_selector = tostring(summary.main_pawn_common_action_selector or "nil"),
       main_pawn_common_action_selector_source = tostring(summary.main_pawn_common_action_selector_source or "unresolved"),
       main_pawn_ai_blackboard_controller = tostring(summary.main_pawn_ai_blackboard_controller or "nil"),
       main_pawn_ai_blackboard_address = tostring(summary.main_pawn_ai_blackboard_address or "nil"),
       main_pawn_ai_blackboard_source = tostring(summary.main_pawn_ai_blackboard_source or "unresolved"),
       main_pawn_ai_decision_maker = tostring(summary.main_pawn_ai_decision_maker or "nil"),
       main_pawn_decision_module = tostring(summary.main_pawn_decision_module or "nil"),
       main_pawn_decision_executor = tostring(summary.main_pawn_decision_executor or "nil"),
       main_pawn_executing_decision = tostring(summary.main_pawn_executing_decision or "nil"),
       main_pawn_executing_decision_target = tostring(summary.main_pawn_executing_decision_target or "nil"),
      main_pawn_current_execute_actinter = tostring(summary.main_pawn_current_execute_actinter or "nil"),
      main_pawn_current_execute_actinter_pack = tostring(summary.main_pawn_current_execute_actinter_pack or "nil"),
      main_pawn_current_execute_actinter_pack_path = tostring(summary.main_pawn_current_execute_actinter_pack_path or "nil"),
      main_pawn_last_observed_actinter_pack_path = tostring(summary.main_pawn_last_observed_actinter_pack_path or "nil"),
      main_pawn_job07_decision_packhandler_snapshot = tostring(summary.main_pawn_job07_decision_packhandler_snapshot or "nil"),
      main_pawn_actinter_requests = tostring(summary.main_pawn_actinter_requests or 0),
       main_pawn_request_action_calls = tostring(summary.main_pawn_request_action_calls or 0),
       main_pawn_last_requested_action = tostring(summary.main_pawn_last_requested_action or "nil"),
       main_pawn_last_requested_priority = tostring(summary.main_pawn_last_requested_priority or "nil"),
       main_pawn_observed_request_action_count = tostring(summary.main_pawn_observed_request_action_count or 0),
      decision_probe_hits = tostring(summary.decision_probe_hits or 0),
        last_decision_probe_action = tostring(summary.last_decision_probe_action or "nil"),
        last_decision_probe_priority = tostring(summary.last_decision_probe_priority or "nil"),
        last_decision_probe_nodes = tostring(summary.last_decision_probe_nodes or "nil|nil"),
        last_decision_probe_decision = tostring(summary.last_decision_probe_decision or "nil"),
        last_decision_probe_decision_target = tostring(summary.last_decision_probe_decision_target or "nil"),
        last_decision_probe_pack_path = tostring(summary.last_decision_probe_pack_path or "nil"),
        last_decision_probe_actions = tostring(summary.last_decision_probe_actions or "nil,nil"),
        last_decision_snapshot_target = tostring(summary.last_decision_snapshot_target or "none"),
        last_decision_snapshot_action = tostring(summary.last_decision_snapshot_action or "nil"),
        last_decision_snapshot_fields = tostring(summary.last_decision_snapshot_fields or ""),
        last_ai_decision_snapshot_action = tostring(summary.last_ai_decision_snapshot_action or "nil"),
        last_ai_decision_snapshot_fields = tostring(summary.last_ai_decision_snapshot_fields or ""),
        last_ai_target_snapshot_action = tostring(summary.last_ai_target_snapshot_action or "nil"),
        last_ai_target_snapshot_fields = tostring(summary.last_ai_target_snapshot_fields or ""),
        last_decision_actionpack_snapshot_action = tostring(summary.last_decision_actionpack_snapshot_action or "nil"),
        last_decision_actionpack_snapshot_fields = tostring(summary.last_decision_actionpack_snapshot_fields or ""),
        last_decision_producer_snapshot_action = tostring(summary.last_decision_producer_snapshot_action or "nil"),
        last_decision_producer_snapshot_fields = tostring(summary.last_decision_producer_snapshot_fields or ""),
        main_pawn_full_node = tostring(summary.main_pawn_full_node or "nil"),
        main_pawn_upper_node = tostring(summary.main_pawn_upper_node or "nil"),
        main_pawn_in_job_action_node = tostring(summary.main_pawn_in_job_action_node),
       last_actinter_target = tostring(summary.last_actinter_target or "none"),
       last_actinter_pack = tostring(summary.last_actinter_pack or "nil"),
       last_actinter_pack_path = tostring(summary.last_actinter_pack_path or "nil"),
       last_actinter_controller = tostring(summary.last_actinter_controller or "nil"),
       last_actinter_controller_address = tostring(summary.last_actinter_controller_address or "nil"),
       observed_pack_count = tostring(summary.observed_pack_count or 0),
       current_job_gap = tostring(summary.current_job_gap or "unresolved"),
   }
end

local function action_research_recent_events_map(runtime)
    local data = runtime.action_research_data
    if data == nil then
        return {}
    end

    local map = {}
    for index, item in ipairs(data.recent_events or {}) do
        map[index] = string.format(
          "player_job=%s | player_rt=%s | player_ctrl=%s | player_selector=%s | player_bb=%s | player_decision=%s -> %s | player_nodes=%s|%s | pawn_job=%s | pawn_rt=%s | pawn_ctrl=%s | pawn_selector=%s | pawn_bb=%s | pawn_decision=%s -> %s | pawn_nodes=%s|%s | actinter=%s/%s@%s [%s] path=%s | req=%s/%s:%s | gap=%s",
          tostring(item.player_job),
          tostring(item.player_runtime_character_address or "nil"),
          tostring(item.player_current_job_action_ctrl_source),
          tostring(item.player_common_action_selector_source),
          tostring(item.player_ai_blackboard_address or "nil"),
          tostring(item.player_executing_decision or "nil"),
          tostring(item.player_executing_decision_target or "nil"),
          tostring(item.player_full_node),
          tostring(item.player_upper_node),
          tostring(item.main_pawn_job),
          tostring(item.main_pawn_runtime_character_address or "nil"),
          tostring(item.main_pawn_current_job_action_ctrl_source),
          tostring(item.main_pawn_common_action_selector_source),
          tostring(item.main_pawn_ai_blackboard_address or "nil"),
          tostring(item.main_pawn_executing_decision or "nil"),
          tostring(item.main_pawn_executing_decision_target or "nil"),
          tostring(item.main_pawn_full_node),
          tostring(item.main_pawn_upper_node),
          tostring(item.actinter_target or "none"),
          tostring(item.actinter_target_reason or "unknown"),
          tostring(item.actinter_job or "nil"),
          tostring(item.actinter_controller_address or "nil"),
          tostring(item.actinter_pack_path or "nil"),
          tostring(item.request_action_target or "none"),
          tostring(item.request_action_priority or "nil"),
          tostring(item.request_action_name or "nil"),
          tostring(item.current_job_gap)
       )
   end
    return map
end

local function action_research_observed_packs_map(runtime)
    local data = runtime.action_research_data
    if data == nil then
        return {}
    end

    local map = {}
    local items = {}
    for _, item in pairs(data.observed_packs or {}) do
        table.insert(items, item)
    end
    table.sort(items, function(left, right)
        return tostring(left.address or "") < tostring(right.address or "")
    end)

    for index, item in ipairs(items) do
        if index > 16 then
            break
        end
        local method_names = {}
        for method_name in pairs(item.methods or {}) do
            table.insert(method_names, tostring(method_name))
        end
        table.sort(method_names)
        local field_parts = {}
        for _, field in ipairs(item.fields or {}) do
            table.insert(field_parts, string.format("%s=%s", tostring(field.name), tostring(field.value)))
        end
        map[index] = string.format(
            "pack=%s | path=%s | type=%s | via=%s | count=%s | methods=%s | fields=%s",
            tostring(item.address or "nil"),
            tostring(item.path or "nil"),
            tostring(item.type_name or "unknown"),
            tostring(item.target_reason or "unknown"),
            tostring(item.count or 0),
            table.concat(method_names, ","),
            table.concat(field_parts, "; ")
        )
    end
    return map
end

local function action_research_observed_request_actions_map(runtime)
    local data = runtime.action_research_data
    if data == nil then
        return {}
    end

    local map = {}
    local index = 0
    local targets = { "player", "main_pawn" }

    for _, target in ipairs(targets) do
        local items = {}
        for _, item in pairs((data.observed_request_actions or {})[target] or {}) do
            table.insert(items, item)
        end

        table.sort(items, function(left, right)
            if (left.job or -1) ~= (right.job or -1) then
                return (left.job or -1) < (right.job or -1)
            end
            if tostring(left.action or "") ~= tostring(right.action or "") then
                return tostring(left.action or "") < tostring(right.action or "")
            end
            return (left.count or 0) > (right.count or 0)
        end)

        for _, item in ipairs(items) do
            index = index + 1
            if index > 32 then
                return map
            end

            local priorities = {}
            for priority in pairs(item.priorities or {}) do
                table.insert(priorities, tostring(priority))
            end
            table.sort(priorities)

            map[index] = string.format(
                "target=%s job=%s action=%s count=%s priorities=%s first_nodes=%s",
                tostring(item.target),
                tostring(item.job),
                tostring(item.action),
                tostring(item.count or 0),
                table.concat(priorities, ","),
                tostring(item.first_nodes or "nil")
            )
        end
    end

    return map
end

local function action_research_observed_decision_probes_map(runtime)
    local data = runtime.action_research_data
    if data == nil then
        return {}
    end

    local map = {}
    local items = {}
    for _, item in pairs(data.observed_decision_probes or {}) do
        table.insert(items, item)
    end

    table.sort(items, function(left, right)
        if (left.count or 0) ~= (right.count or 0) then
            return (left.count or 0) > (right.count or 0)
        end
        return tostring(left.action or "") < tostring(right.action or "")
    end)

    for index, item in ipairs(items) do
        if index > 16 then
            break
        end
        map[index] = string.format(
            "action=%s count=%s nodes=%s decision=%s target=%s pack=%s actions=%s,%s",
            tostring(item.action or "nil"),
            tostring(item.count or 0),
            tostring(item.nodes or "nil|nil"),
            tostring(item.decision or "nil"),
            tostring(item.decision_target or "nil"),
            tostring(item.pack_path or "nil"),
            tostring((item.current_actions or {})[1] or "nil"),
            tostring((item.current_actions or {})[2] or "nil")
        )
    end

    return map
end

local function action_research_observed_decision_snapshots_map(runtime)
    local data = runtime.action_research_data
    if data == nil then
        return {}
    end

    local map = {}
    local index = 0
    local targets = { "player", "main_pawn" }

    for _, target in ipairs(targets) do
        local items = {}
        for _, item in pairs((data.observed_decision_snapshots or {})[target] or {}) do
            table.insert(items, item)
        end

        table.sort(items, function(left, right)
            if (left.count or 0) ~= (right.count or 0) then
                return (left.count or 0) > (right.count or 0)
            end
            return tostring(left.action or "") < tostring(right.action or "")
        end)

        for _, item in ipairs(items) do
            index = index + 1
            if index > 16 then
                return map
            end

            local field_parts = {}
            for _, field in ipairs(item.fields or {}) do
                table.insert(field_parts, string.format("%s=%s", tostring(field.name), tostring(field.value)))
            end

            map[index] = string.format(
                "target=%s job=%s action=%s count=%s nodes=%s decision=%s target_obj=%s pack=%s fields=%s",
                tostring(item.target or "unknown"),
                tostring(item.job or "nil"),
                tostring(item.action or "nil"),
                tostring(item.count or 0),
                tostring(item.nodes or "nil|nil"),
                tostring(item.decision or "nil"),
                tostring(item.decision_target or "nil"),
                tostring(item.pack_path or "nil"),
                table.concat(field_parts, "; ")
            )
        end
    end

    return map
end

local function action_research_observed_ai_decision_snapshots_map(runtime)
    local data = runtime.action_research_data
    if data == nil then
        return {}
    end

    local map = {}
    local items = {}
    for _, item in pairs(data.observed_ai_decision_snapshots or {}) do
        table.insert(items, item)
    end

    table.sort(items, function(left, right)
        if (left.count or 0) ~= (right.count or 0) then
            return (left.count or 0) > (right.count or 0)
        end
        return tostring(left.action or "") < tostring(right.action or "")
    end)

    for index, item in ipairs(items) do
        if index > 16 then
            break
        end

        local fields_text = tostring(item.fields_text or "")
        if fields_text == "" then
            local field_parts = {}
            for _, field in ipairs(item.fields or {}) do
                table.insert(field_parts, string.format("%s=%s", tostring(field.name), tostring(field.value)))
            end
            fields_text = table.concat(field_parts, "; ")
        end

        map[index] = string.format(
            "job=%s action=%s count=%s decision=%s fields=%s",
            tostring(item.job or "nil"),
            tostring(item.action or "nil"),
            tostring(item.count or 0),
            tostring(item.decision or "nil"),
            tostring(fields_text)
        )
    end

    return map
end

local function action_research_observed_ai_target_snapshots_map(runtime)
    local data = runtime.action_research_data
    if data == nil then
        return {}
    end

    local map = {}
    local items = {}
    for _, item in pairs(data.observed_ai_target_snapshots or {}) do
        table.insert(items, item)
    end

    table.sort(items, function(left, right)
        if (left.count or 0) ~= (right.count or 0) then
            return (left.count or 0) > (right.count or 0)
        end
        return tostring(left.action or "") < tostring(right.action or "")
    end)

    for index, item in ipairs(items) do
        if index > 16 then
            break
        end

        map[index] = string.format(
            "job=%s action=%s count=%s target=%s fields=%s",
            tostring(item.job or "nil"),
            tostring(item.action or "nil"),
            tostring(item.count or 0),
            tostring(item.target or "nil"),
            tostring(item.fields_text or "")
        )
    end

    return map
end

local function action_research_observed_decision_actionpack_snapshots_map(runtime)
    local data = runtime.action_research_data
    if data == nil then
        return {}
    end

    local map = {}
    local items = {}
    for _, item in pairs(data.observed_decision_actionpack_snapshots or {}) do
        table.insert(items, item)
    end

    table.sort(items, function(left, right)
        if (left.count or 0) ~= (right.count or 0) then
            return (left.count or 0) > (right.count or 0)
        end
        return tostring(left.action or "") < tostring(right.action or "")
    end)

    for index, item in ipairs(items) do
        if index > 16 then
            break
        end

        map[index] = string.format(
            "job=%s action=%s count=%s pack=%s fields=%s",
            tostring(item.job or "nil"),
            tostring(item.action or "nil"),
            tostring(item.count or 0),
            tostring(item.pack or "nil"),
            tostring(item.fields_text or "")
        )
    end

    return map
end

local function action_research_observed_decision_producer_snapshots_map(runtime)
    local data = runtime.action_research_data
    if data == nil then
        return {}
    end

    local map = {}
    local items = {}
    for _, item in pairs(data.observed_decision_producer_snapshots or {}) do
        table.insert(items, item)
    end

    table.sort(items, function(left, right)
        if (left.count or 0) ~= (right.count or 0) then
            return (left.count or 0) > (right.count or 0)
        end
        return tostring(left.action or "") < tostring(right.action or "")
    end)

    for index, item in ipairs(items) do
        if index > 16 then
            break
        end

        map[index] = string.format(
            "job=%s action=%s count=%s fields=%s",
            tostring(item.job or "nil"),
            tostring(item.action or "nil"),
            tostring(item.count or 0),
            tostring(item.fields_text or "")
        )
    end

    return map
end

local function action_research_registration_errors_map(runtime)
    local data = runtime.action_research_data
    if data == nil then
        return {}
    end

    local map = {}
    for index, item in ipairs(data.registration_errors or {}) do
        map[index] = tostring(item)
    end
    return map
end

local function vocation_research_map(runtime)
    local data = runtime.vocation_research_data
    if data == nil then
        return {}
    end

    local summary = data.summary or {}
    return {
        hooks_installed = tostring(data.hooks_installed),
        installed_methods = table.concat(data.installed_methods or {}, ", "),
        registration_error_count = tostring(#(data.registration_errors or {})),
        recent_event_count = tostring(#(data.recent_events or {})),
        purchase_events = tostring(data.stats and data.stats.purchase_events or 0),
        skill_set_events = tostring(data.stats and data.stats.skill_set_events or 0),
        player_job = tostring(summary.player_job or "nil"),
        player_job_level = tostring(summary.player_current_job_level or "nil"),
        player_access_current_job = tostring(summary.player_access_current_job),
        player_current_job_skills = tostring(summary.player_current_job_skills or ""),
        player_current_job_skill_levels = tostring(summary.player_current_job_skill_levels or ""),
        player_has_current_job_weapon = tostring(summary.player_has_current_job_weapon),
        player_purchase_like_ready = tostring(summary.player_purchase_like_ready),
        player_runtime_ready = tostring(summary.player_runtime_ready),
        purchase_policy = tostring(summary.purchase_policy or "per_character_required"),
        main_pawn_job = tostring(summary.main_pawn_job or "nil"),
        main_pawn_job_level = tostring(summary.main_pawn_current_job_level or "nil"),
        main_pawn_access_current_job = tostring(summary.main_pawn_access_current_job),
        main_pawn_current_job_skills = tostring(summary.main_pawn_current_job_skills or ""),
        main_pawn_current_job_skill_levels = tostring(summary.main_pawn_current_job_skill_levels or ""),
        main_pawn_has_current_job_weapon = tostring(summary.main_pawn_has_current_job_weapon),
        main_pawn_purchase_like_ready = tostring(summary.main_pawn_purchase_like_ready),
        main_pawn_runtime_ready = tostring(summary.main_pawn_runtime_ready),
        access_gap = tostring(summary.access_gap or "unresolved"),
        purchase_gap = tostring(summary.purchase_gap or "unresolved"),
        current_job_gap = tostring(summary.current_job_gap or "unresolved"),
    }
end

local function vocation_research_recent_events_map(runtime)
    local data = runtime.vocation_research_data
    if data == nil then
        return {}
    end

    local map = {}
    for index, item in ipairs(data.recent_events or {}) do
        map[index] = string.format(
            "%s | %s | job=%s | skill=%s | slot=%s | current_job=%s | weapon=%s",
            tostring(item.target),
            tostring(item.method),
            tostring(item.job_id),
            tostring(item.skill_id),
            tostring(item.slot_index),
            tostring(item.current_job),
            tostring(item.weapon_job)
        )
    end
    return map
end

local function vocation_research_registration_errors_map(runtime)
    local data = runtime.vocation_research_data
    if data == nil then
        return {}
    end

    local map = {}
    for index, item in ipairs(data.registration_errors or {}) do
        map[index] = tostring(item)
    end
    return map
end

local function combat_research_recent_events_map(runtime)
    local data = runtime.combat_research_data
    if data == nil then
        return {}
    end

    local map = {}
    for index, item in ipairs(data.recent_events or {}) do
        map[index] = string.format(
            "%s | %s | %s | skill=%s | result=%s | code=%s | job=%s | weapon=%s",
            tostring(item.target),
            tostring(item.hook_type),
            tostring(item.method),
            tostring(item.skill_id),
            tostring(item.result),
            tostring(item.result_hex or item.result_code),
            tostring(item.current_job),
            tostring(item.weapon_job)
        )
    end
    return map
end

local function combat_research_registration_errors_map(runtime)
    local data = runtime.combat_research_data
    if data == nil then
        return {}
    end

    local map = {}
    for index, item in ipairs(data.registration_errors or {}) do
        map[index] = tostring(item)
    end
    return map
end

local function record_equipment_domain(runtime)
    if not config.debug.session_domain_equipment then
        return
    end

    local session = get_session_state(runtime)
    local main_pawn_data = runtime.main_pawn_data
    local payload = {
        main_pawn_job = main_pawn_data and (main_pawn_data.current_job or main_pawn_data.job) or nil,
        main_pawn_weapon_job = main_pawn_data and main_pawn_data.weapon_job or nil,
        main_pawn_status_condition_ctrl = main_pawn_data and util.describe_obj(main_pawn_data.status_condition_ctrl) or nil,
        pawn_health_item_controller = main_pawn_data and main_pawn_data.pawn_ai_fields and util.describe_obj(main_pawn_data.pawn_ai_fields.pawn_health_item_controller) or nil,
        ai_stamina_manager = main_pawn_data and main_pawn_data.pawn_ai_fields and util.describe_obj(main_pawn_data.pawn_ai_fields.ai_stamina_manager) or nil,
    }

    local signature = json_encode_simple(payload)
    if signature == session.last_equipment_signature then
        return
    end
    session.last_equipment_signature = signature

    queue_session_event(
        runtime,
        "equip",
        "equipment_context_changed",
        payload,
        string.format(
            "main_pawn_job=%s weapon_job=%s",
            tostring(payload.main_pawn_job),
            tostring(payload.main_pawn_weapon_job)
        )
    )
end

local function record_inventory_domain(runtime, discovery)
    if not config.debug.session_domain_inventory then
        return
    end

    local session = get_session_state(runtime)
    local item_manager = discovery and discovery.managers and discovery.managers.ItemManager or nil
    local payload = {
        item_manager = util.describe_obj(item_manager),
        item_manager_fields = summarize_field_subset(
            item_manager and util.get_fields_snapshot(item_manager, 16) or nil,
            {
                "<ItemList>k__BackingField",
                "<Storage>k__BackingField",
                "<Warehouse>k__BackingField",
                "ItemList",
                "Storage",
                "Warehouse",
            },
            6
        ),
    }

    local signature = json_encode_simple(payload)
    if signature == session.last_inventory_signature then
        return
    end
    session.last_inventory_signature = signature

    queue_session_event(
        runtime,
        "equip",
        "inventory_context_changed",
        payload,
        string.format("item_manager=%s", tostring(payload.item_manager))
    )
end

queue_first_seen_event = function(runtime, key, category, name, payload, line)
    local session = get_session_state(runtime)
    if session.first_seen[key] then
        return
    end

    session.first_seen[key] = true
    queue_session_event(runtime, category, name, payload, line)
end

local function record_weapon_domain(runtime, discovery)
    if not config.debug.session_domain_weapon then
        return
    end

    local session = get_session_state(runtime)
    local progression = runtime.progression_gate_data
    local main_pawn_data = runtime.main_pawn_data
    local npc_weapons = {}

    for _, entry in ipairs(discovery.party or {}) do
        local payload = extract_actor_vocation_payload(entry)
        table.insert(npc_weapons, {
            name = payload.name,
            chara_id = payload.chara_id,
            current_job = payload.current_job,
            job = payload.job,
            weapon_job = payload.weapon_job,
        })
        if #npc_weapons >= 6 then
            break
        end
    end

    local payload = {
        player_job = progression and progression.current_job or nil,
        main_pawn_job = main_pawn_data and (main_pawn_data.current_job or main_pawn_data.job) or nil,
        main_pawn_weapon_job = main_pawn_data and main_pawn_data.weapon_job or nil,
        main_pawn_weapon_matches_job = main_pawn_data ~= nil
            and tostring(main_pawn_data.weapon_job) == tostring(main_pawn_data.current_job or main_pawn_data.job)
            or nil,
        npc_weapon_jobs = npc_weapons,
    }

    local signature = json_encode_simple(payload)
    if signature == session.last_weapon_signature then
        return
    end
    session.last_weapon_signature = signature

    queue_session_event(
        runtime,
        "equip",
        "weapon_compatibility_context_changed",
        payload,
        string.format(
            "player_job=%s main_pawn_job=%s weapon_job=%s match=%s",
            tostring(payload.player_job),
            tostring(payload.main_pawn_job),
            tostring(payload.main_pawn_weapon_job),
            tostring(payload.main_pawn_weapon_matches_job)
        )
    )
end

local function record_reference_domain(runtime, discovery)
    if not config.debug.session_domain_reference then
        return
    end

    local progression = runtime.progression_gate_data
    local main_pawn_data = runtime.main_pawn_data

    if progression ~= nil then
        queue_first_seen_event(
            runtime,
            "player_job:" .. tostring(progression.current_job),
            "reference",
            "player_job_first_seen",
            {
                current_job = progression.current_job,
                qualified_job_bits = progression.qualified_job_bits,
                viewed_new_job_bits = progression.viewed_new_job_bits,
                changed_job_bits = progression.changed_job_bits,
            },
            string.format("player_job=%s", tostring(progression.current_job))
        )
    end

    if main_pawn_data ~= nil then
        local current_job = main_pawn_data.current_job or main_pawn_data.job
        queue_first_seen_event(
            runtime,
            "main_pawn_source:" .. tostring(discovery.main_pawn and discovery.main_pawn.source or "nil"),
            "reference",
            "main_pawn_source_first_seen",
            {
                source = discovery.main_pawn and discovery.main_pawn.source or nil,
                character_source = discovery.main_pawn and discovery.main_pawn.character_source or nil,
                candidate_count = discovery.main_pawn and discovery.main_pawn.candidate_count or 0,
                errors = discovery.main_pawn and discovery.main_pawn.errors or {},
                candidate_paths = compact_candidate_paths(discovery.main_pawn and discovery.main_pawn.candidate_paths or {}, 8),
            },
            string.format(
                "source=%s character_source=%s",
                tostring(discovery.main_pawn and discovery.main_pawn.source or "nil"),
                tostring(discovery.main_pawn and discovery.main_pawn.character_source or "nil")
            )
        )
        queue_first_seen_event(
            runtime,
            "main_pawn_job:" .. tostring(current_job),
            "reference",
            "main_pawn_job_first_seen",
            {
                chara_id = main_pawn_data.chara_id,
                current_job = current_job,
                weapon_job = main_pawn_data.weapon_job,
                name = main_pawn_data.name,
            },
            string.format("main_pawn_job=%s weapon_job=%s", tostring(current_job), tostring(main_pawn_data.weapon_job))
        )
        queue_first_seen_event(
            runtime,
            "main_pawn_acquired:" .. tostring(main_pawn_data.chara_id),
            "reference",
            "main_pawn_acquired_first_seen",
            {
                chara_id = main_pawn_data.chara_id,
                name = main_pawn_data.name,
                current_job = current_job,
                weapon_job = main_pawn_data.weapon_job,
                job_context = util.describe_obj(main_pawn_data.job_context),
                skill_context = util.describe_obj(main_pawn_data.skill_context),
                human = util.describe_obj(main_pawn_data.human),
                runtime_character = util.describe_obj(main_pawn_data.runtime_character),
                object = util.describe_obj(main_pawn_data.object),
                job_context_fields = compact_named_fields(
                    main_pawn_data.job_context_fields,
                    {"CurrentJob", "QualifiedJobBits", "ViewedNewJobBits", "ChangedJobBits"}
                ),
                skill_context_fields = compact_named_fields(
                    main_pawn_data.skill_context_fields,
                    {"CustomSkillSet", "LearnedCustomSkillBits", "SkillSet", "WeaponSkillSet"}
                ),
            },
            string.format("main_pawn_acquired=%s job=%s weapon_job=%s", tostring(main_pawn_data.name), tostring(current_job), tostring(main_pawn_data.weapon_job))
        )
        if main_pawn_data.job_context ~= nil then
            queue_first_seen_event(
                runtime,
                "main_pawn_job_context:" .. tostring(main_pawn_data.chara_id),
                "reference",
                "main_pawn_job_context_first_seen",
                {
                    chara_id = main_pawn_data.chara_id,
                    name = main_pawn_data.name,
                    job_context = util.describe_obj(main_pawn_data.job_context),
                    fields = compact_named_fields(
                        main_pawn_data.job_context_fields,
                        {"CurrentJob", "QualifiedJobBits", "ViewedNewJobBits", "ChangedJobBits"}
                    ),
                },
                string.format(
                    "main_pawn_job_context=%s current_job=%s",
                    tostring(util.describe_obj(main_pawn_data.job_context)),
                    tostring(current_job)
                )
            )
        end
        if main_pawn_data.skill_context ~= nil then
            queue_first_seen_event(
                runtime,
                "main_pawn_skill_context:" .. tostring(main_pawn_data.chara_id),
                "reference",
                "main_pawn_skill_context_first_seen",
                {
                    chara_id = main_pawn_data.chara_id,
                    name = main_pawn_data.name,
                    skill_context = util.describe_obj(main_pawn_data.skill_context),
                    fields = compact_named_fields(
                        main_pawn_data.skill_context_fields,
                        {"CustomSkillSet", "LearnedCustomSkillBits", "SkillSet", "WeaponSkillSet"}
                    ),
                },
                string.format("main_pawn_skill_context=%s", tostring(util.describe_obj(main_pawn_data.skill_context)))
            )
        end
    end

    for _, entry in ipairs(discovery.party or {}) do
        local payload = extract_actor_vocation_payload(entry)
        local key = string.format(
            "npc_job:%s:%s:%s",
            tostring(payload.chara_id),
            tostring(payload.current_job),
            tostring(payload.weapon_job)
        )
        queue_first_seen_event(
            runtime,
            key,
            "reference",
            "npc_job_first_seen",
            payload,
            string.format(
                "name=%s current_job=%s weapon_job=%s",
                tostring(payload.name),
                tostring(payload.current_job),
                tostring(payload.weapon_job)
            )
        )
    end

    for _, key in ipairs(hybrid_jobs.keys) do
        local bits = progression and progression.hybrid_gate_status and progression.hybrid_gate_status[key] or nil
        if bits ~= nil then
            queue_first_seen_event(
                runtime,
                "hybrid_bits:" .. key,
                "reference",
                "hybrid_job_bits_first_seen",
                {
                    key = key,
                    bits = bits,
                },
                string.format("hybrid=%s", tostring(key))
            )
        end
    end
end

local function looks_like_quest_context(value)
    if type(value) ~= "string" then
        return false
    end

    local lower = string.lower(value)
    return string.find(lower, "quest", 1, true) ~= nil
        or string.find(lower, "mission", 1, true) ~= nil
        or string.find(lower, "ui05", 1, true) ~= nil
end

local function looks_like_dialogue_context(value)
    if type(value) ~= "string" then
        return false
    end

    local lower = string.lower(value)
    return string.find(lower, "talk", 1, true) ~= nil
        or string.find(lower, "dialog", 1, true) ~= nil
        or string.find(lower, "conversation", 1, true) ~= nil
        or string.find(lower, "npc", 1, true) ~= nil
end

local function build_context_marker_matches(guild_flow, matcher)
    local candidates = {
        {source = "current_state", value = guild_flow and tostring(guild_flow.current_state or "") or ""},
        {source = "current_menu", value = guild_flow and tostring(guild_flow.current_menu or "") or ""},
        {source = "current_window", value = guild_flow and tostring(guild_flow.current_window or "") or ""},
        {source = "focused_window", value = guild_flow and tostring(guild_flow.focused_window or "") or ""},
        {source = "active_ui_type", value = guild_flow and tostring(guild_flow.active_ui_type or "") or ""},
        {source = "current_scene_name", value = guild_flow and tostring(guild_flow.current_scene_name or "") or ""},
    }

    local matched = {}
    local labels = {}
    for _, candidate in ipairs(candidates) do
        if matcher(candidate.value) then
            table.insert(matched, {
                source = candidate.source,
                value = candidate.value,
            })
            table.insert(labels, string.format("%s=%s", candidate.source, candidate.value))
        end
    end

    return matched, labels
end

local function summarize_party_roles(runtime, limit)
    local result = {}
    local main_pawn_data = runtime.main_pawn_data
    for _, item in ipairs(main_pawn_data and main_pawn_data.party_snapshot or {}) do
        table.insert(result, {
            role = item.role,
            name = item.name,
            description = item.description,
        })
        if #result >= (limit or 4) then
            break
        end
    end
    return result
end

local function resolve_character_from_party_object(actor)
    if not util.is_valid_obj(actor) then
        return nil
    end

    if util.is_a(actor, "app.Character") then
        return actor
    end

    local direct = util.safe_method(actor, "get_Character")
    if util.is_valid_obj(direct) and util.is_a(direct, "app.Character") then
        return direct
    end

    local game_object = util.safe_method(actor, "get_GameObject")
    if util.is_valid_obj(game_object) then
        local component = util.safe_method(game_object, "getComponent(System.Type)", sdk.typeof("app.Character"))
        if util.is_valid_obj(component) and util.is_a(component, "app.Character") then
            return component
        end
    end

    return nil
end

extract_actor_vocation_payload = function(entry)
    local actor = entry and entry.object or nil
    local runtime_character = resolve_character_from_party_object(actor)
    local human = runtime_character and util.safe_method(runtime_character, "get_Human") or nil
    local job_context = human and util.safe_field(human, "<JobContext>k__BackingField") or nil
    local skill_context = human and util.safe_field(human, "<SkillContext>k__BackingField") or nil

    return {
        name = entry and entry.name or nil,
        description = entry and entry.description or nil,
        object = util.describe_obj(actor),
        runtime_character = util.describe_obj(runtime_character),
        chara_id = runtime_character and util.safe_method(runtime_character, "get_CharaID") or nil,
        job = runtime_character and util.safe_field(runtime_character, "Job") or nil,
        weapon_job = runtime_character and util.safe_field(runtime_character, "WeaponJob") or nil,
        current_job = job_context and util.safe_field(job_context, "CurrentJob") or nil,
        human = util.describe_obj(human),
        job_context = util.describe_obj(job_context),
        skill_context = util.describe_obj(skill_context),
        job_context_fields = summarize_field_subset(
            job_context and util.get_fields_snapshot(job_context, 12) or nil,
            {"CurrentJob", "QualifiedJobBits", "ChangedJobBits", "ViewedNewJobBits"},
            4
        ),
        skill_context_fields = summarize_field_subset(
            skill_context and util.get_fields_snapshot(skill_context, 12) or nil,
            {"CustomSkillSet", "LearnedCustomSkillBits", "SkillSet", "WeaponSkillSet"},
            4
        ),
    }
end

local function record_quest_domain(runtime)
    if not config.debug.session_domain_quest then
        return
    end

    local session = get_session_state(runtime)
    local guild_flow = runtime.guild_flow_research_data
    local matched, labels = build_context_marker_matches(guild_flow, looks_like_quest_context)
    local progression = runtime.progression_gate_data
    local signature = table.concat(labels, "|")
    if signature == "" or signature == session.last_quest_signature then
        return
    end
    session.last_quest_signature = signature

    queue_session_event(
        runtime,
        "quest",
        "quest_ui_context_seen",
        {
            markers = matched,
            current_scene_name = guild_flow and guild_flow.current_scene_name or nil,
            current_state = guild_flow and guild_flow.current_state or nil,
            current_window = guild_flow and guild_flow.current_window or nil,
            current_menu = guild_flow and guild_flow.current_menu or nil,
            focused_window = guild_flow and guild_flow.focused_window or nil,
            active_ui_type = guild_flow and guild_flow.active_ui_type or nil,
            player_job = progression and progression.current_job or nil,
            qualified_job_bits = progression and progression.qualified_job_bits or nil,
            viewed_new_job_bits = progression and progression.viewed_new_job_bits or nil,
            changed_job_bits = progression and progression.changed_job_bits or nil,
            party_roles = summarize_party_roles(runtime, 4),
        },
        string.format("markers=%s", table.concat(labels, " | "))
    )
end

local function record_dialogue_domain(runtime, discovery)
    if not config.debug.session_domain_dialogue then
        return
    end

    local session = get_session_state(runtime)
    local guild_flow = runtime.guild_flow_research_data
    local matched, labels = build_context_marker_matches(guild_flow, looks_like_dialogue_context)
    local party_candidates = {}
    for _, entry in ipairs(discovery and discovery.party or {}) do
        table.insert(party_candidates, {
            name = entry.name,
            description = entry.description,
        })
        if #party_candidates >= 4 then
            break
        end
    end

    local signature = table.concat(labels, "|")
    if signature == "" or signature == session.last_dialogue_signature then
        return
    end
    session.last_dialogue_signature = signature

    queue_session_event(
        runtime,
        "dialogue",
        "dialogue_ui_context_seen",
        {
            markers = matched,
            current_scene_name = guild_flow and guild_flow.current_scene_name or nil,
            current_state = guild_flow and guild_flow.current_state or nil,
            current_window = guild_flow and guild_flow.current_window or nil,
            current_menu = guild_flow and guild_flow.current_menu or nil,
            focused_window = guild_flow and guild_flow.focused_window or nil,
            active_ui_type = guild_flow and guild_flow.active_ui_type or nil,
            nearby_party = party_candidates,
            party_roles = summarize_party_roles(runtime, 4),
        },
        string.format("markers=%s", table.concat(labels, " | "))
    )
end

local function record_talk_event_domain(runtime)
    if not config.debug.session_domain_dialogue then
        return
    end

    local session = get_session_state(runtime)
    local trace = runtime.talk_event_trace_data
    local last_entry = trace and trace.last_entry or nil
    if last_entry == nil then
        return
    end

    local payload = {
        event_count = trace.event_count or 0,
        hook_name = last_entry.hook_name,
        phase = last_entry.phase,
        event_id = last_entry.event_id,
        event_label = last_entry.event_label,
        event_kind = last_entry.event_kind,
        object = last_entry.object,
        speaker = last_entry.speaker,
        listener = last_entry.listener,
        main_pawn_matches_speaker = last_entry.main_pawn_matches_speaker,
        main_pawn_matches_listener = last_entry.main_pawn_matches_listener,
        player_matches_speaker = last_entry.player_matches_speaker,
        player_matches_listener = last_entry.player_matches_listener,
        quest_id = last_entry.quest_id,
        active_ui_type = last_entry.active_ui_type,
        current_scene_name = last_entry.current_scene_name,
        current_state = last_entry.current_state,
        current_window = last_entry.current_window,
        history = trace.history or {},
    }

    local signature = json_encode_simple(payload)
    if signature == session.last_talk_event_signature then
        return
    end
    session.last_talk_event_signature = signature

    queue_session_event(
        runtime,
        "dialogue",
        "talk_event_runtime_changed",
        payload,
        string.format(
            "hook=%s phase=%s event_id=%s label=%s kind=%s",
            tostring(payload.hook_name),
            tostring(payload.phase),
            tostring(payload.event_id),
            tostring(payload.event_label),
            tostring(payload.event_kind)
        )
    )

    if payload.event_id ~= nil then
        queue_first_seen_event(
            runtime,
            "talk_event_id:" .. tostring(payload.event_id),
            "reference",
            "talk_event_id_first_seen",
            {
                event_id = payload.event_id,
                event_label = payload.event_label,
                event_kind = payload.event_kind,
                hook_name = payload.hook_name,
                speaker = payload.speaker,
                listener = payload.listener,
            },
            string.format("event_id=%s label=%s hook=%s", tostring(payload.event_id), tostring(payload.event_label), tostring(payload.hook_name))
        )
    end
end

local function record_prototype_domain(runtime)
    if not config.debug.session_domain_prototype then
        return
    end

    local session = get_session_state(runtime)
    local prototype = runtime.hybrid_unlock_prototype_data
    if prototype == nil then
        return
    end

    local signature = table.concat({
        tostring(prototype.prototype_mode),
        tostring(prototype.reason),
        tostring(prototype.request_reason),
        tostring(prototype.qualification_reason),
        tostring(prototype.current_main_pawn_job),
        tostring(prototype.target_job),
    }, "|")
    if signature == session.last_prototype_signature then
        return
    end
    session.last_prototype_signature = signature

    local payload = {
        prototype_mode = prototype.prototype_mode,
        activation_mode = prototype.activation_mode,
        reason = prototype.reason,
        request_reason = prototype.request_reason,
        qualification_reason = prototype.qualification_reason,
        current_player_job = prototype.current_player_job,
        current_main_pawn_job = prototype.current_main_pawn_job,
        target_job = prototype.target_job,
        target_name = prototype.supported_target_name,
    }

    queue_session_event(
        runtime,
        "prototype",
        "state_changed",
        payload,
        string.format(
            "mode=%s reason=%s main_pawn_job=%s target=%s",
            tostring(payload.prototype_mode),
            tostring(payload.reason),
            tostring(payload.current_main_pawn_job),
            tostring(payload.target_name)
        )
    )
end

local function record_npc_domain(runtime, discovery)
    if not config.debug.session_domain_npc then
        return
    end

    local session = get_session_state(runtime)
    for _, entry in ipairs(discovery.party or {}) do
        local key = tostring(entry.name) .. "|" .. tostring(util.get_address(entry.object) or "nil")
        local payload = extract_actor_vocation_payload(entry)
        local signature = json_encode_simple({
            chara_id = payload.chara_id,
            job = payload.job,
            weapon_job = payload.weapon_job,
            current_job = payload.current_job,
            runtime_character = payload.runtime_character,
        })

        if not session.npc_seen[key] then
            session.npc_seen[key] = true
            queue_session_event(
                runtime,
                "npc",
                "party_member_seen",
                payload,
                string.format("name=%s description=%s", tostring(entry.name), tostring(entry.description))
            )
        end

        if session.npc_vocation_signatures[key] ~= signature then
            session.npc_vocation_signatures[key] = signature
            queue_session_event(
                runtime,
                "npc",
                "npc_vocation_reference_changed",
                payload,
                string.format(
                    "name=%s job=%s weapon_job=%s current_job=%s",
                    tostring(payload.name),
                    tostring(payload.job),
                    tostring(payload.weapon_job),
                    tostring(payload.current_job)
                )
            )
        end
    end
end

local function record_session_domains(runtime, discovery)
    if not config.debug.session_logging_enabled then
        return
    end

    local session = get_session_state(runtime)
    if session.last_domain_sync_time == runtime.game_time then
        return
    end
    session.last_domain_sync_time = runtime.game_time

    record_scene_domain(runtime)
    record_character_domain(runtime)
    record_main_pawn_resolution_domain(runtime, discovery)
    record_main_pawn_baseline_domain(runtime)
    record_player_main_pawn_alignment_domain(runtime)
    record_party_snapshot_domain(runtime, discovery)
    record_character_type_domain(runtime)
    record_progression_domain(runtime)
    record_job_definition_domain(runtime)
    record_skill_domain(runtime)
    record_equipment_domain(runtime)
    record_inventory_domain(runtime, discovery)
    record_weapon_domain(runtime, discovery)
    record_quest_domain(runtime)
    record_dialogue_domain(runtime, discovery)
    record_talk_event_domain(runtime)
    record_guild_domain(runtime)
    record_prototype_domain(runtime)
    record_npc_domain(runtime, discovery)
    record_reference_domain(runtime, discovery)
    flush_session_logs(runtime, "late_update", false)
end

local function write_with_fallback(text)
    local last_error = "open_failed"

    for _, path in ipairs(candidate_log_paths()) do
        local ok, err = append_file(path, text)
        if ok then
            update_file_status({
                attempted = true,
                ok = true,
                path = path,
                reason = "written",
                gate = "written",
                last_success_path = path,
                last_success_reason = "written",
            })
            return true
        end

        last_error = err or last_error
    end

    update_file_status({
        attempted = true,
        ok = false,
        path = nil,
        reason = tostring(last_error),
        gate = tostring(last_error),
    })
    print(prefix("WARN") .. "Failed to write discovery log file: " .. tostring(last_error))
    return false
end

local function write_section(lines, title, values)
    if values == nil then
        return
    end

    table.insert(lines, "[" .. title .. "]")

    local keys = {}
    for key, _ in pairs(values) do
        table.insert(keys, key)
    end
    table.sort(keys)

    for _, key in ipairs(keys) do
        table.insert(lines, string.format("%s=%s", tostring(key), util.describe_obj(values[key])))
    end
end

local function candidate_paths_map(discovery)
    local map = {}
    for index, entry in ipairs(discovery.main_pawn.candidate_paths or {}) do
        map[index] = string.format("%s => %s", tostring(entry.source), tostring(entry.type_name or entry.result))
    end
    return map
end

local function party_snapshot_map(data)
    local map = {}
    for _, entry in ipairs(data.party_snapshot or {}) do
        map[entry.index] = string.format(
            "%s | %s | %s",
            tostring(entry.role),
            tostring(entry.name),
            tostring(entry.description)
        )
    end
    return map
end

local function progression_gate_map(runtime)
    local data = runtime.progression_gate_data
    if data == nil or data.hybrid_gate_status == nil then
        return {}
    end

    local map = {
        player = util.describe_obj(data.player),
        player_name = tostring(data.name),
        job_context_source = tostring(data.job_context_source),
        skill_context_source = tostring(data.skill_context_source),
        current_job = tostring(data.current_job),
        qualified_job_bits = tostring(data.qualified_job_bits),
        viewed_new_job_bits = tostring(data.viewed_new_job_bits),
        changed_job_bits = tostring(data.changed_job_bits),
    }

    for label, status in pairs(data.hybrid_gate_status) do
        map[label] = string.format(
            "qualified(job=%s,job-1=%s) viewed(job=%s,job-1=%s) changed(job=%s,job-1=%s)",
            tostring(status.qualified.bit_job_index),
            tostring(status.qualified.bit_job_minus_one),
            tostring(status.viewed.bit_job_index),
            tostring(status.viewed.bit_job_minus_one),
            tostring(status.changed.bit_job_index),
            tostring(status.changed.bit_job_minus_one)
        )
    end

    for label, status in pairs(data.direct_hybrid_status or {}) do
        map[label .. "_direct"] = string.format(
            "is_job_qualified=%s job_level=%s",
            tostring(status.is_job_qualified),
            tostring(status.job_level)
        )
    end

    return map
end

local function progression_context_fields_map(runtime)
    local data = runtime.progression_gate_data
    if data == nil then
        return {}, {}
    end

    return data.job_context_fields or {}, data.skill_context_fields or {}
end

local function progression_state_summary_map(runtime)
    local data = runtime.progression_state_data
    if data == nil or data.summary == nil then
        return {}
    end

    return {
        player_ready = tostring(data.summary.player_ready),
        main_pawn_ready = tostring(data.summary.main_pawn_ready),
        player_current_job = tostring(data.summary.player_current_job),
        main_pawn_current_job = tostring(data.summary.main_pawn_current_job),
        qualified_match = tostring(data.summary.qualified_match),
        viewed_match = tostring(data.summary.viewed_match),
        changed_match = tostring(data.summary.changed_match),
        dominant_gap = tostring(data.summary.dominant_gap),
        player_job_context_source = tostring(data.summary.player_job_context_source),
        main_pawn_job_context_source = tostring(data.summary.main_pawn_job_context_source),
        player_job_changer_source = tostring(data.summary.player_job_changer_source),
        main_pawn_job_changer_source = tostring(data.summary.main_pawn_job_changer_source),
    }
end

local function progression_actor_map(actor)
    if actor == nil then
        return {}
    end

    return {
        name = tostring(actor.name),
        chara_id = tostring(actor.chara_id),
        raw_job = tostring(actor.raw_job),
        current_job = tostring(actor.current_job),
        weapon_job = tostring(actor.weapon_job),
        job_context = util.describe_obj(actor.job_context),
        job_context_source = tostring(actor.job_context_source),
        job_changer = util.describe_obj(actor.job_changer),
        job_changer_source = tostring(actor.job_changer_source),
        skill_context = util.describe_obj(actor.skill_context),
        skill_context_source = tostring(actor.skill_context_source),
        qualified_job_bits = tostring(actor.qualified_job_bits),
        viewed_new_job_bits = tostring(actor.viewed_new_job_bits),
        changed_job_bits = tostring(actor.changed_job_bits),
    }
end

local function progression_alignment_map(runtime)
    local alignment = runtime.progression_state_data and runtime.progression_state_data.alignment or nil
    if alignment == nil then
        return {}
    end

    local map = {
        player_job = tostring(alignment.player_job),
        main_pawn_job = tostring(alignment.main_pawn_job),
        main_pawn_weapon_job = tostring(alignment.main_pawn_weapon_job),
        qualified_match = tostring(alignment.qualified_match),
        viewed_match = tostring(alignment.viewed_match),
        changed_match = tostring(alignment.changed_match),
        dominant_gap = tostring(alignment.dominant_gap),
        player_job_context = tostring(alignment.player_job_context),
        main_pawn_job_context = tostring(alignment.main_pawn_job_context),
        player_job_changer = tostring(alignment.player_job_changer),
        main_pawn_job_changer = tostring(alignment.main_pawn_job_changer),
    }

    for key, item in pairs(alignment.hybrid or {}) do
        map[key] = string.format(
            "qualified:%s/%s viewed:%s/%s changed:%s/%s direct:%s/%s",
            tostring(item.player_qualified),
            tostring(item.pawn_qualified),
            tostring(item.player_viewed),
            tostring(item.pawn_viewed),
            tostring(item.player_changed),
            tostring(item.pawn_changed),
            tostring(item.player_is_job_qualified),
            tostring(item.pawn_is_job_qualified)
        )
    end

    return map
end

local function progression_trace_map(runtime)
    local trace = runtime.progression_trace_data
    if trace == nil then
        return {}
    end

    return {
        hooks_installed = tostring(trace.hooks_installed),
        installed_count = tostring(trace.summary and trace.summary.installed_count or #(trace.installed_methods or {})),
        registration_error_count = tostring(trace.summary and trace.summary.registration_error_count or #(trace.registration_errors or {})),
        recent_event_count = tostring(trace.summary and trace.summary.recent_event_count or #(trace.recent_events or {})),
        qualification_checks = tostring(trace.stats and trace.stats.qualification_checks or 0),
        qualification_writes = tostring(trace.stats and trace.stats.qualification_writes or 0),
        job_change_requests = tostring(trace.stats and trace.stats.job_change_requests or 0),
        qualification_true = tostring(trace.stats and trace.stats.qualification_true or 0),
        qualification_false = tostring(trace.stats and trace.stats.qualification_false or 0),
        qualification_unknown = tostring(trace.stats and trace.stats.qualification_unknown or 0),
        qualification_probe_attempts = tostring(trace.stats and trace.stats.qualification_probe_attempts or 0),
        qualification_probe_applied = tostring(trace.stats and trace.stats.qualification_probe_applied or 0),
        qualification_probe_last_reason = tostring(trace.summary and trace.summary.mirror_probe and trace.summary.mirror_probe.last_reason or "not_attempted"),
        qualification_probe_last_target = tostring(trace.summary and trace.summary.mirror_probe and trace.summary.mirror_probe.last_target or "none"),
        qualification_probe_last_job_id = tostring(trace.summary and trace.summary.mirror_probe and trace.summary.mirror_probe.last_job_id or "nil"),
        qualification_probe_last_before_code = tostring(trace.summary and trace.summary.mirror_probe and trace.summary.mirror_probe.last_before_code or "nil"),
        qualification_probe_last_after_code = tostring(trace.summary and trace.summary.mirror_probe and trace.summary.mirror_probe.last_after_code or "nil"),
        installed_methods = table.concat(trace.installed_methods or {}, ", "),
    }
end

local function progression_probe_map(runtime)
    local probe = runtime.progression_probe_data
    if probe == nil then
        return {}
    end

    local summary = probe.summary or probe
    return {
        enabled = tostring(summary.enabled),
        attempts = tostring(summary.attempts or 0),
        applied = tostring(summary.applied or 0),
        last_reason = tostring(summary.last_reason or "not_attempted"),
        last_target = tostring(summary.last_target or "none"),
        last_job_id = tostring(summary.last_job_id or "nil"),
        last_fields = tostring(summary.last_fields or ""),
        last_before_qualified = tostring(summary.last_before_qualified or "nil"),
        last_after_qualified = tostring(summary.last_after_qualified or "nil"),
        last_before_viewed = tostring(summary.last_before_viewed or "nil"),
        last_after_viewed = tostring(summary.last_after_viewed or "nil"),
        last_before_changed = tostring(summary.last_before_changed or "nil"),
        last_after_changed = tostring(summary.last_after_changed or "nil"),
    }
end

local function progression_trace_recent_events_map(runtime)
    local trace = runtime.progression_trace_data
    if trace == nil then
        return {}
    end

    local map = {}
    for index, item in ipairs(trace.recent_events or {}) do
       map[index] = string.format(
           "%s | target=%s | job_id=%s | method=%s | result=%s | code=%s | hex=%s | direct_code=%s",
           tostring(item.name),
           tostring(item.target),
           tostring(item.job_id),
           tostring(item.method),
           tostring(item.result_bool ~= nil and item.result_bool or item.result),
           tostring(item.result_code),
           tostring(item.result_hex),
           tostring(item.snapshot_direct_code)
       )
    end
    return map
end

local function progression_trace_matrix_map(runtime)
    local trace = runtime.progression_trace_data
    if trace == nil then
        return {}
    end

    local map = {}
    for index, item in ipairs(trace.summary and trace.summary.latest_check_matrix or {}) do
        map[index] = item
    end
    return map
end

local function progression_trace_registration_errors_map(runtime)
    local trace = runtime.progression_trace_data
    if trace == nil then
        return {}
    end

    local map = {}
    for index, item in ipairs(trace.registration_errors or {}) do
        map[index] = tostring(item)
    end
    return map
end

local function job_gate_correlation_map(runtime)
    local data = runtime.job_gate_correlation_data
    if data == nil then
        return {}
    end

    local map = {
        dominant_gap = tostring(data.summary and data.summary.dominant_gap or "unresolved"),
        latest_talk_event_id = tostring(data.summary and data.summary.latest_talk_event_id or "nil"),
        latest_talk_event_label = tostring(data.summary and data.summary.latest_talk_event_label or "nil"),
        latest_job_info_hint = tostring(data.summary and data.summary.latest_job_info_hint or "unobserved"),
    }

    for key, item in pairs(data.by_job or {}) do
        map[key] = string.format(
            "qualified_match=%s viewed_match=%s changed_match=%s direct:%s/%s runtime=%s@%s player_code=%s pawn_code=%s player_direct=%s pawn_direct=%s",
            tostring(item.qualified_match),
            tostring(item.viewed_match),
            tostring(item.changed_match),
            tostring(item.player_is_job_qualified),
            tostring(item.pawn_is_job_qualified),
            tostring(item.latest_runtime_event),
            tostring(item.latest_runtime_target),
            tostring(item.player_runtime_hex or item.player_runtime_code),
            tostring(item.pawn_runtime_hex or item.pawn_runtime_code),
            tostring(item.player_runtime_snapshot_direct_hex or item.player_runtime_snapshot_direct_code),
            tostring(item.pawn_runtime_snapshot_direct_hex or item.pawn_runtime_snapshot_direct_code)
        )
    end

    return map
end

local function module_registry_map(runtime)
    local registry = runtime.module_registry
    if registry == nil then
        return {}
    end

    local map = {
        install_order = table.concat(registry.install_order or {}, ", "),
    }

    for key, entry in pairs(registry.entries or {}) do
        map[key] = string.format(
            "installed=%s install_count=%s update_count=%s last_error=%s deps=%s",
            tostring(entry.installed),
            tostring(entry.install_count),
            tostring(entry.update_count),
            tostring(entry.last_error),
            table.concat(entry.dependencies or {}, ", ")
        )
    end

    return map
end

local function progression_job_map(values, title)
    local lines = {}
    if values == nil then
        return lines
    end

    table.insert(lines, "[" .. title .. "]")

    local items = {}
    for key, item in pairs(values) do
        if item ~= nil then
            table.insert(items, { key = key, item = item })
        end
    end
    table.sort(items, function(left, right)
        local left_id = left.item and left.item.id or math.huge
        local right_id = right.item and right.item.id or math.huge
        if left_id == right_id then
            return tostring(left.key) < tostring(right.key)
        end
        return left_id < right_id
    end)

    for _, entry in ipairs(items) do
        local item = entry.item
        table.insert(lines, string.format(
            "%02d_%s=bit(job)=%s bit(job-1)=%s",
            item.id,
            tostring(entry.key),
            tostring(item.bit_job),
            tostring(item.bit_job_minus_one)
        ))
    end

    return lines
end

local function progression_direct_table(values, title)
    local lines = {}
    if values == nil then
        return lines
    end

    table.insert(lines, "[" .. title .. "]")

    local items = {}
    for key, item in pairs(values) do
        if item ~= nil then
            table.insert(items, { key = key, item = item })
        end
    end
    table.sort(items, function(left, right)
        local left_id = left.item and left.item.id or math.huge
        local right_id = right.item and right.item.id or math.huge
        if left_id == right_id then
            return tostring(left.key) < tostring(right.key)
        end
        return left_id < right_id
    end)

    for _, entry in ipairs(items) do
        local item = entry.item
        table.insert(lines, string.format(
            "%02d_%s=isJobQualified=%s jobLevel=%s",
            item.id,
            tostring(entry.key),
            tostring(item.is_job_qualified),
            tostring(item.job_level)
        ))
    end

    return lines
end

local function hybrid_unlock_research_map(runtime)
    local data = runtime.hybrid_unlock_research_data
    if data == nil then
        return {}
    end

    local map = {
        main_pawn_only_guard = tostring(data.main_pawn_only_guard),
        progression_source = tostring(data.progression_source),
        current_player_job = tostring(data.current_player_job),
        current_main_pawn_job = tostring(data.current_main_pawn_job),
    }

    for key, item in pairs(data.target_vocations or {}) do
        map[key] = string.format(
            "job_id=%s progression_allowed=%s unlock_layer_ready=%s",
            tostring(item.job_id),
            tostring(item.progression_allowed),
            tostring(item.unlock_layer_ready)
        )
    end

    return map
end

local function hybrid_unlock_prototype_map(runtime)
    local data = runtime.hybrid_unlock_prototype_data
    if data == nil then
        return {}
    end

    return {
        enabled = tostring(data.enabled),
        prototype_mode = tostring(data.prototype_mode),
        activation_mode = tostring(data.activation_mode),
        auto_apply_target_job = tostring(data.auto_apply_target_job),
        auto_qualify_target_job = tostring(data.auto_qualify_target_job),
        request_job_notice = tostring(data.request_job_notice),
        cleanup_equipment_after_apply = tostring(data.cleanup_equipment_after_apply),
        current_player_job = tostring(data.current_player_job),
        current_main_pawn_job = tostring(data.current_main_pawn_job),
        target_job = tostring(data.target_job),
        configured_target_job = tostring(data.configured_target_job),
        supported_target_name = tostring(data.supported_target_name),
        target_reason = tostring(data.target_reason),
        can_attempt = tostring(data.can_attempt),
        reason = tostring(data.reason),
        attempted = tostring(data.attempted),
        request_ok = tostring(data.request_ok),
        request_allowed = tostring(data.request_allowed),
        request_reason = tostring(data.request_reason),
        requested_job = tostring(data.requested_job),
        qualified_before = tostring(data.qualified_before),
        qualified_after = tostring(data.qualified_after),
        qualification_attempted = tostring(data.qualification_attempted),
        qualification_ok = tostring(data.qualification_ok),
        qualification_reason = tostring(data.qualification_reason),
        notice_attempted = tostring(data.notice_attempted),
        notice_ok = tostring(data.notice_ok),
        notice_reason = tostring(data.notice_reason),
        equipment_cleanup_attempted = tostring(data.equipment_cleanup_attempted),
        equipment_cleanup_ok = tostring(data.equipment_cleanup_ok),
        equipment_cleanup_reason = tostring(data.equipment_cleanup_reason),
        removed_equipped_items = tostring(data.removed_equipped_items),
        apply_equip_change_ok = tostring(data.apply_equip_change_ok),
        chara_id = tostring(data.chara_id),
        runtime_character = util.describe_obj(data.runtime_character),
        gui_manager = util.describe_obj(data.gui_manager),
        job_context = util.describe_obj(data.job_context),
        job_changer = util.describe_obj(data.job_changer),
    }
end

local function guild_flow_research_map(runtime)
    local data = runtime.guild_flow_research_data
    if data == nil then
        return {}
    end

    local map = {
        enabled = tostring(data.enabled),
        gui_manager = tostring(data.gui_manager),
        player_job = tostring(data.player_job),
        player_chara_id = tostring(data.player_chara_id),
        main_pawn_job = tostring(data.main_pawn_job),
        main_pawn_name = tostring(data.main_pawn_name),
        main_pawn_chara_id = tostring(data.main_pawn_chara_id),
        current_scene_name = tostring(data.current_scene_name),
        current_state = tostring(data.current_state),
        current_menu = tostring(data.current_menu),
        current_window = tostring(data.current_window),
        focused_window = tostring(data.focused_window),
        guild_ui_hint = tostring(data.guild_ui_hint),
        signature_changed = tostring(data.signature_changed),
        event_count = tostring(data.event_count),
        last_event = tostring(data.last_event_summary),
        registered_hooks = tostring(#(data.registered_hooks or {})),
        registration_errors = tostring(#(data.registration_errors or {})),
    }

    for key, value in pairs(data.method_results or {}) do
        map["method_" .. tostring(key)] = tostring(value)
    end

    for key, value in pairs(data.keyword_fields or {}) do
        map["field_" .. tostring(key)] = tostring(value)
    end

    return map
end

local function guild_flow_context_alignment_map(runtime)
    local data = runtime.guild_flow_research_data
    local alignment = data and data.context_alignment or nil
    if alignment == nil then
        return {}
    end

    return {
        player_chara_id = tostring(alignment.player_chara_id),
        main_pawn_chara_id = tostring(alignment.main_pawn_chara_id),
        player_job_context = tostring(alignment.player_job_context),
        main_pawn_job_context = tostring(alignment.main_pawn_job_context),
        player_current_job = tostring(alignment.player_current_job),
        main_pawn_current_job = tostring(alignment.main_pawn_current_job),
    }
end

local function guild_flow_trace_assessment_map(runtime)
    local data = runtime.guild_flow_research_data
    local assessment = data and data.trace_assessment or nil
    if assessment == nil then
        return {}
    end

    return {
        paired_trace_ready = tostring(assessment.paired_trace_ready),
        paired_ui_types = table.concat(assessment.paired_ui_types or {}, ","),
        player_only_ui_types = table.concat(assessment.player_only_ui_types or {}, ","),
        main_pawn_only_ui_types = table.concat(assessment.main_pawn_only_ui_types or {}, ","),
        unknown_ui_types = table.concat(assessment.unknown_ui_types or {}, ","),
        player_events = tostring(assessment.target_stats and assessment.target_stats.player or 0),
        main_pawn_events = tostring(assessment.target_stats and assessment.target_stats.main_pawn or 0),
        unknown_events = tostring(assessment.target_stats and assessment.target_stats.unknown or 0),
    }
end

local function guild_flow_active_ui_map(runtime)
    local data = runtime.guild_flow_research_data
    if data == nil then
        return {}
    end

    local map = {}
    for ui_type, item in pairs(data.active_ui or {}) do
        map[ui_type] = string.format(
            "method=%s phase=%s role=%s chara_id=%s chara_id_source=%s flow_id=%s arg=%s job_context_source=%s is_pawn=%s updated_at=%s",
            tostring(item.method),
            tostring(item.phase),
            tostring(item.target_role),
            tostring(item.chara_id),
            tostring(item.chara_id_source),
            tostring(item.flow_id),
            tostring(item.argument),
            tostring(item.job_context_source),
            tostring(item.is_pawn),
            tostring(item.updated_at)
        )
    end

    return map
end

local function guild_flow_recent_events_map(runtime)
    local data = runtime.guild_flow_research_data
    if data == nil then
        return {}
    end

    local map = {}
    for _, item in ipairs(data.recent_events_for_log or {}) do
        map[item.id] = string.format(
            "%s | %s | %s | chara_id=%s | role=%s | flow_id=%s | arg=%s | chara_src=%s | job_ctx_src=%s | is_pawn=%s",
            tostring(item.time),
            tostring(item.ui_type),
            tostring(item.method),
            tostring(item.chara_id),
            tostring(item.target_role),
            tostring(item.flow_id),
            tostring(item.argument),
            tostring(item.chara_id_source),
            tostring(item.job_context_source),
            tostring(item.is_pawn)
        )
    end

    return map
end

local function guild_flow_trace_summary_map(runtime)
    local data = runtime.guild_flow_research_data
    local assessment = data and data.trace_assessment or nil
    if assessment == nil then
        return {}
    end

    local map = {}
    for index, line in ipairs(assessment.summary_lines or {}) do
        map[index] = line
    end
    return map
end

local function guild_flow_unique_events_map(runtime)
    local data = runtime.guild_flow_research_data
    if data == nil then
        return {}
    end

    local map = {}
    for index, item in ipairs(data.unique_events_for_log or {}) do
        map[index] = string.format(
            "%s | %s | %s | phase=%s | target=%s | chara_id=%s | job=%s | flow_id=%s | is_pawn=%s | chara_src=%s | job_ctx_src=%s",
            tostring(item.time),
            tostring(item.ui_type),
            tostring(item.method),
            tostring(item.phase),
            tostring(item.resolved_target),
            tostring(item.chara_id),
            tostring(item.current_job),
            tostring(item.flow_id),
            tostring(item.is_pawn),
            tostring(item.chara_id_source),
            tostring(item.job_context_source)
        )
    end
    return map
end

local function guild_flow_unique_ui_observations_map(runtime)
    local data = runtime.guild_flow_research_data
    if data == nil then
        return {}
    end

    local map = {}
    local ui_types = {}
    for ui_type, _ in pairs(data.unique_ui_observations or {}) do
        table.insert(ui_types, ui_type)
    end
    table.sort(ui_types)

    local index = 1
    for _, ui_type in ipairs(ui_types) do
        local bucket = data.unique_ui_observations[ui_type] or {}
        local keys = {}
        for key, _ in pairs(bucket) do
            table.insert(keys, key)
        end
        table.sort(keys)

        for _, key in ipairs(keys) do
            map[index] = string.format("%s | %s", tostring(ui_type), tostring(bucket[key]))
            index = index + 1
        end
    end

    return map
end

local function guild_flow_targeted_ui_details_map(runtime)
    local data = runtime.guild_flow_research_data
    if data == nil then
        return {}
    end

    local map = {}
    local ui_types = {}
    for ui_type, _ in pairs(data.targeted_ui_details or {}) do
        table.insert(ui_types, ui_type)
    end
    table.sort(ui_types)

    local index = 1
    for _, ui_type in ipairs(ui_types) do
        local detail = data.targeted_ui_details[ui_type]
        if detail ~= nil then
            map[index] = string.format(
                "%s | list_ctrl=%s | list_ctrl_type=%s | info_list_type=%s | item_list_type=%s | first_info_type=%s | first_item_type=%s | source=%s | current_index=%s | current_index_source=%s | selected_index_source=%s | item_num=%s | count=%s | visible_start=%s | visible_end=%s",
                tostring(ui_type),
                util.describe_obj(detail.main_contents_list_ctrl),
                tostring(detail.main_contents_list_ctrl_type),
                tostring(detail.info_list_type),
                tostring(detail.item_list_type),
                tostring(detail.first_info_entry_type),
                tostring(detail.first_item_entry_type),
                tostring(detail.main_contents_list_ctrl_source),
                tostring(detail.current_index),
                tostring(detail.current_index_source),
                tostring(detail.selected_index_source),
                tostring(detail.item_num),
                tostring(detail.count),
                tostring(detail.visible_start_index),
                tostring(detail.visible_end_index)
            )
            index = index + 1
            map[index] = string.format("%s | flow_now=%s | chara_tab=%s", tostring(ui_type), tostring(detail.flow_now), tostring(detail.chara_tab))
            index = index + 1

            for _, line in ipairs(detail.ui_fields or {}) do
                map[index] = string.format("%s | ui_field | %s", tostring(ui_type), tostring(line))
                index = index + 1
            end

            for _, line in ipairs(detail.list_ctrl_fields or {}) do
                map[index] = string.format("%s | list_ctrl_field | %s", tostring(ui_type), tostring(line))
                index = index + 1
            end

            for _, line in ipairs(detail.ui_methods or {}) do
                map[index] = string.format("%s | ui_method | %s", tostring(ui_type), tostring(line))
                index = index + 1
            end

            for _, line in ipairs(detail.list_ctrl_methods or {}) do
                map[index] = string.format("%s | list_ctrl_method | %s", tostring(ui_type), tostring(line))
                index = index + 1
            end

            for _, line in ipairs(detail.chara_tab_fields or {}) do
                map[index] = string.format("%s | chara_tab_field | %s", tostring(ui_type), tostring(line))
                index = index + 1
            end

            for _, line in ipairs(detail.chara_tab_selected or {}) do
                map[index] = string.format("%s | chara_tab_selected | %s", tostring(ui_type), tostring(line))
                index = index + 1
            end

            for _, line in ipairs(detail.chara_tab_methods or {}) do
                map[index] = string.format("%s | chara_tab_method | %s", tostring(ui_type), tostring(line))
                index = index + 1
            end

            for _, line in ipairs(detail.chara_tab_related_collections or {}) do
                map[index] = string.format("%s | chara_tab_collection | %s", tostring(ui_type), tostring(line))
                index = index + 1
            end

            if detail.chara_tab_list_ctrl ~= nil then
                map[index] = string.format(
                    "%s | chara_tab_list_ctrl=%s | type=%s | source=%s",
                    tostring(ui_type),
                    util.describe_obj(detail.chara_tab_list_ctrl),
                    tostring(detail.chara_tab_list_ctrl_type),
                    tostring(detail.chara_tab_list_ctrl_source)
                )
                index = index + 1
            end

            for _, line in ipairs(detail.chara_tab_list_ctrl_fields or {}) do
                map[index] = string.format("%s | chara_tab_list_ctrl_field | %s", tostring(ui_type), tostring(line))
                index = index + 1
            end

            for _, line in ipairs(detail.chara_tab_list_ctrl_related_collections or {}) do
                map[index] = string.format("%s | chara_tab_list_ctrl_collection | %s", tostring(ui_type), tostring(line))
                index = index + 1
            end

            for _, line in ipairs(detail.info_entries or {}) do
                map[index] = string.format("%s | info_entry | %s", tostring(ui_type), tostring(line))
                index = index + 1
            end

            for _, line in ipairs(detail.item_entries or {}) do
                map[index] = string.format("%s | item_entry | %s", tostring(ui_type), tostring(line))
                index = index + 1
            end
        end
    end

    return map
end

local function guild_flow_targeted_ui_details_by_target_map(runtime)
    local data = runtime.guild_flow_research_data
    if data == nil then
        return {}
    end

    local map = {}
    local ui_types = {}
    for ui_type, _ in pairs(data.targeted_ui_details_by_target or {}) do
        table.insert(ui_types, ui_type)
    end
    table.sort(ui_types)

    local index = 1
    for _, ui_type in ipairs(ui_types) do
        local targets = data.targeted_ui_details_by_target[ui_type] or {}
        local target_names = {}
        for target_name, _ in pairs(targets) do
            table.insert(target_names, target_name)
        end
        table.sort(target_names)

        for _, target_name in ipairs(target_names) do
            local detail = targets[target_name]
            if detail ~= nil then
                map[index] = string.format(
                    "%s | target=%s | list_ctrl=%s | list_ctrl_type=%s | info_list_type=%s | item_list_type=%s | first_info_type=%s | first_item_type=%s | current_index=%s | current_index_source=%s | selected_index_source=%s | item_num=%s | count=%s | info_count=%s | item_count=%s",
                    tostring(ui_type),
                    tostring(target_name),
                    util.describe_obj(detail.main_contents_list_ctrl),
                    tostring(detail.main_contents_list_ctrl_type),
                    tostring(detail.info_list_type),
                    tostring(detail.item_list_type),
                    tostring(detail.first_info_entry_type),
                    tostring(detail.first_item_entry_type),
                    tostring(detail.current_index),
                    tostring(detail.current_index_source),
                    tostring(detail.selected_index_source),
                    tostring(detail.item_num),
                    tostring(detail.count),
                    tostring(detail.info_count),
                    tostring(detail.item_count)
                )
                index = index + 1
                map[index] = string.format("%s | target=%s | flow_now=%s | chara_tab=%s", tostring(ui_type), tostring(target_name), tostring(detail.flow_now), tostring(detail.chara_tab))
                index = index + 1

                for _, line in ipairs(detail.chara_tab_fields or {}) do
                    map[index] = string.format("%s | target=%s | chara_tab_field | %s", tostring(ui_type), tostring(target_name), tostring(line))
                    index = index + 1
                end

                for _, line in ipairs(detail.chara_tab_selected or {}) do
                    map[index] = string.format("%s | target=%s | chara_tab_selected | %s", tostring(ui_type), tostring(target_name), tostring(line))
                    index = index + 1
                end

                for _, line in ipairs(detail.chara_tab_related_collections or {}) do
                    map[index] = string.format("%s | target=%s | chara_tab_collection | %s", tostring(ui_type), tostring(target_name), tostring(line))
                    index = index + 1
                end

                if detail.chara_tab_list_ctrl ~= nil then
                    map[index] = string.format(
                        "%s | target=%s | chara_tab_list_ctrl=%s | type=%s | source=%s",
                        tostring(ui_type),
                        tostring(target_name),
                        util.describe_obj(detail.chara_tab_list_ctrl),
                        tostring(detail.chara_tab_list_ctrl_type),
                        tostring(detail.chara_tab_list_ctrl_source)
                    )
                    index = index + 1
                end

                for _, line in ipairs(detail.chara_tab_list_ctrl_fields or {}) do
                    map[index] = string.format("%s | target=%s | chara_tab_list_ctrl_field | %s", tostring(ui_type), tostring(target_name), tostring(line))
                    index = index + 1
                end

                for _, line in ipairs(detail.chara_tab_list_ctrl_related_collections or {}) do
                    map[index] = string.format("%s | target=%s | chara_tab_list_ctrl_collection | %s", tostring(ui_type), tostring(target_name), tostring(line))
                    index = index + 1
                end

                for _, line in ipairs(detail.info_entries or {}) do
                    map[index] = string.format("%s | target=%s | info_entry | %s", tostring(ui_type), tostring(target_name), tostring(line))
                    index = index + 1
                end

                for _, line in ipairs(detail.item_entries or {}) do
                    map[index] = string.format("%s | target=%s | item_entry | %s", tostring(ui_type), tostring(target_name), tostring(line))
                    index = index + 1
                end
            end
        end
    end

    return map
end

local function guild_flow_setup_job_menu_contents_info_map(runtime)
    local data = runtime.guild_flow_research_data
    if data == nil then
        return {}
    end

    local map = {}
    local targets = {}
    for target_name, _ in pairs(data.setup_job_menu_contents_info_snapshots or {}) do
        table.insert(targets, target_name)
    end
    table.sort(targets)

    local index = 1
    for _, target_name in ipairs(targets) do
        local phases = data.setup_job_menu_contents_info_snapshots[target_name] or {}
        local ordered_phases = { "pre", "post" }
        for _, phase_name in ipairs(ordered_phases) do
            local item = phases[phase_name]
            if item ~= nil then
                map[index] = string.format(
                    "target=%s | phase=%s | time=%s | chara_id=%s | job=%s | flow_now=%s | info_count=%s | item_count=%s | chara_tab=%s | chara_tab_type=%s | chara_tab_list_ctrl=%s | chara_tab_list_ctrl_type=%s",
                    tostring(target_name),
                    tostring(phase_name),
                    tostring(item.time),
                    tostring(item.chara_id),
                    tostring(item.current_job),
                    tostring(item.flow_now),
                    tostring(item.info_count),
                    tostring(item.item_count),
                    tostring(item.chara_tab),
                    tostring(item.chara_tab_type),
                    tostring(item.chara_tab_list_ctrl),
                    tostring(item.chara_tab_list_ctrl_type)
                )
                index = index + 1

                for _, line in ipairs(item.chara_tab_fields or {}) do
                    map[index] = string.format("target=%s | phase=%s | chara_tab_field | %s", tostring(target_name), tostring(phase_name), tostring(line))
                    index = index + 1
                end

                for _, line in ipairs(item.chara_tab_selected or {}) do
                    map[index] = string.format("target=%s | phase=%s | chara_tab_selected | %s", tostring(target_name), tostring(phase_name), tostring(line))
                    index = index + 1
                end

                for _, line in ipairs(item.chara_tab_related_collections or {}) do
                    map[index] = string.format("target=%s | phase=%s | chara_tab_collection | %s", tostring(target_name), tostring(phase_name), tostring(line))
                    index = index + 1
                end

                for _, line in ipairs(item.chara_tab_list_ctrl_fields or {}) do
                    map[index] = string.format("target=%s | phase=%s | chara_tab_list_ctrl_field | %s", tostring(target_name), tostring(phase_name), tostring(line))
                    index = index + 1
                end

                for _, line in ipairs(item.chara_tab_list_ctrl_related_collections or {}) do
                    map[index] = string.format("target=%s | phase=%s | chara_tab_list_ctrl_collection | %s", tostring(target_name), tostring(phase_name), tostring(line))
                    index = index + 1
                end

                for _, line in ipairs(item.info_name_lines or {}) do
                    map[index] = string.format("target=%s | phase=%s | info_name | %s", tostring(target_name), tostring(phase_name), tostring(line))
                    index = index + 1
                end
            end
        end
    end

    return map
end

local function append_selected_chara_detail_lines(map, index, target_name, label, detail)
    if detail == nil then
        return index
    end

    map[string.format("%03d", index)] = string.format(
        "target=%s | %s | chara=%s | chara_type=%s | job_context=%s | job_context_type=%s | human=%s | human_type=%s | current_job=%s",
        tostring(target_name),
        tostring(label),
        tostring(detail.chara),
        tostring(detail.chara_type),
        tostring(detail.job_context),
        tostring(detail.job_context_type),
        tostring(detail.human),
        tostring(detail.human_type),
        tostring(detail.current_job)
    )
    index = index + 1

    for _, line in ipairs(detail.chara_fields or {}) do
        map[string.format("%03d", index)] = string.format("target=%s | %s | chara_field | %s", tostring(target_name), tostring(label), tostring(line))
        index = index + 1
    end

    for _, line in ipairs(detail.job_context_fields or {}) do
        map[string.format("%03d", index)] = string.format("target=%s | %s | job_context_field | %s", tostring(target_name), tostring(label), tostring(line))
        index = index + 1
    end

    for _, line in ipairs(detail.human_fields or {}) do
        map[string.format("%03d", index)] = string.format("target=%s | %s | human_field | %s", tostring(target_name), tostring(label), tostring(line))
        index = index + 1
    end

    for _, line in ipairs(detail.chara_collections or {}) do
        map[string.format("%03d", index)] = string.format("target=%s | %s | chara_collection | %s", tostring(target_name), tostring(label), tostring(line))
        index = index + 1
    end

    for _, line in ipairs(detail.job_context_collections or {}) do
        map[string.format("%03d", index)] = string.format("target=%s | %s | job_context_collection | %s", tostring(target_name), tostring(label), tostring(line))
        index = index + 1
    end

    return index
end

local function guild_flow_setup_job_menu_comparison_map(runtime)
    local data = runtime.guild_flow_research_data
    local item = data and data.setup_job_menu_comparison or nil
    if item == nil or next(item) == nil then
        return {}
    end

    local map = {
        player_info_count = tostring(item.player_info_count),
        main_pawn_info_count = tostring(item.main_pawn_info_count),
        player_item_count = tostring(item.player_item_count),
        main_pawn_item_count = tostring(item.main_pawn_item_count),
        player_chara_id = tostring(item.player_chara_id),
        main_pawn_chara_id = tostring(item.main_pawn_chara_id),
        player_selected_chara_id = tostring(item.player_selected_chara_id),
        main_pawn_selected_chara_id = tostring(item.main_pawn_selected_chara_id),
        player_flow_now = tostring(item.player_flow_now),
        main_pawn_flow_now = tostring(item.main_pawn_flow_now),
        player_jobs = table.concat(item.player_job_names or {}, ", "),
        main_pawn_jobs = table.concat(item.main_pawn_job_names or {}, ", "),
        missing_for_main_pawn = table.concat(item.missing_for_main_pawn or {}, ", "),
        extra_for_main_pawn = table.concat(item.extra_for_main_pawn or {}, ", "),
    }

    local next_index = 100
    next_index = append_selected_chara_detail_lines(map, next_index, "player", "selected_chara_detail", item.player_selected_chara_detail)
    append_selected_chara_detail_lines(map, next_index, "main_pawn", "selected_chara_detail", item.main_pawn_selected_chara_detail)
    return map
end

local function guild_flow_character_type_gate_map(runtime)
    local data = runtime.guild_flow_research_data
    local item = data and data.setup_job_menu_comparison or nil
    if item == nil or next(item) == nil then
        return {}
    end

    local player_detail = item.player_selected_chara_detail or {}
    local main_pawn_detail = item.main_pawn_selected_chara_detail or {}

    return {
        player_chara_type = tostring(player_detail.chara_type),
        main_pawn_chara_type = tostring(main_pawn_detail.chara_type),
        player_human_type = tostring(player_detail.human_type),
        main_pawn_human_type = tostring(main_pawn_detail.human_type),
        player_job_context_type = tostring(player_detail.job_context_type),
        main_pawn_job_context_type = tostring(main_pawn_detail.job_context_type),
        player_current_job = tostring(player_detail.current_job),
        main_pawn_current_job = tostring(main_pawn_detail.current_job),
        chara_type_differs = tostring(tostring(player_detail.chara_type) ~= tostring(main_pawn_detail.chara_type)),
        human_type_differs = tostring(tostring(player_detail.human_type) ~= tostring(main_pawn_detail.human_type)),
        job_context_type_differs = tostring(tostring(player_detail.job_context_type) ~= tostring(main_pawn_detail.job_context_type)),
    }
end

local function guild_flow_hypothesis_matrix_map(runtime)
    local data = runtime.guild_flow_research_data
    if data == nil then
        return {}
    end

    local comparison = data.setup_job_menu_comparison or {}
    local player_source = data.player_job_list_override or {}
    local prune = data.prune_bypass_probe or {}
    local reinjection = data.post_prune_reinjection or {}
    local rewrite = data.manual_prune_rewrite or {}
    local job_info = data.job_info_pawn_override or {}
    local latest = data.multi_intervention_latest or {}
    local update_stage = latest.updateJobMenu or {}
    local setup_stage = latest.setupJobMenuContentsInfo or {}

    local missing = comparison.missing_for_main_pawn or {}
    local hybrid_missing_count = 0
    for _, name in ipairs(missing) do
        if tostring(name) ~= "" then
            hybrid_missing_count = hybrid_missing_count + 1
        end
    end

    return {
        player_full_source_ready = tostring(player_source.source_full_ready == true),
        player_full_source_counts = string.format("%s/%s", tostring(player_source.source_info_count), tostring(player_source.source_item_count)),
        player_full_source_method = tostring(player_source.source_method),
        prune_detected = tostring((prune.attempted == true) or (reinjection.attempted == true)),
        prune_removed_hybrid_count = tostring(hybrid_missing_count),
        prune_bypass_attempted = tostring(prune.attempted == true),
        prune_bypass_ok = tostring(prune.ok == true),
        prune_bypass_reason = tostring(prune.reason),
        reinjection_attempted = tostring(reinjection.attempted == true),
        reinjection_ok = tostring(reinjection.ok == true),
        reinjection_reason = tostring(reinjection.reason),
        reinjection_after_counts = string.format("%s/%s", tostring(reinjection.after_info_count), tostring(reinjection.after_item_count)),
        manual_rewrite_attempted = tostring(rewrite.attempted == true),
        manual_rewrite_ok = tostring(rewrite.ok == true),
        manual_rewrite_reason = tostring(rewrite.reason),
        update_stage_attempted = tostring(update_stage.attempted == true),
        update_stage_reason = tostring(update_stage.reason),
        setup_stage_attempted = tostring(setup_stage.attempted == true),
        setup_stage_reason = tostring(setup_stage.reason),
        job_info_override_attempted = tostring(job_info.attempted == true),
        job_info_override_ok = tostring(job_info.ok == true),
        job_info_override_reason = tostring(job_info.reason),
        job_info_override_job_id = tostring(job_info.job_id),
    }
end

local function guild_flow_player_job_list_override_map(runtime)
    local data = runtime.guild_flow_research_data
    if data == nil or data.player_job_list_override == nil then
        return {}
    end

    local item = data.player_job_list_override
    return {
        enabled = tostring(item.enabled),
        copy_item_list = tostring(item.copy_item_list),
        source_ready = tostring(item.source_ready),
        source_full_ready = tostring(item.source_full_ready),
        source_target = tostring(item.source_target),
        source_method = tostring(item.source_method),
        source_time = tostring(item.source_time),
        source_chara_id = tostring(item.source_chara_id),
        source_job = tostring(item.source_job),
        source_info_count = tostring(item.source_info_count),
        source_item_count = tostring(item.source_item_count),
        source_info_list_type = tostring(item.source_info_list_type),
        source_item_list_type = tostring(item.source_item_list_type),
        source_list_ctrl_type = tostring(item.source_list_ctrl_type),
        last_result = tostring(item.last_result),
        last_reason = tostring(item.last_reason),
        last_target = tostring(item.last_target),
        last_time = tostring(item.last_time),
        last_flow_now = tostring(item.last_flow_now),
        last_before_info_count = tostring(item.last_before_info_count),
        last_before_item_count = tostring(item.last_before_item_count),
        last_after_info_count = tostring(item.last_after_info_count),
        last_after_item_count = tostring(item.last_after_item_count),
        last_info_field = tostring(item.last_info_field),
        last_item_field = tostring(item.last_item_field),
        last_source_info_count = tostring(item.last_source_info_count),
        last_source_item_count = tostring(item.last_source_item_count),
    }
end

local function guild_flow_source_probe_once_map(runtime)
    local data = runtime.guild_flow_research_data
    local item = data and data.source_probe_once or nil
    if item == nil then
        return {}
    end

    return {
        enabled = tostring(item.enabled),
        armed = tostring(item.armed),
        capture_count = tostring(item.capture_count),
        capture_limit_per_target = tostring(item.capture_limit_per_target),
        capture_limit_get_job_info = tostring(item.capture_limit_get_job_info),
        capture_limit_add_normal = tostring(item.capture_limit_add_normal),
        capture_limit_get_job_info_player = tostring(item.capture_limit_get_job_info_player),
        capture_limit_get_job_info_main_pawn = tostring(item.capture_limit_get_job_info_main_pawn),
        capture_limit_add_normal_player = tostring(item.capture_limit_add_normal_player),
        capture_limit_add_normal_main_pawn = tostring(item.capture_limit_add_normal_main_pawn),
        captured_player = tostring(item.captured_targets and item.captured_targets.player or 0),
        captured_main_pawn = tostring(item.captured_targets and item.captured_targets.main_pawn or 0),
        add_normal_player = tostring(item.method_capture_counts and item.method_capture_counts["addNormalContentsList:player"] or 0),
        add_normal_main_pawn = tostring(item.method_capture_counts and item.method_capture_counts["addNormalContentsList:main_pawn"] or 0),
        get_job_info_player = tostring(item.method_capture_counts and item.method_capture_counts["getJobInfoParam:player"] or 0),
        get_job_info_main_pawn = tostring(item.method_capture_counts and item.method_capture_counts["getJobInfoParam:main_pawn"] or 0),
        last_method = tostring(item.last_method),
        last_target = tostring(item.last_target),
        last_reason = tostring(item.last_reason),
        last_time = tostring(item.last_time),
        last_flow_now = tostring(item.last_flow_now),
        last_capture_job_id = tostring(item.last_capture_job_id),
    }
end

local function guild_flow_aggressive_hook_session_map(runtime)
    local data = runtime.guild_flow_research_data
    local item = data and data.aggressive_hook_session or nil
    if item == nil then
        return {}
    end

    return {
        enabled = tostring(item.enabled),
        active = tostring(item.active),
        target = tostring(item.target),
        trigger_method = tostring(item.trigger_method),
        event_count = tostring(item.event_count),
        event_limit = tostring(item.event_limit),
        duration_seconds = tostring(item.duration_seconds),
        started_at = tostring(item.started_at),
        expires_at = tostring(item.expires_at),
        last_reason = tostring(item.last_reason),
        last_time = tostring(item.last_time),
    }
end

local function guild_flow_job_info_pawn_override_map(runtime)
    local data = runtime.guild_flow_research_data
    local item = data and data.job_info_pawn_override or nil
    if item == nil then
        return {}
    end

    return {
        enabled = tostring(item.enabled),
        attempted = tostring(item.attempted),
        ok = tostring(item.ok),
        reason = tostring(item.reason),
        job_id = tostring(item.job_id),
        flow_now = tostring(item.flow_now),
        flow_now_source = tostring(item.flow_now_source),
        before_enable_pawn = tostring(item.before_enable_pawn),
        after_enable_pawn = tostring(item.after_enable_pawn),
        time = tostring(item.time),
    }
end

local function guild_flow_source_method_snapshots_map(runtime)
    local data = runtime.guild_flow_research_data
    if data == nil then
        return {}
    end

    local map = {}
    local methods = {}
    for method_name, _ in pairs(data.source_method_snapshots or {}) do
        table.insert(methods, method_name)
    end
    table.sort(methods)

    local index = 1
    for _, method_name in ipairs(methods) do
        local target_bucket = data.source_method_snapshots[method_name] or {}
        local targets = {}
        for target_name, _ in pairs(target_bucket) do
            table.insert(targets, target_name)
        end
        table.sort(targets)

        for _, target_name in ipairs(targets) do
            local captures = target_bucket[target_name] or {}
            table.sort(captures, function(a, b)
                local pass_a = tonumber(a and a.capture_pass) or 0
                local pass_b = tonumber(b and b.capture_pass) or 0
                if pass_a ~= pass_b then
                    return pass_a < pass_b
                end

                local seq_a = tonumber(a and a.capture_sequence) or 0
                local seq_b = tonumber(b and b.capture_sequence) or 0
                if seq_a ~= seq_b then
                    return seq_a < seq_b
                end

                local time_a = tonumber(a and a.time) or 0
                local time_b = tonumber(b and b.time) or 0
                if time_a ~= time_b then
                    return time_a < time_b
                end

                return tostring(a and a.capture_label) < tostring(b and b.capture_label)
            end)

            for _, item in ipairs(captures) do
                local phase_name = item.phase or "unknown"
                map[index] = string.format(
                    "method=%s | target=%s | selected_target=%s | event_target=%s | drift=%s | selected_chara_id=%s | capture_job_id=%s | capture_label=%s | pass=%s | seq=%s | phase=%s | time=%s | chara_id=%s | job=%s | flow_now=%s | info_count=%s | item_count=%s | last_info_name=%s | args=%s | return=%s | return_type=%s",
                    tostring(method_name),
                    tostring(target_name),
                    tostring(item.selected_target_name),
                    tostring(item.event_target_name),
                    tostring(item.context_drift),
                    tostring(item.selected_chara_id),
                    tostring(item.capture_job_id),
                    tostring(item.capture_label),
                    tostring(item.capture_pass),
                    tostring(item.capture_sequence),
                    tostring(phase_name),
                    tostring(item.time),
                    tostring(item.chara_id),
                    tostring(item.current_job),
                    tostring(item.flow_now),
                    tostring(item.info_count),
                    tostring(item.item_count),
                    tostring(item.last_info_entry_name),
                    tostring(item.argument_summary),
                    tostring(item.return_summary),
                    tostring(item.return_type)
                )
                index = index + 1

                if item.last_info_entry_summary ~= nil then
                    map[index] = string.format(
                        "method=%s | target=%s | capture_job_id=%s | phase=%s | list_entry | %s",
                        tostring(method_name),
                        tostring(target_name),
                        tostring(item.capture_job_id),
                        tostring(phase_name),
                        tostring(item.last_info_entry_summary)
                    )
                    index = index + 1
                end

                if item.transition_summary ~= nil then
                    map[index] = string.format(
                        "method=%s | target=%s | capture_job_id=%s | phase=%s | transition | %s | delta_info=%s | delta_item=%s",
                        tostring(method_name),
                        tostring(target_name),
                        tostring(item.capture_job_id),
                        tostring(phase_name),
                        tostring(item.transition_summary),
                        tostring(item.delta_info_count),
                        tostring(item.delta_item_count)
                    )
                    index = index + 1
                end

                for _, line in ipairs(item.argument_details or {}) do
                    map[index] = string.format(
                        "method=%s | target=%s | capture_job_id=%s | phase=%s | arg_detail | %s",
                        tostring(method_name),
                        tostring(target_name),
                        tostring(item.capture_job_id),
                        tostring(phase_name),
                        tostring(line)
                    )
                    index = index + 1
                end

                for _, line in ipairs(item.return_keyword_fields or {}) do
                    map[index] = string.format(
                        "method=%s | target=%s | capture_job_id=%s | phase=%s | return_keyword | %s",
                        tostring(method_name),
                        tostring(target_name),
                        tostring(item.capture_job_id),
                        tostring(phase_name),
                        tostring(line)
                    )
                    index = index + 1
                end

                for _, line in ipairs(item.return_fields or {}) do
                    map[index] = string.format(
                        "method=%s | target=%s | capture_job_id=%s | phase=%s | return_field | %s",
                        tostring(method_name),
                        tostring(target_name),
                        tostring(item.capture_job_id),
                        tostring(phase_name),
                        tostring(line)
                    )
                    index = index + 1
                end

                for _, line in ipairs(item.return_collections or {}) do
                    map[index] = string.format(
                        "method=%s | target=%s | capture_job_id=%s | phase=%s | return_collection | %s",
                        tostring(method_name),
                        tostring(target_name),
                        tostring(item.capture_job_id),
                        tostring(phase_name),
                        tostring(line)
                    )
                    index = index + 1
                end
            end
        end
    end

    return map
end

local function guild_flow_prune_windows_map(runtime)
    local data = runtime.guild_flow_research_data
    if data == nil then
        return {}
    end

    local map = {}
    local index = 1
    local windows = data.prune_windows or {}
    for _, item in ipairs(windows) do
        map[index] = string.format(
            "time=%s | method=%s | target=%s | selected_target=%s | event_target=%s | selected_chara_id=%s | pass=%s | seq=%s | transition=%s | delta_info=%s | delta_item=%s",
            tostring(item.time),
            tostring(item.method),
            tostring(item.target),
            tostring(item.selected_target_name),
            tostring(item.event_target_name),
            tostring(item.selected_chara_id),
            tostring(item.capture_pass),
            tostring(item.capture_sequence),
            tostring(item.transition_summary),
            tostring(item.delta_info_count),
            tostring(item.delta_item_count)
        )
        index = index + 1

        if item.current_entry_summary ~= nil then
            map[index] = string.format("current_entry | %s", tostring(item.current_entry_summary))
            index = index + 1
        end

        if item.prune_bypass_result ~= nil then
            map[index] = string.format(
                "prune_bypass | enabled=%s attempted=%s ok=%s reason=%s info_field=%s item_field=%s",
                tostring(item.prune_bypass_result.enabled),
                tostring(item.prune_bypass_result.attempted),
                tostring(item.prune_bypass_result.ok),
                tostring(item.prune_bypass_result.reason),
                tostring(item.prune_bypass_result.info_field),
                tostring(item.prune_bypass_result.item_field)
            )
            index = index + 1
        end

        if item.post_prune_reinjection_result ~= nil then
            map[index] = string.format(
                "post_prune_reinjection | enabled=%s attempted=%s ok=%s reason=%s before_info=%s after_info=%s before_item=%s after_item=%s info_method=%s item_method=%s refresh_attempted=%s refresh_ok=%s refresh_method=%s",
                tostring(item.post_prune_reinjection_result.enabled),
                tostring(item.post_prune_reinjection_result.attempted),
                tostring(item.post_prune_reinjection_result.ok),
                tostring(item.post_prune_reinjection_result.reason),
                tostring(item.post_prune_reinjection_result.before_info_count),
                tostring(item.post_prune_reinjection_result.after_info_count),
                tostring(item.post_prune_reinjection_result.before_item_count),
                tostring(item.post_prune_reinjection_result.after_item_count),
                tostring(item.post_prune_reinjection_result.info_add_method),
                tostring(item.post_prune_reinjection_result.item_add_method),
                tostring(item.post_prune_reinjection_result.refresh_attempted),
                tostring(item.post_prune_reinjection_result.refresh_ok),
                tostring(item.post_prune_reinjection_result.refresh_method)
            )
            index = index + 1

            if type(item.post_prune_reinjection_result.reinserted_entries) == "table"
                and #item.post_prune_reinjection_result.reinserted_entries > 0
            then
                map[index] = string.format(
                    "reinserted_entries | %s",
                    table.concat(item.post_prune_reinjection_result.reinserted_entries, ", ")
                )
                index = index + 1
            end

            if type(item.post_prune_reinjection_result.after_info_names) == "table"
                and #item.post_prune_reinjection_result.after_info_names > 0
            then
                map[index] = string.format(
                    "after_reinjection_entries | %s",
                    table.concat(item.post_prune_reinjection_result.after_info_names, " || ")
                )
                index = index + 1
            end
        end

        if item.removed_info_names ~= nil then
            map[index] = string.format("removed_entries | %s", table.concat(item.removed_info_names, ", "))
            index = index + 1
        end

        if type(item.previous_info_name_lines) == "table" and #item.previous_info_name_lines > 0 then
            map[index] = string.format("pre_prune_entries | %s", table.concat(item.previous_info_name_lines, " || "))
            index = index + 1
        end

        if type(item.current_info_name_lines) == "table" and #item.current_info_name_lines > 0 then
            map[index] = string.format("post_prune_entries | %s", table.concat(item.current_info_name_lines, " || "))
            index = index + 1
        end

        for _, event_line in ipairs(item.recent_events or {}) do
            map[index] = string.format(
                "recent_event | %s | %s | %s | chara_id=%s | role=%s | flow_id=%s",
                tostring(event_line.time),
                tostring(event_line.ui_type),
                tostring(event_line.method),
                tostring(event_line.chara_id),
                tostring(event_line.target_role),
                tostring(event_line.flow_id)
            )
            index = index + 1
        end

        for _, field_line in ipairs(item.recent_field_sets or {}) do
            local compact = {}
            for key, value in pairs(field_line.fields or {}) do
                table.insert(compact, tostring(key) .. "=" .. tostring(value))
            end
            table.sort(compact)
            map[index] = string.format(
                "recent_field | %s | %s | %s | %s",
                tostring(field_line.time),
                tostring(field_line.ui_type),
                tostring(field_line.method),
                table.concat(compact, "; ")
            )
            index = index + 1
        end
    end

    return map
end

local function guild_flow_prune_followups_map(runtime)
    local data = runtime.guild_flow_research_data
    if data == nil then
        return {}
    end

    local map = {}
    local index = 1
    for _, item in ipairs(data.prune_followups or {}) do
        map[index] = string.format(
            "time=%s | method=%s | phase=%s | target=%s | chara_id=%s | selected_chara_id=%s | job=%s | flow_now=%s | info_count=%s | item_count=%s | last_info_name=%s",
            tostring(item.time),
            tostring(item.method),
            tostring(item.phase),
            tostring(item.target),
            tostring(item.chara_id),
            tostring(item.selected_chara_id),
            tostring(item.current_job),
            tostring(item.flow_now),
            tostring(item.info_count),
            tostring(item.item_count),
            tostring(item.last_info_name)
        )
        index = index + 1
    end

    return map
end

local function guild_flow_prune_bypass_probe_map(runtime)
    local data = runtime.guild_flow_research_data
    local probe = data and data.prune_bypass_probe or nil
    if probe == nil then
        return {}
    end

    return {
        enabled = tostring(probe.enabled),
        attempted = tostring(probe.attempted),
        ok = tostring(probe.ok),
        reason = tostring(probe.reason),
        target = tostring(probe.target),
        time = tostring(probe.time),
        selected_chara_id = tostring(probe.selected_chara_id),
        previous_info_count = tostring(probe.previous_info_count),
        info_count = tostring(probe.info_count),
        info_field = tostring(probe.info_field),
        item_field = tostring(probe.item_field),
        removed_info_names = probe.removed_info_names and table.concat(probe.removed_info_names, ", ") or "",
    }
end

local function guild_flow_post_prune_reinjection_map(runtime)
    local data = runtime.guild_flow_research_data
    local reinjection = data and data.post_prune_reinjection or nil
    if reinjection == nil then
        return {}
    end

    return {
        enabled = tostring(reinjection.enabled),
        attempted = tostring(reinjection.attempted),
        ok = tostring(reinjection.ok),
        reason = tostring(reinjection.reason),
        target = tostring(reinjection.target),
        time = tostring(reinjection.time),
        selected_chara_id = tostring(reinjection.selected_chara_id),
        before_info_count = tostring(reinjection.before_info_count),
        after_info_count = tostring(reinjection.after_info_count),
        before_item_count = tostring(reinjection.before_item_count),
        after_item_count = tostring(reinjection.after_item_count),
        info_add_ok = tostring(reinjection.info_add_ok),
        item_add_ok = tostring(reinjection.item_add_ok),
        info_add_method = tostring(reinjection.info_add_method),
        item_add_method = tostring(reinjection.item_add_method),
        refresh_attempted = tostring(reinjection.refresh_attempted),
        refresh_ok = tostring(reinjection.refresh_ok),
        refresh_method = tostring(reinjection.refresh_method),
        refresh_success_chain = tostring(reinjection.refresh_success_chain),
        refresh_candidates = reinjection.refresh_candidates and table.concat(reinjection.refresh_candidates, ", ") or "",
        list_ctrl_refresh_methods = reinjection.list_ctrl_refresh_methods and table.concat(reinjection.list_ctrl_refresh_methods, ", ") or "",
        ui_refresh_methods = reinjection.ui_refresh_methods and table.concat(reinjection.ui_refresh_methods, ", ") or "",
        removed_info_names = reinjection.removed_info_names and table.concat(reinjection.removed_info_names, ", ") or "",
        reinserted_entries = reinjection.reinserted_entries and table.concat(reinjection.reinserted_entries, ", ") or "",
        after_info_names = reinjection.after_info_names and table.concat(reinjection.after_info_names, " || ") or "",
        atomic_refresh_window = reinjection.atomic_refresh_window and string.format(
            "method=%s | info:%s->%s | item:%s->%s | current_index:%s->%s | current_index_source:%s->%s | flow_now:%s->%s",
            tostring(reinjection.atomic_refresh_window.method),
            tostring(reinjection.atomic_refresh_window.info_before),
            tostring(reinjection.atomic_refresh_window.info_after),
            tostring(reinjection.atomic_refresh_window.item_before),
            tostring(reinjection.atomic_refresh_window.item_after),
            tostring(reinjection.atomic_refresh_window.current_index_before),
            tostring(reinjection.atomic_refresh_window.current_index_after),
            tostring(reinjection.atomic_refresh_window.current_index_source_before),
            tostring(reinjection.atomic_refresh_window.current_index_source_after),
            tostring(reinjection.atomic_refresh_window.flow_now_before),
            tostring(reinjection.atomic_refresh_window.flow_now_after)
        ) or "",
        atomic_removed_entries = reinjection.atomic_refresh_window and reinjection.atomic_refresh_window.removed_entries and table.concat(reinjection.atomic_refresh_window.removed_entries, " || ") or "",
        atomic_added_entries = reinjection.atomic_refresh_window and reinjection.atomic_refresh_window.added_entries and table.concat(reinjection.atomic_refresh_window.added_entries, " || ") or "",
        atomic_before_entries = reinjection.atomic_refresh_window and reinjection.atomic_refresh_window.before_entries and table.concat(reinjection.atomic_refresh_window.before_entries, " || ") or "",
        atomic_after_entries = reinjection.atomic_refresh_window and reinjection.atomic_refresh_window.after_entries and table.concat(reinjection.atomic_refresh_window.after_entries, " || ") or "",
        atomic_removed_ui_fields = reinjection.atomic_refresh_window and reinjection.atomic_refresh_window.removed_ui_fields and table.concat(reinjection.atomic_refresh_window.removed_ui_fields, " || ") or "",
        atomic_added_ui_fields = reinjection.atomic_refresh_window and reinjection.atomic_refresh_window.added_ui_fields and table.concat(reinjection.atomic_refresh_window.added_ui_fields, " || ") or "",
        atomic_removed_list_ctrl_fields = reinjection.atomic_refresh_window and reinjection.atomic_refresh_window.removed_list_ctrl_fields and table.concat(reinjection.atomic_refresh_window.removed_list_ctrl_fields, " || ") or "",
        atomic_added_list_ctrl_fields = reinjection.atomic_refresh_window and reinjection.atomic_refresh_window.added_list_ctrl_fields and table.concat(reinjection.atomic_refresh_window.added_list_ctrl_fields, " || ") or "",
    }
end

local function guild_flow_manual_prune_rewrite_map(runtime)
    local data = runtime.guild_flow_research_data
    local rewrite = data and data.manual_prune_rewrite or nil
    if rewrite == nil then
        return {}
    end

    return {
        enabled = tostring(rewrite.enabled),
        attempted = tostring(rewrite.attempted),
        ok = tostring(rewrite.ok),
        reason = tostring(rewrite.reason),
        target = tostring(rewrite.target),
        time = tostring(rewrite.time),
        selected_chara_id = tostring(rewrite.selected_chara_id),
        before_info_count = tostring(rewrite.before_info_count),
        after_info_count = tostring(rewrite.after_info_count),
        before_item_count = tostring(rewrite.before_item_count),
        after_item_count = tostring(rewrite.after_item_count),
        source_info_count = tostring(rewrite.source_info_count),
        source_item_count = tostring(rewrite.source_item_count),
        info_add_ok = tostring(rewrite.info_add_ok),
        item_add_ok = tostring(rewrite.item_add_ok),
        info_add_method = tostring(rewrite.info_add_method),
        item_add_method = tostring(rewrite.item_add_method),
        after_info_names = rewrite.after_info_names and table.concat(rewrite.after_info_names, " || ") or "",
    }
end

local function guild_flow_multi_intervention_latest_map(runtime)
    local data = runtime.guild_flow_research_data
    if data == nil then
        return {}
    end

    local map = {}
    local latest = data.multi_intervention_latest or {}
    local stages = {}
    for stage, _ in pairs(latest) do
        table.insert(stages, tostring(stage))
    end
    table.sort(stages)

    for _, stage in ipairs(stages) do
        local item = latest[stage]
        map[stage] = string.format(
            "attempted=%s ok=%s reason=%s target=%s time=%s before=%s/%s after=%s/%s source=%s/%s info_ok=%s item_ok=%s info_method=%s item_method=%s",
            tostring(item and item.attempted),
            tostring(item and item.ok),
            tostring(item and item.reason),
            tostring(item and item.target),
            tostring(item and item.time),
            tostring(item and item.before_info_count),
            tostring(item and item.before_item_count),
            tostring(item and item.after_info_count),
            tostring(item and item.after_item_count),
            tostring(item and item.source_info_count),
            tostring(item and item.source_item_count),
            tostring(item and item.info_add_ok),
            tostring(item and item.item_add_ok),
            tostring(item and item.info_add_method),
            tostring(item and item.item_add_method)
        )
    end

    return map
end

local function guild_flow_multi_intervention_attempts_map(runtime)
    local data = runtime.guild_flow_research_data
    if data == nil then
        return {}
    end

    local map = {}
    local index = 1
    for _, item in ipairs(data.multi_intervention_attempts or {}) do
        map[index] = string.format(
            "stage=%s | attempted=%s | ok=%s | reason=%s | target=%s | time=%s | before=%s/%s | after=%s/%s | source=%s/%s | info_ok=%s | item_ok=%s | info_method=%s | item_method=%s",
            tostring(item.stage),
            tostring(item.attempted),
            tostring(item.ok),
            tostring(item.reason),
            tostring(item.target),
            tostring(item.time),
            tostring(item.before_info_count),
            tostring(item.before_item_count),
            tostring(item.after_info_count),
            tostring(item.after_item_count),
            tostring(item.source_info_count),
            tostring(item.source_item_count),
            tostring(item.info_add_ok),
            tostring(item.item_add_ok),
            tostring(item.info_add_method),
            tostring(item.item_add_method)
        )
        index = index + 1
        if type(item.after_info_names) == "table" and #item.after_info_names > 0 then
            map[index] = "after_info_names | " .. table.concat(item.after_info_names, " || ")
            index = index + 1
        end
    end

    return map
end

local function guild_flow_source_rebuild_windows_map(runtime)
    local data = runtime.guild_flow_research_data
    if data == nil then
        return {}
    end

    local map = {}
    local index = 1
    for _, item in ipairs(data.source_rebuild_windows or {}) do
        map[index] = string.format(
            "time=%s | method=%s | target=%s | chara_id=%s | selected_chara_id=%s | flow_now=%s | info:%s->%s | item:%s->%s | current_index:%s->%s | current_index_source:%s->%s",
            tostring(item.time),
            tostring(item.method),
            tostring(item.target),
            tostring(item.chara_id),
            tostring(item.selected_chara_id),
            tostring(item.flow_now),
            tostring(item.before_info_count),
            tostring(item.after_info_count),
            tostring(item.before_item_count),
            tostring(item.after_item_count),
            tostring(item.before_current_index),
            tostring(item.after_current_index),
            tostring(item.before_current_index_source),
            tostring(item.after_current_index_source)
        )
        index = index + 1

        if type(item.removed_entries) == "table" and #item.removed_entries > 0 then
            map[index] = "removed_entries | " .. table.concat(item.removed_entries, " || ")
            index = index + 1
        end
        if type(item.added_entries) == "table" and #item.added_entries > 0 then
            map[index] = "added_entries | " .. table.concat(item.added_entries, " || ")
            index = index + 1
        end
        if type(item.before_info_name_lines) == "table" and #item.before_info_name_lines > 0 then
            map[index] = "before_entries | " .. table.concat(item.before_info_name_lines, " || ")
            index = index + 1
        end
        if type(item.after_info_name_lines) == "table" and #item.after_info_name_lines > 0 then
            map[index] = "after_entries | " .. table.concat(item.after_info_name_lines, " || ")
            index = index + 1
        end
        if type(item.removed_ui_fields) == "table" and #item.removed_ui_fields > 0 then
            map[index] = "removed_ui_fields | " .. table.concat(item.removed_ui_fields, " || ")
            index = index + 1
        end
        if type(item.added_ui_fields) == "table" and #item.added_ui_fields > 0 then
            map[index] = "added_ui_fields | " .. table.concat(item.added_ui_fields, " || ")
            index = index + 1
        end
        if type(item.removed_list_ctrl_fields) == "table" and #item.removed_list_ctrl_fields > 0 then
            map[index] = "removed_list_ctrl_fields | " .. table.concat(item.removed_list_ctrl_fields, " || ")
            index = index + 1
        end
        if type(item.added_list_ctrl_fields) == "table" and #item.added_list_ctrl_fields > 0 then
            map[index] = "added_list_ctrl_fields | " .. table.concat(item.added_list_ctrl_fields, " || ")
            index = index + 1
        end
    end

    return map
end

local function guild_flow_source_state_windows_map(runtime)
    local data = runtime.guild_flow_research_data
    if data == nil then
        return {}
    end

    local map = {}
    local index = 1
    for _, item in ipairs(data.source_state_windows or {}) do
        map[index] = string.format(
            "time=%s | method=%s | target=%s | chara_id=%s | selected_chara_id=%s | scalar_changes=%s",
            tostring(item.time),
            tostring(item.method),
            tostring(item.target),
            tostring(item.chara_id),
            tostring(item.selected_chara_id),
            table.concat(item.scalar_changes or {}, ", ")
        )
        index = index + 1

        local groups = {
            { label = "removed_entries", values = item.removed_entries },
            { label = "added_entries", values = item.added_entries },
            { label = "before_entries", values = item.before_info_name_lines },
            { label = "after_entries", values = item.after_info_name_lines },
            { label = "removed_refs", values = item.removed_refs },
            { label = "added_refs", values = item.added_refs },
            { label = "removed_ui_fields", values = item.removed_ui_fields },
            { label = "added_ui_fields", values = item.added_ui_fields },
            { label = "removed_list_ctrl_fields", values = item.removed_list_ctrl_fields },
            { label = "added_list_ctrl_fields", values = item.added_list_ctrl_fields },
            { label = "removed_chara_tab_fields", values = item.removed_chara_tab_fields },
            { label = "added_chara_tab_fields", values = item.added_chara_tab_fields },
            { label = "removed_ui_collections", values = item.removed_ui_collections },
            { label = "added_ui_collections", values = item.added_ui_collections },
            { label = "removed_list_ctrl_collections", values = item.removed_list_ctrl_collections },
            { label = "added_list_ctrl_collections", values = item.added_list_ctrl_collections },
        }

        for _, group in ipairs(groups) do
            if type(group.values) == "table" and #group.values > 0 then
                map[index] = string.format("%s | %s", tostring(group.label), table.concat(group.values, " || "))
                index = index + 1
            end
        end
    end

    return map
end

local function guild_flow_recent_fields_map(runtime)
    local data = runtime.guild_flow_research_data
    if data == nil then
        return {}
    end

    local map = {}
    for index, item in ipairs(data.recent_field_sets_for_log or {}) do
        local field_parts = {}
        local field_keys = {}
        for key, _ in pairs(item.fields or {}) do
            table.insert(field_keys, key)
        end
        table.sort(field_keys)

        for _, key in ipairs(field_keys) do
            table.insert(field_parts, tostring(key) .. "=" .. tostring(item.fields[key]))
        end

        map[index] = string.format(
            "%s | %s | %s | %s",
            tostring(item.time),
            tostring(item.ui_type),
            tostring(item.method),
            table.concat(field_parts, "; ")
        )
    end

    return map
end

local function guild_flow_registered_hooks_map(runtime)
    local data = runtime.guild_flow_research_data
    if data == nil then
        return {}
    end

    local map = {}
    for index, item in ipairs(data.registered_hooks or {}) do
        map[index] = tostring(item)
    end
    return map
end

local function guild_flow_registration_errors_map(runtime)
    local data = runtime.guild_flow_research_data
    if data == nil then
        return {}
    end

    local map = {}
    for index, item in ipairs(data.registration_errors or {}) do
        map[index] = tostring(item)
    end
    return map
end

local function append_guild_flow_sections(lines, runtime)
    write_section(lines, "guild_flow_research", guild_flow_research_map(runtime))
    write_section(lines, "guild_flow_context_alignment", guild_flow_context_alignment_map(runtime))
    write_section(lines, "guild_flow_trace_assessment", guild_flow_trace_assessment_map(runtime))
    write_section(lines, "guild_flow_trace_summary", guild_flow_trace_summary_map(runtime))
    write_section(lines, "guild_flow_unique_events", guild_flow_unique_events_map(runtime))
    write_section(lines, "guild_flow_unique_ui_observations", guild_flow_unique_ui_observations_map(runtime))
    write_section(lines, "guild_flow_targeted_ui_details", guild_flow_targeted_ui_details_map(runtime))
    write_section(lines, "guild_flow_targeted_ui_details_by_target", guild_flow_targeted_ui_details_by_target_map(runtime))
    write_section(lines, "guild_flow_setup_job_menu_contents_info", guild_flow_setup_job_menu_contents_info_map(runtime))
    write_section(lines, "guild_flow_setup_job_menu_comparison", guild_flow_setup_job_menu_comparison_map(runtime))
    write_section(lines, "guild_flow_character_type_gate", guild_flow_character_type_gate_map(runtime))
    write_section(lines, "guild_flow_hypothesis_matrix", guild_flow_hypothesis_matrix_map(runtime))
    write_section(lines, "guild_flow_player_job_list_override", guild_flow_player_job_list_override_map(runtime))
    write_section(lines, "guild_flow_source_probe_once", guild_flow_source_probe_once_map(runtime))
    write_section(lines, "guild_flow_aggressive_hook_session", guild_flow_aggressive_hook_session_map(runtime))
    write_section(lines, "guild_flow_job_info_pawn_override", guild_flow_job_info_pawn_override_map(runtime))
    write_section(lines, "guild_flow_source_method_snapshots", guild_flow_source_method_snapshots_map(runtime))
    write_section(lines, "guild_flow_prune_windows", guild_flow_prune_windows_map(runtime))
    write_section(lines, "guild_flow_prune_followups", guild_flow_prune_followups_map(runtime))
    write_section(lines, "guild_flow_prune_bypass_probe", guild_flow_prune_bypass_probe_map(runtime))
    write_section(lines, "guild_flow_post_prune_reinjection", guild_flow_post_prune_reinjection_map(runtime))
    write_section(lines, "guild_flow_manual_prune_rewrite", guild_flow_manual_prune_rewrite_map(runtime))
    write_section(lines, "guild_flow_multi_intervention_latest", guild_flow_multi_intervention_latest_map(runtime))
    write_section(lines, "guild_flow_multi_intervention_attempts", guild_flow_multi_intervention_attempts_map(runtime))
    write_section(lines, "guild_flow_source_rebuild_windows", guild_flow_source_rebuild_windows_map(runtime))
    write_section(lines, "guild_flow_source_state_windows", guild_flow_source_state_windows_map(runtime))
    write_section(lines, "guild_flow_active_ui", guild_flow_active_ui_map(runtime))
    write_section(lines, "guild_flow_recent_events", guild_flow_recent_events_map(runtime))
    write_section(lines, "guild_flow_recent_fields", guild_flow_recent_fields_map(runtime))
    write_section(lines, "guild_flow_registered_hooks", guild_flow_registered_hooks_map(runtime))
    write_section(lines, "guild_flow_registration_errors", guild_flow_registration_errors_map(runtime))
end

local function make_guild_trace_snapshot(runtime, discovery)
    local lines = {
        string.format("player=%s", util.describe_obj(runtime.player)),
        string.format("main_pawn_source=%s", tostring(discovery.main_pawn.source)),
        string.format("runtime_character_source=%s", tostring(discovery.main_pawn.character_source)),
    }

    write_section(lines, "hybrid_unlock_prototype", hybrid_unlock_prototype_map(runtime))
    append_guild_flow_sections(lines, runtime)

    return table.concat(lines, "\n")
end

local function make_discovery_snapshot(runtime, discovery, data)
    local effective_data = data or runtime.main_pawn_data
    local lines = {
        string.format("player=%s", util.describe_obj(runtime.player)),
        string.format("main_pawn_source=%s", tostring(discovery.main_pawn.source)),
        string.format("runtime_character_source=%s", tostring(discovery.main_pawn.character_source)),
        string.format("party_candidates=%s", tostring(discovery.main_pawn.candidate_count)),
    }

    if effective_data ~= nil then
        table.insert(lines, string.format("name=%s", tostring(effective_data.name)))
        table.insert(lines, string.format("pawn=%s", util.describe_obj(effective_data.pawn)))
        table.insert(lines, string.format("runtime_character=%s", util.describe_obj(effective_data.runtime_character)))
        table.insert(lines, string.format("game_object=%s", util.describe_obj(effective_data.object)))
        table.insert(lines, string.format("chara_id=%s", tostring(effective_data.chara_id)))
        table.insert(lines, string.format("job=%s", tostring(effective_data.current_job or effective_data.job)))
        table.insert(lines, string.format("weapon_job=%s", tostring(effective_data.weapon_job)))
        table.insert(lines, string.format("skill_state=%s", tostring(effective_data.skill_state)))
        table.insert(lines, string.format("full_node=%s", tostring(effective_data.full_node)))
        table.insert(lines, string.format("upper_node=%s", tostring(effective_data.upper_node)))
        table.insert(lines, string.format("human=%s", util.describe_obj(effective_data.human)))
        table.insert(lines, string.format("action_manager=%s", util.describe_obj(effective_data.action_manager)))
        table.insert(lines, string.format("motion=%s", util.describe_obj(effective_data.motion)))
        table.insert(lines, string.format("stamina_manager=%s", util.describe_obj(effective_data.stamina_manager)))

        write_section(lines, "pawn_candidate_paths", candidate_paths_map(discovery))
        write_section(lines, "pawn_stable_fields", effective_data.pawn_fields)
        write_section(lines, "pawn_ai_fields", effective_data.pawn_ai_fields)
        write_section(lines, "human_context_fields", effective_data.human_context_fields)
        write_section(lines, "knowledge_and_inclination_hints", effective_data.knowledge_hints)
        write_section(lines, "personality_fields", effective_data.personality_fields)
        write_section(lines, "personality_data_fields", effective_data.personality_data_fields)
        write_section(lines, "job_context_fields", effective_data.job_context_fields)
        write_section(lines, "skill_context_fields", effective_data.skill_context_fields)
        write_section(lines, "ai_goal_planning_fields", effective_data.ai_goal_planning_fields)
        write_section(lines, "decision_maker_fields", effective_data.decision_maker_fields)
        write_section(lines, "pawn_data_context_fields", effective_data.pawn_data_context_fields)
        write_section(lines, "decision_evaluation_module_fields", effective_data.decision_evaluation_module_fields)
        write_section(lines, "party_snapshot", party_snapshot_map(effective_data))
        write_section(lines, "progression_gate", progression_gate_map(runtime))
        write_section(lines, "progression_state_summary", progression_state_summary_map(runtime))
        write_section(lines, "progression_player_state", progression_actor_map(runtime.progression_state_data and runtime.progression_state_data.player or nil))
        write_section(lines, "progression_main_pawn_state", progression_actor_map(runtime.progression_state_data and runtime.progression_state_data.main_pawn or nil))
        write_section(lines, "progression_player_main_pawn_alignment", progression_alignment_map(runtime))
        write_section(lines, "progression_runtime_trace", progression_trace_map(runtime))
        write_section(lines, "progression_bit_mirror_probe", progression_probe_map(runtime))
        write_section(lines, "progression_runtime_trace_recent_events", progression_trace_recent_events_map(runtime))
        write_section(lines, "progression_runtime_trace_matrix", progression_trace_matrix_map(runtime))
        write_section(lines, "progression_runtime_trace_registration_errors", progression_trace_registration_errors_map(runtime))
        write_section(lines, "vocation_research", vocation_research_map(runtime))
        write_section(lines, "vocation_research_recent_events", vocation_research_recent_events_map(runtime))
        write_section(lines, "vocation_research_registration_errors", vocation_research_registration_errors_map(runtime))
        write_section(lines, "ability_research", ability_research_map(runtime))
        write_section(lines, "ability_research_recent_events", ability_research_recent_events_map(runtime))
        write_section(lines, "ability_research_registration_errors", ability_research_registration_errors_map(runtime))
       write_section(lines, "action_research", action_research_map(runtime))
       write_section(lines, "action_research_recent_events", action_research_recent_events_map(runtime))
       write_section(lines, "action_research_observed_packs", action_research_observed_packs_map(runtime))
     write_section(lines, "action_research_observed_request_actions", action_research_observed_request_actions_map(runtime))
     write_section(lines, "action_research_observed_decision_probes", action_research_observed_decision_probes_map(runtime))
     write_section(lines, "action_research_observed_decision_snapshots", action_research_observed_decision_snapshots_map(runtime))
     write_section(lines, "action_research_observed_ai_decision_snapshots", action_research_observed_ai_decision_snapshots_map(runtime))
     write_section(lines, "action_research_observed_ai_target_snapshots", action_research_observed_ai_target_snapshots_map(runtime))
     write_section(lines, "action_research_observed_decision_actionpack_snapshots", action_research_observed_decision_actionpack_snapshots_map(runtime))
     write_section(lines, "action_research_observed_decision_producer_snapshots", action_research_observed_decision_producer_snapshots_map(runtime))
     write_section(lines, "action_research_registration_errors", action_research_registration_errors_map(runtime))
        write_section(lines, "combat_research", combat_research_map(runtime))
        write_section(lines, "combat_research_recent_events", combat_research_recent_events_map(runtime))
        write_section(lines, "combat_research_registration_errors", combat_research_registration_errors_map(runtime))
        write_section(lines, "job_gate_correlation", job_gate_correlation_map(runtime))
        write_section(lines, "module_registry", module_registry_map(runtime))
        write_section(lines, "hybrid_unlock_research", hybrid_unlock_research_map(runtime))
        write_section(lines, "hybrid_unlock_prototype", hybrid_unlock_prototype_map(runtime))
        append_guild_flow_sections(lines, runtime)

        local progression = runtime.progression_gate_data
        if progression ~= nil then
            for _, line in ipairs(progression_job_map(progression.qualified_job_map, "qualified_job_bits_map")) do
                table.insert(lines, line)
            end
            for _, line in ipairs(progression_job_map(progression.viewed_job_map, "viewed_new_job_bits_map")) do
                table.insert(lines, line)
            end
            for _, line in ipairs(progression_job_map(progression.changed_job_map, "changed_job_bits_map")) do
                table.insert(lines, line)
            end
            for _, line in ipairs(progression_direct_table(progression.job_diagnostic_table, "direct_job_qualification_table")) do
                table.insert(lines, line)
            end
        end

        local player_job_context_fields, player_skill_context_fields = progression_context_fields_map(runtime)
        write_section(lines, "player_job_context_fields", player_job_context_fields)
        write_section(lines, "player_skill_context_fields", player_skill_context_fields)
    end

    return table.concat(lines, "\n")
end

local function should_log_snapshot(runtime, discovery, data)
    local effective_data = data or runtime.main_pawn_data
    if effective_data == nil then
        return false
    end

    if runtime.player == nil then
        return false
    end

    if discovery.main_pawn.source == "unresolved" then
        return false
    end

    if discovery.main_pawn.character_source == "unresolved" then
        return false
    end

    if effective_data.runtime_character == nil then
        return false
    end

    return true
end

function log.info(message)
    emit("INFO", message)
end

function log.warn(message)
    emit("WARN", message)
end

function log.debug(message)
    emit("DEBUG", message)
end

function log.error(message)
    emit("ERROR", message)
end

function log.get_file_status()
    return last_file_status
end

function log.get_session_status()
    return last_session_status
end

function log.bootstrap_probe()
    if not config.debug.write_discovery_file then
        update_file_status({
            enabled = false,
            attempted = false,
            ok = false,
            path = nil,
            reason = "disabled",
            gate = "disabled",
        })
        return
    end

    update_file_status({
        enabled = true,
        attempted = false,
        gate = "probe_pending",
    })

    ensure_parent_directory(config.debug.discovery_log_path)

    write_with_fallback(
        os.date("%Y-%m-%d %H:%M:%S") ..
        "\n" ..
        prefix("INFO") ..
        "bootstrap_probe version=" .. tostring(config.version) .. "\n\n"
    )
end

function log.session_bootstrap(runtime)
    if not config.debug.session_logging_enabled then
        last_session_status.enabled = false
        return
    end

    local session = get_session_state(runtime)
    local text_path, jsonl_path = resolve_session_paths(runtime)
    ensure_parent_directory(text_path)
    if config.debug.session_jsonl_enabled then
        ensure_parent_directory(jsonl_path)
    end
    queue_session_line(runtime, string.format("[session/bootstrap] session_id=%s", session.session_id))
    queue_session_line(runtime, string.format("[session/bootstrap] version=%s", tostring(config.version)))
    queue_session_line(runtime, string.format("[session/bootstrap] text_path=%s", tostring(text_path)))
    if config.debug.session_jsonl_enabled then
        queue_session_line(runtime, string.format("[session/bootstrap] jsonl_path=%s", tostring(jsonl_path)))
    end
    queue_session_event(
        runtime,
        "bootstrap",
        "session_started",
        {
            version = config.version,
            mod_name = config.mod_name,
            text_path = text_path,
            jsonl_path = config.debug.session_jsonl_enabled and jsonl_path or nil,
        },
        string.format("session=%s started", session.session_id)
    )
    flush_session_logs(runtime, "session_bootstrap", true)
end

function log.session_marker(runtime, category, name, payload, line)
    if not config.debug.session_logging_enabled then
        return
    end

    queue_session_event(runtime, category or "system", name or "marker", payload or {}, line)
    flush_session_logs(runtime, "session_marker", true)
end

function log.talk_event_marker(runtime, payload, line)
    if not config.debug.session_logging_enabled then
        return
    end

    log.session_marker(runtime, "dialogue", "talk_event_runtime_marker", payload or {}, line)
end

function log.session_shutdown(runtime, reason, payload)
    if not config.debug.session_logging_enabled then
        return
    end

    local effective_payload = payload or {}
    effective_payload.reason = tostring(reason or "unknown")
    log.session_marker(
        runtime,
        "system",
        "session_shutdown_attempt",
        effective_payload,
        string.format("reason=%s", tostring(reason or "unknown"))
    )
end

function log.discovery_snapshot(runtime, discovery, data)
    record_session_domains(runtime, discovery)

    if not config.debug.write_discovery_file then
        update_file_status({
            enabled = false,
            attempted = false,
            ok = false,
            path = nil,
            reason = "disabled",
            gate = "disabled",
        })
        return
    end

    update_file_status({
        enabled = true,
    })

    if not should_log_snapshot(runtime, discovery, data) then
        update_file_status({
            attempted = false,
            gate = "snapshot_not_ready",
            last_discovery_gate = "snapshot_not_ready",
            last_discovery_reason = "snapshot_not_ready",
        })
        return
    end

    local snapshot = make_discovery_snapshot(runtime, discovery, data)
    if snapshot == last_discovery_snapshot then
        update_file_status({
            attempted = false,
            gate = "unchanged_snapshot",
            last_discovery_gate = "unchanged_snapshot",
            last_discovery_reason = "unchanged_snapshot",
        })
        return
    end

    last_discovery_snapshot = snapshot
    local ok = write_with_fallback(os.date("%Y-%m-%d %H:%M:%S") .. "\n" .. snapshot .. "\n\n")
    update_file_status({
        last_discovery_gate = ok and "written" or "write_failed",
        last_discovery_reason = ok and "written" or "write_failed",
    })
end

function log.guild_trace(runtime, discovery)
    record_session_domains(runtime, discovery)

    if not config.debug.write_discovery_file then
        return
    end

    local guild_flow = runtime.guild_flow_research_data
    if guild_flow == nil then
        update_file_status({
            last_guild_event_reason = "guild_trace_unavailable",
            last_guild_event_ok = false,
        })
        return
    end

    if not guild_flow.guild_ui_hint then
        update_file_status({
            last_guild_event_reason = "guild_hint_missing",
            last_guild_event_ok = false,
        })
        return
    end

    if guild_flow.trace_dirty == false and last_guild_trace_signature ~= nil then
        update_file_status({
            last_guild_event_reason = "guild_trace_clean",
            last_guild_event_ok = false,
        })
        return
    end

    local trace_snapshot = make_guild_trace_snapshot(runtime, discovery)
    if trace_snapshot == last_guild_trace_signature then
        if guild_flow ~= nil then
            guild_flow.trace_dirty = false
        end
        update_file_status({
            last_guild_event_reason = "unchanged_guild_trace",
            last_guild_event_ok = false,
        })
        return
    end

    last_guild_trace_signature = trace_snapshot
    local ok = write_with_fallback(
        os.date("%Y-%m-%d %H:%M:%S") ..
        "\n" ..
        "[guild_trace]\n" ..
        trace_snapshot ..
        "\n\n"
    )

    if guild_flow ~= nil then
        guild_flow.trace_dirty = not ok
    end

    update_file_status({
        last_guild_event_reason = ok and "written" or "write_failed",
        last_guild_event_ok = ok and true or false,
    })
end

return log

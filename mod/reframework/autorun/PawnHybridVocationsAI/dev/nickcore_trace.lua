local config = require("PawnHybridVocationsAI/config")
local log = require("PawnHybridVocationsAI/core/log")
local state = require("PawnHybridVocationsAI/core/runtime")
local access = require("PawnHybridVocationsAI/core/access")
local main_pawn_properties = require("PawnHybridVocationsAI/game/main_pawn_properties")

local nickcore_trace = {}

local GLOBAL_KEY = "__phvai_nickcore_trace_v1"
local SIGURD_CHARA_ID = 1108605478

local runtime_state = rawget(_G, GLOBAL_KEY) or {
    initialized = false,
    unavailable_logged = false,
    session_id = nil,
    relative_path = nil,
    summary_relative_path = nil,
    file_handle = nil,
    callbacks_registered = false,
    action_callback = nil,
    execute_callback = nil,
    summary = nil,
}
rawset(_G, GLOBAL_KEY, runtime_state)

local function trace_config()
    return config.debug or {}
end

local function is_enabled()
    return trace_config().nickcore_trace_enabled == true
end

local util = access
local call_first = access.call_first
local field_first = access.field_first
local resolve_pack_path = access.resolve_pack_path
local resolve_pack_name = access.resolve_pack_name

local function escape_regex(text)
    return tostring(text):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

local function build_glob_pattern(prefix)
    local directory = tostring(trace_config().nickcore_trace_directory or "PawnHybridVocationsAI/logs"):gsub("/", "\\")
    return "^" .. escape_regex(directory) .. [[\\]] .. escape_regex(prefix) .. [[_.*$]]
end

local function extract_sort_key(relative_path)
    local stamp = tostring(relative_path):match("_(%d%d%d%d%d%d%d%d_%d%d%d%d%d%d)")
    if stamp ~= nil then
        return stamp
    end

    return tostring(relative_path)
end

local function remove_relative_file(relative_path)
    if type(relative_path) ~= "string" or relative_path == "" then
        return false
    end

    local normalized = relative_path:gsub("/", "\\")
    if not normalized:match("^PawnHybridVocationsAI\\logs\\") then
        return false
    end

    local game_relative_path = "reframework\\data\\" .. normalized
    local ok, result = pcall(os.remove, game_relative_path)
    return ok and result == true
end

local function prune_old_logs(prefix)
    local max_files = tonumber(trace_config().nickcore_trace_max_files) or 8
    if max_files <= 0 or fs == nil or type(fs.glob) ~= "function" then
        return
    end

    local matched = fs.glob(build_glob_pattern(prefix))
    local existing = {}
    for _, relative_path in ipairs(matched or {}) do
        existing[#existing + 1] = tostring(relative_path)
    end

    local keep_existing = math.max(max_files - 1, 0)
    if #existing <= keep_existing then
        return
    end

    table.sort(existing, function(left, right)
        local left_key = extract_sort_key(left)
        local right_key = extract_sort_key(right)
        if left_key == right_key then
            return left < right
        end
        return left_key < right_key
    end)

    for index = 1, (#existing - keep_existing) do
        remove_relative_file(existing[index])
    end
end

local function close_file()
    if runtime_state.file_handle ~= nil then
        pcall(function()
            runtime_state.file_handle:flush()
            runtime_state.file_handle:close()
        end)
        runtime_state.file_handle = nil
    end
end

local function has_callback(callbacks, needle)
    if type(callbacks) ~= "table" or type(needle) ~= "function" then
        return false
    end

    for _, callback in ipairs(callbacks) do
        if callback == needle then
            return true
        end
    end

    return false
end

local function reset_summary()
    runtime_state.summary = {
        tag = "nickcore_job07_trace",
        generated_at = os.date("%Y-%m-%d %H:%M:%S"),
        event_count = 0,
        action_request_count = 0,
        execute_ai_count = 0,
        by_actor_role = {},
        by_job = {},
        request_action_nodes = {},
        request_action_nodes_by_actor = {},
        execute_ai_packs = {},
        execute_ai_packs_by_actor = {},
        observed_actor_ids = {},
    }
end

local function ensure_file_open()
    if runtime_state.file_handle ~= nil then
        return true
    end

    local directory = tostring(trace_config().nickcore_trace_directory or "PawnHybridVocationsAI/logs")
    local prefix = tostring(trace_config().nickcore_trace_prefix or "PawnHybridVocationsAI.nicktrace")
    local summary_prefix = tostring(trace_config().nickcore_trace_summary_prefix or "PawnHybridVocationsAI.nicktrace_summary")

    prune_old_logs(prefix)
    prune_old_logs(summary_prefix)

    runtime_state.session_id = os.date("%Y%m%d_%H%M%S")
    runtime_state.relative_path = string.format("%s/%s_%s.log", directory, prefix, runtime_state.session_id)
    runtime_state.summary_relative_path = string.format("%s/%s_%s.json", directory, summary_prefix, runtime_state.session_id)

    local handle = io.open(runtime_state.relative_path, "a")
    if handle == nil then
        log.warn(string.format("NickCore tracer failed to open log file: %s", tostring(runtime_state.relative_path)))
        runtime_state.relative_path = nil
        runtime_state.summary_relative_path = nil
        return false
    end

    runtime_state.file_handle = handle
    if runtime_state.summary == nil then
        reset_summary()
    end

    runtime_state.file_handle:write(string.format("[PHVAI_NICKTRACE][INFO] Session started %s\n", os.date("%Y-%m-%d %H:%M:%S")))
    runtime_state.file_handle:flush()
    return true
end

local function format_scalar(value)
    if value == nil then
        return "nil"
    end

    local value_type = type(value)
    if value_type == "string" then
        return string.format("%q", value)
    end
    if value_type == "boolean" then
        return value and "true" or "false"
    end

    return tostring(value)
end

local function write_line(kind, payload)
    if not ensure_file_open() then
        return
    end

    local keys = {}
    for key, _ in pairs(payload or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)

    local parts = {
        string.format("[PHVAI_NICKTRACE][%s]", tostring(kind)),
    }

    for _, key in ipairs(keys) do
        parts[#parts + 1] = string.format("%s=%s", tostring(key), format_scalar(payload[key]))
    end

    runtime_state.file_handle:write(table.concat(parts, " ") .. "\n")
    runtime_state.file_handle:flush()
end

local function bump(counter, key)
    local normalized = tostring(key or "nil")
    counter[normalized] = (counter[normalized] or 0) + 1
end

local function bump_nested(counter, outer_key, inner_key)
    local outer = tostring(outer_key or "nil")
    counter[outer] = counter[outer] or {}
    bump(counter[outer], inner_key)
end

local function resolve_player()
    if util.is_valid_obj(state.runtime.player) then
        return state.runtime.player
    end

    local character_manager = util.safe_singleton("managed", "app.CharacterManager")
    return field_first(character_manager, {
        "<ManualPlayer>k__BackingField",
        "_ManualPlayer",
        "ManualPlayer",
    }) or call_first(character_manager, {
        "get_ManualPlayer()",
        "get_ManualPlayer",
    })
end

local function resolve_runtime_character(pawn)
    if util.is_valid_obj(pawn) and util.is_a(pawn, "app.Character") then
        return pawn
    end

    return call_first(pawn, {
        "get_CachedCharacter()",
        "get_Character()",
        "get_Chara()",
        "get_PawnCharacter()",
    }) or field_first(pawn, {
        "<CachedCharacter>k__BackingField",
        "<Character>k__BackingField",
        "<Chara>k__BackingField",
        "Character",
        "Chara",
    })
end

local function resolve_main_pawn_runtime_character()
    local main_pawn_data = main_pawn_properties.get_resolved_main_pawn_data(
        state.runtime,
        "nickcore_trace_main_pawn_data_unresolved"
    )
    if main_pawn_data ~= nil and util.is_valid_obj(main_pawn_data.runtime_character) then
        return main_pawn_data.runtime_character
    end

    local pawn_manager = util.safe_singleton("managed", "app.PawnManager")
    local main_pawn = call_first(pawn_manager, {
        "get_MainPawn()",
        "get_MainPawn",
    }) or field_first(pawn_manager, {
        "_MainPawn",
        "<MainPawn>k__BackingField",
    })

    return resolve_runtime_character(main_pawn)
end

local function resolve_human(character)
    return call_first(character, {
        "get_Human()",
        "get_Human",
    }) or field_first(character, {
        "<Human>k__BackingField",
        "Human",
    })
end

local function resolve_job_context(human)
    return field_first(human, {
        "<JobContext>k__BackingField",
        "JobContext",
    }) or call_first(human, {
        "get_JobContext()",
        "get_JobContext",
    })
end

local function resolve_current_job(character)
    local human = resolve_human(character)
    local current_job = field_first(human, {
        "<CurrentJob>k__BackingField",
        "CurrentJob",
    }) or call_first(human, {
        "get_CurrentJob()",
        "get_CurrentJob",
    })
    if current_job ~= nil then
        return tonumber(current_job)
    end

    local job_context = resolve_job_context(human)
    current_job = field_first(job_context, {
        "CurrentJob",
    }) or call_first(job_context, {
        "get_CurrentJob()",
        "get_CurrentJob",
    })
    if current_job ~= nil then
        return tonumber(current_job)
    end

    current_job = field_first(character, {
        "Job",
    }) or call_first(character, {
        "get_CurrentJob()",
        "get_CurrentJob",
        "get_Job()",
        "get_Job",
    })
    return tonumber(current_job)
end

local function resolve_chara_id(character)
    return call_first(character, {
        "get_CharaIDString()",
        "get_CharaIDString",
        "get_CharaID()",
        "get_CharaID",
    }) or field_first(character, {
        "CharaID",
        "<CharaID>k__BackingField",
    })
end

local function resolve_actor_name(character)
    local game_object = util.resolve_game_object(character, false)
    return call_first(game_object, {
        "get_Name()",
        "get_Name",
    })
end

local function is_party_pawn(human)
    local value = util.safe_method(human, "isPlayerOrPartyPawn()")
    if value ~= nil then
        return value == true
    end

    value = util.safe_method(human, "isPlayerOrPartyPawn")
    return value == true
end

local function classify_actor(character)
    if not util.is_valid_obj(character) then
        return nil
    end

    local chara_id = resolve_chara_id(character)
    local job = resolve_current_job(character)
    local human = resolve_human(character)
    local main_pawn = resolve_main_pawn_runtime_character()
    local player = resolve_player()

    local actor_role = "other"
    if util.same_object(character, main_pawn) then
        actor_role = "main_pawn"
    elseif util.same_object(character, player) then
        actor_role = "player"
    elseif tonumber(chara_id) == SIGURD_CHARA_ID then
        actor_role = "sigurd"
    elseif job == 7 then
        actor_role = is_party_pawn(human) and "party_pawn_job07" or "job07_other"
    end

    if actor_role == "other" then
        return nil
    end

    return {
        actor_role = actor_role,
        current_job = job,
        chara_id = chara_id ~= nil and tostring(chara_id) or "nil",
        actor_name = tostring(resolve_actor_name(character) or "nil"),
        actor_type = tostring(util.get_type_full_name(character) or "nil"),
        actor_desc = util.describe_obj(character),
    }
end

local function record_event(kind, actor_meta, payload)
    if runtime_state.summary == nil then
        reset_summary()
    end

    runtime_state.summary.event_count = runtime_state.summary.event_count + 1
    bump(runtime_state.summary.by_actor_role, actor_meta.actor_role)
    bump(runtime_state.summary.by_job, actor_meta.current_job)
    bump(runtime_state.summary.observed_actor_ids, string.format("%s:%s", actor_meta.actor_role, actor_meta.chara_id))

    local line_payload = {
        ts = os.date("%Y-%m-%d %H:%M:%S"),
        clock = string.format("%.3f", tonumber(os.clock()) or 0.0),
        actor_role = actor_meta.actor_role,
        current_job = actor_meta.current_job,
        chara_id = actor_meta.chara_id,
        actor_name = actor_meta.actor_name,
        actor_type = actor_meta.actor_type,
        actor_desc = actor_meta.actor_desc,
    }

    for key, value in pairs(payload or {}) do
        line_payload[key] = value
    end

    if kind == "ACTION" then
        runtime_state.summary.action_request_count = runtime_state.summary.action_request_count + 1
        bump(runtime_state.summary.request_action_nodes, payload and payload.node or "nil")
        bump_nested(runtime_state.summary.request_action_nodes_by_actor, actor_meta.actor_role, payload and payload.node or "nil")
    elseif kind == "EXECUTE" then
        runtime_state.summary.execute_ai_count = runtime_state.summary.execute_ai_count + 1
        bump(runtime_state.summary.execute_ai_packs, payload and payload.pack_path or "nil")
        bump_nested(runtime_state.summary.execute_ai_packs_by_actor, actor_meta.actor_role, payload and payload.pack_path or "nil")
    end

    write_line(kind, line_payload)
end

local function on_pre_action_request(_, data)
    local actor_meta = classify_actor(data and data.character)
    if actor_meta == nil then
        return false
    end

    record_event("ACTION", actor_meta, {
        event = "requestActionCore",
        node = tostring(data and data.node or "nil"),
        layer = tonumber(data and data.layer),
        priority = tonumber(data and data.priority),
    })
    return false
end

local function on_pre_execute_ai(data)
    local actor_meta = classify_actor(data and data.character)
    if actor_meta == nil then
        return false
    end

    local pack_data = data and data.packData or nil
    record_event("EXECUTE", actor_meta, {
        event = "setBBValuesToExecuteActInter",
        pack_path = tostring(resolve_pack_path(pack_data) or "nil"),
        pack_name = tostring(resolve_pack_name(pack_data) or "nil"),
        pack_type = tostring(util.get_type_full_name(pack_data) or "nil"),
        pack_desc = util.describe_obj(pack_data),
    })
    return false
end

local function safe_action_callback(args, data)
    local ok, result = pcall(on_pre_action_request, args, data)
    if not ok then
        log.warn(string.format("NickCore tracer ACTION callback failed: %s", tostring(result)))
    end
    return result == true
end

local function safe_execute_callback(data)
    local ok, result = pcall(on_pre_execute_ai, data)
    if not ok then
        log.warn(string.format("NickCore tracer EXECUTE callback failed: %s", tostring(result)))
    end
    return result == true
end

function nickcore_trace.init()
    if runtime_state.initialized or not is_enabled() then
        return
    end

    local ok_fns, fns = pcall(require, "_NickCore/Functions")
    if not ok_fns or type(fns) ~= "table" then
        if not runtime_state.unavailable_logged then
            log.info("NickCore tracer is enabled but _NickCore is not available; skipping dev trace hooks")
            runtime_state.unavailable_logged = true
        end
        return
    end

    reset_summary()
    ensure_file_open()

    if runtime_state.action_callback == nil then
        runtime_state.action_callback = safe_action_callback
    end
    if runtime_state.execute_callback == nil then
        runtime_state.execute_callback = safe_execute_callback
    end

    if not has_callback(fns.on_pre_action_request, runtime_state.action_callback) then
        table.insert(fns.on_pre_action_request, runtime_state.action_callback)
    end
    if not has_callback(fns.on_pre_execute_ai, runtime_state.execute_callback) then
        table.insert(fns.on_pre_execute_ai, runtime_state.execute_callback)
    end
    runtime_state.callbacks_registered = true

    runtime_state.initialized = true
    log.info(string.format(
        "NickCore tracer enabled: events -> %s summary -> %s",
        tostring(runtime_state.relative_path),
        tostring(runtime_state.summary_relative_path)
    ))
end

function nickcore_trace.shutdown()
    if runtime_state.summary ~= nil and runtime_state.summary_relative_path ~= nil then
        runtime_state.summary.generated_at = os.date("%Y-%m-%d %H:%M:%S")
        pcall(json.dump_file, runtime_state.summary_relative_path, runtime_state.summary)
    end

    if runtime_state.file_handle ~= nil then
        runtime_state.file_handle:write(string.format("[PHVAI_NICKTRACE][INFO] Session closed %s\n", os.date("%Y-%m-%d %H:%M:%S")))
        runtime_state.file_handle:flush()
    end

    close_file()
    runtime_state.initialized = false
end

return nickcore_trace

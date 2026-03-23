local state = require("PawnHybridVocationsAI/state")
local log = require("PawnHybridVocationsAI/core/log")
local util = require("PawnHybridVocationsAI/core/util")

local talk_event_trace = {}

local function get_trace(runtime)
    runtime.talk_event_trace_data = runtime.talk_event_trace_data or {
        event_count = 0,
        last_signature = nil,
        last_entry = nil,
        history = {},
    }
    return runtime.talk_event_trace_data
end

local function classify_talk_event_id(event_id)
    if event_id == nil then
        return "unknown", "unknown"
    end
    if event_id == 1936 then
        return "pawn_dialogue", "pawn_related"
    end
    if event_id == 1926 then
        return "vocation_guild", "guild_related"
    end
    if event_id == 1914 then
        return "inn_storage", "storage_related"
    end
    return "event_" .. tostring(event_id), "other"
end

local function character_summary(obj)
    local managed = obj
    if type(obj) == "userdata" then
        managed = sdk.to_managed_object(obj) or obj
    end
    if not util.is_valid_obj(managed) then
        return nil
    end

    local game_object = util.safe_method(managed, "get_GameObject")
    return {
        description = util.describe_obj(managed),
        type_name = util.get_type_full_name(managed),
        chara_id = util.safe_method(managed, "get_CharaID"),
        name = game_object and util.safe_method(game_object, "get_Name") or nil,
        object = game_object and util.describe_obj(game_object) or nil,
        human = util.describe_obj(util.safe_method(managed, "get_Human")),
    }
end

local function compact_history_entry(entry)
    return {
        hook_name = entry.hook_name,
        phase = entry.phase,
        event_id = entry.event_id,
        event_label = entry.event_label,
        event_kind = entry.event_kind,
        object = entry.object,
        speaker = entry.speaker and {
            chara_id = entry.speaker.chara_id,
            name = entry.speaker.name,
            type_name = entry.speaker.type_name,
        } or nil,
        listener = entry.listener and {
            chara_id = entry.listener.chara_id,
            name = entry.listener.name,
            type_name = entry.listener.type_name,
        } or nil,
        player_matches_speaker = entry.player_matches_speaker,
        player_matches_listener = entry.player_matches_listener,
        main_pawn_matches_speaker = entry.main_pawn_matches_speaker,
        main_pawn_matches_listener = entry.main_pawn_matches_listener,
        quest_id = entry.quest_id,
        current_scene_name = entry.current_scene_name,
        current_state = entry.current_state,
        current_window = entry.current_window,
        active_ui_type = entry.active_ui_type,
    }
end

local function append_talk_event(runtime, entry)
    local trace = get_trace(runtime)
    local main_pawn_data = runtime.main_pawn_data
    local player_chara_id = runtime.player and util.safe_method(runtime.player, "get_CharaID") or nil
    local main_pawn_chara_id = main_pawn_data and main_pawn_data.chara_id or nil

    entry.player_matches_speaker = entry.speaker ~= nil and tostring(entry.speaker.chara_id) == tostring(player_chara_id) or false
    entry.player_matches_listener = entry.listener ~= nil and tostring(entry.listener.chara_id) == tostring(player_chara_id) or false
    entry.main_pawn_matches_speaker = entry.speaker ~= nil and tostring(entry.speaker.chara_id) == tostring(main_pawn_chara_id) or false
    entry.main_pawn_matches_listener = entry.listener ~= nil and tostring(entry.listener.chara_id) == tostring(main_pawn_chara_id) or false

    local guild_flow = runtime.guild_flow_research_data
    entry.current_scene_name = guild_flow and guild_flow.current_scene_name or nil
    entry.current_state = guild_flow and guild_flow.current_state or nil
    entry.current_window = guild_flow and guild_flow.current_window or nil
    entry.active_ui_type = guild_flow and guild_flow.active_ui_type or nil

    local signature = table.concat({
        tostring(entry.hook_name),
        tostring(entry.phase),
        tostring(entry.event_id),
        tostring(entry.event_label),
        tostring(entry.event_kind),
        tostring(entry.speaker and entry.speaker.chara_id or "nil"),
        tostring(entry.listener and entry.listener.chara_id or "nil"),
        tostring(entry.quest_id),
        tostring(entry.current_scene_name),
        tostring(entry.current_state),
        tostring(entry.current_window),
        tostring(entry.active_ui_type),
    }, "|")

    trace.event_count = (trace.event_count or 0) + 1
    trace.last_entry = entry
    table.insert(trace.history, 1, compact_history_entry(entry))
    while #trace.history > 8 do
        table.remove(trace.history)
    end

    if signature ~= trace.last_signature then
        trace.last_signature = signature
        log.talk_event_marker(
            runtime,
            compact_history_entry(entry),
            string.format(
                "hook=%s phase=%s event_id=%s label=%s",
                tostring(entry.hook_name),
                tostring(entry.phase),
                tostring(entry.event_id),
                tostring(entry.event_label)
            )
        )
    end
end

local function hook_method(type_name, method_name, pre_fn, post_fn)
    local td = util.safe_sdk_typedef(type_name)
    local method = td and td:get_method(method_name) or nil
    if method == nil then
        log.info(string.format("TalkEvent hook skipped: %s::%s", tostring(type_name), tostring(method_name)))
        return
    end

    local ok, err = pcall(sdk.hook, method, pre_fn, post_fn)
    if not ok then
        log.warn(string.format("TalkEvent hook failed: %s::%s (%s)", tostring(type_name), tostring(method_name), tostring(err)))
    end
end

function talk_event_trace.install_hooks()
    hook_method(
        "app.TalkEventManager",
        "selectTalkEvent(app.Character, app.Character, System.Collections.Generic.Dictionary`2<app.CharacterID,app.Character>)",
        nil,
        function(retval)
            local event_id = tonumber(sdk.to_int64(retval))
            local event_label, event_kind = classify_talk_event_id(event_id)
            append_talk_event(state.runtime, {
                hook_name = "TalkEventManager.selectTalkEvent",
                phase = "post",
                event_id = event_id,
                event_label = event_label,
                event_kind = event_kind,
            })
            return retval
        end
    )

    hook_method(
        "app.TalkEventManager",
        "requestPlay(System.Object, app.TalkEventDefine.ID, app.Character, app.Character, System.Collections.Generic.Dictionary`2<app.CharacterID,app.Character>, System.Action, System.Action, System.Action, app.Job05Tackle.MotInfo[], System.Boolean, System.Boolean, System.Boolean)",
        function(args)
            local event_id = tonumber(sdk.to_int64(args[4]))
            local event_label, event_kind = classify_talk_event_id(event_id)
            append_talk_event(state.runtime, {
                hook_name = "TalkEventManager.requestPlay",
                phase = "pre",
                event_id = event_id,
                event_label = event_label,
                event_kind = event_kind,
                object = util.describe_obj(sdk.to_managed_object(args[3])),
                speaker = character_summary(args[5]),
                listener = character_summary(args[6]),
            })
        end,
        nil
    )

    hook_method(
        "app.SpeechController",
        "requestSpeech(app.TalkEventDefine.ID, app.Character, app.Character, System.Collections.Generic.List`1<app.Character>, System.Boolean)",
        function(args)
            local event_id = tonumber(sdk.to_int64(args[3]))
            local event_label, event_kind = classify_talk_event_id(event_id)
            append_talk_event(state.runtime, {
                hook_name = "SpeechController.requestSpeech",
                phase = "pre",
                event_id = event_id,
                event_label = event_label,
                event_kind = event_kind,
                speaker = character_summary(args[4]),
                listener = character_summary(args[5]),
            })
        end,
        nil
    )

    hook_method(
        "app.TalkEventPlayer",
        "startJobChangeNode()",
        function(args)
            local this_obj = sdk.to_managed_object(args[2])
            append_talk_event(state.runtime, {
                hook_name = "TalkEventPlayer.startJobChangeNode",
                phase = "pre",
                event_id = 1926,
                event_label = "vocation_guild",
                event_kind = "guild_related",
                quest_id = util.safe_field(this_obj, "_QuestId"),
                object = util.describe_obj(this_obj),
            })
        end,
        nil
    )
end

return talk_event_trace

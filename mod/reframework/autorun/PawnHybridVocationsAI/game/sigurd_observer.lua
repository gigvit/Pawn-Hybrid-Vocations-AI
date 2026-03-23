local config = require("PawnHybridVocationsAI/config")
local util = require("PawnHybridVocationsAI/core/util")
local log = require("PawnHybridVocationsAI/core/log")

local sigurd_observer = {}

local gui_base_name_method = nil
local SIGURD_CHARA_ID = config.npc_spawn.sigurd_chara_id or 1108605478

local function bind_runtime_data(runtime, data)
    -- Keep a dedicated runtime handle for actor tracing while preserving legacy state storage.
    runtime.sigurd_observer_data = data
end

local function get_npc_manager()
    return util.safe_singleton("managed", "app.NPCManager")
end

local function get_character_list_holder()
    return util.safe_singleton("managed", "app.CharacterListHolder")
end

local function get_gui_base_name_method()
    if gui_base_name_method ~= nil then
        return gui_base_name_method
    end

    local gui_base_type = util.safe_sdk_typedef("app.GUIBase")
    if gui_base_type == nil then
        return nil
    end

    gui_base_name_method = gui_base_type:get_method("getName(app.CharacterID)")
    return gui_base_name_method
end

local function get_character_name(character_id)
    local method = get_gui_base_name_method()
    if method == nil or character_id == nil then
        return nil
    end

    local ok, value = pcall(function()
        return method:call(nil, character_id)
    end)
    if not ok then
        return nil
    end

    return value
end

local function compute_distance_to_player(runtime, game_object, holder)
    local player = runtime.player
    if not util.is_valid_obj(player) then
        return nil
    end

    local player_transform = util.safe_method(player, "get_Transform")
    local player_position = util.safe_method(player_transform, "get_Position")
    if player_position == nil then
        return nil
    end

    local target_position = nil
    if util.is_valid_obj(game_object) then
        local target_transform = util.safe_method(game_object, "get_Transform")
        target_position = util.safe_method(target_transform, "get_Position")
            or util.safe_method(target_transform, "get_UniversalPosition")
    end
    if target_position == nil and holder ~= nil then
        target_position = util.safe_method(holder, "get_UniversalPosition")
    end
    if target_position == nil then
        return nil
    end

    local ok, distance = pcall(function()
        return (player_position - target_position):length()
    end)
    if ok then
        return distance
    end

    return nil
end

local function clear_sigurd_fields(data)
    data.sigurd_last_seen_address = nil
    data.sigurd_last_seen_character = nil
    data.sigurd_last_seen_npc_data = nil
    data.sigurd_last_seen_name = nil
    data.sigurd_last_seen_job = nil
    data.sigurd_last_seen_distance = nil
    data.sigurd_last_seen_source = nil
    data.sigurd_last_seen_holder = nil
    data.sigurd_character_obj = nil
    data.sigurd_game_object_obj = nil
    data.sigurd_human_obj = nil
end

local function mark_sigurd_found(runtime, data, source, holder, chara_id, character, game_object, npc_data, npc_name, current_job, distance)
    data.sigurd_found_count = data.sigurd_found_count + 1
    data.sigurd_last_status = "found_loaded"
    data.sigurd_last_error = "<none>"
    data.sigurd_last_seen_address = util.is_valid_obj(game_object) and game_object:get_address() or nil
    data.sigurd_last_seen_character = util.describe_obj(character)
    data.sigurd_last_seen_npc_data = util.describe_obj(npc_data)
    data.sigurd_last_seen_name = npc_name or "<unnamed>"
    data.sigurd_last_seen_job = current_job
    data.sigurd_last_seen_distance = distance
    data.sigurd_last_seen_source = source
    data.sigurd_last_seen_holder = util.describe_obj(holder)
    data.sigurd_character_obj = character
    data.sigurd_game_object_obj = game_object
    data.sigurd_human_obj = util.safe_method(character, "get_Human") or character

    log.session_marker(runtime, "npc", "sigurd_found_loaded", {
        source = source,
        chara_id = chara_id,
        holder = util.describe_obj(holder),
        character = util.describe_obj(character),
        game_object = util.describe_obj(game_object),
        game_object_address = data.sigurd_last_seen_address,
        npc_data = data.sigurd_last_seen_npc_data,
        npc_name = data.sigurd_last_seen_name,
        current_job = current_job,
        distance = distance,
    }, string.format("source=%s name=%s job=%s go=0x%X", tostring(source), tostring(data.sigurd_last_seen_name), tostring(current_job), tonumber(data.sigurd_last_seen_address or 0)))
    return true
end

local function iter_taskguide_followers(npc_manager)
    local dict = util.safe_field(npc_manager, "TaskGuideFollowIdleNPCDict")
    if dict == nil then
        return nil, "taskguide_dict_unresolved"
    end

    local items = util.dictionary_values(dict, 256)
    if #items == 0 then
        return nil, "taskguide_enumerator_unresolved"
    end

    return items, nil
end

function sigurd_observer.bind_runtime_data(runtime, data)
    bind_runtime_data(runtime, data)
    return data
end

function sigurd_observer.lookup_loaded(runtime, data)
    bind_runtime_data(runtime, data)

    local holder = get_character_list_holder()
    local npc_manager = get_npc_manager()

    data.sigurd_lookup_count = data.sigurd_lookup_count + 1
    data.sigurd_last_status = "searching"
    data.sigurd_last_error = "<none>"

    log.session_marker(runtime, "npc", "sigurd_lookup_started", {
        lookup_count = data.sigurd_lookup_count,
        sigurd_chara_id = SIGURD_CHARA_ID,
    }, string.format("lookup=%s chara_id=%s", tostring(data.sigurd_lookup_count), tostring(SIGURD_CHARA_ID)))

    if holder == nil then
        data.sigurd_last_status = "failed"
        data.sigurd_last_error = "character_list_holder_unresolved"
        log.session_marker(runtime, "npc", "sigurd_lookup_failed", {
            error = data.sigurd_last_error,
        }, data.sigurd_last_error)
        return false
    end

    local all_characters = util.safe_method(holder, "getAllCharacters")
    local count = all_characters and util.safe_method(all_characters, "get_Count") or 0
    if all_characters == nil or count == nil then
        data.sigurd_last_status = "failed"
        data.sigurd_last_error = "character_list_unresolved"
        log.session_marker(runtime, "npc", "sigurd_lookup_failed", {
            error = data.sigurd_last_error,
        }, data.sigurd_last_error)
        return false
    end

    for index = 0, count - 1 do
        local character = util.safe_method(all_characters, "get_Item", index)
        local chara_id = util.safe_method(character, "get_CharaID")
        if chara_id == SIGURD_CHARA_ID then
            local game_object = util.safe_method(character, "get_GameObject")
            local npc_data = npc_manager and util.safe_method(npc_manager, "getNPCData(System.UInt32)", chara_id) or util.safe_method(npc_manager, "getNPCData", chara_id)
            local npc_name = util.safe_method(npc_data, "get_Name")
            local current_job = util.safe_method(character, "get_CurrentJob")
            local distance = compute_distance_to_player(runtime, game_object, character)

            return mark_sigurd_found(runtime, data, "character_list_holder", character, chara_id, character, game_object, npc_data, npc_name, current_job, distance)
        end
    end

    data.sigurd_last_status = "not_loaded"
    data.sigurd_last_error = "sigurd_not_loaded"
    clear_sigurd_fields(data)
    log.session_marker(runtime, "npc", "sigurd_not_loaded", {
        chara_id = SIGURD_CHARA_ID,
        party_size = count,
    }, string.format("chara_id=%s not loaded", tostring(SIGURD_CHARA_ID)))
    return false
end

function sigurd_observer.lookup_npc_manager(runtime, data)
    bind_runtime_data(runtime, data)

    local npc_manager = get_npc_manager()

    data.sigurd_lookup_count = data.sigurd_lookup_count + 1
    data.sigurd_last_status = "searching_npc_manager"
    data.sigurd_last_error = "<none>"

    log.session_marker(runtime, "npc", "sigurd_npc_manager_lookup_started", {
        lookup_count = data.sigurd_lookup_count,
        sigurd_chara_id = SIGURD_CHARA_ID,
    }, string.format("lookup=%s chara_id=%s source=npc_manager", tostring(data.sigurd_lookup_count), tostring(SIGURD_CHARA_ID)))

    if npc_manager == nil then
        data.sigurd_last_status = "failed"
        data.sigurd_last_error = "npc_manager_unresolved"
        log.session_marker(runtime, "npc", "sigurd_lookup_failed", {
            source = "npc_manager",
            error = data.sigurd_last_error,
        }, data.sigurd_last_error)
        return false
    end

    local followers, follower_error = iter_taskguide_followers(npc_manager)
    if followers == nil then
        data.sigurd_last_status = "failed"
        data.sigurd_last_error = follower_error or "npc_manager_container_unresolved"
        log.session_marker(runtime, "npc", "sigurd_lookup_failed", {
            source = "npc_manager",
            error = data.sigurd_last_error,
        }, data.sigurd_last_error)
        return false
    end

    data.follow_npc_last_count = #followers
    for _, holder in ipairs(followers) do
        local chara_id = util.safe_field(holder, "CharaID")
        local character = util.safe_method(holder, "get_chara")
        local game_object = util.safe_method(holder, "get_go")
        local npc_data = npc_manager and (util.safe_method(npc_manager, "getNPCData(System.UInt32)", chara_id) or util.safe_method(npc_manager, "getNPCData", chara_id)) or nil
        local npc_name = get_character_name(chara_id) or util.safe_method(npc_data, "get_Name")
        local current_job = util.safe_method(character, "get_CurrentJob")
        local distance = compute_distance_to_player(runtime, game_object, holder)

        if chara_id == SIGURD_CHARA_ID or npc_name == "Sigurd" then
            return mark_sigurd_found(runtime, data, "npc_manager", holder, chara_id, character, game_object, npc_data, npc_name, current_job, distance)
        end
    end

    data.sigurd_last_status = "not_loaded_npc_manager"
    data.sigurd_last_error = "sigurd_not_in_npc_manager"
    clear_sigurd_fields(data)
    log.session_marker(runtime, "npc", "sigurd_not_loaded", {
        source = "npc_manager",
        chara_id = SIGURD_CHARA_ID,
        holder_count = #followers,
    }, string.format("chara_id=%s not in npc_manager count=%s", tostring(SIGURD_CHARA_ID), tostring(#followers)))
    return false
end

function sigurd_observer.dump_npc_manager_holders(runtime, data)
    bind_runtime_data(runtime, data)

    local npc_manager = get_npc_manager()
    if npc_manager == nil then
        data.last_error = "npc_manager_unresolved"
        log.session_marker(runtime, "npc", "npc_manager_dump_failed", {
            error = data.last_error,
        }, data.last_error)
        return false
    end

    local followers, follower_error = iter_taskguide_followers(npc_manager)
    if followers == nil then
        data.last_error = follower_error or "taskguide_followers_unresolved"
        log.session_marker(runtime, "npc", "npc_manager_dump_failed", {
            error = data.last_error,
        }, data.last_error)
        return false
    end

    data.follow_npc_dump_count = data.follow_npc_dump_count + 1
    data.follow_npc_last_count = #followers
    log.session_marker(runtime, "npc", "npc_manager_dump_started", {
        dump_count = data.follow_npc_dump_count,
        holder_count = #followers,
    }, string.format("dump=%s count=%s", tostring(data.follow_npc_dump_count), tostring(#followers)))

    for index, holder in ipairs(followers) do
        local chara_id = util.safe_field(holder, "CharaID")
        local character = util.safe_method(holder, "get_chara")
        local game_object = util.safe_method(holder, "get_go")
        local npc_data = npc_manager and (util.safe_method(npc_manager, "getNPCData(System.UInt32)", chara_id) or util.safe_method(npc_manager, "getNPCData", chara_id)) or nil
        local npc_name = get_character_name(chara_id) or util.safe_method(npc_data, "get_Name")
        local current_job = util.safe_method(character, "get_CurrentJob")
        local distance = compute_distance_to_player(runtime, game_object, holder)
        log.session_marker(runtime, "npc", "npc_manager_holder_entry", {
            index = index,
            chara_id = chara_id,
            name = npc_name,
            current_job = current_job,
            distance = distance,
            holder = util.describe_obj(holder),
            character = util.describe_obj(character),
            game_object = util.describe_obj(game_object),
            npc_data = util.describe_obj(npc_data),
        }, string.format("index=%s name=%s chara_id=%s job=%s dist=%s", tostring(index), tostring(npc_name), tostring(chara_id), tostring(current_job), tostring(distance)))
    end

    return true
end

function sigurd_observer.clear_tracking(runtime, data)
    bind_runtime_data(runtime, data)
    data.sigurd_last_status = "idle"
    data.sigurd_last_error = "<none>"
    clear_sigurd_fields(data)
    return true
end

return sigurd_observer

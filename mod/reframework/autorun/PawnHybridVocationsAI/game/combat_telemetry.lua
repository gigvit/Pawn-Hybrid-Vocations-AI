local config = require("PawnHybridVocationsAI/config")
local state = require("PawnHybridVocationsAI/core/runtime")
local log = require("PawnHybridVocationsAI/core/log")
local access = require("PawnHybridVocationsAI/core/access")
local main_pawn_properties = require("PawnHybridVocationsAI/game/main_pawn_properties")
local hybrid_executor = require("PawnHybridVocationsAI/game/hybrid_executor")
local attack_graphs = require("PawnHybridVocationsAI/data/attack_graphs")

local combat_telemetry = {}

local hooks_installed = false

local MAGIC_BIND_SHELL_PHASE = {
    [2307083031] = "bolt_hit",
    [2313730043] = "bolt_hit",
}

local function combat_config()
    return config.combat or {}
end

local function telemetry_enabled()
    return combat_config().damage_telemetry_enabled ~= false
end

local function damage_assist_enabled()
    return combat_config().damage_assist_enabled == true
end

local function log_prefix_from_hit(hit)
    local job_id = tonumber(hit and hit.active_move_job_id)
    return string.format("Job%02d", job_id or 0)
end

local function ensure_state(runtime)
    runtime = runtime or state.runtime
    if type(runtime.combat_damage_data) ~= "table" then
        runtime.combat_damage_data = {
            total_hits = 0,
            total_damage = 0.0,
            total_events = 0,
            total_value_hits = 0,
            total_proc_hits = 0,
            total_reaction_hits = 0,
            assist_hits = 0,
            assist_damage_added = 0.0,
            last_hit_at = nil,
            last_hit_summary = "no_hits",
            last_hit_move = "nil",
            last_hit_shell = "nil",
            last_hit_receiver = "nil",
            last_hit_phase = "nil",
            last_hit_active = "inactive",
            last_hit_target_match = "nil",
        }
    end

    return runtime.combat_damage_data
end

local function read_number(value)
    local direct = tonumber(value)
    if direct ~= nil then
        return direct
    end
    return tonumber(access.decode_small_int(value))
end

local function read_damage_field(damage_info, names)
    return read_number(access.field_first(damage_info, names))
end

local function resolve_character_from_object(obj)
    if not access.is_valid_obj(obj) then
        return nil
    end
    if access.is_a(obj, "app.Character") then
        return obj
    end

    return access.safe_get_component(obj, "app.Character", true)
end

local function resolve_chara_id(character)
    if not access.is_valid_obj(character) then
        return "nil"
    end

    local chara_id = access.call_first(character, {
        "get_CharaIDString",
        "get_CharaIDString()",
    })
    if chara_id ~= nil then
        return tostring(chara_id)
    end

    chara_id = access.call_first(character, {
        "get_CharaID",
        "get_CharaID()",
    }) or access.field_first(character, {
        "CharaID",
        "<CharaID>k__BackingField",
    })
    return tostring(chara_id or "nil")
end

local function resolve_main_pawn_data()
    local runtime = state.runtime
    local pawn_data = main_pawn_properties.get_resolved_main_pawn_data(runtime, "combat_telemetry")
    if type(pawn_data) ~= "table" then
        return nil
    end

    return pawn_data
end

local function is_main_pawn_attacker(attacker, attack_owner_object)
    local pawn_data = resolve_main_pawn_data()
    if type(pawn_data) ~= "table" then
        return false, nil
    end

    if access.is_valid_obj(attacker) then
        if access.same_object(attacker, pawn_data.runtime_character)
            or access.same_object(attacker, pawn_data.pawn)
            or access.same_object(attacker, pawn_data.object) then
            return true, pawn_data
        end

        local attacker_object = access.resolve_game_object(attacker, true)
        if access.is_valid_obj(attacker_object) and access.same_object(attacker_object, pawn_data.object) then
            return true, pawn_data
        end
    end

    local owner_character = resolve_character_from_object(attack_owner_object)
    if access.is_valid_obj(owner_character)
        and (
            access.same_object(owner_character, pawn_data.runtime_character)
            or access.same_object(owner_character, pawn_data.pawn)
            or access.same_object(owner_character, pawn_data.object)
        ) then
        return true, pawn_data
    end

    return false, pawn_data
end

local function resolve_receiver(damage_info)
    local damage_game_object = access.field_first(damage_info, {
        "<DamageGameObject>k__BackingField",
        "DamageGameObject",
    })
    local receiver = resolve_character_from_object(damage_game_object)
    if access.is_valid_obj(receiver) then
        return receiver, damage_game_object
    end

    local damage_hit_controller = access.field_first(damage_info, {
        "<DamageHitController>k__BackingField",
        "DamageHitController",
    })
    if not access.is_valid_obj(damage_hit_controller) then
        return nil, damage_game_object
    end

    receiver = access.field_first(damage_hit_controller, {
        "<CachedCharacter>k__BackingField",
        "CachedCharacter",
    })
    return receiver, damage_game_object
end

local function resolve_attacker_info(damage_info)
    local attack_owner_object = access.field_first(damage_info, {
        "<AttackOwnerObject>k__BackingField",
        "AttackOwnerObject",
    })
    local attacker = resolve_character_from_object(attack_owner_object)

    local attack_hit_controller = access.field_first(damage_info, {
        "<AttackHitController>k__BackingField",
        "AttackHitController",
    })
    local shell = nil
    local cached_character = nil
    if access.is_valid_obj(attack_hit_controller) then
        shell = access.field_first(attack_hit_controller, {
            "<CachedShell>k__BackingField",
            "CachedShell",
        })
        cached_character = access.field_first(attack_hit_controller, {
            "<CachedCharacter>k__BackingField",
            "CachedCharacter",
        })
    end

    if access.is_valid_obj(shell) then
        local shell_owner = access.field_first(shell, {
            "<OwnerCharacter>k__BackingField",
            "OwnerCharacter",
        }) or access.call_first(shell, "get_OwnerCharacter")
        if access.is_valid_obj(shell_owner) then
            attacker = shell_owner
        end
    elseif not access.is_valid_obj(attacker) and access.is_valid_obj(cached_character) then
        attacker = cached_character
    end

    return {
        attacker = attacker,
        attack_owner_object = attack_owner_object,
        cached_character = cached_character,
        shell = shell,
        shell_hash = access.is_valid_obj(shell) and access.call_first(shell, "get_ShellParamId") or nil,
    }
end

local function active_move_key(combat_data)
    if type(combat_data) == "table" and type(combat_data.active) == "table" then
        return tostring(combat_data.active.move and combat_data.active.move.key or "nil")
    end

    return tostring(combat_data and combat_data.last_move_key or "nil")
end

local function get_move_damage_profile(move_key)
    local combat_data = state.runtime and state.runtime.combat_data or nil
    local active_move = combat_data and combat_data.active and combat_data.active.move or nil
    if type(active_move) == "table" and tostring(active_move.key or "nil") == tostring(move_key or "nil") then
        return active_move, type(active_move.damage) == "table" and active_move.damage or {}
    end

    local move = attack_graphs.get_move(move_key)
    return move, type(move and move.damage) == "table" and move.damage or {}
end

local function build_hit_summary(pawn_data, receiver, damage_info, attacker_info, phase)
    local runtime = state.runtime
    local combat_data = runtime and runtime.combat_data or nil
    local attack_data = access.field_first(damage_info, {
        "<AttackUserData>k__BackingField",
        "AttackUserData",
    })
    local damage = read_damage_field(damage_info, {
        "Damage",
        "<Damage>k__BackingField",
    })
    local action_rate = read_number(access.field_first(attack_data, {
        "ActionRate",
        "<ActionRate>k__BackingField",
    }))
    local reaction_rate = read_number(access.field_first(attack_data, {
        "DmgReactionRate",
        "<DmgReactionRate>k__BackingField",
    }))
    local shell_hash = read_number(attacker_info and attacker_info.shell_hash)
    local resolved_pawn_data = pawn_data
    if type(resolved_pawn_data) ~= "table" or resolved_pawn_data.full_node == nil then
        resolved_pawn_data = main_pawn_properties.get_resolved_main_pawn_data(
            runtime,
            "combat_telemetry_refresh"
        )
    end
    local move_name = tostring(resolved_pawn_data and resolved_pawn_data.full_node or "nil")
    local active_summary = hybrid_executor.describe_active(combat_data)
    local current_active_move_key = active_move_key(combat_data)
    local target_character = combat_data
        and combat_data.cached_target_info
        and combat_data.cached_target_info.character
        or nil
    local target_signature = access.describe_obj(target_character)
    local receiver_matches_target = access.is_valid_obj(target_character)
        and access.is_valid_obj(receiver)
        and access.same_object(receiver, target_character)
    local attacker = attacker_info and attacker_info.attacker or nil

    return {
        phase = tostring(phase or "unknown"),
        damage = damage,
        physical_damage = read_damage_field(damage_info, { "PhysicalDamage", "AttackDamage" }),
        magic_damage = read_damage_field(damage_info, { "MagicDamage" }),
        shoot_damage = read_damage_field(damage_info, { "ShootDamage" }),
        enchant_damage = read_damage_field(damage_info, { "EnchantDamage" }),
        damage_rate = read_damage_field(damage_info, { "DamageRate" }),
        action_rate = action_rate,
        reaction_rate = reaction_rate,
        shell_hash = shell_hash,
        move_name = move_name,
        active_summary = active_summary,
        active_move_key = current_active_move_key,
        active_move_job_id = combat_data
            and combat_data.active
            and combat_data.active.move
            and combat_data.active.move.job_id
            or combat_data
            and combat_data.current_job_id
            or nil,
        attacker_signature = access.describe_obj(attacker),
        attacker_chara_id = resolve_chara_id(attacker),
        receiver_signature = access.describe_obj(receiver),
        receiver_chara_id = resolve_chara_id(receiver),
        target_signature = target_signature,
        receiver_matches_target = receiver_matches_target,
        summary = string.format(
            "phase=%s move=%s active_move=%s active=%s target_match=%s damage=%s action_rate=%s reaction=%s receiver=%s receiver_id=%s target=%s shell=%s",
            tostring(phase or "unknown"),
            tostring(move_name),
            tostring(current_active_move_key),
            tostring(active_summary),
            tostring(receiver_matches_target),
            tostring(damage or "nil"),
            tostring(action_rate or "nil"),
            tostring(reaction_rate or "nil"),
            tostring(access.describe_obj(receiver)),
            tostring(resolve_chara_id(receiver)),
            tostring(target_signature),
            tostring(shell_hash or "nil")
        ),
    }
end

local function should_apply_damage_assist(hit)
    if not damage_assist_enabled() then
        return false, "assist_disabled"
    end
    if type(hit) ~= "table" then
        return false, "hit_unresolved"
    end
    if tostring(hit.receiver_signature or "nil") == "nil" then
        return false, "receiver_unresolved"
    end
    if tonumber(hit.action_rate or 0.0) <= 0.0 then
        return false, "non_attack_damage"
    end

    local move, damage_profile = get_move_damage_profile(hit.active_move_key)
    if type(move) ~= "table" then
        return false, "active_move_unresolved"
    end
    if damage_profile.assist ~= true then
        return false, "move_assist_disabled"
    end
    if damage_profile.requires_target_match ~= false
        and combat_config().damage_assist_required_target_match ~= false then
        if tostring(hit.target_signature or "nil") == "nil" then
            return false, "target_unresolved"
        end
        if hit.receiver_matches_target ~= true then
            return false, "receiver_not_current_target"
        end
    end

    return true, "move_damage:" .. tostring(move.key or "nil")
end

local function apply_damage_assist(damage_info, hit)
    local ok, reason = should_apply_damage_assist(hit)
    if not ok then
        return false, reason
    end

    local old_damage = tonumber(hit.damage) or 0.0
    local multiplier = tonumber(combat_config().damage_assist_multiplier) or 1.0
    local _, damage_profile = get_move_damage_profile(hit.active_move_key)
    local minimum_damage = tonumber(damage_profile.minimum_damage)
        or tonumber(combat_config().damage_assist_minimum_damage)
        or 0.0
    local new_damage = math.max(old_damage * multiplier, minimum_damage)
    if new_damage <= old_damage then
        return false, "damage_already_sufficient"
    end

    if not access.safe_set_field(damage_info, "Damage", new_damage) then
        access.safe_set_field(damage_info, "<Damage>k__BackingField", new_damage)
    end
    hit.damage_assist = string.format("%s->%s", tostring(old_damage), tostring(new_damage))
    hit.damage = new_damage

    local data = ensure_state(state.runtime)
    data.assist_hits = (tonumber(data.assist_hits) or 0) + 1
    data.assist_damage_added = (tonumber(data.assist_damage_added) or 0.0) + (new_damage - old_damage)

    local combat_data = state.runtime and state.runtime.combat_data or nil
    if type(combat_data) == "table" and type(combat_data.active) == "table" then
        combat_data.active.damage_assist_hits = (tonumber(combat_data.active.damage_assist_hits) or 0) + 1
    end

    log.info(string.format(
        "%s damage_assist %s reason=%s",
        log_prefix_from_hit(hit),
        tostring(hit.summary),
        tostring(reason)
    ))
    return true, reason
end

local function grant_magic_bind_chain(shell_hash, receiver_signature, receiver_matches_target, source)
    local normalized_shell_hash = tonumber(shell_hash)
    local chain_phase = normalized_shell_hash ~= nil and MAGIC_BIND_SHELL_PHASE[normalized_shell_hash] or nil
    if chain_phase == nil and tostring(source or "") == "job07_magic_bind_shell" then
        chain_phase = "bolt_hit"
    end
    if chain_phase == nil then
        return
    end
    if receiver_matches_target ~= true then
        return
    end

    local runtime = state.runtime
    local combat_data = runtime and runtime.combat_data or nil
    if type(combat_data) ~= "table" then
        return
    end

    local duration = tonumber(combat_config().magic_bind_hit_window_seconds) or 0.65
    local now = tonumber(runtime.game_time or os.clock()) or 0.0
    hybrid_executor.grant_chain_state(
        combat_data,
        chain_phase,
        receiver_signature,
        now,
        duration,
        tostring(source or "magic_bind_shell") .. ":" .. tostring(normalized_shell_hash or "nil")
    )
    log.info(string.format(
        "Job07 bind_chain phase=%s source=%s source_shell=%s target=%s window=%s",
        tostring(chain_phase),
        tostring(source or "nil"),
        tostring(normalized_shell_hash or "nil"),
        tostring(receiver_signature or "nil"),
        tostring(duration)
    ))
end

local function update_magic_bind_chain(hit, phase)
    if type(hit) ~= "table" or (phase ~= "calc_value" and phase ~= "damage_proc") then
        return
    end
    if tonumber(hit.active_move_job_id) ~= 7 then
        return
    end

    grant_magic_bind_chain(
        hit.shell_hash,
        hit.receiver_signature,
        hit.receiver_matches_target,
        phase
    )
end

local function record_hit(phase, hit)
    local runtime = state.runtime
    local data = ensure_state(runtime)
    local combat_data = runtime and runtime.combat_data or nil
    local active_state = combat_data and combat_data.active or nil
    local _, damage_profile = get_move_damage_profile(hit and hit.active_move_key)
    local damage = tonumber(hit and hit.damage) or 0.0

    data.total_events = (tonumber(data.total_events) or 0) + 1
    if phase == "calc_value" then
        data.total_hits = (tonumber(data.total_hits) or 0) + 1
        data.total_value_hits = (tonumber(data.total_value_hits) or 0) + 1
        data.total_damage = (tonumber(data.total_damage) or 0.0) + damage
    elseif phase == "damage_proc" then
        data.total_proc_hits = (tonumber(data.total_proc_hits) or 0) + 1
    elseif phase == "calc_reaction" then
        data.total_reaction_hits = (tonumber(data.total_reaction_hits) or 0) + 1
    end

    data.last_hit_at = tonumber(runtime.game_time or os.clock()) or 0.0
    data.last_hit_summary = tostring(hit.summary)
    data.last_hit_move = tostring(hit.move_name or "nil")
    data.last_hit_shell = tostring(hit.shell_hash or "nil")
    data.last_hit_receiver = tostring(hit.receiver_signature or "nil")
    data.last_hit_phase = tostring(phase or "nil")
    data.last_hit_active = tostring(hit.active_summary or "inactive")
    data.last_hit_target_match = tostring(hit.receiver_matches_target)

    if type(active_state) == "table" then
        active_state.damage_events = (tonumber(active_state.damage_events) or 0) + 1
        if phase == "calc_value" then
            active_state.damage_value_hits = (tonumber(active_state.damage_value_hits) or 0) + 1
            active_state.damage_total = (tonumber(active_state.damage_total) or 0.0) + damage
            if hit.receiver_matches_target == true then
                active_state.damage_target_hits = (tonumber(active_state.damage_target_hits) or 0) + 1
            else
                active_state.damage_wrong_target_hits = (tonumber(active_state.damage_wrong_target_hits) or 0) + 1
                local wrong_target_cooldown = tonumber(damage_profile.wrong_target_cooldown_seconds)
                    or tonumber(combat_config().wrong_target_hit_cooldown_seconds)
                    or 0.0
                if wrong_target_cooldown > 0.0 then
                    local now = tonumber(runtime.game_time or os.clock()) or 0.0
                    active_state.extra_cooldown_until = math.max(
                        tonumber(active_state.extra_cooldown_until) or 0.0,
                        now + wrong_target_cooldown
                    )
                end
            end
        end
    end
end

local function handle_damage_event(damage_info, phase, allow_assist)
    if not telemetry_enabled() then
        return
    end
    if not access.is_valid_obj(damage_info) then
        return
    end

    local attacker_info = resolve_attacker_info(damage_info)
    local attacker = attacker_info and attacker_info.attacker or nil
    local is_main_pawn, pawn_data = is_main_pawn_attacker(attacker, attacker_info and attacker_info.attack_owner_object)
    if not is_main_pawn or type(pawn_data) ~= "table" then
        return
    end

    local receiver = resolve_receiver(damage_info)
    local hit = build_hit_summary(pawn_data, receiver, damage_info, attacker_info, phase)
    if allow_assist == true then
        apply_damage_assist(damage_info, hit)
        hit.summary = string.format(
            "%s assist=%s",
            tostring(hit.summary),
            tostring(hit.damage_assist or "none")
        )
    end

    update_magic_bind_chain(hit, phase)
    record_hit(phase, hit)
    log.info(string.format("%s damage %s", log_prefix_from_hit(hit), tostring(hit.summary)))
end

function combat_telemetry.describe_recent(now)
    local data = ensure_state(state.runtime)
    local current_time = tonumber(now or state.runtime.game_time or os.clock()) or 0.0
    local last_hit_at = tonumber(data.last_hit_at)
    if last_hit_at ~= nil and (current_time - last_hit_at) <= 4.00 then
        return tostring(data.last_hit_summary or "recent_hit")
    end

    return string.format(
        "hits=%s value_hits=%s proc_hits=%s reaction_hits=%s total_damage=%s assists=%s added=%s last_move=%s",
        tostring(data.total_hits or 0),
        tostring(data.total_value_hits or 0),
        tostring(data.total_proc_hits or 0),
        tostring(data.total_reaction_hits or 0),
        tostring(data.total_damage or 0.0),
        tostring(data.assist_hits or 0),
        tostring(data.assist_damage_added or 0.0),
        tostring(data.last_hit_move or "nil")
    )
end

function combat_telemetry.install_hooks()
    if hooks_installed then
        return
    end

    hooks_installed = true

    sdk.hook(
        sdk.find_type_definition("app.HitController"):get_method("calcDamageValue(app.HitController.DamageInfo)"),
        function(args)
            if not telemetry_enabled() then
                return
            end
            local storage = thread.get_hook_storage()
            storage.phvai_damage_info = sdk.to_managed_object(args[3])
        end,
        function(retval)
            local storage = thread.get_hook_storage()
            handle_damage_event(storage.phvai_damage_info, "calc_value", true)
            storage.phvai_damage_info = nil
            return retval
        end
    )

    sdk.hook(
        sdk.find_type_definition("app.HitController"):get_method("damageProc(app.HitController.DamageInfo)"),
        function(args)
            handle_damage_event(sdk.to_managed_object(args[3]), "damage_proc", false)
        end
    )

    local magic_bind_shell_td = sdk.find_type_definition("app.Job07MagicBindShell")
    if magic_bind_shell_td ~= nil then
        local hit_method = magic_bind_shell_td:get_method("Hit_AttackHitHandler(app.HitController.DamageInfo)")
        if hit_method ~= nil then
            sdk.hook(
                hit_method,
                function(args)
                    if not telemetry_enabled() then
                        return
                    end

                    local shell = sdk.to_managed_object(args[2])
                    local damage_info = sdk.to_managed_object(args[3])
                    if not access.is_valid_obj(shell) or not access.is_valid_obj(damage_info) then
                        return
                    end

                    local owner = access.field_first(shell, {
                        "<OwnerCharacter>k__BackingField",
                        "OwnerCharacter",
                    }) or access.call_first(shell, "get_OwnerCharacter")
                    local is_main_pawn = is_main_pawn_attacker(owner, nil)
                    if not is_main_pawn then
                        return
                    end

                    local receiver = resolve_receiver(damage_info)
                    local runtime = state.runtime
                    local combat_data = runtime and runtime.combat_data or nil
                    local target_character = combat_data
                        and combat_data.cached_target_info
                        and combat_data.cached_target_info.character
                        or nil
                    local receiver_matches_target = access.is_valid_obj(target_character)
                        and access.is_valid_obj(receiver)
                        and access.same_object(receiver, target_character)
                    local shell_hash = read_number(access.call_first(shell, "get_ShellParamId"))

                    grant_magic_bind_chain(
                        shell_hash,
                        access.describe_obj(receiver),
                        receiver_matches_target,
                        "job07_magic_bind_shell"
                    )
                end
            )
        end
    end

    sdk.hook(
        sdk.find_type_definition("app.HitController"):get_method("calcDamageReaction(app.HitController.DamageInfo)"),
        function(args)
            if not telemetry_enabled() then
                return
            end
            local storage = thread.get_hook_storage()
            storage.phvai_damage_info = sdk.to_managed_object(args[3])
        end,
        function(retval)
            local storage = thread.get_hook_storage()
            handle_damage_event(storage.phvai_damage_info, "calc_reaction", false)
            storage.phvai_damage_info = nil
            return retval
        end
    )
end

return combat_telemetry

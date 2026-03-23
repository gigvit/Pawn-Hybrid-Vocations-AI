local state = require("PawnHybridVocationsAI/state")
local config = require("PawnHybridVocationsAI/config")
local util = require("PawnHybridVocationsAI/core/util")
local discovery = require("PawnHybridVocationsAI/game/discovery")

local main_pawn_properties = {}

-- Runtime-sensitive module. Unlock/progression for main_pawn regressed when this file
-- was refactored too aggressively, so the resolver below is restored from the last
-- known-good backup and should stay close to that behavior until revalidated in-game.

local candidate_specs = {
    {source = "PawnManager:get_MainPawn()", manager = "PawnManager", kind = "method", key = "get_MainPawn"},
    {source = "PawnManager.<MainPawn>k__BackingField", manager = "PawnManager", kind = "field", key = "<MainPawn>k__BackingField"},
    {source = "CharacterManager:get_MainPawn()", manager = "CharacterManager", kind = "method", key = "get_MainPawn"},
    {source = "CharacterManager.<MainPawn>k__BackingField", manager = "CharacterManager", kind = "field", key = "<MainPawn>k__BackingField"},
    {source = "CharacterManager:get_ManualPlayerPawn()", manager = "CharacterManager", kind = "method", key = "get_ManualPlayerPawn"},
    {source = "CharacterManager:get_ManualPlayerMainPawn()", manager = "CharacterManager", kind = "method", key = "get_ManualPlayerMainPawn"},
}

local character_specs = {
    {source = "pawn.<CachedCharacter>k__BackingField", kind = "field", key = "<CachedCharacter>k__BackingField"},
    {source = "pawn:get_Character()", kind = "method", key = "get_Character"},
    {source = "pawn:get_Chara()", kind = "method", key = "get_Chara"},
    {source = "pawn:get_PawnCharacter()", kind = "method", key = "get_PawnCharacter"},
    {source = "pawn.<Character>k__BackingField", kind = "field", key = "<Character>k__BackingField"},
    {source = "pawn.<Chara>k__BackingField", kind = "field", key = "<Chara>k__BackingField"},
    {source = "pawn.Character", kind = "field", key = "Character"},
    {source = "pawn.Chara", kind = "field", key = "Chara"},
}

local volatile_pawn_fields = {
    ["<CurrentMovePos>k__BackingField"] = true,
    ["<CurrentQueryPos>k__BackingField"] = true,
    ["<OwnerPrevPos>k__BackingField"] = true,
    ["<CachedPlayerDistance>k__BackingField"] = true,
    ["<ActiveOrder>k__BackingField"] = true,
    ["<ActiveOrderTime>k__BackingField"] = true,
}

local function snapshot_fields(obj, limit)
    local snapshot = {}
    for _, entry in ipairs(util.get_fields_snapshot(obj, limit or config.debug.targeted_snapshot_limit)) do
        snapshot[entry.name] = entry.value
    end
    return snapshot
end

local function snapshot_filtered_pawn_fields(pawn)
    local filtered = {}
    for _, entry in ipairs(util.get_fields_snapshot(pawn, 32)) do
        if not volatile_pawn_fields[entry.name] then
            filtered[entry.name] = entry.value
        end
    end
    return filtered
end

local function get_player()
    local manager = discovery.get_manager("CharacterManager")
    if manager == nil then
        return nil
    end

    local player = util.safe_field(manager, "<ManualPlayer>k__BackingField")
    if util.is_valid_obj(player) then
        return player
    end

    player = util.safe_method(manager, "get_ManualPlayer")
    if util.is_valid_obj(player) then
        return player
    end

    return nil
end

local function extract_party()
    local party = {}
    local pawn_manager = discovery.get_manager("PawnManager")
    if pawn_manager == nil then
        state.discovery.party = party
        return party
    end

    local pawn_list = util.safe_method(pawn_manager, "get_PawnCharacterList")
    for _, pawn in ipairs(util.array_to_lua(pawn_list, 16)) do
        if util.is_valid_obj(pawn) then
            local object = util.safe_method(pawn, "get_GameObject")
            local name = object and util.safe_method(object, "get_Name") or nil
            table.insert(party, {
                object = pawn,
                name = name or "<unnamed pawn>",
                description = util.describe_obj(pawn),
            })
        end
    end

    state.discovery.party = party
    return party
end

local function build_party_snapshot(main_runtime_character)
    local snapshot = {}

    for index, party_entry in ipairs(state.discovery.party) do
        local role = util.same_object(party_entry.object, main_runtime_character) and "main_pawn" or "other_pawn"
        table.insert(snapshot, {
            index = index,
            role = role,
            name = party_entry.name,
            description = party_entry.description,
            object = party_entry.object,
        })
    end

    return snapshot
end

local function resolve_main_pawn()
    extract_party()

    local resolved = nil
    local source = "unresolved"
    local errors = {}

    for _, spec in ipairs(candidate_specs) do
        local manager = discovery.get_manager(spec.manager)
        if manager ~= nil then
            local candidate = nil
            if spec.kind == "field" then
                candidate = util.safe_field(manager, spec.key)
            else
                candidate = util.safe_method(manager, spec.key)
            end

            if util.is_valid_obj(candidate) then
                resolved = candidate
                source = spec.source
                break
            end
        else
            table.insert(errors, spec.manager .. " missing")
        end
    end

    state.discovery.main_pawn.source = source
    state.discovery.main_pawn.errors = errors
    state.discovery.main_pawn.candidate_count = #state.discovery.party

    return resolved
end

local function try_character_candidate(source, candidate, candidate_paths)
    table.insert(candidate_paths, {
        source = source,
        result = util.describe_obj(candidate),
        type_name = util.get_typedef_name(candidate),
    })

    if util.is_valid_obj(candidate) and util.is_a(candidate, "app.Character") then
        return candidate, source
    end

    return nil, nil
end

local function resolve_runtime_character(pawn)
    local candidate_paths = {}
    if not util.is_valid_obj(pawn) then
        state.discovery.main_pawn.character_source = "unresolved"
        state.discovery.main_pawn.candidate_paths = candidate_paths
        return nil
    end

    for _, spec in ipairs(character_specs) do
        local candidate = nil
        if spec.kind == "field" then
            candidate = util.safe_field(pawn, spec.key)
        else
            candidate = util.safe_method(pawn, spec.key)
        end

        local resolved, source = try_character_candidate(spec.source, candidate, candidate_paths)
        if resolved ~= nil then
            state.discovery.main_pawn.character_source = source
            state.discovery.main_pawn.candidate_paths = candidate_paths
            return resolved
        end
    end

    local object = util.safe_method(pawn, "get_GameObject")
    local resolved, source = try_character_candidate("pawn:get_GameObject()", object, candidate_paths)
    if resolved ~= nil then
        state.discovery.main_pawn.character_source = source
        state.discovery.main_pawn.candidate_paths = candidate_paths
        return resolved
    end

    if util.is_valid_obj(object) then
        local component = util.safe_method(object, "getComponent(System.Type)", sdk.typeof("app.Character"))
        resolved, source = try_character_candidate("pawn:get_GameObject():getComponent(app.Character)", component, candidate_paths)
        if resolved ~= nil then
            state.discovery.main_pawn.character_source = source
            state.discovery.main_pawn.candidate_paths = candidate_paths
            return resolved
        end
    end

    for _, party_entry in ipairs(state.discovery.party) do
        if party_entry.name ~= nil and util.is_valid_obj(party_entry.object) then
            local party_go = util.safe_method(party_entry.object, "get_GameObject")
            local party_name = party_go and util.safe_method(party_go, "get_Name") or nil
            if party_name == party_entry.name and party_name ~= nil then
                resolved, source = try_character_candidate("party_entry.object", party_entry.object, candidate_paths)
                if resolved ~= nil then
                    state.discovery.main_pawn.character_source = source
                    state.discovery.main_pawn.candidate_paths = candidate_paths
                    return resolved
                end
            end
        end
    end

    state.discovery.main_pawn.character_source = "unresolved"
    state.discovery.main_pawn.candidate_paths = candidate_paths
    return nil
end

local function describe_pawn_ai_fields(pawn)
    return {
        cached_character = util.safe_field(pawn, "<CachedCharacter>k__BackingField"),
        cached_human = util.safe_field(pawn, "<CachedHuman>k__BackingField"),
        cached_game_object = util.safe_field(pawn, "<CachedGameObject>k__BackingField"),
        cached_personality = util.safe_field(pawn, "<CachedPersonality>k__BackingField"),
        cached_navigation_ai = util.safe_field(pawn, "<CachedNavigational>k__BackingField"),
        cached_navigation_controller = util.safe_field(pawn, "<CachedNavigationController>k__BackingField"),
        cached_ai_agent = util.safe_field(pawn, "<CachedAIAgent>k__BackingField"),
        cached_formation_evaluator = util.safe_field(pawn, "<CachedFormationEvaluator>k__BackingField"),
        cached_ai_goal_planning = util.safe_field(pawn, "<CachedAIGoalPlanning>k__BackingField"),
        goal_action_data_list = util.safe_field(pawn, "<GoalActionDataList>k__BackingField"),
        action_order = util.safe_field(pawn, "<ActionOrder>k__BackingField"),
        is_front_of_player = util.safe_field(pawn, "<IsFrontOfPlayer>k__BackingField"),
        owner = util.safe_field(pawn, "<Owner>k__BackingField"),
        pawn_health_item_controller = util.safe_field(pawn, "<PawnHealthItemController>k__BackingField"),
        ai_stamina_manager = util.safe_field(pawn, "<AIStaminaManager>k__BackingField"),
    }
end

local function describe_human_context_fields(human)
    if human == nil then
        return {}
    end

    return {
        job_context = util.safe_field(human, "<JobContext>k__BackingField"),
        skill_context = util.safe_field(human, "<SkillContext>k__BackingField"),
        ability_context = util.safe_field(human, "<AbilityContext>k__BackingField"),
        dragon_hermit_context = util.safe_field(human, "<DragonHermitContext>k__BackingField"),
        custom_skill_state = util.safe_field(human, "<CustomSkillState>k__BackingField"),
        status_context = util.safe_field(human, "<StatusContext>k__BackingField"),
        human_enemy_controller = util.safe_field(human, "HumanEnemyController"),
        track = util.safe_field(human, "Track"),
    }
end

local function describe_knowledge_hints(pawn, human)
    return {
        pawn_context = util.safe_field(pawn, "<Context>k__BackingField"),
        special_pawn = util.safe_method(util.safe_field(pawn, "<CachedGameObject>k__BackingField"), "getComponent(System.Type)", sdk.typeof("app.SpecialPawn")),
        personality = util.safe_field(pawn, "<CachedPersonality>k__BackingField"),
        owner = util.safe_field(pawn, "<Owner>k__BackingField"),
        status_context = human and util.safe_field(human, "<StatusContext>k__BackingField") or nil,
    }
end

local function get_current_node(action_manager, layer_index)
    local fsm = util.safe_field(action_manager, "Fsm")
    if fsm == nil then
        return nil
    end

    local node_name = util.safe_method(fsm, "getCurrentNodeName(System.UInt32)", layer_index)
    if node_name == nil then
        node_name = util.safe_method(fsm, "getCurrentNodeName", layer_index)
    end

    if type(node_name) == "string" then
        return node_name:match("([^%.]+)$") or node_name
    end

    local as_string = node_name and util.safe_method(node_name, "ToString")
    if type(as_string) == "string" then
        return as_string:match("([^%.]+)$") or as_string
    end

    return nil
end

local function build_identity_signature(player, pawn, runtime_character, job_context)
    return table.concat({
        tostring(util.get_address(player) or "nil"),
        tostring(util.get_address(pawn) or "nil"),
        tostring(util.get_address(runtime_character) or "nil"),
        tostring(util.get_address(job_context) or "nil"),
    }, "|")
end

local function should_refresh_deep_data(runtime, identity_signature)
    if identity_signature ~= runtime.last_main_pawn_identity_signature then
        return true
    end

    local interval = tonumber(config.main_pawn.deep_refresh_interval_seconds) or 0.5
    if interval <= 0 then
        return true
    end

    return (runtime.game_time - (runtime.last_main_pawn_deep_refresh or 0.0)) >= interval
end

local function enrich_deep_data(data, pawn, runtime_character)
    data.pawn_fields = snapshot_filtered_pawn_fields(pawn)
    data.pawn_ai_fields = describe_pawn_ai_fields(pawn)
    data.human_context_fields = describe_human_context_fields(data.human)
    data.knowledge_hints = describe_knowledge_hints(pawn, data.human)
    data.personality = util.safe_field(pawn, "<CachedPersonality>k__BackingField")
    data.ai_goal_planning = util.safe_field(pawn, "<CachedAIGoalPlanning>k__BackingField")
    data.personality_data = util.safe_field(data.personality, "<_PersonalityData>k__BackingField")
    data.decision_maker = util.safe_field(data.ai_goal_planning, "_CachedDecisionMaker")
    data.pawn_data_context = util.safe_field(data.ai_goal_planning, "_CachedPawnContext")
    data.decision_evaluation_module = util.safe_field(data.ai_goal_planning, "_CachedDecisionEvaluationModule")
    data.personality_fields = snapshot_fields(data.personality)
    data.personality_data_fields = snapshot_fields(data.personality_data)
    data.job_context_fields = snapshot_fields(data.job_context)
    data.skill_context_fields = snapshot_fields(data.skill_context)
    data.ai_goal_planning_fields = snapshot_fields(data.ai_goal_planning)
    data.decision_maker_fields = snapshot_fields(data.decision_maker)
    data.pawn_data_context_fields = snapshot_fields(data.pawn_data_context)
    data.decision_evaluation_module_fields = snapshot_fields(data.decision_evaluation_module)
    data.party_snapshot = build_party_snapshot(runtime_character)
end

function main_pawn_properties.update()
    discovery.refresh(false)

    local runtime = state.runtime
    local last_time = runtime.game_time
    runtime.game_time = os.clock()
    runtime.delta_time = last_time == 0 and 0 or (runtime.game_time - last_time)

    runtime.player = get_player()
    runtime.main_pawn = resolve_main_pawn()

    local pawn = runtime.main_pawn
    if not util.is_valid_obj(pawn) then
        runtime.main_pawn_data = nil
        return nil
    end

    local runtime_character = resolve_runtime_character(pawn)
    if not util.is_valid_obj(runtime_character) then
        runtime.main_pawn_data = nil
        return nil
    end

    local previous = runtime.main_pawn_data
    local data = previous or {}

    data.pawn = pawn
    data.runtime_character = runtime_character
    data.object = util.safe_method(runtime_character, "get_GameObject")
    data.transform = util.safe_method(runtime_character, "get_Transform")
    data.stamina_manager = util.safe_method(runtime_character, "get_StaminaManager")
    data.hit_controller = util.safe_method(runtime_character, "get_Hit")
    data.action_manager = util.safe_method(runtime_character, "get_ActionManager")
    data.human = util.safe_method(runtime_character, "get_Human")
    data.lock_on_ctrl = util.safe_method(runtime_character, "get_LockOnCtrl")
    data.name = nil
    data.chara_id = util.safe_method(runtime_character, "get_CharaID")
    data.job = util.safe_field(runtime_character, "Job")
    data.weapon_job = util.safe_field(runtime_character, "WeaponJob")

    if data.object ~= nil then
        data.name = util.safe_method(data.object, "get_Name")
    end

    if data.human ~= nil then
        data.job_context = util.safe_field(data.human, "<JobContext>k__BackingField")
        data.skill_context = util.safe_field(data.human, "<SkillContext>k__BackingField")
        data.ability_context = util.safe_field(data.human, "<AbilityContext>k__BackingField")
        data.status_condition_ctrl = util.safe_method(runtime_character, "get_StatusConditionCtrl") or util.safe_field(data.human, "StatusConditionCtrl")
        data.skill_state = util.safe_field(data.human, "<CustomSkillState>k__BackingField")
    else
        data.job_context = nil
        data.skill_context = nil
        data.ability_context = nil
        data.status_condition_ctrl = nil
        data.skill_state = nil
    end

    if data.action_manager ~= nil then
        data.motion = util.safe_method(runtime_character, "get_Motion")
        if data.motion ~= nil then
            data.full_layer = util.safe_method(data.motion, "getLayer(System.UInt32)", 0) or util.safe_method(data.motion, "getLayer", 0)
            data.upper_layer = util.safe_method(data.motion, "getLayer(System.UInt32)", 1) or util.safe_method(data.motion, "getLayer", 1)
        else
            data.full_layer = nil
            data.upper_layer = nil
        end

        data.full_node = get_current_node(data.action_manager, 0)
        data.upper_node = get_current_node(data.action_manager, 1)
    else
        data.motion = nil
        data.full_layer = nil
        data.upper_layer = nil
        data.full_node = nil
        data.upper_node = nil
    end

    if data.job_context ~= nil then
        data.current_job = util.safe_field(data.job_context, "CurrentJob")
    else
        data.current_job = nil
    end

    local identity_signature = build_identity_signature(runtime.player, pawn, runtime_character, data.job_context)
    if should_refresh_deep_data(runtime, identity_signature) then
        enrich_deep_data(data, pawn, runtime_character)
        runtime.last_main_pawn_identity_signature = identity_signature
        runtime.last_main_pawn_deep_refresh = runtime.game_time
    elseif previous ~= nil then
        data.party_snapshot = previous.party_snapshot
    end

    runtime.main_pawn_data = data
    return data
end

return main_pawn_properties

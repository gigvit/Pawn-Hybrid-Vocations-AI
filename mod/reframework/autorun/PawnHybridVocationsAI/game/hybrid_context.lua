local access = require("PawnHybridVocationsAI/core/access")
local main_pawn_properties = require("PawnHybridVocationsAI/game/main_pawn_properties")
local vocations = require("PawnHybridVocationsAI/data/vocations")

local hybrid_context = {}

local field_first = access.field_first
local call_first = access.call_first
local decode_small_int = access.decode_small_int
local get_current_node = access.get_current_node

local function build_job_output_tokens(job_id)
    local normalized_job_id = tonumber(job_id)
    local job = normalized_job_id ~= nil and vocations.get_job(normalized_job_id) or nil
    local action_prefix = tostring(job and job.action_prefix or string.format("Job%02d", normalized_job_id or 0))
    local lower_prefix = string.lower(action_prefix)
    return {
        "/" .. lower_prefix .. "/",
        lower_prefix .. "_",
        action_prefix .. "_",
    }
end

local function build_output_text_list(context)
    return {
        tostring(context and context.decision_pack_path or "nil"),
        tostring(context and context.current_action_identity or "nil"),
        tostring(context and context.selected_request_identity or "nil"),
        tostring(context and context.full_node or "nil"),
        tostring(context and context.upper_node or "nil"),
    }
end

local function resolve_context_current_job(main_pawn, runtime_character)
    local human = main_pawn and main_pawn.human or call_first(runtime_character, "get_Human")
    local job_context = main_pawn and main_pawn.job_context

    if not access.is_valid_obj(job_context) and access.is_valid_obj(human) then
        job_context = field_first(human, {
            "<JobContext>k__BackingField",
            "JobContext",
        }) or call_first(human, "get_JobContext")
    end

    local current_job = decode_small_int(main_pawn and main_pawn.current_job)
        or decode_small_int(main_pawn and main_pawn.job)
        or (access.is_valid_obj(job_context) and decode_small_int(
            field_first(job_context, "CurrentJob")
                or call_first(job_context, "get_CurrentJob")
        ))
        or (access.is_valid_obj(human) and decode_small_int(
            field_first(human, {
                "<CurrentJob>k__BackingField",
                "CurrentJob",
            }) or call_first(human, "get_CurrentJob")
        ))
        or decode_small_int(call_first(runtime_character, "get_CurrentJob"))
        or decode_small_int(call_first(runtime_character, "get_Job"))
        or decode_small_int(field_first(runtime_character, "Job"))

    return current_job, human, job_context
end

local function resolve_action_manager(main_pawn, runtime_character)
    return main_pawn and main_pawn.action_manager
        or call_first(runtime_character, "get_ActionManager")
        or field_first(runtime_character, {
            "<ActionManager>k__BackingField",
            "ActionManager",
        })
end

function hybrid_context.build_output_texts(context)
    if type(context) == "table" and type(context.output_texts) == "table" then
        return context.output_texts
    end

    local values = build_output_text_list(context)
    if type(context) == "table" then
        context.output_texts = values
    end
    return values
end

function hybrid_context.build_output_blob(context)
    if type(context) == "table" and type(context.output_blob) == "string" then
        return context.output_blob
    end

    local blob = table.concat(hybrid_context.build_output_texts(context), " | ")
    if type(context) == "table" then
        context.output_blob = blob
    end
    return blob
end

function hybrid_context.output_has_any_token(context, tokens)
    if type(tokens) ~= "table" or #tokens == 0 then
        return false
    end

    local blob = type(context) == "table" and context.output_blob_lower or nil
    if type(blob) ~= "string" then
        blob = string.lower(hybrid_context.build_output_blob(context))
        if type(context) == "table" then
            context.output_blob_lower = blob
        end
    end

    for _, token in ipairs(tokens or {}) do
        local needle = string.lower(tostring(token or ""))
        if needle ~= "" and blob:find(needle, 1, true) ~= nil then
            return true
        end
    end
    return false
end

function hybrid_context.has_native_job_output(context)
    return hybrid_context.output_has_any_token(context, build_job_output_tokens(context and context.current_job))
end

function hybrid_context.resolve(runtime)
    local main_pawn, main_pawn_source, main_pawn_age = main_pawn_properties.get_resolved_main_pawn_data(
        runtime,
        "combat_main_pawn_data_unresolved"
    )
    if main_pawn == nil then
        return nil, "main_pawn_data_unresolved"
    end

    local runtime_character = main_pawn.runtime_character
    if not access.is_valid_obj(runtime_character) then
        return nil, "runtime_character_unresolved"
    end

    local current_job, human, job_context = resolve_context_current_job(main_pawn, runtime_character)
    if current_job == nil or vocations.get_job(current_job) == nil then
        return nil, "main_pawn_job_unrecognized"
    end

    local action_manager = resolve_action_manager(main_pawn, runtime_character)
    if not access.is_valid_obj(action_manager) then
        return nil, "action_manager_unresolved"
    end

    local decision_maker = field_first(runtime_character, {
        "<AIDecisionMaker>k__BackingField",
        "AIDecisionMaker",
    }) or call_first(runtime_character, "get_AIDecisionMaker")
    local decision_module = field_first(decision_maker, {
        "<DecisionModule>k__BackingField",
        "DecisionModule",
    }) or call_first(decision_maker, "get_DecisionModule")
    local decision_executor = field_first(decision_module, {
        "<DecisionExecutor>k__BackingField",
        "_DecisionExecutor",
        "DecisionExecutor",
    }) or call_first(decision_module, "get_DecisionExecutor")
    local executing_decision = field_first(decision_executor, {
        "<ExecutingDecision>k__BackingField",
        "_ExecutingDecision",
        "ExecutingDecision",
    }) or call_first(decision_executor, "get_ExecutingDecision")
    local ai_blackboard = field_first(runtime_character, {
        "<AIBlackBoardController>k__BackingField",
        "AIBlackBoardController",
    }) or call_first(runtime_character, "get_AIBlackBoardController")
    local ai_meta_controller = access.present_field(ai_blackboard, {
        "<AIMetaController>k__BackingField",
        "AIMetaController",
    })
    local cached_pawn_order_target_controller = access.present_field(ai_meta_controller, {
        "<CachedPawnOrderTargetController>k__BackingField",
        "CachedPawnOrderTargetController",
    })
    local ai_blackboard_order_target_controller = access.present_field(ai_blackboard, {
        "<OrderTargetController>k__BackingField",
        "_OrderTargetController",
        "OrderTargetController",
    })
    local ai_blackboard_battle_controller = access.present_field(ai_blackboard, {
        "<BattleController>k__BackingField",
        "_BattleController",
        "BattleController",
    })
    local ai_blackboard_order_controller = access.present_field(ai_blackboard, {
        "<OrderController>k__BackingField",
        "_OrderController",
        "OrderController",
    })
    local human_action_selector = access.present_field(human, {
        "<HumanActionSelector>k__BackingField",
        "HumanActionSelector",
    })
    local common_action_selector = access.present_field(human, {
        "<CommonActionSelector>k__BackingField",
        "CommonActionSelector",
    })
    local human_order_target_controller = access.present_field(human_action_selector, {
        "<OrderTargetController>k__BackingField",
        "_OrderTargetController",
        "OrderTargetController",
    })
    local common_order_target_controller = access.present_field(common_action_selector, {
        "<OrderTargetController>k__BackingField",
        "_OrderTargetController",
        "OrderTargetController",
    })
    local pawn_manager = access.safe_singleton("managed", "app.PawnManager")
    local pawn_manager_order_target_controller = access.field_first(pawn_manager, {
        "<PawnOrderTargetController>k__BackingField",
        "PawnOrderTargetController",
    }) or access.call_first(pawn_manager, "get_PawnOrderTargetController")

    local current_action = field_first(action_manager, "CurrentAction")
    local selected_request = field_first(action_manager, "SelectedRequest")
    local context = {
        main_pawn = main_pawn,
        runtime_character = runtime_character,
        human = human,
        job_context = job_context,
        current_job = decode_small_int(current_job),
        action_manager = action_manager,
        decision_maker = decision_maker,
        decision_module = decision_module,
        decision_executor = decision_executor,
        executing_decision = executing_decision,
        ai_blackboard = ai_blackboard,
        ai_meta_controller = ai_meta_controller,
        cached_pawn_order_target_controller = cached_pawn_order_target_controller,
        ai_blackboard_order_target_controller = ai_blackboard_order_target_controller,
        ai_blackboard_battle_controller = ai_blackboard_battle_controller,
        ai_blackboard_order_controller = ai_blackboard_order_controller,
        human_action_selector = human_action_selector,
        common_action_selector = common_action_selector,
        human_order_target_controller = human_order_target_controller,
        common_order_target_controller = common_order_target_controller,
        pawn_manager_order_target_controller = pawn_manager_order_target_controller,
        lock_on_ctrl = main_pawn.lock_on_ctrl or call_first(runtime_character, "get_LockOnCtrl"),
        current_action = current_action,
        selected_request = selected_request,
        current_action_identity = access.resolve_pack_like_identity(current_action),
        selected_request_identity = access.resolve_pack_like_identity(selected_request),
        decision_pack_path = access.resolve_decision_pack_path(decision_module, executing_decision),
        full_node = main_pawn.full_node or get_current_node(action_manager, 0),
        upper_node = main_pawn.upper_node or get_current_node(action_manager, 1),
        context_resolution_source = tostring(main_pawn_source or "runtime_main_pawn_data"),
        context_resolution_age = tonumber(main_pawn_age) or 0.0,
    }
    context.output_texts = build_output_text_list(context)
    context.output_blob = table.concat(context.output_texts, " | ")
    context.output_blob_lower = string.lower(context.output_blob)

    return context, nil
end

return hybrid_context

local state = require("PawnHybridVocationsAI/core/runtime")
local access = require("PawnHybridVocationsAI/core/access")
local config = require("PawnHybridVocationsAI/config")
local hybrid_context = require("PawnHybridVocationsAI/game/hybrid_context")
local hybrid_targeting = require("PawnHybridVocationsAI/game/hybrid_targeting")
local hybrid_executor = require("PawnHybridVocationsAI/game/hybrid_executor")
local attack_graphs = require("PawnHybridVocationsAI/data/attack_graphs")
local vocations = require("PawnHybridVocationsAI/data/vocations")

local content_editor_capture = {}

local installed = false
local collect_runtime_summary
local trace_state = {
    active = false,
    started_at = nil,
    started_wall_time = nil,
    samples = {},
    segments = {},
    hits = {},
    current_segment = nil,
    last_signature = nil,
    last_sample_at = nil,
    last_hit_at = nil,
}

local JOB_PARAM_FIELDS = {
    [1] = "Job01Parameter",
    [2] = "Job02Parameter",
    [3] = "Job03Parameter",
    [4] = "Job04Parameter",
    [5] = "Job05Parameter",
    [6] = "Job06Parameter",
    [7] = "Job07Parameter",
    [8] = "Job08Parameter",
    [9] = "Job09Parameter",
    [10] = "Job10Parameter",
}

local BASE_ATTACK_RESEARCH_TYPES = {
    "app.ActionManager",
    "app.ActInterPackData",
    "app.AIBlackBoardController",
    "app.AIBlackBoardExtensions",
    "app.HitController.DamageInfo",
    "app.HumanCustomSkillID",
    "app.AttackUserData",
    "app.AttackHitController",
}

local JOB_TYPE_SUFFIXES = {
    "Parameter",
    "ActionCtrl",
    "ActionSelector",
    "InputProcessor",
}

local EXTRA_ATTACK_RESEARCH_TYPES = {
    "app.Job07MagicBindShell",
}

local STATIC_SNAPSHOT_TYPES = {
    "app.Character.JobEnum",
    "app.CharacterData.JobDefine",
    "app.JobUniqueParameter",
    "app.HumanParam",
    "app.HumanJobParam",
    "app.HumanJobParameter",
    "app.HumanSkillContext",
    "app.HumanSkillState",
    "app.HumanSkillAvailability",
    "app.HumanCustomSkillID",
    "app.HumanCustomSkillParam",
    "app.HumanAbilityID",
    "app.HumanAbilityContext",
    "app.HumanAbilityParam",
    "app.HumanActionSelector",
    "app.CommonActionSelector",
    "app.ActionData",
    "app.ActionRequest",
    "app.HitController",
    "app.DamageReactionController",
    "app.HumanEnemyParameterBase.NPCCombatParamTemplate",
    "via.motion.Motion",
    "via.motion.MotionListResource",
    "via.motion.DynamicMotionBank",
}

local function safe_require(name)
    local ok, module = pcall(require, name)
    return ok and module or nil
end

local function timestamp()
    return os.date("%Y%m%d_%H%M%S")
end

local function dump_path(label)
    return string.format("ce_dump/PawnHybridVocationsAI_%s_%s.json", tostring(label or "dump"), timestamp())
end

local function safe_call(fn, fallback)
    local ok, result = pcall(fn)
    if ok then
        return result
    end
    return fallback
end

local function safe_export(import_handlers, obj)
    if obj == nil then
        return nil
    end

    if type(obj) ~= "userdata" then
        return obj
    end

    if not access.is_valid_obj(obj) then
        return {
            error = "invalid_userdata",
            object = access.describe_obj(obj),
        }
    end

    local ok, exported = pcall(function()
        return import_handlers.export(obj, nil, { raw = true })
    end)

    if ok then
        return exported
    end

    return {
        error = tostring(exported),
        object = access.describe_obj(obj),
    }
end

local function sanitize(value, depth, seen)
    local value_type = type(value)
    if value == nil or value_type == "string" or value_type == "number" or value_type == "boolean" then
        return value
    end
    if value_type == "userdata" then
        return access.describe_obj(value)
    end
    if value_type == "function" or value_type == "thread" then
        return tostring(value_type)
    end
    if value_type ~= "table" then
        return tostring(value)
    end

    depth = tonumber(depth) or 0
    if depth <= 0 then
        return "<max_depth>"
    end

    seen = seen or {}
    if seen[value] then
        return "<cycle>"
    end
    seen[value] = true

    local out = {}
    local count = 0
    for key, item in pairs(value) do
        count = count + 1
        if count > 160 then
            out.__truncated = true
            break
        end
        out[tostring(key)] = sanitize(item, depth - 1, seen)
    end

    seen[value] = nil
    return out
end

local function compact_obj(obj)
    return access.describe_obj(obj)
end

local function format_job_prefix(job_id)
    local normalized = tonumber(job_id)
    if normalized == nil then
        return "JobXX"
    end
    return string.format("Job%02d", normalized)
end

local function resolve_attack_context(runtime)
    local context, reason = hybrid_context.resolve(runtime)
    if context ~= nil then
        return context, reason or "hybrid_context"
    end

    local data = runtime and runtime.main_pawn_data or nil
    local runtime_character = data and data.runtime_character or nil
    local action_manager = data and data.action_manager or nil
    if not access.is_valid_obj(runtime_character) or not access.is_valid_obj(action_manager) then
        return nil, tostring(reason or "main_pawn_action_context_unresolved")
    end

    local decision_maker = access.field_first(runtime_character, {
        "<AIDecisionMaker>k__BackingField",
        "AIDecisionMaker",
    }) or access.call_first(runtime_character, "get_AIDecisionMaker")
    local decision_module = access.field_first(decision_maker, {
        "<DecisionModule>k__BackingField",
        "DecisionModule",
    }) or access.call_first(decision_maker, "get_DecisionModule")
    local decision_executor = access.field_first(decision_module, {
        "<DecisionExecutor>k__BackingField",
        "_DecisionExecutor",
        "DecisionExecutor",
    }) or access.call_first(decision_module, "get_DecisionExecutor")
    local executing_decision = access.field_first(decision_executor, {
        "<ExecutingDecision>k__BackingField",
        "_ExecutingDecision",
        "ExecutingDecision",
    }) or access.call_first(decision_executor, "get_ExecutingDecision")
    local ai_blackboard = access.field_first(runtime_character, {
        "<AIBlackBoardController>k__BackingField",
        "AIBlackBoardController",
    }) or access.call_first(runtime_character, "get_AIBlackBoardController")
    local current_action = access.field_first(action_manager, "CurrentAction")
    local selected_request = access.field_first(action_manager, "SelectedRequest")

    local generic = {
        main_pawn = data,
        runtime_character = runtime_character,
        human = data and data.human or access.call_first(runtime_character, "get_Human"),
        current_job = access.decode_small_int(data and data.current_job)
            or access.decode_small_int(data and data.job),
        action_manager = action_manager,
        decision_maker = decision_maker,
        decision_module = decision_module,
        decision_executor = decision_executor,
        executing_decision = executing_decision,
        ai_blackboard = ai_blackboard,
        lock_on_ctrl = data and data.lock_on_ctrl or access.call_first(runtime_character, "get_LockOnCtrl"),
        current_action = current_action,
        selected_request = selected_request,
        current_action_identity = access.resolve_pack_like_identity(current_action),
        selected_request_identity = access.resolve_pack_like_identity(selected_request),
        decision_pack_path = access.resolve_decision_pack_path(decision_module, executing_decision),
        full_node = data and data.full_node or access.get_current_node(action_manager, 0),
        upper_node = data and data.upper_node or access.get_current_node(action_manager, 1),
    }

    generic.output_texts = {
        tostring(generic.decision_pack_path or "nil"),
        tostring(generic.current_action_identity or "nil"),
        tostring(generic.selected_request_identity or "nil"),
        tostring(generic.full_node or "nil"),
        tostring(generic.upper_node or "nil"),
    }
    generic.output_blob = table.concat(generic.output_texts, " | ")
    generic.output_blob_lower = string.lower(generic.output_blob)

    return generic, tostring(reason or "generic_action_context")
end

local function compact_runtime_value(value)
    if value == nil then
        return nil
    end

    local value_type = type(value)
    if value_type == "string" or value_type == "number" or value_type == "boolean" then
        return value
    end
    if value_type == "userdata" then
        return compact_obj(value)
    end

    return tostring(value)
end

local function probe_fields(obj, field_names)
    local out = {}
    if not access.is_valid_obj(obj) then
        return out
    end

    for _, field_name in ipairs(field_names or {}) do
        local value = access.field_first(obj, field_name)
        if value ~= nil then
            out[tostring(field_name)] = compact_runtime_value(value)
        end
    end

    return out
end

local function probe_methods(obj, method_names)
    local out = {}
    if not access.is_valid_obj(obj) then
        return out
    end

    for _, method_name in ipairs(method_names or {}) do
        local value = access.call_first(obj, method_name)
        if value ~= nil then
            out[tostring(method_name)] = compact_runtime_value(value)
        end
    end

    return out
end

local function describe_type_member(member)
    local name = safe_call(function()
        return member:get_name()
    end, tostring(member))
    local signature = safe_call(function()
        return member:to_string()
    end, tostring(member))

    return {
        name = tostring(name or "nil"),
        signature = tostring(signature or "nil"),
    }
end

local function describe_type_definition(type_name)
    local td = access.safe_sdk_typedef(type_name)
    if td == nil then
        return {
            type_name = tostring(type_name),
            status = "missing",
        }
    end

    local fields = {}
    local methods = {}
    local ok_fields, raw_fields = pcall(function()
        return td:get_fields()
    end)
    if ok_fields and type(raw_fields) == "table" then
        for index, field in ipairs(raw_fields) do
            if index > 260 then
                fields.__truncated = true
                break
            end
            fields[#fields + 1] = describe_type_member(field)
        end
    end

    local ok_methods, raw_methods = pcall(function()
        return td:get_methods()
    end)
    if ok_methods and type(raw_methods) == "table" then
        for index, method in ipairs(raw_methods) do
            if index > 360 then
                methods.__truncated = true
                break
            end
            methods[#methods + 1] = describe_type_member(method)
        end
    end

    return {
        type_name = tostring(type_name),
        status = "ok",
        full_name = tostring(safe_call(function()
            return td:get_full_name()
        end, type_name)),
        fields = fields,
        methods = methods,
    }
end

local function collect_typedef_field_names(type_name, max_count)
    local td = access.safe_sdk_typedef(type_name)
    if td == nil then
        return {}, "missing", false
    end

    local ok_fields, raw_fields = pcall(function()
        return td:get_fields()
    end)
    if not ok_fields or type(raw_fields) ~= "table" then
        return {}, "fields_unavailable", false
    end

    local out = {}
    local truncated = false
    local limit = tonumber(max_count) or 180
    for index, field in ipairs(raw_fields) do
        if index > limit then
            truncated = true
            break
        end

        local name = safe_call(function()
            return field:get_name()
        end)
        if type(name) == "string" and name ~= "" then
            out[#out + 1] = name
        end
    end

    return out, "ok", truncated
end

local function collect_object_field_exports(import_handlers, obj, type_name, max_count)
    local field_names, field_status, field_truncated = collect_typedef_field_names(type_name, max_count)
    local fields = {}

    for _, field_name in ipairs(field_names) do
        local value = access.field_first(obj, field_name)
        fields[tostring(field_name)] = {
            object = compact_obj(value),
            export = safe_export(import_handlers, value),
        }
    end

    return {
        type_name = tostring(type_name or "nil"),
        object = compact_obj(obj),
        field_status = tostring(field_status or "nil"),
        field_truncated = field_truncated == true,
        fields = fields,
    }
end

local function get_human_param()
    local character_manager = access.safe_singleton("managed", "app.CharacterManager")
    return character_manager and safe_call(function()
        return character_manager:get_HumanParam()
    end) or nil
end

local function get_job_param_root()
    local human_param = get_human_param()
    if human_param == nil then
        return nil
    end

    return access.field_first(human_param, {
        "JobParam",
        "<JobParam>k__BackingField",
        "_JobParam",
    })
end

local function collect_human_param_static_roots(import_handlers)
    local human_param = get_human_param()
    local root_fields = {
        "JobParam",
        "AbilityParam",
        "SkillParam",
        "CustomSkillParam",
        "CustomSkillLevelParam",
        "NormalSkillParam",
        "SkillLevelParam",
        "JobAbilityParam",
        "JobAbilityParameters",
        "LevelParam",
        "StatusParam",
        "StaminaParam",
        "NPCCombatParam",
    }

    local roots = {}
    for _, field_name in ipairs(root_fields) do
        local value = access.field_first(human_param, {
            field_name,
            "<" .. field_name .. ">k__BackingField",
            "_" .. field_name,
        })
        roots[field_name] = {
            object = compact_obj(value),
            export = safe_export(import_handlers, value),
        }
    end

    local human_type_name = access.get_type_full_name(human_param) or "app.HumanParam"
    return {
        note = "Heavy static export. This is read-only CE data from CharacterManager:get_HumanParam(); no game files are modified.",
        human_param_object = compact_obj(human_param),
        human_param_export = safe_export(import_handlers, human_param),
        human_param_fields = collect_object_field_exports(import_handlers, human_param, human_type_name, 180),
        root_exports = roots,
    }
end

local function collect_human_job_params(import_handlers)
    local job_param = get_job_param_root()
    local out = {}

    for job_id, field_name in pairs(JOB_PARAM_FIELDS) do
        local value = access.field_first(job_param, {
            field_name,
            "<" .. field_name .. ">k__BackingField",
            "_" .. field_name,
        })
        out[tostring(job_id)] = {
            field = field_name,
            export = safe_export(import_handlers, value),
        }
    end

    return out
end

local function collect_all_job_param_surfaces(import_handlers)
    local job_param = get_job_param_root()
    local out = {}

    for _, job in vocations.each() do
        local prefix = tostring(job.action_prefix or format_job_prefix(job.job_id))
        local field_name = tostring(JOB_PARAM_FIELDS[job.job_id] or prefix .. "Parameter")
        local expected_type_name = "app." .. prefix .. "Parameter"
        local value = access.field_first(job_param, {
            field_name,
            "<" .. field_name .. ">k__BackingField",
            "_" .. field_name,
        })

        out[tostring(job.job_id)] = {
            job_id = job.job_id,
            key = tostring(job.key or "nil"),
            label = tostring(job.label or "nil"),
            field = field_name,
            expected_type_name = expected_type_name,
            object = compact_obj(value),
            root_export = safe_export(import_handlers, value),
            parameter_field_exports = collect_object_field_exports(import_handlers, value, expected_type_name, 240),
        }
    end

    return out
end

local function collect_known_pack_paths()
    local seen = {}
    local out = {}

    for _, graph in attack_graphs.each() do
        for _, move in graph.each() do
            local pack_path = move and move.entry and move.entry.pack_path or nil
            if type(pack_path) == "string" and pack_path ~= "" and not seen[pack_path] then
                seen[pack_path] = true
                out[#out + 1] = pack_path
            end
        end
    end

    table.sort(out)
    return out
end

local function add_unique(list, seen, value)
    if type(value) ~= "string" or value == "" or seen[value] == true then
        return
    end

    seen[value] = true
    list[#list + 1] = value
end

local function build_action_class_guess(action_name)
    if type(action_name) ~= "string" or action_name == "" then
        return nil
    end

    return "app." .. action_name:gsub("_", "")
end

local function build_action_candidate(prefix, family)
    if type(family) ~= "string" or family == "" then
        return nil
    end
    if family:find(prefix, 1, true) == 1 then
        return family
    end
    if family:sub(1, 1) == "_" then
        return prefix .. family
    end
    return prefix .. "_" .. family
end

local function collect_all_job_action_candidates()
    local jobs = {}
    local flat = {}
    local flat_seen = {}

    for _, job in vocations.each() do
        local prefix = tostring(job.action_prefix or format_job_prefix(job.job_id))
        local job_actions = {}
        local seen = {}

        for _, family in ipairs(job.base_or_core_families or {}) do
            local action_name = build_action_candidate(prefix, tostring(family or ""))
            add_unique(job_actions, seen, action_name)
            add_unique(flat, flat_seen, action_name)
        end

        for _, skill in ipairs(job.all_custom_skills or job.custom_skills or {}) do
            add_unique(job_actions, seen, tostring(skill.name or ""))
            add_unique(flat, flat_seen, tostring(skill.name or ""))

            local runtime_phase = skill.runtime_phase or {}
            local contract = runtime_phase.execution_contract or skill.execution_contract or {}
            local candidates = contract.action_candidates
                or contract.probe_action_candidates
                or runtime_phase.action_candidates
                or {}
            for _, action_name in ipairs(candidates) do
                add_unique(job_actions, seen, tostring(action_name or ""))
                add_unique(flat, flat_seen, tostring(action_name or ""))
            end
        end

        table.sort(job_actions)
        jobs[tostring(job.job_id)] = {
            job_id = job.job_id,
            key = tostring(job.key or "nil"),
            prefix = prefix,
            action_candidates = job_actions,
        }
    end

    table.sort(flat)
    return {
        by_job = jobs,
        flat = flat,
    }
end

local function collect_all_job_attack_matrix()
    local out = {}
    local all_candidates = collect_all_job_action_candidates()
    for _, job in vocations.each() do
        local prefix = tostring(job.action_prefix or format_job_prefix(job.job_id))
        local action_candidates = all_candidates.by_job[tostring(job.job_id)]
        out[#out + 1] = {
            job_id = job.job_id,
            key = tostring(job.key or "nil"),
            label = tostring(job.label or "nil"),
            action_prefix = prefix,
            job_param_field = tostring(JOB_PARAM_FIELDS[job.job_id] or "nil"),
            ability_band = sanitize(job.ability_band, 3),
            base_or_core_families = sanitize(job.base_or_core_families, 4),
            custom_skills = sanitize(job.all_custom_skills or job.custom_skills, 8),
            generated_action_candidates = sanitize(action_candidates and action_candidates.action_candidates or {}, 4),
            expected_type_names = {
                parameter = "app." .. prefix .. "Parameter",
                action_ctrl = "app." .. prefix .. "ActionCtrl",
                action_selector = "app." .. prefix .. "ActionSelector",
                input_processor = "app." .. prefix .. "InputProcessor",
            },
        }
    end
    return out
end

local function collect_pack_exports(import_handlers)
    local out = {}
    for _, pack_path in ipairs(collect_known_pack_paths()) do
        local pack_data = access.safe_create_userdata("app.ActInterPackData", pack_path)
        out[#out + 1] = {
            path = pack_path,
            created = pack_data ~= nil,
            export = safe_export(import_handlers, pack_data),
        }
    end
    return out
end

local function collect_runtime_move_matrix()
    local out = {}
    for job_id, graph in attack_graphs.each() do
        local moves = {}
        for _, move in graph.each() do
            moves[#moves + 1] = {
                key = tostring(move.key or "nil"),
                family = tostring(move.family or "nil"),
                label = tostring(move.label or "nil"),
                cooldown_seconds = move.cooldown_seconds,
                failure_cooldown_seconds = move.failure_cooldown_seconds,
                stability = tostring(move.stability or "stable"),
                output_tokens = sanitize(move.output_tokens, 4),
                availability = sanitize(move.availability, 5),
                selection = sanitize(move.selection, 5),
                damage = sanitize(move.damage, 5),
                animation = sanitize(move.animation, 5),
                entry = sanitize(move.entry, 5),
                sequence = sanitize(move.sequence, 6),
                chain = sanitize(move.chain, 5),
                flow = sanitize(move.flow, 5),
            }
        end
        out[string.format("job%02d", tonumber(job_id) or 0)] = {
            job_id = job_id,
            key = tostring(graph.key or "nil"),
            label = tostring(graph.label or "nil"),
            action_prefix = tostring(graph.action_prefix or "nil"),
            move_count = #moves,
            moves = moves,
        }
    end
    return out
end

local function collect_vocation_skill_matrix()
    local out = {}
    for _, job in vocations.each() do
        out[#out + 1] = {
            job_id = job.job_id,
            key = tostring(job.key or "nil"),
            label = tostring(job.label or "nil"),
            action_prefix = tostring(job.action_prefix or "nil"),
            hybrid = job.hybrid == true,
            ability_band = sanitize(job.ability_band, 3),
            input_processor = tostring(job.input_processor or "nil"),
            controller_getter = tostring(job.controller_getter or "nil"),
            controller_field = tostring(job.controller_field or "nil"),
            base_or_core_families = sanitize(job.base_or_core_families, 4),
            custom_skills = sanitize(job.all_custom_skills or job.custom_skills, 7),
        }
    end
    return out
end

local function collect_attack_research_types()
    local out = {}
    local seen = {}

    for _, type_name in ipairs(BASE_ATTACK_RESEARCH_TYPES) do
        add_unique(out, seen, type_name)
    end
    for _, type_name in ipairs(EXTRA_ATTACK_RESEARCH_TYPES) do
        add_unique(out, seen, type_name)
    end
    for _, job in vocations.each() do
        local prefix = tostring(job.action_prefix or format_job_prefix(job.job_id))
        for _, suffix in ipairs(JOB_TYPE_SUFFIXES) do
            add_unique(out, seen, "app." .. prefix .. suffix)
        end
    end

    local action_candidates = collect_all_job_action_candidates()
    for _, action_name in ipairs(action_candidates.flat or {}) do
        add_unique(out, seen, build_action_class_guess(action_name))
    end

    table.sort(out)
    return out
end

local function collect_static_research_types()
    local out = {}
    local seen = {}

    for _, type_name in ipairs(STATIC_SNAPSHOT_TYPES) do
        add_unique(out, seen, type_name)
    end
    for _, type_name in ipairs(collect_attack_research_types()) do
        add_unique(out, seen, type_name)
    end

    table.sort(out)
    return out
end

local function collect_type_surfaces(type_names)
    local out = {}
    for _, type_name in ipairs(type_names or collect_attack_research_types()) do
        out[type_name] = describe_type_definition(type_name)
    end
    return out
end

local function resolve_current_job_controller(data)
    local current_job = access.decode_small_int(data and data.current_job)
    local getter = vocations.get_controller_getter(current_job)
    local field_name = vocations.get_controller_field(current_job)
    local prefix = format_job_prefix(current_job)
    local generic_getter = "get_" .. prefix .. "ActionCtrl"
    local generic_fields = {
        "<" .. prefix .. "ActionCtrl>k__BackingField",
        "_" .. prefix .. "ActionCtrl",
        prefix .. "ActionCtrl",
    }
    if type(field_name) == "string" and field_name ~= "" then
        table.insert(generic_fields, 1, field_name)
    end

    return access.call_first(data and data.human, getter)
        or access.field_first(data and data.human, field_name)
        or access.call_first(data and data.human, generic_getter)
        or access.field_first(data and data.human, generic_fields)
        or access.call_first(data and data.runtime_character, getter)
        or access.field_first(data and data.runtime_character, field_name)
        or access.call_first(data and data.runtime_character, generic_getter)
        or access.field_first(data and data.runtime_character, generic_fields)
end

local function collect_attack_runtime_surface(import_handlers)
    local runtime = state.runtime
    local data = runtime and runtime.main_pawn_data or nil
    local context, context_reason = resolve_attack_context(runtime)
    local target_info, target_reason, probes = nil, nil, nil
    if context ~= nil then
        target_info, target_reason, probes = hybrid_targeting.resolve(
            context,
            runtime,
            runtime and runtime.combat_data or {},
            runtime and runtime.game_time or os.clock()
        )
    end

    local controller = resolve_current_job_controller(data)

    return {
        runtime_summary = collect_runtime_summary(),
        context_reason = tostring(context_reason or "ok"),
        target_reason = tostring(target_reason or "nil"),
        target_probes = hybrid_targeting.describe_probes(probes),
        current_output = context and hybrid_context.build_output_blob(context) or "nil",
        action_manager = safe_export(import_handlers, data and data.action_manager),
        current_action = safe_export(import_handlers, context and context.current_action),
        selected_request = safe_export(import_handlers, context and context.selected_request),
        decision_module = safe_export(import_handlers, context and context.decision_module),
        executing_decision = safe_export(import_handlers, context and context.executing_decision),
        ai_blackboard = safe_export(import_handlers, context and context.ai_blackboard),
        current_job_controller = safe_export(import_handlers, controller),
        motion = safe_export(import_handlers, data and data.motion),
    }
end

local function compact_main_pawn_data(data)
    if type(data) ~= "table" then
        return nil
    end

    return {
        pawn = compact_obj(data.pawn),
        runtime_character = compact_obj(data.runtime_character),
        object = compact_obj(data.object),
        human = compact_obj(data.human),
        action_manager = compact_obj(data.action_manager),
        job_context = compact_obj(data.job_context),
        skill_context = compact_obj(data.skill_context),
        ability_context = compact_obj(data.ability_context),
        skill_state = compact_obj(data.skill_state),
        lock_on_ctrl = compact_obj(data.lock_on_ctrl),
        motion = compact_obj(data.motion),
        name = tostring(data.name or "nil"),
        chara_id = tostring(data.chara_id or "nil"),
        job = tostring(data.job or "nil"),
        weapon_job = tostring(data.weapon_job or "nil"),
        current_job = tostring(data.current_job or "nil"),
        full_node = tostring(data.full_node or "nil"),
        upper_node = tostring(data.upper_node or "nil"),
    }
end

local function collect_ai_components(import_handlers, utils)
    local pawn_manager = access.safe_singleton("managed", "app.PawnManager")
    local pawn_ai_data = pawn_manager and safe_call(function()
        return pawn_manager:get_AIData()
    end)
    local pawn_ai_go = _G.ce_find and safe_call(function()
        return _G.ce_find(":app.PawnUpdateController::item:get_GameObject()", true)
    end)

    local components = {
        pawn_ai_data = safe_export(import_handlers, pawn_ai_data),
        pawn_ai_root = safe_export(import_handlers, pawn_ai_go),
    }

    if pawn_ai_go ~= nil and utils and utils.gameobject then
        local names = {
            "app.PawnUpdateController",
            "app.PawnBattleController",
            "app.PawnOrderController",
            "app.PawnOrderTargetController",
            "app.AIMetaController",
        }

        for _, name in ipairs(names) do
            local component = safe_call(function()
                return utils.gameobject.get_component(pawn_ai_go, name)
            end)
            components[name] = safe_export(import_handlers, component)
        end
    end

    return components
end

collect_runtime_summary = function()
    local runtime = state.runtime
    local data = runtime and runtime.main_pawn_data or nil
    local context, context_reason = resolve_attack_context(runtime)
    local target_info, target_reason, probes = nil, nil, nil

    if context ~= nil then
        target_info, target_reason, probes = hybrid_targeting.resolve(
            context,
            runtime,
            runtime and runtime.combat_data or {},
            runtime and runtime.game_time or os.clock()
        )
    end

    return {
        captured_at = os.date("%Y-%m-%d %H:%M:%S"),
        runtime_time = runtime and runtime.game_time or nil,
        main_pawn_resolution = {
            source = runtime and runtime.main_pawn_data_resolution_source or "nil",
            reason = runtime and runtime.main_pawn_data_resolution_reason or "nil",
            age = runtime and runtime.main_pawn_data_resolution_age or nil,
        },
        main_pawn = compact_main_pawn_data(data),
        context = {
            reason = tostring(context_reason or "ok"),
            current_job = context and tostring(context.current_job or "nil") or "nil",
            output = context and hybrid_context.build_output_blob(context) or "nil",
            current_action = compact_obj(context and context.current_action),
            selected_request = compact_obj(context and context.selected_request),
            ai_blackboard = compact_obj(context and context.ai_blackboard),
            decision_module = compact_obj(context and context.decision_module),
            full_node = tostring(context and context.full_node or "nil"),
            upper_node = tostring(context and context.upper_node or "nil"),
        },
        target = {
            reason = tostring(target_reason or "nil"),
            character = compact_obj(target_info and target_info.character),
            object = compact_obj(target_info and target_info.game_object),
            distance = target_info and target_info.distance or nil,
            probes = hybrid_targeting.describe_probes(probes),
        },
        progression = sanitize(runtime and runtime.progression_state_data, 4),
        combat = sanitize(runtime and runtime.combat_data, 4),
        scheduler_errors = sanitize(runtime and runtime.scheduler_errors, 3),
    }
end

local function dump_runtime_summary()
    local path = dump_path("runtime_summary")
    json.dump_file(path, collect_runtime_summary())
    return path
end

local function dump_main_pawn_raw(import_handlers)
    local runtime = state.runtime
    local data = runtime and runtime.main_pawn_data or nil
    local path = dump_path("main_pawn_raw")

    json.dump_file(path, {
        captured_at = os.date("%Y-%m-%d %H:%M:%S"),
        summary = compact_main_pawn_data(data),
        pawn = safe_export(import_handlers, data and data.pawn),
        runtime_character = safe_export(import_handlers, data and data.runtime_character),
        human = safe_export(import_handlers, data and data.human),
        action_manager = safe_export(import_handlers, data and data.action_manager),
        job_context = safe_export(import_handlers, data and data.job_context),
        skill_context = safe_export(import_handlers, data and data.skill_context),
        skill_state = safe_export(import_handlers, data and data.skill_state),
    })

    return path
end

local function dump_ai_overview(import_handlers, utils)
    local path = dump_path("ai_overview")
    json.dump_file(path, {
        captured_at = os.date("%Y-%m-%d %H:%M:%S"),
        components = collect_ai_components(import_handlers, utils),
    })
    return path
end

local function dump_job07_params(import_handlers)
    local character_manager = access.safe_singleton("managed", "app.CharacterManager")
    local human_param = character_manager and safe_call(function()
        return character_manager:get_HumanParam()
    end)
    local job07 = human_param
        and human_param.JobParam
        and human_param.JobParam.Job07Parameter
        or nil
    local path = dump_path("job07_params")

    json.dump_file(path, {
        captured_at = os.date("%Y-%m-%d %H:%M:%S"),
        job07 = safe_export(import_handlers, job07),
    })

    return path
end

local function collect_all_jobs_static_snapshot(import_handlers)
    local static_type_names = collect_static_research_types()

    return {
        captured_at = os.date("%Y-%m-%d %H:%M:%S"),
        mod_version = tostring(config.version or "nil"),
        scope = "Job01-Job10",
        mode = "static_no_combat_required",
        purpose = "One-shot CE snapshot of all human jobs, skills, params, guessed action surfaces, controller/selector/input surfaces, hit/damage and motion-related type surfaces.",
        source_contract = {
            writes_game_folder = false,
            runtime_combat_required = false,
            primary_roots = {
                "CharacterManager:get_HumanParam()",
                "JobParam.Job01Parameter through JobParam.Job10Parameter",
                "sdk.find_type_definition(...) for job/action/selector/input/motion/hit surfaces",
            },
        },
        limitations = {
            "This dump exports every static surface we can reach through CE/import_handlers and sdk typedefs, but it cannot invent resource paths that CE does not expose.",
            "If animation asset paths are not present in JobXXParameter or ActInterPackData exports, the next pass must use CE resource/database evidence to enumerate motion banks.",
            "Known ActInterPackData exports currently include concrete paths already grounded by our runtime move table; all-job pack discovery depends on CE exposing additional paths.",
        },
        vocation_skill_matrix = collect_vocation_skill_matrix(),
        all_job_attack_matrix = collect_all_job_attack_matrix(),
        all_job_action_candidates = collect_all_job_action_candidates(),
        all_job_param_surfaces = collect_all_job_param_surfaces(import_handlers),
        human_job_params = collect_human_job_params(import_handlers),
        human_param_static_roots = collect_human_param_static_roots(import_handlers),
        implemented_runtime_move_matrix = collect_runtime_move_matrix(),
        known_actinter_packs = {
            note = "Concrete ActInter pack exports known from implemented runtime moves. This section is intentionally static and does not require combat.",
            exports = collect_pack_exports(import_handlers),
        },
        researched_type_names = static_type_names,
        type_surfaces = collect_type_surfaces(static_type_names),
    }
end

local function dump_all_jobs_static_snapshot(import_handlers)
    local path = dump_path("all_jobs_static_snapshot")
    json.dump_file(path, collect_all_jobs_static_snapshot(import_handlers))
    return path
end

local function dump_attack_graph(import_handlers)
    local path = dump_path("attack_graph")
    json.dump_file(path, {
        captured_at = os.date("%Y-%m-%d %H:%M:%S"),
        mod_version = tostring(config.version or "nil"),
        scope = "Job01-Job10",
        purpose = "All-job static and live research surface for skill/action/condition/animation relationships.",
        vocation_skill_matrix = collect_vocation_skill_matrix(),
        all_job_attack_matrix = collect_all_job_attack_matrix(),
        all_job_action_candidates = collect_all_job_action_candidates(),
        current_runtime_move_matrix = collect_runtime_move_matrix(),
        human_job_params = collect_human_job_params(import_handlers),
        known_actinter_packs = {
            note = "Currently known concrete ActInter pack paths from implemented runtime moves; all-job pack discovery requires CE/resource evidence.",
            exports = collect_pack_exports(import_handlers),
        },
        researched_type_names = collect_attack_research_types(),
        type_surfaces = collect_type_surfaces(),
        live_runtime_surface = collect_attack_runtime_surface(import_handlers),
    })
    return path
end

local function motion_probe(data)
    local motion = data and data.motion or nil
    return {
        object = compact_obj(motion),
        fields = probe_fields(motion, {
            "CurrentMotionID",
            "MotionID",
            "AnimationID",
            "Frame",
            "Time",
            "Speed",
            "Rate",
            "Layer",
        }),
        methods = probe_methods(motion, {
            "get_CurrentMotionID",
            "get_CurrentMotionNo",
            "get_MotionID",
            "get_AnimationID",
            "get_Frame",
            "get_PlayFrame",
            "get_NormalizedTime",
            "get_Time",
            "get_Speed",
            "get_Rate",
        }),
    }
end

local function action_manager_probe(action_manager)
    return {
        object = compact_obj(action_manager),
        fields = probe_fields(action_manager, {
            "CurrentAction",
            "SelectedRequest",
            "Fsm",
            "Layer",
            "Priority",
        }),
        methods = probe_methods(action_manager, {
            "get_CurrentAction",
            "get_SelectedRequest",
            "get_Fsm",
        }),
    }
end

local function build_attack_frame()
    local runtime = state.runtime
    local data = runtime and runtime.main_pawn_data or nil
    local combat_data = runtime and runtime.combat_data or nil
    local damage_data = runtime and runtime.combat_damage_data or nil
    local context, context_reason = resolve_attack_context(runtime)
    local target_info, target_reason, probes = nil, nil, nil
    if context ~= nil then
        target_info, target_reason, probes = hybrid_targeting.resolve(
            context,
            runtime,
            combat_data or {},
            runtime and runtime.game_time or os.clock()
        )
    end

    local now = tonumber(runtime and runtime.game_time or os.clock()) or 0.0
    local output = context and hybrid_context.build_output_blob(context) or "nil"
    local active_move = combat_data and combat_data.active and combat_data.active.move or nil

    return {
        time = now,
        wall_time = os.date("%Y-%m-%d %H:%M:%S"),
        context_reason = tostring(context_reason or "ok"),
        target_reason = tostring(target_reason or "nil"),
        target = compact_obj(target_info and target_info.character),
        target_distance = target_info and target_info.distance or nil,
        target_probes = hybrid_targeting.describe_probes(probes),
        active_move_key = tostring(active_move and active_move.key or combat_data and combat_data.last_move_key or "nil"),
        active_summary = hybrid_executor.describe_active(combat_data),
        chain_summary = hybrid_executor.describe_chain(combat_data, now),
        output = output,
        current_action_identity = tostring(context and context.current_action_identity or "nil"),
        selected_request_identity = tostring(context and context.selected_request_identity or "nil"),
        decision_pack_path = tostring(context and context.decision_pack_path or "nil"),
        full_node = tostring(context and context.full_node or "nil"),
        upper_node = tostring(context and context.upper_node or "nil"),
        motion = motion_probe(data),
        action_manager = action_manager_probe(data and data.action_manager),
        last_hit_at = damage_data and damage_data.last_hit_at or nil,
        last_hit_summary = tostring(damage_data and damage_data.last_hit_summary or "nil"),
        last_hit_move = tostring(damage_data and damage_data.last_hit_move or "nil"),
        last_hit_shell = tostring(damage_data and damage_data.last_hit_shell or "nil"),
        last_hit_phase = tostring(damage_data and damage_data.last_hit_phase or "nil"),
        last_hit_target_match = tostring(damage_data and damage_data.last_hit_target_match or "nil"),
    }
end

local function frame_signature(frame)
    local motion_methods = frame and frame.motion and frame.motion.methods or {}
    return table.concat({
        tostring(frame and frame.active_move_key or "nil"),
        tostring(frame and frame.current_action_identity or "nil"),
        tostring(frame and frame.selected_request_identity or "nil"),
        tostring(frame and frame.decision_pack_path or "nil"),
        tostring(frame and frame.full_node or "nil"),
        tostring(frame and frame.upper_node or "nil"),
        tostring(motion_methods.get_CurrentMotionID or motion_methods.get_MotionID or "nil"),
        tostring(motion_methods.get_AnimationID or "nil"),
    }, " | ")
end

local function close_trace_segment(now)
    if type(trace_state.current_segment) ~= "table" then
        return
    end

    trace_state.current_segment.exited_at = tonumber(now) or trace_state.current_segment.entered_at
    trace_state.current_segment.duration = math.max(
        0.0,
        trace_state.current_segment.exited_at - (tonumber(trace_state.current_segment.entered_at) or trace_state.current_segment.exited_at)
    )
    trace_state.segments[#trace_state.segments + 1] = trace_state.current_segment
    trace_state.current_segment = nil
end

local function append_trace_frame(frame, force_sample)
    local now = tonumber(frame and frame.time) or 0.0
    local signature = frame_signature(frame)

    if signature ~= trace_state.last_signature then
        close_trace_segment(now)
        trace_state.current_segment = {
            signature = signature,
            entered_at = now,
            active_move_key = tostring(frame.active_move_key or "nil"),
            current_action_identity = tostring(frame.current_action_identity or "nil"),
            selected_request_identity = tostring(frame.selected_request_identity or "nil"),
            decision_pack_path = tostring(frame.decision_pack_path or "nil"),
            full_node = tostring(frame.full_node or "nil"),
            upper_node = tostring(frame.upper_node or "nil"),
            motion = sanitize(frame.motion, 4),
            output = tostring(frame.output or "nil"),
            target = tostring(frame.target or "nil"),
            target_distance = frame.target_distance,
        }
        trace_state.last_signature = signature
        force_sample = true
    end

    local sample_interval = 0.05
    if force_sample == true
        or trace_state.last_sample_at == nil
        or (now - trace_state.last_sample_at) >= sample_interval then
        trace_state.samples[#trace_state.samples + 1] = sanitize(frame, 5)
        trace_state.last_sample_at = now
    end

    if frame.last_hit_at ~= nil and tostring(frame.last_hit_at) ~= tostring(trace_state.last_hit_at) then
        trace_state.hits[#trace_state.hits + 1] = {
            time = frame.time,
            hit_at = frame.last_hit_at,
            active_move_key = frame.active_move_key,
            full_node = frame.full_node,
            upper_node = frame.upper_node,
            shell = frame.last_hit_shell,
            phase = frame.last_hit_phase,
            target_match = frame.last_hit_target_match,
            summary = frame.last_hit_summary,
        }
        trace_state.last_hit_at = frame.last_hit_at
    end
end

local function start_attack_trace()
    local now = tonumber(state.runtime and state.runtime.game_time or os.clock()) or 0.0
    trace_state.active = true
    trace_state.started_at = now
    trace_state.started_wall_time = os.date("%Y-%m-%d %H:%M:%S")
    trace_state.samples = {}
    trace_state.segments = {}
    trace_state.hits = {}
    trace_state.current_segment = nil
    trace_state.last_signature = nil
    trace_state.last_sample_at = nil
    trace_state.last_hit_at = nil
    append_trace_frame(build_attack_frame(), true)
end

local function stop_attack_trace_and_dump()
    local now = tonumber(state.runtime and state.runtime.game_time or os.clock()) or 0.0
    append_trace_frame(build_attack_frame(), true)
    close_trace_segment(now)

    trace_state.active = false
    local path = dump_path("attack_trace")
    json.dump_file(path, {
        captured_at = os.date("%Y-%m-%d %H:%M:%S"),
        mod_version = tostring(config.version or "nil"),
        started_at = trace_state.started_at,
        started_wall_time = trace_state.started_wall_time,
        stopped_at = now,
        duration = trace_state.started_at ~= nil and math.max(0.0, now - trace_state.started_at) or nil,
        segments = sanitize(trace_state.segments, 7),
        hits = sanitize(trace_state.hits, 6),
        samples = sanitize(trace_state.samples, 6),
    })
    return path
end

local function dump_current_attack_frame()
    local path = dump_path("attack_frame")
    json.dump_file(path, build_attack_frame())
    return path
end

function content_editor_capture.install()
    if installed then
        return false, "already_installed"
    end

    local core = safe_require("content_editor.core")
    if core == nil or core.editor_enabled ~= true then
        return false, "content_editor_disabled"
    end

    local editor = safe_require("content_editor.editor")
    local import_handlers = safe_require("content_editor.import_handlers")
    local utils = safe_require("content_editor.utils")
    if editor == nil or import_handlers == nil then
        return false, "content_editor_api_unavailable"
    end

    editor.define_window("pawn_hybrid_capture", "Pawn Hybrid Capture", function(window_state)
        window_state = window_state or {}
        imgui.text("PawnHybridVocationsAI capture helper")
        imgui.text("Outputs go to reframework/data/ce_dump/")

        if imgui.button("Dump runtime summary") then
            window_state.last_result = dump_runtime_summary()
        end
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Small normalized snapshot: pawn context, target, selector state, progression, combat state.")
        end

        if imgui.button("Dump main pawn raw") then
            window_state.last_result = dump_main_pawn_raw(import_handlers)
        end
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Raw CE export of main pawn, Human, ActionManager, JobContext and SkillContext.")
        end

        if imgui.button("Dump AI overview raw") then
            window_state.last_result = dump_ai_overview(import_handlers, utils)
        end
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Raw CE export of Pawn AI data and Pawn AI controller components.")
        end

        if imgui.button("Dump Job07 params") then
            window_state.last_result = dump_job07_params(import_handlers)
        end
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Static Job07Parameter export from CharacterManager HumanParam.")
        end

        if type(imgui.separator) == "function" then
            imgui.separator()
        else
            imgui.spacing()
        end
        imgui.text("Attack graph research")

        if imgui.button("Dump ALL jobs static snapshot") then
            window_state.last_result = dump_all_jobs_static_snapshot(import_handlers)
        end
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Heavy no-combat CE export: Job01-Job10 params, skills, generated action candidates, controller/selector/input/action/motion/hit type surfaces.")
        end

        if imgui.button("Dump attack graph research") then
            window_state.last_result = dump_attack_graph(import_handlers)
        end
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Wide static+live export for Job01-Job10: vocation skills, job params, generated action candidates, ActInter packs, type surfaces, current runtime attack state.")
        end

        if imgui.button("Dump current attack frame") then
            window_state.last_result = dump_current_attack_frame()
        end
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Single-frame snapshot: current action/request/FSM/motion/target/hit state.")
        end

        if trace_state.active == true then
            imgui.text(string.format(
                "Attack trace recording: %.2fs, segments=%s, hits=%s, samples=%s",
                (tonumber(state.runtime and state.runtime.game_time or os.clock()) or 0.0) - (tonumber(trace_state.started_at) or 0.0),
                tostring(#trace_state.segments + (trace_state.current_segment and 1 or 0)),
                tostring(#trace_state.hits),
                tostring(#trace_state.samples)
            ))
            if imgui.button("Stop attack trace and dump") then
                window_state.last_result = stop_attack_trace_and_dump()
            end
        else
            if imgui.button("Start attack trace") then
                start_attack_trace()
                window_state.last_result = "attack_trace_started"
            end
        end
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Records action/FSM/motion transitions and hit timestamps until stopped.")
        end

        if window_state.last_result ~= nil then
            imgui.spacing()
            imgui.text("Last dump:")
            imgui.text(tostring(window_state.last_result))
        end
    end)

    editor.add_editor_tab("pawn_hybrid_capture")
    installed = true
    return true, "installed"
end

function content_editor_capture.update()
    if trace_state.active ~= true then
        return
    end

    local ok, err = pcall(function()
        append_trace_frame(build_attack_frame(), false)
    end)
    if not ok then
        trace_state.active = false
        trace_state.last_error = tostring(err)
    end
end

return content_editor_capture

-- Purpose:
-- Capture vocation/class definition surface from engine singletons and live progression contexts.
-- This is not a combat snapshot script; it focuses on class-level data that can be read in one screen:
--   * job / skill / ability enum surfaces
--   * CharacterManager HumanParam roots: JobParam, AbilityParam, ActionParam
--   * per-job JobXXParameter value trees
--   * per-job AbilityParameter entries
--   * type surfaces for JobXXParameter / InputProcessor / ActionController / ActionSelector
--   * live player and main_pawn SkillContext / availability / equipped-skill state
--
-- Output:
--   reframework/data/ce_dump/vocation_definition_surface_<timestamp>.json

local SHALLOW_FIELD_LIMIT = 24
local NUMERIC_TREE_DEPTH = 2
local NUMERIC_TREE_FIELD_LIMIT = 48
local NUMERIC_TREE_COLLECTION_LIMIT = 16
local MAX_METHODS_PER_TYPE = 160
local MAX_SKILL_SCAN = 512
local MAX_ABILITY_ITEMS_PER_JOB = 96

local JOB_LABELS = {
    [1] = "Fighter",
    [2] = "Archer",
    [3] = "Mage",
    [4] = "Thief",
    [5] = "Warrior",
    [6] = "Sorcerer",
    [7] = "Mystic Spearhand",
    [8] = "Magick Archer",
    [9] = "Trickster",
    [10] = "Warfarer",
}

local JOB_PARAM_FIELDS = {
    "JobParam",
    "<JobParam>k__BackingField",
    "_JobParam",
}

local ABILITY_PARAM_FIELDS = {
    "AbilityParam",
    "<AbilityParam>k__BackingField",
    "_AbilityParam",
}

local ACTION_PARAM_FIELDS = {
    "ActionParam",
    "<ActionParam>k__BackingField",
    "_ActionParam",
    "HumanActionParam",
    "<HumanActionParam>k__BackingField",
    "_HumanActionParam",
}

local SKILL_CONTEXT_FIELDS = {
    "<SkillContext>k__BackingField",
    "SkillContext",
    "_SkillContext",
}

local ABILITY_CONTEXT_FIELDS = {
    "<AbilityContext>k__BackingField",
    "AbilityContext",
    "_AbilityContext",
}

local JOB_CONTEXT_FIELDS = {
    "<JobContext>k__BackingField",
    "JobContext",
    "_JobContext",
}

local CUSTOM_SKILL_STATE_FIELDS = {
    "<CustomSkillState>k__BackingField",
    "CustomSkillState",
    "_CustomSkillState",
}

local ABILITY_LIST_FIELDS = {
    "JobAbilityParameters",
    "<JobAbilityParameters>k__BackingField",
    "_JobAbilityParameters",
}

local ABILITY_ITEM_FIELDS = {
    "Abilities",
    "<Abilities>k__BackingField",
    "_Abilities",
}

local EQUIPPED_SKILLS_FIELDS = {
    "EquipedSkills",
    "<EquipedSkills>k__BackingField",
    "_EquipedSkills",
}

local SKILLS_LIST_FIELDS = {
    "Skills",
    "<Skills>k__BackingField",
    "_Skills",
}

local PLAYER_CANDIDATES = {
    { source = "CharacterManager:get_ManualPlayer()", value = function(cm) return cm:call("get_ManualPlayer()") end },
    { source = "CharacterManager.<ManualPlayer>k__BackingField", value = function(cm) return cm["<ManualPlayer>k__BackingField"] end },
    { source = "CharacterManager._ManualPlayer", value = function(cm) return cm["_ManualPlayer"] end },
    { source = "CharacterManager:get_Player()", value = function(cm) return cm:call("get_Player()") end },
}

local MAIN_PAWN_CANDIDATES = {
    { source = "PawnManager:get_MainPawn()", value = function(pm, cm) return pm:call("get_MainPawn()") end },
    { source = "PawnManager._MainPawn", value = function(pm, cm) return pm["_MainPawn"] end },
    { source = "PawnManager.<MainPawn>k__BackingField", value = function(pm, cm) return pm["<MainPawn>k__BackingField"] end },
    { source = "CharacterManager:get_MainPawn()", value = function(pm, cm) return cm:call("get_MainPawn()") end },
    { source = "CharacterManager.<MainPawn>k__BackingField", value = function(pm, cm) return cm["<MainPawn>k__BackingField"] end },
    { source = "CharacterManager:get_ManualPlayerPawn()", value = function(pm, cm) return cm:call("get_ManualPlayerPawn()") end },
    { source = "CharacterManager:get_ManualPlayerMainPawn()", value = function(pm, cm) return cm:call("get_ManualPlayerMainPawn()") end },
}

local function try_eval(fn)
    local ok, value = pcall(fn)
    return ok, value
end

local function safe_call_method0(obj, methods)
    if obj == nil then
        return nil, "root_nil"
    end

    for _, method_name in ipairs(methods) do
        local ok, value = try_eval(function()
            return obj:call(method_name)
        end)
        if ok then
            return value, method_name
        end
    end

    return nil, "unresolved"
end

local function safe_call_method1(obj, methods, arg1)
    if obj == nil then
        return nil, "root_nil"
    end

    for _, method_name in ipairs(methods) do
        local ok, value = try_eval(function()
            return obj:call(method_name, arg1)
        end)
        if ok then
            return value, method_name
        end
    end

    return nil, "unresolved"
end

local function safe_call_method2(obj, methods, arg1, arg2)
    if obj == nil then
        return nil, "root_nil"
    end

    for _, method_name in ipairs(methods) do
        local ok, value = try_eval(function()
            return obj:call(method_name, arg1, arg2)
        end)
        if ok then
            return value, method_name
        end
    end

    return nil, "unresolved"
end

local function safe_field(obj, fields)
    if obj == nil then
        return nil, "root_nil"
    end

    for _, field_name in ipairs(fields) do
        local ok, value = try_eval(function()
            return obj[field_name]
        end)
        if ok then
            return value, field_name
        end
    end

    return nil, "unresolved"
end

local function safe_present_field(obj, fields)
    if obj == nil then
        return nil, "root_nil"
    end

    local last_source = "unresolved"
    for _, field_name in ipairs(fields) do
        local ok, value = try_eval(function()
            return obj[field_name]
        end)
        if ok then
            last_source = field_name
            if value ~= nil and tostring(value) ~= "nil" then
                return value, field_name
            end
        end
    end

    return nil, last_source
end

local function is_present(obj)
    return obj ~= nil and tostring(obj) ~= "nil"
end

local function get_type_name(obj)
    if obj == nil then
        return "nil"
    end

    local ok, value = try_eval(function()
        return obj:get_type_definition():get_full_name()
    end)
    if ok and value ~= nil then
        return tostring(value)
    end

    return type(obj)
end

local function describe(obj)
    if obj == nil then
        return "nil"
    end

    local value_type = type(obj)
    if value_type == "userdata" then
        return tostring(obj)
    end
    if value_type == "table" then
        return "<table>"
    end

    return tostring(obj)
end

local function to_string_or_nil(value)
    if value == nil then
        return nil
    end

    local value_type = type(value)
    if value_type == "string" or value_type == "number" or value_type == "boolean" then
        return tostring(value)
    end

    return nil
end

local function extract_enum_underlying(value)
    if value == nil then
        return nil
    end

    if type(value) == "number" then
        return value
    end

    local enum_value, _ = safe_field(value, { "value__" })
    if enum_value ~= nil then
        return tonumber(enum_value) or enum_value
    end

    return nil
end

local function extract_scalarish(value)
    local value_type = type(value)
    if value_type == "string" or value_type == "number" or value_type == "boolean" then
        return value
    end

    return extract_enum_underlying(value)
end

local function decode_truthy(value)
    if value == nil then
        return nil
    end

    if type(value) == "boolean" then
        return value
    end

    local scalar = extract_scalarish(value)
    if scalar == nil then
        return nil
    end

    local text = tostring(scalar)
    if text == "true" or text == "1" then
        return true
    end
    if text == "false" or text == "0" then
        return false
    end

    return nil
end

local function serialize_object(value, source)
    return {
        present = is_present(value),
        description = describe(value),
        type_name = get_type_name(value),
        source = source or "unresolved",
    }
end

local function serialize_scalar(value, source)
    return {
        present = value ~= nil,
        description = describe(value),
        type_name = type(value),
        source = source or "unresolved",
        value = value,
    }
end

local function get_collection_count(obj)
    if obj == nil then
        return nil, "root_nil"
    end

    local count, count_source = safe_call_method0(obj, {
        "get_Count()",
        "get_count()",
        "get_Size()",
        "get_size()",
    })
    if count ~= nil then
        return tonumber(count), count_source
    end

    local field_count, field_count_source = safe_field(obj, { "Count", "count", "_size", "size", "Length", "_Length" })
    if field_count ~= nil then
        return tonumber(field_count), field_count_source
    end

    return nil, "unresolved"
end

local function get_collection_item(obj, index)
    return safe_call_method1(obj, {
        "get_Item(System.Int32)",
        "get_Item(System.UInt32)",
        "get_Item",
    }, index)
end

local function get_indexed_item(obj, index)
    local item, item_source = get_collection_item(obj, index)
    if item ~= nil then
        return item, item_source
    end

    local ok, raw_item = try_eval(function()
        return obj[index]
    end)
    if ok then
        return raw_item, "index:" .. tostring(index)
    end

    return nil, "unresolved"
end

local function snapshot_shallow_fields(obj, limit)
    local result = {}

    if obj == nil or type(obj) ~= "userdata" then
        return result
    end

    local ok_td, td = try_eval(function()
        return obj:get_type_definition()
    end)
    if not ok_td or td == nil then
        return result
    end

    local ok_fields, fields = try_eval(function()
        return td:get_fields()
    end)
    if not ok_fields or fields == nil then
        return result
    end

    local max_fields = limit or SHALLOW_FIELD_LIMIT
    for index, field in ipairs(fields) do
        if index > max_fields then
            break
        end

        local field_name = "field_" .. tostring(index)
        local ok_name, resolved_name = try_eval(function()
            return field:get_name()
        end)
        if ok_name and resolved_name ~= nil then
            field_name = tostring(resolved_name)
        end

        local ok_value, value = try_eval(function()
            return field:get_data(obj)
        end)

        result[#result + 1] = {
            index = index,
            name = field_name,
            value = ok_value and serialize_object(value, "field:" .. field_name) or {
                present = false,
                description = "<read_error>",
                type_name = "error",
                source = "field:" .. field_name,
            },
        }
    end

    return result
end

local function get_object_identity(obj)
    if obj == nil or type(obj) ~= "userdata" then
        return nil
    end

    local ok, value = try_eval(function()
        return obj:get_address()
    end)
    if ok and value ~= nil then
        return tostring(value)
    end

    return tostring(obj)
end

local function capture_numeric_tree(value, depth, seen)
    local scalar = extract_scalarish(value)
    if scalar ~= nil then
        return scalar
    end

    if value == nil or type(value) ~= "userdata" then
        return nil
    end

    local identity = get_object_identity(value) or tostring(value)
    if seen[identity] then
        return "<cycle>"
    end
    seen[identity] = true

    local count = get_collection_count(value)
    if count ~= nil and count > 0 then
        local items = {}
        local max_items = math.min(count, NUMERIC_TREE_COLLECTION_LIMIT)
        for index = 0, max_items - 1 do
            local item, _ = get_indexed_item(value, index)
            local captured = depth > 0 and capture_numeric_tree(item, depth - 1, seen) or extract_scalarish(item)
            if captured ~= nil then
                items[#items + 1] = {
                    index = index,
                    value = captured,
                }
            end
        end
        seen[identity] = nil
        if #items > 0 then
            return items
        end
    end

    if depth <= 0 then
        seen[identity] = nil
        return nil
    end

    local ok_td, td = try_eval(function()
        return value:get_type_definition()
    end)
    if not ok_td or td == nil then
        seen[identity] = nil
        return nil
    end

    local ok_fields, fields = try_eval(function()
        return td:get_fields()
    end)
    if not ok_fields or fields == nil then
        seen[identity] = nil
        return nil
    end

    local out = {}
    local used_fields = 0
    for _, field in ipairs(fields) do
        if used_fields >= NUMERIC_TREE_FIELD_LIMIT then
            break
        end

        local field_name_ok, field_name_value = try_eval(function()
            return field:get_name()
        end)
        local field_name = field_name_ok and tostring(field_name_value) or "unknown"
        local ok_value, field_value = try_eval(function()
            return field:get_data(value)
        end)
        if ok_value and field_value ~= nil then
            local captured = extract_scalarish(field_value)
            if captured == nil then
                captured = capture_numeric_tree(field_value, depth - 1, seen)
            end
            if captured ~= nil then
                out[field_name] = captured
                used_fields = used_fields + 1
            end
        end
    end

    seen[identity] = nil
    return next(out) ~= nil and out or nil
end

local function capture_type_surface(type_name)
    local td = sdk.find_type_definition(type_name)
    if td == nil then
        return {
            present = false,
            type_name = type_name,
        }
    end

    local fields = {}
    local methods = {}
    local interesting_methods = {}

    local ok_fields, field_list = try_eval(function()
        return td:get_fields()
    end)
    if ok_fields and field_list ~= nil then
        for _, field in ipairs(field_list) do
            local ok_name, field_name = try_eval(function()
                return field:get_name()
            end)
            if ok_name and field_name ~= nil then
                fields[#fields + 1] = tostring(field_name)
            end
        end
    end

    local ok_methods, method_list = try_eval(function()
        return td:get_methods()
    end)
    if ok_methods and method_list ~= nil then
        for index, method in ipairs(method_list) do
            if index > MAX_METHODS_PER_TYPE then
                break
            end

            local ok_name, method_name = try_eval(function()
                return method:get_name()
            end)
            local name = ok_name and method_name ~= nil and tostring(method_name) or tostring(method)
            methods[#methods + 1] = name

            local lower_name = string.lower(name)
            if string.find(lower_name, "process", 1, true) ~= nil
                or string.find(lower_name, "request", 1, true) ~= nil
                or string.find(lower_name, "skill", 1, true) ~= nil
                or string.find(lower_name, "attack", 1, true) ~= nil
                or string.find(lower_name, "guard", 1, true) ~= nil
                or string.find(lower_name, "jump", 1, true) ~= nil
                or string.find(lower_name, "weapon", 1, true) ~= nil
                or string.find(lower_name, "bind", 1, true) ~= nil
            then
                interesting_methods[#interesting_methods + 1] = name
            end
        end
    end

    table.sort(fields)
    table.sort(methods)
    table.sort(interesting_methods)

    return {
        present = true,
        type_name = type_name,
        field_count = #fields,
        method_count = #methods,
        fields = fields,
        methods = methods,
        interesting_methods = interesting_methods,
    }
end

local function capture_enum_type(type_name)
    local td = sdk.find_type_definition(type_name)
    if td == nil then
        return {
            present = false,
            type_name = type_name,
            entries = {},
            value_to_name = {},
        }
    end

    local entries = {}
    local value_to_name = {}

    local ok_fields, fields = try_eval(function()
        return td:get_fields()
    end)
    if ok_fields and fields ~= nil then
        for _, field in ipairs(fields) do
            local ok_name, field_name = try_eval(function()
                return field:get_name()
            end)
            local name = ok_name and field_name ~= nil and tostring(field_name) or nil
            if name ~= nil and name ~= "value__" then
                local ok_value, raw_value = try_eval(function()
                    return field:get_data(nil)
                end)
                if ok_value then
                    local value = extract_enum_underlying(raw_value)
                    entries[#entries + 1] = {
                        name = name,
                        value = value,
                        display = describe(raw_value),
                    }
                    if value ~= nil and value_to_name[value] == nil then
                        value_to_name[value] = name
                    end
                end
            end
        end
    end

    table.sort(entries, function(a, b)
        local av = a.value
        local bv = b.value
        if av ~= nil and bv ~= nil and av ~= bv then
            return av < bv
        end
        if av ~= nil and bv == nil then
            return true
        end
        if av == nil and bv ~= nil then
            return false
        end
        return tostring(a.name) < tostring(b.name)
    end)

    return {
        present = true,
        type_name = type_name,
        entry_count = #entries,
        entries = entries,
        value_to_name = value_to_name,
    }
end

local function resolve_runtime_character_from_actor(actor)
    if actor == nil then
        return nil, "actor_nil"
    end

    if get_type_name(actor) == "app.Character" then
        return actor, "actor_is_character"
    end

    local value, source = safe_call_method0(actor, {
        "get_CachedCharacter()",
        "get_Character()",
        "get_Chara()",
        "get_PawnCharacter()",
    })
    if is_present(value) then
        return value, "actor:" .. source
    end

    local field_value, field_source = safe_field(actor, {
        "<CachedCharacter>k__BackingField",
        "<Character>k__BackingField",
        "<Chara>k__BackingField",
        "Character",
        "Chara",
    })
    if is_present(field_value) then
        return field_value, "actor:" .. field_source
    end

    return nil, "unresolved"
end

local function resolve_player(CharacterManager)
    for _, candidate in ipairs(PLAYER_CANDIDATES) do
        local ok, value = try_eval(function()
            return candidate.value(CharacterManager)
        end)
        if ok and is_present(value) then
            return value, candidate.source
        end
    end

    return nil, "unresolved"
end

local function resolve_main_pawn(PawnManager, CharacterManager)
    for _, candidate in ipairs(MAIN_PAWN_CANDIDATES) do
        local ok, value = try_eval(function()
            return candidate.value(PawnManager, CharacterManager)
        end)
        if ok and is_present(value) then
            return value, candidate.source
        end
    end

    return nil, "unresolved"
end

local function resolve_human(runtime_character)
    if runtime_character == nil then
        return nil, "runtime_character_nil"
    end

    local human, human_source = safe_call_method0(runtime_character, {
        "get_Human()",
    })
    if is_present(human) then
        return human, human_source
    end

    local field_human, field_human_source = safe_field(runtime_character, {
        "<Human>k__BackingField",
        "Human",
    })
    if is_present(field_human) then
        return field_human, field_human_source
    end

    return nil, "unresolved"
end

local function resolve_current_job(human, runtime_character)
    local job_context, job_context_source = safe_field(human, JOB_CONTEXT_FIELDS)
    if not is_present(job_context) then
        job_context, job_context_source = safe_call_method0(human, {
            "get_JobContext()",
        })
    end

    local current_job, current_job_source = safe_field(human, { "<CurrentJob>k__BackingField" })
    if current_job ~= nil then
        return current_job, "human:" .. tostring(current_job_source), job_context, job_context_source
    end

    local job_context_job, job_context_job_source = safe_field(job_context, { "CurrentJob" })
    if job_context_job ~= nil then
        return job_context_job, "job_context:" .. tostring(job_context_job_source), job_context, job_context_source
    end

    local method_job, method_job_source = safe_call_method0(runtime_character, {
        "get_CurrentJob()",
        "get_Job()",
    })
    if method_job ~= nil then
        return method_job, "runtime_character:" .. tostring(method_job_source), job_context, job_context_source
    end

    local field_job, field_job_source = safe_field(runtime_character, { "CurrentJob", "Job", "WeaponJob" })
    return field_job, "runtime_character:" .. tostring(field_job_source), job_context, job_context_source
end

local function call_get_job_level(job_context, job_id)
    if job_context == nil or job_id == nil then
        return nil, "unresolved"
    end

    local level, level_source = safe_call_method1(job_context, {
        "getJobLevel(System.Int32)",
        "getJobLevel(app.Character.JobEnum)",
        "getJobLevel",
    }, job_id)
    return level, level_source
end

local function resolve_skill_availability(skill_context)
    if skill_context == nil then
        return nil, "skill_context_nil"
    end

    local direct, direct_source = safe_call_method0(skill_context, {
        "get_Availability()",
        "get_Availability",
        "get_SkillAvailability()",
        "get_SkillAvailability",
    })
    if is_present(direct) then
        return direct, direct_source
    end

    local field, field_source = safe_field(skill_context, {
        "<Availability>k__BackingField",
        "Availability",
        "<SkillAvailability>k__BackingField",
        "SkillAvailability",
    })
    if is_present(field) then
        return field, field_source
    end

    return nil, "unresolved"
end

local function resolve_job_equip_list(skill_context, job_id)
    if skill_context == nil then
        return nil, "skill_context_nil"
    end

    local list, list_source = safe_call_method1(skill_context, {
        "getEquipList(System.Int32)",
        "getEquipList(app.Character.JobEnum)",
        "getEquipList",
    }, job_id)
    if is_present(list) then
        return list, list_source
    end

    local equipped_root, equipped_root_source = safe_present_field(skill_context, EQUIPPED_SKILLS_FIELDS)
    local indexed, indexed_source = get_indexed_item(equipped_root, job_id)
    if is_present(indexed) then
        return indexed, "equipped_root:" .. tostring(indexed_source)
    end

    local indexed_minus_one, indexed_minus_one_source = get_indexed_item(equipped_root, job_id - 1)
    if is_present(indexed_minus_one) then
        return indexed_minus_one, "equipped_root:" .. tostring(indexed_minus_one_source)
    end

    return nil, equipped_root_source
end

local function collect_equipped_skills(skill_context, skill_name_by_value)
    local by_job = {}
    local skill_to_jobs = {}

    for job_id = 1, 10 do
        local equip_list, equip_list_source = resolve_job_equip_list(skill_context, job_id)
        local skills_root, skills_root_source = safe_present_field(equip_list, SKILLS_LIST_FIELDS)
        local skill_count, skill_count_source = get_collection_count(skills_root)
        local slots = {}

        local max_slots = skill_count ~= nil and math.min(skill_count, 8) or 4
        for slot = 0, max_slots - 1 do
            local item, item_source = get_indexed_item(skills_root, slot)
            local skill_id = extract_enum_underlying(item) or extract_scalarish(item)
            slots[#slots + 1] = {
                slot = slot,
                item = serialize_object(item, item_source),
                skill_id = serialize_scalar(skill_id, item_source),
                skill_name = skill_id ~= nil and skill_name_by_value[skill_id] or nil,
            }

            if skill_id ~= nil and skill_id > 0 then
                if skill_to_jobs[skill_id] == nil then
                    skill_to_jobs[skill_id] = {}
                end
                skill_to_jobs[skill_id][#skill_to_jobs[skill_id] + 1] = job_id
            end
        end

        by_job[string.format("job%02d", job_id)] = {
            job_id = job_id,
            job_label = JOB_LABELS[job_id],
            equip_list = serialize_object(equip_list, equip_list_source),
            skills_root = serialize_object(skills_root, skills_root_source),
            skill_count = serialize_scalar(skill_count, skill_count_source),
            slots = slots,
        }
    end

    return by_job, skill_to_jobs
end

local function call_is_custom_skill_enable(skill_context, skill_id)
    if skill_context == nil or skill_id == nil then
        return nil, "unresolved"
    end

    return safe_call_method1(skill_context, {
        "isCustomSkillEnable(app.HumanCustomSkillID)",
        "isCustomSkillEnable",
    }, skill_id)
end

local function call_get_custom_skill_level(skill_context, skill_id)
    if skill_context == nil or skill_id == nil then
        return nil, "unresolved"
    end

    return safe_call_method1(skill_context, {
        "getCustomSkillLevel(app.HumanCustomSkillID)",
        "getCustomSkillLevel",
    }, skill_id)
end

local function call_is_custom_skill_available(skill_availability, skill_id)
    if skill_availability == nil or skill_id == nil then
        return nil, "unresolved"
    end

    return safe_call_method1(skill_availability, {
        "isCustomSkillAvailable(app.HumanCustomSkillID)",
        "isCustomSkillAvailable",
    }, skill_id)
end

local function capture_live_skill_scan(skill_context, skill_availability, skill_enum_entries, equipped_skill_jobs)
    local entries = {}
    local scanned = 0

    for _, enum_entry in ipairs(skill_enum_entries) do
        if scanned >= MAX_SKILL_SCAN then
            break
        end
        scanned = scanned + 1

        local skill_id = tonumber(enum_entry.value)
        if skill_id ~= nil then
            local enabled, enabled_source = call_is_custom_skill_enable(skill_context, skill_id)
            local available, available_source = call_is_custom_skill_available(skill_availability, skill_id)
            local level, level_source = call_get_custom_skill_level(skill_context, skill_id)
            local equipped_jobs = equipped_skill_jobs[skill_id]
            local level_scalar = extract_scalarish(level)
            local enabled_bool = decode_truthy(enabled)
            local available_bool = decode_truthy(available)

            if enabled_bool == true
                or available_bool == true
                or (level_scalar ~= nil and tonumber(level_scalar) ~= nil and tonumber(level_scalar) > 0)
                or (equipped_jobs ~= nil and #equipped_jobs > 0)
            then
                entries[#entries + 1] = {
                    skill_id = skill_id,
                    skill_name = enum_entry.name,
                    enabled = serialize_scalar(enabled_bool, enabled_source),
                    available = serialize_scalar(available_bool, available_source),
                    level = serialize_scalar(level_scalar, level_source),
                    equipped_jobs = equipped_jobs or {},
                }
            end
        end
    end

    table.sort(entries, function(a, b)
        return tonumber(a.skill_id) < tonumber(b.skill_id)
    end)

    return {
        scanned_skill_entries = scanned,
        active_entries = entries,
    }
end

local function capture_actor_surface(actor_root, actor_root_source, actor_label, skill_name_by_value, skill_enum_entries)
    local runtime_character, runtime_character_source = resolve_runtime_character_from_actor(actor_root)
    local human, human_source = resolve_human(runtime_character)
    local skill_context, skill_context_source = safe_present_field(human, SKILL_CONTEXT_FIELDS)
    if not is_present(skill_context) then
        skill_context, skill_context_source = safe_call_method0(human, {
            "get_SkillContext()",
        })
    end

    local ability_context, ability_context_source = safe_present_field(human, ABILITY_CONTEXT_FIELDS)
    if not is_present(ability_context) then
        ability_context, ability_context_source = safe_call_method0(human, {
            "get_AbilityContext()",
        })
    end

    local current_job, current_job_source, job_context, job_context_source = resolve_current_job(human, runtime_character)
    local current_job_number = tonumber(extract_scalarish(current_job) or current_job)
    local current_job_level, current_job_level_source = call_get_job_level(job_context, current_job_number)
    local chara_id, chara_id_source = safe_call_method0(runtime_character, {
        "get_CharaID()",
    })
    local skill_availability, skill_availability_source = resolve_skill_availability(skill_context)
    local custom_skill_state, custom_skill_state_source = safe_present_field(human, CUSTOM_SKILL_STATE_FIELDS)
    local equipped_skills_by_job, equipped_skill_jobs = collect_equipped_skills(skill_context, skill_name_by_value)
    local live_skill_scan = capture_live_skill_scan(skill_context, skill_availability, skill_enum_entries, equipped_skill_jobs)

    return {
        actor_label = actor_label,
        actor_root = serialize_object(actor_root, actor_root_source),
        runtime_character = serialize_object(runtime_character, runtime_character_source),
        human = serialize_object(human, human_source),
        chara_id = serialize_scalar(chara_id, chara_id_source),
        current_job = serialize_scalar(current_job_number, current_job_source),
        current_job_label = current_job_number ~= nil and JOB_LABELS[current_job_number] or nil,
        current_job_level = serialize_scalar(extract_scalarish(current_job_level), current_job_level_source),
        job_context = serialize_object(job_context, job_context_source),
        skill_context = serialize_object(skill_context, skill_context_source),
        ability_context = serialize_object(ability_context, ability_context_source),
        skill_availability = serialize_object(skill_availability, skill_availability_source),
        custom_skill_state = serialize_object(custom_skill_state, custom_skill_state_source),
        equipped_skills_by_job = equipped_skills_by_job,
        live_skill_scan = live_skill_scan,
    }
end

local function capture_job_parameters(job_param_root)
    local out = {}

    for job_id = 1, 10 do
        local field_name = string.format("Job%02dParameter", job_id)
        local job_param, job_param_source = safe_present_field(job_param_root, { field_name })
        out[string.format("job%02d", job_id)] = {
            job_id = job_id,
            job_label = JOB_LABELS[job_id],
            object = serialize_object(job_param, job_param_source),
            shallow_fields = snapshot_shallow_fields(job_param, SHALLOW_FIELD_LIMIT),
            numeric_tree = capture_numeric_tree(job_param, NUMERIC_TREE_DEPTH, {}),
        }
    end

    return out
end

local function capture_ability_entry(ability_item, item_source, ability_name_by_value)
    local ability_id, ability_id_source = safe_present_field(ability_item, {
        "AbilityID",
        "<AbilityID>k__BackingField",
        "_AbilityID",
    })
    local value, value_source = safe_present_field(ability_item, {
        "Value",
        "<Value>k__BackingField",
        "_Value",
    })
    local comment, comment_source = safe_present_field(ability_item, {
        "Comment",
        "<Comment>k__BackingField",
        "_Comment",
    })

    local ability_id_number = extract_enum_underlying(ability_id) or extract_scalarish(ability_id)
    local value_scalar = extract_scalarish(value)
    local comment_text = to_string_or_nil(comment) or describe(comment)

    return {
        object = serialize_object(ability_item, item_source),
        ability_id = serialize_scalar(ability_id_number, ability_id_source),
        ability_enum_name = ability_id_number ~= nil and ability_name_by_value[ability_id_number] or nil,
        value = serialize_scalar(value_scalar, value_source),
        comment = serialize_scalar(comment_text, comment_source),
        shallow_fields = snapshot_shallow_fields(ability_item, 12),
    }
end

local function capture_ability_parameters(ability_param_root, ability_name_by_value)
    local result = {}
    local ability_lists, ability_lists_source = safe_present_field(ability_param_root, ABILITY_LIST_FIELDS)

    for job_id = 1, 10 do
        local ability_group, ability_group_source = get_indexed_item(ability_lists, job_id - 1)
        if not is_present(ability_group) then
            ability_group, ability_group_source = get_indexed_item(ability_lists, job_id)
        end

        local abilities_root, abilities_root_source = safe_present_field(ability_group, ABILITY_ITEM_FIELDS)
        local ability_count, ability_count_source = get_collection_count(abilities_root)
        local entries = {}

        if ability_count ~= nil then
            local max_items = math.min(ability_count, MAX_ABILITY_ITEMS_PER_JOB)
            for index = 0, max_items - 1 do
                local ability_item, item_source = get_indexed_item(abilities_root, index)
                entries[#entries + 1] = capture_ability_entry(ability_item, item_source, ability_name_by_value)
            end
        end

        result[string.format("job%02d", job_id)] = {
            job_id = job_id,
            job_label = JOB_LABELS[job_id],
            ability_group = serialize_object(ability_group, ability_group_source),
            abilities_root = serialize_object(abilities_root, abilities_root_source),
            ability_count = serialize_scalar(ability_count, ability_count_source),
            entries = entries,
        }
    end

    return {
        root = serialize_object(ability_lists, ability_lists_source),
        per_job = result,
    }
end

local function capture_job_type_surfaces()
    local result = {}

    for job_id = 1, 10 do
        local prefix = string.format("Job%02d", job_id)
        result[string.format("job%02d", job_id)] = {
            job_id = job_id,
            job_label = JOB_LABELS[job_id],
            parameter = capture_type_surface("app." .. prefix .. "Parameter"),
            input_processor = capture_type_surface("app." .. prefix .. "InputProcessor"),
            action_controller = capture_type_surface("app." .. prefix .. "ActionController"),
            action_selector = capture_type_surface("app." .. prefix .. "ActionSelector"),
        }
    end

    return result
end

local CharacterManager = sdk.get_managed_singleton("app.CharacterManager")
local PawnManager = sdk.get_managed_singleton("app.PawnManager")

local enums = {
    job_enum = capture_enum_type("app.Character.JobEnum"),
    custom_skill_enum = capture_enum_type("app.HumanCustomSkillID"),
    ability_enum = capture_enum_type("app.HumanAbilityID"),
}

local human_param, human_param_source = safe_present_field(CharacterManager, {
    "<HumanParam>k__BackingField",
    "HumanParam",
    "_HumanParam",
})
if not is_present(human_param) then
    human_param, human_param_source = safe_call_method0(CharacterManager, {
        "get_HumanParam()",
    })
end

local job_param_root, job_param_root_source = safe_present_field(human_param, JOB_PARAM_FIELDS)
local ability_param_root, ability_param_root_source = safe_present_field(human_param, ABILITY_PARAM_FIELDS)
local action_param_root, action_param_root_source = safe_present_field(human_param, ACTION_PARAM_FIELDS)

local direct_action_param, direct_action_param_source = safe_call_method0(CharacterManager, {
    "get_HumanActionParam()",
})
if not is_present(direct_action_param) then
    direct_action_param, direct_action_param_source = safe_present_field(CharacterManager, {
        "<HumanActionParam>k__BackingField",
        "HumanActionParam",
        "_HumanActionParam",
    })
end

local player, player_source = resolve_player(CharacterManager)
local main_pawn, main_pawn_source = resolve_main_pawn(PawnManager, CharacterManager)

local ability_name_by_value = enums.ability_enum.value_to_name or {}
local skill_name_by_value = enums.custom_skill_enum.value_to_name or {}
local skill_enum_entries = enums.custom_skill_enum.entries or {}

local output = {
    tag = "vocation_definition_surface",
    generated_at = os.date("%Y-%m-%d %H:%M:%S"),
    output_note = "Class/job extraction surface from CharacterManager, type definitions, and live progression contexts. Designed to capture class-level data, not only combat snapshots.",
    managers = {
        character_manager = serialize_object(CharacterManager, "sdk.get_managed_singleton(app.CharacterManager)"),
        pawn_manager = serialize_object(PawnManager, "sdk.get_managed_singleton(app.PawnManager)"),
    },
    enums = enums,
    global_human_param = {
        object = serialize_object(human_param, human_param_source),
        job_param_root = serialize_object(job_param_root, job_param_root_source),
        ability_param_root = serialize_object(ability_param_root, ability_param_root_source),
        action_param_root = serialize_object(action_param_root, action_param_root_source),
        direct_action_param = serialize_object(direct_action_param, direct_action_param_source),
        human_param_shallow_fields = snapshot_shallow_fields(human_param, SHALLOW_FIELD_LIMIT),
        action_param_numeric_tree = capture_numeric_tree(action_param_root, NUMERIC_TREE_DEPTH, {}),
        direct_action_param_numeric_tree = capture_numeric_tree(direct_action_param, NUMERIC_TREE_DEPTH, {}),
    },
    job_parameters = capture_job_parameters(job_param_root),
    ability_parameters = capture_ability_parameters(ability_param_root, ability_name_by_value),
    job_type_surfaces = capture_job_type_surfaces(),
    live_actor_surfaces = {
        player = capture_actor_surface(player, player_source, "player", skill_name_by_value, skill_enum_entries),
        main_pawn = capture_actor_surface(main_pawn, main_pawn_source, "main_pawn", skill_name_by_value, skill_enum_entries),
    },
}

local output_path = "ce_dump/vocation_definition_surface_" .. os.date("%Y%m%d_%H%M%S") .. ".json"
json.dump_file(output_path, output)
print("[vocation_definition_surface] wrote " .. output_path)
return output_path

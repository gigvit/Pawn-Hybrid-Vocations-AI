-- Purpose:
-- Capture a progression-oriented vocation matrix for hybrid jobs Job07-Job10.
-- Focus:
--   * per-job level signals from JobContext
--   * base/core family surface from JobXXParameter fields
--   * custom-skill bands, equip state, enable state, and custom-skill level
--   * equipped augments / abilities from AbilityContext
--   * per-job ability parameter entries from HumanParam.AbilityParam
--
-- Output:
--   reframework/data/ce_dump/vocation_progression_matrix_<timestamp>.json

local SHALLOW_FIELD_LIMIT = 20
local MAX_ABILITY_ITEMS_PER_JOB = 96
local MAX_SKILLS_PER_JOB = 16

local HYBRID_JOB_IDS = { 7, 8, 9, 10 }

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

local JOB_SKILL_BANDS = {
    [7] = { first = 70, last = 79 },
    [8] = { first = 80, last = 91 },
    [9] = { first = 92, last = 99 },
    [10] = { first = 100, last = 100 },
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

local EQUIPPED_ABILITIES_FIELDS = {
    "EquipedAbilities",
    "<EquipedAbilities>k__BackingField",
    "_EquipedAbilities",
}

local ENABLED_ABILITIES_FIELDS = {
    "EnableAbilities",
    "<EnableAbilities>k__BackingField",
    "_EnableAbilities",
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

local function extract_scalarish(value)
    if value == nil then
        return nil
    end

    local value_type = type(value)
    if value_type == "number" or value_type == "string" or value_type == "boolean" then
        return value
    end

    local enum_value, _ = safe_present_field(value, { "value__" })
    if enum_value ~= nil and type(enum_value) ~= "userdata" and type(enum_value) ~= "table" then
        return enum_value
    end

    local text, _ = safe_call_method0(value, { "ToString()" })
    if type(text) == "string" or type(text) == "number" or type(text) == "boolean" then
        return text
    end

    return nil
end

local function extract_enum_underlying(value)
    local scalar = extract_scalarish(value)
    if scalar == nil then
        return nil
    end
    local number = tonumber(scalar)
    return number ~= nil and number or scalar
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
    if type(scalar) == "boolean" then
        return scalar
    end
    if type(scalar) == "number" then
        return scalar ~= 0
    end
    local text = tostring(scalar)
    if text == "true" or text == "True" or text == "TRUE" then
        return true
    end
    if text == "false" or text == "False" or text == "FALSE" then
        return false
    end
    local number = tonumber(text)
    return number ~= nil and number ~= 0 or nil
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

    local field_count, field_count_source = safe_field(obj, { "Count", "count", "_size", "size" })
    if field_count ~= nil then
        return tonumber(field_count), field_count_source
    end

    return nil, "unresolved"
end

local function get_indexed_item(obj, index)
    return safe_call_method1(obj, {
        "get_Item(System.Int32)",
        "get_Item(System.UInt32)",
        "get_Item",
    }, index)
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

    local field_value, field_source = safe_present_field(actor, {
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

local function resolve_human(runtime_character)
    local human, human_source = safe_present_field(runtime_character, {
        "<Human>k__BackingField",
        "Human",
    })
    if is_present(human) then
        return human, human_source
    end

    human, human_source = safe_call_method0(runtime_character, {
        "get_Human()",
    })
    if is_present(human) then
        return human, human_source
    end

    return nil, "unresolved"
end

local function call_get_job_level(job_context, job_id)
    if job_context == nil or job_id == nil then
        return nil, "job_level_unresolved"
    end

    return safe_call_method1(job_context, {
        "getJobLevel(System.Int32)",
        "getJobLevel(app.Character.JobEnum)",
        "getJobLevel",
    }, job_id)
end

local function resolve_current_job(human, runtime_character)
    local job_context, job_context_source = safe_present_field(human, JOB_CONTEXT_FIELDS)
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

    local field_job, field_job_source = safe_field(runtime_character, { "CurrentJob", "Job" })
    return field_job, "runtime_character:" .. tostring(field_job_source), job_context, job_context_source
end

local function resolve_skill_availability(skill_context)
    if skill_context == nil then
        return nil, "skill_availability_unresolved"
    end

    local direct, source = safe_call_method0(skill_context, {
        "get_Availability()",
        "get_Availability",
        "get_SkillAvailability()",
        "get_SkillAvailability",
    })
    if is_present(direct) then
        return direct, source
    end

    local field, field_source = safe_present_field(skill_context, {
        "<Availability>k__BackingField",
        "Availability",
        "<SkillAvailability>k__BackingField",
        "SkillAvailability",
    })
    if is_present(field) then
        return field, field_source
    end

    return nil, "skill_availability_unresolved"
end

local function resolve_job_equip_list(skill_context, job_id)
    if skill_context == nil or job_id == nil then
        return nil, "root_nil"
    end

    local equip_list, equip_source = safe_call_method1(skill_context, {
        "getEquipList(System.Int32)",
        "getEquipList(app.Character.JobEnum)",
        "getEquipList",
    }, job_id)
    if is_present(equip_list) then
        return equip_list, equip_source
    end

    local equipped_root, equipped_root_source = safe_present_field(skill_context, EQUIPPED_SKILLS_FIELDS)
    local indexed, indexed_source = get_indexed_item(equipped_root, job_id)
    if is_present(indexed) then
        return indexed, indexed_source
    end

    local indexed_minus_one, indexed_minus_one_source = get_indexed_item(equipped_root, job_id - 1)
    if is_present(indexed_minus_one) then
        return indexed_minus_one, indexed_minus_one_source
    end

    return nil, equipped_root_source
end

local function collect_equipped_skills(skill_context, skill_name_by_value)
    local per_job = {}
    local jobs_by_skill = {}

    for _, job_id in ipairs(HYBRID_JOB_IDS) do
        local job_key = string.format("job%02d", job_id)
        local equip_list, equip_list_source = resolve_job_equip_list(skill_context, job_id)
        local skills_root, skills_root_source = safe_present_field(equip_list, SKILLS_LIST_FIELDS)
        local skill_count, skill_count_source = get_collection_count(skills_root)
        local entries = {}

        if skill_count ~= nil then
            local max_items = math.min(skill_count, MAX_SKILLS_PER_JOB)
            for index = 0, max_items - 1 do
                local item, item_source = get_indexed_item(skills_root, index)
                local skill_id = extract_enum_underlying(item)
                if skill_id ~= nil and tonumber(skill_id) ~= nil and tonumber(skill_id) ~= 0 then
                    local numeric_skill_id = tonumber(skill_id)
                    entries[#entries + 1] = {
                        slot = index,
                        skill_id = numeric_skill_id,
                        skill_name = skill_name_by_value[numeric_skill_id],
                        item = serialize_object(item, item_source),
                    }
                    jobs_by_skill[numeric_skill_id] = jobs_by_skill[numeric_skill_id] or {}
                    jobs_by_skill[numeric_skill_id][#jobs_by_skill[numeric_skill_id] + 1] = job_id
                end
            end
        end

        per_job[job_key] = {
            job_id = job_id,
            job_label = JOB_LABELS[job_id],
            equip_list = serialize_object(equip_list, equip_list_source),
            skills_root = serialize_object(skills_root, skills_root_source),
            skill_count = serialize_scalar(skill_count, skill_count_source),
            entries = entries,
        }
    end

    return per_job, jobs_by_skill
end

local function resolve_ability_group(root, job_id)
    local group, group_source = get_indexed_item(root, job_id - 1)
    if is_present(group) then
        return group, group_source
    end

    group, group_source = get_indexed_item(root, job_id)
    if is_present(group) then
        return group, group_source
    end

    return nil, "unresolved"
end

local function collect_ability_entries_from_group(group, ability_name_by_value)
    local entries = {}
    local abilities_root, abilities_root_source = safe_present_field(group, ABILITY_ITEM_FIELDS)
    local ability_count, ability_count_source = get_collection_count(abilities_root)

    if ability_count ~= nil then
        local max_items = math.min(ability_count, MAX_ABILITY_ITEMS_PER_JOB)
        for index = 0, max_items - 1 do
            local ability_item, item_source = get_indexed_item(abilities_root, index)
            local ability_id = extract_enum_underlying(ability_item)
            if ability_id == nil then
                local ability_value, _ = safe_present_field(ability_item, {
                    "AbilityID",
                    "<AbilityID>k__BackingField",
                    "_AbilityID",
                    "value__",
                })
                ability_id = extract_enum_underlying(ability_value)
            end
            local numeric_ability_id = tonumber(ability_id)
            if numeric_ability_id ~= nil and numeric_ability_id ~= 0 then
                entries[#entries + 1] = {
                    ability_id = numeric_ability_id,
                    ability_name = ability_name_by_value[numeric_ability_id],
                    item = serialize_object(ability_item, item_source),
                }
            end
        end
    end

    return abilities_root, abilities_root_source, ability_count, ability_count_source, entries
end

local function collect_equipped_abilities(ability_context, ability_name_by_value)
    local root, root_source = safe_present_field(ability_context, EQUIPPED_ABILITIES_FIELDS)
    local result = {
        root = serialize_object(root, root_source),
        per_job = {},
    }

    for _, job_id in ipairs(HYBRID_JOB_IDS) do
        local job_key = string.format("job%02d", job_id)
        local group, group_source = resolve_ability_group(root, job_id)
        local abilities_root, abilities_root_source, ability_count, ability_count_source, entries =
            collect_ability_entries_from_group(group, ability_name_by_value)

        result.per_job[job_key] = {
            job_id = job_id,
            job_label = JOB_LABELS[job_id],
            ability_group = serialize_object(group, group_source),
            abilities_root = serialize_object(abilities_root, abilities_root_source),
            ability_count = serialize_scalar(ability_count, ability_count_source),
            entries = entries,
        }
    end

    return result
end

local function collect_enabled_abilities(ability_context, ability_name_by_value)
    local root, root_source = safe_present_field(ability_context, ENABLED_ABILITIES_FIELDS)
    local result = {
        root = serialize_object(root, root_source),
        per_job = {},
    }

    for _, job_id in ipairs(HYBRID_JOB_IDS) do
        local job_key = string.format("job%02d", job_id)
        local group, group_source = resolve_ability_group(root, job_id)
        local abilities_root, abilities_root_source, ability_count, ability_count_source, entries =
            collect_ability_entries_from_group(group, ability_name_by_value)

        result.per_job[job_key] = {
            job_id = job_id,
            job_label = JOB_LABELS[job_id],
            ability_group = serialize_object(group, group_source),
            abilities_root = serialize_object(abilities_root, abilities_root_source),
            ability_count = serialize_scalar(ability_count, ability_count_source),
            entries = entries,
        }
    end

    return result
end

local function call_is_custom_skill_enable(skill_context, skill_id)
    if skill_context == nil or skill_id == nil then
        return nil, "root_nil"
    end

    return safe_call_method1(skill_context, {
        "isCustomSkillEnable(app.HumanCustomSkillID)",
        "isCustomSkillEnable",
    }, skill_id)
end

local function call_get_custom_skill_level(skill_context, skill_id)
    if skill_context == nil or skill_id == nil then
        return nil, "root_nil"
    end

    return safe_call_method1(skill_context, {
        "getCustomSkillLevel(app.HumanCustomSkillID)",
        "getCustomSkillLevel",
    }, skill_id)
end

local function call_is_custom_skill_available(skill_availability, skill_id)
    if skill_availability == nil or skill_id == nil then
        return nil, "root_nil"
    end

    return safe_call_method1(skill_availability, {
        "isCustomSkillAvailable(app.HumanCustomSkillID)",
        "isCustomSkillAvailable",
    }, skill_id)
end

local function call_has_equipped_skill(skill_context, job_id, skill_id)
    if skill_context == nil or job_id == nil or skill_id == nil then
        return nil, "root_nil"
    end

    return safe_call_method2(skill_context, {
        "hasEquipedSkill(app.Character.JobEnum, app.HumanCustomSkillID)",
        "hasEquipedSkill",
    }, job_id, skill_id)
end

local function contains_number(list, value)
    for _, item in ipairs(list or {}) do
        if tonumber(item) == tonumber(value) then
            return true
        end
    end
    return false
end

local function capture_hybrid_skill_band_matrix(skill_context, skill_availability, equipped_skill_jobs, skill_enum_by_job)
    local result = {}

    for _, job_id in ipairs(HYBRID_JOB_IDS) do
        local job_key = string.format("job%02d", job_id)
        local entries = {}

        for _, enum_entry in ipairs(skill_enum_by_job[job_id] or {}) do
            local skill_id = tonumber(enum_entry.value)
            local enabled, enabled_source = call_is_custom_skill_enable(skill_context, skill_id)
            local available, available_source = call_is_custom_skill_available(skill_availability, skill_id)
            local level, level_source = call_get_custom_skill_level(skill_context, skill_id)
            local equipped, equipped_source = call_has_equipped_skill(skill_context, job_id, skill_id)
            local listed_jobs = equipped_skill_jobs[skill_id] or {}

            local enabled_bool = decode_truthy(enabled)
            local available_bool = decode_truthy(available)
            local equipped_bool = decode_truthy(equipped)
            local level_value = tonumber(extract_scalarish(level) or 0) or 0
            local listed_for_job = contains_number(listed_jobs, job_id)

            local inferred_state = "locked_or_unresolved"
            if listed_for_job or equipped_bool == true then
                inferred_state = "equipped"
            elseif enabled_bool == true or available_bool == true or level_value > 0 then
                inferred_state = "unlocked_not_equipped"
            end

            entries[#entries + 1] = {
                skill_id = skill_id,
                skill_name = enum_entry.name,
                equipped = serialize_scalar(equipped_bool, equipped_source),
                enabled = serialize_scalar(enabled_bool, enabled_source),
                available = serialize_scalar(available_bool, available_source),
                level = serialize_scalar(level_value, level_source),
                listed_in_job_equip_list = listed_for_job,
                listed_jobs = listed_jobs,
                inferred_state = inferred_state,
            }
        end

        result[job_key] = {
            job_id = job_id,
            job_label = JOB_LABELS[job_id],
            skill_band = JOB_SKILL_BANDS[job_id],
            entries = entries,
        }
    end

    return result
end

local function build_job_level_matrix(job_context)
    local result = {}

    for _, job_id in ipairs(HYBRID_JOB_IDS) do
        local level, level_source = call_get_job_level(job_context, job_id)
        result[string.format("job%02d", job_id)] = {
            job_id = job_id,
            job_label = JOB_LABELS[job_id],
            level = serialize_scalar(extract_scalarish(level), level_source),
        }
    end

    return result
end

local function build_skill_enum_by_job(custom_skill_enum)
    local result = {}
    for _, job_id in ipairs(HYBRID_JOB_IDS) do
        result[job_id] = {}
    end

    for _, entry in ipairs(custom_skill_enum.entries or {}) do
        local value = tonumber(entry.value)
        if value ~= nil then
            for _, job_id in ipairs(HYBRID_JOB_IDS) do
                local band = JOB_SKILL_BANDS[job_id]
                if value >= band.first and value <= band.last then
                    result[job_id][#result[job_id] + 1] = entry
                    break
                end
            end
        end
    end

    return result
end

local function build_custom_skill_name_set(job_id, skill_enum_by_job)
    local result = {}
    local prefix = string.format("Job%02d_", job_id)

    for _, entry in ipairs(skill_enum_by_job[job_id] or {}) do
        local name = tostring(entry.name or "")
        local trimmed = string.sub(name, 1, #prefix) == prefix and string.sub(name, #prefix + 1) or name
        result[trimmed] = true
    end

    return result
end

local function trim_param_suffix(name)
    local text = tostring(name or "")
    text = string.gsub(text, "Parameter$", "")
    text = string.gsub(text, "Paramter$", "")
    text = string.gsub(text, "Param$", "")
    return text
end

local function capture_job_parameter_families(job_param_root, job_id, custom_skill_name_set)
    local field_name = string.format("Job%02dParameter", job_id)
    local job_param, job_param_source = safe_present_field(job_param_root, { field_name })
    local families = {}

    if is_present(job_param) then
        local ok_td, td = try_eval(function()
            return job_param:get_type_definition()
        end)
        if ok_td and td ~= nil then
            local ok_fields, fields = try_eval(function()
                return td:get_fields()
            end)
            if ok_fields and fields ~= nil then
                for _, field in ipairs(fields) do
                    local ok_name, raw_name = try_eval(function()
                        return field:get_name()
                    end)
                    local name = ok_name and raw_name ~= nil and tostring(raw_name) or nil
                    if name ~= nil then
                        local trimmed = trim_param_suffix(name)
                        if string.find(name, "Param", 1, true) ~= nil or string.find(name, "Attack", 1, true) ~= nil then
                            local ok_value, value = try_eval(function()
                                return field:get_data(job_param)
                            end)
                            families[#families + 1] = {
                                field_name = name,
                                family_name = trimmed,
                                inferred_kind = custom_skill_name_set[trimmed] and "custom_skill_family" or "base_or_core_family",
                                object = ok_value and serialize_object(value, "field:" .. name) or serialize_object(nil, "field:" .. name),
                            }
                        end
                    end
                end
            end
        end
    end

    table.sort(families, function(a, b)
        return tostring(a.field_name or "") < tostring(b.field_name or "")
    end)

    return {
        job_id = job_id,
        job_label = JOB_LABELS[job_id],
        object = serialize_object(job_param, job_param_source),
        shallow_fields = snapshot_shallow_fields(job_param, SHALLOW_FIELD_LIMIT),
        families = families,
    }
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
    local numeric_ability_id = tonumber(ability_id_number)
    local value_scalar = extract_scalarish(value)
    local comment_text = to_string_or_nil(comment) or describe(comment)

    return {
        object = serialize_object(ability_item, item_source),
        ability_id = serialize_scalar(numeric_ability_id, ability_id_source),
        ability_enum_name = numeric_ability_id ~= nil and ability_name_by_value[numeric_ability_id] or nil,
        value = serialize_scalar(value_scalar, value_source),
        comment = serialize_scalar(comment_text, comment_source),
    }
end

local function capture_hybrid_ability_parameters(ability_param_root, ability_name_by_value)
    local result = {}
    local ability_lists, ability_lists_source = safe_present_field(ability_param_root, ABILITY_LIST_FIELDS)

    for _, job_id in ipairs(HYBRID_JOB_IDS) do
        local job_key = string.format("job%02d", job_id)
        local ability_group, ability_group_source = resolve_ability_group(ability_lists, job_id)
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

        result[job_key] = {
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

local function capture_actor_progression(actor_root, actor_root_source, actor_label, skill_name_by_value, ability_name_by_value, skill_enum_by_job)
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
    local skill_availability, skill_availability_source = resolve_skill_availability(skill_context)
    local custom_skill_state, custom_skill_state_source = safe_present_field(human, CUSTOM_SKILL_STATE_FIELDS)
    local chara_id, chara_id_source = safe_call_method0(runtime_character, {
        "get_CharaID()",
    })

    local equipped_skills_by_job, equipped_skill_jobs = collect_equipped_skills(skill_context, skill_name_by_value)
    local equipped_abilities_by_job = collect_equipped_abilities(ability_context, ability_name_by_value)
    local enabled_abilities_by_job = collect_enabled_abilities(ability_context, ability_name_by_value)
    local hybrid_skill_matrix = capture_hybrid_skill_band_matrix(skill_context, skill_availability, equipped_skill_jobs, skill_enum_by_job)
    local hybrid_job_levels = build_job_level_matrix(job_context)

    return {
        actor_label = actor_label,
        actor_root = serialize_object(actor_root, actor_root_source),
        runtime_character = serialize_object(runtime_character, runtime_character_source),
        human = serialize_object(human, human_source),
        chara_id = serialize_scalar(chara_id, chara_id_source),
        current_job = serialize_scalar(current_job_number, current_job_source),
        current_job_label = current_job_number ~= nil and JOB_LABELS[current_job_number] or nil,
        current_job_level = serialize_scalar(extract_scalarish(current_job_level), current_job_level_source),
        hybrid_job_levels = hybrid_job_levels,
        job_context = serialize_object(job_context, job_context_source),
        skill_context = serialize_object(skill_context, skill_context_source),
        ability_context = serialize_object(ability_context, ability_context_source),
        skill_availability = serialize_object(skill_availability, skill_availability_source),
        custom_skill_state = serialize_object(custom_skill_state, custom_skill_state_source),
        equipped_skills_by_job = equipped_skills_by_job,
        equipped_abilities_by_job = equipped_abilities_by_job,
        enabled_abilities_by_job = enabled_abilities_by_job,
        hybrid_custom_skills = hybrid_skill_matrix,
    }
end

local function build_derived_job_matrix(job_id, parameter_families, ability_parameters, actor_surfaces, skill_enum_by_job)
    local job_key = string.format("job%02d", job_id)
    local base_or_core_families = {}
    local custom_skill_families = {}

    for _, family in ipairs(parameter_families.families or {}) do
        if family.inferred_kind == "custom_skill_family" then
            custom_skill_families[#custom_skill_families + 1] = family.family_name
        else
            base_or_core_families[#base_or_core_families + 1] = family.family_name
        end
    end

    table.sort(base_or_core_families)
    table.sort(custom_skill_families)

    local actor_views = {}
    for actor_key, actor_surface in pairs(actor_surfaces) do
        actor_views[actor_key] = {
            hybrid_job_level = actor_surface.hybrid_job_levels[job_key],
            equipped_skills = actor_surface.equipped_skills_by_job[job_key],
            equipped_abilities = actor_surface.equipped_abilities_by_job.per_job[job_key],
            enabled_abilities = actor_surface.enabled_abilities_by_job.per_job[job_key],
            custom_skills = actor_surface.hybrid_custom_skills[job_key],
        }
    end

    return {
        job_id = job_id,
        job_label = JOB_LABELS[job_id],
        skill_band = JOB_SKILL_BANDS[job_id],
        custom_skill_enum_entries = skill_enum_by_job[job_id],
        base_or_core_families = base_or_core_families,
        custom_skill_families = custom_skill_families,
        ability_parameter_entries = ability_parameters.per_job[job_key],
        actor_views = actor_views,
        known_limitations = {
            "Base/core family presence is confirmed from JobXXParameter and InputProcessor surface, but direct unlock levels for non-custom moves are not exposed here.",
            "Custom-skill unlock state is inferred from SkillContext equip lists, isCustomSkillEnable(...), getCustomSkillLevel(...), and availability signals.",
            "Ability/augment entries are captured from HumanParam AbilityParam and live AbilityContext, but passive semantics may still need manual naming review.",
        },
    }
end

local CharacterManager = sdk.get_managed_singleton("app.CharacterManager")
local PawnManager = sdk.get_managed_singleton("app.PawnManager")

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

local custom_skill_enum = capture_enum_type("app.HumanCustomSkillID")
local ability_enum = capture_enum_type("app.HumanAbilityID")
local skill_enum_by_job = build_skill_enum_by_job(custom_skill_enum)
local skill_name_by_value = custom_skill_enum.value_to_name or {}
local ability_name_by_value = ability_enum.value_to_name or {}

local player, player_source = resolve_player(CharacterManager)
local main_pawn, main_pawn_source = resolve_main_pawn(PawnManager, CharacterManager)

local definitions = {}
for _, job_id in ipairs(HYBRID_JOB_IDS) do
    local custom_skill_name_set = build_custom_skill_name_set(job_id, skill_enum_by_job)
    definitions[string.format("job%02d", job_id)] = {
        parameter_families = capture_job_parameter_families(job_param_root, job_id, custom_skill_name_set),
    }
end

local ability_parameters = capture_hybrid_ability_parameters(ability_param_root, ability_name_by_value)
local actor_surfaces = {
    player = capture_actor_progression(player, player_source, "player", skill_name_by_value, ability_name_by_value, skill_enum_by_job),
    main_pawn = capture_actor_progression(main_pawn, main_pawn_source, "main_pawn", skill_name_by_value, ability_name_by_value, skill_enum_by_job),
}

local derived_matrix = {}
for _, job_id in ipairs(HYBRID_JOB_IDS) do
    local job_key = string.format("job%02d", job_id)
    derived_matrix[job_key] = build_derived_job_matrix(
        job_id,
        definitions[job_key].parameter_families,
        ability_parameters,
        actor_surfaces,
        skill_enum_by_job
    )
end

local output = {
    tag = "vocation_progression_matrix",
    generated_at = os.date("%Y-%m-%d %H:%M:%S"),
    output_note = "Progression-oriented extraction for hybrid jobs Job07-Job10: levels, base/core families, custom skills, equipped skills, and augment/ability layers.",
    managers = {
        character_manager = serialize_object(CharacterManager, "sdk.get_managed_singleton(app.CharacterManager)"),
        pawn_manager = serialize_object(PawnManager, "sdk.get_managed_singleton(app.PawnManager)"),
    },
    enums = {
        custom_skill_enum = custom_skill_enum,
        ability_enum = ability_enum,
        hybrid_skill_bands = JOB_SKILL_BANDS,
    },
    global_human_param = {
        object = serialize_object(human_param, human_param_source),
        job_param_root = serialize_object(job_param_root, job_param_root_source),
        ability_param_root = serialize_object(ability_param_root, ability_param_root_source),
        human_param_shallow_fields = snapshot_shallow_fields(human_param, SHALLOW_FIELD_LIMIT),
    },
    definitions = definitions,
    ability_parameters = ability_parameters,
    actors = actor_surfaces,
    derived_matrix = derived_matrix,
    limitations = {
        "This script captures family existence, equip state, enable state, custom-skill levels, and ability surfaces.",
        "It does not prove direct unlock levels for every non-custom base/core move.",
        "If a current or per-job level returns nil, treat that runtime level surface as unresolved rather than absent.",
    },
}

local output_path = "ce_dump/vocation_progression_matrix_" .. os.date("%Y%m%d_%H%M%S") .. ".json"
json.dump_file(output_path, output)
print("[vocation_progression_matrix] wrote " .. output_path)
return output_path

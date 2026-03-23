local hybrid_jobs = {}

local function copy_array(values)
    local result = {}
    for _, value in ipairs(values or {}) do
        table.insert(result, value)
    end
    return result
end

local function infer_attack_type(name)
    if type(name) ~= "string" then
        return "unknown"
    end

    local patterns = {
        { match = "Prepare", value = "prepare" },
        { match = "Ready", value = "ready" },
        { match = "Shoot", value = "shoot" },
        { match = "Cast", value = "cast" },
        { match = "Summon", value = "summon" },
        { match = "Transfer", value = "transfer" },
        { match = "Unsummon", value = "unsummon" },
        { match = "Counter", value = "counter" },
        { match = "Shield", value = "shield" },
        { match = "Bind", value = "bind" },
        { match = "Attack", value = "attack" },
        { match = "HeavyAttack", value = "heavy_attack" },
        { match = "Dash", value = "dash" },
        { match = "Climbing", value = "climbing" },
        { match = "Air", value = "air" },
        { match = "Landing", value = "landing" },
        { match = "Throw", value = "throw" },
    }

    for _, item in ipairs(patterns) do
        if string.find(name, item.match, 1, true) ~= nil then
            return item.value
        end
    end

    return "unknown"
end

local function build_attacks(names, sources)
    local attacks = {}
    for _, name in ipairs(names or {}) do
        table.insert(attacks, {
            name = name,
            type = infer_attack_type(name),
            trigger = "runtime action node",
            mechanism = "RE action graph node",
            sources = copy_array(sources),
            completeness = "found_in_examples",
        })
    end
    return attacks
end

local function build_action_names(attacks)
    local names = {}
    for _, attack in ipairs(attacks or {}) do
        table.insert(names, attack.name)
    end
    return names
end

local function build_skill(entry)
    return {
        id = entry.id,
        name = entry.name,
        effect = entry.effect,
        conditions = entry.conditions,
        mechanism = entry.mechanism,
        sources = copy_array(entry.sources),
        completeness = entry.completeness or "partial",
        notes = entry.notes,
    }
end

local function build_skill_refs(skills)
    local refs = {}
    for _, skill in ipairs(skills or {}) do
        local id_label = skill.id ~= nil and string.format("id=%s", tostring(skill.id)) or "id=<unknown>"
        local name_label = skill.name ~= nil and tostring(skill.name) or "<name-unresolved>"
        table.insert(refs, string.format("%s %s", id_label, name_label))
    end
    return refs
end

local ordered = {
    {
        id = 7,
        key = "mystic_spearhand",
        label = "Mystic Spearhand",
        action_prefix = "Job07",
        controller_getter = "get_Job07ActionCtrl",
        controller_field = "<Job07ActionCtrl>k__BackingField",
        input_processor = "app.Job07InputProcessor",
        parameters = {
            known_controller_fields = {
                "<BladeShootCtrl>k__BackingField",
                "<QuickShieldCtrl>k__BackingField",
            },
            known_skill_states = { 71, 74, 78 },
        },
        sources = {
            "Dullahan/Mystic Spearhand/*",
            "Weaponlord/Mystic Spearhand.lua",
            "Skill Maker ActionNames.json",
            "Nick's Devtools/CombatTools.lua",
            "Bestiary/Utils/Status.lua",
        },
        attacks = build_attacks({
            "Job07_AirFinishingMoveBack",
            "Job07_AirFinishingMoveDown",
            "Job07_AirFinishingMoveFront",
            "Job07_AttackAir",
            "Job07_AttackAirLanding",
            "Job07_AttackLeft",
            "Job07_Blade",
            "Job07_ClimbingAttack",
            "Job07_ClimbingAttackFinish",
            "Job07_ClimbingHeavyAttack",
            "Job07_ClimbingHeavyAttackLanding",
            "Job07_DanceOfDeath",
            "Job07_DashAttack",
            "Job07_DashFinishingMoveBack",
            "Job07_DashFinishingMoveFront",
            "Job07_DashHeavyAttack",
            "Job07_DragonStinger",
            "Job07_DragonStingerAirFinish",
            "Job07_DragonStingerAirFinishLarge",
            "Job07_DragonStingerLanding",
            "Job07_EnergyDrain",
            "Job07_EnergyDrainCombo",
            "Job07_EnergyDrainEnd",
            "Job07_ExceptIdle",
            "Job07_FarThrow",
            "Job07_FinishingMoveBack",
            "Job07_FinishingMoveDown",
            "Job07_FinishingMoveFront",
            "Job07_FinishingMoveLarge",
            "Job07_FinishingMoveLargeAir",
            "Job07_FinishingMoveLargeBelow",
            "Job07_FinishingMoveLargeLow",
            "Job07_FinishingMoveLargeLowAir",
            "Job07_Gungnir",
            "Job07_GungnirAbort",
            "Job07_GungnirShoot",
            "Job07_HeavyAttackAir",
            "Job07_HeavyAttackAirLanding",
            "Job07_HeavyAttackLargeBelow",
            "Job07_HoldDownAttack",
            "Job07_HoldDownAttackEnd",
            "Job07_HoldDownHeavyAttack",
            "Job07_HoldDownHeavyAttackEnd",
            "Job07_HoldDownHeavyAttackNew",
            "Job07_HoldDownHeavyAttackWithDraw",
            "Job07_LongRangeAttack",
            "Job07_LongRangeFinishingMoveBack",
            "Job07_LongRangeFinishingMoveFront",
            "Job07_LongRangeHeavyAttack",
            "Job07_MagicBindComplete",
            "Job07_MagicBindCompleteLanding",
            "Job07_MagicBindImcomplete",
            "Job07_MagicBindImcompleteFullBody",
            "Job07_MagicBindJustExplosion",
            "Job07_MagicBindJustExplosionAir",
            "Job07_MagicBindJustExplosionLanding",
            "Job07_MagicBindJustLeap",
            "Job07_MagicBindJustLeapLanding",
            "Job07_PsychoShoot",
            "Job07_QuickShield",
            "Job07_SheathBlade",
            "Job07_ShortRangeAttack",
            "Job07_ShortRangeHeavyAttack",
            "Job07_SkyDive",
            "Job07_SkyDiveLanding",
            "Job07_SpiralSlash",
            "Job07_SpiralSlashEnd",
            "Job07_SpiralSlashPrevEnd",
            "Job07_SpiralSlashStartFullBody",
            "Job07_TwoSeconds",
        }, {
            "Dullahan/Mystic Spearhand/*",
            "Weaponlord/Mystic Spearhand.lua",
            "Skill Maker ActionNames.json",
        }),
        skills = {
            build_skill({
                id = 71,
                name = "RuinousSegil",
                effect = "Referenced by runtime research example; exact in-game effect not normalized from local sources.",
                conditions = "Observed as skillState == 71 in Mystic Spearhand examples.",
                mechanism = "app.Job07InputProcessor:processCustomSkill(...)",
                sources = {
                    "Dullahan/Mystic Spearhand/RuinousSegil.lua",
                },
            }),
            build_skill({
                id = 74,
                name = nil,
                effect = "Observed in multiple Mystic Spearhand examples; canonical name unresolved in current local sources.",
                conditions = "Observed as skillState == 74; linked from mirour_shelde and MagikeCanon example logic.",
                mechanism = "app.Job07InputProcessor:processCustomSkill(...)",
                sources = {
                    "Dullahan/Mystic Spearhand/MysticSpearhand.lua",
                    "Dullahan/Mystic Spearhand/MagikeCanon.lua",
                    "Dullahan/config.lua",
                },
                completeness = "partial_name_unresolved",
                notes = "Do not merge mirour_shelde and MagikeCanon into a single canonical skill name without stronger source evidence.",
            }),
            build_skill({
                id = 78,
                name = "ForbedingBolt",
                effect = "Projectile / bind-related Mystic Spearhand custom skill path from example logic.",
                conditions = "Observed as skillState == 78 and EnabledCustomSkills[78].Level.",
                mechanism = "app.Job07InputProcessor:processCustomSkill(...)",
                sources = {
                    "Dullahan/Mystic Spearhand/ForbedingBolt.lua",
                },
            }),
        },
        completeness = {
            attacks = "high_from_examples",
            skills = "partial",
            parameters = "partial",
        },
    },
    {
        id = 8,
        key = "magick_archer",
        label = "Magick Archer",
        action_prefix = "Job08",
        controller_getter = "get_Job08ActionCtrl",
        controller_field = "<Job08ActionCtrl>k__BackingField",
        input_processor = nil,
        parameters = {
            known_controller_fields = {
                "<RemainArrowCtrl>k__BackingField",
            },
            known_skill_states = { 86 },
        },
        sources = {
            "_NickCore/player properties",
            "Weaponlord/Magick Archer.lua",
            "Weaponlord/helpers.lua",
            "Dullahan/Magick Archer/MagickArcher.lua",
            "Skill Maker ActionNames.json",
        },
        attacks = build_attacks({
            "Job08_AbsorbArrowWithoutAim",
            "Job08_AimTurn",
            "Job08_AimTurnWithoutAim",
            "Job08_BurningLightWithoutAim",
            "Job08_ChangeArrow",
            "Job08_ChangeArrowOnAim",
            "Job08_ClimbingAttack",
            "Job08_ClimbingHeavyAttack",
            "Job08_ClimbingSquatAttack",
            "Job08_CounterArrowWithoutAim",
            "Job08_DashAttack",
            "Job08_DashAttackShoot",
            "Job08_FlameLanceWithoutAim",
            "Job08_FlameLanceWithoutAimEnd",
            "Job08_FrostBlockWithoutAim",
            "Job08_FrostTraceWithoutAim",
            "Job08_HoldDownAttack",
            "Job08_HoldDownHeavyAttack",
            "Job08_LifeReturnWithoutAim",
            "Job08_NormalShootWithoutAim",
            "Job08_NormalShootWithoutAimAir",
            "Job08_PrepareAbsorbArrow",
            "Job08_PrepareBurningLight",
            "Job08_PrepareCounterArrow",
            "Job08_PrepareFlameLance",
            "Job08_PrepareFrostBlock",
            "Job08_PrepareFrostTrace",
            "Job08_PrepareLifeReturn",
            "Job08_PrepareReflectThunder",
            "Job08_PrepareSeriesArrow",
            "Job08_PrepareSleepArrow",
            "Job08_PrepareSpiritArrow",
            "Job08_PrepareThunderChain",
            "Job08_ReadyAbsorbArrow",
            "Job08_ReadyBurningLight",
            "Job08_ReadyCounterArrow",
            "Job08_ReadyFlameLance",
            "Job08_ReadyFrostBlock",
            "Job08_ReadyFrostTrace",
            "Job08_ReadyLifeReturn",
            "Job08_ReadyReflectThunder",
            "Job08_ReadySeriesArrow",
            "Job08_ReadySleepArrow",
            "Job08_ReadySpiritArrow",
            "Job08_ReadyThunderChain",
            "Job08_ReflectThunderWithoutAim",
            "Job08_ReflectThunderWithoutAimEnd",
            "Job08_RestartAim",
            "Job08_SeriesArrowWithoutAim",
            "Job08_SeriesArrowWithoutAimEnd",
            "Job08_ShootAbsorbArrow",
            "Job08_ShootBurningLight",
            "Job08_ShootCounterArrow",
            "Job08_ShootFlameLance",
            "Job08_ShootFlameLanceEnd",
            "Job08_ShootFrostBlock",
            "Job08_ShootFrostTrace",
            "Job08_ShootLifeReturn",
            "Job08_ShootLifeReturnFull",
            "Job08_ShootNormalArrow",
            "Job08_ShootReflectThunder",
            "Job08_ShootReflectThunderEnd",
            "Job08_ShootSeriesArrow",
            "Job08_ShootSeriesArrowEnd",
            "Job08_ShootSleepArrow",
            "Job08_ShootSleepArrowFull",
            "Job08_ShootSpiritArrow",
            "Job08_ShootThunderChain",
            "Job08_ShootThunderChainEnd",
            "Job08_SleepArrowWithoutAim",
            "Job08_StartAim",
            "Job08_ThunderChainWithoutAim",
            "Job08_ThunderChainWithoutAimEnd",
        }, {
            "Weaponlord/Magick Archer.lua",
            "Skill Maker ActionNames.json",
        }),
        skills = {
            build_skill({
                id = 86,
                name = "lifetaking_arrow",
                effect = "Referenced by Magick Archer example logic; exact in-game description not normalized from local sources.",
                conditions = "Observed as skillState == 86.",
                mechanism = "runtime custom skill path; dedicated input processor not explicitly confirmed in local sources",
                sources = {
                    "Dullahan/Magick Archer/MagickArcher.lua",
                    "Dullahan/config.lua",
                },
            }),
        },
        completeness = {
            attacks = "high_from_examples",
            skills = "partial",
            parameters = "partial",
        },
    },
    {
        id = 9,
        key = "trickster",
        label = "Trickster",
        action_prefix = "Job09",
        controller_getter = nil,
        controller_field = "<Job09ActionCtrl>k__BackingField",
        input_processor = nil,
        parameters = {
            known_controller_fields = {
                "<DecoyHandler>k__BackingField",
            },
            known_skill_states = { 95, 97, 98 },
        },
        sources = {
            "Dullahan/Trickster/*",
            "Weaponlord/player_properties.lua",
            "Skill Maker ActionNames.json",
        },
        attacks = build_attacks({
            "Job09_CastAttentionFregrance",
            "Job09_CastDetectFregrance",
            "Job09_CastDetectFregranceEnd",
            "Job09_CastPossessionSmoke",
            "Job09_CastRageFregrance",
            "Job09_CastSmokeDragon",
            "Job09_CastSmokeDragonEnd",
            "Job09_CastSmokeGround",
            "Job09_CastSmokeWall",
            "Job09_CastTripFregrance",
            "Job09_CastTripFregranceEnd",
            "Job09_ClingKeepDraw",
            "Job09_ClingRepairEnd",
            "Job09_ClingSheathe",
            "Job09_ClingSmokeAttack",
            "Job09_ClingSummonToWear",
            "Job09_ClingTransfer",
            "Job09_ClingWearSmokeDecoy",
            "Job09_ClingWearToTransfer",
            "Job09_DashSmokeAttack",
            "Job09_HoldDownKeepDraw",
            "Job09_HoldDownSheathe",
            "Job09_HoldDownSmokeAttack",
            "Job09_HoldDownSummonToWear",
            "Job09_HoldDownTransfer",
            "Job09_HoldDownWearSmokeDecoy",
            "Job09_HoldDownWearToTransfer",
            "Job09_JumpSummonDecoyLanding",
            "Job09_MoveSmokeAttack",
            "Job09_PrepareMoveThrowSmoke",
            "Job09_PrepareSmokeGround",
            "Job09_PrepareSmokeWall",
            "Job09_PrepareSummonAir",
            "Job09_PrepareThrowSmoke",
            "Job09_ShortSmokeAttack",
            "Job09_SmokeAttackAir",
            "Job09_SmokeDecoy",
            "Job09_SummonDecoy",
            "Job09_SummonDecoyDash",
            "Job09_SummonDecoyFinish",
            "Job09_ThrowSmoke",
            "Job09_Transfer",
            "Job09_TransferAir",
            "Job09_Unsummon",
            "Job09_UnsummonAir",
            "Job09_UnsummonUpperBody",
            "Job09_Wear",
            "Job09_WearToTransfer",
            "Job09_WearUpperBody",
        }, {
            "Dullahan/Trickster/*",
            "Skill Maker ActionNames.json",
        }),
        skills = {
            build_skill({
                id = 95,
                name = "vorpal_effluvium",
                effect = "Custom skill referenced by Trickster example logic.",
                conditions = "Observed as skillState == 95 and EnabledCustomSkills[95].Level.",
                mechanism = "runtime custom skill path; dedicated input processor not explicitly confirmed in local sources",
                sources = {
                    "Dullahan/Trickster/VorpalEffluvium.lua",
                    "Dullahan/Trickster/Trickster.lua",
                    "Dullahan/config.lua",
                },
            }),
            build_skill({
                id = 97,
                name = "aromatic_resurgence",
                effect = "Referenced by Trickster example config and runtime logic.",
                conditions = "Observed as skillState == 97.",
                mechanism = "runtime custom skill path; dedicated input processor not explicitly confirmed in local sources",
                sources = {
                    "Dullahan/Trickster/Trickster.lua",
                    "Dullahan/config.lua",
                },
            }),
            build_skill({
                id = 98,
                name = "fragrant_alarum",
                effect = "Referenced by Trickster example config and runtime logic.",
                conditions = "Observed as skillState == 98.",
                mechanism = "runtime custom skill path; dedicated input processor not explicitly confirmed in local sources",
                sources = {
                    "Dullahan/Trickster/Trickster.lua",
                    "Dullahan/config.lua",
                },
            }),
        },
        completeness = {
            attacks = "high_from_examples",
            skills = "partial",
            parameters = "partial",
        },
    },
    {
        id = 10,
        key = "warfarer",
        label = "Warfarer",
        action_prefix = "Job10",
        controller_getter = nil,
        controller_field = nil,
        input_processor = "app.PlayerInputProcessorDetail",
        parameters = {
            known_controller_fields = {},
            known_skill_states = { 100 },
        },
        sources = {
            "Dullahan/Warfarer/Warfarer.lua",
            "Updated Seamless Warfarer.lua",
            "Skill Maker ActionNames.json",
        },
        attacks = build_attacks({
            "Job10_00",
            "Job10_ClimbingSkill",
            "Job10_HoldDownSkill",
        }, {
            "Dullahan/Warfarer/Warfarer.lua",
            "Updated Seamless Warfarer.lua",
            "Skill Maker ActionNames.json",
        }),
        skills = {
            build_skill({
                id = 100,
                name = "rearmament",
                effect = "Weapon-swap custom skill referenced by Warfarer examples.",
                conditions = "Observed as skillState == 100 and setSkill(10,100,0).",
                mechanism = "app.PlayerInputProcessorDetail:processCustomSkill(...)",
                sources = {
                    "Dullahan/Warfarer/Warfarer.lua",
                    "Updated Seamless Warfarer.lua",
                    "Dullahan/config.lua",
                },
            }),
        },
        completeness = {
            attacks = "partial_from_examples",
            skills = "partial",
            parameters = "partial",
        },
    },
}

local by_key = {}
local by_id = {}
local keys = {}
local ids = {}

for _, entry in ipairs(ordered) do
    entry.raw_actions = build_action_names(entry.attacks)
    entry.actions = entry.raw_actions
    entry.skill_refs = build_skill_refs(entry.skills)
    by_key[entry.key] = entry
    by_id[entry.id] = entry
    table.insert(keys, entry.key)
    table.insert(ids, entry.id)
end

hybrid_jobs.ordered = ordered
hybrid_jobs.by_key = by_key
hybrid_jobs.by_id = by_id
hybrid_jobs.keys = keys
hybrid_jobs.ids = ids

function hybrid_jobs.each()
    return ipairs(ordered)
end

function hybrid_jobs.get_by_key(key)
    return by_key[key]
end

function hybrid_jobs.get_by_id(job_id)
    return by_id[tonumber(job_id)]
end

function hybrid_jobs.find_key_by_id(job_id)
    local item = hybrid_jobs.get_by_id(job_id)
    return item and item.key or nil
end

function hybrid_jobs.is_hybrid_job(job_id)
    return hybrid_jobs.get_by_id(job_id) ~= nil
end

function hybrid_jobs.get_action_prefix(job_id)
    local item = hybrid_jobs.get_by_id(job_id)
    return item and item.action_prefix or nil
end

function hybrid_jobs.get_controller_getter(job_id)
    local item = hybrid_jobs.get_by_id(job_id)
    return item and item.controller_getter or nil
end

function hybrid_jobs.get_controller_field(job_id)
    local item = hybrid_jobs.get_by_id(job_id)
    return item and item.controller_field or nil
end

function hybrid_jobs.get_input_processor(job_id)
    local item = hybrid_jobs.get_by_id(job_id)
    return item and item.input_processor or nil
end

function hybrid_jobs.get_attacks(job_id)
    local item = hybrid_jobs.get_by_id(job_id)
    return item and item.attacks or {}
end

function hybrid_jobs.get_skills(job_id)
    local item = hybrid_jobs.get_by_id(job_id)
    return item and item.skills or {}
end

function hybrid_jobs.get_action_names(job_id)
    local item = hybrid_jobs.get_by_id(job_id)
    return item and item.raw_actions or {}
end

return hybrid_jobs

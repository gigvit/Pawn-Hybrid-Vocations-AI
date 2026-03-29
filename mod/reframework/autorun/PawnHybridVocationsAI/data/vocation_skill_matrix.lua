local vocation_skill_matrix = {}
local execution_contracts = require("PawnHybridVocationsAI/core/execution_contracts")

local function merge_into(target, extra)
    if type(extra) ~= "table" then
        return target
    end

    for key, value in pairs(extra) do
        target[key] = value
    end

    return target
end

local function runtime_phase(extra)
    return merge_into({
        min_job_level = 0,
        requires_equipped_skill = true,
        requires_enabled_skill = true,
    }, extra)
end

local function custom_skill(id, name, extra)
    return merge_into({
        id = id,
        name = name,
        progression = {
            layer = "custom_skill",
            requires_equipped_skill = true,
            requires_enabled_skill = true,
            skill_level_signal = "getCustomSkillLevel(app.HumanCustomSkillID)",
            job_level_requirement = "unresolved",
        },
        execution_contract = execution_contracts.selector_owned({
            confidence = "unclassified",
            note = "matrix placeholder until this skill family is grounded by CE or runtime probe evidence",
        }),
    }, extra)
end

local ordered = {
    {
        job_id = 1,
        key = "fighter",
        label = "Fighter",
        action_prefix = "Job01",
        ability_band = { first = 4, last = 8 },
        base_or_core_families = {
            "NormalAttack",
            "TuskToss",
            "Guard",
            "BlinkStrike",
            "ViolentStab",
            "HindsightSlash",
            "FullMoonGuard",
            "ShieldCounter",
            "DivineDefense",
        },
        custom_skills = {
            custom_skill(1, "Job01_BlinkStrike"),
            custom_skill(2, "Job01_RisingLunge"),
            custom_skill(3, "Job01_CymbalAttack"),
            custom_skill(4, "Job01_FullMoonSlash"),
            custom_skill(5, "Job01_Springboard"),
            custom_skill(6, "Job01_ShieldSummons"),
            custom_skill(7, "Job01_ViolentStab"),
            custom_skill(8, "Job01_HindsightSlash"),
            custom_skill(9, "Job01_FullMoonGuard"),
            custom_skill(10, "Job01_ShieldCounter"),
            custom_skill(11, "Job01_DivineDefense"),
            custom_skill(12, "Job01_BravesRaid"),
        },
    },
    {
        job_id = 2,
        key = "archer",
        label = "Archer",
        action_prefix = "Job02",
        ability_band = { first = 9, last = 13 },
        base_or_core_families = {
            "NormalArrow",
            "FullBend",
            "QuickLoose",
            "Threehold",
            "Triad",
            "MeteorShot",
            "AcrobatShot",
            "WhirlingArrow",
            "FullBlast",
        },
        custom_skills = {
            custom_skill(13, "Job02_ThreefoldArrow"),
            custom_skill(14, "Job02_TriadShot"),
            custom_skill(15, "Job02_BodyBinder"),
            custom_skill(16, "Job02_MeteorShot"),
            custom_skill(17, "Job02_SpecialAllowBomb"),
            custom_skill(18, "Job02_SpecialAllowWater"),
            custom_skill(19, "Job02_SpecialAllowOil"),
            custom_skill(20, "Job02_SpecialAllowPoison"),
            custom_skill(21, "Job02_RandomShot"),
            custom_skill(22, "Job02_WhirlingArrow"),
            custom_skill(23, "Job02_FullBlast"),
        },
    },
    {
        job_id = 3,
        key = "mage",
        label = "Mage",
        action_prefix = "Job03",
        ability_band = { first = 14, last = 18 },
        base_or_core_families = {
            "Anodyne",
            "FireStrom",
            "Levin",
            "Frigor",
            "GuardBit",
            "HolyShine",
            "CureSpot",
            "HasteSpot",
            "Boon",
            "Enchant",
        },
        custom_skills = {
            custom_skill(24, "Job03_Firestorm"),
            custom_skill(25, "Job03_Levin"),
            custom_skill(26, "Job03_Frigor"),
            custom_skill(27, "Job03_SpellStock"),
            custom_skill(28, "Job03_GuardBit"),
            custom_skill(29, "Job03_FireBoon"),
            custom_skill(30, "Job03_IceBoon"),
            custom_skill(31, "Job03_ThunderBoon"),
            custom_skill(32, "Job03_HolyShine"),
            custom_skill(33, "Job03_CureSpot"),
            custom_skill(34, "Job03_HasteSpot"),
            custom_skill(35, "Job03_FullRecover"),
            custom_skill(36, "Job03_SpellBreak"),
            custom_skill(37, "Job03_HolyGlare"),
        },
    },
    {
        job_id = 4,
        key = "thief",
        label = "Thief",
        action_prefix = "Job04",
        ability_band = { first = 19, last = 23 },
        base_or_core_families = {
            "_NormalAttack",
            "_LoopAttack",
            "_Pickpocket",
            "_CuttingWind",
            "_Guillotine",
            "_ParryCounter",
            "_AbsoluteAvoidance",
            "_Stealth",
        },
        custom_skills = {
            custom_skill(38, "Job04_CuttingWind"),
            custom_skill(39, "Job04_Guillotine"),
            custom_skill(40, "Job04_Attract"),
            custom_skill(41, "Job04_ParryCounter"),
            custom_skill(42, "Job04_AbsoluteAvoidance"),
            custom_skill(43, "Job04_HollowOut"),
            custom_skill(44, "Job04_FlameBlade"),
            custom_skill(45, "Job04_SmokeScreen"),
            custom_skill(46, "Job04_RemoteBomb"),
            custom_skill(47, "Job04_WindWave"),
            custom_skill(48, "Job04_Stealth"),
            custom_skill(49, "Job04_Snatch"),
        },
        special_custom_skills = {
            custom_skill(101, "Job04_FakeMaster", {
                progression = {
                    layer = "special_case_custom_skill",
                    requires_equipped_skill = false,
                    requires_enabled_skill = false,
                    job_level_requirement = "special_case_unresolved",
                },
            }),
        },
    },
    {
        job_id = 5,
        key = "warrior",
        label = "Warrior",
        action_prefix = "Job05",
        ability_band = { first = 24, last = 28 },
        base_or_core_families = {
            "NormalAttack",
            "ChargeNormalAttack",
            "HeavyAttack",
            "CrescentSlash",
            "GroundDrill",
            "WarCry",
            "IndomitableLash",
            "CycloneSlash",
            "ArcOfObliteration",
        },
        custom_skills = {
            custom_skill(50, "Job05_HeavyRunningThrust"),
            custom_skill(51, "Job05_HorizontalSlash"),
            custom_skill(52, "Job05_CrescentSlash"),
            custom_skill(53, "Job05_CycloneSlash"),
            custom_skill(54, "Job05_GroundDrill"),
            custom_skill(55, "Job05_CounterAttack"),
            custom_skill(56, "Job05_WarCry"),
            custom_skill(57, "Job05_LandSlide"),
            custom_skill(58, "Job05_IndomitableLash"),
            custom_skill(59, "Job05_Guts"),
            custom_skill(60, "Job05_Springboard"),
            custom_skill(61, "Job05_ArcOfObliteration"),
        },
    },
    {
        job_id = 6,
        key = "sorcerer",
        label = "Sorcerer",
        action_prefix = "Job06",
        ability_band = { first = 29, last = 33 },
        base_or_core_families = {
            "_NormalAttack",
            "_RapidShot",
            "_Salamander",
            "_Blizzard",
            "_MineVolt",
            "_SaintDrain",
            "_MeteorFall",
            "_VortexRage",
        },
        custom_skills = {
            custom_skill(62, "Job06_Salamander"),
            custom_skill(63, "Job06_Blizzard"),
            custom_skill(64, "Job06_MineVolt"),
            custom_skill(65, "Job06_SaintDrain"),
            custom_skill(66, "Job06_RockBeat"),
            custom_skill(67, "Job06_AddFlare"),
            custom_skill(68, "Job06_MeteorFall"),
            custom_skill(69, "Job06_VortexRage"),
        },
    },
    {
        job_id = 7,
        key = "mystic_spearhand",
        label = "Mystic Spearhand",
        action_prefix = "Job07",
        ability_band = { first = 34, last = 38 },
        base_or_core_families = {
            "CustomSkillLv2",
            "Flow",
            "HeavyAttack",
            "JustLeap",
            "MagicBind",
            "NormalAttack",
            "SpiralSlash",
        },
        custom_skills = {
            custom_skill(70, "Job07_PsychoShoot", {
                runtime_phase = runtime_phase({
                    key = "skill_psycho_shoot_far",
                    selection_role = "ranged_skill",
                    synthetic_bucket = "ranged",
                    min_distance = 4.75,
                    max_distance = 9.50,
                    priority = 30,
                    execution_contract = execution_contracts.direct_safe({
                        action_candidates = { "Job07_PsychoShoot" },
                        confidence = "working_assumption",
                    }),
                    note = "full-family ranged custom pressure",
                }),
            }),
            custom_skill(71, "Job07_FarThrow", {
                runtime_phase = runtime_phase({
                    key = "skill_far_throw_far",
                    selection_role = "ranged_skill",
                    synthetic_bucket = "ranged",
                    min_distance = 5.00,
                    max_distance = 9.50,
                    priority = 31,
                    execution_contract = execution_contracts.direct_safe({
                        action_candidates = { "Job07_FarThrow" },
                        confidence = "working_assumption",
                    }),
                    note = "full-family ranged throw pressure",
                }),
            }),
            custom_skill(72, "Job07_EnergyDrain", {
                runtime_phase = runtime_phase({
                    key = "skill_energy_drain_close",
                    selection_role = "melee_skill",
                    synthetic_bucket = "sustain",
                    min_distance = 0.00,
                    max_distance = 2.85,
                    priority = 40,
                    execution_contract = execution_contracts.direct_safe({
                        action_candidates = { "Job07_EnergyDrain" },
                        confidence = "working_assumption",
                    }),
                    note = "full-family close custom pressure",
                }),
            }),
            custom_skill(73, "Job07_DragonStinger", {
                runtime_phase = runtime_phase({
                    key = "skill_dragon_stinger_mid",
                    selection_role = "gapclose_skill",
                    synthetic_bucket = "opener",
                    stability = "crash_prone",
                    min_distance = 2.25,
                    max_distance = 6.25,
                    priority = 46,
                    execution_contract = execution_contracts.controller_stateful({
                        action_candidates = { "Job07_DragonStinger" },
                        probe_pack_candidates = {
                            "AppSystem/AI/ActionInterface/ActInterPackData/NPC/Job07/ch300_job07_DragonStinger.user",
                        },
                        preferred_probe_mode = "carrier_then_action",
                        controller_snapshot_key = "Job07_DragonStinger",
                        controller_state_fields = {
                            "DragonStingerVec",
                            "DragonStingerSpeed",
                            "DragonStingerHit",
                        },
                        confidence = "grounded_probe_required",
                    }),
                    note = "first live-grounded custom phase; direct action reached the correct animation but later crashed in app.Job07DragonStinger.update, so this skill now uses explicit probe modes to isolate its required native context",
                }),
            }),
            custom_skill(74, "Job07_QuickShield", {
                runtime_phase = runtime_phase({
                    key = "skill_quick_shield_mid",
                    selection_role = "defense_skill",
                    synthetic_bucket = "defense",
                    min_distance = 1.25,
                    max_distance = 4.75,
                    priority = 22,
                    execution_contract = execution_contracts.direct_safe({
                        action_candidates = { "Job07_QuickShield" },
                        confidence = "working_assumption",
                    }),
                    note = "full-family defensive custom pressure",
                }),
            }),
            custom_skill(75, "Job07_BladeShoot", {
                runtime_phase = runtime_phase({
                    key = "skill_blade_shoot_mid_far",
                    selection_role = "ranged_skill",
                    synthetic_bucket = "ranged",
                    min_distance = 3.25,
                    max_distance = 8.25,
                    priority = 28,
                    synthetic_initiator_priority = 118,
                    execution_contract = execution_contracts.direct_safe({
                        action_candidates = { "Job07_BladeShoot", "Job07_Blade" },
                        confidence = "working_assumption",
                    }),
                    note = "family/action mismatch unresolved; try direct skill name first, then the observed blade action alias",
                }),
            }),
            custom_skill(76, "Job07_SkyDive", {
                runtime_phase = runtime_phase({
                    key = "skill_skydive_far",
                    selection_role = "gapclose_skill",
                    synthetic_bucket = "opener",
                    min_distance = 4.75,
                    max_distance = 7.50,
                    priority = 48,
                    synthetic_initiator_priority = 120,
                    execution_contract = execution_contracts.direct_safe({
                        action_candidates = { "Job07_SkyDive" },
                        confidence = "working_assumption",
                    }),
                    note = "advanced far-range dive pressure",
                }),
            }),
            custom_skill(77, "Job07_Gungnir", {
                runtime_phase = runtime_phase({
                    key = "skill_gungnir_far",
                    selection_role = "ranged_skill",
                    synthetic_bucket = "ranged",
                    min_distance = 4.50,
                    max_distance = 9.00,
                    priority = 36,
                    execution_contract = execution_contracts.direct_safe({
                        action_candidates = { "Job07_Gungnir", "Job07_GungnirShoot" },
                        confidence = "working_assumption",
                    }),
                    note = "full-family spear barrage pressure",
                }),
            }),
            custom_skill(78, "Job07_TwoSeconds", {
                runtime_phase = runtime_phase({
                    key = "skill_two_seconds_mid_far",
                    selection_role = "ranged_skill",
                    synthetic_bucket = "ranged",
                    min_distance = 3.50,
                    max_distance = 8.00,
                    priority = 27,
                    execution_contract = execution_contracts.direct_safe({
                        action_candidates = { "Job07_TwoSeconds" },
                        confidence = "working_assumption",
                    }),
                    note = "full-family delayed ranged pressure",
                }),
            }),
            custom_skill(79, "Job07_DanceOfDeath", {
                runtime_phase = runtime_phase({
                    key = "skill_dance_of_death_close",
                    selection_role = "melee_skill",
                    synthetic_bucket = "burst",
                    min_distance = 0.00,
                    max_distance = 2.65,
                    priority = 43,
                    execution_contract = execution_contracts.direct_safe({
                        action_candidates = { "Job07_DanceOfDeath" },
                        confidence = "working_assumption",
                    }),
                    note = "full-family close flurry pressure",
                }),
            }),
        },
    },
    {
        job_id = 8,
        key = "magick_archer",
        label = "Magick Archer",
        action_prefix = "Job08",
        ability_band = { first = 39, last = 43 },
        base_or_core_families = {
            "AimArrow",
            "Effect",
            "JustRelease",
            "NormalAttack",
            "RemainArrow",
        },
        custom_skills = {
            custom_skill(80, "Job08_FlameLance"),
            custom_skill(81, "Job08_BurningLight"),
            custom_skill(82, "Job08_FrostTrace"),
            custom_skill(83, "Job08_FrostBlock"),
            custom_skill(84, "Job08_ThunderChain"),
            custom_skill(85, "Job08_ReflectThunder"),
            custom_skill(86, "Job08_AbsorbArrow"),
            custom_skill(87, "Job08_LifeReturn"),
            custom_skill(88, "Job08_CounterArrow"),
            custom_skill(89, "Job08_SleepArrow"),
            custom_skill(90, "Job08_SeriesArrow"),
            custom_skill(91, "Job08_SpiritArrow"),
        },
    },
    {
        job_id = 9,
        key = "trickster",
        label = "Trickster",
        action_prefix = "Job09",
        ability_band = { first = 44, last = 48 },
        base_or_core_families = {
            "_AstralBody",
            "_AttackSmoke",
            "_AttentionFregrance",
            "_Common",
            "_DetectFregrance",
            "_NormalAttack",
            "_PossessionSmoke",
            "_RageFregrance",
            "_SmokeDecoy",
            "_SmokeDragon",
            "_SmokeGround",
            "_SmokeWall",
            "_ThrowSmoke",
            "_TransferSmoke",
        },
        custom_skills = {
            custom_skill(92, "Job09_SmokeWall"),
            custom_skill(93, "Job09_SmokeGround"),
            custom_skill(94, "Job09_TripFregrance"),
            custom_skill(95, "Job09_AttentionFregrance"),
            custom_skill(96, "Job09_PossessionSmoke"),
            custom_skill(97, "Job09_RageFregrance"),
            custom_skill(98, "Job09_DetectFregrance"),
            custom_skill(99, "Job09_SmokeDragon"),
        },
    },
    {
        job_id = 10,
        key = "warfarer",
        label = "Warfarer",
        action_prefix = "Job10",
        ability_band = { first = 49, last = 50 },
        base_or_core_families = {
            "Job10_00",
        },
        custom_skills = {
            custom_skill(100, "Job10_00"),
        },
    },
}

local by_id = {}
local by_key = {}
local skill_by_id = {}
local ordered_job_ids = {}

for _, job in ipairs(ordered) do
    by_id[job.job_id] = job
    by_key[job.key] = job
    ordered_job_ids[#ordered_job_ids + 1] = job.job_id

    for _, skill in ipairs(job.custom_skills or {}) do
        skill.job_id = job.job_id
        skill.job_key = job.key
        skill.job_label = job.label
        skill_by_id[skill.id] = skill
    end

    for _, skill in ipairs(job.special_custom_skills or {}) do
        skill.job_id = job.job_id
        skill.job_key = job.key
        skill.job_label = job.label
        skill_by_id[skill.id] = skill
    end
end

vocation_skill_matrix.ordered = ordered
vocation_skill_matrix.by_id = by_id
vocation_skill_matrix.by_key = by_key
vocation_skill_matrix.skill_by_id = skill_by_id
vocation_skill_matrix.ordered_job_ids = ordered_job_ids

function vocation_skill_matrix.each()
    return ipairs(ordered)
end

function vocation_skill_matrix.get_job(job_id)
    return by_id[tonumber(job_id)]
end

function vocation_skill_matrix.get_job_by_key(key)
    return by_key[key]
end

function vocation_skill_matrix.get_custom_skill(skill_id)
    return skill_by_id[tonumber(skill_id)]
end

return vocation_skill_matrix

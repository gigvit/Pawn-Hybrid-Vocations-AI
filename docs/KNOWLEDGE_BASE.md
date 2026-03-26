# KNOWLEDGE_BASE

## English

### Explanation

#### Project model

Project invariant:

`unlock != equipment != skills != combat runtime != pawn combat context != AI parity`

This means:

- unlock alone is not a combat fix
- visible guild access is not proof of working AI
- a live controller is not proof of a working job-specific combat path

#### Current project split

The repository now follows one strict split:

- `mod/` contains product runtime code
- `docs/ce_scripts/` contains research scripts

Default policy:

- `mod = implementation`
- `CE scripts = research`

#### Source-of-truth order

When sources disagree, trust them in this order:

1. CE outputs written to file
2. current product runtime behavior
3. direct engine data inspection
4. historical git documentation
5. theory and guesses

#### Current product runtime

The active runtime core is limited to:

- `bootstrap.lua`
- `game/discovery.lua`
- `game/main_pawn_properties.lua`
- `game/progression/state.lua`
- `game/hybrid_unlock.lua`

The product runtime currently does three important things:

1. resolves `player` and `main_pawn`
2. reads progression and job-bit state
3. restores the actual hybrid unlock path for `main_pawn`

#### Current unlock state

Confirmed in code:

- hybrid unlock depends on `player.QualifiedJobBits`
- missing hybrid bits are mirrored into `main_pawn.JobContext.QualifiedJobBits`
- the in-memory progression snapshot is refreshed immediately after the mirror write
- a narrow guild-side override is installed on `app.ui040101_00.getJobInfoParam`
- the override enables `_EnablePawn` on hybrid job info for `main_pawn` and otherwise returns the original UI result

Confirmed in game:

- the crash introduced by the earlier risky guild-hook path is gone
- the restored unlock path works again for `main_pawn`

Interpretation:

- unlock works through a product-scoped runtime path again
- unlock and guild access are still separate from the unresolved `Job07` combat-path problem

#### Historical findings preserved from pre-cleanup research

The removed research layer had already established several useful points that remain relevant:

- `Job07` in the engine is real, not fictional
- `Job07` could briefly approach `Job01` and then degrade again
- the weaker `Job07` state looked more like under-population or admission loss than complete absence
- broad getter-heavy probing was expensive and could trigger FPS collapse and REFramework exceptions

These findings are historical context now, not the active implementation path.

#### Confirmed combat findings

##### `main_pawn`

Confirmed:

- `main_pawn` resolves reliably enough for runtime inspection
- progression state, current job, and baseline runtime context are readable

##### `Job01`

`Job01` is the control baseline.

Confirmed by burst traces:

- navigation appears first
- then combat execution transitions into job-specific packs
- then job-specific nodes appear

Observed examples:

- `Job01_BlinkStrike_Standard`
- `Job01_FullMoonSlash`
- `Job01_HindsightSlash`
- `Job01_ViolentStab`
- `Job01_NormalAttack`
- `Job01_SkillAttack`
- `Job01_SubNormalAttack`

##### `main_pawn Job07`

Confirmed by CE dumps and burst traces:

- `current_job = 7`
- `Job07ActionCtrl` is live through both `field` and `getter`
- the primary decision module is `app.DecisionEvaluationModule`
- `DecisionExecutor` is live
- `ExecutingDecision` is live
- combat target can be `app.Character`
- runtime still stays in generic carrier families instead of entering confirmed `Job07_*` combat families

Observed generic carriers:

- `Common/MoveToPosition_Walk_Target.user`
- `ch1_Move_Run_Target.user`
- `Common/InForcedAnimation.user`
- `Locomotion.NormalLocomotion`
- `Locomotion.Strafe`
- `Damage.*`

Not confirmed for `main_pawn Job07`:

- stable `Job07_*` pack
- stable `Job07_*` node

##### `Sigurd Job07`

Valid `Sigurd` control traces now exist.

Confirmed:

- `Sigurd` enters real `Job07`-specific NPC packs
- `Sigurd` enters real `Combat.Job07_*` node families
- the primary decision module is `app.ThinkTableModule`
- `DecisionExecutor` and `ExecutingDecision` are absent in the observed `Sigurd Job07` pipeline

Observed pack examples:

- `ch300_job07_SideWalkB_Blade4`
- `ch300_job07_SideWalkR_Blade4`
- `ch300_job07_SkyDive`
- `ch300_job07_MagicBindLeap`
- `ch300_job07_SpiralSlash`

Observed node examples:

- `Job07_ShortRangeAttack`
- `Job07_MagicBindJustLeap`
- `Job07_MagicBindComplete`
- `Job07_SkyDive`
- `Job07_SkyDiveLanding`
- `Job07_SpiralSlash`

##### Decision pipeline architecture

Focused CE compares now show a structural split:

- `main_pawn Job07` is routed through the pawn `app.DecisionEvaluationModule` pipeline
- `Sigurd Job07` is routed through the NPC `app.ThinkTableModule` pipeline
- `ThinkTableModule` was not found near the observed `main_pawn` decision chain in the tested scenes
- the earlier `selector / admission / context` question is now narrowed to a pawn-specific decision-content or decision-output question

##### Combat main-decision population

Focused combat captures now show a second, stronger split inside the pawn pipeline itself:

- outside combat, selected-job-only snapshots can still look identical between `main_pawn Job01` and `main_pawn Job07`
- in combat, `main_pawn Job01` repeatedly exposes `42` `MainDecisions`
- in combat, `main_pawn Job07` repeatedly exposes only `11` `MainDecisions`
- across repeated captures, `main_pawn Job07` contributes no unique combat `scalar_profile` or `combined_profile`
- the observed `main_pawn Job07` combat `MainDecisions` are a strict subset of the observed `main_pawn Job01` combat `MainDecisions`
- the remaining blocker is therefore already visible inside the pawn `DecisionEvaluationModule` combat decision population

##### Combat semantic split inside `MainDecisions`

The semantic compare sharpens the same conclusion:

- repeated semantic captures show `main_pawn Job01` at `47-48` combat `MainDecisions`
- repeated semantic captures show `main_pawn Job07` at `11` combat `MainDecisions`
- `main_pawn Job07` contributes no unique combat `semantic_signature`; all observed `Job07` semantic signatures are already present in `Job01`
- the retained `Job07` combat layer is dominated by common movement / carry / talk / catch / cliff / keep-distance behavior
- `main_pawn Job07` still surfaces no observed `Job07_*` action-pack identities in these combat captures
- `main_pawn Job01` includes many additional attack-oriented packs and behaviors that do not survive into combat `Job07`, including multiple `Job01_Fighter/*` packs and several `GenericJob/*Attack*` packs
- the reduced `Job07` combat layer also loses much of the richer `EvaluationCriteria`, `TargetConditions`, and `SetAttackRange` start/end-process population seen in combat `Job01`

#### Strengthened conclusions

These conclusions are now strong:

- the blocker is not best explained by a missing `Job07ActionCtrl`
- the blocker is not best explained by a missing decision state
- `Job07` content exists and works in the engine
- the current gap is `main_pawn`-specific
- `main_pawn Job07` and `Sigurd Job07` do not share the same primary decision architecture
- `main_pawn Job07` uses `app.DecisionEvaluationModule`
- `Sigurd Job07` uses `app.ThinkTableModule`
- the current gap is now best explained as a pawn decision-pipeline gap, not only as a generic selector/admission surface gap
- in combat, `main_pawn Job07` is under-populated before action output, not only misrouted after selection
- the observed combat `main_pawn Job07` `MainDecisions` form a strict subset of combat `main_pawn Job01` `MainDecisions`
- the observed combat `main_pawn Job07` semantic layer is still generic/common-heavy and does not expose a confirmed `Job07` attack-oriented decision cluster
- timed combat output bursts now close the next bridge step:
- stable combat `Job01` bursts show `attack_populated` decision state feeding mostly `job_specific_output_candidate` output, including `Job01_*` actions, `Job01_*` FSM nodes, and attack-oriented `decision_pack_path` values
- stable combat `Job07` bursts still show only `11` `MainDecisions`, `current_job_pack_count=0`, `generic_attack_pack_count=0`, utility-only pack identities, and `common_utility_output` such as `Strafe`, `NormalLocomotion`, and `Common/MoveToPosition_Walk_Target`
- the missing combat behavior is therefore now traced through to output surfaces, not only inferred from decision-population differences

#### Weakened or rejected conclusions

These older conclusions are no longer active:

- "`Job07` is absent for `main_pawn`"
- "`ce_dump=nil` proves the absence of `Job07ActionCtrl`"
- "`target kind mismatch` is always the root cause"
- "`getter` alone proves a live attack path"

#### Current strongest hypothesis

Current working hypothesis:

- `main_pawn Job07` does not fail inside the NPC `ThinkTableModule` path because it is not using that path in the observed scenes
- the pawn `DecisionEvaluationModule` content for combat `Job07` is not simply different; it is under-populated versus combat `Job01`
- the next question is which missing attack-oriented combat `MainDecisions` correspond to the lost `Job07` combat behavior and how that reduction propagates into evaluation output or action output
- the strongest local candidates are the missing `Job01_Fighter/*`, `GenericJob/*Attack*`, and `SetAttackRange`-bearing combat decisions that appear in combat `Job01` but not in combat `Job07`

#### Vocation definition surface

`vocation_definition_surface_20260326_195656.json` confirms that CE Console can extract real vocation-definition data, not only actor or NPC snapshots.

- `app.HumanCustomSkillID` now gives confirmed hybrid custom-skill bands:
- `Job07 = 70..79`
- `Job08 = 80..91`
- `Job09 = 92..99`
- `Job10 = 100`
- `app.HumanAbilityID` also resolves hybrid ability bands:
- `Job07 = 34..38`
- `Job08 = 39..43`
- `Job09 = 44..48`
- `Job10 = 49..50`
- `Job07Parameter` exposes real combat surfaces such as `NormalAttackParam`, `HeavyAttackParam`, `MagicBindParam`, `SpiralSlashParam`, `SkyDiveParam`, `DragonStingerParam`, `FarThrowParam`, `EnergyDrainParam`, and `DanceOfDeathParam`
- `Job08Parameter` exposes `NormalAttackParam`, `FlameLanceParam`, `BurningLightParam`, `FrostBlockParam`, `ThunderChainParam`, `CounterArrowParam`, `SeriesArrowParam`, and `SpiritArrowParam`
- `Job09Parameter` exposes `_NormalAttackParam`, `_ThrowSmokeParam`, `_SmokeDecoyParam`, `_DetectFregranceParam`, and `_AstralBodyParam`
- `Job10Parameter` currently exposes only `Job10_00Param`
- `Job07`, `Job08`, and `Job09` all expose live `InputProcessor`, `ActionController`, and `ActionSelector` types, while `Job10` exposes controller and selector surfaces but no observed `Job10InputProcessor`
- `Job07InputProcessor` and `Job07ActionSelector` expose concrete entry points such as `processMagicBind`, `processNormalAttack`, `processSpiralSlash`, `processCustomSkill`, `getCustomSkillAction`, `getNormalAttackAction`, and `requestActionImpl`
- `Job08` and `Job09` also expose concrete job-specific `processCustomSkill` and normal-attack selector surfaces, so later profiles for `08` and `09` do not need to start from blind guesses
- the original vocations also provide a strong control baseline:
- `Job01` through `Job06` expose stable `AbilityParam` bands with no ambiguity in the captured `vocation_definition_surface` output:
- `Job01 = 4..8`
- `Job02 = 9..13`
- `Job03 = 14..18`
- `Job04 = 19..23`
- `Job05 = 24..28`
- `Job06 = 29..33`
- `Job01` through `Job06` also expose rich parameter-family surfaces that help distinguish genuine combat families from custom-skill families:
- `Job01`: `NormalAttack`, `TuskToss`, `Guard`, `BlinkStrike`, `ViolentStab`, `HindsightSlash`, `FullMoonGuard`, `ShieldCounter`, `DivineDefense`
- `Job02`: bow and arrow families such as `NormalArrow`, `FullBend`, `QuickLoose`, `Threehold`, `Triad`, `MeteorShot`, `AcrobatShot`, `WhirlingArrow`, `FullBlast`
- `Job03`: staff or spell families such as `Anodyne`, `FireStrom`, `Levin`, `Frigor`, `GuardBit`, `HolyShine`, `CureSpot`, `HasteSpot`, `Boon`, `Enchant`
- `Job04`: dagger or rogue families such as `_NormalAttack`, `_LoopAttack`, `_Pickpocket`, `_CuttingWind`, `_Guillotine`, `_ParryCounter`, `_AbsoluteAvoidance`, `_Stealth`
- `Job05`: greatsword families such as `NormalAttack`, `ChargeNormalAttack`, `HeavyAttack`, `CrescentSlash`, `GroundDrill`, `WarCry`, `IndomitableLash`, `CycloneSlash`, `ArcOfObliteration`
- `Job06`: sorcerer families such as `_NormalAttack`, `_RapidShot`, `_Salamander`, `_Blizzard`, `_MineVolt`, `_SaintDrain`, `_MeteorFall`, `_VortexRage`
- off-job `SkillContext` access is strong: both `player` and `main_pawn` expose per-job equip lists for `Job07` through `Job10` even while the recorded snapshot was `player=Mage` and `main_pawn=Fighter`
- the same off-job visibility is not hybrid-specific: even while the recorded snapshot was `player = Mage` and `main_pawn = Fighter`, the live skill scan still exposed enabled or level-positive entries across `Job01` through `Job08`, including `Job01_BlinkStrike`, `Job02_ThreefoldArrow`, `Job03_Firestorm`, `Job04_CuttingWind`, and `Job05_CrescentSlash`
- this means the engine is willing to reveal broad cross-job progression state without switching the actor to that vocation, so future progression tooling should treat the original vocations as a control group, not just as unrelated content
- in the recorded snapshot both `player` and `main_pawn` carried `Job07 slot0 = Job07_DragonStinger`, `Job08 slot0 = Job08_FrostTrace`, and empty `Job09` / `Job10` slots
- `SkillAvailability` stayed unresolved in this snapshot while `SkillContext` and `CustomSkillState` were live, so runtime gating should prefer `SkillContext`, per-job equip lists, `hasEquipedSkill(...)`, `isCustomSkillEnable(...)`, and `getCustomSkillLevel(...)`
- `SkyDive` is confirmed custom skill `76`
- `SpiralSlash` appears in `Job07Parameter` and `Job07InputProcessor` but not in `app.HumanCustomSkillID`; until contrary evidence appears it should be treated as a core or non-custom move, not as a custom-skill gate
- `Job10` is structurally special and should stay a separate implementation track when the runtime bridge expands from `Job07` to `Job08` through `Job10`
- two caution signals from the live skill scan are worth preserving:
- a placeholder-like `None` entry can still appear as enabled with `level = 1`
- `Job01_BravesRaid` appeared as enabled with no explicit equipped-job list in this snapshot
- so the live skill scan is powerful, but any progression reader should still filter placeholder rows and not assume that `enabled = true` always implies a clean equipped-slot origin

#### Vocation progression matrix

`vocation_progression_matrix_20260326_214421.json` confirms that the new progression-oriented extractor can separate several layers that were previously mixed together.

- `Job07` now splits cleanly into:
- base or core families: `CustomSkillLv2`, `Flow`, `HeavyAttack`, `JustLeap`, `MagicBind`, `NormalAttack`, `SpiralSlash`
- custom-skill families: `BladeShoot`, `DanceOfDeath`, `DragonStinger`, `EnergyDrain`, `FarThrow`, `Gungnir`, `PsychoShoot`, `QuickShield`, `SkyDive`, `TwoSeconds`
- `Job08` also splits cleanly into:
- base or core families: `AimArrow`, `Effect`, `JustRelease`, `NormalAttack`, `RemainArrow`
- custom-skill families: `AbsorbArrow`, `BurningLight`, `CounterArrow`, `FlameLance`, `FrostBlock`, `FrostTrace`, `LifeReturn`, `ReflectThunder`, `SeriesArrow`, `SleepArrow`, `SpiritArrow`, `ThunderChain`
- the hybrid custom-skill enum is now explicit enough to use as a product-facing reference layer:
- `Job07`: `70 = PsychoShoot`, `71 = FarThrow`, `72 = EnergyDrain`, `73 = DragonStinger`, `74 = QuickShield`, `75 = BladeShoot`, `76 = SkyDive`, `77 = Gungnir`, `78 = TwoSeconds`, `79 = DanceOfDeath`
- `Job08`: `80 = FlameLance`, `81 = BurningLight`, `82 = FrostTrace`, `83 = FrostBlock`, `84 = ThunderChain`, `85 = ReflectThunder`, `86 = AbsorbArrow`, `87 = LifeReturn`, `88 = CounterArrow`, `89 = SleepArrow`, `90 = SeriesArrow`, `91 = SpiritArrow`
- `Job09`: `92 = SmokeWall`, `93 = SmokeGround`, `94 = TripFregrance`, `95 = AttentionFregrance`, `96 = PossessionSmoke`, `97 = RageFregrance`, `98 = DetectFregrance`, `99 = SmokeDragon`
- `Job10`: `100 = Job10_00`
- the all-job `custom-skill` bands are now stable enough to treat as canonical vocabulary:
- `Job01 = 1..12`, `Job02 = 13..23`, `Job03 = 24..37`, `Job04 = 38..49`, `Job05 = 50..61`, `Job06 = 62..69`, `Job07 = 70..79`, `Job08 = 80..91`, `Job09 = 92..99`, `Job10 = 100`
- the same canonical matrix now exists in runtime code as `data/vocation_skill_matrix.lua`, so the mod no longer needs to reassemble these ids from scattered notes or one-off profile patches
- `Job09` does not map cleanly through the same enum-name heuristic yet; its parameter families still appear as smoke, fragrance, possession, decoy, and astral groups, so `Job09` will need its own family mapping instead of a direct enum-name join
- `Job10` remains opaque at this level; the observed parameter family surface is still only `Job10_00`
- the live off-job progression state is stable across both `player` and `main_pawn` in this snapshot:
- `Job07_DragonStinger = 73` is not just present in the enum; it is the first confirmed live-grounded `Job07` custom skill because the snapshot shows it equipped, enabled, and at `level = 1` for both recorded actors
- `Job07_DragonStinger` is equipped, enabled, and reports `level = 1`
- `Job08_FrostTrace` is equipped, enabled, and reports `level = 1`
- no active `Job09` or `Job10` custom skills were observed
- no hybrid equipped augments or abilities were observed in the live `AbilityContext` snapshot for either actor
- `current_job_level` and per-hybrid `getJobLevel(...)` remained `nil` for both recorded actors, so direct runtime level reads are still unreliable and should not hard-block base attacks or level-0 fallback phases
- the first progression-matrix run exposed a new reading rule for hybrid augment data: `AbilityParam.JobAbilityParameters` behaves like a `job_id - 1` indexed collection, so direct `job_id` indexing shifts `Job07` to `Job08`, `Job08` to `Job09`, and so on
- because of that indexing hazard, the first progression-matrix JSON is reliable for base/core families and custom-skill state, but the per-job hybrid augment matrix should be re-captured after the extractor fix before it is treated as canonical

#### Confirmed implementation direction

The next implementation step is no longer blind pack guessing.

- keep the decision-pipeline diagnosis as the main blocker explanation for `main_pawn Job07`
- use the extracted class-definition surface to build progression-aware hybrid profiles
- treat `Job07` as the first grounded profile:
- core phases can use confirmed non-custom surfaces such as `SpiralSlash`
- the first live-grounded custom phase candidate should be `DragonStinger = 73`, because it is confirmed in the enum, in the job parameter family surface, and in live equipped or enabled state
- the `Job07` runtime profile should be built from the whole confirmed custom-skill family, not grown one action at a time
- the first full-family rollout already proved a critical distinction: direct `requestActionCore("Job07_DragonStinger")` can enter visible `Job07_*` animation for `main_pawn`, but the game later crashes in `app.Job07DragonStinger.update`, so some confirmed skills still require more than bare action forcing
- custom-skill phases should use confirmed ids such as `SkyDive = 76`
- expand the same profile architecture to `Job08` and `Job09`, then handle `Job10` as a separate structural case

#### Execution contracts and unsafe skill probes

The runtime bridge now needs an execution-contract layer, not only a skill-id layer.

- a skill id tells the mod what the skill is
- an execution contract tells the mod how that skill may be entered safely
- the working contract categories are now:
- `direct_safe`
- `carrier_required`
- `controller_stateful`
- `selector_owned`
- the canonical all-job matrix now stores an `execution_contract` placeholder for every custom skill from `Job01` through `Job10`
- that placeholder is intentionally conservative: unclassified skills stay `selector_owned` in data until CE or runtime evidence grounds a safer contract
- `Job07` is now the first profile where contracts are explicit in code instead of only described in documentation:
- basic direct actions such as `Job07_ShortRangeAttack` are modeled as `direct_safe`
- carrier-backed core phases such as `MagicBindLeap` and `SpiralSlash` are modeled as `carrier_required`
- `DragonStinger` is modeled as `controller_stateful` and kept in probe mode until its required native context is understood
- the runtime bridge now resolves contract class and bridge mode from phase data instead of relying only on scattered special flags like `unsafe_direct_action`
- session logs now include `contract` and `bridge_mode` on applied or failed phases, so probe results can be turned back into normal runtime data with less guesswork
- contract normalization now lives in a shared runtime module, so the matrix, profile builder, and bridge all resolve the same execution contract instead of each keeping their own partial logic
- probe snapshots are now contract-driven too: stateful skills can declare `controller_state_fields`, and the runtime logs those fields from the matching `JobXXActionCtrl` instead of hardcoding a `Job07`-only snapshot path
- `DragonStinger` is the first confirmed proof that the distinction matters:
- the direct action path reached visible `Job07_*` animation
- the crash then happened in `app.Job07DragonStinger.update`
- CE surfaces show dedicated `Job07ActionCtrl` state for that skill, including `DragonStingerVec`, `DragonStingerSpeed`, and `DragonStingerHit`
- the runtime now treats `DragonStinger` as a probe-gated unsafe-skill path instead of pretending that direct action is the final answer
- the current probe modes are:
- `off`
- `action_only`
- `carrier_only`
- `carrier_then_action`
- probe logs now snapshot the current action output and the `Job07ActionCtrl` state before the unsafe attempt
- this investigation pattern should later expand from `Job07` to the whole vocation matrix, including original vocations, so the mod can classify every skill by execution contract instead of by guessed action names alone
- phase choice is now system-first instead of skill-first:
- raw per-skill `priority` is still preserved
- but it is no longer the only selector
- the runtime now combines role, distance, assumed job-level safety, repetition, and recent skill streak into a final phase score
- this is required so the pawn does not loop the highest-priority skill forever and can still look native-like through ordinary attacks, engagement moves, gap-closers, and only then skill follow-ups

#### Archived research layer

The old research layer was removed from the product hot path.

Archived domains:

- orchestration: `app/module_specs.lua`, `app/runtime_driver.lua`, `core/module_system.lua`
- logging and traces: old `core/log.lua`, session logs, discovery logs, guild trace logs
- research modules: `action_research`, `combat_research`, `loadout_research`, `pawn_ai_data_research`, `guild_flow_research`, `sigurd_observer`, `npc_spawn_prototype`, `talk_event_trace`
- progression probes: `game/progression/trace.lua`, `probe.lua`, `correlation.lua`
- synthetic and adapter layer
- runtime debug UI

Residual value preserved from the old logs before deletion:

- the remaining `2026-03-25` session logs confirm that `main_pawn Job07` could reach the correct hybrid runtime surface (`main_pawn_job=7`, `main_pawn_weapon_job=7`) and still remain stuck in common runtime output such as `NormalLocomotion`, `DrawWeapon`, and `Common/Common_MoveToHighFive.user`
- one recorded `Job07` session still showed a live current-job loadout `73,0,0,0` while output stayed generic/common, so the failure was not explained by a totally empty visible custom-skill slot state
- the old discovery and action-research hooks produced high hook volume but poor payload yield: repeated `actinter_requests` could still end with `decision_probe_hits=0`, `decision_snapshot_hits=0`, and `decision_actionpack_snapshot_hits=0`
- this historical signal supports the current CE-first rule: keep the old logs only as archived evidence, not as the default diagnostic path

Restore rule:

- restore one concrete mechanism only after CE scripts prove that the narrowed question cannot be answered without hooks

#### Performance and network boundary

Still active rules:

- prefer compact summaries over broad reflective scans
- avoid getter-heavy probing in the product hot path
- keep the core branch local-runtime-first
- keep online, rental, and pawn-share logic out of the main implementation branch

#### Archived manual Content Editor path

The older manual `Content Editor` inspection route is preserved as reference, not as the default workflow.

Its main targets were:

- `AI Overview`
- `app.PawnBattleController._BattleAIData`
- `app.PawnOrderController.OrderData`
- `app.PawnUpdateController.AIGoalActionData`
- `app.goalplanning.AIGoalCategoryJob._JobDecisions`
- blackboard collections
- `CharacterManager:get_HumanParam() -> app.Job07Parameter`

Status:

- useful as a bounded manual fallback
- not the default path while CE Console scripts answer the active questions

### How-to

#### How to research now

Use CE Console scripts.

Standard cycle:

1. define one concrete question
2. choose one script for that question
3. write the result to file
4. compare it with a baseline or control actor
5. update this file first
6. update `ROADMAP.md` only if priorities changed
7. update `CHANGELOG.md` when code or documentation changed

#### How to judge a conclusion

A conclusion is strong enough for this file only if:

- the script wrote a structured result to file
- the result is reproducible
- the wording follows directly from recorded fields
- conflicting older wording was removed or explicitly weakened

#### How to decide whether hooks may return

Do not return to hooks by default.

Return is allowed only if all of the following are true:

- the question is already narrowed to one runtime transition
- screen and burst CE scripts do not capture it
- without hooks the cause cannot be demonstrated
- the need is documented before implementation starts
- the product branch stays isolated from broad research logging

### Reference

#### Active CE scripts

- `docs/ce_scripts/job07_runtime_resolution_screen.lua`
- `docs/ce_scripts/job07_burst_combat_trace.lua`
- `docs/ce_scripts/actor_burst_combat_trace.lua`
- `docs/ce_scripts/job07_selector_admission_compare_screen.lua`
- `docs/ce_scripts/main_pawn_main_decision_profile_screen.lua`
- `docs/ce_scripts/main_pawn_main_decision_semantic_screen.lua`
- `docs/ce_scripts/main_pawn_output_bridge_burst.lua`
- `docs/ce_scripts/vocation_definition_surface_screen.lua`
- `docs/ce_scripts/vocation_progression_matrix_screen.lua`

#### Required CE script properties

Each CE script must:

- solve one concrete task
- write output to file
- produce data suitable for compare and later documentation updates

#### Current implementation files

- `mod/reframework/autorun/PawnHybridVocationsAI/bootstrap.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/data/hybrid_combat_profiles.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/discovery.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/main_pawn_properties.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/progression/state.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_unlock.lua`

#### Historical native decision-pool signals

The earlier native-first branch repeatedly used these containers as safe structural signals:

- `_CurrentGoalList`
- `_CurrentAddDecisionList`
- `MainDecisions`
- `PreDecisions`
- `PostDecisions`
- `ActiveDecisionPacks`

They remain useful as historical reference even though the current research path is CE-first.

## Русский

### Объяснение

#### Модель проекта

Инвариант проекта:

`unlock != equipment != skills != combat runtime != pawn combat context != AI parity`

Это означает:

- unlock сам по себе не чинит бой
- видимый guild access не доказывает рабочий AI
- живой controller не доказывает рабочий job-specific combat path

#### Текущее разделение проекта

Репозиторий теперь следует одному строгому разделению:

- `mod/` содержит продуктовый runtime-код
- `docs/ce_scripts/` содержит исследовательские скрипты

Базовая политика:

- `mod = implementation`
- `CE scripts = research`

#### Порядок источников истины

Если источники противоречат друг другу, доверять им в таком порядке:

1. CE outputs, записанные в файл
2. текущее поведение продуктового runtime
3. прямой engine data inspection
4. историческая документация из git
5. теория и догадки

#### Текущий продуктовый runtime

Активное runtime-ядро ограничено файлами:

- `bootstrap.lua`
- `game/discovery.lua`
- `game/main_pawn_properties.lua`
- `game/progression/state.lua`
- `game/hybrid_unlock.lua`

Сейчас продуктовый runtime делает три важных вещи:

1. резолвит `player` и `main_pawn`
2. читает progression и job-bit state
3. восстанавливает реальный hybrid unlock path для `main_pawn`

#### Текущее состояние unlock

Подтверждено в коде:

- hybrid unlock зависит от `player.QualifiedJobBits`
- недостающие hybrid bits зеркалятся в `main_pawn.JobContext.QualifiedJobBits`
- in-memory snapshot progression обновляется сразу после записи
- на `app.ui040101_00.getJobInfoParam` стоит узкий guild-side override
- override включает `_EnablePawn` для hybrid job info у `main_pawn` и в остальных случаях возвращает исходный UI result

Подтверждено в игре:

- краш, внесенный прежним рискованным guild-hook path, устранен
- восстановленный unlock path снова работает для `main_pawn`

Интерпретация:

- unlock снова работает через продуктовый runtime path
- unlock и guild access по-прежнему не решают отдельную проблему боевого `Job07`

#### Исторические выводы из pre-cleanup research

Удаленный research layer уже успел установить несколько полезных пунктов, которые остаются важными:

- `Job07` в движке реален, а не вымышлен
- `Job07` мог кратко приближаться к `Job01`, а затем снова деградировать
- более слабое состояние `Job07` было похоже на under-population или admission loss, а не на полное отсутствие
- широкий getter-heavy probing был дорогим и мог вызывать FPS collapse и REFramework exceptions

Сейчас эти выводы являются историческим контекстом, а не активным implementation path.

#### Подтвержденные боевые выводы

##### `main_pawn`

Подтверждено:

- `main_pawn` резолвится достаточно надежно для runtime inspection
- progression state, current job и базовый runtime context читаются

##### `Job01`

`Job01` - это контрольный baseline.

Подтверждено burst trace:

- сначала видна navigation phase
- затем combat execution переходит в job-specific packs
- затем появляются job-specific nodes

Наблюдавшиеся примеры:

- `Job01_BlinkStrike_Standard`
- `Job01_FullMoonSlash`
- `Job01_HindsightSlash`
- `Job01_ViolentStab`
- `Job01_NormalAttack`
- `Job01_SkillAttack`
- `Job01_SubNormalAttack`

##### `main_pawn Job07`

Подтверждено CE dumps и burst traces:

- `current_job = 7`
- `Job07ActionCtrl` жив и через `field`, и через `getter`
- primary decision module - `app.DecisionEvaluationModule`
- `DecisionExecutor` жив
- `ExecutingDecision` жив
- боевая цель может быть `app.Character`
- runtime остается в generic carrier families вместо подтвержденного перехода в `Job07_*` combat families

Наблюдавшиеся generic carriers:

- `Common/MoveToPosition_Walk_Target.user`
- `ch1_Move_Run_Target.user`
- `Common/InForcedAnimation.user`
- `Locomotion.NormalLocomotion`
- `Locomotion.Strafe`
- `Damage.*`

Не подтверждено для `main_pawn Job07`:

- стабильный `Job07_*` pack
- стабильный `Job07_*` node

##### `Sigurd Job07`

Валидные контрольные `Sigurd` traces уже существуют.

Подтверждено:

- `Sigurd` входит в реальные `Job07`-specific NPC packs
- `Sigurd` входит в реальные `Combat.Job07_*` node families
- primary decision module - `app.ThinkTableModule`
- `DecisionExecutor` и `ExecutingDecision` отсутствуют в наблюдаемом `Sigurd Job07` pipeline

Примеры pack:

- `ch300_job07_SideWalkB_Blade4`
- `ch300_job07_SideWalkR_Blade4`
- `ch300_job07_SkyDive`
- `ch300_job07_MagicBindLeap`
- `ch300_job07_SpiralSlash`

Примеры node:

- `Job07_ShortRangeAttack`
- `Job07_MagicBindJustLeap`
- `Job07_MagicBindComplete`
- `Job07_SkyDive`
- `Job07_SkyDiveLanding`
- `Job07_SpiralSlash`

##### Архитектура decision pipeline

Точечные CE compares теперь показывают структурный разрыв:

- `main_pawn Job07` идет через pawn pipeline `app.DecisionEvaluationModule`
- `Sigurd Job07` идет через NPC pipeline `app.ThinkTableModule`
- `ThinkTableModule` не найден рядом с наблюдаемой decision chain у `main_pawn` в протестированных сценах
- прежний вопрос про `selector / admission / context` теперь уже сужен до вопроса о pawn-specific decision content или decision output

##### Боевая популяция `MainDecisions`

Точечные боевые captures теперь показывают второй, более сильный разрыв уже внутри pawn pipeline:

- вне боя selected-job-only snapshots еще могут выглядеть одинаково между `main_pawn Job01` и `main_pawn Job07`
- в бою `main_pawn Job01` повторяемо показывает `42` `MainDecisions`
- в бою `main_pawn Job07` повторяемо показывает только `11` `MainDecisions`
- по повторным captures у `main_pawn Job07` нет уникальных боевых `scalar_profile` или `combined_profile`
- наблюдаемые боевые `main_pawn Job07` `MainDecisions` являются строгим подмножеством боевых `main_pawn Job01` `MainDecisions`
- значит оставшийся blocker уже виден внутри боевой популяции решений pawn `DecisionEvaluationModule`

##### Семантический боевой разрыв внутри `MainDecisions`

Семантический compare усиливает тот же вывод:

- повторные semantic captures показывают `main_pawn Job01` на уровне `47-48` боевых `MainDecisions`
- повторные semantic captures показывают `main_pawn Job07` на уровне `11` боевых `MainDecisions`
- `main_pawn Job07` не дает ни одной уникальной боевой `semantic_signature`; все наблюдаемые `Job07` semantic signatures уже присутствуют у `Job01`
- сохраненный боевой слой `Job07` доминируется common/generic utility-поведением: movement, carry, talk, catch, cliff, keep-distance
- в этих боевых captures у `main_pawn Job07` все еще не наблюдаются `Job07_*` action-pack identities
- `main_pawn Job01` содержит много дополнительных attack-oriented packs и behavior, которые не доживают до боевого `Job07`, включая множественные `Job01_Fighter/*` packs и несколько `GenericJob/*Attack*` packs
- у сокращенного боевого слоя `Job07` также пропадает значительная часть более богатой популяции `EvaluationCriteria`, `TargetConditions` и start/end-process c `SetAttackRange`, которая есть у боевого `Job01`

#### Усиленные выводы

Эти выводы сейчас сильные:

- блокер не объясняется отсутствием `Job07ActionCtrl`
- блокер не объясняется отсутствием decision state
- `Job07` content существует и работает в движке
- текущий разрыв специфичен для `main_pawn`
- `main_pawn Job07` и `Sigurd Job07` не используют одну и ту же primary decision architecture
- `main_pawn Job07` использует `app.DecisionEvaluationModule`
- `Sigurd Job07` использует `app.ThinkTableModule`
- текущий разрыв теперь лучше объясняется как gap в pawn decision-pipeline, а не только как generic selector/admission surface gap
- в бою `main_pawn Job07` недонаселен до action output, а не только misrouted после selection
- наблюдаемые боевые `main_pawn Job07` `MainDecisions` являются строгим подмножеством боевых `main_pawn Job01` `MainDecisions`
- наблюдаемый боевой semantic layer у `main_pawn Job07` остается generic/common-heavy и не показывает подтвержденного `Job07` attack-oriented decision cluster
- timed combat output bursts теперь закрывают следующий bridge-step:
- стабильные боевые burst-срезы `Job01` показывают `attack_populated` decision state, который в основном уходит в `job_specific_output_candidate`, включая `Job01_*` actions, `Job01_*` FSM nodes и attack-oriented `decision_pack_path`
- стабильный боевой burst у `Job07` все еще показывает только `11` `MainDecisions`, `current_job_pack_count=0`, `generic_attack_pack_count=0`, utility-only pack identities и `common_utility_output` вроде `Strafe`, `NormalLocomotion` и `Common/MoveToPosition_Walk_Target`
- значит отсутствующее боевое поведение теперь прослежено до output surfaces, а не только выведено из differences в decision population

#### Ослабленные или отвергнутые выводы

Эти старые выводы больше не активны:

- "`Job07` отсутствует у `main_pawn`"
- "`ce_dump=nil` доказывает отсутствие `Job07ActionCtrl`"
- "`target kind mismatch` всегда является корнем проблемы"
- "`getter` сам по себе доказывает живой attack path"

#### Текущая сильнейшая гипотеза

Текущая рабочая гипотеза:

- `main_pawn Job07` не ломается внутри NPC `ThinkTableModule` path, потому что в наблюдаемых сценах он вообще не использует этот path
- боевой content pawn `DecisionEvaluationModule` для `Job07` не просто отличается; он недонаселен относительно боевого `Job01`
- следующий вопрос - какие именно отсутствующие attack-oriented боевые `MainDecisions` соответствуют потерянному `Job07` combat behavior и как это сокращение доходит до evaluation output или action output
- самые сильные локальные кандидаты сейчас - отсутствующие `Job01_Fighter/*`, `GenericJob/*Attack*` и `SetAttackRange`-bearing combat decisions, которые присутствуют у боевого `Job01`, но не появляются у боевого `Job07`

#### Поверхность определений профессий

`vocation_definition_surface_20260326_195656.json` подтверждает, что через CE Console мы можем вытаскивать не только actor или NPC snapshots, но и реальную class-definition surface профессий.

- `app.HumanCustomSkillID` теперь дает подтвержденные hybrid custom-skill bands:
- `Job07 = 70..79`
- `Job08 = 80..91`
- `Job09 = 92..99`
- `Job10 = 100`
- `app.HumanAbilityID` также дает подтвержденные hybrid ability bands:
- `Job07 = 34..38`
- `Job08 = 39..43`
- `Job09 = 44..48`
- `Job10 = 49..50`
- `Job07Parameter` раскрывает реальные боевые поверхности вроде `NormalAttackParam`, `HeavyAttackParam`, `MagicBindParam`, `SpiralSlashParam`, `SkyDiveParam`, `DragonStingerParam`, `FarThrowParam`, `EnergyDrainParam` и `DanceOfDeathParam`
- `Job08Parameter` раскрывает `NormalAttackParam`, `FlameLanceParam`, `BurningLightParam`, `FrostBlockParam`, `ThunderChainParam`, `CounterArrowParam`, `SeriesArrowParam` и `SpiritArrowParam`
- `Job09Parameter` раскрывает `_NormalAttackParam`, `_ThrowSmokeParam`, `_SmokeDecoyParam`, `_DetectFregranceParam` и `_AstralBodyParam`
- `Job10Parameter` пока показывает только `Job10_00Param`
- `Job07`, `Job08` и `Job09` имеют живые `InputProcessor`, `ActionController` и `ActionSelector`, тогда как у `Job10` наблюдаются controller и selector surfaces, но не наблюдается `Job10InputProcessor`
- `Job07InputProcessor` и `Job07ActionSelector` уже показывают конкретные точки входа вроде `processMagicBind`, `processNormalAttack`, `processSpiralSlash`, `processCustomSkill`, `getCustomSkillAction`, `getNormalAttackAction` и `requestActionImpl`
- `Job08` и `Job09` тоже показывают конкретные job-specific `processCustomSkill` и normal-attack selector surfaces, так что профили для `08` и `09` можно строить уже не вслепую
- исходные профессии тоже дают сильный control baseline:
- у `Job01` through `Job06` в captured `vocation_definition_surface` стабильно читаются `AbilityParam` bands без неоднозначности:
- `Job01 = 4..8`
- `Job02 = 9..13`
- `Job03 = 14..18`
- `Job04 = 19..23`
- `Job05 = 24..28`
- `Job06 = 29..33`
- `Job01` through `Job06` также показывают богатые parameter-family surfaces, которые помогают отличать реальные боевые families от custom-skill families:
- `Job01`: `NormalAttack`, `TuskToss`, `Guard`, `BlinkStrike`, `ViolentStab`, `HindsightSlash`, `FullMoonGuard`, `ShieldCounter`, `DivineDefense`
- `Job02`: bow и arrow families вроде `NormalArrow`, `FullBend`, `QuickLoose`, `Threehold`, `Triad`, `MeteorShot`, `AcrobatShot`, `WhirlingArrow`, `FullBlast`
- `Job03`: staff или spell families вроде `Anodyne`, `FireStrom`, `Levin`, `Frigor`, `GuardBit`, `HolyShine`, `CureSpot`, `HasteSpot`, `Boon`, `Enchant`
- `Job04`: dagger или rogue families вроде `_NormalAttack`, `_LoopAttack`, `_Pickpocket`, `_CuttingWind`, `_Guillotine`, `_ParryCounter`, `_AbsoluteAvoidance`, `_Stealth`
- `Job05`: greatsword families вроде `NormalAttack`, `ChargeNormalAttack`, `HeavyAttack`, `CrescentSlash`, `GroundDrill`, `WarCry`, `IndomitableLash`, `CycloneSlash`, `ArcOfObliteration`
- `Job06`: sorcerer families вроде `_NormalAttack`, `_RapidShot`, `_Salamander`, `_Blizzard`, `_MineVolt`, `_SaintDrain`, `_MeteorFall`, `_VortexRage`
- off-job доступ к `SkillContext` сильный: и `player`, и `main_pawn` показывают per-job equip lists для `Job07` through `Job10`, даже если в момент capture они были не на этих профессиях
- эта off-job visibility не является чем-то сугубо hybrid-specific: даже когда в recorded snapshot `player = Mage`, а `main_pawn = Fighter`, live skill scan всё равно показывает enabled или level-positive entries по `Job01` through `Job08`, включая `Job01_BlinkStrike`, `Job02_ThreefoldArrow`, `Job03_Firestorm`, `Job04_CuttingWind` и `Job05_CrescentSlash`
- это значит, что движок готов раскрывать широкое cross-job progression state без фактического переключения актёра на нужную профессию, поэтому в будущих progression tools исходные профессии нужно использовать как control group, а не как “чужой” контент
- в записанном snapshot и `player`, и `main_pawn` имели `Job07 slot0 = Job07_DragonStinger`, `Job08 slot0 = Job08_FrostTrace`, а `Job09` и `Job10` были пустыми
- `SkillAvailability` в этом snapshot остался unresolved, тогда как `SkillContext` и `CustomSkillState` были живыми, значит runtime-gating лучше опирать на `SkillContext`, per-job equip lists, `hasEquipedSkill(...)`, `isCustomSkillEnable(...)` и `getCustomSkillLevel(...)`
- `SkyDive` подтвержден как custom skill `76`
- `SpiralSlash` присутствует в `Job07Parameter` и `Job07InputProcessor`, но отсутствует в `app.HumanCustomSkillID`; пока не появится противоположное CE evidence, его правильно считать core или non-custom move, а не custom-skill gate
- `Job10` структурно особый и должен идти отдельной implementation track, когда runtime bridge будет расширяться с `Job07` на `Job08` through `Job10`
- два caution signal из live skill scan тоже стоит сохранить:
- placeholder-like `None` entry всё ещё может появляться как enabled с `level = 1`
- `Job01_BravesRaid` в этом snapshot появлялся как enabled без явного equipped-job list
- значит live skill scan очень полезен, но любой progression reader всё равно должен фильтровать placeholder rows и не считать, что `enabled = true` всегда автоматически означает чистый equipped-slot origin

#### Матрица прогрессии профессий

`vocation_progression_matrix_20260326_214421.json` подтверждает, что новый progression-oriented extractor уже может разделять несколько слоев, которые раньше смешивались.

- `Job07` теперь раскладывается достаточно чисто:
- base или core families: `CustomSkillLv2`, `Flow`, `HeavyAttack`, `JustLeap`, `MagicBind`, `NormalAttack`, `SpiralSlash`
- custom-skill families: `BladeShoot`, `DanceOfDeath`, `DragonStinger`, `EnergyDrain`, `FarThrow`, `Gungnir`, `PsychoShoot`, `QuickShield`, `SkyDive`, `TwoSeconds`
- `Job08` тоже раскладывается достаточно чисто:
- base или core families: `AimArrow`, `Effect`, `JustRelease`, `NormalAttack`, `RemainArrow`
- custom-skill families: `AbsorbArrow`, `BurningLight`, `CounterArrow`, `FlameLance`, `FrostBlock`, `FrostTrace`, `LifeReturn`, `ReflectThunder`, `SeriesArrow`, `SleepArrow`, `SpiritArrow`, `ThunderChain`
- `Job09` пока не маппится так же чисто через enum-name heuristic; его parameter families всё ещё выглядят как smoke, fragrance, possession, decoy и astral groups, значит для `Job09` нужен отдельный family mapping, а не прямой enum-name join
- `Job10` на этом уровне всё ещё остаётся opaque; наблюдаемая parameter family surface пока сводится только к `Job10_00`
- live off-job progression state в этом snapshot совпадает и у `player`, и у `main_pawn`:
- `Job07_DragonStinger` стоит в экипировке, включён и показывает `level = 1`
- `Job08_FrostTrace` стоит в экипировке, включён и показывает `level = 1`
- активных `Job09` или `Job10` custom skills в этом snapshot не наблюдалось
- в live `AbilityContext` snapshot для обоих акторов не наблюдалось экипированных hybrid augments или abilities
- `current_job_level` и per-hybrid `getJobLevel(...)` у обоих записанных акторов остались `nil`, значит прямые runtime reads уровня всё ещё ненадёжны и не должны жёстко блокировать базовые атаки или level-0 fallback phases
- первый прогон progression-matrix выявил новое правило чтения для hybrid augment data: `AbilityParam.JobAbilityParameters` ведёт себя как коллекция с индексом `job_id - 1`, поэтому прямое индексирование по `job_id` сдвигает `Job07` на `Job08`, `Job08` на `Job09` и так далее
- из-за этой indexing hazard первый progression-matrix JSON уже надёжен для base/core families и custom-skill state, но per-job hybrid augment matrix нужно переснять после фикса extractor, прежде чем считать её канонической

#### Подтвержденное направление реализации

Следующий шаг теперь уже не blind pack guessing.

- держать diagnosis по decision-pipeline как основное объяснение проблемы `main_pawn Job07`
- использовать extracted class-definition surface для построения progression-aware hybrid profiles
- рассматривать `Job07` как первый grounded profile:
- core phases могут опираться на подтвержденные non-custom surfaces вроде `SpiralSlash`
- custom-skill phases должны опираться на подтвержденные ids вроде `SkyDive = 76`
- ту же profile architecture нужно расширять на `Job08` и `Job09`, а `Job10` вести как отдельный structural case

#### Архив удаленного research layer

Старый research layer удален из продуктового hot path.

Архивированные домены:

- orchestration: `app/module_specs.lua`, `app/runtime_driver.lua`, `core/module_system.lua`
- logging and traces: старый `core/log.lua`, session logs, discovery logs, guild trace logs
- research modules: `action_research`, `combat_research`, `loadout_research`, `pawn_ai_data_research`, `guild_flow_research`, `sigurd_observer`, `npc_spawn_prototype`, `talk_event_trace`
- progression probes: `game/progression/trace.lua`, `probe.lua`, `correlation.lua`
- synthetic и adapter layer
- runtime debug UI

Остаточная полезная ценность старых логов перед удалением:

- оставшиеся session logs от `2026-03-25` подтверждают, что `main_pawn Job07` мог дойти до правильного hybrid runtime surface (`main_pawn_job=7`, `main_pawn_weapon_job=7`) и все равно оставаться в common runtime output вроде `NormalLocomotion`, `DrawWeapon` и `Common/Common_MoveToHighFive.user`
- в одной записанной `Job07` session сохранялся живой current-job loadout `73,0,0,0`, но output все равно оставался generic/common; значит сбой не объяснялся полной пустотой видимого custom-skill state
- старые discovery/action-research hooks давали высокий hook volume, но низкий payload yield: даже при повторных `actinter_requests` можно было получать `decision_probe_hits=0`, `decision_snapshot_hits=0` и `decision_actionpack_snapshot_hits=0`
- этот исторический сигнал поддерживает текущее правило CE-first: старые логи стоит держать только как archived evidence, а не как diagnostic path по умолчанию

Правило возврата:

- возвращать только один конкретный механизм и только после того, как CE scripts докажут, что narrowed question нельзя решить без hooks

#### Граница производительности и сети

Все еще действующие правила:

- предпочитать компактные summaries широким reflective scans
- избегать getter-heavy probing в продуктовом hot path
- держать core branch local-runtime-first
- не вносить online, rental и pawn-share logic в main implementation branch

#### Архивный ручной Content Editor path

Старый ручной путь через `Content Editor` сохранен как reference, а не как путь по умолчанию.

Его главные targets:

- `AI Overview`
- `app.PawnBattleController._BattleAIData`
- `app.PawnOrderController.OrderData`
- `app.PawnUpdateController.AIGoalActionData`
- `app.goalplanning.AIGoalCategoryJob._JobDecisions`
- blackboard collections
- `CharacterManager:get_HumanParam() -> app.Job07Parameter`

Статус:

- полезен как bounded manual fallback
- не является путем по умолчанию, пока CE Console scripts отвечают на активные вопросы

### Как сделать

#### Как исследовать сейчас

Использовать CE Console scripts.

Стандартный цикл:

1. сформулировать один конкретный вопрос
2. выбрать один скрипт под этот вопрос
3. записать результат в файл
4. сравнить его с baseline или control actor
5. сначала обновить этот файл
6. обновить `ROADMAP.md` только если изменились приоритеты
7. обновить `CHANGELOG.md`, если изменились код или документация

#### Как оценивать силу вывода

Вывод достаточно силен для этого файла только если:

- скрипт записал структурированный результат в файл
- результат воспроизводим
- формулировка прямо следует из записанных полей
- конфликтующие старые формулировки удалены или явно ослаблены

#### Как решать, можно ли вернуть hooks

Не возвращаться к hooks по умолчанию.

Возврат допустим только если одновременно выполнены условия:

- вопрос уже сужен до одного runtime transition
- screen и burst CE scripts не ловят его
- без hooks нельзя доказать причину
- необходимость задокументирована до начала реализации
- product branch остается изолированным от широкого research logging

### Справка

#### Активные CE scripts

- `docs/ce_scripts/job07_runtime_resolution_screen.lua`
- `docs/ce_scripts/job07_burst_combat_trace.lua`
- `docs/ce_scripts/actor_burst_combat_trace.lua`
- `docs/ce_scripts/job07_selector_admission_compare_screen.lua`
- `docs/ce_scripts/vocation_definition_surface_screen.lua`
- `docs/ce_scripts/vocation_progression_matrix_screen.lua`

#### Обязательные свойства CE script

Каждый CE script должен:

- решать одну конкретную задачу
- писать результат в файл
- выдавать данные, пригодные для compare и дальнейшего обновления документации

#### Текущие implementation files

- `mod/reframework/autorun/PawnHybridVocationsAI/bootstrap.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/discovery.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/main_pawn_properties.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/progression/state.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_unlock.lua`

#### Исторические native decision-pool signals

Ранний native-first branch многократно использовал эти containers как безопасные структурные сигналы:

- `_CurrentGoalList`
- `_CurrentAddDecisionList`
- `MainDecisions`
- `PreDecisions`
- `PostDecisions`
- `ActiveDecisionPacks`

Они остаются полезной исторической справкой, даже если текущий путь исследования теперь CE-first.

#### Дополнение 2026-03-26: hybrid custom-skill matrix

Это короткое дополнение фиксирует выводы из `vocation_progression_matrix_20260326_214421.json`, которые полезны даже вне текущей задачи.

- Полная подтверждённая hybrid `custom-skill` matrix сейчас выглядит так:
- Полная подтверждённая all-job `custom-skill` bands сейчас выглядят так:
- `Job01 = 1..12`, `Job02 = 13..23`, `Job03 = 24..37`, `Job04 = 38..49`, `Job05 = 50..61`, `Job06 = 62..69`, `Job07 = 70..79`, `Job08 = 80..91`, `Job09 = 92..99`, `Job10 = 100`
- `Job07`: `70 = PsychoShoot`, `71 = FarThrow`, `72 = EnergyDrain`, `73 = DragonStinger`, `74 = QuickShield`, `75 = BladeShoot`, `76 = SkyDive`, `77 = Gungnir`, `78 = TwoSeconds`, `79 = DanceOfDeath`
- `Job08`: `80 = FlameLance`, `81 = BurningLight`, `82 = FrostTrace`, `83 = FrostBlock`, `84 = ThunderChain`, `85 = ReflectThunder`, `86 = AbsorbArrow`, `87 = LifeReturn`, `88 = CounterArrow`, `89 = SleepArrow`, `90 = SeriesArrow`, `91 = SpiritArrow`
- `Job09`: `92 = SmokeWall`, `93 = SmokeGround`, `94 = TripFregrance`, `95 = AttentionFregrance`, `96 = PossessionSmoke`, `97 = RageFregrance`, `98 = DetectFregrance`, `99 = SmokeDragon`
- `Job10`: `100 = Job10_00`
- Canonical data-layer для этой матрицы теперь лежит в `mod/reframework/autorun/PawnHybridVocationsAI/data/vocation_skill_matrix.lua`
- Для `Job07` первым live-grounded custom skill теперь надо считать `DragonStinger = 73`: он подтверждён в enum, в `Job07Parameter`, и в live equip/enabled state у `player` и `main_pawn`
- Для `Job08` аналогичным первым live-grounded custom skill сейчас является `FrostTrace = 82`
- `current_job_level` и per-job `getJobLevel(...)` по-прежнему могут оставаться `nil`, поэтому жёстко гейтить базовые атаки по этому сигналу нельзя
- `AbilityParam.JobAbilityParameters` нужно читать с приоритетом `job_id - 1`, иначе hybrid augment layer сдвигается на одну профессию

#### Контракты исполнения и unsafe skill probes

Теперь runtime bridge должен знать не только `skill id`, но и контракт исполнения каждого навыка.

- `skill id` отвечает на вопрос, что это за навык
- `execution contract` отвечает на вопрос, как его можно безопасно запускать
- рабочие категории сейчас выглядят так:
- `direct_safe`
- `carrier_required`
- `controller_stateful`
- `selector_owned`
- каноническая all-job матрица теперь хранит `execution_contract` placeholder для каждого custom skill от `Job01` до `Job10`
- этот placeholder специально консервативный: пока CE или runtime не заземлят навык, он остаётся в данных как `selector_owned`
- `Job07` теперь стал первым профилем, где контракты уже явно живут в коде, а не только в документации:
- базовые direct action вроде `Job07_ShortRangeAttack` моделируются как `direct_safe`
- carrier-backed core-фазы вроде `MagicBindLeap` и `SpiralSlash` моделируются как `carrier_required`
- `DragonStinger` моделируется как `controller_stateful` и остаётся в probe-режиме, пока не станет понятен нужный ему native context
- runtime bridge теперь резолвит класс контракта и `bridge_mode` из данных фазы, а не опирается только на россыпь специальных флагов вроде `unsafe_direct_action`
- session-логи теперь пишут `contract` и `bridge_mode` у применённых и упавших фаз, чтобы результаты probe можно было быстрее переводить обратно в обычные runtime-правила
- нормализация контрактов теперь живёт в отдельном shared runtime-модуле, так что matrix, profile builder и bridge больше не держат три разные частичные версии одной и той же логики
- probe-snapshot теперь тоже контрактно-управляемый: stateful skills могут объявлять `controller_state_fields`, а runtime пишет именно эти поля из соответствующего `JobXXActionCtrl` вместо жёстко прошитого `Job07`-только пути
- `DragonStinger` стал первым подтверждённым доказательством, что это различие реально важно:
- прямой `requestActionCore("Job07_DragonStinger")` смог довести `main_pawn` до видимой `Job07_*` анимации
- но затем игра упала внутри `app.Job07DragonStinger.update`
- CE surface при этом показывает отдельный `Job07ActionCtrl` state именно для этого навыка: `DragonStingerVec`, `DragonStingerSpeed` и `DragonStingerHit`
- значит `DragonStinger` нельзя считать “обычным direct action skill” только потому, что он один раз стартовал
- текущий runtime теперь ведёт его как probe-gated unsafe-skill path, а не как окончательно решённый direct-action путь
- текущие probe-режимы такие:
- `off`
- `action_only`
- `carrier_only`
- `carrier_then_action`
- probe-логи теперь снимают текущий output и состояние `Job07ActionCtrl` до попытки unsafe skill
- этот же шаблон дальше надо расширять с `Job07` на всю vocation matrix, включая исходные профессии, чтобы мод классифицировал навыки по execution contract, а не только по имени action
- выбор фаз теперь system-first, а не skill-first:
- raw `priority` каждого навыка сохраняется
- но больше не является единственным селектором
- итоговый phase score теперь учитывает роль фазы, дистанцию, safe fallback при assumed job level, повторы и недавний skill streak
- это нужно, чтобы пешка не спамила навык с самым высоким приоритетом и выглядела нативно за счёт обычных атак, engage-мувов, gap-close и уже потом skill follow-up

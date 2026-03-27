# KNOWLEDGE_BASE

## English

### Reading guide

This file is now meant to be read in three layers:

1. invariants and current conclusions
2. structured catalogs with provenance, purpose, and general use
3. historical narrative and archive notes

Catalog rule:

- if an identifier is important enough to influence design, runtime behavior, or research workflow, it should appear in a structured catalog entry somewhere in this file
- narrative sections may still mention the same identifier, but the catalog entry is the place that defines what it is and where it came from

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
- `game/main_pawn_properties.lua`
- `game/progression/state.lua`
- `game/hybrid_unlock.lua`
- `game/hybrid_combat_fix.lua`

The product runtime currently does four important things:

1. resolves `player` and `main_pawn`
2. reads progression and job-bit state
3. restores the actual hybrid unlock path for `main_pawn`
4. runs the combat bridge for hybrid vocations

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

#### External research tooling

Research is now intentionally externalized.

Use these tools instead of reintroducing product-runtime discovery code:

- `Content Editor` as the primary live inspection tool:
- `ce_find(...)`
- `ce_dump(...)`
- AI overview and blackboard viewers
- `DD2_DataScraper` as the primary one-shot export tool for bulk data snapshots
- `Nick's Devtools` and `_NickCore` only as dev-only live tracers, never as product-runtime dependencies
- `Skill Maker` as a reference catalog for action names, skill metadata, and user-facing skill datasets

Policy:

- `mod/` must not ship broad discovery, recursive graph scans, or hook-heavy research utilities
- live research belongs in `docs/ce_scripts/` or external tool mods
- if a question can be answered by `Content Editor` or `DD2_DataScraper`, do not add a new runtime probe to the product mod
- skip-reason logs and target-source probe logs should stay off by default in product runtime; if they are needed again, enable them only temporarily for a narrowed question

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
- phase choice has been rolled back to `priority-first`
- raw per-skill `priority` is again the actual selector order
- execution contracts remain useful, but only as the execution layer after a phase is chosen
- `assumed_minimum_job_level` should not hard-block higher-level phases, because it only means the runtime failed to read the real level and should not silently collapse the candidate set
- custom-skill gating should therefore be driven primarily by precomputed skill lifecycle state, not by combat-time guesses: `potential -> unlockable -> learned -> equipped -> combat_ready`

#### Latest runtime stabilization note

The latest `Job07` runtime session adds one more grounded conclusion.

- the bridge is already capable of entering several real `Job07` actions before the stall, including `Job07_BladeShoot`, carrier-backed `ch300_job07_Run_Blade4`, `Job07_MagicBindJustLeap`, and `Job07_ShortRangeAttack`
- the next blocker is therefore no longer best described as pure phase-selection failure
- the same session exposed a diagnostics bug: blocked-phase summaries were dropping execution-contract metadata and could falsely print `selector_owned` even for `direct_safe`, `carrier_required`, or `controller_stateful` phases
- the same session also exposed a runtime stability issue: several hot paths were still trying `via.Component.get_GameObject`, and REFramework logs those internal exceptions even when Lua catches the method call
- because of that, field-backed `GameObject` resolution is now the preferred hot-path rule for combat target resolution and actor-state collection
- the next runtime correction is therefore not more `Job07` admission theory but a return to the already grounded execution-contract solution: keep `carrier_required` phases on the carrier bridge, keep direct `requestActionCore(...)` as the `direct_safe` path only, and stop treating raw action forcing as the universal answer
- the live bridge now uses a short-lived enemy target cache plus throttled secondary target scans so one-frame `ExecutingDecision` oscillation no longer ejects `carrier_required` phases before the pack bridge can fire
- fresh `Job07` target-publication bursts now sharpen the next runtime gate: enemy target can stay live through `ExecutingDecision` or `_EnemyList` while output temporarily sits in `Damage.DmgShrink*`, so the bridge must admit a narrow damage-recovery window instead of allowing entry only from locomotion or utility-like output
- the next two sessions after that fix were almost empty and only recorded bootstrap, which means the runtime was still leaving before phase logging and the remaining blind spot moved to early skip paths rather than to phase execution itself
- because of that, the runtime now also emits throttled skip telemetry for silent exits such as unresolved context, non-utility output, unresolved target, unresolved target `GameObject`, or unresolved bridge context
- comparing the attacking `2026-03-26 22:58:44` session against the stalled `2026-03-26 23:27:31` session shows that the current blocker is target acquisition rather than action execution: the later run no longer holds a stable enemy target and flips between `self`-targeted and unresolved target surfaces before any phase can fire
- because of that, combat target diagnosis now probes `ExecutingDecision`, `AIBlackBoardController`, `HumanActionSelector`, `CommonActionSelector`, `OrderTargetController`, and `JobXXActionCtrl` separately and logs each source instead of collapsing everything into one selector root

#### Последняя заметка по стабилизации runtime

Последний runtime-session для `Job07` добавил ещё один заземлённый вывод.

- bridge уже способен доходить до нескольких реальных `Job07` действий до момента затупа, включая `Job07_BladeShoot`, carrier-backed `ch300_job07_Run_Blade4`, `Job07_MagicBindJustLeap` и `Job07_ShortRangeAttack`
- значит следующий блокер теперь уже нельзя лучше всего описывать как чистый сбой phase selection
- тот же session-log вскрыл дефект диагностики: blocked-phase summary теряла metadata execution contract и могла ложно писать `selector_owned` даже для фаз с контрактами `direct_safe`, `carrier_required` или `controller_stateful`
- тот же session-log также показал проблему runtime-stability: несколько hot paths всё ещё пытались звать `via.Component.get_GameObject`, а REFramework всё равно пишет такие internal exception в log, даже если Lua ловит сам вызов
- поэтому field-backed resolution `GameObject` теперь считается правильным hot-path правилом для combat target resolution и actor-state collection
- следующие два session-log после этого фикса оказались почти пустыми и сохранили только bootstrap, а значит runtime всё ещё выходил раньше phase logging и оставшаяся слепая зона теперь сидит в early skip paths, а не в самой phase execution
- поэтому runtime теперь ещё и пишет throttled skip telemetry для тихих выходов вроде unresolved context, non-utility output, unresolved target, unresolved target `GameObject` или unresolved bridge context

#### Runtime target follow-up / Дополнение по target

- English: the successful `2026-03-26 22:58:44` session still had one stable enemy target, while the stalled `2026-03-26 23:27:31` session had no stable enemy target and alternated between `self` and `nil`
- Русский: успешный session `2026-03-26 22:58:44` ещё держал одну стабильную enemy target, а stalled session `2026-03-26 23:27:31` уже не удерживал врага и переключался между `self` и `nil`
- English: runtime target diagnosis now logs `ExecutingDecision`, `AIBlackBoardController`, `HumanActionSelector`, `CommonActionSelector`, `OrderTargetController`, and `JobXXActionCtrl` separately so target regressions can be traced before phase execution
- Русский: теперь runtime-диагностика по target логирует `ExecutingDecision`, `AIBlackBoardController`, `HumanActionSelector`, `CommonActionSelector`, `OrderTargetController` и `JobXXActionCtrl` по отдельности, чтобы target regression было видно ещё до phase execution
- English: old CE compare captures already showed a useful asymmetry for `main_pawn Job07`: `ExecutingDecision.Target` was live while `AIBlackBoard`, `HumanActionSelector`, and `Job07ActionCtrl` target surfaces were still `nil`, so selector-facing roots should not be treated as the primary historical target contract
- Русский: старые CE compare-слепки уже показали полезную асимметрию для `main_pawn Job07`: живым был именно `ExecutingDecision.Target`, а target-поверхности `AIBlackBoard`, `HumanActionSelector` и `Job07ActionCtrl` оставались `nil`, поэтому selector-facing roots нельзя считать нашим основным историческим target contract
- English: the same older CE and git research also exposed `LockOnCtrl`, `AIMetaController`, and cached pawn controllers such as `CachedPawnOrderTargetController`, so these are now the most grounded secondary target roots to restore before probing wider battle/request surfaces
- Русский: те же старые CE и git-данные также подтвердили `LockOnCtrl`, `AIMetaController` и cached pawn controllers вроде `CachedPawnOrderTargetController`, поэтому именно их теперь правильно возвращать как самые grounded secondary target roots до расширения поиска в более широкие battle/request surfaces
- English: the older relevant combat session still showed one grounded fact: `executing_decision_target` could already expose a valid `via.GameObject` while the chosen character still resolved to `self`, so target identity remained a confirmed blocker at least for that build
- Русский: старый релевантный боевой session всё же дал один grounded-факт: `executing_decision_target` уже мог нести валидный `via.GameObject`, а выбранным персонажем всё равно оставалась сама пешка, так что для той сборки target identity точно был подтверждённым блокером
- English: however, later runtime patches replaced several hot-path `get_GameObject` calls with field-backed `resolve_game_object(..., false)` resolution, so newer `re2_framework_log.txt` sessions can no longer be used as a clean negative test for the `via.Component.get_GameObject` hypothesis
- Русский: однако последующие runtime-правки заменили несколько hot-path вызовов `get_GameObject` на field-backed `resolve_game_object(..., false)`, поэтому более новые `re2_framework_log.txt` уже нельзя использовать как чистый негативный тест для гипотезы про `via.Component.get_GameObject`
- English: `docs/ce_scripts/main_pawn_target_surface_screen.lua` now exists as a focused CE Console extractor for target-bearing roots, writing `main_pawn_target_surface_<timestamp>.json` with `ExecutingDecision`, `LockOnCtrl`, `AIMetaController`, cached pawn controllers, selectors, `JobXXActionCtrl`, `CurrentAction`, and `SelectedRequest`
- Русский: теперь есть `docs/ce_scripts/main_pawn_target_surface_screen.lua` как узкий CE Console extractor для target-bearing roots; он пишет `main_pawn_target_surface_<timestamp>.json` и снимает `ExecutingDecision`, `LockOnCtrl`, `AIMetaController`, cached pawn controllers, selectors, `JobXXActionCtrl`, `CurrentAction` и `SelectedRequest`
- English: three fresh `main_pawn_target_surface` captures added a stronger comparison point: both `Job07` and `Job01` can expose a valid enemy directly through `ExecutingDecision.<Target>.<Character>`, while `LockOnCtrl`, `AIBlackBoard.Target`, selectors, and `JobXXActionCtrl.Target` still stay empty in the same samples
- Русский: три свежих `main_pawn_target_surface` слепка добавили более сильную точку сравнения: и `Job07`, и `Job01` могут показывать валидного врага напрямую через `ExecutingDecision.<Target>.<Character>`, а `LockOnCtrl`, `AIBlackBoard.Target`, selectors и `JobXXActionCtrl.Target` в тех же samples остаются пустыми
- English: those same captures also show that `app.PawnOrderTargetController` is not actually empty; it carries `_EnemyTargetNum`, `_EnemyList`, `_FrontTargetList`, `_InCameraTargetList`, and `_SensorHitResult`, which means the controller is target-bearing through collections rather than through a plain `Target` field
- Русский: те же слепки также показали, что `app.PawnOrderTargetController` на самом деле не пустой; он несёт `_EnemyTargetNum`, `_EnemyList`, `_FrontTargetList`, `_InCameraTargetList` и `_SensorHitResult`, а значит этот контроллер target-bearing именно через collections, а не через обычное поле `Target`
- English: because of that, the runtime target fallback now needs collection-based extraction from `PawnOrderTargetController`, not only more `Target/CurrentTarget/OrderTarget` probing
- Русский: из-за этого runtime fallback по target теперь должен уметь collection-based extraction из `PawnOrderTargetController`, а не только всё глубже опрашивать `Target/CurrentTarget/OrderTarget`
- English: inference: the latest game-side session log still does not print `ai_meta_controller` or cached-controller probes, which suggests the game run was likely using an older synced mod build than the current local target-root patch
- Русский: inference: последний game-side session-log всё ещё не печатает `ai_meta_controller` или cached-controller probes, а значит этот запуск, вероятно, шёл на более старой синхронизированной сборке мода, чем текущий локальный target-root patch
- English: the next `Job07` target-surface triplet (`2026-03-27 00:22:52`, `00:22:55`, `00:22:58`) refined the same picture: `ExecutingDecision` oscillated between `self` and a real enemy, `PlayerOfAITarget` consistently resolved the player plus owner-self pair, and selector-facing roots still stayed empty
- Русский: следующий `Job07` target-surface-триплет (`2026-03-27 00:22:52`, `00:22:55`, `00:22:58`) уточнил ту же картину: `ExecutingDecision` переключался между `self` и реальным врагом, `PlayerOfAITarget` стабильно резолвил пару `player + owner-self`, а selector-facing roots всё ещё оставались пустыми
- English: those same captures also reveal the concrete collection item types inside `PawnOrderTargetController`: `_EnemyList -> via.GameObject`, `_FrontTargetList/_InCameraTargetList -> app.VisionMarker`, `_SensorHitResult -> app.PawnOrderTargetController.HitResultData`
- Русский: те же слепки также показали конкретные типы элементов внутри `PawnOrderTargetController`: `_EnemyList -> via.GameObject`, `_FrontTargetList/_InCameraTargetList -> app.VisionMarker`, `_SensorHitResult -> app.PawnOrderTargetController.HitResultData`
- English: because of that, both runtime and CE extraction now need special handling for `VisionMarker.<CachedCharacter>` and `HitResultData.Obj`, not only plain `Character` or `Target` fields
- Русский: из-за этого и runtime, и CE extraction теперь должны отдельно уметь читать `VisionMarker.<CachedCharacter>` и `HitResultData.Obj`, а не только обычные поля `Character` или `Target`
- English: the next `Job07` triplet (`2026-03-27 06:58:07`, `06:58:12`, `06:58:15`) finally grounded the strongest fallback root so far: `_EnemyList` no longer looked merely “non-empty”; each first item was a direct `via.GameObject` that resolved an `other` enemy `app.Character` even when `ExecutingDecision` had already flipped back to `self`
- Русский: следующий `Job07` триплет (`2026-03-27 06:58:07`, `06:58:12`, `06:58:15`) наконец заземлил самый сильный fallback root на текущий момент: `_EnemyList` оказался не просто “не пустым”, а его первый элемент был прямым `via.GameObject`, который резолвил `other` enemy `app.Character` даже тогда, когда `ExecutingDecision` уже успевал вернуться в `self`
- English: the same triplet also showed no field-vs-method divergence for `ExecutingDecision` itself: `game_object_paths.target_field` and `game_object_paths.target_method` both resolved the same `via.GameObject`, so that root currently points more strongly to identity instability than to `GameObject` access skew
- Русский: тот же триплет также не показал расхождения `field` против `method` для самого `ExecutingDecision`: `game_object_paths.target_field` и `game_object_paths.target_method` оба резолвили один и тот же `via.GameObject`, так что этот root сейчас сильнее указывает на identity-instability, чем на перекос доступа к `GameObject`
- English: `VisionMarker` stayed weaker in these exact captures because `<CachedCharacter>` was still `nil`, while `get_GameObject()` returned a `via.GameObject`; `HitResultData` exposed `Obj` in reflective field snapshots, but ordinary indexed field access still missed it, which means `SensorHitResult` will require reflection-backed named field reads if it is promoted into runtime fallback
- Русский: `VisionMarker` остался более слабым именно в этих captures, потому что `<CachedCharacter>` там был `nil`, а `get_GameObject()` при этом возвращал `via.GameObject`; `HitResultData` же показывал `Obj` в reflective field snapshots, но обычный индексный доступ это поле всё ещё не видел, а значит для перевода `SensorHitResult` в runtime fallback понадобятся reflection-backed named field reads
- English: because of that, the runtime target selector now treats `cached_pawn_order_target_controller` and other order-target-controller roots as the first fallback tier before wider blackboard and selector surfaces whenever `ExecutingDecision` falls back to `self` or `nil`
- Русский: из-за этого runtime target selector теперь считает `cached_pawn_order_target_controller` и другие order-target-controller roots первым fallback-tier до более широких blackboard- и selector-surfaces всякий раз, когда `ExecutingDecision` проваливается в `self` или `nil`
- English: the runtime also now allows a narrower method-backed `GameObject` retry only when field-backed target extraction failed to produce a usable enemy character, which gives `VisionMarker` a live path without fully restoring hot-path `get_GameObject` dependence everywhere
- Русский: runtime также теперь допускает более узкий method-backed retry по `GameObject` только тогда, когда field-backed target extraction не дал пригодного enemy character; это даёт `VisionMarker` живой path, не возвращая при этом полную зависимость всего hot path от `get_GameObject`
- English: `HitResultData.Obj` is still a second-tier path: runtime `resolve_game_object(...)` now supports reflection-backed named field reads, but `_SensorHitResult` should only become a primary fallback after a live combat run proves it contributes usable enemy characters instead of only extra noise
- Русский: `HitResultData.Obj` пока остаётся second-tier path: runtime `resolve_game_object(...)` теперь уже умеет reflection-backed named field reads, но `_SensorHitResult` стоит поднимать в primary fallback только после live combat-прогона, который докажет, что он реально даёт пригодных enemy characters, а не только дополнительный шум
- English: the next `Job07` triplet (`2026-03-27 07:17:05`, `07:17:10`, `07:17:12`) exposed a different target mode rather than disproving the earlier `_EnemyList` result: `_EnemyList`, `_FrontTargetList`, and `_InCameraTargetList` were all empty, while `_SensorHitResult` jumped to `49` entries
- Русский: следующий `Job07` триплет (`2026-03-27 07:17:05`, `07:17:10`, `07:17:12`) показал уже другой target-mode, а не опроверг прошлый вывод про `_EnemyList`: `_EnemyList`, `_FrontTargetList` и `_InCameraTargetList` там были пустыми, зато `_SensorHitResult` вырос сразу до `49` элементов
- English: each first `HitResultData` entry in that triplet still exposed `Obj -> via.GameObject` in reflective field snapshots, so `_SensorHitResult` is now a validated sensor-side carrier of scene objects even though the CE extractor did not yet promote those entries into chosen enemy characters
- Русский: каждый первый `HitResultData` элемент в этом триплете всё равно показывал `Obj -> via.GameObject` в reflective field snapshots, а значит `_SensorHitResult` теперь уже подтверждён как sensor-side carrier объектов сцены, даже если CE extractor пока ещё не поднимал эти entries до выбранных enemy characters
- English: the paired runtime log for that window was again not a true combat loop; it stayed in `special_output_state` with `Common/HumanTurn_Target_Talking`, so this triplet should currently be treated as a non-combat or transitional target mode rather than as the final fallback design point for attack execution
- Русский: парный runtime-log для этого окна снова не был полноценным боевым циклом; он застрял в `special_output_state` с `Common/HumanTurn_Target_Talking`, поэтому этот триплет пока правильнее считать non-combat или transitional target-mode, а не окончательной опорой для fallback-дизайна атак
- English: because the game-side state is not visually distinguishable enough to separate “true combat stall” from `HumanTurn_Target_Talking` by eye, the runtime has now been intentionally returned to a more method-enabled `via.GameObject` baseline close to the pre-disable period; the next screening should compare against that baseline rather than against the stricter field-only phase
- Русский: поскольку по визуалу в игре недостаточно надёжно отличить “настоящий боевой stall” от `HumanTurn_Target_Talking`, runtime теперь сознательно возвращён к более method-enabled `via.GameObject` baseline, близкому к периоду до отключения; следующий screening правильнее сравнивать уже с этой базой, а не со строгой field-only фазой
- English: the next post-rollback pair (`2026-03-27 07:27:29`, `07:27:34`) exposed a third target mode: all `PawnOrderTargetController` collections were empty again, while `ExecutingDecision` flipped from `self` to `other` between the two captures without any collection help at all
- Русский: следующая post-rollback пара (`2026-03-27 07:27:29`, `07:27:34`) показала уже третий target-mode: все collection-поля `PawnOrderTargetController` снова оказались пустыми, а `ExecutingDecision` успел переключиться из `self` в `other` между двумя captures вообще без какой-либо помощи коллекций
- English: the paired runtime session for that window was the first useful method-enabled baseline after rollback, and it still stalled mostly on `executing_decision_unresolved`; the target probe summary also showed `cached_pawn_order_target_controller_target_unresolved`, so the live blocker there was not bad identity inside a populated collection but full absence of exposed target state at that moment
- Русский: парный runtime-session для этого окна стал первым полезным method-enabled baseline после rollback и всё равно в основном упирался в `executing_decision_unresolved`; summary по target probes также показал `cached_pawn_order_target_controller_target_unresolved`, а значит в тот момент живой блокер был не в плохой identity внутри заполненной коллекции, а в полном отсутствии опубликованного target-state
- English: because the in-game pose alone is not reliable enough to distinguish a true combat stall from `HumanTurn_Target_Talking` or other utility-like transitions, the next grounded screening tool is now `docs/ce_scripts/main_pawn_target_publication_burst.lua`, which samples `ExecutingDecision`, `selected_request`, `current_action`, `full_node`, and `PawnOrderTargetController` collections over time instead of freezing one frame

#### Archived research layer

The old research layer was removed from the product hot path.

The current cleanup goes one step further:

- product runtime no longer loads `game/discovery.lua`
- product runtime no longer performs recursive object-graph scans to resolve `main_pawn`
- `main_pawn` resolution is now limited to direct `PawnManager` / `CharacterManager` access plus narrow character resolution

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

`Content Editor` is now an approved primary external research tool.

The older manual inspection route is preserved as a bounded workflow, not as an excuse to restore internal runtime research.

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
Purpose:
one-shot runtime-resolution screen for `main_pawn Job07`
General use:
quickly verify whether core roots, job controllers, and action surfaces are even alive before writing a heavier extractor

- `docs/ce_scripts/job07_burst_combat_trace.lua`
Purpose:
early timed combat trace for `Job07`
General use:
coarse control trace when the question is about “does anything combat-like happen at all”

- `docs/ce_scripts/actor_burst_combat_trace.lua`
Purpose:
generic actor burst trace family
General use:
compare actors or scenes without hardcoding one exact vocation path

- `docs/ce_scripts/job07_selector_admission_compare_screen.lua`
Purpose:
compare selector and admission surfaces between `main_pawn Job07` and Sigurd `Job07`
General use:
ground pawn-versus-NPC differences before changing runtime selection logic

- `docs/ce_scripts/job07_decision_pipeline_compare_screen.lua`
Purpose:
compare primary AI pipeline families between actors
General use:
decide whether an NPC research path is structurally transferable to pawns

- `docs/ce_scripts/main_pawn_decision_list_screen.lua`
Purpose:
count and dump decision-list entries
General use:
inventory decision pools and compare population size between states or vocations

- `docs/ce_scripts/main_pawn_main_decision_profile_screen.lua`
Purpose:
profile `MainDecisions` by pack identity
General use:
separate attack-heavy decision populations from utility-heavy populations

- `docs/ce_scripts/main_pawn_main_decision_semantic_screen.lua`
Purpose:
dump semantic fields from `app.AIDecision`
General use:
inspect preconditions, target policy, criteria, tags, and decision metadata

- `docs/ce_scripts/main_pawn_target_surface_screen.lua`
Purpose:
one-shot target-surface extractor
General use:
compare target-bearing roots, collection entries, and field-versus-method access paths in one frame

- `docs/ce_scripts/main_pawn_target_publication_burst.lua`
Purpose:
timed burst across targets, outputs, requests, actions, FSM nodes, and `MainDecisions`
General use:
single best CE script for separating target-publication failure, utility masking, and decision-population gaps over time

- `docs/ce_scripts/main_pawn_output_bridge_burst.lua`
Purpose:
timed burst that correlates decision population to action and output surfaces
General use:
prove whether an actor has attack-populated decisions but still fails to output combat behavior

- `docs/ce_scripts/vocation_definition_surface_screen.lua`
Purpose:
extract vocation-definition surfaces and visible runtime job metadata
General use:
ground enum values, vocation descriptors, and job-definition references without touching product runtime

- `docs/ce_scripts/vocation_progression_matrix_screen.lua`
Purpose:
extract progression and custom-skill matrix surfaces
General use:
ground job-level progression, custom-skill IDs, and skill-to-job bands for any vocation

#### Required CE script properties

Each CE script must:

- solve one concrete task
- write output to file
- produce data suitable for compare and later documentation updates

#### Current implementation files

- `mod/reframework/autorun/PawnHybridVocationsAI/bootstrap.lua`
Purpose:
top-level product entrypoint and scheduler wiring
General use:
define what runs every frame, what runs on intervals, and where product runtime begins

- `mod/reframework/autorun/PawnHybridVocationsAI/config.lua`
Purpose:
product-runtime tuning, refresh intervals, and log throttles
General use:
change cadence or verbosity without editing combat logic directly

- `mod/reframework/autorun/PawnHybridVocationsAI/state.lua`
Purpose:
shared runtime state container
General use:
cache actor references, snapshots, and cross-module state without forcing each module to rediscover them

- `mod/reframework/autorun/PawnHybridVocationsAI/core/log.lua`
Purpose:
session-log writer and log rotation
General use:
keep bounded diagnostics in production-like runtime without unbounded file growth

- `mod/reframework/autorun/PawnHybridVocationsAI/core/scheduler.lua`
Purpose:
small interval scheduler keyed by task name
General use:
move expensive or low-volatility work out of per-frame hot paths

- `mod/reframework/autorun/PawnHybridVocationsAI/core/util.lua`
Purpose:
common wrappers for engine access, object resolution, and safe helper functions
General use:
centralize risky engine calls and keep combat code smaller and more consistent

- `mod/reframework/autorun/PawnHybridVocationsAI/core/execution_contracts.lua`
Purpose:
normalize `execution_contract` and `bridge_mode` semantics
General use:
keep selector data, combat profiles, and bridge logic on one shared classification system

- `mod/reframework/autorun/PawnHybridVocationsAI/data/vocation_skill_matrix.lua`
Purpose:
canonical data layer for custom-skill IDs and vocation skill bands
General use:
ground skill names and IDs without scattering literal numbers through runtime code

- `mod/reframework/autorun/PawnHybridVocationsAI/data/hybrid_combat_profiles.lua`
Purpose:
phase-selection data for hybrid combat behavior
General use:
define priorities, skill requirements, range hints, and execution contracts in data instead of hardcoded branches

- `mod/reframework/autorun/PawnHybridVocationsAI/game/main_pawn_properties.lua`
Purpose:
resolve and refresh `main_pawn`, `player`, and their minimal live runtime context
General use:
actor resolution layer for any pawn-focused runtime system

- `mod/reframework/autorun/PawnHybridVocationsAI/game/progression/state.lua`
Purpose:
build cached progression snapshots, per-job level state, and current skill lifecycle state
General use:
move progression and skill-state checks out of combat hot paths

- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_unlock.lua`
Purpose:
restore hybrid unlock state for `main_pawn`
General use:
mirror progression or qualification state while keeping the unlock path isolated from combat logic

- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua`
Purpose:
runtime combat bridge, target resolution, phase selection, and execution
General use:
main product runtime for turning cached progression and live combat surfaces into actual behavior changes

#### Historical native decision-pool signals

The earlier native-first branch repeatedly used these containers as safe structural signals:

- `_CurrentGoalList`
- `_CurrentAddDecisionList`
- `MainDecisions`
- `PreDecisions`
- `PostDecisions`
- `ActiveDecisionPacks`

They remain useful as historical reference even though the current research path is CE-first.

#### Evidence inventory snapshot before log cleanup

This is the authoritative archive snapshot as of `2026-03-27`.

If older prose elsewhere in this file conflicts with the concrete file families below, trust this snapshot first.

- `PawnHybridVocationsAI.session_*.log`
Source:
runtime file logs from `2026-03-26` through `2026-03-27`
Purpose:
record skip reasons, applied phases, target-probe summaries, and bridge outcomes
General use:
runtime triage and regression comparison

- `main_pawn_output_bridge_burst_*.json`
Source:
`docs/ce_scripts/main_pawn_output_bridge_burst.lua`
Purpose:
correlate `MainDecisions` population with `decision_pack_path`, `SelectedRequest`, `CurrentAction`, and FSM output nodes
General use:
separate empty decision-pool windows from attack-populated-but-utility-output windows

- `main_pawn_target_publication_burst_*.json`
Source:
`docs/ce_scripts/main_pawn_target_publication_burst.lua`
Purpose:
sample target publication over time across `ExecutingDecision`, order-target collections, requests, actions, and FSM nodes
General use:
separate true combat stalls from talking or utility transitions that look identical in-game

- `main_pawn_target_surface_*.json`
Source:
`docs/ce_scripts/main_pawn_target_surface_screen.lua`
Purpose:
one-shot snapshot of target-bearing roots and order-target collections
General use:
root-level surface inspection, collection-entry inspection, and field-vs-method comparison

- `job07_selector_admission_compare_*.json`
Source:
`docs/ce_scripts/job07_selector_admission_compare_screen.lua`
Purpose:
compare `main_pawn Job07` against Sigurd `Job07` at selector and admission layer
General use:
ground pawn-vs-NPC differences before editing runtime behavior

- `job07_decision_pipeline_compare_*.json`
Source:
`docs/ce_scripts/job07_decision_pipeline_compare_screen.lua`
Purpose:
compare primary AI pipeline modules between actors
General use:
decide whether an NPC path is structurally portable to pawns

- `main_pawn_decision_list_screen_*.json`, `main_pawn_main_decision_profile_*.json`, and `main_pawn_main_decision_semantic_screen_*.json`
Source:
the matching CE scripts under `docs/ce_scripts/`
Purpose:
inspect `MainDecisions` counts, pack identities, and semantic metadata
General use:
decision-pool inventory and interpretation

- `actor_burst_combat_trace_*.json`, `job07_burst_combat_trace_*.json`, and `job07_runtime_resolution_screen_*.json`
Purpose:
early burst and one-shot research families
General use:
coarse control traces and root-existence sanity checks

- `vocation_definition_surface_*.json` and `vocation_progression_matrix_*.json`
Purpose:
extract vocation definitions, skill bands, and progression-related surfaces
General use:
stable data-layer reference instead of runtime guessing

#### Aggregated findings from archived logs and JSON

- Session-log reason counts in the archived set are dominated first by bootstrap or control noise, then by the real combat blockers:
- `main_pawn_data_unresolved = 135`
- `main_pawn_not_hybrid_job = 113`
- `invalid_target_identity = 33`
- `special_output_state = 25`
- `executing_decision_unresolved = 13`
- `decision_target_character_unresolved = 6`

- Archived applied `Job07` phases prove that the bridge has entered real combat actions before stalls:
- `skill_blade_shoot_mid_far = 2`
- `core_bind_close = 2`
- `skill_dragon_stinger_mid = 2`
- `core_bind_mid = 1`
- `core_gapclose_far = 1`
- `core_short_attack_mid = 1`
- `core_short_attack_close = 1`

- Archived block patterns show that historical failures were often caused by runtime heuristics rather than by total absence of combat actions:
- `job_level_above_assumed_minimum = 7`
- `skill_not_equipped = 5`
- `unsafe_probe_disabled = 1`

- `special_output_state` is a broad interaction or utility guard, not only a talking marker.
Representative archived outputs include:
- `Common/HumanTurn_Target_Talking.user`
- `Common/Pawn_SortItem.user`
- `Common/Interact_Gimmick_TreasureBox.user`
- `Common/Common_WinBattle_Well_02.user`

- `executing_decision_unresolved` is not “one bad getter”.
Archived target-probe summaries repeatedly showed simultaneous unresolved state across `ExecutingDecision`, `AIBlackBoardController`, `AIMetaController`, `HumanActionSelector`, `SelectedRequest`, `CurrentAction`, `Job07ActionCtrl`, and `PawnOrderTargetController`.

- Output bridge bursts established a strong control-vs-problem contrast:
- `main_pawn_output_bridge_burst_job01_main_pawn_output_auto_20260326_185648.json` showed `attack_populated = 24` and mostly `job_specific_output_candidate = 22`
- `main_pawn_output_bridge_burst_job07_main_pawn_output_auto_20260326_190100.json` showed `attack_populated = 24` but still `common_utility_output = 24`

- Target publication bursts established a healthy combat control for `Job01` and multiple target-publication modes for `Job07`:
- `main_pawn_target_publication_burst_job01_main_pawn_target_publication_auto_20260327_075607.json` showed `executing_decision_other = 28` and real `Job01_*` combat nodes
- `main_pawn_target_publication_burst_job07_main_pawn_target_publication_auto_20260327_075916.json` showed `front_target_list_other = 27` while output stayed in locomotion
- `main_pawn_target_publication_burst_job07_main_pawn_target_publication_auto_20260327_075943.json` showed `executing_decision_other = 20` and `enemy_list_other = 10` while output oscillated between locomotion and `Damage.DmgShrink*`
- `main_pawn_target_publication_burst_job07_main_pawn_target_publication_auto_20260327_082519.json` showed `enemy_list_other = 4` and `executing_decision_other = 1` during `Damage.DmgShrinkL/M`

- Target surface screens established at least four one-shot `Job07` target modes:
- populated mixed collections around `20260327_002252` through `20260327_002258`
- stable `_EnemyList` enemy mode around `20260327_065555` through `20260327_065815`
- sensor-heavy `_SensorHitResult` mode around `20260327_071705` through `20260327_071712`
- empty-collection mode around `20260327_072729` through `20260327_072734`

- `job07_selector_admission_compare_20260325_231011.json` and `job07_selector_admission_compare_20260325_231111.json` grounded a pre-pack-selection stall for `main_pawn Job07`.

- `job07_decision_pipeline_compare_20260325_233353.json` and `job07_decision_pipeline_compare_20260325_233501.json` grounded a structural split:
- `main_pawn_primary_module_type = app.DecisionEvaluationModule`
- `sigurd_primary_module_type = app.ThinkTableModule`

#### Grounded surface catalog

The catalog below lists the methods, fields, and containers that are currently grounded by archived logs, CE JSON, local runtime code, and example mods.

If a surface is not listed here, it should not be treated as settled product evidence yet.

- `app.JobContext:getJobLevel(job_id)`
Provenance:
current progression runtime, progression-matrix research, and example skill or progression tooling
Purpose:
read the actor's per-job level
General use:
unlock gating, progression UI parity, and data snapshots
Caveat:
if the runtime cannot read it in time, a fallback like `assumed_minimum_job_level` is only a diagnostic sentinel, not proof that the real level is `0`

- `getCustomSkillLevel(skill_id)`
Provenance:
example skill tooling plus the current lifecycle-cache implementation
Purpose:
read whether a custom skill is learned and at what level or state it exists
General use:
separate `unlockable` from `learned`; build skill lifecycle caches and progression views

- `hasEquipedSkill(job_id, skill_id)`
Provenance:
current runtime gate and example mods
Purpose:
read whether a skill is equipped in the active loadout
General use:
prevent selectors from choosing skills that exist but are not slotted

- `isCustomSkillEnable(skill_id)`
Provenance:
current runtime gate and example mods
Purpose:
read whether a skill is enabled by the current skill context
General use:
runtime legality checks after ownership and equipment have already passed

- `isCustomSkillAvailable(skill_id)`
Provenance:
example mods, lifecycle-gate research, and current runtime probes
Purpose:
read whether a skill is usable under current volatile runtime conditions
General use:
weapon, item, or context-sensitive legality checks
Caveat:
more volatile and historically less trusted than `learned`, `equipped`, and `enabled`, so it should be treated as a combat-readiness layer, not as ownership proof

- `current_job_skill_lifecycle`
Provenance:
current product progression cache
Purpose:
cache `potential -> unlockable -> learned -> equipped -> combat_ready` for the current job outside the combat hot path
General use:
move expensive skill-state checks into a slower progression snapshot and let combat selection read a prepared cache

- `assumed_minimum_job_level`
Provenance:
current runtime fallback and archived session logs
Purpose:
signal that the runtime could not confirm the real job level and fell back to a conservative minimum
General use:
diagnostics only
Caveat:
do not treat it as true actor progression state

- `app.DecisionExecutor.ExecutingDecision`
Provenance:
runtime target probes, target-publication bursts, and target-surface screens
Purpose:
surface the currently executing decision result and often its current target or action pack
General use:
cheap first-pass target-publication check, decision-pack inspection, and combat-loop health screening
Caveat:
can flip between `other`, `self`, and unresolved across short windows

- `app.DecisionEvaluationModule.MainDecisions`
Provenance:
decision-list screens, decision-profile screens, semantic screens, and output-bridge bursts
Purpose:
surface the main AI decision pool
General use:
measure decision population, classify attack-vs-utility weighting, and extract pack identities

- `app.ActionManager.SelectedRequest`
Provenance:
runtime target probes, target-publication bursts, and output-bridge bursts
Purpose:
surface the action or request that the action manager wants next
General use:
compare request intent against current action and output-node state

- `app.ActionManager.CurrentAction`
Provenance:
runtime target probes, target-publication bursts, and output-bridge bursts
Purpose:
surface the action or request that is active now
General use:
classify current output mode, detect utility or talking packs, and compare against `SelectedRequest`

- `Fsm.getCurrentNodeName(layer)`
Provenance:
target-publication bursts, output-bridge bursts, and session logs
Purpose:
read current FSM node names for lower and upper layers
General use:
distinguish locomotion, damage recovery, utility output, and job-specific combat output

- `app.Character:get_AIBlackBoardController()`
Provenance:
runtime target probes and target-surface screens
Purpose:
root access to AI blackboard surfaces
General use:
inspect AI targets, order or update controllers, and action-interface staging roots

- `app.Character:get_LockOnCtrl()`
Provenance:
target-surface screens and runtime target probes
Purpose:
surface lock-on target state
General use:
secondary target-publication source or reseat candidate when decision target collapses

- `app.AIMetaController.<CachedPawnOrderTargetController>`
Provenance:
target-surface screens, target-publication bursts, and runtime target probes
Purpose:
surface the pawn order-target collections through the AI meta controller
General use:
collect fallback enemy, front, camera, or sensor targets without recursive graph scans

- `app.PawnOrderTargetController._EnemyList`
Provenance:
target-surface captures around `20260327_065555` through `20260327_065815`, plus later publication bursts
Purpose:
enemy-target collection
General use:
primary grounded fallback root when `ExecutingDecision` loses or misidentifies the enemy target

- `app.PawnOrderTargetController._FrontTargetList`
Provenance:
target-surface captures and target-publication burst `20260327_075916`
Purpose:
front-priority target collection
General use:
secondary fallback root when the enemy exists in front-target logic but not in `ExecutingDecision`

- `app.PawnOrderTargetController._InCameraTargetList`
Provenance:
target-surface captures
Purpose:
camera-visible target collection
General use:
camera-filtered fallback publication

- `app.PawnOrderTargetController._SensorHitResult`
Provenance:
sensor-heavy target-surface captures around `20260327_071705` through `20260327_071712`
Purpose:
sensor-side container of hit results and scene objects
General use:
tertiary or emergency target or object carrier when ordinary target collections are empty
Caveat:
noisier and less direct than `_EnemyList` or `_FrontTargetList`

- `HitResultData.Obj`
Provenance:
reflective field snapshots inside sensor-heavy target-surface captures
Purpose:
surface the `via.GameObject` stored inside a hit-result entry
General use:
extract scene objects from sensor results through reflection when normal field access fails

- `app.AITargetGameObject`
Provenance:
current bridge implementation and the `AdditionalPawnCommands` example mod
Purpose:
package a target object into an AI or ActInter-compatible carrier
General use:
blackboard target injection, carrier-backed action requests, and AI-side target staging

- `set_ReqMainActInterPackData(app.ActInterPackData)`
Provenance:
current bridge implementation and example carrier-bridge patterns
Purpose:
request a main action-interface pack through the actor blackboard or controller path
General use:
carrier-backed action execution, especially when direct `requestActionCore(...)` is not safe enough

- `special_output_state`
Provenance:
archived session logs and current runtime skip telemetry
Purpose:
runtime skip reason emitted when current output surfaces match interaction, talking, or utility-special tokens
General use:
protect combat bridge code from firing during non-combat interactions

- `executing_decision_unresolved`
Provenance:
archived session logs, runtime target-probe summaries, and target-publication research
Purpose:
runtime skip reason emitted when the current executing-decision target cannot be resolved into a valid target state
General use:
flag missing target publication and trigger external CE screening instead of adding wider hot-path probes

- `app.DecisionEvaluationModule` versus `app.ThinkTableModule`
Provenance:
`job07_decision_pipeline_compare_*.json`
Purpose:
identify which AI pipeline family an actor currently uses
General use:
decide whether an NPC research path is structurally portable to pawns
Caveat:
the current archive grounds `main_pawn` in `DecisionEvaluationModule` and Sigurd in `ThinkTableModule`; they must not be treated as the same architecture

#### Engine data, skill-state, and execution-surface catalog

- `app.HumanCustomSkillID`
Provenance:
enum inspection, progression-matrix research, and example skill tooling
Purpose:
canonical enum family for human custom-skill identifiers
General use:
map numeric custom-skill IDs back to stable symbolic names

- `AbilityParam.JobAbilityParameters`
Provenance:
progression-matrix research and archived augment inspection
Purpose:
container for per-job ability and augment parameter blocks
General use:
inspect augment layers and job-indexed ability data
Important:
the archive grounds the access pattern as `job_id - 1`, not raw `job_id`

- `Job07Parameter`
Provenance:
progression and custom-skill matrix research
Purpose:
job-specific parameter block for vocation `Job07`
General use:
verify that a custom skill, parameter slot, or skill band is real in engine data before changing runtime behavior

- `NormalAttackParam`
Provenance:
decision-semantic research and archived CE semantic captures
Purpose:
parameter surface for baseline attack behavior
General use:
compare normal-attack behavior against custom-skill or job-specific attack layers

- `SetAttackRange`
Provenance:
semantic `MainDecisions` research and archived combat compare data
Purpose:
criterion or process token associated with attack-range staging
General use:
detect whether a decision pool still contains richer combat range-management behavior

- `SkillContext`
Provenance:
runtime skill gates, lifecycle-cache design, and archived skill-state probes
Purpose:
engine-side context that answers ownership, enablement, and related skill-state questions
General use:
separate learned or equipped state from broader runtime legality

- `getCustomSkillLevel(skill_id)`
Provenance:
skill tooling examples and current lifecycle cache
Purpose:
read whether a custom skill is actually learned
General use:
separate unlockability from real skill ownership

- `hasEquipedSkill(job_id, skill_id)`
Provenance:
current runtime skill gate and example mods
Purpose:
check whether a skill is currently slotted
General use:
prevent selectors from choosing skills that the actor does not currently have equipped

- `isCustomSkillEnable(skill_id)`
Provenance:
current runtime skill gate and example mods
Purpose:
check whether a skill is enabled by the current skill context
General use:
runtime legality check after ownership and equip gates

- `isCustomSkillAvailable(skill_id)`
Provenance:
example mods, lifecycle research, and runtime probes
Purpose:
check whether a skill is usable right now under the current game conditions
General use:
volatile combat-ready gate for context-sensitive skills
Important:
this is a more volatile signal than `learned`, `equipped`, or `enabled`

- `current_job_skill_lifecycle`
Provenance:
current progression cache
Purpose:
cache the staged skill state `potential -> unlockable -> learned -> equipped -> combat_ready`
General use:
keep skill lifecycle checks out of the combat hot path and make selector decisions auditable

- `JobXXActionCtrl`
Provenance:
runtime probes, CE target screens, and archived controller-state research
Purpose:
family name for per-job action controllers such as `Job07ActionCtrl`
General use:
inspect controller-owned state when a skill looks partially stateful or unsafe to force directly

- `Job07InputProcessor`
Provenance:
archived `Job07` controller and execution-path research
Purpose:
input-side job-specific processing surface for `Job07`
General use:
investigate whether a vocation requires an input-processor context in addition to a pack or direct action request

- `processCustomSkill`
Provenance:
archived execution-path research and example skill tooling
Purpose:
engine-side processing entry for custom-skill requests
General use:
research alternative execution paths when `requestActionCore(...)` is too shallow or unsafe

- `requestActionCore(...)`
Provenance:
current runtime bridge, archived unsafe-skill probes, and example mods
Purpose:
direct action-request surface used by the runtime bridge
General use:
fast execution path for `direct_safe` phases or as the second half of `carrier_then_action`
Important:
the archive shows that “action starts” does not prove that the surrounding controller state is valid

- `via.Component.get_GameObject` and `via.GameObject.getComponent(System.Type)`
Provenance:
current utility layer, target-surface research, and REFramework exception logs
Purpose:
bridge from arbitrary engine objects or components to a `via.GameObject` and then to typed components such as `app.Character`
General use:
component resolution, target normalization, and scene-object extraction
Important:
use sparingly in hot paths; the archive shows that overly broad getter-heavy use can trigger costly exceptions

#### Unlock, contract, and classification catalog

- `player.QualifiedJobBits`
Provenance:
current unlock runtime and guild-side unlock restoration code
Purpose:
bitfield of jobs qualified by the player actor
General use:
progression gating, unlock mirroring, and UI parity checks

- `main_pawn.JobContext.QualifiedJobBits`
Provenance:
current hybrid-unlock runtime
Purpose:
bitfield of jobs qualified by `main_pawn`
General use:
mirror missing qualification bits from one actor to another and verify unlock state without opening UI

- `app.ui040101_00.getJobInfoParam`
Provenance:
current guild-side unlock override
Purpose:
UI-facing job info accessor used by the guild job screen
General use:
install narrow UI overrides when a runtime unlock exists but the view layer still hides it

- `_EnablePawn`
Provenance:
current guild-side unlock override and UI inspection
Purpose:
job-info flag that controls whether the pawn is allowed to use or show the job in UI
General use:
UI parity fixes and view-layer debugging

- `execution_contract`
Provenance:
current runtime data model, combat profiles, and archived contract research
Purpose:
classify how a skill or phase may be entered safely
General use:
separate skill identity from execution semantics in any action bridge

- `direct_safe`
Provenance:
archived contract research and current runtime data
Purpose:
contract label for phases that can safely enter through direct action forcing
General use:
direct `requestActionCore(...)` path or equivalent low-risk action triggers

- `carrier_required`
Provenance:
archived contract research, current bridge, and carrier-backed example mods
Purpose:
contract label for phases that require an AI-target or ActInter carrier path
General use:
pack-based execution, blackboard target staging, and safer bridge admission for context-heavy skills

- `controller_stateful`
Provenance:
archived `DragonStinger` investigation and current runtime probe mode
Purpose:
contract label for phases that depend on dedicated controller state beyond a simple action request
General use:
mark unsafe or partial research paths that require controller snapshots before implementation

- `selector_owned`
Provenance:
current data model and archived conservative contract placeholder policy
Purpose:
contract label for phases that should still be left to native selection until stronger grounding exists
General use:
safe default for unclassified actions in research-heavy systems

- `action_only`
Provenance:
current bridge modes and archived unsafe-probe work
Purpose:
bridge mode that fires only a direct action request
General use:
low-overhead execution path for directly safe actions

- `carrier_only`
Provenance:
current bridge modes and archived unsafe-probe work
Purpose:
bridge mode that submits only the carrier or pack side of a request
General use:
staging or experimental contexts where native follow-up is expected after the carrier lands

- `carrier_then_action`
Provenance:
current bridge modes and archived contract work
Purpose:
bridge mode that stages carrier context first and then fires the direct action path
General use:
hybrid execution for context-heavy actions

- `priority-first`
Provenance:
current selector rollback and archived regression analysis
Purpose:
selection rule where raw phase `priority` decides ordering and contracts only affect execution, not candidate ranking
General use:
recover deterministic behavior when heuristic selectors become too opaque

- `assumed_minimum_job_level`
Provenance:
current runtime fallback and archived blocked-phase logs
Purpose:
diagnostic fallback meaning the runtime could not confirm the real job level
General use:
telemetry and guardrail diagnostics
Caveat:
not a substitute for the true job level

- `attack_populated`
Provenance:
output-bridge burst classification
Purpose:
decision-pool label meaning attack-oriented packs are present in `MainDecisions`
General use:
distinguish an admission or output problem from a missing decision-population problem

- `no_pack_population`
Provenance:
output-bridge burst classification
Purpose:
decision-pool label meaning no pack-bearing decisions were found in the scanned population
General use:
identify empty or under-instrumented decision windows

- `common_utility_output`
Provenance:
output-bridge burst classification and runtime output interpretation
Purpose:
output label for locomotion or utility-like packs, requests, and nodes
General use:
separate non-combat output from job-specific or attack-like output

- `job_specific_output_candidate`
Provenance:
output-bridge burst classification
Purpose:
output label meaning current surfaces contain job-specific pack or node tokens
General use:
detect plausible combat output without hardcoding one exact animation

- `executing_decision_other`, `enemy_list_other`, `front_target_list_other`, `in_camera_target_list_other`
Provenance:
target-publication burst classifications
Purpose:
publication labels that identify which target source currently carries an `other` enemy target
General use:
choose fallback roots based on observed live publication rather than on assumptions

#### Lifecycle and skip-reason catalog

- `potential`
Provenance:
current skill-lifecycle cache design
Purpose:
label for skills that exist in the matrix but have not yet passed unlock requirements
General use:
separate “known to data” from “ready to be unlocked”

- `unlockable`
Provenance:
current skill-lifecycle cache design and progression research
Purpose:
label for skills whose job-level gate is already satisfied
General use:
show that a skill may now appear for purchase or ownership checks

- `learned`
Provenance:
current skill-lifecycle cache and skill-state research
Purpose:
label for skills that are actually owned or learned
General use:
hard gate selection so unowned skills never enter combat candidates

- `equipped`
Provenance:
current skill-lifecycle cache and equip-state research
Purpose:
label for skills that are currently slotted
General use:
restrict selectors to the actor’s active combat loadout

- `combat_ready`
Provenance:
current skill-lifecycle cache design
Purpose:
final staged label meaning a skill is learned, equipped, and runtime-legal now
General use:
cheap selector-facing summary instead of rechecking every gate in the combat hot path

- `bridge_mode`
Provenance:
current combat bridge and archived contract normalization work
Purpose:
runtime execution-mode label derived from a phase contract
General use:
log and compare how the bridge actually tried to execute a chosen phase

- `invalid_target_identity`
Provenance:
session logs and archived target-gate failures
Purpose:
skip reason emitted when a resolved target collapses to `self`, `player`, or another disallowed identity
General use:
separate missing target publication from bad target classification

- `skill_not_learned`
Provenance:
current lifecycle-backed skill gate
Purpose:
skip reason emitted when a phase requires a skill that the actor does not actually own
General use:
prove a lifecycle failure before blaming target or output logic

- `skill_not_equipped`
Provenance:
current and archived skill-gate telemetry
Purpose:
skip reason emitted when a required skill is owned but not slotted
General use:
separate loadout problems from deeper execution problems

- `skill_not_enabled`
Provenance:
current skill-gate telemetry
Purpose:
skip reason emitted when a required skill is equipped but not enabled by current skill context
General use:
detect runtime legality failures after ownership and equip succeed

- `skill_not_available`
Provenance:
current skill-gate telemetry and example-mod availability checks
Purpose:
skip reason emitted when a skill is enabled in principle but unavailable under current game conditions
General use:
track volatile combat gating separately from stable lifecycle state

- `job_level_above_assumed_minimum`
Provenance:
archived blocked-phase logs and current fallback diagnostics
Purpose:
skip or warning reason showing that a phase required a higher level than the fallback runtime could confirm
General use:
flag unresolved progression data instead of treating fallback level as true progression

#### Research tooling and script catalog

- `Content Editor`
Provenance:
external tool mod already used in project research
Purpose:
primary live inspection environment for CE console scripts, AI overview, blackboard viewers, and direct dumps
General use:
interactive engine-state inspection without shipping probes in product runtime

- `ce_find(...)`
Provenance:
Content Editor console workflow
Purpose:
search engine-side objects, types, fields, or resources through the CE environment
General use:
quick surface discovery before writing a specialized extractor

- `ce_dump(...)`
Provenance:
Content Editor console workflow
Purpose:
dump structured CE inspection output to file
General use:
repeatable evidence capture that can be archived and compared offline

- `DD2_DataScraper`
Provenance:
external utility pack research tool
Purpose:
bulk one-shot exporter for larger data snapshots
General use:
offload heavy discovery or catalog extraction from the product runtime

- `Nick's Devtools` and `_NickCore`
Provenance:
external research tooling loaded during development
Purpose:
dev-only tracing and helper infrastructure
General use:
bounded live tracing when CE scripts and static dumps are not enough

- `Skill Maker`
Provenance:
external example mod used as a reference set
Purpose:
reference catalog for action names, skill metadata, and user-facing skill datasets
General use:
ground naming and ID interpretation without inventing new nomenclature

- `docs/ce_scripts/main_pawn_target_surface_screen.lua`
Purpose:
one-shot target-surface extractor
General use:
compare target-bearing roots and order-target collections at one frame

- `docs/ce_scripts/main_pawn_target_publication_burst.lua`
Purpose:
timed publication burst over targets, outputs, and now `MainDecisions`
General use:
single best script for separating target-publication failure from utility-output masking

- `docs/ce_scripts/main_pawn_output_bridge_burst.lua`
Purpose:
timed burst correlating decision population to action and output surfaces
General use:
prove whether an actor has attack-populated decisions but still fails to output combat behavior

- `docs/ce_scripts/main_pawn_decision_list_screen.lua`
Purpose:
stable count and entry dump for decision lists
General use:
decision-pool inventory and count comparison

- `docs/ce_scripts/main_pawn_main_decision_profile_screen.lua`
Purpose:
pack-identity profile for `MainDecisions`
General use:
attack-vs-utility population profiling

- `docs/ce_scripts/main_pawn_main_decision_semantic_screen.lua`
Purpose:
semantic field dump for `app.AIDecision`
General use:
preconditions, target policy, and tag interpretation

- `docs/ce_scripts/job07_selector_admission_compare_screen.lua`
Purpose:
compare selector and admission surfaces between `main_pawn Job07` and Sigurd `Job07`
General use:
ground structural differences before changing runtime logic

- `docs/ce_scripts/job07_decision_pipeline_compare_screen.lua`
Purpose:
compare the primary AI module family between actors
General use:
decide whether NPC research is structurally transferable to pawns

- `docs/ce_scripts/actor_burst_combat_trace.lua`, `docs/ce_scripts/job07_burst_combat_trace.lua`, and `docs/ce_scripts/job07_runtime_resolution_screen.lua`
Purpose:
early burst or one-shot research families
General use:
coarse control traces and root-liveness sanity checks

## Русский

### Путеводитель

Этот файл теперь стоит читать в трех слоях:

1. инварианты проекта и текущие выводы
2. структурированные каталоги с полями `Откуда / Что делает / Как использовать / Что важно`
3. исторический narrative и архивные заметки

Правило каталога:

- если идентификатор, файл, метод, контейнер, skip reason или исследовательский артефакт влияет на дизайн, runtime-поведение или workflow исследования, он должен быть описан в одном из каталогов ниже
- narrative-разделы могут повторно упоминать те же сущности, но именно каталог должен объяснять, что это такое, откуда мы это взяли и как это можно применять не только в рамках нашего мода

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
- `game/main_pawn_properties.lua`
- `game/progression/state.lua`
- `game/hybrid_unlock.lua`
- `game/hybrid_combat_fix.lua`

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
Что делает:
one-shot screen по runtime-resolution для `main_pawn Job07`
Как можно использовать:
быстро проверить, живы ли корневые roots, job controller и action surfaces до написания более тяжелого extractor

- `docs/ce_scripts/job07_burst_combat_trace.lua`
Что делает:
ранний timed combat trace для `Job07`
Как можно использовать:
грубый контрольный trace, когда нужно понять, происходит ли вообще хоть что-то похожее на бой

- `docs/ce_scripts/actor_burst_combat_trace.lua`
Что делает:
универсальная burst-trace family для акторов
Как можно использовать:
сравнивать актеров и сцены без жесткой привязки к одной профессии

- `docs/ce_scripts/job07_selector_admission_compare_screen.lua`
Что делает:
сравнивает selector/admission surfaces между `main_pawn Job07` и Sigurd `Job07`
Как можно использовать:
заземлять различия pawn-vs-NPC до правок runtime-логики

- `docs/ce_scripts/job07_decision_pipeline_compare_screen.lua`
Что делает:
сравнивает primary AI pipeline family между актерами
Как можно использовать:
решать, переносим ли вообще NPC-path на pawn по архитектуре

- `docs/ce_scripts/main_pawn_decision_list_screen.lua`
Что делает:
считает и дампит entries decision list
Как можно использовать:
инвентаризация decision pool и сравнение плотности популяции между состояниями

- `docs/ce_scripts/main_pawn_main_decision_profile_screen.lua`
Что делает:
профилирует `MainDecisions` по pack identity
Как можно использовать:
разводить attack-heavy и utility-heavy decision populations

- `docs/ce_scripts/main_pawn_main_decision_semantic_screen.lua`
Что делает:
дампит semantic fields у `app.AIDecision`
Как можно использовать:
смотреть preconditions, target policy, criteria, tags и metadata решения

- `docs/ce_scripts/main_pawn_target_surface_screen.lua`
Что делает:
one-shot extractor target surfaces
Как можно использовать:
сравнивать target-bearing roots, entries коллекций и field-vs-method пути в одном кадре

- `docs/ce_scripts/main_pawn_target_publication_burst.lua`
Что делает:
timed burst по target, output, requests, actions, FSM nodes и `MainDecisions`
Как можно использовать:
лучший единый CE script, чтобы разводить провал target-publication, utility masking и decision-population gap во времени

- `docs/ce_scripts/main_pawn_output_bridge_burst.lua`
Что делает:
timed burst, который связывает population решений с action/output surfaces
Как можно использовать:
доказывать, что у актора есть attack-populated decisions, но он все равно не выдает боевой output

- `docs/ce_scripts/vocation_definition_surface_screen.lua`
Что делает:
достает vocation-definition surfaces и runtime job metadata
Как можно использовать:
заземлять enum values, vocation descriptors и job-definition references без продуктовых probes

- `docs/ce_scripts/vocation_progression_matrix_screen.lua`
Что делает:
достает progression surfaces и custom-skill matrix
Как можно использовать:
заземлять job-level progression, custom-skill IDs и bands навыков для любой профессии

#### Обязательные свойства CE script

Каждый CE script должен:

- решать одну конкретную задачу
- писать результат в файл
- выдавать данные, пригодные для compare и дальнейшего обновления документации

#### Текущие implementation files

- `mod/reframework/autorun/PawnHybridVocationsAI/bootstrap.lua`
Что делает:
верхнеуровневый entrypoint продукта и wiring scheduler
Как можно использовать:
понимать, что у нас тикает каждый кадр, что идет по интервалу и где вообще начинается product runtime

- `mod/reframework/autorun/PawnHybridVocationsAI/config.lua`
Что делает:
хранит tuning продукта, refresh intervals и log throttles
Как можно использовать:
менять cadence и verbosity без правки боевой логики напрямую

- `mod/reframework/autorun/PawnHybridVocationsAI/state.lua`
Что делает:
общий container для runtime state
Как можно использовать:
кэшировать actor references, snapshots и межмодульное состояние без повторного discovery в каждом модуле

- `mod/reframework/autorun/PawnHybridVocationsAI/core/log.lua`
Что делает:
пишет session-log и крутит ротацию файлов
Как можно использовать:
держать ограниченную диагностику в продуктоподобном runtime без бесконечного роста папки логов

- `mod/reframework/autorun/PawnHybridVocationsAI/core/scheduler.lua`
Что делает:
маленький interval scheduler по имени задачи
Как можно использовать:
вытаскивать дорогие или медленно меняющиеся проверки из per-frame hot path

- `mod/reframework/autorun/PawnHybridVocationsAI/core/util.lua`
Что делает:
содержит общие wrappers для engine access, object resolution и safe helper functions
Как можно использовать:
централизовать рискованные engine calls и держать боевой код короче и единообразнее

- `mod/reframework/autorun/PawnHybridVocationsAI/core/execution_contracts.lua`
Что делает:
нормализует `execution_contract` и `bridge_mode`
Как можно использовать:
держать selector data, combat profiles и bridge logic на одной общей классификации

- `mod/reframework/autorun/PawnHybridVocationsAI/data/vocation_skill_matrix.lua`
Что делает:
канонический data layer для custom-skill IDs и vocation skill bands
Как можно использовать:
заземлять skill names и IDs без россыпи литеральных чисел по runtime-коду

- `mod/reframework/autorun/PawnHybridVocationsAI/data/hybrid_combat_profiles.lua`
Что делает:
хранит phase-selection data для hybrid combat behavior
Как можно использовать:
описывать priorities, skill requirements, range hints и execution contracts данными, а не жесткими ветками

- `mod/reframework/autorun/PawnHybridVocationsAI/game/main_pawn_properties.lua`
Что делает:
резолвит и обновляет `main_pawn`, `player` и их минимальный live runtime context
Как можно использовать:
служить actor-resolution слоем для любой pawn-focused runtime-системы

- `mod/reframework/autorun/PawnHybridVocationsAI/game/progression/state.lua`
Что делает:
строит кэш progression snapshots, per-job level state и lifecycle state навыков
Как можно использовать:
вынести progression и skill-state checks из combat hot path

- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_unlock.lua`
Что делает:
восстанавливает hybrid unlock state у `main_pawn`
Как можно использовать:
зеркалить progression или qualification state, не смешивая unlock path с боевой логикой

- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua`
Что делает:
содержит runtime combat bridge, target resolution, phase selection и execution
Как можно использовать:
это главный продуктовый runtime для превращения кэшированного progression state и live combat surfaces в реальное поведение

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

#### Архивный snapshot перед очисткой логов

Этот раздел теперь считается основной опорной точкой перед удалением старых логов и JSON.

- `PawnHybridVocationsAI.session_*.log`
Откуда:
runtime file logs за `2026-03-26` и `2026-03-27`
Что делает:
фиксирует skip reasons, applied phases, target-probe summaries и bridge results
Как можно использовать:
разбирать runtime-регрессии и сравнивать сессии между собой

- `main_pawn_output_bridge_burst_*.json`
Откуда:
`docs/ce_scripts/main_pawn_output_bridge_burst.lua`
Что делает:
связывает population `MainDecisions` с `decision_pack_path`, `SelectedRequest`, `CurrentAction` и FSM output
Как можно использовать:
отделять пустой decision pool от attack-populated decision pool, который всё равно выдаёт utility output

- `main_pawn_target_publication_burst_*.json`
Откуда:
`docs/ce_scripts/main_pawn_target_publication_burst.lua`
Что делает:
показывает target publication во времени через `ExecutingDecision`, collections `PawnOrderTargetController`, requests, actions и FSM nodes
Как можно использовать:
разводить настоящий combat stall и talking или utility transition

- `main_pawn_target_surface_*.json`
Откуда:
`docs/ce_scripts/main_pawn_target_surface_screen.lua`
Что делает:
one-shot snapshot target roots и order-target collections
Как можно использовать:
смотреть root-level surfaces, collection entries и field-vs-method paths

- `job07_selector_admission_compare_*.json`
Что делает:
сравнивает `main_pawn Job07` и Sigurd `Job07` на selector или admission layer
Как можно использовать:
доказывать pawn-vs-NPC differences до правок runtime

- `job07_decision_pipeline_compare_*.json`
Что делает:
сравнивает primary AI module types между акторами
Как можно использовать:
понимать, переносим ли NPC path на pawn вообще по архитектуре

- `main_pawn_decision_list_screen_*.json`, `main_pawn_main_decision_profile_*.json`, `main_pawn_main_decision_semantic_screen_*.json`
Что делают:
дают count, profile и semantic view по `MainDecisions`
Как можно использовать:
инвентаризация и interpretation decision pool

#### Агрегированные выводы из архива

- На текущем архивном наборе причины в session-log распределяются так:
- `main_pawn_data_unresolved = 135`
- `main_pawn_not_hybrid_job = 113`
- `invalid_target_identity = 33`
- `special_output_state = 25`
- `executing_decision_unresolved = 13`
- `decision_target_character_unresolved = 6`

- Архив уже доказывает, что bridge реально входил в боевые `Job07` фазы:
- `skill_blade_shoot_mid_far = 2`
- `core_bind_close = 2`
- `skill_dragon_stinger_mid = 2`
- `core_bind_mid = 1`
- `core_gapclose_far = 1`
- `core_short_attack_mid = 1`
- `core_short_attack_close = 1`

- Архивные block patterns показывают, что часть старых сбоев была вызвана не отсутствием навыков, а runtime heuristics:
- `job_level_above_assumed_minimum = 7`
- `skill_not_equipped = 5`
- `unsafe_probe_disabled = 1`

- `special_output_state` — это не только talking.
В архиве под этот reason попадали:
- `Common/HumanTurn_Target_Talking.user`
- `Common/Pawn_SortItem.user`
- `Common/Interact_Gimmick_TreasureBox.user`
- `Common/Common_WinBattle_Well_02.user`

- `executing_decision_unresolved` — это не один плохой getter.
Архивные target-probe summaries показывают, что в такие окна одновременно разваливались `ExecutingDecision`, `AIBlackBoardController`, `AIMetaController`, `HumanActionSelector`, `SelectedRequest`, `CurrentAction`, `Job07ActionCtrl` и `PawnOrderTargetController`.

- Output bridge bursts уже зафиксировали контрольную разницу:
- `main_pawn_output_bridge_burst_job01_main_pawn_output_auto_20260326_185648.json` дал `attack_populated = 24` и в основном `job_specific_output_candidate = 22`
- `main_pawn_output_bridge_burst_job07_main_pawn_output_auto_20260326_190100.json` дал `attack_populated = 24`, но при этом `common_utility_output = 24`

- Target publication bursts уже зафиксировали и healthy control для `Job01`, и несколько разных `Job07` publication modes:
- `...075607` показал `executing_decision_other = 28` и реальные `Job01_*` combat nodes
- `...075916` показал `front_target_list_other = 27`, но output остался locomotion
- `...075943` показал смесь `executing_decision_other` и `enemy_list_other` при output в locomotion и `Damage.DmgShrink*`
- `...082519` показал live enemy target во время `Damage.DmgShrinkL/M`

- Target surface screens уже доказали как минимум четыре `Job07` target mode:
- mixed collections
- stable `_EnemyList` mode
- sensor-heavy `_SensorHitResult` mode
- empty-collection mode

- `job07_selector_admission_compare_*.json` зафиксировали stall до полноценного `Job07` pack selection.

- `job07_decision_pipeline_compare_*.json` зафиксировали структурное расхождение:
- `main_pawn = app.DecisionEvaluationModule`
- `sigurd = app.ThinkTableModule`

#### Каталог grounded surfaces

- `app.JobContext:getJobLevel(job_id)`
Откуда:
progression runtime, progression research и example tooling
Что делает:
читает per-job level актора
Как можно использовать:
unlock gating, progression snapshots, UI parity
Важно:
`assumed_minimum_job_level` не является proof реального уровня

- `getCustomSkillLevel(skill_id)`
Откуда:
example skill tooling и текущий lifecycle cache
Что делает:
читает, изучен ли custom skill
Как можно использовать:
разводить `unlockable` и `learned`

- `hasEquipedSkill(job_id, skill_id)`
Откуда:
runtime gate и example mods
Что делает:
проверяет, экипирован ли skill
Как можно использовать:
не давать selector’у выбирать неслотнутые навыки

- `isCustomSkillEnable(skill_id)`
Откуда:
runtime gate и example mods
Что делает:
проверяет, разрешён ли skill текущим skill context
Как можно использовать:
runtime legality check после ownership и equip

- `isCustomSkillAvailable(skill_id)`
Откуда:
example mods, lifecycle research, runtime probes
Что делает:
проверяет, можно ли skill использовать прямо сейчас
Как можно использовать:
context-sensitive `combat_ready` gate
Важно:
это более volatile слой, чем `learned`, `equipped` и `enabled`

- `current_job_skill_lifecycle`
Откуда:
текущий progression cache
Что делает:
кэширует `potential -> unlockable -> learned -> equipped -> combat_ready`
Как можно использовать:
выносить skill-state проверки из combat hot path

- `app.DecisionExecutor.ExecutingDecision`
Откуда:
runtime target probes, publication bursts, target surfaces
Что делает:
surface текущего executing decision и часто его target или action pack
Как можно использовать:
дешёвый first-pass target publication check

- `app.DecisionEvaluationModule.MainDecisions`
Откуда:
decision-list/profile/semantic screens и output bursts
Что делает:
surface основного AI decision pool
Как можно использовать:
мерить attack-vs-utility population и вытаскивать pack identities

- `app.ActionManager.SelectedRequest`
Откуда:
runtime probes и CE bursts
Что делает:
surface action/request, который action manager хочет следующим
Как можно использовать:
сравнивать request intent с `CurrentAction`

- `app.ActionManager.CurrentAction`
Откуда:
runtime probes и CE bursts
Что делает:
surface action/request, активный сейчас
Как можно использовать:
классифицировать текущий output mode

- `Fsm.getCurrentNodeName(layer)`
Откуда:
CE bursts и session-log interpretation
Что делает:
читает имена FSM nodes по слоям
Как можно использовать:
разводить locomotion, damage, utility и job-specific combat output

- `app.Character:get_AIBlackBoardController()`
Откуда:
runtime target probes и target-surface screens
Что делает:
даёт корневой доступ к AI blackboard surfaces
Как можно использовать:
смотреть AI targets, order/update controllers и action-interface staging

- `app.Character:get_LockOnCtrl()`
Откуда:
target-surface screens и runtime target probes
Что делает:
surface состояния lock-on target
Как можно использовать:
secondary target source или reseat candidate

- `app.AIMetaController.<CachedPawnOrderTargetController>`
Откуда:
target-surface screens, publication bursts и runtime target probes
Что делает:
даёт доступ к pawn order-target collections
Как можно использовать:
брать fallback enemy/front/camera/sensor targets без recursive scans

- `app.PawnOrderTargetController._EnemyList`
Откуда:
target-surface wave `065555` – `065815` и later bursts
Что делает:
enemy-target collection
Как можно использовать:
primary grounded fallback root

- `app.PawnOrderTargetController._FrontTargetList`
Откуда:
target-surface captures и burst `075916`
Что делает:
front-priority target collection
Как можно использовать:
secondary fallback root

- `app.PawnOrderTargetController._InCameraTargetList`
Откуда:
target-surface captures
Что делает:
camera-visible target collection
Как можно использовать:
camera-filtered target publication

- `app.PawnOrderTargetController._SensorHitResult`
Откуда:
sensor-heavy target-surface captures
Что делает:
sensor-side container hit results и scene objects
Как можно использовать:
tertiary или emergency target/object carrier

- `HitResultData.Obj`
Откуда:
reflective field snapshots в sensor-heavy captures
Что делает:
достаёт `via.GameObject` из hit-result entry
Как можно использовать:
reflection-backed object extraction

- `app.AITargetGameObject`
Откуда:
current bridge и example mod `AdditionalPawnCommands`
Что делает:
упаковывает target в AI/ActInter-compatible carrier
Как можно использовать:
blackboard target injection и carrier-backed action requests

- `set_ReqMainActInterPackData(app.ActInterPackData)`
Откуда:
current bridge и example carrier patterns
Что делает:
запрашивает main action-interface pack
Как можно использовать:
carrier-backed action execution

- `special_output_state`
Откуда:
archived session logs и runtime skip telemetry
Что делает:
skip reason для interaction, talking и utility-special output
Как можно использовать:
не запускать combat bridge во время non-combat states

- `executing_decision_unresolved`
Откуда:
archived session logs, runtime target-probe summaries и publication research
Что делает:
skip reason для провала target publication по executing decision
Как можно использовать:
маркер, что пора идти во внешний CE screening, а не расширять hot-path probes

- `app.DecisionEvaluationModule` против `app.ThinkTableModule`
Откуда:
`job07_decision_pipeline_compare_*.json`
Что делает:
показывает, к какой AI pipeline family относится actor
Как можно использовать:
решать, переносим ли NPC research path на pawn

#### Каталог engine data, skill-state и execution surfaces

- `app.HumanCustomSkillID`
Откуда:
enum inspection, research по progression matrix и example skill tooling
Что делает:
каноническая enum-family для human custom-skill identifiers
Как можно использовать:
маппить числовые custom-skill IDs обратно в стабильные символические имена

- `AbilityParam.JobAbilityParameters`
Откуда:
research по progression matrix и архивная инспекция augment-layer
Что делает:
container для per-job ability и augment parameter blocks
Как можно использовать:
исследовать augment layers и job-indexed ability data
Что важно:
архив заземляет доступ как `job_id - 1`, а не raw `job_id`

- `Job07Parameter`
Откуда:
research по progression и custom-skill matrix
Что делает:
job-specific parameter block для профессии `Job07`
Как можно использовать:
проверять, что custom skill, parameter slot или skill band реально существуют в engine data до правок runtime

- `NormalAttackParam`
Откуда:
semantic research по `MainDecisions` и архивные CE semantic captures
Что делает:
parameter surface для baseline attack behavior
Как можно использовать:
сравнивать поведение обычной атаки с custom-skill и job-specific attack layers

- `SetAttackRange`
Откуда:
semantic research и архивные combat compare data
Что делает:
criterion или process token, связанный с управлением дистанцией атаки
Как можно использовать:
проверять, осталась ли в decision pool более богатая combat range-management логика

- `SkillContext`
Откуда:
runtime skill gates, дизайн lifecycle-cache и архивные skill-state probes
Что делает:
engine-side context, который отвечает на вопросы ownership, enablement и родственные skill-state вопросы
Как можно использовать:
разводить learned/equipped state и более широкий runtime legality layer

- `getCustomSkillLevel(skill_id)`
Откуда:
example skill tooling и текущий lifecycle cache
Что делает:
читает, реально ли custom skill изучен
Как можно использовать:
разводить `unlockable` и `learned`

- `hasEquipedSkill(job_id, skill_id)`
Откуда:
текущий runtime gate и example mods
Что делает:
проверяет, стоит ли skill в слотах
Как можно использовать:
не давать selector’у выбирать неэкипированные навыки

- `isCustomSkillEnable(skill_id)`
Откуда:
текущий runtime gate и example mods
Что делает:
проверяет, разрешен ли skill текущим skill context
Как можно использовать:
runtime legality check после ownership и equip gates

- `isCustomSkillAvailable(skill_id)`
Откуда:
example mods, lifecycle research и runtime probes
Что делает:
проверяет, можно ли skill использовать прямо сейчас в текущих игровых условиях
Как можно использовать:
volatile `combat_ready` gate для context-sensitive skills
Что важно:
это более volatile сигнал, чем `learned`, `equipped` и `enabled`

- `current_job_skill_lifecycle`
Откуда:
текущий progression cache
Что делает:
кэширует staged skill state `potential -> unlockable -> learned -> equipped -> combat_ready`
Как можно использовать:
вынести skill lifecycle checks из combat hot path и сделать selector-решения проверяемыми

- `JobXXActionCtrl`
Откуда:
runtime probes, CE target screens и архивное research по controller-state
Что делает:
общее имя family для per-job action controllers, например `Job07ActionCtrl`
Как можно использовать:
смотреть controller-owned state у навыков, которые выглядят частично stateful или unsafe для прямого форса

- `Job07InputProcessor`
Откуда:
архивное research по controller и execution path у `Job07`
Что делает:
job-specific input-side processing surface для `Job07`
Как можно использовать:
проверять, требует ли профессия input-processor context помимо pack или direct action request

- `processCustomSkill`
Откуда:
архивное research execution paths и example skill tooling
Что делает:
engine-side processing entry для custom-skill requests
Как можно использовать:
исследовать альтернативные execution paths, когда `requestActionCore(...)` оказывается слишком поверхностным или unsafe

- `requestActionCore(...)`
Откуда:
текущий runtime bridge, архивные unsafe-skill probes и example mods
Что делает:
surface прямого action-request, которым пользуется runtime bridge
Как можно использовать:
быстрый execution path для `direct_safe` phases или вторая половина `carrier_then_action`
Что важно:
архив уже показал, что “action стартовал” не доказывает, что окружающий controller state валиден

- `via.Component.get_GameObject` и `via.GameObject.getComponent(System.Type)`
Откуда:
текущий utility layer, target-surface research и REFramework exception logs
Что делает:
строит bridge от произвольного engine object или component к `via.GameObject`, а затем к typed component вроде `app.Character`
Как можно использовать:
component resolution, target normalization и scene-object extraction
Что важно:
использовать аккуратно в hot path; архив уже показал, что слишком широкое getter-heavy использование может вызывать дорогие exceptions

#### Каталог unlock, контрактов и классификаций

- `player.QualifiedJobBits`
Откуда:
текущий unlock runtime и код восстановления unlock на guild-side
Что делает:
bitfield профессий, на которые квалифицирован player actor
Как можно использовать:
progression gating, unlock mirroring и UI parity checks

- `main_pawn.JobContext.QualifiedJobBits`
Откуда:
текущий runtime hybrid unlock
Что делает:
bitfield профессий, на которые квалифицирован `main_pawn`
Как можно использовать:
зеркалить недостающие qualification bits между актерами и проверять unlock state без открытия UI

- `app.ui040101_00.getJobInfoParam`
Откуда:
текущий guild-side unlock override
Что делает:
UI-facing accessor job info, который использует экран guild jobs
Как можно использовать:
ставить узкие UI overrides, когда runtime unlock уже существует, а view layer еще его скрывает

- `_EnablePawn`
Откуда:
текущий guild-side unlock override и UI inspection
Что делает:
job-info flag, который контролирует, может ли pawn использовать или видеть профессию в UI
Как можно использовать:
чинить UI parity и отлаживать view-layer

- `execution_contract`
Откуда:
текущая runtime data model, combat profiles и архивное research по контрактам
Что делает:
классифицирует, как skill или phase можно безопасно запускать
Как можно использовать:
разделять идентичность навыка и семантику его исполнения в любом action bridge

- `direct_safe`
Откуда:
архивное research по контрактам и текущие runtime data
Что делает:
label для фаз, которые можно безопасно запускать прямым action forcing
Как можно использовать:
прямой путь через `requestActionCore(...)` или похожий low-risk trigger

- `carrier_required`
Откуда:
архивное research по контрактам, текущий bridge и carrier-backed example mods
Что делает:
label для фаз, которым нужен AI-target или ActInter carrier path
Как можно использовать:
pack-based execution, blackboard target staging и более безопасный bridge admission для context-heavy skills

- `controller_stateful`
Откуда:
архивное исследование `DragonStinger` и текущий runtime probe mode
Что делает:
label для фаз, которые зависят от dedicated controller state сверх простого action request
Как можно использовать:
маркировать unsafe или частично исследованные пути, которым перед имплементацией нужны controller snapshots

- `selector_owned`
Откуда:
текущая data model и архивная conservative placeholder policy
Что делает:
label для фаз, которые пока лучше оставить нативному selector’у
Как можно использовать:
безопасный default для еще не заземленных actions

- `action_only`
Откуда:
текущие bridge modes и архивное unsafe-probe research
Что делает:
bridge mode, который шлет только direct action request
Как можно использовать:
low-overhead execution path для действительно direct-safe actions

- `carrier_only`
Откуда:
текущие bridge modes и архивное unsafe-probe research
Что делает:
bridge mode, который шлет только carrier или pack
Как можно использовать:
staging или экспериментальные случаи, где дальнейший native follow-up должен произойти после carrier

- `carrier_then_action`
Откуда:
текущие bridge modes и архивное contract research
Что делает:
bridge mode, который сначала ставит carrier context, а затем шлет direct action path
Как можно использовать:
hybrid execution для context-heavy actions

- `priority-first`
Откуда:
текущий rollback selector’а и архивный анализ регрессии
Что делает:
selection rule, где ordering определяет raw phase `priority`, а contracts влияют только на execution
Как можно использовать:
возвращать детерминированное поведение, когда heuristic selector становится слишком непрозрачным

- `assumed_minimum_job_level`
Откуда:
текущий runtime fallback и архивные logs по blocked phases
Что делает:
диагностический fallback, означающий, что runtime не смог подтвердить реальный job level
Как можно использовать:
telemetry и guardrail diagnostics
Что важно:
это не замена настоящему job level

- `attack_populated`
Откуда:
classification из output-bridge burst
Что делает:
label decision pool, означающий, что attack-oriented packs присутствуют в `MainDecisions`
Как можно использовать:
разводить проблему admission/output и проблему отсутствующей decision population

- `no_pack_population`
Откуда:
classification из output-bridge burst
Что делает:
label decision pool, означающий, что в просканированной популяции не найдено pack-bearing decisions
Как можно использовать:
находить пустые или недоинструментированные decision windows

- `common_utility_output`
Откуда:
classification из output-bridge burst и текущая интерпретация output
Что делает:
label output для locomotion и utility-like packs, requests и nodes
Как можно использовать:
отделять небоевой output от job-specific и attack-like output

- `job_specific_output_candidate`
Откуда:
classification из output-bridge burst
Что делает:
label output, означающий, что текущие surfaces содержат job-specific pack или node tokens
Как можно использовать:
детектировать правдоподобный боевой output без хардкода на одну конкретную анимацию

- `executing_decision_other`, `enemy_list_other`, `front_target_list_other`, `in_camera_target_list_other`
Откуда:
classifications из target-publication burst
Что делает:
labels publication mode, которые показывают, какой target source сейчас несет `other` enemy target
Как можно использовать:
выбирать fallback roots по реально наблюдаемой live publication, а не по теории

#### Каталог lifecycle-labels и skip reasons

- `potential`
Откуда:
текущий дизайн skill-lifecycle cache
Что делает:
label для навыков, которые существуют в matrix, но еще не прошли unlock requirements
Как можно использовать:
разводить “навык известен данным” и “навык уже можно открывать”

- `unlockable`
Откуда:
текущий skill-lifecycle cache и research по progression
Что делает:
label для навыков, у которых уже выполнен job-level gate
Как можно использовать:
показывать, что навык уже должен появляться для покупки или дальнейших ownership checks

- `learned`
Откуда:
текущий skill-lifecycle cache и skill-state research
Что делает:
label для навыков, которые реально изучены или принадлежат актеру
Как можно использовать:
жестко не пускать в combat candidates навыки, которыми актер не владеет

- `equipped`
Откуда:
текущий skill-lifecycle cache и research по equip-state
Что делает:
label для навыков, которые сейчас стоят в слотах
Как можно использовать:
ограничивать selector активным боевым loadout актера

- `combat_ready`
Откуда:
текущий дизайн skill-lifecycle cache
Что делает:
финальный staged label, означающий, что навык изучен, экипирован и сейчас runtime-legal
Как можно использовать:
дешевый selector-facing summary вместо повторной проверки всех gates в combat hot path

- `bridge_mode`
Откуда:
текущий combat bridge и архивная нормализация контрактов
Что делает:
runtime execution-mode label, который выводится из phase contract
Как можно использовать:
логировать и сравнивать, как bridge реально пытался исполнять выбранную фазу

- `invalid_target_identity`
Откуда:
session logs и архивные target-gate failures
Что делает:
skip reason, который появляется, когда резолвнутый target схлопывается в `self`, `player` или другую недопустимую identity
Как можно использовать:
разводить отсутствие target publication и плохую target classification

- `skill_not_learned`
Откуда:
текущий lifecycle-backed skill gate
Что делает:
skip reason, который появляется, когда phase требует skill, которым актер реально не владеет
Как можно использовать:
доказывать lifecycle failure до того, как обвинять target или output logic

- `skill_not_equipped`
Откуда:
текущая и архивная skill-gate telemetry
Что делает:
skip reason, который появляется, когда required skill изучен, но не стоит в слотах
Как можно использовать:
разводить проблемы loadout и более глубокие execution problems

- `skill_not_enabled`
Откуда:
текущая skill-gate telemetry
Что делает:
skip reason, который появляется, когда required skill экипирован, но не разрешен текущим skill context
Как можно использовать:
находить runtime legality failures после успешных ownership и equip checks

- `skill_not_available`
Откуда:
текущая skill-gate telemetry и example-mod availability checks
Что делает:
skip reason, который появляется, когда skill в принципе разрешен, но недоступен в текущих игровых условиях
Как можно использовать:
отделять volatile combat gating от стабильного lifecycle state

- `job_level_above_assumed_minimum`
Откуда:
архивные logs по blocked phases и текущая fallback diagnostics
Что делает:
skip или warning reason, который показывает, что phase требовал более высокий уровень, чем fallback runtime смог подтвердить
Как можно использовать:
помечать unresolved progression data, не выдавая fallback level за настоящий progression

#### Каталог исследовательских инструментов

- `Content Editor`
Откуда:
внешний tool mod, который уже использовался в проектном research
Что делает:
главная среда live inspection для CE console scripts, AI overview, blackboard viewers и direct dumps
Как можно использовать:
интерактивно исследовать engine state без shipping probes в product runtime

- `ce_find(...)`
Откуда:
console workflow внутри Content Editor
Что делает:
ищет engine-side objects, types, fields и resources через CE environment
Как можно использовать:
быстро находить surface до написания отдельного extractor

- `ce_dump(...)`
Откуда:
console workflow внутри Content Editor
Что делает:
пишет structured CE inspection output в файл
Как можно использовать:
получать повторяемые evidence captures для архива и оффлайн compare

- `DD2_DataScraper`
Откуда:
внешний research tool из utility pack
Что делает:
bulk one-shot exporter для больших data snapshots
Как можно использовать:
выносить тяжелый discovery и catalog extraction из product runtime

- `Nick's Devtools` и `_NickCore`
Откуда:
внешний dev-only tooling, который загружался во время исследования
Что делает:
дают bounded live tracing и вспомогательную dev infrastructure
Как можно использовать:
включать только для узких live traces, когда CE scripts и dumps уже не отвечают на вопрос

- `Skill Maker`
Откуда:
внешний example mod, использованный как reference set
Что делает:
дает reference catalog action names, skill metadata и user-facing datasets
Как можно использовать:
заземлять naming и interpretation skill IDs без выдумывания собственной номенклатуры

- `docs/ce_scripts/*`
Откуда:
наш текущий research layer внутри репозитория
Что делает:
содержит одноразовые и burst-oriented extractor scripts, которые пишут evidence в файл
Как можно использовать:
держать исследование вне product runtime и обновлять документацию по воспроизводимым file outputs

# KNOWLEDGE_BASE_EN

## Reading guide

This file is now meant to be read in three layers:

1. invariants and current conclusions
2. structured catalogs with provenance, purpose, and general use
3. historical narrative and archive notes

Catalog rule:

- if an identifier is important enough to influence design, runtime behavior, or research workflow, it should appear in a structured catalog entry somewhere in this file
- narrative sections may still mention the same identifier, but the catalog entry is the place that defines what it is and where it came from

## Explanation

### Project model

Project invariant:

`unlock != equipment != skills != combat runtime != pawn combat context != AI parity`

This means:

- unlock alone is not a combat fix
- visible guild access is not proof of working AI
- a live controller is not proof of a working job-specific combat path

### Current project split

The repository now follows one strict split:

- `mod/` contains product runtime code
- `docs/ce_scripts/` contains research scripts

Default policy:

- `mod = implementation`
- `CE scripts = research`

### Source-of-truth order

When sources disagree, trust them in this order:

1. CE outputs written to file
2. current product runtime behavior
3. direct engine data inspection
4. historical git documentation
5. theory and guesses

### Current product runtime

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

### Current unlock state

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

### Historical findings preserved from pre-cleanup research

The removed research layer had already established several useful points that remain relevant:

- `Job07` in the engine is real, not fictional
- `Job07` could briefly approach `Job01` and then degrade again
- the weaker `Job07` state looked more like under-population or admission loss than complete absence
- broad getter-heavy probing was expensive and could trigger FPS collapse and REFramework exceptions

These findings are historical context now, not the active implementation path.

### External research tooling

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

### Current implementation pivot

The project now treats native `MainDecisions` restoration for `main_pawn Job07` as a background hypothesis instead of the critical implementation path.

Current working direction:

- keep native ownership of target publication, navigation, safety states, and already-present hybrid output
- treat the missing `Job07` attack cluster as a practical under-population problem rather than a near-term restoration target
- build a narrow synthetic attack adapter that only wakes up after a bounded `synthetic_stall` window with a live enemy target
- keep `execution_contracts` as the execution backend for that adapter instead of trying to make contracts replace native decision population

### External collaborator handoff snapshot (`2026-03-29`)

Current product runtime status:

- unlock is restored through runtime bit mirroring plus the narrow guild-side `_EnablePawn` override
- the synthetic `Job07` adapter now reaches real `Job07` execution on `main_pawn`, not only common locomotion
- latest live traces already show `ch300_job07_Run_Blade4.user`, `ch300_job07_RunAttackNormal.user`, `ch300_job07_MagicBindLeap.user`, and repeated `Job07_ShortRangeAttack`
- `DragonStinger` is blocked by default through a data-driven stability gate because direct live execution repeatedly crashed in `app.Job07DragonStinger.update`
- product runtime now also keeps a conservative `min_job_level` gate even when level is only known as `assumed_minimum_job_level`; older notes that argued against this are historical research conclusions, not current product behavior
- the current blocker is no longer first admission into combat; the blocker is close-contact continuity and hit conversion after the first successful engage, because landing or recovery output plus `native_output_backoff_active` still push the pawn back out of follow-through too easily

Important live evidence for handoff:

- `PawnHybridVocationsAI.session_20260329_080636.log`
- `PawnHybridVocationsAI.nicktrace_20260329_080636.log`
- `actor_burst_combat_trace_sigurd_job07_20260328_145935.json`
- `actor_burst_combat_trace_sigurd_job07_20260328_145907.json`

Current ask for the `_NickCore` author:

- validate why `MagicBindLeap` and `Job07_ShortRangeAttack` already execute but still convert poorly into real damage
- inspect whether execution-layer target continuity, lock-on continuity, or hit-confirm context is missing between `setBBValuesToExecuteActInter(...)` and the later `requestActionCore(...)`
- keep `_NickCore` as a dev-only tracer and reference surface, not as a hard product dependency

### Code audit snapshot (`2026-03-29`)

Strengths:

- product runtime and CE research are now cleanly separated
- scheduler timestamps are only committed after successful scheduled runs
- `main_pawn` data now has a shared stable snapshot that progression, unlock, combat, and the dev tracer can all reuse
- cached reflected-field readers, method fallbacks, pack/path/name/node/collection helpers, and reusable skill/job accessors now live in one shared `core/access.lua` layer instead of drifting across modules
- runtime scheduling and cross-module state now live in one shared `core/runtime.lua` layer, and `_NickCore` remains optional dev-only instrumentation rather than a hard product dependency
- `execution_contracts`, `vocations`, `hybrid_combat_profiles`, and the `_NickCore` tracer are data-driven enough to support outside collaboration

Current structural risks:

- `game/hybrid_combat_fix.lua` still centralizes context resolution, target normalization, output classification, support-heal guards, skill gating, stage routing, selection scoring, bridge execution, quarantine, telemetry, and logs in one roughly `3.6k` line module
- deep target/context helpers are still concentrated inside `game/hybrid_combat_fix.lua`; readers and generic runtime surfaces are now shared, but enemy-target bridging and combat-context shaping are not yet split into their own modules
- `allow_unmapped_skill_phases = true` is now documented and logged more honestly, but it is still intentionally narrower than its broad name suggests: `selector_owned` contracts remain blocked as `selector_owned_unbridgeable`
- hot combat target resolution still contains optional `resolve_game_object(..., true)` and component-based fallback paths, so dirty combat frames remain more fragile than they should be
- the repository still has no automated Lua syntax or regression harness; in-game validation remains the main safety net

Recommended refactor order:

1. split `game/hybrid_combat_fix.lua` into smaller runtime modules such as `context`, `target`, `gates`, `selector`, and `bridge`
2. keep `core/access.lua`, `core/runtime.lua`, and `data/vocations.lua` as the only shared source-of-truth layers instead of reintroducing per-module helpers
3. split enemy-target bridging and combat-context shaping into explicit runtime helpers instead of continuing to grow those layers inside `game/hybrid_combat_fix.lua`
4. extract close-contact hold and hit-conversion logic into an explicit follow-through module instead of continuing to grow generic selector code
5. keep `_NickCore` tracing optional and external, with the product mod consuming only the minimum dev-only callbacks

### Confirmed combat findings

#### `main_pawn`

Confirmed:

- `main_pawn` resolves reliably enough for runtime inspection
- progression state, current job, and baseline runtime context are readable

#### `Job01`

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

#### `main_pawn Job07`

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

#### `Sigurd Job07`

Valid `Sigurd` control traces now exist.

Confirmed:

- `Sigurd` enters real `Job07`-specific NPC packs
- `Sigurd` enters real `Combat.Job07_*` node families
- the primary decision module is `app.ThinkTableModule`
- `DecisionExecutor` and `ExecutingDecision` are absent in the observed `Sigurd Job07` pipeline

Observed pack examples:

- `ch300_job07_SideWalkB_Blade4`
- `ch300_job07_SideWalkL_Blade4`
- `ch300_job07_SideWalkR_Blade4`
- `ch300_job07_SkyDive`
- `ch300_job07_MagicBindLeap`
- `ch300_job07_Run_Blade4`
- `ch300_job07_RunAttackNormal`
- `ch300_job07_QuickShield`
- `ch300_job07_SpiralSlash`

Observed node examples:

- `Job07_ShortRangeAttack`
- `Job07_MagicBindJustLeap`
- `Job07_MagicBindComplete`
- `Job07_SkyDive`
- `Job07_SkyDiveLanding`
- `Job07_SpiralSlash`

#### Decision pipeline architecture

Focused CE compares now show a structural split:

- `main_pawn Job07` is routed through the pawn `app.DecisionEvaluationModule` pipeline
- `Sigurd Job07` is routed through the NPC `app.ThinkTableModule` pipeline
- `ThinkTableModule` was not found near the observed `main_pawn` decision chain in the tested scenes
- the earlier `selector / admission / context` question is now narrowed to a pawn-specific decision-content or decision-output question

#### Combat main-decision population

Focused combat captures now show a second, stronger split inside the pawn pipeline itself:

- outside combat, selected-job-only snapshots can still look identical between `main_pawn Job01` and `main_pawn Job07`
- in combat, `main_pawn Job01` repeatedly exposes `42` `MainDecisions`
- in combat, `main_pawn Job07` repeatedly exposes only `11` `MainDecisions`
- across repeated captures, `main_pawn Job07` contributes no unique combat `scalar_profile` or `combined_profile`
- the observed `main_pawn Job07` combat `MainDecisions` are a strict subset of the observed `main_pawn Job01` combat `MainDecisions`
- the remaining blocker is therefore already visible inside the pawn `DecisionEvaluationModule` combat decision population

#### Combat semantic split inside `MainDecisions`

The semantic compare sharpens the same conclusion:

- repeated semantic captures show `main_pawn Job01` at `47-48` combat `MainDecisions`
- repeated semantic captures show `main_pawn Job07` at `11` combat `MainDecisions`
- `main_pawn Job07` contributes no unique combat `semantic_signature`; all observed `Job07` semantic signatures are already present in `Job01`
- the retained `Job07` combat layer is dominated by common movement / carry / talk / catch / cliff / keep-distance behavior
- `main_pawn Job07` still surfaces no observed `Job07_*` action-pack identities in these combat captures
- `main_pawn Job01` includes many additional attack-oriented packs and behaviors that do not survive into combat `Job07`, including multiple `Job01_Fighter/*` packs and several `GenericJob/*Attack*` packs
- the reduced `Job07` combat layer also loses much of the richer `EvaluationCriteria`, `TargetConditions`, and `SetAttackRange` start/end-process population seen in combat `Job01`

### Strengthened conclusions

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

### Weakened or rejected conclusions

These older conclusions are no longer active:

- "`Job07` is absent for `main_pawn`"
- "`ce_dump=nil` proves the absence of `Job07ActionCtrl`"
- "`target kind mismatch` is always the root cause"
- "`getter` alone proves a live attack path"

### Current strongest hypothesis

Current working hypothesis:

- `main_pawn Job07` does not fail inside the NPC `ThinkTableModule` path because it is not using that path in the observed scenes
- the pawn `DecisionEvaluationModule` content for combat `Job07` is not simply different; it is under-populated versus combat `Job01`
- the next question is which missing attack-oriented combat `MainDecisions` correspond to the lost `Job07` combat behavior and how that reduction propagates into evaluation output or action output
- the strongest local candidates are the missing `Job01_Fighter/*`, `GenericJob/*Attack*`, and `SetAttackRange`-bearing combat decisions that appear in combat `Job01` but not in combat `Job07`

### Vocation definition surface

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

### Vocation progression matrix

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
- the same canonical matrix now exists in runtime code as `data/vocations.lua`, so the mod no longer needs to reassemble these ids from scattered notes or one-off profile patches
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

### Confirmed implementation direction

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

### Execution contracts and unsafe skill probes

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

### Latest runtime stabilization note

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

### Runtime target follow-up

- the successful `2026-03-26 22:58:44` session still had one stable enemy target, while the stalled `2026-03-26 23:27:31` session had no stable enemy target and alternated between `self` and `nil`
- runtime target diagnosis now logs `ExecutingDecision`, `AIBlackBoardController`, `HumanActionSelector`, `CommonActionSelector`, `OrderTargetController`, and `JobXXActionCtrl` separately so target regressions can be traced before phase execution
- old CE compare captures already showed a useful asymmetry for `main_pawn Job07`: `ExecutingDecision.Target` was live while `AIBlackBoard`, `HumanActionSelector`, and `Job07ActionCtrl` target surfaces were still `nil`, so selector-facing roots should not be treated as the primary historical target contract
- the same older CE and git research also exposed `LockOnCtrl`, `AIMetaController`, and cached pawn controllers such as `CachedPawnOrderTargetController`, so these are now the most grounded secondary target roots to restore before probing wider battle/request surfaces
- the older relevant combat session still showed one grounded fact: `executing_decision_target` could already expose a valid `via.GameObject` while the chosen character still resolved to `self`, so target identity remained a confirmed blocker at least for that build
- however, later runtime patches replaced several hot-path `get_GameObject` calls with field-backed `resolve_game_object(..., false)` resolution, so newer `re2_framework_log.txt` sessions can no longer be used as a clean negative test for the `via.Component.get_GameObject` hypothesis
- `docs/ce_scripts/main_pawn_target_surface_screen.lua` now exists as a focused CE Console extractor for target-bearing roots, writing `main_pawn_target_surface_<timestamp>.json` with `ExecutingDecision`, `LockOnCtrl`, `AIMetaController`, cached pawn controllers, selectors, `JobXXActionCtrl`, `CurrentAction`, and `SelectedRequest`
- three fresh `main_pawn_target_surface` captures added a stronger comparison point: both `Job07` and `Job01` can expose a valid enemy directly through `ExecutingDecision.<Target>.<Character>`, while `LockOnCtrl`, `AIBlackBoard.Target`, selectors, and `JobXXActionCtrl.Target` still stay empty in the same samples
- those same captures also show that `app.PawnOrderTargetController` is not actually empty; it carries `_EnemyTargetNum`, `_EnemyList`, `_FrontTargetList`, `_InCameraTargetList`, and `_SensorHitResult`, which means the controller is target-bearing through collections rather than through a plain `Target` field
- because of that, the runtime target fallback now needs collection-based extraction from `PawnOrderTargetController`, not only more `Target/CurrentTarget/OrderTarget` probing
- inference: the latest game-side session log still does not print `ai_meta_controller` or cached-controller probes, which suggests the game run was likely using an older synced mod build than the current local target-root patch
- the next `Job07` target-surface triplet (`2026-03-27 00:22:52`, `00:22:55`, `00:22:58`) refined the same picture: `ExecutingDecision` oscillated between `self` and a real enemy, `PlayerOfAITarget` consistently resolved the player plus owner-self pair, and selector-facing roots still stayed empty
- those same captures also reveal the concrete collection item types inside `PawnOrderTargetController`: `_EnemyList -> via.GameObject`, `_FrontTargetList/_InCameraTargetList -> app.VisionMarker`, `_SensorHitResult -> app.PawnOrderTargetController.HitResultData`
- because of that, both runtime and CE extraction now need special handling for `VisionMarker.<CachedCharacter>` and `HitResultData.Obj`, not only plain `Character` or `Target` fields
- the next `Job07` triplet (`2026-03-27 06:58:07`, `06:58:12`, `06:58:15`) finally grounded the strongest fallback root so far: `_EnemyList` no longer looked merely “non-empty”; each first item was a direct `via.GameObject` that resolved an `other` enemy `app.Character` even when `ExecutingDecision` had already flipped back to `self`
- the same triplet also showed no field-vs-method divergence for `ExecutingDecision` itself: `game_object_paths.target_field` and `game_object_paths.target_method` both resolved the same `via.GameObject`, so that root currently points more strongly to identity instability than to `GameObject` access skew
- `VisionMarker` stayed weaker in these exact captures because `<CachedCharacter>` was still `nil`, while `get_GameObject()` returned a `via.GameObject`; `HitResultData` exposed `Obj` in reflective field snapshots, but ordinary indexed field access still missed it, which means `SensorHitResult` will require reflection-backed named field reads if it is promoted into runtime fallback
- because of that, the runtime target selector now treats `cached_pawn_order_target_controller` and other order-target-controller roots as the first fallback tier before wider blackboard and selector surfaces whenever `ExecutingDecision` falls back to `self` or `nil`
- the runtime also now allows a narrower method-backed `GameObject` retry only when field-backed target extraction failed to produce a usable enemy character, which gives `VisionMarker` a live path without fully restoring hot-path `get_GameObject` dependence everywhere
- `HitResultData.Obj` is still a second-tier path: runtime `resolve_game_object(...)` now supports reflection-backed named field reads, but `_SensorHitResult` should only become a primary fallback after a live combat run proves it contributes usable enemy characters instead of only extra noise
- the next `Job07` triplet (`2026-03-27 07:17:05`, `07:17:10`, `07:17:12`) exposed a different target mode rather than disproving the earlier `_EnemyList` result: `_EnemyList`, `_FrontTargetList`, and `_InCameraTargetList` were all empty, while `_SensorHitResult` jumped to `49` entries
- each first `HitResultData` entry in that triplet still exposed `Obj -> via.GameObject` in reflective field snapshots, so `_SensorHitResult` is now a validated sensor-side carrier of scene objects even though the CE extractor did not yet promote those entries into chosen enemy characters
- the paired runtime log for that window was again not a true combat loop; it stayed in `special_output_state` with `Common/HumanTurn_Target_Talking`, so this triplet should currently be treated as a non-combat or transitional target mode rather than as the final fallback design point for attack execution
- because the game-side state is not visually distinguishable enough to separate “true combat stall” from `HumanTurn_Target_Talking` by eye, the runtime has now been intentionally returned to a more method-enabled `via.GameObject` baseline close to the pre-disable period; the next screening should compare against that baseline rather than against the stricter field-only phase
- the next post-rollback pair (`2026-03-27 07:27:29`, `07:27:34`) exposed a third target mode: all `PawnOrderTargetController` collections were empty again, while `ExecutingDecision` flipped from `self` to `other` between the two captures without any collection help at all
- the paired runtime session for that window was the first useful method-enabled baseline after rollback, and it still stalled mostly on `executing_decision_unresolved`; the target probe summary also showed `cached_pawn_order_target_controller_target_unresolved`, so the live blocker there was not bad identity inside a populated collection but full absence of exposed target state at that moment
- because the in-game pose alone is not reliable enough to distinguish a true combat stall from `HumanTurn_Target_Talking` or other utility-like transitions, the next grounded screening tool is now `docs/ce_scripts/main_pawn_target_publication_burst.lua`, which samples `ExecutingDecision`, `selected_request`, `current_action`, `full_node`, and `PawnOrderTargetController` collections over time instead of freezing one frame

### Archived research layer

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

### Performance and network boundary

Still active rules:

- prefer compact summaries over broad reflective scans
- avoid getter-heavy probing in the product hot path
- keep the core branch local-runtime-first
- keep online, rental, and pawn-share logic out of the main implementation branch

### Archived manual Content Editor path

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

## How-to

### How to research now

Use CE Console scripts.

Standard cycle:

1. define one concrete question
2. choose one script for that question
3. write the result to file
4. compare it with a baseline or control actor
5. update this file first
6. update `ROADMAP.md` only if priorities changed
7. update `CHANGELOG.md` when code or documentation changed

### How to judge a conclusion

A conclusion is strong enough for this file only if:

- the script wrote a structured result to file
- the result is reproducible
- the wording follows directly from recorded fields
- conflicting older wording was removed or explicitly weakened

### How to decide whether hooks may return

Do not return to hooks by default.

Return is allowed only if all of the following are true:

- the question is already narrowed to one runtime transition
- screen and burst CE scripts do not capture it
- without hooks the cause cannot be demonstrated
- the need is documented before implementation starts
- the product branch stays isolated from broad research logging

## REFramework / RE Engine Impact Taxonomy
This section merges the cross-mod method taxonomy, recurring patterns, and per-mod mapping from the dedicated mod-analysis pass. It complements the project-specific notes in this repository and stays close to the existing reference flow on purpose.

### Scope
This knowledge base aggregates the local `temp_*.md` reports for eleven Dragon's Dogma 2 mods and groups the findings by method of affecting REFramework and RE Engine.

### Taxonomy Of Techniques
#### 1. Runtime bootstrap and lifecycle callbacks
- Core pattern: use `reframework/autorun/*.lua` as the entry point and attach logic to lifecycle callbacks.
- Common callbacks: `re.on_application_entry(...)`, `re.on_pre_application_entry(...)`, `re.on_frame(...)`, `re.on_draw_ui(...)`, `re.on_script_reset(...)`, `re.on_config_save(...)`.
- Strong examples: `NickCore`, `ScriptCore`, `Bestiary`, `Dullahan`, `Skill Maker`, `JobChanger`, `HiredPawnOverride`, `Nick's Devtools`.

#### 2. Method hooks and original-call control
- Core pattern: intercept managed/native methods with `sdk.hook(...)`.
- Typical interventions:
  - mutate arguments in pre-hooks
  - force return values in post-hooks
  - cancel original logic with `sdk.PreHookResult.SKIP_ORIGINAL`
  - carry state across hook stages with `thread.get_hook_storage()`
- Strong examples:
  - `NickCore` for generalized hook buses
  - `SkillUnlocker` and `Pawns Use All Skills` for minimal boolean gate bypasses
  - `Bestiary`, `Dullahan`, `Skill Maker`, `Nick's Devtools` for broad gameplay interception

#### 3. Shared abstraction cores
- Core pattern: centralize fragile SDK/hook logic into reusable utility layers.
- `NickCore` provides:
  - hook buses in `fns.on_*`
  - player-state caching
  - startup/readiness checks
  - install markers
  - timers
- `ScriptCore` provides:
  - hotkeys
  - ImGui helpers and themes
  - reflection/object helpers
  - cloning and value-type writing
  - file picker
  - physics casts
  - dynamic motion-bank helpers

#### 4. Live object and backing-field mutation
- Core pattern: directly edit live engine objects instead of or in addition to hooks.
- Typical targets:
  - `DamageInfo`
  - `AttackUserData`
  - `PawnDataContext`
  - equipment/storage data
  - motion layers
  - shell request structures
  - generate/prefab structures
- Strong examples:
  - `HiredPawnOverride` mutates pawn equipment, personality, specialization, and voice data
  - `Bestiary` and `Dullahan` mutate damage/status/shell state
  - `Skill Maker` mutates motion, VFX, target, speed, corpse, and relationship state

#### 5. UI and tooling injection
- Core pattern: inject in-game editors, debug panels, tracers, and control surfaces with `imgui`.
- Typical uses:
  - configuration menus
  - hotkey editing
  - search/filter UIs
  - live authoring tools
  - tracing toggles
  - devtool panels
- Strong examples:
  - `Skill Maker` editor
  - `JobChanger`
  - `HiredPawnOverride`
  - `Nick's Devtools`
  - `Dullahan` config and UI patches

#### 6. Input and HID capture
- Core pattern: poll keyboard/mouse/gamepad and redirect or suppress input.
- Key entry points:
  - `via.hid.Keyboard`
  - `via.hid.Gamepad`
  - `via.hid.Mouse`
  - `re.on_application_entry("UpdateHID", ...)`
  - player input processor methods
- Strong examples:
  - `ScriptCore` hotkey system
  - `JobChanger` hotkey usage
  - `Skill Maker` input remapping
  - `Nick's Devtools` input suppression in position/flight tools

#### 7. Runtime spawning and resource injection
- Shells and projectiles:
  - `app.ShellManager.requestCreateShell(...)`
  - `app.Shell.checkFinish()`
  - `sdk.create_userdata("app.ShellParamData", path)`
- Enemies and prefabs:
  - `app.GenerateManager.requestCreateInstance(...)`
  - `sdk.create_instance("app.GenerateInfo.GenerateInfoContainer")`
  - `sdk.create_instance("via.Prefab")`
  - `sdk.create_instance("app.PrefabController")`
  - `sdk.create_instance("app.InstanceInfo")`
- Effects and sound:
  - `via.effect.script.ObjectEffectManager2.requestEffect(...)`
  - Wwise trigger surfaces
- Motion resources:
  - `via.motion.DynamicMotionBank`
  - `via.motion.MotionListResource`
- Strong examples:
  - `Bestiary`
  - `Dullahan`
  - `Skill Maker`
  - `Nick's Devtools`
  - `ScriptCore` as helper infrastructure

#### 8. Combat, damage, status, and shell pipelines
- Common hook surfaces:
  - `app.HitController.damageProc(...)`
  - `app.HitController.calcDamageValue(...)`
  - `app.ExceptPlayerDamageCalculator.calcDamageValueDefence(...)`
  - `app.HitController.calcRegionDamageRate(...)`
  - `app.HitController.calcDamageReaction(...)`
  - `app.StatusConditionCtrl.reqStatusConditionApplyCore(...)`
  - `app.StatusConditionInfo.applyStatusConditionDamage(...)`
- Typical interventions:
  - change raw damage
  - patch reaction type or stagger
  - recolor or alter shell behavior
  - rewrite status application
  - bypass stamina costs
- Strong examples:
  - `NickCore`
  - `Bestiary`
  - `Dullahan`
  - `Skill Maker`
  - `Nick's Devtools`

#### 9. AI, action, relationship, and target control
- Common entry points:
  - `app.ActionManager.requestActionCore(...)`
  - `app.AIBlackBoardExtensions.setBBValuesToExecuteActInter(...)`
  - `app.BattleRelationshipHolder.getRelationshipFromTo(...)`
  - `app.TargetController.setTarget(...)`
  - monster action selector methods
- Typical uses:
  - force skill/action selection
  - rewrite summon behavior
  - change faction/ally/enemy relations
  - redirect target logic
  - inject AI behavior packs
- Strong examples:
  - `NickCore`
  - `Bestiary`
  - `Dullahan`
  - `Skill Maker`
  - `Nick's Devtools`

#### 10. Data-driven execution and persistence
- Core pattern: keep runtime generic while pushing authored content into JSON/Lua data tables.
- Common tools:
  - `json.load_file(...)`
  - `json.dump_file(...)`
  - `fs.glob(...)`
- Strong examples:
  - `Skill Maker` node graphs and content catalogs
  - `HiredPawnOverride` item catalog plus per-pawn config
  - `JobChanger` hotkey config
  - `ScriptCore` hotkey persistence
  - `Dullahan` config toggles

#### 11. Static RE Engine asset replacement
- Core pattern: replace serialized RE Engine assets instead of scripting at runtime.
- Observed form:
  - `KPKA` `.pak`
  - overridden `.user.2` generation tables
- Strong example:
  - `Durnehviir`

### Concrete Entry Points
- Core managers and singletons:
  - `app.CharacterManager`, `app.PawnManager`, `app.ItemManager`, `app.GuiManager`, `app.ShellManager`, `app.GenerateManager`, `app.BattleManager`, `app.BattleRelationshipHolder`, `app.QuestManager`, `app.WeatherManager`, `app.EnemyManager`, `via.SceneManager`, `via.Application`, `via.physics.System`
- High-value methods:
  - `app.ActionManager.requestActionCore(...)`
  - `app.ShellManager.requestCreateShell(...)`
  - `app.GenerateManager.requestCreateInstance(...)`
  - `app.HitController.calcDamageValue(...)`
  - `app.HitController.calcDamageReaction(...)`
  - `app.StatusConditionCtrl.reqStatusConditionApplyCore(...)`
  - `app.AIBlackBoardExtensions.setBBValuesToExecuteActInter(...)`
  - `app.BattleRelationshipHolder.getRelationshipFromTo(...)`
  - `app.GuiManager.OnChangeSceneType`
  - `app.HumanSkillAvailability.*`
  - `app.HumanSkillContext.*`

### Recurring Patterns
- One shared core owns hooks; feature mods subscribe to it.
- Per-frame caches are used for unstable or late-spawned game objects.
- Request-ID or address-keyed tables are used for shell/enemy/pawn tracking.
- Reuse of shipped `.user` resources is preferred over inventing all content from scratch.
- Minimal mods often succeed by hooking only 1-7 validation methods.
- Large mods combine hook logic with in-game tooling and JSON persistence.

### Reusable Implementation Patterns
- `NickCore` event bus for multi-mod composition.
- `ScriptCore` hotkeys, file picker, reflection, clone, physics, and ImGui helpers.
- Spawn pipelines for shells and prefabs.
- Boolean and numeric validator bypass with post-hook return forcing.
- Apply-until-success per-frame mutation for transient actors.
- Action forcing via `requestActionCore(...)`.
- AI pack injection through `app.ActInterPackData`.
- Static `.pak` replacement for deterministic data edits.

### Per-Mod Mapping
- `NickCore`: low-level hook bus, startup gate, timers, player cache.
- `ScriptCore`: shared hotkeys, reflection, ImGui/file tools, physics, motion-bank helpers.
- `Bestiary`: enemy AI/moveset overhaul, shell/effect spawning, variant systems, Dragonsplague/Silence rewrites.
- `Dullahan`: modular vocation overhaul with shell-driven skills and UI patching.
- `Durnehviir`: `.pak`-based encounter table replacement.
- `Skill Maker`: data-driven skill editor/runtime with shells, summons, AI packs, and motion/VFX control.
- `SkillUnlocker`: stacked validation bypass hooks for skills.
- `HiredPawnOverride`: per-frame equipment and pawn-attribute mutation.
- `JobChanger`: job-switch utility with hotkeys and auto-equip.
- `Nick's Devtools`: tracing, spawning, shell/effect/audio testing, combat and world-state tools.
- `Pawns Use All Skills`: ultra-minimal pawn skill-availability bypass.

## Reference

### Active CE scripts

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

### Required CE script properties

Each CE script must:

- solve one concrete task
- write output to file
- produce data suitable for compare and later documentation updates

### Current implementation files

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

- `mod/reframework/autorun/PawnHybridVocationsAI/core/runtime.lua`
Purpose:
shared runtime state, guarded execution, and interval scheduling
General use:
cache actor references, snapshots, and per-task timestamps without splitting runtime orchestration across multiple tiny files

- `mod/reframework/autorun/PawnHybridVocationsAI/core/log.lua`
Purpose:
session-log writer and log rotation
General use:
keep bounded diagnostics in production-like runtime without unbounded file growth

- `mod/reframework/autorun/PawnHybridVocationsAI/core/access.lua`
Purpose:
shared engine-access, reflection, runtime-surface, and skill/job helper layer
General use:
centralize risky engine calls, reflected fallbacks, pack/node lookup, collection access, and shared skill-state readers so gameplay modules stop carrying subtly different helper copies

- `mod/reframework/autorun/PawnHybridVocationsAI/core/execution_contracts.lua`
Purpose:
normalize `execution_contract` and `bridge_mode` semantics
General use:
keep selector data, combat profiles, and bridge logic on one shared classification system

- `mod/reframework/autorun/PawnHybridVocationsAI/data/vocations.lua`
Purpose:
canonical vocation registry for skill IDs, vocation bands, hybrid metadata, and progression hints
General use:
ground skill names, IDs, action prefixes, controller metadata, and hybrid-job lookups without scattering literal numbers or duplicate vocation tables through runtime code

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

### Historical native decision-pool signals

The earlier native-first branch repeatedly used these containers as safe structural signals:

- `_CurrentGoalList`
- `_CurrentAddDecisionList`
- `MainDecisions`
- `PreDecisions`
- `PostDecisions`
- `ActiveDecisionPacks`

They remain useful as historical reference even though the current research path is CE-first.

### 2026-03-26 addendum: hybrid custom-skill matrix

This short addendum records findings from `vocation_progression_matrix_20260326_214421.json` that remain useful beyond the immediate task.

- The confirmed hybrid `custom-skill` matrix is now grounded by the all-job band map below.
- The current confirmed all-job `custom-skill` bands are:
- `Job01 = 1..12`, `Job02 = 13..23`, `Job03 = 24..37`, `Job04 = 38..49`, `Job05 = 50..61`, `Job06 = 62..69`, `Job07 = 70..79`, `Job08 = 80..91`, `Job09 = 92..99`, `Job10 = 100`
- `Job07`: `70 = PsychoShoot`, `71 = FarThrow`, `72 = EnergyDrain`, `73 = DragonStinger`, `74 = QuickShield`, `75 = BladeShoot`, `76 = SkyDive`, `77 = Gungnir`, `78 = TwoSeconds`, `79 = DanceOfDeath`
- `Job08`: `80 = FlameLance`, `81 = BurningLight`, `82 = FrostTrace`, `83 = FrostBlock`, `84 = ThunderChain`, `85 = ReflectThunder`, `86 = AbsorbArrow`, `87 = LifeReturn`, `88 = CounterArrow`, `89 = SleepArrow`, `90 = SeriesArrow`, `91 = SpiritArrow`
- `Job09`: `92 = SmokeWall`, `93 = SmokeGround`, `94 = TripFregrance`, `95 = AttentionFregrance`, `96 = PossessionSmoke`, `97 = RageFregrance`, `98 = DetectFregrance`, `99 = SmokeDragon`
- `Job10`: `100 = Job10_00`
- The canonical data layer for this matrix now lives in `mod/reframework/autorun/PawnHybridVocationsAI/data/vocations.lua`
- For `Job07`, the first live-grounded custom skill should now be treated as `DragonStinger = 73`: it is confirmed in the enum, in `Job07Parameter`, and in live equip/enabled state for both `player` and `main_pawn`
- For `Job08`, the analogous first live-grounded custom skill is currently `FrostTrace = 82`
- `current_job_level` and per-job `getJobLevel(...)` can still resolve to `nil`, so base attacks must not be hard-gated on that signal
- `AbilityParam.JobAbilityParameters` should be read with `job_id - 1` priority; otherwise the hybrid augment layer shifts by one vocation

### Evidence inventory snapshot before log cleanup

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

### Aggregated findings from archived logs and JSON

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

### Grounded surface catalog

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

- `app.PawnManager._MainPawn` and `app.PawnManager.get_MainPawn()`
Provenance:
`DD2_Scraper/_meta_app_PawnManager.json`
Purpose:
grounded primary singleton surface for resolving the actual main pawn object
General use:
prefer as the first `main_pawn` acquisition root before falling back to `CharacterManager`-side helpers

- `app.PawnManager.get_PawnOrderTargetController()`
Provenance:
`DD2_Scraper/_meta_app_PawnManager.json`
Purpose:
grounded getter for the pawn order-target controller on the same singleton that owns `_MainPawn`
General use:
prefer when validating whether target-publication surfaces belong to the real main-pawn pipeline

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

- `app.AITargetGeneralPoint`
Provenance:
`usercontent/rsz/dd2.json` and `usercontent/cache/typecache.json`
Purpose:
grounded native target shape for general scene points and non-character targeting
General use:
treat as a first-class `AITarget*` root in runtime normalization instead of assuming only `app.AITargetGameObject` is valid

- `app.AITargetPosition`
Provenance:
`usercontent/rsz/dd2.json`, `usercontent/cache/typecache.json`, and CE target dumps
Purpose:
grounded native target shape for position-oriented AI requests
General use:
strong signal that the actor is navigating toward a point rather than directly targeting a character; useful for support/recovery and move-to-position guards

- `app.Human.<Job07ActionCtrl>k__BackingField` and `app.Human.get_Job07ActionCtrl()`
Provenance:
`DD2_Scraper/_meta_app_Human.json`
Purpose:
grounded `Job07`-specific action-controller surface on `app.Human`
General use:
safe job-specific foothold for `main_pawn Job07` inspection without inventing custom skill-side state

- `app.decision.condition.IsEnterTimingNonMaxMainPawnHP`
Provenance:
`usercontent/rsz/dd2.json`
Purpose:
native decision-condition type showing that low-HP main-pawn timing is a real engine-side admission concept
General use:
ground low-HP retreat or support heuristics in native decision architecture instead of treating them as a mod-only guess

- `app.HumanEnemyParameterBase.NPCCombatParamTemplate`
Provenance:
`usercontent/enums/app.HumanEnemyParameterBase.NPCCombatParamTemplate.json`
Purpose:
enumeration surface for native NPC combat templates including `Job07`, `Job07_6`, `Job07_7`, and `Job07_Master`
General use:
reference Sigurd-like or NPC-like combat archetypes without assuming the main pawn shares the same decision pipeline

- `app.MainPawnDataContext`
Provenance:
`usercontent/rsz/dd2.json`
Purpose:
schema-level main-pawn context type with favorability and persistent pawn-side data
General use:
ground future progression or pawn-context research in a real engine type rather than ad-hoc naming

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

### Engine data, skill-state, and execution-surface catalog

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

### Unlock, contract, and classification catalog

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

### Lifecycle and skip-reason catalog

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

### Output-state family catalog

- `Locomotion.*`
Provenance:
session logs, CE output bursts, and FSM node captures
Purpose:
family of baseline movement and navigation states such as `Locomotion.NormalLocomotion` and `Locomotion.Strafe`
General use:
normal pre-attack or combat-positioning window; usually a safe bridge-admission family

- `Common/*`
Provenance:
session logs, CE output bursts, and action-pack identity captures
Purpose:
family of shared utility, interaction, social, or non-vocation-specific states
General use:
separate true combat output from utility masking, talking, carry, sorting, treasure interactions, and other shared states
Important:
some `Common/*` states are valid hard non-combat blocks, while some talking-like windows may still need a narrow recovery rule

- `Damage.DmgShrink*`
Provenance:
CE output bursts and damage-side FSM node captures
Purpose:
family of hit-reaction or damage-recovery states such as `Damage.Damage_Root.DmgShrinkM`
General use:
short-lived recovery window after taking damage; may be a narrow bridge-admission family if a live enemy target still exists

- `Damage.DieCollapse`
Provenance:
CE output bursts and damage-side FSM node captures
Purpose:
collapse or death-like damage state
General use:
treat as a hard stop-state, not as a recoverable attack-admission window

### Research tooling and script catalog

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

- `DD2_Scraper/`
Provenance:
external dump directory under `reframework/data/DD2_Scraper`
Purpose:
offline metadata and roster export set containing singleton lists, `_meta_*` type snapshots, enum dumps, and skill parameter bundles
General use:
confirm engine surfaces and singleton ownership without adding new runtime probes

- `DD2_Scraper/all_singletons.json`
Provenance:
`DD2_Scraper`
Purpose:
catalog of exported singleton types such as `app.PawnManager`, `app.CharacterManager`, `app.BattleManager`, and related managers
General use:
choose grounded singleton entry points before guessing manager ownership in runtime code

- `DD2_Scraper/_meta_*.json`
Provenance:
`DD2_Scraper`
Purpose:
per-type field and method exports for classes like `app.PawnManager`, `app.Character`, `app.Human`, and `app.HitController`
General use:
validate getters, backing fields, and job-specific controller surfaces before writing reflection fallbacks

- `DD2_Scraper/skill_params.json`
Provenance:
`DD2_Scraper`
Purpose:
offline bundle of ability, job, level-up, and stamina parameter tables
General use:
background parameter reference when verifying skill or job datasets without scraping live runtime state

- `DD2_Scraper/character_roster.json`
Provenance:
`DD2_Scraper`
Purpose:
point-in-time roster snapshot for player, pawns, NPCs, and enemies
General use:
light roster sanity check
Caveat:
not reliable as a rich live-combat source; snapshots can be sparse or partially unresolved

- `usercontent/`
Provenance:
Content Editor support directory under `reframework/data/usercontent`
Purpose:
offline CE workspace containing RSZ schema exports, enum dumps, type caches, presets, and editor state
General use:
schema and tooling reference, not primary live gameplay evidence

- `usercontent/rsz/dd2.json`
Provenance:
`usercontent/rsz`
Purpose:
schema and import-surface export covering AI classes, `AITarget*` variants, decision-condition types, `Job07` classes, and main-pawn context types
General use:
confirm that a type or field exists in engine schema before assuming it in mod architecture

- `usercontent/enums/*.json`
Provenance:
`usercontent/enums`
Purpose:
focused enum exports such as `app.Character.JobEnum`, `app.CharacterData.JobDefine`, and `app.HumanEnemyParameterBase.NPCCombatParamTemplate`
General use:
ground job IDs, NPC template names, and combat-template labels without inventing local nomenclature

- `usercontent/dumps/enums_2026-03-24 20-59-33/*`
Provenance:
archived Content Editor enum dump inside `usercontent/dumps`
Purpose:
richer historical enum snapshot than the trimmed `usercontent/enums` subset
General use:
fallback source when a needed enum is absent from the shorter current export set

- `usercontent/cache/typecache.json`
Provenance:
`usercontent/cache`
Purpose:
large offline type index covering classes, generic containers, and many engine-side symbol names
General use:
fast discovery index for confirming whether a type family exists before deeper CE or runtime probing

- `usercontent/editor_settings.json`
Provenance:
Content Editor workspace state
Purpose:
stores CE UI state, recent selections, and embedded editor/script session data
General use:
recover operator workflow context
Caveat:
do not treat as live gameplay truth or authoritative runtime evidence

- `reframework/data/`
Provenance:
full top-level survey of the installed `reframework/data` tree on `2026-03-28`
Purpose:
working source map for everything currently emitted by CE, the product mod, offline dump tools, and dev-only helper mods
General use:
treat `ce_dump/` and `PawnHybridVocationsAI/logs/` as the primary live evidence layer, `DD2_Scraper/` and `usercontent/` as schema or reference layers, and the remaining top-level folders as mostly service or tool-state directories

- `reframework/data/ce_dump/`
Provenance:
Content Editor scripts and repo-local CE dump scripts
Purpose:
archive one-shot and burst JSON captures such as output-classification screens and target-publication bursts
General use:
primary point-in-time live evidence when validating target publication, output classification, or admission-family state
Caveat:
frame snapshots should be paired with session logs when timing-sensitive behavior is under investigation

- `reframework/data/PawnHybridVocationsAI/logs/`
Provenance:
product-runtime session telemetry
Purpose:
store the mod's own session logs, skip reasons, target-source probe summaries, and bridge-admission telemetry
General use:
primary runtime evidence for what the shipped mod actually saw and why it skipped or failed
Caveat:
if these logs disagree with `ce_dump/`, treat that as evidence of unstable runtime acquisition or normalization rather than assuming CE is wrong

- `reframework/data/NickCore/`
Provenance:
dev-only helper mod state
Purpose:
tiny state directory currently containing launch and script-reset markers
General use:
tooling sanity check only
Caveat:
not a gameplay-evidence source

- `reframework/data/NicksDevtools/`
Provenance:
dev-only helper mod configuration
Purpose:
store Nick's Devtools trace and visualization settings
General use:
operator config reference when reproducing an external trace session
Caveat:
not a gameplay-evidence source

- `reframework/data/reframework/`
Provenance:
current install tree
Purpose:
currently just an empty nested scaffold under `reframework/data`
General use:
ignore for project research unless a future tool actually starts writing files there

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

## External Mod Analysis: Bestiary (2026-04-01)

Source analyzed:
`E:\[Codex]\Dragons Dogma 2\Примеры модов\Bestiary-1196-2-0-5-1775046237`

### High-level conclusion

`Bestiary` does not "unlock hidden native monster spells" in a narrow sense.
It builds a custom combat-execution layer for enemies on top of `_NickCore` callback buses and REFramework hooks.

The mod makes enemies cast spells and use non-native-looking attacks by combining:

- native action requests through `ActionManager:requestActionCore(...)`
- raw motion swaps through `MotionLayer:changeMotion(...)`
- custom sequence nodes advanced frame-by-frame
- direct shell/projectile spawning through `app.ShellManager.requestCreateShell(...)`
- temporary AI / locomotion suppression while the custom sequence is running
- per-shell and per-hit mutation hooks for damage, color, collision, lifetime, element, and summon logic

So the real answer to "how does it make mobs cast?" is:

- it registers a handled enemy
- listens for native action requests or idle windows
- chooses a custom move from a moveset table
- starts an authored sequence
- steps through that sequence every frame
- injects native nodes, raw motions, effects, sounds, shells, summons, and damage edits at authored frames
- blocks most native interruptions until the sequence finishes or aborts

### File map

- Entry:
  - `reframework/autorun/Bestiary.lua`
- Core moveset runtime:
  - `Bestiary/MovesetHandler.lua`
  - `Bestiary/MovesetHandler/Setup.lua`
  - `Bestiary/MovesetHandler/Selection.lua`
  - `Bestiary/MovesetHandler/Executor.lua`
  - `Bestiary/MovesetHandler/NodeCore.lua`
  - `Bestiary/MovesetHandler/NodeHooks.lua`
  - `Bestiary/MovesetHandler/NodeShells.lua`
  - `Bestiary/MovesetHandler/NodeFX.lua`
  - `Bestiary/MovesetHandler/NodeAborts.lua`
  - `Bestiary/MovesetHandler/PreventInterrupts.lua`
- Shell runtime:
  - `Bestiary/ShellHandler.lua`
  - `Bestiary/ShellHandler/ShellHooks.lua`
  - `Bestiary/ShellHandler/ShellParams.lua`
  - `Bestiary/ShellHandler/ShellUdatas.lua`
- Spawning and utilities:
  - `Bestiary/EnemySpawner.lua`
  - `Bestiary/Utils.lua`
  - `Bestiary/Utils/*.lua`
- Side systems:
  - `Bestiary/VariantHandler.lua`
  - `Bestiary/SilenceRework.lua`
  - `Bestiary/DragonsplagueRework.lua`
- Enemy-authored movesets:
  - `Bestiary/Enemies/*.lua`
  - `Bestiary/EnemyVariants/*.lua`

### What `Bestiary.lua` actually does

- Loads side systems first:
  - `VariantHandler`
  - `SilenceRework`
  - `DragonsplagueRework`
- Reads config and conditionally loads enabled enemy and variant files.
- Rebuilds variant and moveset UI caches.
- Registers cleanup on:
  - character death
  - hit destruction
  - script reset
- Exposes a debug menu that can manually trigger authored moves on all currently handled enemies.

This means `Bestiary.lua` is mostly bootstrap and cleanup, not the actual combat brain.

### How enemy registration works

Primary function:
`Bestiary/MovesetHandler/Setup.lua -> setup.setup_character(params)`

That function installs four important layers:

1. `on_pre_action_request`
- detects matching enemy species by `chName`
- lazily creates `characterInfo`
- watches native requested nodes
- optionally replaces them with custom moves

2. `on_frame`
- refreshes live info like node, position, target, target distance
- if not already inside a custom move, watches for idle windows and may launch an idle move

3. `on_pre_die_character` / `on_pre_destroy_hit`
- flushes summon references

4. `on_pre_unregist_shell`
- flushes shell references

`setup_info(data, params)` builds the per-enemy runtime state:

- `character`
- `lastMoveTimes`
- `idleTime`
- `position`
- `targetPosition`
- `targetDistance`
- `fullNode`
- `trackingDistance`
- `isInMove`
- `frame`
- `actionsTable`

and also injects helper methods directly into `characterInfo`:

- `kill_shell(shellHash)`
- `kill_all_shells(shellHash?)`
- `kill_summon(name)`
- `kill_all_summons(name?)`
- `destroy_summon(name)`
- `destroy_all_summons(name?)`
- `kill_all_efx()`

### How move selection works

Primary file:
`Bestiary/MovesetHandler/Selection.lua`

Functions:

- `selection.is_valid_move(characterInfo, name, move)`
  - validates cooldown
  - validates target distance band
  - validates HP thresholds
  - validates current status
  - validates angle to target
  - validates custom predicate
- `selection.get_valid_moves(moveset, characterInfo, weightName)`
  - filters whole moveset down to currently legal moves
  - also accumulates total weight
- `selection.pick_random_move(validMoves, weightName, totalWeight)`
  - weighted random roll
- `selection.choose_move(moveset, characterInfo, weightName)`
  - full public selector
  - writes cooldown timestamp into `characterInfo.lastMoveTimes`
- `selection.get_idle_move_chance(idleTime, minIdleTime, maxIdleTime)`
  - gradually increases idle-trigger probability over time

Important design point:
`Bestiary` is not priority-first like our current pawn synthetic layer.
It is weight-based among currently valid authored moves.

### How native actions get replaced

Primary function:
`Setup.lua -> handle_replace_moves(characterInfo, data, params)`

Behavior:

- reads `actionsTable[data.node]`
- if current native node is marked replaceable, rolls replacement chance
- if enemy is already in custom move or combat preconditions fail:
  - only "specific replacement" entries can still suppress the native move
- otherwise chooses a move using `selection.choose_move(..., "replaceWeight")`
- starts it with `executor.play_sequence(...)`
- returns `true` to skip native node when replacement wins

This is the first big answer to "how it makes mobs do more than vanilla":
it intercepts native action requests before they execute and swaps some of them out.

### Combat preconditions

Primary function:
`Setup.lua -> can_play_move(characterInfo)`

Checks:

- special dragon-phase exception
- current node exists
- enemy is not carrying an object
- enemy combat state controller says it is actually in combat
- enemy is not already in a stagger/damage node
- `EnemyCtrl.Ch2:getAttackTarget()` exists and is valid
- for most species:
  - target must have a game object
  - target usually must resolve to a character
- slime-like exception:
  - location targets are allowed

This is why `Bestiary` does not fully ignore native target logic.
It still anchors itself to the enemy's own attack target before launching custom content.

### How authored moves execute

Primary file:
`Bestiary/MovesetHandler/Executor.lua`

Main method:
`executor.play_sequence(characterInfo, sequence, addMotionBank)`

What it does:

- collects current combat state and engine handles:
  - transform
  - combat state control
  - work rate
  - motion
  - enemy controller Ch2
  - tracking object
  - address
- builds `ctx`
- aborts previous move hooks if any
- marks `characterInfo.isInMove = true`
- optionally injects a dynamic motion bank
- installs helper closures on `characterInfo`
  - `go_to_node(number)`
  - `go_to_next_node()`
  - `abort_fns()`
- jumps to first node
- starts per-frame driver
- enables interrupt prevention

This is the main "sequence runtime constructor".

### Node engine

Primary file:
`Bestiary/MovesetHandler/NodeCore.lua`

Functions:

- `nodeCore.get_layer(ctx)`
  - resolves animation layer from node or motion data
- `nodeCore.play_node(characterInfo, ctx)`
  - if node has `nodeName`, requests native action with `requestActionCore(0, nodeName, layer)`
  - if node has `motionData`, forces motion with `utils.motion.change_motion(...)`
- `nodeCore.is_in_node(characterInfo, ctx)`
  - checks whether engine is still in the authored node or motion
- `nodeCore.go_to_node(characterInfo, ctx, number)`
  - switches active node
  - resets per-node flags
  - runs `on_end` for previous node
  - runs `on_start` for new node
  - resets frame counter
  - plays node
  - attaches damage and cast-color hooks
  - re-enables `ActInter` for explicitly interruptible nodes
- `nodeCore.go_to_next_node(characterInfo, ctx)`
  - shorthand to advance sequence
- `nodeCore.set_character_frame(characterInfo, ctx)`
  - frame counter core
  - for non-interruptible nodes it uses motion-layer delta frame
  - for interruptible nodes it falls back to real time
- `nodeCore.set_character_speed(characterInfo, ctx)`
  - multiplies work rate by node speed
- `nodeCore.set_character_rotation(characterInfo, ctx)`
  - tracks target during configured frame window
  - can stop tracking when close, frozen, climbing, etc.
- `nodeCore.on_frame(characterInfo, ctx)`
  - main per-frame loop
  - aborts if node desyncs or character dies
  - updates frame, speed, rotation
  - fires shell / summon / efx / sfx payloads
  - runs node `on_frame`
  - advances to next node or aborts whole move at sequence end

This is the actual finite-state machine of the move.

### Interrupt suppression

Primary file:
`Bestiary/MovesetHandler/PreventInterrupts.lua`

Functions:

- `preventInterrupts.disable_ai(ctx)`
  - disables `ctx.ch2._ActInter`
- `preventInterrupts.skip_ai(ctx)`
  - skips native AI execution callback for this enemy while node is non-interruptible
- `preventInterrupts.skip_locomotion(ctx)`
  - blocks locomotion changes
- `preventInterrupts.on_pre_action_request(characterInfo, ctx)`
  - blocks most incoming native action requests
  - allows some behavior for stagger handling
  - can soft-abort on interruptible nodes
- `preventInterrupts.prevent_interrupts(characterInfo, ctx)`
  - master wrapper that installs the above

This is the second big answer to "how can the spell sequence stay alive":
the mod aggressively owns the enemy during execution and keeps vanilla AI from cancelling the custom move.

### Abort and cleanup path

Primary file:
`Bestiary/MovesetHandler/NodeAborts.lua`

Functions:

- `nodeAborts.enable_ai(characterInfo, ctx)`
  - restores `ActInter`
  - if enemy is still in damage state, waits until stagger ends
  - includes a special ogre blown-down fix
- `nodeAborts.flush_functions(characterInfo, ctx)`
  - clears active callbacks and resets move state
- `nodeAborts.abort_fns(characterInfo, ctx, delay?)`
  - clears frame/damage hooks immediately or after delay
- `nodeAborts.soft_abort(characterInfo, ctx)`
  - partial cleanup
  - keeps per-frame logic alive so lingering shells can continue

### Per-node damage and cast hooks

Primary file:
`Bestiary/MovesetHandler/NodeHooks.lua`

Functions:

- `nodeHooks.attach_damage_info_hook(characterInfo, ctx)`
  - can edit final `DamageInfo`
  - can suppress reaction for uninterruptible nodes
- `nodeHooks.attach_attack_data_hook(characterInfo, ctx)`
  - can mutate raw `AttackUserData`
  - restores backup afterward
- `nodeHooks.attach_cast_colors_hook(characterInfo, ctx)`
  - recolors casting VFX tied to this node

### Per-node effects and sound

Primary file:
`Bestiary/MovesetHandler/NodeFX.lua`

Functions:

- `nodeFx.play_efx(characterInfo, ctx)`
  - spawns authored VFX once at configured frame
  - supports source/target presets, joint, offset, rotation, duration
- `nodeFx.play_sfx(characterInfo, ctx)`
  - triggers authored sound once at configured frame
  - can stop it after duration

### Per-node shell and summon system

Primary file:
`Bestiary/MovesetHandler/NodeShells.lua`

Functions:

- `random_quaternion()`
  - utility for random shell orientation
- `get_shell_position(characterInfo, ctx, shell, shellPosition)`
  - resolves spawn point from owner / joint / weapon / target / attach rules
- `get_shell_rotation(characterInfo, ctx, shell, position)`
  - resolves shell direction from presets like `front`, `joint`, `aimed`, `up`, `down`, `random`
- `nodeShells.cast_shell(characterInfo, ctx)`
  - turns authored node `shell = {...}` into a real shell creation request
  - can also replace an existing shell when `replaceShell` is configured
- `nodeShells.summon(characterInfo, ctx)`
  - spawns new enemies using `EnemySpawner.spawn_enemy(...)`
  - supports random owner-centered spawn offsets

This is the third big answer to "how it makes mobs cast spells":
spell payloads are not inferred by AI; they are authored explicitly as shell-creation nodes.

### Shell runtime

Primary files:

- `Bestiary/ShellHandler.lua`
- `Bestiary/ShellHandler/ShellHooks.lua`
- `Bestiary/ShellHandler/ShellParams.lua`
- `Bestiary/ShellHandler/ShellUdatas.lua`

`shellHandler.cast_shell(owner, udataPath, shellID, params)`:

- loads target `app.ShellParamData`
- builds `app.ShellRequest.ShellCreateInfo`
- temporarily edits shell base params
- calls `app.ShellManager.requestCreateShell(...)`
- attaches follow-up hooks for:
  - registration
  - frame updates
  - follow-joint behavior
  - recolor
  - absolute lifetime
  - attack-data mutation
  - damage-info mutation
  - special-case shell behavior
  - cleanup on unregister

`ShellParams.lua` functions:

- `modify_base_params(udata, shellID, params)`
  - temporary scale / lifetime / omen edits
- `modify_gravity(udata, shellID, params)`
  - temporary gravity edits

`ShellHooks.lua` functions:

- `attach_regist_hook(params, shared)`
  - captures created shell
  - applies cosmetic and element rules
- `attach_follow_joint_fn(params, owner, shared)`
  - glues shell to owner joint each update
- `attach_on_frame_fn(params, shared)`
  - applies per-frame speed changes and custom shell frame callback
- `attach_color_hook(params, shared)`
  - recolors created shell effects
- `attach_absolute_lifetime_hook(params, shared)`
  - prevents early expiry until desired lifetime
- `attach_attack_data_hook(params, owner, shared)`
  - mutates shell attack data
- `attach_damage_info_hook(params, owner, shared)`
  - mutates shell damage info
- `handle_special_cases(shared, udataPath, shellID)`
  - hardcoded exception for flamelance movement behavior
- `flush_shell_hooks(shared, delay)`
  - removes temporary hook set when shell dies

`ShellUdatas.lua`:

- preloads a very large table of shell-param userdata paths
- this is effectively the mod's spell/projectile resource catalog

### Utility layer

`Bestiary/Utils.lua` is just an aggregator.
The real reusable helpers are in the submodules.

`Utils/Enemy.lua`

- `attach_rock_handler(chName, rockActionRate)`
  - special multi-hit rock shell dampening
- `get_shuffled_party()`
- `ground_multicast_condition(characterInfo)`
- `get_random_offset(enemyMatrix, radius)`
- `is_low_hp_or_angry(characterInfo)`
- `is_armed(characterInfo)`
- `is_unarmed(characterInfo)`
- `remove_seism_unconscious(damageInfo, data)`
- `remove_hitstop(damageInfo, data)`
- `is_drawed_weapon(characterInfo)`

`Utils/Motion.lua`

- `is_stagger_node(fullNode)`
- `is_staggered(character)`
- `add_dynamic_motionbank(motion, path, newBankID)`
- `change_motion(character, motionData)`

`Utils/Object.lua`

- `is_paused()`
- `str_to_ptr(string)`
- `print_fields(typeName)`
- `shuffle(list)`
- `get_party()`
- `get_scene()`
- `create_resource(resourceType, resourcePath)`
- `get_component(object, name)`
- `get_attacker(damageInfo)`
- `get_receiver(damageInfo)`
- `copy_fields(source, target)`
- `generate_enum(typeName)`
- `generate_reverse_enum(typeName)`
- `generate_enum_list(typeName)`
- `get_children(xform)`

`Utils/FX.lua`

- `change_container_colors(container, entryNumber, color, externColor)`
- `change_color(thing, color)`
- `trigger_sound(source, target, triggerID)`
- `play_efx(source, target, joint, containerIndex, containerId, elementId, offset, rotationOffset)`
- `play_root_efx(characterInfo, ids, delay)`

`Utils/Position.lua`

- movement/geometry helpers:
  - grounded / air checks
  - map and dungeon checks
  - quaternion facing
  - universal/local position conversion
  - raycast visibility
  - forward vector
  - horizontal angle
  - target angle
  - angle-range check
  - ground distance

`Utils/Status.lua`

- `check_status`
- `apply_status`
- `cure_status`
- `cure_all_status`

`Utils/Variant.lua`

- variant name cache
- variant GUID lookup
- quest sphinx detection
- weighted variant pick
- runtime variant param resolution

`Utils/Chimera.lua` and `Utils/Medusa.lua`

- enemy-specific structural helpers for multipart enemies and mode switching

### Enemy authoring format

Enemy files do not write custom logic into the runtime core.
Instead they fill data tables and then call `movesetHandler.setup_character(...)`.

Typical pieces inside an enemy file:

- `movesetHandler.movesets.<EnemyName> = { ... }`
- `actions = { [nativeNodeName] = true/false/number, ... }`
- `idles = { [nodeName] = true, ... }`
- `movesetHandler.setup_character({...})`

Each move entry can contain:

- `targetDistance`
- `cooldownSeconds`
- `hpThreshold`
- `validStatus`
- `angles`
- `idleWeight`
- `replaceWeight`
- `custom_condition`
- `addMotionBank`
- `sequence`

Each sequence node can contain:

- `nodeName`
- `motionData`
- `nextFrame`
- `trackingFrames`
- `trackingForce`
- `speed`
- `interruptible`
- `uninterruptible`
- `on_start`
- `on_frame`
- `on_end`
- `on_stagger`
- `modify_attack_data`
- `modify_damage_info`
- `castingColors`
- `efx`
- `sfx`
- `shell`
- `summon`

This is the mod's real DSL.

### Concrete examples

`Enemies/SacredArborPurgener.lua`

- declares authored spells like:
  - `Summon Rattlers`
  - `Brine Meteor`
  - `Brine Meteor - Multi Target`
- those "spells" are implemented as:
  - VFX windup
  - SFX windup
  - shell creation at authored frames
  - summon payloads
  - cooldown bookkeeping like `characterInfo.lastSpellTime`

`Enemies/GoblinLeader.lua`

- shows how a grounded melee enemy gets extra fantasy behavior
- `Throwblast Frenzy`:
  - uses native nodes and raw motion
  - repeatedly spawns explosive shells from hand joint
- `Suicide Bomber`:
  - attaches shell to hand
  - tracks target
  - branches to later node when distance becomes short enough

This proves the mod is not limited to casters.
It is a general sequence-authoring system for enemies.

### Side systems not directly related to movesets

`VariantHandler.lua`

- randomizes enemy variants
- recolors enemies and weapons
- changes scale, healthbars, EXP multipliers, status resistances, damage dealt / taken, stagger dealt / taken, and element swaps

`SilenceRework.lua`

- redefines how silence affects bosses and special enemies
- can force stagger-like interruption when a boss is silenced mid-action

`DragonsplagueRework.lua`

- rewires dragonsplague infection and calamity behavior
- can spawn special black dragon consequences

These are real parts of the mod, but they are not the mechanism that makes enemies cast custom spells.

### What is useful for Pawn Hybrid Vocations AI

Strongly useful concepts:

- sequence runtime with authored nodes
- separate selector vs executor vs anti-interrupt layers
- node-level payload composition:
  - native node
  - motion swap
  - VFX
  - SFX
  - shell
  - summon
  - hit/damage mutation
- coarse move validation via distance / HP / angle / cooldown / custom predicate
- short-lived execution ownership while custom move is active

Potentially reusable techniques:

- `requestActionCore(0, nodeName, layer)` as one execution primitive
- dynamic motion-bank injection and `changeMotion(...)`
- temporary attack-data and damage-info mutation around one move
- per-move callbacks:
  - `on_start`
  - `on_frame`
  - `on_end`
  - `on_stagger`

Useful mostly for research or dev tools:

- deep `_NickCore` callback fabric
- shell creation and shell mutation layer
- debug UI for forcing authored moves

Probably not reusable directly as product architecture for our pawn mod:

- full enemy-style AI suppression during move ownership
- blanket locomotion suppression
- broad `ActInter` disabling as the default pawn path
- shell-heavy authoring model as the main solution to pawn melee continuity

Why:

- `Bestiary` is allowed to own monsters much more aggressively than we can safely own `main_pawn`
- enemies tolerate stronger override and desync risk than the player's main pawn
- our product problem is closer to synthetic continuation over pawn combat context, not full monster-style move takeover

### Bestiary-specific lessons for us

1. Their most important architectural win is not "shells".
It is the strict separation of:
- move eligibility
- sequence execution
- interrupt suppression
- payload injection
- abort cleanup

2. Their authored `sequence` model is stronger than our current single-phase bridge model.
If we borrow anything structurally, it should be that:
- one selected move can own several timed steps
- each step can do more than just request one node

3. Their anti-interrupt layer is powerful, but for us it should become a narrow "combat-owned common subset", not full enemy-style suppression.

4. Their selection is data-driven and local to each enemy file.
That is a good pattern for authored combat packs, even if our selection math stays different.

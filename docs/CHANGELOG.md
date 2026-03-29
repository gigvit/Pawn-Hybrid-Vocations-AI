# CHANGELOG

## 2026-03-29

### Changed

- `docs/KNOWLEDGE_BASE.md` now contains an explicit external-collaborator handoff snapshot and a code-audit snapshot, so the current product status, live evidence set, architectural strengths, and known runtime risks can be handed to the `_NickCore` author without relying on scattered session-log summaries
- `docs/ROADMAP.md` now reflects the post-admission state of the project more honestly: `main_pawn Job07` already reaches real synthetic `Job07` actions, the critical path has shifted to close-contact continuity and hit conversion, and `_NickCore` is now documented as a dev-only collaborator for execution-layer diagnosis rather than as a product dependency
- `mod/reframework/autorun/PawnHybridVocationsAI/core/readers.lua` now centralizes cached reflected-field and method-fallback readers, and the main runtime modules (`main_pawn_properties`, `progression/state`, `hybrid_unlock`, `hybrid_combat_fix`, `dev/nickcore_trace`) now use that shared helper instead of carrying subtly different local reader implementations
- `mod/reframework/autorun/PawnHybridVocationsAI/core/runtime_surfaces.lua` now centralizes shared surface helpers for pack/path/name lookup, current FSM node lookup, decision-pack resolution, and collection access; `game/hybrid_combat_fix.lua` and `dev/nickcore_trace.lua` now share that layer instead of carrying separate pack-surface logic
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now honors `telemetry_only` as a real observe-only runtime mode, and its unmapped-phase policy now goes through one shared helper so `allow_unmapped_skill_phases` no longer quietly sounds broader than the selector can actually execute
- `mod/reframework/autorun/PawnHybridVocationsAI/config.lua` and `game/hybrid_combat_fix.lua` now use more honest unmapped/selector-owned wording as well: the config explicitly says it does not make selector-owned contracts executable, and bridge failures now log `selector_owned_unbridgeable` instead of implying a generic implementation hole
- `docs/KNOWLEDGE_BASE.md` code-audit snapshot is now synchronized with those runtime fixes: it explicitly mentions the shared `readers` and `runtime_surfaces` layers, no longer describes pre-fix `telemetry_only` drift as a current fact, and now names `enemy-target bridging` extraction as the next structural refactor target

## 2026-03-28

### Changed

- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now preserves the last good bridge-critical context (`decision_module`, `decision_executor`, `executing_decision`, `ai_blackboard`) when a later frame resolves the same pawn/job/profile without those surfaces, and phase scoring now remembers the last applied `Job07` role/bucket so close-range follow-through stops over-spamming opener phases and can bias back toward real sustain pressure
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now treats `synthetic_bucket` as a coarse combat-stage gate instead of the main score source: `initiator`, `follow_through`, and `recovery` stages first decide which bucket families are even legal, then the selector mostly falls back to per-phase priority plus light distance/anti-repeat adjustments, which should look less jerky than the old heavy bucket-bias model
- `mod/reframework/autorun/PawnHybridVocationsAI/data/vocation_skill_matrix.lua`, `game/hybrid_combat_fix.lua`, and `config.lua` now add a data-driven stability gate for known crash-prone phases: `Job07_DragonStinger` is marked `crash_prone` in the shared skill matrix, product runtime blocks such phases by default with `enable_crash_prone_skill_phases = false`, and the phase can still be re-enabled for focused research without adding runtime-only skill special-cases
- `mod/reframework/autorun/PawnHybridVocationsAI/data/hybrid_combat_profiles.lua` now propagates runtime-phase `stability` metadata from the shared skill matrix into generated custom-skill phases, fixing the bug where `DragonStinger` was marked `crash_prone` in data but still slipped into the live selector because the flag never reached runtime
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now enforces `min_job_level` even when current job level is only the conservative `assumed_minimum_job_level`; previously the runtime silently nulled level requirements in that case, which let over-level phases like `SpiralSlash` outrank basic attacks and made low-level Job07 combat look both too fancy and too ineffective
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now forward-declares `resolve_phase_synthetic_bucket` before phase filtering and treats `GenericJob_MoveIntoHealingSpotUntilHpFull`-style output as support/recovery navigation, so the runtime no longer crashes on another Lua helper-order regression and synthetic combat is less likely to override explicit healing-spot movement
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now treats obvious non-combat self/social states earlier and more honestly: `Pawn_Perform_Chilling`-style outputs are classified as `special_output_state` before target resolution, `HitResultData` extraction no longer falls back to `get_GameObject`, and `resolve_phase_selection_role` is now bound before `filter_phase_candidates` so synthetic phase filtering stops crashing on another Lua forward-reference regression
- `mod/reframework/autorun/PawnHybridVocationsAI/core/util.lua`, `game/main_pawn_properties.lua`, `game/progression/state.lua`, and `dev/nickcore_trace.lua` now avoid hot-path `get_GameObject` fallback on already-resolved character components unless truly necessary, reducing the chance that `via.Component.get_GameObject` `InvalidOperationException` spam from dirty combat frames interrupts analysis
- `KNOWLEDGE_BASE.md` now records a full `reframework/data` source map: `ce_dump/` and `PawnHybridVocationsAI/logs/` are documented as the primary live-evidence layer, `DD2_Scraper/` and `usercontent/` as schema and reference layers, and `NickCore/`, `NicksDevtools/`, and `reframework/data/reframework/` as mostly service or tool-state directories
- `bootstrap.lua`, `core/scheduler.lua`, `game/main_pawn_properties.lua`, `game/progression/state.lua`, and `game/hybrid_unlock.lua` now share a more stable runtime skeleton: scheduled updates are isolated from uncaught errors, scheduler timestamps are only committed after successful runs, `main_pawn_properties.lua` keeps a short-lived shared stable main-pawn snapshot instead of hard-resetting all downstream readers on one bad frame, and progression/unlock readers now consume the same resolved main-pawn context with reflected field fallback
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now forward-declares `extract_target_character` before early decision-target resolution, fixing a Lua upvalue regression that made `hybrid_combat_fix.update` crash at startup with `global 'extract_target_character' is not callable`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now also forward-declares `build_target_info` for the same early target-resolution path, fixing the follow-up Lua regression where startup moved past `extract_target_character` and then crashed on `global 'build_target_info' is not callable`
- `mod/reframework/autorun/PawnHybridVocationsAI/data/hybrid_combat_profiles.lua`, `data/vocation_skill_matrix.lua`, and `game/hybrid_combat_fix.lua` now treat `Common/Locomotion` synthetic entry as a bucketed `Job07` problem instead of a flat priority list: core and custom phases carry explicit `synthetic_bucket` hints such as `opener`, `sustain`, `ranged`, `defense`, and `burst`, Sigurd-observed `ch300_job07_RunAttackNormal.user` is now modeled as an additional far engage core phase, and phase scoring now biases `synthetic_initiator` toward opener or gap-close phases before sustain, ranged, defense, or burst follow-ups
- `mod/reframework/autorun/PawnHybridVocationsAI/dev/nickcore_trace.lua` now adds an optional dev-only `_NickCore` consumer that records live `requestActionCore(...)` and `setBBValuesToExecuteActInter(...)` events for `main_pawn`, `Sigurd`, and other observed `Job07` actors into separate trace files under `PawnHybridVocationsAI/logs/`; `bootstrap.lua` initializes it without making `_NickCore` a hard runtime dependency
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now narrows target-layer fallback toward grounded publishers instead of broad generic roots: `PawnOrderTargetController` collections and `DecisionEvaluationResult.<Target>` stay first-class, `PawnManager.get_PawnOrderTargetController()` is now included directly, `VisionMarker` and `HitResultData.Obj` get explicit character extraction, and target telemetry now distinguishes missing decision targets, empty order-target collections, and unresolved collection items more cleanly
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now follows one extra owner-level when target extraction starts from a `via.GameObject`, so `HitResultData.Obj` or other child-object hits can still resolve back to an owning `app.Character` instead of collapsing into `collection_item_unresolved`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/main_pawn_properties.lua` and `game/hybrid_combat_fix.lua` now stabilize hybrid combat context against transient bad frames: reflected field fallback improves `main_pawn_data`, current-job resolution now checks `Human` and `JobContext` before falling back to raw job fields, and `hybrid_combat_fix.lua` keeps a short-lived stable-context fallback so one-frame `main_pawn_data_unresolved` or `main_pawn_not_hybrid_job` spikes no longer immediately reset synthetic combat state

## 2026-03-27

### Changed

- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now pivots its first bridge admission step toward `synthetic_stall`: the bridge no longer treats every first utility or `DmgShrink*` frame as an immediate entry window, but instead waits for a short live-target stall window and respects a short native-output backoff before re-entering
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now classifies `Damage.DmgShrink*` as `damage_recovery` before considering utility-style upper-body locomotion, so synthetic-stall admission can mature on real damage-recovery frames instead of mislabeling them as generic utility
- `docs/ce_scripts/main_pawn_output_classification_screen.lua` now dumps the current output-classification catalog, raw token matches, target usability, and both current and legacy recoverable-family precedence so output/admission misclassifications can be diagnosed without relying on session-log timing
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now distinguishes proactive `synthetic_initiator` admission from fallback `synthetic_stall`: utility/locomotion stalls can open combat on a shorter window, while `damage_recovery` remains a slower recovery-only admission path
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` and `data/hybrid_combat_profiles.lua` now give `synthetic_initiator` an opener bias: core gap-close, engage, and basic-attack phases get explicit initiator priorities, while controller-stateful or selector-owned phases no longer steal first entry just because their raw priority is higher
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now resolves combat targets through the same CE-grounded target shapes we already verified in dumps: collection items are unwrapped into target-like roots before character extraction, decision targets no longer require overly strict object-validity gates just to be read, and hot-path game-object fallback no longer calls `Character.get_GameObject`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now quarantines phases that just failed to bridge, so the runtime no longer retries the same broken phase every `0.10s`; `mod/reframework/autorun/PawnHybridVocationsAI/config.lua` exposes the quarantine window as `phase_failure_quarantine_seconds`
- `mod/reframework/autorun/PawnHybridVocationsAI/core/execution_contracts.lua`, `data/vocation_skill_matrix.lua`, and `game/hybrid_combat_fix.lua` now let grounded controller-stateful skills declare their preferred probe mode through the shared skill matrix and execution-contract metadata even when the global `unsafe_skill_probe_mode` stays `off`, so skill-specific execution context remains data-driven instead of hardcoded in profile or runtime branches
- `mod/reframework/autorun/PawnHybridVocationsAI/config.lua` now makes `synthetic_initiator` immediate by default, while `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` records why the synthetic timer was reset and why a new admission window started, so first-entry failures can be distinguished from real target or output regressions
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now backs off from `synthetic_initiator` when the pawn is already hurt and current output looks like support or recovery navigation, so synthetic combat no longer tries to override likely movement into mage healing or other recovery positioning; the low-HP threshold is exposed as `synthetic_support_recovery_hp_ratio` in `config.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now uses reflection-backed field fallback with per-type caching in its runtime target and context readers, and it treats any `app.AITarget*` object as a direct target-like surface, so CE-proven shapes such as `app.AITargetGeneralPoint` stop collapsing into `executing_decision_unresolved` just because direct field access missed them
- `mod/reframework/autorun/PawnHybridVocationsAI/config.lua` now exposes `synthetic_initiator_window_seconds`, `synthetic_stall_window_seconds`, and `synthetic_native_output_backoff_seconds` for the first synthetic-adapter rollout
- `ROADMAP.md` and `KNOWLEDGE_BASE.md` now record the implementation pivot: restoring native `MainDecisions` for `main_pawn Job07` remains a background hypothesis, while the critical path is now a narrow synthetic attack adapter over native target publication, movement, and safety states
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now treats `Common/HumanTurn_Target_Talking` as a narrow recoverable admission window instead of an unconditional early skip when a live enemy target is already resolved, while still keeping treasure, carry, sort-item, greeting, and win-state outputs blocked
- product runtime no longer loads `game/discovery.lua` from `bootstrap.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/main_pawn_properties.lua` no longer performs recursive object-graph scans or writes discovery diagnostics into shared runtime state
- `mod/reframework/autorun/PawnHybridVocationsAI/state.lua` and `config.lua` no longer carry the old discovery-state scaffolding
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now keeps skip-telemetry and target-source probe logging disabled by default, and target probes are no longer built in the hot path unless that logging is explicitly re-enabled
- documentation now treats research as externalized tooling: `Content Editor` for live inspection, `DD2_DataScraper` for bulk exports, and `Nick's Devtools` / `_NickCore` as dev-only tracers rather than product-runtime dependencies

## 2026-03-26

### Added

- `docs/ce_scripts/main_pawn_main_decision_profile_screen.lua` for deeper combat/non-combat profiling of `main_pawn` `MainDecisions`
- `docs/ce_scripts/main_pawn_main_decision_semantic_screen.lua` for semantic profiling of combat `MainDecisions`, action packs, conditions, evaluation criteria, and processes
- `docs/ce_scripts/main_pawn_output_bridge_burst.lua` for timed combat bursts linking `MainDecisions` population to selected request, current action, pack path, and FSM output
- `docs/ce_scripts/main_pawn_target_publication_burst.lua` for timed target-publication bursts linking `ExecutingDecision`, order-target-controller collections, selected request, current action, and FSM output during visually ambiguous stalls
- `docs/ce_scripts/vocation_definition_surface_screen.lua` for class-level extraction of vocation enums, job parameters, ability parameters, job type surfaces, and live skill/loadout state
- `docs/ce_scripts/vocation_progression_matrix_screen.lua` for progression-oriented extraction of hybrid job levels, base/core families, custom-skill bands, equip state, and augment/ability layers
- `mod/reframework/autorun/PawnHybridVocationsAI/core/execution_contracts.lua` as the shared execution-contract resolver for matrix data, profile building, and runtime bridging
- `mod/reframework/autorun/PawnHybridVocationsAI/data/vocation_skill_matrix.lua` as the canonical all-job vocation skill and ability matrix for `Job01` through `Job10`

### Changed

- documentation now records the stable combat `main_pawn Job01` vs `main_pawn Job07` `MainDecisions` split inside the pawn `DecisionEvaluationModule`
- documentation now records the semantic combat split: `main_pawn Job07` retains only a generic/common-heavy subset and exposes no unique combat `semantic_signature`
- documentation now records the confirmed combat output bridge: `Job01` reaches mostly job-specific combat output while `Job07` remains locked to common utility output
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now keeps the already grounded execution-contract bridge but rolls phase choice back toward literal `priority` ordering: fast target reuse stays cheap through a short-lived enemy cache, secondary target scans are throttled, and contracts stay in the execution layer instead of steering selection through extra bonuses
- `mod/reframework/autorun/PawnHybridVocationsAI/game/progression/state.lua` now precomputes a current-job custom-skill lifecycle cache (`potential -> unlockable -> learned -> equipped -> combat_ready`), and `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now reads that cache so custom-skill phases must pass an explicit learned-state gate before they ever enter `priority-first` combat selection
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now treats narrow `DmgShrink*` recovery states as a valid hybrid bridge window when a live enemy target is already present, so `Job07` is no longer blocked only because output left locomotion for a short damage-recovery cycle
- documentation now records the successful vocation-definition extraction from `vocation_definition_surface_20260326_195656.json`, including hybrid custom-skill bands, hybrid ability bands, off-job equip lists, and the special `Job10` surface
- documentation now records the first progression-matrix extraction from `vocation_progression_matrix_20260326_214421.json`, including `Job07` and `Job08` base/core vs custom family splits, live off-job custom-skill state, and the new `AbilityParam` indexing hazard
- documentation now records the full all-job `HumanCustomSkillID` matrix instead of only the hybrid `Job07` through `Job10` segment
- documentation now records the explicit hybrid custom-skill id matrix for `Job07` through `Job10`, including `Job07_DragonStinger = 73` as the first live-grounded `Job07` custom skill and `Job08_FrostTrace = 82` as the first live-grounded `Job08` custom skill
- documentation now preserves the remaining useful signal from the old `2026-03-25` session and discovery logs before deletion: `Job07` could reach the correct runtime surface and still remain trapped in common output, while the old hook-heavy research layer stayed low-yield
- the roadmap now shifts from blind `Job07` narrowing toward grounded progression-aware hybrid profiles for `Job07` through `Job10`
- `Job07` runtime profiling now treats `SpiralSlash` as a core or non-custom move and gates `SkyDive` by confirmed custom skill id `76`
- `Job07` runtime profiling now keeps the whole confirmed custom-skill family in the canonical vocation matrix while moving `DragonStinger = 73` into an explicit unsafe-skill investigation path instead of treating bare direct action as the final implementation
- `Job07` runtime profiling now uses a full-family custom-skill phase set driven from the canonical vocation matrix instead of growing one action at a time
- `mod/reframework/autorun/PawnHybridVocationsAI/data/vocation_skill_matrix.lua` now stores explicit `execution_contract` data, including placeholder all-job contracts for `Job01` through `Job10` and grounded `Job07` contract classes for the first live family
- `mod/reframework/autorun/PawnHybridVocationsAI/data/hybrid_combat_profiles.lua` now normalizes both core and custom `Job07` phases through explicit execution contracts instead of depending on scattered bridge fields alone
- `SECURITY.md` is now again a standalone bilingual repository policy instead of a git-tracked stub that only redirected readers to `rules.md`
- runtime logs now record that direct `Job07_DragonStinger` entry is unsafe for `main_pawn`: the game reached real `Job07_*` animations but crashed in `app.Job07DragonStinger.update`, so the skill is now investigated through probe-gated execution modes instead of being treated as a solved direct-action case
- `Job07` phase selection is now back to `priority-first`: phase ordering follows raw `priority`, execution contracts stay execution-only, and `assumed_minimum_job_level` no longer hard-blocks higher-level phases by pretending the pawn is definitely below them
- the roadmap and knowledge base now treat the next runtime direction as an execution-contract system for all vocations, where every skill family will eventually be classified as `direct_safe`, `carrier_required`, `controller_stateful`, or `selector_owned`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now resolves phase contract class and bridge mode from phase data and exposes both values in session logs for applied and failed attempts
- probe snapshots now read contract-declared controller state fields from the matching `JobXXActionCtrl` instead of relying on a `Job07`-only hardcoded dump path
- documentation now records that the latest `Job07` runtime session reached multiple real actions before the stall, including `Job07_BladeShoot`, `ch300_job07_Run_Blade4`, `Job07_MagicBindJustLeap`, and `Job07_ShortRangeAttack`
- documentation now records that the next two `Job07` session logs were almost empty after bootstrap, which means the runtime was silently exiting before phase logging rather than reaching a visible bridge failure
- documentation now records that the next target-facing `Job07` session did not fail in action execution; it failed earlier because combat target surfaces oscillated between `self` and `nil` while the older attacking session still had a stable enemy target
- documentation now records the git-and-CE target comparison: older `main_pawn Job07` captures already treated `ExecutingDecision.Target` as the only consistently live target root, while selector-facing target surfaces were often still `nil`
- documentation now records a narrower and more accurate `GameObject` conclusion: one older combat session already showed `executing_decision_target` exposing a valid `via.GameObject` while the chosen target still resolved to `self`, but newer logs are no longer a clean negative test because later runtime patches moved several hot paths away from direct `get_GameObject` calls
- documentation now records that three fresh `main_pawn_target_surface` captures showed the same asymmetry for both `Job07` and `Job01`: enemy target is visible through `ExecutingDecision.<Target>.<Character>`, while selector-facing target fields remain empty in the same samples
- documentation now records that `app.PawnOrderTargetController` is target-bearing through collections such as `_EnemyList`, `_FrontTargetList`, `_InCameraTargetList`, and `_SensorHitResult`, not through the plain `Target` field that the runtime had been probing
- documentation now records the next `Job07` target triplet: `_EnemyList` is now the strongest grounded fallback root because its first `via.GameObject` item consistently resolved an `other` enemy character even when `ExecutingDecision` had already flipped back to `self`
- documentation now records that the same triplet showed no `field` vs `method` `GameObject` divergence inside `ExecutingDecision`, while `VisionMarker` remained method-only and `HitResultData.Obj` appeared only through reflective field snapshots
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now prioritizes cached and explicit order-target-controller roots before wider blackboard and selector surfaces when `ExecutingDecision` fails to hold a usable enemy target
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now gives target extraction one narrow method-backed `GameObject` retry only after field-backed character discovery failed, so `VisionMarker` can participate without restoring blanket hot-path dependence on `get_GameObject`
- `mod/reframework/autorun/PawnHybridVocationsAI/core/util.lua` now supports reflection-backed named field reads inside `resolve_game_object(...)`, which is required for structures such as `HitResultData.Obj`
- documentation now records the next `Job07` target triplet as a separate sensor-heavy mode: `_EnemyList` dropped to zero while `_SensorHitResult` rose to `49`, and each first `HitResultData` item still exposed `Obj -> via.GameObject` through reflective field snapshots
- target and actor hot paths are now intentionally back on a more method-enabled `via.GameObject` baseline for the next screening pass, so the runtime can again be compared against the earlier pre-disable behavior instead of only the later field-first phase
- documentation now records the first useful post-rollback pair: after returning to the method-enabled baseline, the next `Job07` captures showed a third mode where all order-target collections were empty and the stall was dominated by `executing_decision_unresolved` rather than by bad identity inside a populated target source
- documentation now records that visually ambiguous stalls should now be screened with a timed target-publication burst instead of only with one-shot target surfaces, because single captures cannot reliably distinguish combat stall, sensor-heavy transition, and talking-like utility output

### Fixed

- `docs/ce_scripts/main_pawn_output_bridge_burst.lua` now resolves the first present pack-like field instead of stopping on an earlier readable-but-empty pack slot such as `ActionPackData`
- `docs/ce_scripts/vocation_progression_matrix_screen.lua` now reads `AbilityParam.JobAbilityParameters` with `job_id - 1` priority so the hybrid augment layer is no longer shifted by one job
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now accepts action candidate lists so runtime phases can safely try more than one confirmed action entrypoint when a skill family name and direct action name diverge
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now populates equipped skill ids and maps from live `SkillContext` equip lists instead of leaving them empty
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now keeps cleaner summaries of allowed phases, blocked phases, and per-skill gate signals so the next combat run is easier to diagnose
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now preserves execution-contract metadata inside blocked-phase summaries, so logs no longer mislabel blocked `direct_safe`, `carrier_required`, or `controller_stateful` phases as `selector_owned`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now writes throttled skip telemetry for early silent exits such as unresolved context, non-utility output, unresolved target, or unresolved bridge context
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now dumps throttled per-source target diagnostics for `ExecutingDecision`, `AIBlackBoardController`, `HumanActionSelector`, `CommonActionSelector`, `OrderTargetController`, and `JobXXActionCtrl` surfaces so target regressions can be traced before phase execution
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now probes `HumanActionSelector` and `CommonActionSelector` separately instead of collapsing them into one first-hit selector root, and it also inspects nested controller surfaces already confirmed by CE research
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now resolves `ExecutingDecision.Target` through the same non-self character extractor used by fallback target sources, so one `AITarget` object can no longer force an early `self` target if it also contains a usable enemy `Character`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/main_pawn_properties.lua` now restores `LockOnCtrl` into live main-pawn state so the runtime can reuse an older known-good target root already seen in previous git and CE research
- `docs/ce_scripts/main_pawn_target_surface_screen.lua` now provides a focused CE Console dump for current target-bearing roots so runtime target stalls can be compared against JSON instead of only session logs
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now reads collection-based fallback candidates from `app.PawnOrderTargetController`, so cached order-target controllers are no longer treated as empty just because they lack a direct `Target` field
- `docs/ce_scripts/main_pawn_target_surface_screen.lua` now also samples `AIBlackBoard` special `AITarget` slots and `PawnOrderTargetController` collections such as `_EnemyList`, `_FrontTargetList`, `_InCameraTargetList`, and `_SensorHitResult`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now exposes unsafe-skill probe modes `action_only`, `carrier_only`, and `carrier_then_action` so crash-prone skills can be investigated with controller snapshots instead of being silently forced or removed
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` no longer depends only on ad hoc bridge flags such as `unsafe_direct_action`; it now falls back to a normalized execution-contract resolver so the hot path is easier to extend and clean up
- `mod/reframework/autorun/PawnHybridVocationsAI/data/hybrid_combat_profiles.lua` no longer carries a hidden runtime call to an undefined `merge_into(...)`; contract helpers are now sourced from the shared execution-contract module
- actor-state and combat hot paths now prefer field-backed `GameObject` resolution over direct `get_GameObject` calls, reducing noisy `via.Component.get_GameObject` exceptions during live runtime
- `mod/reframework/autorun/PawnHybridVocationsAI/core/log.lua` now writes compact session log files under `reframework/data/PawnHybridVocationsAI/logs/` and prunes older `PawnHybridVocationsAI.session_*` files so only the newest `20` remain

## 2026-03-25

### Added

- `docs/ce_scripts/job07_selector_admission_compare_screen.lua` for a focused `main_pawn Job07` vs `Sigurd Job07` compare
- `docs/ce_scripts/job07_decision_pipeline_compare_screen.lua` for a focused `DecisionEvaluationModule` vs `ThinkTableModule` compare
- `docs/ce_scripts/main_pawn_decision_list_screen.lua` for `main_pawn Job01` vs `main_pawn Job07` decision-list captures

### Changed

- documentation now follows the structure required by `rules.md`
- all project knowledge is now recorded only in:
  - `README.md`
  - `docs/KNOWLEDGE_BASE.md`
  - `docs/CONTRIBUTING.md`
  - `docs/ROADMAP.md`
  - `docs/CHANGELOG.md`
- content from the previous CE playbook, Job07 catalog, and research-layer archive was merged into the allowed files
- the knowledge base now records the confirmed decision-pipeline split:
  - `main_pawn Job07 -> app.DecisionEvaluationModule`
  - `Sigurd Job07 -> app.ThinkTableModule`
- the roadmap now treats `main_pawn Job01` vs `main_pawn Job07` decision-list compare as the next narrowing step

### Fixed

- restored the actual hybrid unlock path after the cleanup regression
- restored field writes through `util.safe_set_field(...)`
- restored `QualifiedJobBits` mirroring from `player` to `main_pawn`
- refreshed the in-memory progression snapshot immediately after the unlock mirror
- restored the narrow guild-side hybrid job info override needed for `main_pawn`
- documentation now records the valid `Job01 / Job07 / Sigurd` compare outcome instead of the earlier outdated pre-compare state
- documentation no longer claims that the guild override falls back to a cached player retval
- documentation now records the in-game verified unlock/crash-fix state

### Removed

- standalone documentation files outside the allowed project structure:
  - `docs/CONTENT_EDITOR_RESEARCH_PLAYBOOK.md`
  - `docs/JOB07_RESEARCH_CATALOG.md`
  - `docs/RESEARCH_LAYER_ARCHIVE.md`

## 2026-03-24 to 2026-03-23

### Added

- the earlier `native-first` documentation set
- CE and runtime research material around `Job01`, `Job07`, and `Sigurd`
- repository policy files such as `LICENSE` and `SECURITY.md`

### Changed

- the project moved away from synthetic-first assumptions
- the main research direction became `native-first`
- the codebase later moved from a broad research runtime toward a smaller product runtime plus CE scripts

### Fixed

- multiple historical documentation inconsistencies during the `Job07` research phase
- several earlier mojibake and formatting issues in the public docs

### Removed

- the old runtime research layer from the product hot path during the cleanup phase

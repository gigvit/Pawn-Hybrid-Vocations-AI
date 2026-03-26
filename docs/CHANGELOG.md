# CHANGELOG

## 2026-03-26

### Added

- `docs/ce_scripts/main_pawn_main_decision_profile_screen.lua` for deeper combat/non-combat profiling of `main_pawn` `MainDecisions`
- `docs/ce_scripts/main_pawn_main_decision_semantic_screen.lua` for semantic profiling of combat `MainDecisions`, action packs, conditions, evaluation criteria, and processes
- `docs/ce_scripts/main_pawn_output_bridge_burst.lua` for timed combat bursts linking `MainDecisions` population to selected request, current action, pack path, and FSM output
- `docs/ce_scripts/vocation_definition_surface_screen.lua` for class-level extraction of vocation enums, job parameters, ability parameters, job type surfaces, and live skill/loadout state
- `docs/ce_scripts/vocation_progression_matrix_screen.lua` for progression-oriented extraction of hybrid job levels, base/core families, custom-skill bands, equip state, and augment/ability layers
- `mod/reframework/autorun/PawnHybridVocationsAI/data/vocation_skill_matrix.lua` as the canonical all-job vocation skill and ability matrix for `Job01` through `Job10`

### Changed

- documentation now records the stable combat `main_pawn Job01` vs `main_pawn Job07` `MainDecisions` split inside the pawn `DecisionEvaluationModule`
- documentation now records the semantic combat split: `main_pawn Job07` retains only a generic/common-heavy subset and exposes no unique combat `semantic_signature`
- documentation now records the confirmed combat output bridge: `Job01` reaches mostly job-specific combat output while `Job07` remains locked to common utility output
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
- runtime logs now record that direct `Job07_DragonStinger` entry is unsafe for `main_pawn`: the game reached real `Job07_*` animations but crashed in `app.Job07DragonStinger.update`, so the skill is now investigated through probe-gated execution modes instead of being treated as a solved direct-action case
- `Job07` phase selection is now system-first instead of skill-first: the selector scores `basic_attack`, `engage_basic`, `gapclose`, `core_advanced`, and skill roles separately, prefers ordinary/core combat when job level is only assumed, and exposes the final phase `score` in logs so skill ids no longer dominate selection by raw priority alone
- the roadmap and knowledge base now treat the next runtime direction as an execution-contract system for all vocations, where every skill family will eventually be classified as `direct_safe`, `carrier_required`, `controller_stateful`, or `selector_owned`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now resolves phase contract class and bridge mode from phase data and exposes both values in session logs for applied and failed attempts

### Fixed

- `docs/ce_scripts/main_pawn_output_bridge_burst.lua` now resolves the first present pack-like field instead of stopping on an earlier readable-but-empty pack slot such as `ActionPackData`
- `docs/ce_scripts/vocation_progression_matrix_screen.lua` now reads `AbilityParam.JobAbilityParameters` with `job_id - 1` priority so the hybrid augment layer is no longer shifted by one job
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now accepts action candidate lists so runtime phases can safely try more than one confirmed action entrypoint when a skill family name and direct action name diverge
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now populates equipped skill ids and maps from live `SkillContext` equip lists instead of leaving them empty
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now keeps cleaner summaries of allowed phases, blocked phases, and per-skill gate signals so the next combat run is easier to diagnose
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` now exposes unsafe-skill probe modes `action_only`, `carrier_only`, and `carrier_then_action` so crash-prone skills can be investigated with controller snapshots instead of being silently forced or removed
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua` no longer depends only on ad hoc bridge flags such as `unsafe_direct_action`; it now falls back to a normalized execution-contract resolver so the hot path is easier to extend and clean up
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

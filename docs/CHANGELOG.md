# CHANGELOG

## 2026-03-26

### Added

- `docs/ce_scripts/main_pawn_main_decision_profile_screen.lua` for deeper combat/non-combat profiling of `main_pawn` `MainDecisions`
- `docs/ce_scripts/main_pawn_main_decision_semantic_screen.lua` for semantic profiling of combat `MainDecisions`, action packs, conditions, evaluation criteria, and processes
- `docs/ce_scripts/main_pawn_output_bridge_burst.lua` for timed combat bursts linking `MainDecisions` population to selected request, current action, pack path, and FSM output

### Changed

- documentation now records the stable combat `main_pawn Job01` vs `main_pawn Job07` `MainDecisions` split inside the pawn `DecisionEvaluationModule`
- documentation now records the semantic combat split: `main_pawn Job07` retains only a generic/common-heavy subset and exposes no unique combat `semantic_signature`
- documentation now records the confirmed combat output bridge: `Job01` reaches mostly job-specific combat output while `Job07` remains locked to common utility output
- the roadmap now treats product-scoped runtime change as the next active step, not another broad CE narrowing pass

### Fixed

- `docs/ce_scripts/main_pawn_output_bridge_burst.lua` now resolves the first present pack-like field instead of stopping on an earlier readable-but-empty pack slot such as `ActionPackData`

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

# CHANGELOG

## 2026-03-25

### Added

- `docs/ce_scripts/job07_selector_admission_compare_screen.lua` for a focused `main_pawn Job07` vs `Sigurd Job07` compare

### Changed

- documentation now follows the structure required by `rules.md`
- all project knowledge is now recorded only in:
  - `README.md`
  - `docs/KNOWLEDGE_BASE.md`
  - `docs/CONTRIBUTING.md`
  - `docs/ROADMAP.md`
  - `docs/CHANGELOG.md`
- content from the previous CE playbook, Job07 catalog, and research-layer archive was merged into the allowed files

### Fixed

- restored the actual hybrid unlock path after the cleanup regression
- restored field writes through `util.safe_set_field(...)`
- restored `QualifiedJobBits` mirroring from `player` to `main_pawn`
- refreshed the in-memory progression snapshot immediately after the unlock mirror
- restored the narrow guild-side hybrid job info override needed for `main_pawn`
- documentation now records the valid `Job01 / Job07 / Sigurd` compare outcome instead of the earlier outdated pre-compare state

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

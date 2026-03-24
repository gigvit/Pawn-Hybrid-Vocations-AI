# CHANGELOG

## English

## 0.8.14-native-executor-getter-guard - 2026-03-24

### English

#### Changed

- `game/pawn_ai_data_research.lua` no longer performs dynamic getter probing for:
  - `app.DecisionExecutor`
  - `app.DecisionEvaluationCore`

#### Why

- the latest stabilized native probe still triggered a risky runtime getter:
  - `app.DecisionExecutor.get_PreviousDecisionForPenalty`
- these two types are still useful as structural roots, but probing their `get_*` methods in the hot path is not worth the runtime risk

#### Current Known State

- native comparison still shows the same useful structural difference:
  - `Job01` has a richer native decision pool than `Job07`
- this pass is a narrow safety fix so we can keep reading those containers without introducing another wave of REFramework exceptions

## 0.8.13-native-goal-probe-stabilization - 2026-03-24

### English

#### Changed

- `main_pawn_native_goal_probe_changed` now deduplicates on a compact semantic signature instead of the full volatile payload
- getter probing is now also disabled for:
  - `app.DecisionPackHandler`
  - `app.DecisionEvaluationModule`
- native goal probe collection item expansion is disabled by default
- native goal probe refresh interval is increased to `5.0` seconds

#### Why

- the previous log still produced excessive native goal probe spam even after throttling
- the latest runtime also showed a new risky getter path:
  - `app.DecisionPackHandler.get_PreDecisionList`

#### Current Known State

- native comparison is still giving useful structural differences between `Job01` and `Job07`
- this pass is meant to keep that signal while removing hot-path noise and dangerous getter calls

## 0.8.12-native-goal-probe-throttle - 2026-03-24

### English

#### Changed

- `game/pawn_ai_data_research.lua` native goal probing is now throttled and cached by `job + phase` instead of recomputing the heavy scan every refresh tick
- getter probing is now disabled for unstable native item types:
  - `app.AIDecision`
  - `app.DecisionEvaluationResult`
  - `app.DecisionPack`
- collection item root expansion is now limited by config and defaults to a single item per collection

#### Why

- the previous `0.8.11` pass exposed the right native decision neighborhood but was too expensive in runtime
- fresh logs showed:
  - `main_pawn_native_goal_probe_changed=281`
  - REFramework exceptions during `app.AIDecision` getter invocation
  - severe FPS collapse during the combat check

#### Current Known State

- native data-layer resolution is still progressing in the right direction
- this pass is a stability fix so we can keep probing native decision containers without destroying runtime performance

## 0.8.11-native-decision-container-probe - 2026-03-24

### English

#### Changed

- `game/pawn_ai_data_research.lua` native goal probing now walks deeper native decision containers instead of stopping at top-level roots:
  - `app.goalplanning.AIGoalData`
  - `app.DecisionEvaluationCore`
  - `app.DecisionExecutor`
  - `app.DecisionPackHandler`
  - `MainDecisions / PreDecisions / PostDecisions`
  - `PreMidway / Midway / PostMidway DecisionResults`
- root and candidate snapshots now include collection context:
  - `collection_count`
  - first item descriptions for collection-like objects
- the root builder now appends the first items from native decision/result lists so the next log can show whether the `Job` branch is hiding inside list entries rather than in a direct `AIGoalCategoryJob` field

#### Current Known State

- `0.8.10` exposed the correct native neighborhood but still left `job_goal_category` unresolved
- this pass shifts probing inward to decision and result containers, which is the most likely place to find the real admission path or the missing `Job` branch container

## 0.8.10-native-goal-candidate-scan - 2026-03-24

### English

#### Changed

- `game/pawn_ai_data_research.lua` native goal probing now records all valid candidate objects discovered through:
  - hardcoded `Goal/Category/Decision/Attack/Job` field paths
  - matching backing fields
  - matching getter methods on root objects
  - precomputed field snapshots from `main_pawn_properties`
- `main_pawn_native_goal_probe_changed` now has a better chance to expose the nearest usable native container even when `job_goal_category` is still unresolved

#### Current Known State

- `0.8.9` added root/candidate telemetry
- this pass makes the telemetry more aggressive so the next log should show concrete candidate object types instead of only unresolved roots

## 0.8.9-native-goal-probe-telemetry - 2026-03-24

### English

#### Changed

- `game/pawn_ai_data_research.lua` now emits `main_pawn_native_goal_probe_changed`
- the new event captures:
  - native goal-category roots
  - direct candidate objects found near `decision_maker`, `decision_evaluation_module`, `ai_goal_planning`, and related runtime objects
  - resolved category source when available
- native goal probing now also includes:
  - backing-field variants for attack goal categories
  - `runtime_character:get_AIDecisionMaker()`
  - precomputed deep snapshots already collected by `main_pawn_properties`

#### Current Known State

- `0.8.8` did not move the blocker past `job_goal_category_missing`
- this pass is intentionally diagnostic and should make the next log identify the real native container or at least the closest valid candidate path

## 0.8.8-native-job-category-probe - 2026-03-24

### English

#### Changed

- `game/pawn_ai_data_research.lua` now probes native `Job` goal-category paths directly before falling back to recursive scanning
- the resolver now checks:
  - `main_pawn_data.decision_maker`
  - `main_pawn_data.decision_evaluation_module`
  - `main_pawn_data.ai_goal_planning`
  - `main_pawn_data.pawn_data_context`
  - direct `AIDecisionMaker` category fields such as `NormalAttackAIGoalCategory` and `SkillAttackAIGoalCategory`
- native `job_goal_category_source` should now report a more precise path when a valid `Job` goal category is found

#### Current Known State

- the previous log proved controller/data access up to:
  - `PawnUpdateController`
  - `PawnBattleController`
  - `PawnOrderController`
  - `AIBlackBoardController`
  - `goal_action_data`
  - `battle_ai_data`
  - `order_data`
- the remaining native blocker was `job_goal_category_missing`
- this pass targets that blocker directly instead of searching `goal_action_data` blindly

## 0.8.7-native-readiness-pass - 2026-03-24

### English

#### Changed

- `game/pawn_ai_data_research.lua` now derives a native-readiness summary instead of exposing only raw controller/data snapshots
- the runtime now emits `main_pawn_native_ai_readiness_changed` with:
  - native controller resolution
  - native data resolution
  - `Job07` branch state
  - readiness stage
  - primary blocker
- `app/module_specs.lua` no longer makes `pawn_ai_data_research` depend on the synthetic `Job07` adapter

#### Current Known State

- native AI inspection now stands on its own hot path
- the next validation log should be able to say not only what objects were found, but what is still blocking native `Job07` proof

## 0.8.6-skill-gated-synthetic - 2026-03-23

### English

#### Changed

- `game/ai/synthetic_job07_adapter.lua` now applies a conservative skill-loadout gate before selecting synthetic `Job07` attack phases
- synthetic attack phases now read current `main_pawn` equipped skill ids from the runtime loadout summary instead of assuming every profile attack is always legal
- adapter skip/apply payloads now include:
  - allowed phase candidates
  - blocked phase candidates
  - equipped skill ids

#### Added

- `game/ai/job07_sigurd_profile.lua` attack phases now carry explicit skill-requirement metadata:
  - `required_skill_name`
  - `required_skill_id`
  - `requires_equipped_skill`
  - `requires_enabled_skill`
  - `block_if_unmapped`
- `config.synthetic_job07_adapter` now exposes:
  - `enforce_skill_loadout_gate`
  - `allow_unmapped_skill_phases`

#### Current Known State

- this pass is intentionally conservative
- unmapped synthetic `Job07` attack phases are blocked by default instead of guessed
- this protects guild/loadout correctness until exact `HumanCustomSkillID` mapping is proven
- `engage` phases still run; skill-backed attack phases now require real loadout evidence

## 0.8.5-unlock-resolver-hardening - 2026-03-23

### English

#### Fixed

- `game/main_pawn_properties.lua` now hardens main pawn resolution with:
  - `PawnManager._MainPawn` fallback
  - `pawn:get_CachedCharacter()` fallback
  - a recursive `PawnManager:get_AIData()` / manager-root scan that can recover:
    - `app.Pawn`
    - `app.Character`
    - `via.GameObject`
    - `app.PawnUpdateController`
- `get_player()` now also checks `_ManualPlayer` and direct `get_ManualPlayer` resolution before falling back to the older method-only path
- the runtime no longer aborts `main_pawn_data` construction immediately when the pawn object is missing but the main pawn `app.Character` can still be recovered through native AI roots

#### Current Known State

- this change is aimed at restoring unlock/progression inputs that regressed to `unresolved`
- guild hooks were still registering before this fix; the main blocker was upstream `player/main_pawn` resolution rather than the guild hook list itself

## 0.8.5-native-controller-resolver-pass - 2026-03-23

### English

#### Changed

- `game/pawn_ai_data_research.lua` now broadens controller/data resolution through:
  - extra roots from `PawnManager:get_AIData()`
  - extra roots from cached AI/planning objects on `main_pawn`
  - a recursive controller resolver pass after direct `GameObject/component` resolution
- the resolver now attempts to recover:
  - `PawnUpdateController`
  - `PawnBattleController`
  - `PawnOrderController`
  - `PawnOrderTargetController`
  - `AIMetaController`
  - `AIBlackBoardController`
  even when the first direct source is not the true AI root `GameObject`

#### Current Known State

- syntax is valid after this resolver pass
- this change is intended to improve native data visibility, not to claim solved `Job07` behavior yet

## 0.8.5-native-first-docs-pivot - 2026-03-23

### English

#### Changed

- documentation now treats `native-first` as the main project strategy again
- synthetic `Job07` is now documented as:
  - fallback
  - test harness
  - diagnostic bridge
  rather than the preferred final path
- roadmap now prioritizes:
  - repairing `pawn_ai_data_research` controller/data resolution
  - validating newly discovered hook families from external references
  - proving or disproving native `Job07` candidate availability
- `Sigurd` is now documented more explicitly as a future control scenario rather than a current runtime dependency

#### Current Known State

- the strategic pivot is documentation-first for now
- no runtime code behavior was changed by this docs pass
- the active native-first plan assumes we should extract maximum value from the current toolchain before reacquiring a clean `Sigurd` runtime

## 0.8.5-repository-policy - 2026-03-23

### English

#### Added

- `MIT` `LICENSE`
- repository-level `SECURITY.md`

#### Changed

- main docs now link the repository license and security policy
- contribution rules now mention licensing and security-reporting expectations
- knowledge base and roadmap now explicitly reference the repository security boundary

#### Current Known State

- the public repository now has a basic legal and security baseline
- no runtime code behavior was changed by this repository-policy pass

## 0.8.5-domain-consolidation - 2026-03-23

### English

#### Added

- unified unlock domain module:
  - `game/hybrid_unlock.lua`
- unified loadout inspection module:
  - `game/loadout_research.lua`

#### Removed

- retired the split unlock pair:
  - `game/hybrid_unlock_research.lua`
  - `game/hybrid_unlock_prototype.lua`
- retired the split loadout pair:
  - `game/vocation_research.lua`
  - `game/ability_research.lua`
- removed the now-unused runtime config tail:
  - `runtime.prototype_refresh_interval_seconds`

#### Changed

- project version is now `0.8.5-domain-consolidation`
- install/update orchestration now treats unlock as one domain and loadout inspection as one domain
- compatibility runtime fields for legacy summaries are still preserved so logging and UI stay stable
- the runtime tree is smaller again:
  - `40` Lua files validated by `luac`

#### Current Known State

- the project now has fewer sibling modules competing for the same actors and refresh cadence
- runtime behavior and init order were preserved while shrinking the tree
- this cleanup is structural only; it does not claim new `Job07` combat behavior by itself

### Русский

#### 0.8.5-native-controller-resolver-pass - 2026-03-23

##### Changed

- `game/pawn_ai_data_research.lua` теперь расширяет controller/data resolution через:
  - дополнительные roots из `PawnManager:get_AIData()`
  - дополнительные roots из cached AI/planning объектов на `main_pawn`
  - recursive controller resolver pass после прямого `GameObject/component` resolution
- resolver теперь пытается восстановить:
  - `PawnUpdateController`
  - `PawnBattleController`
  - `PawnOrderController`
  - `PawnOrderTargetController`
  - `AIMetaController`
  - `AIBlackBoardController`
  даже если первый прямой source не является настоящим AI root `GameObject`

##### Current Known State

- после этого resolver pass синтаксис валиден
- цель изменения — улучшить видимость native data, а не заявить, что `Job07` уже решён

#### 0.8.5-native-first-docs-pivot - 2026-03-23

##### Changed

- документация снова фиксирует `native-first` как основную стратегию проекта
- synthetic `Job07` теперь описывается как:
  - fallback
  - test harness
  - диагностический мост
  а не как предпочтительный финальный путь
- в roadmap теперь приоритетны:
  - починка controller/data resolution в `pawn_ai_data_research`
  - валидация новых семейств hooks из внешних reference-модов
  - доказательство или опровержение native `Job07` candidate availability
- `Sigurd` теперь ещё явнее описан как будущий control scenario, а не как текущая runtime-зависимость

##### Current Known State

- стратегический pivot пока проведён на уровне документации
- этот docs pass не менял runtime-поведение кода
- активный native-first план исходит из того, что сначала нужно выжать максимум из текущего toolchain, а уже потом возвращать чистый runtime `Sigurd`

#### 0.8.5-repository-policy - 2026-03-23

##### Added

- `MIT`-лицензия `LICENSE`
- repository-level `SECURITY.md`

##### Changed

- в основных docs теперь есть ссылки на лицензию и security policy репозитория
- в правилах contribution теперь зафиксированы ожидания по лицензии и security-reporting
- в knowledge base и roadmap теперь явно упоминается security boundary репозитория

##### Current Known State

- у публичного репозитория теперь есть базовая юридическая и security-основа
- этот repository-policy pass не менял runtime-поведение кода

#### Added

- единый модуль домена unlock:
  - `game/hybrid_unlock.lua`
- единый модуль inspect-ветки по loadout:
  - `game/loadout_research.lua`

#### Removed

- убрана старая пара unlock-модулей:
  - `game/hybrid_unlock_research.lua`
  - `game/hybrid_unlock_prototype.lua`
- убрана старая пара loadout-модулей:
  - `game/vocation_research.lua`
  - `game/ability_research.lua`
- удалён больше не нужный хвост конфига:
  - `runtime.prototype_refresh_interval_seconds`

#### Changed

- версия проекта теперь `0.8.5-domain-consolidation`
- install/update orchestration теперь рассматривает unlock как один домен, а loadout inspection как один домен
- совместимые runtime-поля для legacy-summary сохранены, чтобы не ломать логгер и UI
- runtime-дерево снова уменьшилось:
  - `40` Lua-файлов прошли проверку `luac`

#### Current Known State

- у проекта теперь меньше соседних модулей, конкурирующих за одних и тех же акторов и одну и ту же частоту обновления
- runtime-поведение и порядок инициализации сохранены при уменьшении дерева
- этот cleanup носит структурный характер и сам по себе не заявляет о новом `Job07` combat behavior

## 0.8.4-runtime-cleanup - 2026-03-23

### Removed

- retired `game/job07_runtime_probe.lua`
- retired probe UI / probe registry code that only served the old `Job07` probe branch
- retired inline `Job07` minimal experiment code from `game/action_research.lua`
- retired live `Sigurd` runtime capture / comparison from `game/action_research.lua`
- retired obsolete `Sigurd` action summary serialization from `core/log.lua`

### Changed

- project version is now `0.8.4-runtime-cleanup`
- the active `Job07` runtime write path is now centered on:
  - `game/ai/synthetic_job07_adapter.lua`
  - `game/ai/job07_sigurd_profile.lua`
- `action_research` now focuses on:
  - `player`
  - `main_pawn`
  and no longer tracks `Sigurd` as a hot-path combat target

### Current Known State

- the runtime tree is smaller and easier to reason about
- the project now has one active synthetic `Job07` carrier branch instead of several competing legacy paths

### Русский

#### Removed

- удалён устаревший `game/job07_runtime_probe.lua`
- удалён probe UI / probe registry код, который обслуживал только старую ветку `Job07` probe
- удалён старый inline `Job07` minimal experiment из `game/action_research.lua`
- удалён старый live runtime capture / comparison для `Sigurd` из `game/action_research.lua`
- удалена устаревшая `Sigurd` summary-сериализация из `core/log.lua`

#### Changed

- версия проекта теперь `0.8.4-runtime-cleanup`
- активный runtime write path для `Job07` теперь сосредоточен вокруг:
  - `game/ai/synthetic_job07_adapter.lua`
  - `game/ai/job07_sigurd_profile.lua`
- `action_research` теперь сосредоточен на:
  - `player`
  - `main_pawn`
  и больше не ведёт `Sigurd` как hot-path combat target

#### Current Known State

- runtime-дерево стало меньше и проще для анализа
- у проекта теперь одна активная synthetic `Job07` carrier-ветка вместо нескольких конкурирующих legacy-путей

## 0.8.3-phase-bound-ai-data - 2026-03-23

### Added

- phase-bound in-mod AI data capture for:
  - `idle`
  - `pre_combat`
  - `during_combat`
  - `post_combat`
- new runtime event:
  - `main_pawn_ai_data_phase_changed`
- new phase-aware comparison event:
  - `main_pawn_job01_job07_phase_ai_compare_changed`

### Changed

- `game/pawn_ai_data_research.lua` now keys domain snapshots by job and combat phase
- `_JobDecisions` snapshots now include richer branch-entry summaries
- blackboard snapshots now include richer interesting-field summaries
- project version is now `0.8.3-phase-bound-ai-data`

### Current Known State

- the integrated AI data branch is now much closer to the manual `Content Editor` pipeline
- the mod now captures phase-disciplined `Job01 vs Job07` evidence directly in runtime logs

### Русский

#### Added

- phase-bound in-mod AI data capture для:
  - `idle`
  - `pre_combat`
  - `during_combat`
  - `post_combat`
- новое runtime-событие:
  - `main_pawn_ai_data_phase_changed`
- новое phase-aware событие сравнения:
  - `main_pawn_job01_job07_phase_ai_compare_changed`

#### Changed

- `game/pawn_ai_data_research.lua` теперь ключует domain snapshots по job и боевой фазе
- snapshots по `_JobDecisions` теперь содержат более богатые branch-entry summaries
- snapshots по blackboard теперь содержат более богатые summaries по interesting fields
- версия проекта теперь `0.8.3-phase-bound-ai-data`

#### Current Known State

- интегрированная AI data-ветка теперь намного ближе к ручному `Content Editor` pipeline
- мод теперь снимает phase-disciplined evidence по `Job01 vs Job07` прямо в runtime logs

## 0.8.2-ai-data-research - 2026-03-23

### Added

- integrated in-mod data-layer inspection module:
  - `game/pawn_ai_data_research.lua`
- runtime capture for:
  - `AIGoalActionData`
  - `_BattleAIData`
  - `OrderData`
  - `_JobDecisions`
  - blackboard collections
  - current job parameter snapshot
- automatic `Job01` vs `Job07` comparison event in session logs
- documented `Pawn Share Settings` as a network-safety reference

### Changed

- the `Content Editor` inspection branch is now no longer only a manual playbook
- the mod can now emit direct AI data snapshots for `main_pawn` during runtime
- docs now define an explicit online/share safety boundary for the core AI branch
- project version is now `0.8.2-ai-data-research`

### Current Known State

- direct runtime logging is now available for the main data-layer comparison branch
- `Job07` combat behavior is still unresolved, but the mod now captures stronger evidence directly

## 0.8.1-docs-refresh - 2026-03-23

### Added

- bilingual, English-first documentation refresh
- documented `Content Editor` as the next direct data-layer research path
- documented the `Sigurd`-inspired phased `Job07` profile
- documented concrete `Content Editor` reference paths and the direct `Job01 vs Job07` inspection plan
- added a dedicated `Content Editor` research playbook

### Changed

- updated the project description from unlock-focused wording to AI-runtime wording
- updated the working `Job07` model:
  - native candidate/context problem first
  - pack injection problem second
- updated roadmap priorities around combat carrier, target tracking, and `_BattleAIData` / `_JobDecisions`
- clarified that `Sigurd` is a reference profile, not a required live donor

### Fixed

- removed broken mojibake Russian sections from the main docs set
- normalized the documentation set to clean bilingual formatting

### Current Known State

- unlock works
- `Job01` remains the healthy combat baseline
- `main_pawn Job07` still does not show stable native combat behavior
- synthetic `Job07` can raise nodes, but real combat carrier adoption is still incomplete
- `Content Editor` is now part of the active research plan for data-layer inspection

## 0.8.0-architecture-refactor - 2026-03-22 to 2026-03-23

### Added

- dedicated runtime module:
  - `game/ai/synthetic_job07_adapter.lua`
- separate `Sigurd`-inspired phased profile:
  - `game/ai/job07_sigurd_profile.lua`
- low-noise `Job07` carrier tracing in the decision/runtime layer
- direct decision lifecycle coverage around:
  - `chooseDecision`
  - `startDecision`
  - `lateUpdateDecision`
  - `endDecision`
- bounded synthetic observation and release logging

### Changed

- the project now treats `Job07` as:
  - native candidate / context problem first
  - pack-injection problem second
- `Sigurd` is now treated primarily as a reference profile, not as a mandatory live donor
- the synthetic branch now uses a phased profile instead of a flat pack rotation
- the main docs are now maintained as bilingual, English-first documentation

### Fixed

- multiple Lua forward-declaration and runtime nil-call bugs in research/logging code
- guild UI hook isolation so unlock remains available while unstable menu hooks stay quarantined
- `requestSkipThink()` resolution through `app.DecisionEvaluationModule`
- synthetic adapter lifecycle now supports:
  - `apply`
  - `hold`
  - `release`

### Current Known State

- unlock works
- `Job01` remains a healthy combat baseline
- `main_pawn Job07` still does not show stable native combat behavior
- synthetic `Job07` can raise nodes, but real combat carrier adoption is still incomplete

---

## Русский

## 0.8.2-ai-data-research - 2026-03-23

### Added

- встроенный in-mod data-layer inspection module:
  - `game/pawn_ai_data_research.lua`
- runtime capture для:
  - `AIGoalActionData`
  - `_BattleAIData`
  - `OrderData`
  - `_JobDecisions`
  - blackboard collections
- current job parameter snapshot
- автоматическое событие сравнения `Job01` vs `Job07` в session logs
- задокументирован `Pawn Share Settings` как reference по network safety

### Changed

- ветка `Content Editor` inspection теперь больше не только ручной playbook
- мод теперь умеет эмитить прямые AI data snapshots для `main_pawn` во время runtime
- docs теперь явно фиксируют online/share safety boundary для core AI-ветки
- версия проекта теперь `0.8.2-ai-data-research`

### Current Known State

- для основной data-layer ветки теперь доступен прямой runtime logging
- `Job07` combat behavior всё ещё не решён, но мод теперь снимает более сильные прямые доказательства

## 0.8.1-docs-refresh - 2026-03-23

### Added

- двуязычное, English-first обновление документации
- документирован `Content Editor` как следующая прямая data-layer ветка исследования
- документирован `Sigurd`-inspired phased `Job07` profile
- документированы конкретные `Content Editor` reference-path и прямой план inspection `Job01 vs Job07`
- добавлен отдельный `Content Editor` research playbook

### Changed

- описание проекта обновлено с unlock-focused формулировок на AI-runtime формулировки
- обновлена рабочая модель `Job07`:
  - сначала проблема native candidate/context
  - потом проблема pack injection
- обновлены приоритеты roadmap вокруг combat carrier, target tracking и `_BattleAIData` / `_JobDecisions`
- уточнено, что `Sigurd` — это reference profile, а не обязательный live donor

### Fixed

- удалены сломанные mojibake-русские секции из основного комплекта docs
- весь комплект документации приведён к чистому двуязычному форматированию

### Current Known State

- unlock работает
- `Job01` остаётся здоровым combat baseline
- `main_pawn Job07` всё ещё не показывает стабильное native combat behavior
- synthetic `Job07` умеет поднимать nodes, но real combat carrier adoption всё ещё неполная
- `Content Editor` теперь входит в активный исследовательский план для data-layer inspection

## 0.8.0-architecture-refactor - 2026-03-22 to 2026-03-23

### Added

- отдельный runtime module:
  - `game/ai/synthetic_job07_adapter.lua`
- отдельный `Sigurd`-inspired phased profile:
  - `game/ai/job07_sigurd_profile.lua`
- low-noise `Job07` carrier tracing в decision/runtime layer
- прямое покрытие decision lifecycle вокруг:
  - `chooseDecision`
  - `startDecision`
  - `lateUpdateDecision`
  - `endDecision`
- bounded synthetic observation и release logging

### Changed

- проект теперь рассматривает `Job07` так:
  - сначала проблема native candidate / context
  - потом проблема pack injection
- `Sigurd` теперь рассматривается прежде всего как reference profile, а не как обязательный live donor
- synthetic branch теперь использует phased profile вместо плоской pack rotation
- основной комплект docs теперь ведётся как bilingual documentation с English-first порядком

### Fixed

- несколько Lua forward-declaration и runtime nil-call багов в research/logging code
- изоляция guild UI hooks, чтобы unlock оставался рабочим, пока нестабильные menu hooks находятся в quarantine
- `requestSkipThink()` теперь резолвится через `app.DecisionEvaluationModule`
- synthetic adapter lifecycle теперь поддерживает:
  - `apply`
  - `hold`
  - `release`

### Current Known State

- unlock работает
- `Job01` остаётся здоровым combat baseline
- `main_pawn Job07` всё ещё не показывает стабильное native combat behavior
- synthetic `Job07` умеет поднимать nodes, но real combat carrier adoption пока неполная

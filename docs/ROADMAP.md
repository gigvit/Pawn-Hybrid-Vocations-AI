# ROADMAP

## English

### Current Focus

Current build line: `0.8.x`

Current practical goal:

Understand why `main_pawn` on `Job07` does not adopt a stable native job-specific combat runtime, and repair the native research toolchain far enough to prove or disprove native candidate availability.

### Strategic Direction

Current project direction:

- `native-first`

Supporting rules:

- synthetic `Job07` stays available as fallback/test harness
- synthetic `Job07` attack phases must stay loadout-correct; unmapped skill-backed phases should be blocked rather than guessed
- `Sigurd` stays outside the hot path until a clean control scenario is available again
- direct data-layer inspection is now a first-class workstream, not a side experiment

### Structural Baseline

Current structural baseline:

- rejected legacy `Job07` probe branches are already removed from the hot path
- unlock is consolidated in `game/hybrid_unlock.lua`
- loadout inspection is consolidated in `game/loadout_research.lua`
- compatibility runtime fields are intentionally preserved while the codebase shrinks

### Priority Workstreams

#### 1. Repair native data-layer resolution

Goal:

- make `pawn_ai_data_research` resolve the real controller/data objects instead of producing `nil` snapshots
- produce a stable readiness/blocker summary so each validation log tells us exactly what still blocks native proof

Targets:

- `PawnBattleController`
- `PawnUpdateController`
- `PawnOrderController`
- `_BattleAIData`
- `AIGoalActionData`
- `OrderData`
- `_JobDecisions`

Module:

- `game/pawn_ai_data_research.lua`

Priority:

- highest

#### 2. Validate new hook families from external references

Goal:

- turn newly discovered hooks into a verified intervention map instead of an unprioritized list

Method:

- validate first on `Job01 main_pawn`
- validate next on `Job07 main_pawn`
- validate next on the synthetic fallback branch
- use real `Sigurd` later only as a control scenario

Outputs:

- hook verification matrix
- classification:
  - general-purpose
  - native-`Job07` relevant
  - synthetic-only useful
  - likely real-`Sigurd`-control-only

Priority:

- highest

#### 3. Native candidate research

Goal:

- prove or disprove the working hypothesis that `main_pawn Job07` lacks a stable native combat candidate

Focus:

- native decision observation
- native controller/data evidence
- native context admission

Modules:

- `game/action_research.lua`
- `game/pawn_ai_data_research.lua`

Priority:

- highest

#### 4. Combat-context research

Goal:

- understand the context that keeps `Job07` in `Common/*`, `ch1/*`, and `nil`

Focus areas:

- target type
- target distance
- selector branch
- blackboard source
- move / strafe / reposition loop
- post-combat release conditions

Module:

- `game/action_research.lua`

Priority:

- high

#### 5. Keep synthetic Job07 as fallback harness

Goal:

- preserve one controllable write path for bounded experiments while native research continues

Rules:

- do not expand synthetic into multiple competing branches again
- keep it useful for comparison and reproduction
- do not let it redefine the main project goal

Modules:

- `game/ai/synthetic_job07_adapter.lua`
- `game/ai/job07_sigurd_profile.lua`

Priority:

- high

#### 6. Reacquire Sigurd later as a control scenario

Goal:

- use a clean `Sigurd` runtime later to validate hooks and compare native `Job07` context

Not current assumption:

- `Sigurd` is not needed to start the current native-first work

Why it still matters later:

- stronger control for `Job07`-specific hooks
- better comparison target for `_BattleAIData`, `_JobDecisions`, selector, and blackboard state

Priority:

- medium

#### 7. Guild UI residue cleanup

Goal:

- keep unlock working
- remove remaining guild list instability without reopening unsafe menu hook paths

Priority:

- medium

#### 8. Network safety boundary

Goal:

- keep the core AI branch isolated from online pawn-share side effects

Reference:

- local `Pawn Share Settings` example

Rules:

- do not use upload / download / rental validator hooks in the core AI branch
- keep any future online-aware work isolated and opt-in
- prefer offline job/state lookups such as `ContextDBMS -> OfflineDB -> JobContext`

Priority:

- medium

#### 9. BT/FSM or native plugin escalation

Goal:

- reserve for the point where Lua observation, data inspection, and bounded fallback testing are exhausted

Priority:

- later / conditional

### Immediate Next Success Criteria

We consider the next strong result to be any of:

- `pawn_ai_data_research` resolves real controller/data objects in live tests
- direct `_BattleAIData` / `_JobDecisions` evidence confirms or disproves native candidate availability
- a verified hook matrix exists for the newly discovered hook families
- `Job07` native context becomes explainable as:
  - branch missing
  - branch dormant
  - context-blocked
  - or mixed

### Not Current Goals

The following are not the current focus:

- treating synthetic `Job07` as the final product path
- broad support for `Job08`, `Job09`, and `Job10`
- full BHVT/FSM authoring
- polished end-user UI

---

## Русский

### Текущий фокус

Текущая build-line: `0.8.x`

Текущая практическая цель:

Понять, почему `main_pawn` на `Job07` не принимает стабильный native job-specific combat runtime, и починить native research toolchain настолько, чтобы доказать или опровергнуть наличие native candidate.

### Стратегическое направление

Текущее направление проекта:

- `native-first`

Поддерживающие правила:

- synthetic `Job07` остаётся доступным как fallback/test harness
- `Sigurd` остаётся вне hot path, пока у нас снова не появится чистый control scenario
- direct data-layer inspection теперь является workstream первого класса, а не побочным экспериментом

### Структурная база

Текущая структурная база:

- отвергнутые legacy-ветки `Job07` probe уже убраны из hot path
- unlock консолидирован в `game/hybrid_unlock.lua`
- loadout inspection консолидирован в `game/loadout_research.lua`
- совместимые runtime-поля намеренно сохранены, пока кодовая база уменьшается

### Приоритетные направления работы

#### 1. Починить native data-layer resolution

Цель:

- заставить `pawn_ai_data_research` резолвить реальные controller/data objects вместо `nil` snapshots

Цели:

- `PawnBattleController`
- `PawnUpdateController`
- `PawnOrderController`
- `_BattleAIData`
- `AIGoalActionData`
- `OrderData`
- `_JobDecisions`

Модуль:

- `game/pawn_ai_data_research.lua`

Приоритет:

- самый высокий

#### 2. Валидировать новые семейства hooks из внешних reference-модов

Цель:

- превратить новые найденные hooks в верифицированную карту вмешательства, а не в неупорядоченный список

Метод:

- сначала валидировать на `Job01 main_pawn`
- затем валидировать на `Job07 main_pawn`
- затем валидировать на synthetic fallback branch
- реального `Sigurd` использовать позже только как control scenario

Выходы:

- hook verification matrix
- классификация:
  - general-purpose
  - native-`Job07` relevant
  - useful only for synthetic
  - likely useful only with real-`Sigurd` control

Приоритет:

- самый высокий

#### 3. Native candidate research

Цель:

- доказать или опровергнуть рабочую гипотезу, что `main_pawn Job07` не имеет стабильного native combat candidate

Фокус:

- native decision observation
- native controller/data evidence
- native context admission

Модули:

- `game/action_research.lua`
- `game/pawn_ai_data_research.lua`

Приоритет:

- самый высокий

#### 4. Combat-context research

Цель:

- понять контекст, который удерживает `Job07` в `Common/*`, `ch1/*` и `nil`

Фокусные зоны:

- target type
- target distance
- selector branch
- blackboard source
- цикл move / strafe / reposition
- post-combat release conditions

Модуль:

- `game/action_research.lua`

Приоритет:

- высокий

#### 5. Сохранить synthetic Job07 как fallback harness

Цель:

- сохранить один контролируемый write path для ограниченных экспериментов, пока продолжается native research

Правила:

- не раздувать synthetic снова до нескольких конкурирующих веток
- сохранять его полезным для сравнения и воспроизведения
- не позволять ему снова подменять основную цель проекта

Модули:

- `game/ai/synthetic_job07_adapter.lua`
- `game/ai/job07_sigurd_profile.lua`

Приоритет:

- высокий

#### 6. Вернуть Sigurd позже как control scenario

Цель:

- использовать чистый runtime `Sigurd` позже для валидации hooks и сравнения native `Job07` context

Что сейчас не предполагается:

- `Sigurd` не нужен, чтобы начать текущую native-first работу

Почему он всё ещё важен позже:

- более сильный контроль для `Job07`-specific hooks
- лучшая точка сравнения для `_BattleAIData`, `_JobDecisions`, selector и blackboard state

Приоритет:

- средний

#### 7. Cleanup остаточной guild UI-ветки

Цель:

- сохранить рабочий unlock
- убрать оставшуюся нестабильность guild list без возврата опасных menu hooks

Приоритет:

- средний

#### 8. Граница сетевой безопасности

Цель:

- держать core AI-ветку изолированной от online pawn-share side effects

Reference:

- локальный пример `Pawn Share Settings`

Правила:

- не использовать upload / download / rental validator hooks в core AI-ветке
- держать любую будущую online-aware работу изолированной и opt-in
- предпочитать offline lookup пути вроде `ContextDBMS -> OfflineDB -> JobContext`

Приоритет:

- средний

#### 9. Эскалация в BT/FSM или native plugin

Цель:

- оставить этот путь на момент, когда Lua observation, data inspection и bounded fallback testing будут исчерпаны

Приоритет:

- позже / условно

### Ближайшие критерии успеха

Следующим сильным результатом считаем любой из:

- `pawn_ai_data_research` начинает резолвить реальные controller/data objects в live tests
- direct `_BattleAIData` / `_JobDecisions` evidence подтверждает или опровергает native candidate availability
- для новых семейств hooks существует проверенная verification matrix
- native `Job07` context становится объяснимым как:
  - branch missing
  - branch dormant
  - context-blocked
  - или mixed

### Что сейчас не является целью

Следующее сейчас не в фокусе:

- рассматривать synthetic `Job07` как финальный продуктовый путь
- широкая поддержка `Job08`, `Job09` и `Job10`
- полное BHVT/FSM authoring
- polished end-user UI

# ROADMAP

## English

### Current Focus

Current build line: `0.8.x`

Current practical goal:

Understand whether the engine fails to fully populate or retain native `Job07` combat admission for `main_pawn` in pawn-role, and keep the native research toolchain stable enough to prove or disprove that hypothesis.

### Strategic Direction

Current project direction:

- `native-first`

Supporting rules:

- synthetic `Job07` stays available as fallback and bounded test harness
- synthetic `Job07` stays out of the active runtime path by default while native-first work continues
- synthetic `Job07` attack phases must stay loadout-correct; unmapped skill-backed phases should be blocked rather than guessed
- `Sigurd` stays outside the hot path until a clean control scenario is available again
- direct data-layer inspection is a first-class workstream, not a side experiment
- performance safety matters as much as research depth

### Structural Baseline

Current structural baseline:

- rejected legacy `Job07` probe branches are already removed from the hot path
- unlock is consolidated in `game/hybrid_unlock.lua`
- loadout inspection is consolidated in `game/loadout_research.lua`
- compatibility runtime fields are intentionally preserved while the codebase shrinks

### Priority Workstreams

#### 1. Keep safe native telemetry stable

Goal:

- keep `pawn_ai_data_research` useful without collapsing FPS
- prefer semantic signatures and stable counts over broad reflective scans
- preserve enough signal to follow `Job07` admission loss over time

Targets:

- `_CurrentGoalList`
- `_CurrentAddDecisionList`
- `MainDecisions`
- `PreDecisions`
- `PostDecisions`
- `ActiveDecisionPacks`

Module:

- `game/pawn_ai_data_research.lua`

Priority:

- highest

#### 2. Track the `Job07` degradation path

Goal:

- capture the transition from richer native pool to poorer native pool
- identify what changes near the shift from parity to degraded state

Current target pattern:

- richer or parity state
- then mid degradation
- then low-admission state

Modules:

- `game/pawn_ai_data_research.lua`
- `game/action_research.lua`

Priority:

- highest

#### 3. Build repeatable `Job01` vs `Job07` evidence

Goal:

- prove that the difference between `Job01` and `Job07` is repeatable, not a one-off noisy session
- keep collecting low-overhead evidence that supports or weakens the pawn-role role-gating model

Outputs:

- decision-pool compare payloads
- phase-bound compare payloads
- role-gating event summaries

Priority:

- highest

#### 4. Restore strict data-layer proof path

Goal:

- keep improving direct data-layer resolution until `_BattleAIData`, `AIGoalActionData`, `OrderData`, and eventually `_JobDecisions` become trustworthy proof sources

Targets:

- `PawnBattleController`
- `PawnUpdateController`
- `PawnOrderController`
- `_BattleAIData`
- `AIGoalActionData`
- `OrderData`
- `_JobDecisions`

Priority:

- high

#### 5. Validate new hook families from external references

Goal:

- turn newly discovered hooks into a verified intervention map instead of an unprioritized list

Method:

- validate first on `Job01 main_pawn`
- validate next on `Job07 main_pawn`
- use synthetic only when a bounded fallback comparison is useful
- use real `Sigurd` later only as a control scenario

Outputs:

- hook verification matrix
- classification:
  - general-purpose
  - native-`Job07` relevant
  - synthetic-only useful
  - likely real-`Sigurd`-control-only

Priority:

- high

#### 6. Keep synthetic Job07 preserved but retired

Goal:

- preserve one controllable write path for bounded experiments without letting it redefine the project

Rules:

- do not expand synthetic into multiple competing branches again
- do not put synthetic back into the default hot path without a bounded reason
- keep it available for reproduction and fallback comparison

Modules:

- `game/ai/synthetic_job07_adapter.lua`
- `game/ai/job07_sigurd_profile.lua`

Priority:

- high

#### 7. Reacquire Sigurd later as a control scenario

Goal:

- use a clean `Sigurd` runtime later to validate hooks and compare real `Job07` context against `main_pawn Job07`

Not current assumption:

- `Sigurd` is not needed to start the current native-first work

Why it still matters later:

- stronger control for `Job07`-specific hooks
- better comparison target for `_BattleAIData`, `_JobDecisions`, selector, and blackboard state
- the cleanest way to decide whether the current problem is truly pawn-role-specific

Priority:

- medium

#### 8. Guild UI residue cleanup

Goal:

- keep unlock working
- remove remaining guild-list instability without reopening unsafe menu hook paths

Priority:

- medium

#### 9. Network safety boundary

Goal:

- keep the core AI branch isolated from online pawn-share side effects

Reference:

- the project security policy and local offline-safe examples

Rules:

- do not use upload / download / rental validator hooks in the core AI branch
- keep any future online-aware work isolated and opt-in
- prefer offline job/state lookups such as `ContextDBMS -> OfflineDB -> JobContext`

Priority:

- medium

#### 10. BT/FSM or native plugin escalation

Goal:

- reserve for the point where Lua observation, direct data inspection, and bounded fallback testing are exhausted

Priority:

- later / conditional

### Immediate Next Success Criteria

We consider the next strong result to be any of:

- safe native telemetry remains informative without runtime instability
- `Job07` degradation transitions become repeatable and explainable
- direct `_BattleAIData` / `_JobDecisions` evidence confirms or disproves native candidate availability
- a verified hook matrix exists for newly discovered hook families
- the current `Job07` failure becomes explainable as:
  - branch missing
  - branch dormant
  - context-blocked
  - role-gated / under-populated
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

Понять, не проваливает ли движок наполнение или удержание native `Job07` combat admission для `main_pawn` в роли pawn, и держать native research toolchain достаточно стабильным, чтобы доказать или опровергнуть эту гипотезу.

### Стратегическое направление

Текущее направление проекта:

- `native-first`

Поддерживающие правила:

- synthetic `Job07` остаётся доступным как fallback и bounded test harness
- synthetic `Job07` остаётся вне активного runtime path по умолчанию, пока продолжается native-first работа
- synthetic `Job07` attack phases должны оставаться loadout-correct; неразмеченные skill-backed phases нужно блокировать, а не угадывать
- `Sigurd` остаётся вне hot path, пока снова не появится чистый control scenario
- direct data-layer inspection — это полноценный рабочий поток, а не побочный эксперимент
- безопасность производительности так же важна, как глубина исследования

### Структурный baseline

Текущий структурный baseline:

- отвергнутые legacy `Job07` probe-ветки уже убраны из hot path
- unlock консолидирован в `game/hybrid_unlock.lua`
- loadout inspection консолидирован в `game/loadout_research.lua`
- совместимые runtime-поля намеренно сохранены, пока кодовая база уменьшается

### Приоритетные workstreams

#### 1. Держать safe native telemetry стабильной

Цель:

- сохранять полезность `pawn_ai_data_research` без FPS collapse
- предпочитать semantic signatures и стабильные counts широким reflective scan
- сохранять достаточно сигнала, чтобы видеть потерю admission у `Job07` во времени

Цели:

- `_CurrentGoalList`
- `_CurrentAddDecisionList`
- `MainDecisions`
- `PreDecisions`
- `PostDecisions`
- `ActiveDecisionPacks`

Модуль:

- `game/pawn_ai_data_research.lua`

Приоритет:

- highest

#### 2. Отслеживать путь деградации `Job07`

Цель:

- поймать переход от более богатого native pool к более бедному native pool
- понять, что меняется рядом со срывом от паритета к деградации

Текущий целевой паттерн:

- более богатое состояние или паритет
- затем средняя деградация
- затем low-admission state

Модули:

- `game/pawn_ai_data_research.lua`
- `game/action_research.lua`

Приоритет:

- highest

#### 3. Собрать повторяемое evidence `Job01` vs `Job07`

Цель:

- доказать, что разница между `Job01` и `Job07` повторяется, а не является шумом одной сессии
- продолжать собирать low-overhead данные, которые усиливают или ослабляют pawn-role role-gating модель

Выходы:

- decision-pool compare payloads
- phase-bound compare payloads
- role-gating event summaries

Приоритет:

- highest

#### 4. Восстановить строгий data-layer proof path

Цель:

- продолжать улучшать direct data-layer resolution, пока `_BattleAIData`, `AIGoalActionData`, `OrderData` и позже `_JobDecisions` не станут надёжными proof sources

Цели:

- `PawnBattleController`
- `PawnUpdateController`
- `PawnOrderController`
- `_BattleAIData`
- `AIGoalActionData`
- `OrderData`
- `_JobDecisions`

Приоритет:

- high

#### 5. Валидировать новые hook families из внешних референсов

Цель:

- превратить новые hooks в проверенную intervention map, а не в неупорядоченный список

Метод:

- сначала валидировать на `Job01 main_pawn`
- затем на `Job07 main_pawn`
- synthetic использовать только когда полезно ограниченное fallback-сравнение
- реальный `Sigurd` использовать позже только как control scenario

Выходы:

- hook verification matrix
- классификация:
  - general-purpose
  - native-`Job07` relevant
  - synthetic-only useful
  - likely real-`Sigurd`-control-only

Приоритет:

- high

#### 6. Сохранить synthetic Job07, но оставить его retired

Цель:

- сохранить один контролируемый write path для ограниченных экспериментов, не давая ему переопределить проект

Правила:

- не раздувать synthetic снова до нескольких конкурирующих веток
- не возвращать synthetic в default hot path без ограниченной причины
- сохранять его для reproduction и fallback comparison

Модули:

- `game/ai/synthetic_job07_adapter.lua`
- `game/ai/job07_sigurd_profile.lua`

Приоритет:

- high

#### 7. Позже вернуть Sigurd как control scenario

Цель:

- использовать чистый runtime `Sigurd` позже для валидации hooks и сравнения real `Job07` context с `main_pawn Job07`

Что сейчас не предполагается:

- `Sigurd` не нужен, чтобы начать текущую native-first работу

Почему он всё же важен позже:

- более сильный контроль для `Job07`-specific hooks
- лучшая цель сравнения для `_BattleAIData`, `_JobDecisions`, selector и blackboard state
- самый чистый способ понять, действительно ли текущая проблема специфична для pawn-role

Приоритет:

- medium

#### 8. Cleanup остаточного guild UI

Цель:

- сохранить работоспособный unlock
- убрать оставшуюся нестабильность guild list, не возвращая небезопасные menu hook paths

Приоритет:

- medium

#### 9. Граница сетевой безопасности

Цель:

- держать core AI branch изолированной от online pawn-share side effects

Референс:

- security policy проекта и локальные offline-safe примеры

Правила:

- не использовать upload / download / rental validator hooks в core AI branch
- держать любую будущую online-aware работу изолированной и opt-in
- предпочитать offline job/state lookup вроде `ContextDBMS -> OfflineDB -> JobContext`

Приоритет:

- medium

#### 10. Эскалация в BT/FSM или native plugin

Цель:

- оставить на тот момент, когда Lua observation, direct data inspection и bounded fallback testing будут исчерпаны

Приоритет:

- later / conditional

### Ближайшие критерии успеха

Следующим сильным результатом считаем любой из:

- safe native telemetry остаётся информативной без runtime-нестабильности
- переходы деградации `Job07` становятся повторяемыми и объяснимыми
- прямые `_BattleAIData` / `_JobDecisions` evidence подтверждают или опровергают native candidate availability
- существует проверенная hook matrix для новых hook families
- текущая неудача `Job07` становится объяснимой как:
  - branch missing
  - branch dormant
  - context-blocked
  - role-gated / under-populated
  - или смешанная

### Что сейчас не является целью

Следующее не является текущим фокусом:

- рассматривать synthetic `Job07` как финальный продуктовый путь
- широкая поддержка `Job08`, `Job09` и `Job10`
- полное BHVT/FSM authoring
- polished end-user UI

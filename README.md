# Pawn Hybrid Vocations AI

## English

### Overview

`Pawn Hybrid Vocations AI` is a REFramework mod and research project for `Dragon's Dogma 2`.

The project is not about unlock alone. The real target is to make hybrid vocations usable for `main_pawn` at the AI, combat-runtime, and combat-context levels.

Core rule:

`unlock != equipment != skills != combat runtime != pawn combat context != AI parity`

### Current Status

What is already confirmed:

- `main_pawn` can enter hybrid vocation runtime.
- unlock and guild-side vocation access are working.
- `Job07ActionController` resolves for `main_pawn`.
- the decision lifecycle is observable in runtime research.
- `Job01` has healthy combat decisions and job-specific packs.
- engine-level `Job07` behavior exists.
- `main_pawn Job07` still tends to live in `Common/*`, `ch1/*`, and `nil` instead of a stable native `Job07` combat path.

### Strategic Pivot

Current mainline strategy is now:

- `native-first`

This means:

- native `Job07` candidate research is now the main engineering branch
- direct pawn AI data inspection is now the main escalation path
- synthetic `Job07` is kept as:
  - a fallback
  - a test harness
  - a diagnostic bridge
- synthetic `Job07` is no longer treated as the preferred end-state by itself

### Current Job07 Conclusion

Our strongest current model is:

1. engine-level `Job07` behavior exists
2. `main_pawn` likely does not receive a stable native `Job07` combat candidate in vanilla runtime
3. forcing `Job07` nodes is possible
4. the hard problem is native candidate admission, carrier adoption, target tracking, hit-functional behavior, and clean release

### What We Can Do Without Sigurd

We can still do valuable work without a live `Sigurd` runtime:

- fix direct resolver access to:
  - `PawnBattleController`
  - `PawnUpdateController`
  - `PawnOrderController`
  - `_BattleAIData`
  - `_JobDecisions`
  - `OrderData`
  - `AIGoalActionData`
- verify new hooks from external references against:
  - `Job01 main_pawn`
  - `Job07 main_pawn`
  - the existing synthetic harness
- classify hooks as:
  - general-purpose
  - `Job07`-relevant
  - likely `Sigurd`-specific
- continue narrowing the `native candidate absent / context blocked` hypothesis

### What Sigurd Still Matters For

`Sigurd` remains useful as:

- a reference actor
- a source of observed `Job07` phases and packs
- a future control scenario for validating newly discovered hooks

`Sigurd` is currently not treated as:

- a mandatory live donor
- a stable runtime dependency
- the center of the hot path

### Current Implementation Direction

Current implementation direction:

- observe native runtime through decision hooks
- inspect pawn AI data directly inside the mod
- prioritize native candidate and context research
- keep one synthetic `Job07` write path as fallback/test harness
- avoid reintroducing legacy probe branches or live-donor dependency

### Current Main Modules

- `game/hybrid_unlock.lua`
- `game/loadout_research.lua`
- `game/action_research.lua`
- `game/pawn_ai_data_research.lua`
- `game/ai/synthetic_job07_adapter.lua`
- `game/ai/job07_sigurd_profile.lua`

### Network Safety Boundary

The project explicitly treats online and pawn-share code paths as out of scope for the core AI branch.

Main online/share paths to avoid in the hot path:

- `app.PawnRentalValidator`
- `app.OnlinePawnDataFormatter`
- `app.PawnServerController`
- `app.network.PawnApiRequester`

Useful safe local pattern:

- offline main-pawn job lookup through `app.ContextDBMS -> OfflineDB -> JobContext`

### Repository Guide

- Main knowledge base: [`docs/KNOWLEDGE_BASE.md`](./docs/KNOWLEDGE_BASE.md)
- Contribution rules: [`docs/CONTRIBUTING.md`](./docs/CONTRIBUTING.md)
- Forward plan: [`docs/ROADMAP.md`](./docs/ROADMAP.md)
- Content Editor playbook: [`docs/CONTENT_EDITOR_RESEARCH_PLAYBOOK.md`](./docs/CONTENT_EDITOR_RESEARCH_PLAYBOOK.md)
- Change history: [`docs/CHANGELOG.md`](./docs/CHANGELOG.md)
- License: [`LICENSE`](./LICENSE)
- Security policy: [`SECURITY.md`](./SECURITY.md)

### Quick Start

1. Install REFramework for `Dragon's Dogma 2`.
2. Copy the contents of `mod/` into the game's REFramework structure.
3. Launch the game.
4. Confirm logs are written to:
   - `reframework\data\PawnHybridVocationsAI\logs\`

### Recommended Test Direction

Current preferred test direction:

1. validate `Job01` baseline
2. validate `Job07` runtime in noisy real gameplay
3. focus analysis on:
   - native decision hooks
   - phase-bound AI data capture
   - controller/data resolver success
   - synthetic fallback events only as secondary evidence

---

## Русский

### Обзор

`Pawn Hybrid Vocations AI` — это REFramework-мод и исследовательский проект для `Dragon's Dogma 2`.

Проект не сводится только к unlock. Реальная цель — сделать hybrid-профессии пригодными для `main_pawn` на уровне AI, боевого runtime и боевого контекста.

Основное правило:

`unlock != equipment != skills != combat runtime != pawn combat context != AI parity`

### Текущее состояние

Что уже подтверждено:

- `main_pawn` можно перевести в runtime-состояние hybrid-профессии.
- unlock и guild-side доступ к профессии работают.
- у `main_pawn` резолвится `Job07ActionController`.
- decision lifecycle наблюдается в runtime research.
- у `Job01` есть здоровые боевые decisions и job-specific packs.
- engine-level `Job07` behavior существует.
- `Job07` у `main_pawn` по-прежнему в основном живёт в `Common/*`, `ch1/*` и `nil`, а не в стабильном native `Job07` combat path.

### Стратегический поворот

Основная рабочая стратегия проекта теперь:

- `native-first`

Это значит:

- mainline-ветка теперь снова ориентирована на native `Job07` candidate research
- прямой inspect pawn AI data теперь является главным путём эскалации
- synthetic `Job07` сохраняется как:
  - fallback
  - test harness
  - диагностический мост
- synthetic `Job07` больше не рассматривается как предпочтительное конечное состояние само по себе

### Текущий вывод по Job07

Наша strongest current model такая:

1. engine-level `Job07` behavior существует
2. `main_pawn`, скорее всего, не получает стабильный native `Job07` combat candidate в vanilla runtime
3. форсить `Job07` node мы умеем
4. главная проблема сейчас — native candidate admission, carrier adoption, target tracking, hit-functional behavior и корректный release

### Что мы можем делать без Sigurd

Без живого runtime `Sigurd` у нас всё ещё много полезной работы:

- починить прямой resolver-доступ к:
  - `PawnBattleController`
  - `PawnUpdateController`
  - `PawnOrderController`
  - `_BattleAIData`
  - `_JobDecisions`
  - `OrderData`
  - `AIGoalActionData`
- проверять новые hooks из внешних reference-модов на:
  - `Job01 main_pawn`
  - `Job07 main_pawn`
  - существующем synthetic harness
- классифицировать hooks как:
  - general-purpose
  - `Job07`-relevant
  - вероятно `Sigurd`-specific
- дальше сужать гипотезу `native candidate absent / context blocked`

### Зачем нам всё ещё нужен Sigurd

`Sigurd` всё ещё полезен как:

- reference actor
- источник наблюдавшихся `Job07` phases и packs
- будущий контрольный сценарий для проверки новых hooks

`Sigurd` сейчас не рассматривается как:

- обязательный live donor
- стабильная runtime-зависимость
- центр hot path

### Текущее направление реализации

Текущее направление реализации такое:

- наблюдать native runtime через decision hooks
- inspect pawn AI data напрямую внутри мода
- приоритизировать native candidate и context research
- сохранять один synthetic `Job07` write path как fallback/test harness
- не возвращать legacy probe-ветки и live-donor dependency

### Основные текущие модули

- `game/hybrid_unlock.lua`
- `game/loadout_research.lua`
- `game/action_research.lua`
- `game/pawn_ai_data_research.lua`
- `game/ai/synthetic_job07_adapter.lua`
- `game/ai/job07_sigurd_profile.lua`

### Граница сетевой безопасности

Проект явно считает online и pawn-share ветки вне scope core AI-ветки.

Основные online/share пути, которых нужно избегать в hot path:

- `app.PawnRentalValidator`
- `app.OnlinePawnDataFormatter`
- `app.PawnServerController`
- `app.network.PawnApiRequester`

Полезный безопасный локальный паттерн:

- offline lookup профессии `main_pawn` через `app.ContextDBMS -> OfflineDB -> JobContext`

### Навигация по репозиторию

- Основная база знаний: [`docs/KNOWLEDGE_BASE.md`](./docs/KNOWLEDGE_BASE.md)
- Правила внесения изменений: [`docs/CONTRIBUTING.md`](./docs/CONTRIBUTING.md)
- План дальнейшей работы: [`docs/ROADMAP.md`](./docs/ROADMAP.md)
- Playbook по `Content Editor`: [`docs/CONTENT_EDITOR_RESEARCH_PLAYBOOK.md`](./docs/CONTENT_EDITOR_RESEARCH_PLAYBOOK.md)
- История изменений: [`docs/CHANGELOG.md`](./docs/CHANGELOG.md)
- Лицензия: [`LICENSE`](./LICENSE)
- Security policy: [`SECURITY.md`](./SECURITY.md)

### Быстрый старт

1. Установить REFramework для `Dragon's Dogma 2`.
2. Скопировать содержимое `mod/` в структуру REFramework игры.
3. Запустить игру.
4. Убедиться, что логи пишутся в:
   - `reframework\data\PawnHybridVocationsAI\logs\`

### Предпочтительное направление тестов

Сейчас предпочтительное направление тестов такое:

1. валидировать baseline `Job01`
2. валидировать `Job07` в шумном реальном геймплее
3. фокусировать анализ на:
   - native decision hooks
   - phase-bound AI data capture
   - успехе resolver-а controller/data объектов
   - событиях synthetic fallback только как вторичном доказательстве

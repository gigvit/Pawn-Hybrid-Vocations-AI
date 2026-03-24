# Pawn Hybrid Vocations AI

## English

### Overview

`Pawn Hybrid Vocations AI` is a REFramework mod and research project for `Dragon's Dogma 2`.

The project is not only about unlock. The actual target is to make hybrid vocations usable for `main_pawn` at the AI, combat-runtime, and combat-context levels.

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
- `main_pawn Job07` still tends to drift through `Common/*`, `ch1/*`, and `nil` instead of holding a stable native `Job07` combat path.

### Current Working Hypothesis

Current primary model:

- the engine does not fully populate or retain native `Job07` combat admission for `main_pawn` in pawn-role

This is more precise than:

- "`Job07` does not exist"
- "we only need a better pack"

Why this model is stronger now:

- `Job07` types, actions, and behavior fragments clearly exist in the engine
- `Job01` and `Job07` share the same broad native controller graph
- safe native telemetry shows that `Job07` sometimes briefly matches `Job01`, then degrades
- `Job07 main_pawn` repeatedly fails to hold stable native combat admission

### Latest Native Signal

Current safe-native evidence already shows a repeatable pattern:

- `Job07` can briefly reach the same safe decision-pool counts as `Job01`
- then `Job07` tends to degrade from a richer pool to a poorer pool
- then `Job07` remains stuck in weaker runtime context without normal combat admission

Observed practical pattern:

- short parity
- then degradation
- then loss of stable combat admission

This is why the current investigation is centered on native role-gating and admission loss, not on random pack forcing.

### Strategic Direction

Current mainline strategy:

- `native-first`

This means:

- native `Job07` research is the main engineering branch
- direct pawn AI data inspection is a first-class workstream
- safe native decision-pool telemetry is treated as a core signal
- synthetic `Job07` remains documented and preserved, but not as the preferred end-state

### Current Runtime Policy

Runtime policy right now:

- synthetic `Job07` is preserved as project knowledge and fallback tooling
- synthetic `Job07` is retired from the active hot path by default
- synthetic attack phases must respect real guild and loadout state
- unmapped skill-backed synthetic phases are treated as blocked by default

### What Synthetic Already Proved

Synthetic `Job07` already proved that:

- Lua can write `Job07`-related behavior through blackboard and act-inter paths
- `Job07` nodes can be raised on `main_pawn`
- `requestSkipThink()` works as a practical runtime lever

Synthetic `Job07` did not solve:

- stable native-like combat carrier adoption
- reliable target tracking
- hit-functional melee behavior
- clean release in all runtime conditions

Practical conclusion:

- synthetic is a useful diagnostic bridge
- synthetic is a weak final answer unless native research is exhausted

### What We Can Still Do Without Sigurd

Even without a clean live `Sigurd` runtime, we can still:

- compare `Job01` and `Job07` on `main_pawn`
- inspect `_BattleAIData`, `AIGoalActionData`, `OrderData`, and safe decision-pool counts
- validate new hook families against baseline and problematic jobs
- strengthen or weaken the role-gating hypothesis with repeated low-overhead evidence

### What Sigurd Still Matters For

`Sigurd` still matters as:

- a reference actor
- a source of observed `Job07` phases and packs
- a future control scenario for strict role-gating validation

`Sigurd` is currently not treated as:

- a mandatory live donor
- a stable runtime dependency
- the center of the hot path

### Method Priority

Use now:

- narrow runtime hooks
- direct field-based AI inspection
- safe native decision-pool telemetry
- `Job01` vs `Job07` compare

Use later:

- `Sigurd` as a clean control scenario
- controlled `Content Editor` experiments
- donor-context cloning only after the native toolchain is stable

Avoid in the hot path:

- broad getter-heavy probing
- online/share/rental hooks
- full BT/FSM authoring as the immediate next step

### Main Modules

- `game/hybrid_unlock.lua`
- `game/loadout_research.lua`
- `game/action_research.lua`
- `game/pawn_ai_data_research.lua`
- `game/ai/synthetic_job07_adapter.lua`
- `game/ai/job07_sigurd_profile.lua`

### Network Safety Boundary

The core AI branch is intentionally local-runtime-first.

Avoid in the hot path:

- `app.PawnRentalValidator`
- `app.OnlinePawnDataFormatter`
- `app.PawnServerController`
- `app.network.PawnApiRequester`

Useful safe local pattern:

- offline main-pawn job lookup through `app.ContextDBMS -> OfflineDB -> JobContext`

### Repository Guide

- Knowledge base: [`docs/KNOWLEDGE_BASE.md`](./docs/KNOWLEDGE_BASE.md)
- Roadmap: [`docs/ROADMAP.md`](./docs/ROADMAP.md)
- Contributing: [`docs/CONTRIBUTING.md`](./docs/CONTRIBUTING.md)
- Content Editor playbook: [`docs/CONTENT_EDITOR_RESEARCH_PLAYBOOK.md`](./docs/CONTENT_EDITOR_RESEARCH_PLAYBOOK.md)
- Change history: [`docs/CHANGELOG.md`](./docs/CHANGELOG.md)
- Security policy: [`SECURITY.md`](./SECURITY.md)
- License: [`LICENSE`](./LICENSE)

### Quick Start

1. Install REFramework for `Dragon's Dogma 2`.
2. Copy the contents of `mod/` into the game's REFramework directory.
3. Launch the game.
4. Confirm logs are written under `reframework/data/PawnHybridVocationsAI/logs/`.

### Recommended Test Direction

Current preferred test direction:

1. validate `Job01` baseline
2. validate `Job07` runtime in noisy real gameplay
3. focus analysis on:
   - native decision hooks
   - safe decision-pool transitions
   - phase-bound AI data capture
   - controller/data resolver success
   - role-gating signals

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
- decision lifecycle наблюдается через runtime research.
- у `Job01` есть здоровые боевые decisions и job-specific packs.
- engine-level `Job07` behavior существует.
- `Job07` у `main_pawn` по-прежнему часто дрейфует через `Common/*`, `ch1/*` и `nil`, вместо того чтобы удерживать стабильный native `Job07` combat path.

### Текущая рабочая гипотеза

Текущая основная модель:

- движок не полностью наполняет или не удерживает native `Job07` combat admission для `main_pawn` в роли pawn

Это точнее, чем:

- "`Job07` вообще не существует"
- "нам просто нужен pack получше"

Почему эта модель сейчас сильнее:

- `Job07` типы, действия и фрагменты поведения в движке явно существуют
- `Job01` и `Job07` используют один и тот же широкий native controller graph
- безопасная native телеметрия показывает, что `Job07` иногда кратко совпадает с `Job01`, а затем деградирует
- `Job07 main_pawn` повторяемо не удерживает стабильный native combat admission

### Последний сильный native-сигнал

Текущие safe-native данные уже показывают повторяемый паттерн:

- `Job07` может кратко выйти на те же safe decision-pool counts, что и `Job01`
- затем `Job07` обычно деградирует от более насыщенного pool к более бедному
- после этого `Job07` остаётся в более слабом runtime context без нормального combat admission

Практический паттерн:

- краткий паритет
- затем деградация
- затем потеря стабильного combat admission

Именно поэтому текущее исследование сосредоточено на native role-gating и потере admission, а не на случайном форсинге pack-ов.

### Стратегическое направление

Текущая mainline-стратегия:

- `native-first`

Это означает:

- native `Job07` research — главная инженерная ветка
- прямой inspect pawn AI data — полноценный основной workstream
- safe native decision-pool telemetry считается ключевым сигналом
- synthetic `Job07` сохраняется в проекте и документации, но не считается предпочтительным конечным состоянием

### Текущая runtime-политика

Текущая политика runtime:

- synthetic `Job07` сохраняется как знание проекта и fallback-инструмент
- synthetic `Job07` по умолчанию выведен из активного hot path
- synthetic attack phases должны уважать реальное guild/loadout состояние
- неразмеченные skill-backed synthetic phases по умолчанию считаются заблокированными

### Что synthetic уже доказал

Synthetic `Job07` уже доказал, что:

- Lua может писать `Job07`-related behavior через blackboard и act-inter пути
- `Job07` nodes можно поднимать на `main_pawn`
- `requestSkipThink()` работает как практический runtime-рычаг

Synthetic `Job07` не решил:

- стабильный native-like combat carrier adoption
- надёжный target tracking
- hit-functional melee behavior
- чистый release во всех runtime-условиях

Практический вывод:

- synthetic — полезный диагностический мост
- synthetic — слабый финальный ответ, пока native research ещё не исчерпан

### Что мы можем делать без Sigurd

Даже без чистого живого runtime `Sigurd` мы всё ещё можем:

- сравнивать `Job01` и `Job07` на `main_pawn`
- inspect `_BattleAIData`, `AIGoalActionData`, `OrderData` и safe decision-pool counts
- валидировать новые hook families на baseline и проблемной профессии
- усиливать или ослаблять role-gating гипотезу повторяемыми low-overhead данными

### Зачем Sigurd всё ещё нужен

`Sigurd` всё ещё полезен как:

- reference actor
- источник наблюдавшихся `Job07` phases и packs
- будущий control scenario для строгой проверки role-gating гипотезы

`Sigurd` сейчас не рассматривается как:

- обязательный live donor
- стабильная runtime-зависимость
- центр hot path

### Приоритет методов

Используем сейчас:

- узкие runtime hooks
- прямой field-based AI inspect
- safe native decision-pool telemetry
- сравнение `Job01` vs `Job07`

Используем позже:

- `Sigurd` как чистый control scenario
- контролируемые эксперименты через `Content Editor`
- donor-context cloning только после стабилизации native toolchain

Избегаем в hot path:

- широкого getter-heavy probing
- online/share/rental hooks
- полного BT/FSM authoring как следующего немедленного шага

### Основные модули

- `game/hybrid_unlock.lua`
- `game/loadout_research.lua`
- `game/action_research.lua`
- `game/pawn_ai_data_research.lua`
- `game/ai/synthetic_job07_adapter.lua`
- `game/ai/job07_sigurd_profile.lua`

### Граница сетевой безопасности

Core AI branch намеренно остаётся local-runtime-first.

Избегать в hot path:

- `app.PawnRentalValidator`
- `app.OnlinePawnDataFormatter`
- `app.PawnServerController`
- `app.network.PawnApiRequester`

Полезный безопасный локальный паттерн:

- offline main-pawn job lookup через `app.ContextDBMS -> OfflineDB -> JobContext`

### Навигация по репозиторию

- База знаний: [`docs/KNOWLEDGE_BASE.md`](./docs/KNOWLEDGE_BASE.md)
- Дорожная карта: [`docs/ROADMAP.md`](./docs/ROADMAP.md)
- Правила вклада: [`docs/CONTRIBUTING.md`](./docs/CONTRIBUTING.md)
- Playbook для `Content Editor`: [`docs/CONTENT_EDITOR_RESEARCH_PLAYBOOK.md`](./docs/CONTENT_EDITOR_RESEARCH_PLAYBOOK.md)
- История изменений: [`docs/CHANGELOG.md`](./docs/CHANGELOG.md)
- Политика безопасности: [`SECURITY.md`](./SECURITY.md)
- Лицензия: [`LICENSE`](./LICENSE)

### Быстрый старт

1. Установить REFramework для `Dragon's Dogma 2`.
2. Скопировать содержимое `mod/` в директорию REFramework игры.
3. Запустить игру.
4. Убедиться, что логи пишутся в `reframework/data/PawnHybridVocationsAI/logs/`.

### Рекомендуемое направление тестов

Текущее предпочтительное направление тестов:

1. валидировать baseline `Job01`
2. валидировать `Job07` в шумном реальном геймплее
3. фокусировать разбор на:
   - native decision hooks
   - safe decision-pool transitions
   - phase-bound AI data capture
   - успешности controller/data resolver
   - role-gating сигналах

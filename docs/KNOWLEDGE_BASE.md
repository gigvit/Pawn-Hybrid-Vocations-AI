# KNOWLEDGE_BASE

## English

### Project Goal

`Pawn Hybrid Vocations AI` exists to make hybrid vocations usable for `main_pawn` in `Dragon's Dogma 2`.

The project does not treat unlock as the finish line. The real target is AI parity.

Core model:

`unlock != equipment != skills != combat runtime != pawn combat context != AI parity`

### Confirmed Findings

What is already proven:

- `main_pawn` can enter hybrid vocation runtime.
- unlock and guild-side access are working.
- `Job07ActionController` resolves for `main_pawn`.
- the decision lifecycle is observable:
  - `chooseDecision`
  - `startDecision`
  - `lateUpdateDecision`
  - `endDecision`
- `Job01` has healthy combat behavior and job-specific packs.
- engine-level `Job07` behavior exists.

### Strongest Current Job07 Findings

The strongest current `Job07` conclusion is:

1. `Job07` exists in the engine.
2. `main_pawn Job07` usually does not show a stable native combat candidate in vanilla runtime.
3. observed runtime tends to stay in:
   - `Common/*`
   - `ch1/*`
   - `nil`
4. forcing `Job07` nodes is possible, but carrier adoption remains the real problem.

### Native-First Pivot

Current strategic stance:

- native `Job07` research is the mainline
- synthetic `Job07` is retained as fallback and instrumentation
- `Sigurd` is retained as a reference/control actor, not a live dependency

Practical meaning:

- we do not delete the synthetic branch yet
- we stop treating the synthetic branch as the preferred final answer
- we prioritize proving or disproving native candidate availability and native context admission

### What Synthetic Already Proved

The synthetic branch already proved that:

- Lua can write `Job07`-related behavior through:
  - `AIBlackBoardExtensions.setBBValuesToExecuteActInter(...)`
  - `AIBlackBoardController:set_ReqMainActInterPackData(...)`
  - `requestSkipThink()`
- `Job07` nodes can be raised on `main_pawn`
- `requestSkipThink()` works through `app.DecisionEvaluationModule`

The synthetic branch has not solved:

- stable native-like combat carrier adoption
- correct target tracking during the attack
- correct hit-functional behavior
- reliable clean release in every runtime condition
- exact `HumanCustomSkillID` mapping for every synthetic `Job07` attack phase

Practical conclusion:

- synthetic is a strong diagnostic bridge
- synthetic is a weak final answer unless native research is exhausted
- synthetic must respect real guild/loadout state; unmapped attack phases should be treated as blocked by default rather than guessed

### Combat Context Findings

The project has already confirmed that `Job07` is not only about a pack path. The following matter:

- target type
- target distance
- selector branch
- blackboard source
- move / strafe / reposition loop
- hold / release timing

Observed context signals repeatedly point to:

- `app.HumanActionSelector`
- `runtime_character:get_AIBlackBoardController()`
- `Common/*` carrier behavior instead of stable `Job07/*`

### Decision-Layer Findings

Current intervention map:

- `chooseDecision` is the strongest observed decision hook for `main_pawn Job07`
- `startDecision` is weak or absent in multiple `Job07` sessions
- `lateUpdateDecision` remains visible and useful
- `set_ExecutingDecision` is not the main practical write point for this branch

Practical conclusion:

- decision hooks are excellent for observation
- carrier-layer writes are currently stronger than native decision rewrites
- the next strongest native branch is direct controller/data inspection, not more random pack forcing

### Data-Layer Findings

The intended high-value native inspection targets are:

- `app.PawnBattleController._BattleAIData`
- `app.PawnUpdateController.AIGoalActionData`
- `app.PawnOrderController.OrderData`
- `app.goalplanning.AIGoalCategoryJob._JobDecisions`
- blackboard collections

Current blocker:

- the present resolver in:
  - [`pawn_ai_data_research.lua`](../mod/reframework/autorun/PawnHybridVocationsAI/game/pawn_ai_data_research.lua)
  does not yet reliably reach these controller/data objects in live sessions

Current mitigation:

- the runtime now emits a dedicated native-readiness summary that classifies:
  - controller resolution
  - data resolution
  - `Job07` branch state
  - current primary blocker

Practical conclusion:

- current logs do not yet mathematically prove `_JobDecisions` absence
- they currently prove that the data-layer resolver is still incomplete

### DD2 Utility Pack Hook Validation Direction

New hooks discovered through external analysis should now be validated in this order:

1. `Job01 main_pawn`
2. `Job07 main_pawn`
3. synthetic `Job07` fallback path
4. real `Sigurd`, if and when a clean runtime becomes available again

Each hook should be classified as:

- general-purpose
- native-`Job07` relevant
- synthetic-only useful
- likely real-`Sigurd`-control-only

Practical conclusion:

- we do not need `Sigurd` to start validating new hook families
- we do need `Sigurd` later as a stronger control scenario

### Role of Sigurd

`Sigurd` is currently useful as:

- a reference actor
- a source of observed `Job07` phases and packs
- a profile design reference
- a future control scenario for hook verification

`Sigurd` is currently not treated as:

- a mandatory live donor
- a stable runtime dependency
- the center of the hot path

### Structural Consolidation

Completed consolidations:

- `game/hybrid_unlock.lua`
  - replaces the old split between `hybrid_unlock_research` and `hybrid_unlock_prototype`
- `game/loadout_research.lua`
  - replaces the old split between `vocation_research` and `ability_research`

Design rule:

- merge sibling domains when they share the same actors, cadence, and dependency chain
- preserve compatibility runtime fields while collapsing the tree
- keep observation-heavy runtime modules separate from synthetic write-path modules unless there is a very strong reason

### Retired Runtime Branches

The active codebase no longer keeps these rejected runtime branches in the hot path:

- old `job07_runtime_probe`
- old inline `Job07` minimal experiment inside `action_research`
- old live `Sigurd` runtime capture / comparison inside `action_research`

They still exist as part of project history in documentation and changelog, but they are no longer active runtime branches.

### Content Editor Findings

The local `Content Editor` reference mod is part of the active native-research plan.

Detailed playbook:

- [`CONTENT_EDITOR_RESEARCH_PLAYBOOK.md`](./CONTENT_EDITOR_RESEARCH_PLAYBOOK.md)

Most useful direct inspection paths:

- `app.PawnBattleController._BattleAIData`
- `app.PawnUpdateController.AIGoalActionData`
- `app.PawnOrderController.OrderData`
- `app.goalplanning.AIGoalCategoryJob._JobDecisions`
- blackboard collections:
  - `AIBlackBoardCommonCollection`
  - `ActionCollection`
  - `FormationCollection`
  - `NpcCollection`
  - `SituationCollection`

### Network Safety Boundary

The local `Pawn Share Settings` reference mod is useful as a network-boundary reference, not as a combat-AI reference.

Core rule:

- keep the core AI branch local-runtime-first
- keep online/share hooks out of the hot path

Avoid in the core AI branch:

- `app.PawnRentalValidator`
- `app.OnlinePawnDataFormatter`
- `app.PawnServerController`
- `app.network.PawnApiRequester`
- broad root-validator disabling such as `validationPlaydata`

Useful safe offline pattern:

- `app.ContextDBMS -> OfflineDB -> JobContext`

### What Is Still Not Proven

The following questions remain open:

- whether direct data-layer inspection will prove or disprove native `Job07` combat candidate availability
- whether `_BattleAIData` and `_JobDecisions` contain a dormant but admissible `Job07` branch for `main_pawn`
- whether current `Job07` failure is candidate absence, context-blocking, or both
- whether the current synthetic branch can remain useful strictly as fallback without regaining mainline status

### Best Current Next Questions

1. Why does `Job07` node adoption still live under `Common/*` carrier behavior?
2. Which controller/data path is currently blocking `_BattleAIData` / `_JobDecisions` inspection?
3. Which new hooks from `DD2 Utility Pack` are general-purpose enough to validate right now?
4. What does a future clean `Sigurd` runtime still need to answer after the native-first toolchain is repaired?

---

## Русский

### Цель проекта

`Pawn Hybrid Vocations AI` существует для того, чтобы сделать hybrid-профессии usable для `main_pawn` в `Dragon's Dogma 2`.

Проект не считает unlock финишной точкой. Реальная цель — добиться AI parity.

Базовая модель:

`unlock != equipment != skills != combat runtime != pawn combat context != AI parity`

### Подтверждённые выводы

Что уже доказано:

- `main_pawn` может входить в runtime-состояние hybrid-профессии.
- unlock и guild-side доступ работают.
- у `main_pawn` резолвится `Job07ActionController`.
- decision lifecycle наблюдаем:
  - `chooseDecision`
  - `startDecision`
  - `lateUpdateDecision`
  - `endDecision`
- у `Job01` есть здоровое боевое поведение и job-specific packs.
- engine-level `Job07` behavior существует.

### Самые сильные текущие выводы по Job07

Самый сильный текущий вывод по `Job07` такой:

1. `Job07` существует в движке.
2. `main_pawn Job07` обычно не показывает стабильный native combat candidate в vanilla runtime.
3. наблюдаемый runtime стремится оставаться в:
   - `Common/*`
   - `ch1/*`
   - `nil`
4. форсить `Job07` nodes мы можем, но carrier adoption остаётся настоящей проблемой.

### Поворот к native-first

Текущая стратегическая позиция:

- native `Job07` research снова является mainline
- synthetic `Job07` сохраняется как fallback и инструмент диагностики
- `Sigurd` сохраняется как reference/control actor, а не как live dependency

Практический смысл:

- synthetic-ветка пока не удаляется
- synthetic-ветка больше не считается предпочтительным финальным ответом
- в приоритете теперь доказать или опровергнуть native candidate availability и native context admission

### Что уже доказал synthetic

Synthetic-ветка уже доказала, что:

- Lua может писать `Job07`-related behavior через:
  - `AIBlackBoardExtensions.setBBValuesToExecuteActInter(...)`
  - `AIBlackBoardController:set_ReqMainActInterPackData(...)`
  - `requestSkipThink()`
- `Job07` nodes можно поднять на `main_pawn`
- `requestSkipThink()` работает через `app.DecisionEvaluationModule`

Synthetic-ветка пока не решила:

- стабильный native-like combat carrier
- корректный target tracking во время атаки
- корректное hit-functional behavior
- надёжный clean release во всех runtime-условиях

Практический вывод:

- synthetic — сильный диагностический мост
- synthetic — слабый финальный ответ, пока native research ещё не исчерпан

### Выводы по боевому контексту

Проект уже подтвердил, что `Job07` — это не только pack path. Важны:

- target type
- target distance
- selector branch
- blackboard source
- цикл move / strafe / reposition
- тайминг hold / release

Наблюдаемые context signals снова и снова указывают на:

- `app.HumanActionSelector`
- `runtime_character:get_AIBlackBoardController()`
- `Common/*` carrier behavior вместо стабильного `Job07/*`

### Выводы по decision-layer

Текущая карта вмешательства:

- `chooseDecision` — самый сильный наблюдаемый decision hook для `main_pawn Job07`
- `startDecision` в нескольких `Job07`-сессиях слабый или отсутствует
- `lateUpdateDecision` остаётся видимым и полезным
- `set_ExecutingDecision` не является главным практическим write point для этой ветки

Практический вывод:

- decision hooks отлично подходят для наблюдения
- carrier-layer writes сейчас сильнее, чем native decision rewrites
- следующая сильная native-ветка — это direct controller/data inspection, а не ещё больше случайного pack forcing

### Выводы по data-layer

Целевые высокоценные native inspection targets такие:

- `app.PawnBattleController._BattleAIData`
- `app.PawnUpdateController.AIGoalActionData`
- `app.PawnOrderController.OrderData`
- `app.goalplanning.AIGoalCategoryJob._JobDecisions`
- blackboard collections

Текущий блокер:

- текущий resolver в:
  - [`pawn_ai_data_research.lua`](../mod/reframework/autorun/PawnHybridVocationsAI/game/pawn_ai_data_research.lua)
  пока не добирается до этих controller/data объектов в live sessions

Практический вывод:

- текущие логи пока не доказывают математически отсутствие `_JobDecisions`
- они сейчас доказывают, что data-layer resolver ещё не завершён

### Направление валидации hooks из DD2 Utility Pack

Новые hooks, найденные через внешний анализ, теперь нужно валидировать в таком порядке:

1. `Job01 main_pawn`
2. `Job07 main_pawn`
3. synthetic `Job07` fallback path
4. реальный `Sigurd`, если и когда у нас снова будет чистый runtime

Каждый hook нужно классифицировать как:

- general-purpose
- native-`Job07` relevant
- synthetic-only useful
- likely real-`Sigurd`-control-only

Практический вывод:

- `Sigurd` не нужен, чтобы начать проверять новые семейства hooks
- `Sigurd` понадобится позже как более сильный контрольный сценарий

### Роль Sigurd

`Sigurd` сейчас полезен как:

- reference actor
- источник наблюдавшихся `Job07` phases и packs
- reference для дизайна профиля
- будущий контрольный сценарий для проверки hooks

`Sigurd` сейчас не рассматривается как:

- обязательный live donor
- стабильная runtime-зависимость
- центр hot path

### Структурная консолидация

Уже выполненные объединения:

- `game/hybrid_unlock.lua`
  - заменяет старое разделение на `hybrid_unlock_research` и `hybrid_unlock_prototype`
- `game/loadout_research.lua`
  - заменяет старое разделение на `vocation_research` и `ability_research`

Правило проектирования:

- объединять соседние домены, если у них общие акторы, общая частота обновления и одна цепочка зависимостей
- при схлопывании дерева сохранять совместимые runtime-поля
- не сливать observation-heavy runtime-модули с synthetic write-path модулями без очень сильной причины

### Выведенные из hot path runtime-ветки

Активная кодовая база больше не держит в hot path следующие отвергнутые runtime-ветки:

- старый `job07_runtime_probe`
- старый inline `Job07` minimal experiment внутри `action_research`
- старый live `Sigurd` runtime capture / comparison внутри `action_research`

Они остаются частью истории проекта в документации и changelog, но больше не являются активными runtime-ветками.

### Выводы по Content Editor

Локальный reference-мод `Content Editor` теперь является частью активного native-research плана.

Подробный playbook:

- [`CONTENT_EDITOR_RESEARCH_PLAYBOOK.md`](./CONTENT_EDITOR_RESEARCH_PLAYBOOK.md)

Самые полезные direct inspection paths:

- `app.PawnBattleController._BattleAIData`
- `app.PawnUpdateController.AIGoalActionData`
- `app.PawnOrderController.OrderData`
- `app.goalplanning.AIGoalCategoryJob._JobDecisions`
- blackboard collections:
  - `AIBlackBoardCommonCollection`
  - `ActionCollection`
  - `FormationCollection`
  - `NpcCollection`
  - `SituationCollection`

### Граница сетевой безопасности

Локальный reference-мод `Pawn Share Settings` полезен как reference границы сети, а не как combat-AI reference.

Базовое правило:

- держать core AI-ветку local-runtime-first
- держать online/share hooks вне hot path

Избегать в core AI-ветке:

- `app.PawnRentalValidator`
- `app.OnlinePawnDataFormatter`
- `app.PawnServerController`
- `app.network.PawnApiRequester`
- широкого отключения root-validator путей вроде `validationPlaydata`

Полезный безопасный offline pattern:

- `app.ContextDBMS -> OfflineDB -> JobContext`

### Что всё ещё не доказано

Открытыми остаются следующие вопросы:

- докажет или опровергнет ли direct data-layer inspection наличие native `Job07` combat candidate
- содержат ли `_BattleAIData` и `_JobDecisions` dormant, но admissible `Job07` branch для `main_pawn`
- текущая неудача `Job07` — это candidate absence, context-blocking или их комбинация
- сможет ли текущая synthetic-ветка остаться полезной строго как fallback, не возвращая себе статус mainline

### Лучшие текущие следующие вопросы

1. Почему `Job07` node adoption всё ещё живёт под `Common/*` carrier behavior?
2. Какой именно controller/data path сейчас блокирует inspect `_BattleAIData` / `_JobDecisions`?
3. Какие новые hooks из `DD2 Utility Pack` уже достаточно general-purpose, чтобы валидировать их прямо сейчас?
4. На какие вопросы должен будет ответить будущий чистый runtime `Sigurd`, когда native-first toolchain будет починен?

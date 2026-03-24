# CONTENT_EDITOR_RESEARCH_PLAYBOOK

## English

### Purpose

This playbook defines the direct `Content Editor` inspection flow for `Pawn Hybrid Vocations AI`.

Primary goal:

- compare `Job01` and `Job07` on `main_pawn`
- inspect native AI data instead of relying only on runtime logs
- check whether `Job07` has a real native branch, a dormant branch, or a context-blocked branch

### Tools and References

External reference source:

- a local checkout of the `Content Editor` reference mod for `Dragon's Dogma 2`

Most useful files:

- `experimental_editors/reframework/autorun/editor_ai.lua`
- `param_editor/reframework/autorun/editor_human_params.lua`
- `content_editor/readme.md`
- `content_editor/reframework/data/usercontent/rsz/dd2.json`

Most useful reference capabilities:

- `AI Overview`
- `AIGoalActionData`
- `_BattleAIData`
- `OrderData`
- `AIGoalCategoryJob._JobDecisions`
- blackboard collections
- helper entry points:
  - `ce_find`
  - `ce_dump`
  - `ce_create`

### Research Questions

This playbook is meant to answer:

1. Does `main_pawn Job07` have a real native `Job07` branch in `_JobDecisions`?
2. Does `main_pawn Job07` differ from `Job01` in `_BattleAIData`, `OrderData`, or `AIGoalActionData`?
3. Do blackboard collections show missing or mismatched combat context on `Job07`?
4. Is the current `Job07` problem best described as:
   - branch missing
   - branch dormant
   - branch present but blocked by context
   - role-gated or under-populated for pawn-role

### Test Setup

Use the same controlled scenario for both jobs:

1. restart the game fully
2. load a stable save
3. keep the environment as similar as possible
4. test `Job01` first as baseline
5. test `Job07` second
6. use a simple fight with one stable enemy if possible
7. do not change unrelated UI or mod settings during the comparison

### Capture Order

For each job, capture in this order:

1. idle / out of combat
2. just before combat
3. during combat while target is stable
4. immediately after combat ends

This gives us the best chance to separate:

- native branch presence
- combat admission
- post-combat release

### Step-by-Step Inspection

#### Step 1. Open AI Overview

Open the `Content Editor` AI overview and locate the current `main_pawn`.

Record for both `Job01` and `Job07`:

- pawn identifier
- current job
- whether `AIGoalActionData` is populated
- whether `_BattleAIData` is populated
- whether `OrderData` is populated

#### Step 2. Inspect `_BattleAIData`

Open `app.PawnBattleController._BattleAIData`.

Record:

- object presence or absence
- obvious job-related fields
- combat-state fields
- any target-related fields
- anything that differs clearly between `Job01` and `Job07`

What to look for:

- missing `Job07`-specific state
- different combat-mode state
- missing target admission
- empty vs populated battle AI structures

#### Step 3. Inspect `OrderData`

Open `app.PawnOrderController.OrderData`.

Record:

- current order type
- whether the pawn appears to be in follow/support/common role
- any strong difference between `Job01` and `Job07`

Why this matters:

- a pawn trapped in common party-order behavior may never admit the `Job07` branch correctly

#### Step 4. Inspect `AIGoalActionData`

Open `app.PawnUpdateController.AIGoalActionData`.

Record:

- current goal family
- action-related job data
- visible goal changes between idle and combat
- visible differences between `Job01` and `Job07`

#### Step 5. Inspect `_JobDecisions`

Open `app.goalplanning.AIGoalCategoryJob._JobDecisions`.

Record:

- whether a `Job07` branch exists at all
- whether it looks empty, partial, or populated
- whether `Job01` is clearly richer than `Job07`
- whether decisions are present but look disconnected from current combat runtime

This is one of the most important inspection steps.

#### Step 6. Inspect Blackboard Collections

Inspect the collections exposed in `editor_ai.lua`:

- `AIBlackBoardCommonCollection`
- `ActionCollection`
- `FormationCollection`
- `NpcCollection`
- `SituationCollection`

Record:

- target-related state
- move / strafe / formation state
- situation flags that look combat-relevant
- values that differ clearly between `Job01` and `Job07`

#### Step 7. Inspect Human Job Parameters

Use the path confirmed by `editor_human_params.lua`:

- `CharacterManager:get_HumanParam()`
- `app.Job07Parameter`

Record:

- whether `Job07Parameter` exists and resolves correctly
- whether anything looks obviously missing compared to `Job01`

This step is lower priority than `_BattleAIData` and `_JobDecisions`, but still useful.

### What to Write Down

For each inspected object, write down:

- object path
- present / absent
- key differing fields
- `Job01` value
- `Job07` value
- interpretation

Use a compact table format whenever possible:

| Object | Field / branch | Job01 | Job07 | Interpretation |

### Interpretation Rules

Use the following classification:

- `branch missing`
  - no meaningful `Job07` branch in `_JobDecisions`
- `branch dormant`
  - `Job07` branch exists, but combat-state data does not activate it
- `context blocked`
  - `Job07` branch exists, but target/order/blackboard/combat state appears incompatible
- `parameter mismatch`
  - the branch exists, but job-parameter or related data looks incomplete
- `role-gated / under-populated`
  - the broad native structure exists, but `Job07` is consistently poorer or loses admission compared to baseline

### Success Criteria

The playbook is successful if it gives us at least one of:

- proof that native `Job07` candidate data is missing
- proof that native `Job07` data exists but is dormant
- proof that blackboard / order / battle context blocks the `Job07` branch
- proof that `Job07` is structurally under-populated for pawn-role
- a concrete field or collection to target next in code

### Next Actions From Findings

If the result is:

- `branch missing`
  - continue native-first investigation and verify whether the absence is specific to pawn-role
  - keep synthetic only as bounded fallback or reproduction tooling
- `branch dormant`
  - investigate activation conditions and combat admission
- `context blocked`
  - compare target, order, and blackboard state more aggressively
- `parameter mismatch`
  - inspect `Job07Parameter` and related job configuration more deeply
- `role-gated / under-populated`
  - compare against a real `Job07` control actor later, such as `Sigurd`

---

## Русский

### Назначение

Этот playbook задаёт прямой сценарий inspection через `Content Editor` для `Pawn Hybrid Vocations AI`.

Основная цель:

- сравнить `Job01` и `Job07` у `main_pawn`
- смотреть native AI data, а не только runtime logs
- проверить, есть ли у `Job07` реальная native branch, спящая branch или branch, заблокированная контекстом

### Инструменты и референсы

Внешний reference source:

- локальная копия reference-мода `Content Editor` для `Dragon's Dogma 2`

Самые полезные файлы:

- `experimental_editors/reframework/autorun/editor_ai.lua`
- `param_editor/reframework/autorun/editor_human_params.lua`
- `content_editor/readme.md`
- `content_editor/reframework/data/usercontent/rsz/dd2.json`

Самые полезные reference-capabilities:

- `AI Overview`
- `AIGoalActionData`
- `_BattleAIData`
- `OrderData`
- `AIGoalCategoryJob._JobDecisions`
- blackboard collections
- helper entry points:
  - `ce_find`
  - `ce_dump`
  - `ce_create`

### Исследовательские вопросы

Этот playbook нужен, чтобы ответить на вопросы:

1. Есть ли у `main_pawn Job07` реальная native `Job07` branch в `_JobDecisions`?
2. Отличается ли `main_pawn Job07` от `Job01` в `_BattleAIData`, `OrderData` или `AIGoalActionData`?
3. Показывают ли blackboard collections отсутствующий или неверный combat context на `Job07`?
4. Как правильнее описывать текущую проблему `Job07`:
   - branch missing
   - branch dormant
   - branch present but blocked by context
   - role-gated или under-populated для pawn-role

### Подготовка теста

Для обеих профессий нужно использовать один и тот же контролируемый сценарий:

1. полностью перезапустить игру
2. загрузить стабильный сейв
3. держать окружение максимально одинаковым
4. сначала тестировать `Job01` как baseline
5. потом тестировать `Job07`
6. по возможности использовать простой бой с одним стабильным врагом
7. не менять посторонние UI или mod settings во время сравнения

### Порядок снятия данных

Для каждой профессии снимать данные в таком порядке:

1. idle / вне боя
2. прямо перед боем
3. во время боя, пока target стабильный
4. сразу после конца боя

Это даёт лучший шанс отделить:

- наличие native branch
- допуск в бой
- post-combat release

### Пошаговый inspection

#### Шаг 1. Открыть AI Overview

Открыть `AI Overview` в `Content Editor` и найти текущую `main_pawn`.

Для `Job01` и `Job07` записать:

- идентификатор пешки
- текущую профессию
- заполнен ли `AIGoalActionData`
- заполнен ли `_BattleAIData`
- заполнен ли `OrderData`

#### Шаг 2. Inspect `_BattleAIData`

Открыть `app.PawnBattleController._BattleAIData`.

Записать:

- присутствует объект или нет
- очевидные job-related fields
- combat-state fields
- любые target-related fields
- всё, что явно отличается между `Job01` и `Job07`

Что искать:

- отсутствующее `Job07`-specific state
- другое combat-mode state
- отсутствие target admission
- пустые против заполненных battle AI structures

#### Шаг 3. Inspect `OrderData`

Открыть `app.PawnOrderController.OrderData`.

Записать:

- текущий тип приказа
- выглядит ли пешка как застрявшая в follow/support/common role
- любые сильные различия между `Job01` и `Job07`

Почему это важно:

- если пешка застряла в common party-order behavior, она может вообще не допускать `Job07` branch

#### Шаг 4. Inspect `AIGoalActionData`

Открыть `app.PawnUpdateController.AIGoalActionData`.

Записать:

- текущее goal family
- action-related job data
- видимые изменения goal между idle и combat
- видимые различия между `Job01` и `Job07`

#### Шаг 5. Inspect `_JobDecisions`

Открыть `app.goalplanning.AIGoalCategoryJob._JobDecisions`.

Записать:

- существует ли вообще `Job07` branch
- выглядит ли она пустой, частичной или заполненной
- явно ли `Job01` богаче, чем `Job07`
- присутствуют ли decisions, но выглядят ли они disconnected from current combat runtime

Это один из самых важных шагов inspection.

#### Шаг 6. Inspect Blackboard Collections

Посмотреть collections, которые уже выведены в `editor_ai.lua`:

- `AIBlackBoardCommonCollection`
- `ActionCollection`
- `FormationCollection`
- `NpcCollection`
- `SituationCollection`

Записать:

- target-related state
- move / strafe / formation state
- situation flags, похожие на combat-relevant
- значения, которые явно отличаются между `Job01` и `Job07`

#### Шаг 7. Inspect Human Job Parameters

Использовать path, подтверждённый в `editor_human_params.lua`:

- `CharacterManager:get_HumanParam()`
- `app.Job07Parameter`

Записать:

- существует ли `Job07Parameter` и резолвится ли он корректно
- видно ли что-то явно отсутствующее относительно `Job01`

Этот шаг менее приоритетен, чем `_BattleAIData` и `_JobDecisions`, но тоже полезен.

### Что именно записывать

Для каждого inspected object записывать:

- object path
- present / absent
- key differing fields
- значение `Job01`
- значение `Job07`
- interpretation

По возможности использовать компактную таблицу:

| Object | Field / branch | Job01 | Job07 | Interpretation |

### Правила интерпретации

Использовать такую классификацию:

- `branch missing`
  - нет meaningful `Job07` branch в `_JobDecisions`
- `branch dormant`
  - `Job07` branch существует, но combat-state data её не активирует
- `context blocked`
  - `Job07` branch существует, но target/order/blackboard/combat state выглядит несовместимым
- `parameter mismatch`
  - branch существует, но job-parameter или связанная data выглядит неполной
- `role-gated / under-populated`
  - широкий native каркас существует, но `Job07` стабильно беднее baseline или теряет admission

### Критерии успеха

Playbook считается успешным, если он даёт хотя бы одно из:

- доказательство, что native `Job07` candidate data отсутствует
- доказательство, что native `Job07` data существует, но спит
- доказательство, что blackboard / order / battle context блокирует `Job07` branch
- доказательство, что `Job07` структурно недонаполнен для pawn-role
- конкретное поле или collection, в которое надо целиться дальше кодом

### Следующие действия по результатам

Если результат такой:

- `branch missing`
  - продолжать native-first исследование и проверять, не специфично ли это отсутствие для pawn-role
  - использовать synthetic только как ограниченный fallback или reproduction tooling
- `branch dormant`
  - исследовать activation conditions и combat admission
- `context blocked`
  - агрессивнее сравнивать target, order и blackboard state
- `parameter mismatch`
  - глубже inspect `Job07Parameter` и связанную job configuration
- `role-gated / under-populated`
  - позже сравнить с реальным `Job07` control actor, например `Sigurd`

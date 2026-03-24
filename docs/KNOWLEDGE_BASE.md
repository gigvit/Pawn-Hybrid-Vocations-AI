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
2. `main_pawn Job07` usually does not show a fully populated native pawn-usable combat admission path in vanilla runtime.
3. observed runtime tends to drift through:
   - `Common/*`
   - `ch1/*`
   - `nil`
4. forcing `Job07` nodes is possible, but carrier adoption remains the real problem.

### Primary Working Hypothesis

Current primary working hypothesis:

- the engine does not fully populate or retain native `Job07` combat admission for `main_pawn` in pawn-role

This is more precise than:

- "`Job07` does not exist"
- "we only need a better pack"

Why this hypothesis is currently stronger:

- `Job07` types and behavior fragments clearly exist in the engine
- `Job01` and `Job07` share the same broad native controller graph
- `Job07` repeatedly receives a poorer native decision pool than `Job01`
- `Job07 main_pawn` repeatedly fails to reach stable native combat admission

### Latest High-Value Native Reading

Current safe-native telemetry no longer suggests absolute absence. It suggests instability and under-population.

Most useful recent reading:

- `Job07` can briefly match `Job01` in safe native decision-pool counts
- `Job07` then tends to degrade into a poorer pool
- `Job07` then remains in weaker runtime context without stable combat admission

Observed practical pattern:

- short parity
- then degradation
- then loss of admission

This matters because it weakens the crude model "`Job07` is simply missing" and strengthens the role-gating or under-population model.

### Native-First Pivot

Current strategic stance:

- native `Job07` research is the mainline
- synthetic `Job07` is retained as fallback and instrumentation
- `Sigurd` is retained as a reference/control actor, not a live dependency

Current runtime policy:

- synthetic `Job07` is preserved as project knowledge and code history
- synthetic `Job07` is retired from the active hot path by default

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
- correct target tracking during attacks
- correct hit-functional behavior
- reliable clean release in every runtime condition
- exact `HumanCustomSkillID` mapping for every synthetic `Job07` attack phase

Practical conclusion:

- synthetic is a strong diagnostic bridge
- synthetic is a weak final answer unless native research is exhausted
- synthetic must respect real guild/loadout state
- the active runtime should not depend on synthetic while native-first investigation continues

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

At the same time, `Job07` is not limited to `Common/*` only. Repeated sessions also showed `ch1` family presence. The current problem is therefore not pure absence of richer families, but failure to keep them and turn them into stable combat admission.

### Decision-Layer Findings

Current intervention map:

- `chooseDecision` is the strongest observed decision hook for `main_pawn Job07`
- `startDecision` is weak or absent in multiple `Job07` sessions
- `lateUpdateDecision` remains visible and useful
- `set_ExecutingDecision` is not the main practical write point for this branch

Practical conclusion:

- decision hooks are excellent for observation
- broad native decision rewrites are not the current mainline
- direct controller/data inspection is currently stronger than more random pack forcing

### Data-Layer Findings

The intended high-value native inspection targets are:

- `app.PawnBattleController._BattleAIData`
- `app.PawnUpdateController.AIGoalActionData`
- `app.PawnOrderController.OrderData`
- `app.goalplanning.AIGoalCategoryJob._JobDecisions`
- blackboard collections

Current blocker:

- the resolver in [`pawn_ai_data_research.lua`](../mod/reframework/autorun/PawnHybridVocationsAI/game/pawn_ai_data_research.lua) does not yet reliably reach every desired `job_goal_category` / `_JobDecisions` container in live sessions

Current mitigation:

- the runtime emits dedicated readiness and blocker summaries
- safe decision-pool telemetry works even while `job_goal_category` remains unresolved

Practical conclusion:

- current logs do not yet mathematically prove `_JobDecisions` absence
- current logs do prove that the data-layer resolver is still incomplete and that safe structural differences already exist between `Job01` and `Job07`

### Safe Native Decision-Pool Signal

The current safest high-value native signal is the decision-pool summary, not a broad getter scan.

Current safe counts:

- `app.goalplanning.AIGoalPlanning._CurrentGoalList`
- `app.goalplanning.AIGoalPlanning._CurrentAddDecisionList`
- `app.DecisionEvaluationModule.<MainDecisions>k__BackingField`
- `app.DecisionEvaluationModule.<PreDecisions>k__BackingField`
- `app.DecisionEvaluationModule.<PostDecisions>k__BackingField`
- `app.DecisionPackHandler.<ActiveDecisionPacks>k__BackingField`

Why this matters:

- these counts already show a repeatable structural difference between `Job01` and `Job07`
- they are cheaper and safer than wide getter probing
- they help explain native context weakness even while `job_goal_category` remains unresolved

Current practical interpretation:

- `Job01` repeatedly receives a richer native decision pool than `Job07`
- `Job07` remains structurally poorer before it ever reaches stable native combat behavior

### Native Role-Gating Signal

The current native-first telemetry also emits a dedicated role-gating event:

- `main_pawn_native_role_gating_signal_changed`

Its job is narrow:

- compare safe `Job01` vs `Job07` decision-pool deltas
- tell us when `Job07` is structurally poorer before combat admission

Current practical reading:

- this event is not final proof by itself
- it is a compact, repeatable signal aligned with the pawn-role population/admission hypothesis

### Performance Findings

The project already learned an important toolchain lesson:

- broad getter-heavy native probing can destroy FPS and produce REFramework exceptions

Practical rule:

- favor semantic signatures, stable counts, and deduplicated transitions over deep reflective scans in the hot path

### Method Selection Matrix

Use now:

- narrow runtime hooks
- direct field-based AI inspection
- safe native decision-pool telemetry
- `Job01` vs `Job07` compare

Use later:

- `Sigurd` as a control scenario
- controlled `Content Editor` bundle experiments
- donor-context cloning only after the native toolchain is stable

Avoid in the hot path:

- broad getter-heavy probing on unstable native types
- online/share/rental hooks
- full BT/FSM authoring before the native layer is exhausted

### DD2 Utility Pack Hook Validation Direction

New hooks discovered through external analysis should be validated in this order:

1. `Job01 main_pawn`
2. `Job07 main_pawn`
3. optional synthetic fallback path only when a bounded comparison needs it
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

### Network Safety Boundary

The core AI branch must remain local-runtime-first.

Avoid in the hot path:

- `app.PawnRentalValidator`
- `app.OnlinePawnDataFormatter`
- `app.PawnServerController`
- `app.network.PawnApiRequester`

Prefer:

- offline-safe job/state lookups such as `ContextDBMS -> OfflineDB -> JobContext`

### Open Questions

The biggest open questions are now:

1. Why can `Job07` briefly reach parity and then lose it?
2. What exact native state transition pushes `Job07` from richer pool to poorer pool?
3. Is the missing piece true branch absence, admission loss, role-gating, or a mixture?
4. What will a future clean `Sigurd` runtime prove about pawn-role vs real-actor-role differences?

---

## Русский

### Цель проекта

`Pawn Hybrid Vocations AI` существует, чтобы сделать hybrid-профессии пригодными для `main_pawn` в `Dragon's Dogma 2`.

Проект не считает unlock финишной чертой. Реальная цель — AI parity.

Базовая модель:

`unlock != equipment != skills != combat runtime != pawn combat context != AI parity`

### Подтверждённые выводы

Что уже доказано:

- `main_pawn` может входить в runtime hybrid-профессии.
- unlock и guild-side доступ работают.
- у `main_pawn` резолвится `Job07ActionController`.
- decision lifecycle наблюдается:
  - `chooseDecision`
  - `startDecision`
  - `lateUpdateDecision`
  - `endDecision`
- у `Job01` есть здоровое боевое поведение и job-specific packs.
- engine-level `Job07` behavior существует.

### Самые сильные текущие выводы по Job07

Самый сильный текущий вывод по `Job07` такой:

1. `Job07` существует в движке.
2. `main_pawn Job07` обычно не показывает полностью наполненный native pawn-usable combat admission path в vanilla runtime.
3. наблюдаемый runtime часто дрейфует через:
   - `Common/*`
   - `ch1/*`
   - `nil`
4. форсить `Job07` nodes мы можем, но carrier adoption остаётся настоящей проблемой.

### Основная рабочая гипотеза

Текущая основная рабочая гипотеза:

- движок не полностью наполняет или не удерживает native `Job07` combat admission для `main_pawn` в роли pawn

Это точнее, чем:

- "`Job07` вообще не существует"
- "нам просто нужен лучший pack"

Почему эта гипотеза сейчас сильнее:

- `Job07` типы и фрагменты поведения явно существуют в движке
- `Job01` и `Job07` используют один и тот же широкий native controller graph
- `Job07` повторяемо получает более бедный native decision pool, чем `Job01`
- `Job07 main_pawn` повторяемо не выходит в стабильный native combat admission

### Последнее сильное native-чтение

Текущая safe-native телеметрия уже не говорит об абсолютном отсутствии. Она говорит о нестабильности и недонаполнении.

Самое полезное текущее чтение:

- `Job07` может кратко совпасть с `Job01` по safe native decision-pool counts
- затем `Job07` обычно деградирует в более бедный pool
- после этого `Job07` остаётся в более слабом runtime context без стабильного combat admission

Наблюдаемый практический паттерн:

- краткий паритет
- затем деградация
- затем потеря admission

Это важно, потому что ослабляет грубую модель "`Job07` просто отсутствует" и усиливает модель role-gating / under-population.

### Поворот к native-first

Текущая стратегическая позиция:

- native `Job07` research — mainline
- synthetic `Job07` сохраняется как fallback и instrumentation
- `Sigurd` сохраняется как reference/control actor, а не как живая зависимость

Текущая runtime-политика:

- synthetic `Job07` сохраняется как знание проекта и кодовая история
- synthetic `Job07` по умолчанию выведен из активного hot path

Практический смысл:

- мы пока не удаляем synthetic-ветку
- мы больше не считаем synthetic-ветку предпочтительным финальным ответом
- мы приоритизируем доказательство или опровержение native candidate availability и native context admission

### Что synthetic уже доказал

Synthetic-ветка уже доказала, что:

- Lua может писать `Job07`-related behavior через:
  - `AIBlackBoardExtensions.setBBValuesToExecuteActInter(...)`
  - `AIBlackBoardController:set_ReqMainActInterPackData(...)`
  - `requestSkipThink()`
- `Job07` nodes можно поднять на `main_pawn`
- `requestSkipThink()` работает через `app.DecisionEvaluationModule`

Synthetic-ветка не решила:

- стабильный native-like combat carrier adoption
- корректный target tracking во время атак
- корректное hit-functional behavior
- надёжный clean release во всех runtime-условиях
- точный `HumanCustomSkillID` mapping для каждой synthetic `Job07` attack phase

Практический вывод:

- synthetic — сильный диагностический мост
- synthetic — слабый финальный ответ, пока native research ещё не исчерпан
- synthetic должен уважать реальное guild/loadout состояние
- активный runtime не должен зависеть от synthetic, пока продолжается native-first исследование

### Выводы по combat context

Проект уже подтвердил, что `Job07` — это не только вопрос pack path. Важны:

- тип цели
- дистанция до цели
- selector branch
- источник blackboard
- move / strafe / reposition loop
- hold / release timing

Наблюдавшиеся context signals многократно указывают на:

- `app.HumanActionSelector`
- `runtime_character:get_AIBlackBoardController()`
- `Common/*` carrier behavior вместо стабильного `Job07/*`

При этом `Job07` не ограничен только `Common/*`. В повторяемых сессиях также наблюдалось присутствие `ch1` family. Значит текущая проблема — не полное отсутствие более богатых family, а неспособность удержать их и превратить в стабильный combat admission.

### Выводы по decision layer

Текущая карта вмешательства:

- `chooseDecision` — самый сильный наблюдаемый decision hook для `main_pawn Job07`
- `startDecision` в нескольких `Job07`-сессиях слабый или отсутствует
- `lateUpdateDecision` остаётся видимым и полезным
- `set_ExecutingDecision` не является главным практическим write point для этой ветки

Практический вывод:

- decision hooks отлично подходят для observation
- широкие native decision rewrites сейчас не являются mainline
- прямой controller/data inspect сейчас сильнее, чем ещё больше случайного pack forcing

### Выводы по data layer

Целевые высокоценные native inspection targets:

- `app.PawnBattleController._BattleAIData`
- `app.PawnUpdateController.AIGoalActionData`
- `app.PawnOrderController.OrderData`
- `app.goalplanning.AIGoalCategoryJob._JobDecisions`
- blackboard collections

Текущий blocker:

- resolver в [`pawn_ai_data_research.lua`](../mod/reframework/autorun/PawnHybridVocationsAI/game/pawn_ai_data_research.lua) пока не доходит надёжно до каждого нужного контейнера `job_goal_category` / `_JobDecisions` в живых сессиях

Текущая компенсация:

- runtime эмитит отдельные readiness и blocker summary
- safe decision-pool telemetry уже работает, даже пока `job_goal_category` остаётся unresolved

Практический вывод:

- текущие логи ещё не доказывают математически отсутствие `_JobDecisions`
- текущие логи уже доказывают, что data-layer resolver пока неполон, и что безопасные структурные различия между `Job01` и `Job07` уже существуют

### Безопасный native decision-pool сигнал

Самый безопасный и полезный текущий native-сигнал — это decision-pool summary, а не широкий getter scan.

Текущие safe counts:

- `app.goalplanning.AIGoalPlanning._CurrentGoalList`
- `app.goalplanning.AIGoalPlanning._CurrentAddDecisionList`
- `app.DecisionEvaluationModule.<MainDecisions>k__BackingField`
- `app.DecisionEvaluationModule.<PreDecisions>k__BackingField`
- `app.DecisionEvaluationModule.<PostDecisions>k__BackingField`
- `app.DecisionPackHandler.<ActiveDecisionPacks>k__BackingField`

Почему это важно:

- эти counts уже показывают повторяемую структурную разницу между `Job01` и `Job07`
- они дешевле и безопаснее, чем широкий getter probing
- они помогают объяснять слабость native context, даже пока `job_goal_category` остаётся unresolved

Текущее практическое чтение:

- `Job01` повторяемо получает более богатый native decision pool, чем `Job07`
- `Job07` остаётся структурно беднее ещё до того, как доходит до стабильного native combat behavior

### Native role-gating signal

Текущая native-first телеметрия также эмитит отдельное событие role-gating:

- `main_pawn_native_role_gating_signal_changed`

Его задача узкая:

- сравнивать безопасные `Job01` vs `Job07` deltas decision-pool
- показывать, когда `Job07` структурно беднее ещё до combat admission

Текущее практическое чтение:

- это событие само по себе не является финальным доказательством
- это компактный, повторяемый сигнал, согласованный с гипотезой pawn-role population/admission

### Выводы по производительности

Проект уже выучил важный урок по toolchain:

- широкий getter-heavy native probing может убить FPS и вызывать REFramework exceptions

Практическое правило:

- предпочитать semantic signatures, стабильные counts и deduplicated transitions вместо глубоких reflective scan в hot path

### Матрица выбора методов

Используем сейчас:

- узкие runtime hooks
- прямой field-based AI inspect
- safe native decision-pool telemetry
- сравнение `Job01` vs `Job07`

Используем позже:

- `Sigurd` как control scenario
- контролируемые `Content Editor` bundle experiments
- donor-context cloning только после стабилизации native toolchain

Избегаем в hot path:

- broad getter-heavy probing на нестабильных native типах
- online/share/rental hooks
- полного BT/FSM authoring до исчерпания native layer

### Направление валидации hooks из DD2 Utility Pack

Новые hooks, найденные через внешний анализ, нужно валидировать в таком порядке:

1. `Job01 main_pawn`
2. `Job07 main_pawn`
3. optional synthetic fallback path только если нужен ограниченный comparison
4. реальный `Sigurd`, когда снова появится чистый runtime

Каждый hook должен классифицироваться как:

- general-purpose
- native-`Job07` relevant
- synthetic-only useful
- likely real-`Sigurd`-control-only

Практический вывод:

- `Sigurd` не нужен, чтобы начать валидацию новых hook families
- `Sigurd` понадобится позже как более сильный control scenario

### Роль Sigurd

`Sigurd` сейчас полезен как:

- reference actor
- источник наблюдавшихся `Job07` phases и packs
- reference для дизайна профиля
- будущий control scenario для hook verification

`Sigurd` сейчас не рассматривается как:

- обязательный live donor
- стабильная runtime-зависимость
- центр hot path

### Граница сетевой безопасности

Core AI branch должен оставаться local-runtime-first.

Избегать в hot path:

- `app.PawnRentalValidator`
- `app.OnlinePawnDataFormatter`
- `app.PawnServerController`
- `app.network.PawnApiRequester`

Предпочитать:

- offline-safe job/state lookup вроде `ContextDBMS -> OfflineDB -> JobContext`

### Открытые вопросы

Самые большие открытые вопросы сейчас такие:

1. Почему `Job07` может кратко достигать паритета, а затем терять его?
2. Какой именно native state transition переводит `Job07` из более богатого pool в более бедный?
3. Чего здесь больше: branch absence, admission loss, role-gating или их смеси?
4. Что именно докажет будущий чистый runtime `Sigurd` о разнице между pawn-role и real-actor-role?

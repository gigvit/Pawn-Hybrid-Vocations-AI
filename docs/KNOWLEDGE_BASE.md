# KNOWLEDGE_BASE

## English

### Explanation

#### Project model

Project invariant:

`unlock != equipment != skills != combat runtime != pawn combat context != AI parity`

This means:

- unlock alone is not a combat fix
- visible guild access is not proof of working AI
- a live controller is not proof of a working job-specific combat path

#### Current project split

The repository now follows one strict split:

- `mod/` contains product runtime code
- `docs/ce_scripts/` contains research scripts

Default policy:

- `mod = implementation`
- `CE scripts = research`

#### Source-of-truth order

When sources disagree, trust them in this order:

1. CE outputs written to file
2. current product runtime behavior
3. direct engine data inspection
4. historical git documentation
5. theory and guesses

#### Current product runtime

The active runtime core is limited to:

- `bootstrap.lua`
- `game/discovery.lua`
- `game/main_pawn_properties.lua`
- `game/progression/state.lua`
- `game/hybrid_unlock.lua`

The product runtime currently does three important things:

1. resolves `player` and `main_pawn`
2. reads progression and job-bit state
3. restores the actual hybrid unlock path for `main_pawn`

#### Current unlock state

Confirmed in code:

- hybrid unlock depends on `player.QualifiedJobBits`
- missing hybrid bits are mirrored into `main_pawn.JobContext.QualifiedJobBits`
- the in-memory progression snapshot is refreshed immediately after the mirror write
- a narrow guild-side override is installed on `app.ui040101_00.getJobInfoParam`
- the override enables `_EnablePawn` on hybrid job info for `main_pawn` or falls back to a cached player retval

Interpretation:

- unlock works through a product-scoped runtime path again
- unlock and guild access are still separate from the unresolved `Job07` combat-path problem

#### Historical findings preserved from pre-cleanup research

The removed research layer had already established several useful points that remain relevant:

- `Job07` in the engine is real, not fictional
- `Job07` could briefly approach `Job01` and then degrade again
- the weaker `Job07` state looked more like under-population or admission loss than complete absence
- broad getter-heavy probing was expensive and could trigger FPS collapse and REFramework exceptions

These findings are historical context now, not the active implementation path.

#### Confirmed combat findings

##### `main_pawn`

Confirmed:

- `main_pawn` resolves reliably enough for runtime inspection
- progression state, current job, and baseline runtime context are readable

##### `Job01`

`Job01` is the control baseline.

Confirmed by burst traces:

- navigation appears first
- then combat execution transitions into job-specific packs
- then job-specific nodes appear

Observed examples:

- `Job01_BlinkStrike_Standard`
- `Job01_FullMoonSlash`
- `Job01_HindsightSlash`
- `Job01_ViolentStab`
- `Job01_NormalAttack`
- `Job01_SkillAttack`
- `Job01_SubNormalAttack`

##### `main_pawn Job07`

Confirmed by CE dumps and burst traces:

- `current_job = 7`
- `Job07ActionCtrl` is live through both `field` and `getter`
- `ExecutingDecision` is live
- combat target can be `app.Character`
- runtime still stays in generic carrier families instead of entering confirmed `Job07_*` combat families

Observed generic carriers:

- `Common/MoveToPosition_Walk_Target.user`
- `ch1_Move_Run_Target.user`
- `Common/InForcedAnimation.user`
- `Locomotion.NormalLocomotion`
- `Locomotion.Strafe`
- `Damage.*`

Not confirmed for `main_pawn Job07`:

- stable `Job07_*` pack
- stable `Job07_*` node

##### `Sigurd Job07`

Valid `Sigurd` control traces now exist.

Confirmed:

- `Sigurd` enters real `Job07`-specific NPC packs
- `Sigurd` enters real `Combat.Job07_*` node families

Observed pack examples:

- `ch300_job07_SideWalkB_Blade4`
- `ch300_job07_SideWalkR_Blade4`
- `ch300_job07_SkyDive`
- `ch300_job07_MagicBindLeap`
- `ch300_job07_SpiralSlash`

Observed node examples:

- `Job07_ShortRangeAttack`
- `Job07_MagicBindJustLeap`
- `Job07_MagicBindComplete`
- `Job07_SkyDive`
- `Job07_SkyDiveLanding`
- `Job07_SpiralSlash`

#### Strengthened conclusions

These conclusions are now strong:

- the blocker is not best explained by a missing `Job07ActionCtrl`
- the blocker is not best explained by a missing decision state
- `Job07` content exists and works in the engine
- the current gap is `main_pawn`-specific
- the gap is closer to `selector / admission / context / pack transition`

#### Weakened or rejected conclusions

These older conclusions are no longer active:

- "`Job07` is absent for `main_pawn`"
- "`ce_dump=nil` proves the absence of `Job07ActionCtrl`"
- "`target kind mismatch` is always the root cause"
- "`getter` alone proves a live attack path"

#### Current strongest hypothesis

Current working hypothesis:

- `main_pawn Job07` receives controller, combat target, and decision state
- but `selector / admission / context / pack selection` does not move it from generic carriers into `Job07`-specific combat families

#### Archived research layer

The old research layer was removed from the product hot path.

Archived domains:

- orchestration: `app/module_specs.lua`, `app/runtime_driver.lua`, `core/module_system.lua`
- logging and traces: old `core/log.lua`, session logs, discovery logs, guild trace logs
- research modules: `action_research`, `combat_research`, `loadout_research`, `pawn_ai_data_research`, `guild_flow_research`, `sigurd_observer`, `npc_spawn_prototype`, `talk_event_trace`
- progression probes: `game/progression/trace.lua`, `probe.lua`, `correlation.lua`
- synthetic and adapter layer
- runtime debug UI

Restore rule:

- restore one concrete mechanism only after CE scripts prove that the narrowed question cannot be answered without hooks

#### Performance and network boundary

Still active rules:

- prefer compact summaries over broad reflective scans
- avoid getter-heavy probing in the product hot path
- keep the core branch local-runtime-first
- keep online, rental, and pawn-share logic out of the main implementation branch

#### Archived manual Content Editor path

The older manual `Content Editor` inspection route is preserved as reference, not as the default workflow.

Its main targets were:

- `AI Overview`
- `app.PawnBattleController._BattleAIData`
- `app.PawnOrderController.OrderData`
- `app.PawnUpdateController.AIGoalActionData`
- `app.goalplanning.AIGoalCategoryJob._JobDecisions`
- blackboard collections
- `CharacterManager:get_HumanParam() -> app.Job07Parameter`

Status:

- useful as a bounded manual fallback
- not the default path while CE Console scripts answer the active questions

### How-to

#### How to research now

Use CE Console scripts.

Standard cycle:

1. define one concrete question
2. choose one script for that question
3. write the result to file
4. compare it with a baseline or control actor
5. update this file first
6. update `ROADMAP.md` only if priorities changed
7. update `CHANGELOG.md` when code or documentation changed

#### How to judge a conclusion

A conclusion is strong enough for this file only if:

- the script wrote a structured result to file
- the result is reproducible
- the wording follows directly from recorded fields
- conflicting older wording was removed or explicitly weakened

#### How to decide whether hooks may return

Do not return to hooks by default.

Return is allowed only if all of the following are true:

- the question is already narrowed to one runtime transition
- screen and burst CE scripts do not capture it
- without hooks the cause cannot be demonstrated
- the need is documented before implementation starts
- the product branch stays isolated from broad research logging

### Reference

#### Active CE scripts

- `docs/ce_scripts/job07_runtime_resolution_screen.lua`
- `docs/ce_scripts/job07_burst_combat_trace.lua`
- `docs/ce_scripts/actor_burst_combat_trace.lua`
- `docs/ce_scripts/job07_selector_admission_compare_screen.lua`

#### Required CE script properties

Each CE script must:

- solve one concrete task
- write output to file
- produce data suitable for compare and later documentation updates

#### Current implementation files

- `mod/reframework/autorun/PawnHybridVocationsAI/bootstrap.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/discovery.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/main_pawn_properties.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/progression/state.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_unlock.lua`

#### Historical native decision-pool signals

The earlier native-first branch repeatedly used these containers as safe structural signals:

- `_CurrentGoalList`
- `_CurrentAddDecisionList`
- `MainDecisions`
- `PreDecisions`
- `PostDecisions`
- `ActiveDecisionPacks`

They remain useful as historical reference even though the current research path is CE-first.

## Русский

### Объяснение

#### Модель проекта

Инвариант проекта:

`unlock != equipment != skills != combat runtime != pawn combat context != AI parity`

Это означает:

- unlock сам по себе не чинит бой
- видимый guild access не доказывает рабочий AI
- живой controller не доказывает рабочий job-specific combat path

#### Текущее разделение проекта

Репозиторий теперь следует одному строгому разделению:

- `mod/` содержит продуктовый runtime-код
- `docs/ce_scripts/` содержит исследовательские скрипты

Базовая политика:

- `mod = implementation`
- `CE scripts = research`

#### Порядок источников истины

Если источники противоречат друг другу, доверять им в таком порядке:

1. CE outputs, записанные в файл
2. текущее поведение продуктового runtime
3. прямой engine data inspection
4. историческая документация из git
5. теория и догадки

#### Текущий продуктовый runtime

Активное runtime-ядро ограничено файлами:

- `bootstrap.lua`
- `game/discovery.lua`
- `game/main_pawn_properties.lua`
- `game/progression/state.lua`
- `game/hybrid_unlock.lua`

Сейчас продуктовый runtime делает три важных вещи:

1. резолвит `player` и `main_pawn`
2. читает progression и job-bit state
3. восстанавливает реальный hybrid unlock path для `main_pawn`

#### Текущее состояние unlock

Подтверждено в коде:

- hybrid unlock зависит от `player.QualifiedJobBits`
- недостающие hybrid bits зеркалятся в `main_pawn.JobContext.QualifiedJobBits`
- in-memory snapshot progression обновляется сразу после записи
- на `app.ui040101_00.getJobInfoParam` стоит узкий guild-side override
- override включает `_EnablePawn` для hybrid job info у `main_pawn` или использует cached player retval

Интерпретация:

- unlock снова работает через продуктовый runtime path
- unlock и guild access по-прежнему не решают отдельную проблему боевого `Job07`

#### Исторические выводы из pre-cleanup research

Удаленный research layer уже успел установить несколько полезных пунктов, которые остаются важными:

- `Job07` в движке реален, а не вымышлен
- `Job07` мог кратко приближаться к `Job01`, а затем снова деградировать
- более слабое состояние `Job07` было похоже на under-population или admission loss, а не на полное отсутствие
- широкий getter-heavy probing был дорогим и мог вызывать FPS collapse и REFramework exceptions

Сейчас эти выводы являются историческим контекстом, а не активным implementation path.

#### Подтвержденные боевые выводы

##### `main_pawn`

Подтверждено:

- `main_pawn` резолвится достаточно надежно для runtime inspection
- progression state, current job и базовый runtime context читаются

##### `Job01`

`Job01` - это контрольный baseline.

Подтверждено burst trace:

- сначала видна navigation phase
- затем combat execution переходит в job-specific packs
- затем появляются job-specific nodes

Наблюдавшиеся примеры:

- `Job01_BlinkStrike_Standard`
- `Job01_FullMoonSlash`
- `Job01_HindsightSlash`
- `Job01_ViolentStab`
- `Job01_NormalAttack`
- `Job01_SkillAttack`
- `Job01_SubNormalAttack`

##### `main_pawn Job07`

Подтверждено CE dumps и burst traces:

- `current_job = 7`
- `Job07ActionCtrl` жив и через `field`, и через `getter`
- `ExecutingDecision` жив
- боевая цель может быть `app.Character`
- runtime остается в generic carrier families вместо подтвержденного перехода в `Job07_*` combat families

Наблюдавшиеся generic carriers:

- `Common/MoveToPosition_Walk_Target.user`
- `ch1_Move_Run_Target.user`
- `Common/InForcedAnimation.user`
- `Locomotion.NormalLocomotion`
- `Locomotion.Strafe`
- `Damage.*`

Не подтверждено для `main_pawn Job07`:

- стабильный `Job07_*` pack
- стабильный `Job07_*` node

##### `Sigurd Job07`

Валидные контрольные `Sigurd` traces уже существуют.

Подтверждено:

- `Sigurd` входит в реальные `Job07`-specific NPC packs
- `Sigurd` входит в реальные `Combat.Job07_*` node families

Примеры pack:

- `ch300_job07_SideWalkB_Blade4`
- `ch300_job07_SideWalkR_Blade4`
- `ch300_job07_SkyDive`
- `ch300_job07_MagicBindLeap`
- `ch300_job07_SpiralSlash`

Примеры node:

- `Job07_ShortRangeAttack`
- `Job07_MagicBindJustLeap`
- `Job07_MagicBindComplete`
- `Job07_SkyDive`
- `Job07_SkyDiveLanding`
- `Job07_SpiralSlash`

#### Усиленные выводы

Эти выводы сейчас сильные:

- блокер не объясняется отсутствием `Job07ActionCtrl`
- блокер не объясняется отсутствием decision state
- `Job07` content существует и работает в движке
- текущий разрыв специфичен для `main_pawn`
- разрыв ближе к `selector / admission / context / pack transition`

#### Ослабленные или отвергнутые выводы

Эти старые выводы больше не активны:

- "`Job07` отсутствует у `main_pawn`"
- "`ce_dump=nil` доказывает отсутствие `Job07ActionCtrl`"
- "`target kind mismatch` всегда является корнем проблемы"
- "`getter` сам по себе доказывает живой attack path"

#### Текущая сильнейшая гипотеза

Текущая рабочая гипотеза:

- `main_pawn Job07` получает controller, combat target и decision state
- но `selector / admission / context / pack selection` не переводит его из generic carriers в `Job07`-specific combat families

#### Архив удаленного research layer

Старый research layer удален из продуктового hot path.

Архивированные домены:

- orchestration: `app/module_specs.lua`, `app/runtime_driver.lua`, `core/module_system.lua`
- logging and traces: старый `core/log.lua`, session logs, discovery logs, guild trace logs
- research modules: `action_research`, `combat_research`, `loadout_research`, `pawn_ai_data_research`, `guild_flow_research`, `sigurd_observer`, `npc_spawn_prototype`, `talk_event_trace`
- progression probes: `game/progression/trace.lua`, `probe.lua`, `correlation.lua`
- synthetic и adapter layer
- runtime debug UI

Правило возврата:

- возвращать только один конкретный механизм и только после того, как CE scripts докажут, что narrowed question нельзя решить без hooks

#### Граница производительности и сети

Все еще действующие правила:

- предпочитать компактные summaries широким reflective scans
- избегать getter-heavy probing в продуктовом hot path
- держать core branch local-runtime-first
- не вносить online, rental и pawn-share logic в main implementation branch

#### Архивный ручной Content Editor path

Старый ручной путь через `Content Editor` сохранен как reference, а не как путь по умолчанию.

Его главные targets:

- `AI Overview`
- `app.PawnBattleController._BattleAIData`
- `app.PawnOrderController.OrderData`
- `app.PawnUpdateController.AIGoalActionData`
- `app.goalplanning.AIGoalCategoryJob._JobDecisions`
- blackboard collections
- `CharacterManager:get_HumanParam() -> app.Job07Parameter`

Статус:

- полезен как bounded manual fallback
- не является путем по умолчанию, пока CE Console scripts отвечают на активные вопросы

### Как сделать

#### Как исследовать сейчас

Использовать CE Console scripts.

Стандартный цикл:

1. сформулировать один конкретный вопрос
2. выбрать один скрипт под этот вопрос
3. записать результат в файл
4. сравнить его с baseline или control actor
5. сначала обновить этот файл
6. обновить `ROADMAP.md` только если изменились приоритеты
7. обновить `CHANGELOG.md`, если изменились код или документация

#### Как оценивать силу вывода

Вывод достаточно силен для этого файла только если:

- скрипт записал структурированный результат в файл
- результат воспроизводим
- формулировка прямо следует из записанных полей
- конфликтующие старые формулировки удалены или явно ослаблены

#### Как решать, можно ли вернуть hooks

Не возвращаться к hooks по умолчанию.

Возврат допустим только если одновременно выполнены условия:

- вопрос уже сужен до одного runtime transition
- screen и burst CE scripts не ловят его
- без hooks нельзя доказать причину
- необходимость задокументирована до начала реализации
- product branch остается изолированным от широкого research logging

### Справка

#### Активные CE scripts

- `docs/ce_scripts/job07_runtime_resolution_screen.lua`
- `docs/ce_scripts/job07_burst_combat_trace.lua`
- `docs/ce_scripts/actor_burst_combat_trace.lua`
- `docs/ce_scripts/job07_selector_admission_compare_screen.lua`

#### Обязательные свойства CE script

Каждый CE script должен:

- решать одну конкретную задачу
- писать результат в файл
- выдавать данные, пригодные для compare и дальнейшего обновления документации

#### Текущие implementation files

- `mod/reframework/autorun/PawnHybridVocationsAI/bootstrap.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/discovery.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/main_pawn_properties.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/progression/state.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_unlock.lua`

#### Исторические native decision-pool signals

Ранний native-first branch многократно использовал эти containers как безопасные структурные сигналы:

- `_CurrentGoalList`
- `_CurrentAddDecisionList`
- `MainDecisions`
- `PreDecisions`
- `PostDecisions`
- `ActiveDecisionPacks`

Они остаются полезной исторической справкой, даже если текущий путь исследования теперь CE-first.

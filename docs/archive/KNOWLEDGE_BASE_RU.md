# KNOWLEDGE_BASE_RU

## Путеводитель

Этот файл теперь стоит читать в трех слоях:

1. инварианты проекта и текущие выводы
2. структурированные каталоги с полями `Откуда / Что делает / Как использовать / Что важно`
3. исторический narrative и архивные заметки

Правило каталога:

- если идентификатор, файл, метод, контейнер, skip reason или исследовательский артефакт влияет на дизайн, runtime-поведение или workflow исследования, он должен быть описан в одном из каталогов ниже
- narrative-разделы могут повторно упоминать те же сущности, но именно каталог должен объяснять, что это такое, откуда мы это взяли и как это можно применять не только в рамках нашего мода

## Объяснение

### Модель проекта

Инвариант проекта:

`unlock != equipment != skills != combat runtime != pawn combat context != AI parity`

Это означает:

- unlock сам по себе не чинит бой
- видимый guild access не доказывает рабочий AI
- живой controller не доказывает рабочий job-specific combat path

### Текущее разделение проекта

Репозиторий теперь следует одному строгому разделению:

- `mod/` содержит продуктовый runtime-код
- `docs/ce_scripts/` содержит исследовательские скрипты

Базовая политика:

- `mod = implementation`
- `CE scripts = research`

### Порядок источников истины

Если источники противоречат друг другу, доверять им в таком порядке:

1. CE outputs, записанные в файл
2. текущее поведение продуктового runtime
3. прямой engine data inspection
4. историческая документация из git
5. теория и догадки

### Текущий продуктовый runtime

Активное runtime-ядро ограничено файлами:

- `bootstrap.lua`
- `game/main_pawn_properties.lua`
- `game/progression/state.lua`
- `game/hybrid_unlock.lua`
- `game/hybrid_combat_fix.lua`

Сейчас продуктовый runtime делает три важных вещи:

1. резолвит `player` и `main_pawn`
2. читает progression и job-bit state
3. восстанавливает реальный hybrid unlock path для `main_pawn`

### Текущее состояние unlock

Подтверждено в коде:

- hybrid unlock зависит от `player.QualifiedJobBits`
- недостающие hybrid bits зеркалятся в `main_pawn.JobContext.QualifiedJobBits`
- in-memory snapshot progression обновляется сразу после записи
- на `app.ui040101_00.getJobInfoParam` стоит узкий guild-side override
- override включает `_EnablePawn` для hybrid job info у `main_pawn` и в остальных случаях возвращает исходный UI result

Подтверждено в игре:

- краш, внесенный прежним рискованным guild-hook path, устранен
- восстановленный unlock path снова работает для `main_pawn`

Интерпретация:

- unlock снова работает через продуктовый runtime path
- unlock и guild access по-прежнему не решают отдельную проблему боевого `Job07`

### Исторические выводы из pre-cleanup research

Удаленный research layer уже успел установить несколько полезных пунктов, которые остаются важными:

- `Job07` в движке реален, а не вымышлен
- `Job07` мог кратко приближаться к `Job01`, а затем снова деградировать
- более слабое состояние `Job07` было похоже на under-population или admission loss, а не на полное отсутствие
- широкий getter-heavy probing был дорогим и мог вызывать FPS collapse и REFramework exceptions

Сейчас эти выводы являются историческим контекстом, а не активным implementation path.

### Внешние исследовательские инструменты

Исследование теперь намеренно вынесено во внешние инструменты.

Используйте эти средства вместо возврата discovery-кода в product runtime:

- `Content Editor` как основной инструмент live inspection:
- `ce_find(...)`
- `ce_dump(...)`
- viewers для AI overview и blackboard
- `DD2_DataScraper` как основной one-shot export tool для bulk data snapshots
- `Nick's Devtools` и `_NickCore` только как dev-only live tracers, а не как зависимости product runtime
- `Skill Maker` как справочный каталог action names, skill metadata и user-facing skill datasets

Политика:

- `mod/` не должен поставлять широкие discovery-механизмы, recursive graph scans или hook-heavy research utilities
- live research должно жить в `docs/ce_scripts/` или во внешних tool-модах
- если на вопрос можно ответить через `Content Editor` или `DD2_DataScraper`, не добавляйте новый runtime probe в продуктовый мод
- логи `skip-reason` и `target-source` должны быть выключены по умолчанию в product runtime; если они снова нужны, включайте их только временно под узкий вопрос

### Текущий поворот реализации

Проект теперь считает полное восстановление native `MainDecisions` для `main_pawn Job07` фоновой гипотезой, а не критическим путём внедрения.

Текущее рабочее направление:

- оставить native AI владение target publication, навигацией, safety states и уже идущим hybrid output
- считать отсутствие `Job07` attack cluster практической проблемой недонаселённого decision content, а не ближайшей задачей полного восстановления
- строить узкий synthetic attack adapter, который просыпается только после ограниченного `synthetic_stall` окна при live enemy target
- использовать `execution_contracts` как backend-слой исполнения этого adapter, а не пытаться заставить contracts заменить native decision population

### Handoff snapshot для внешнего разработчика (`2026-03-29`)

Текущее product-состояние:

- unlock снова работает через runtime mirror job bits плюс узкий guild-side `_EnablePawn` override
- synthetic `Job07` adapter уже доходит до реального `Job07` execution на `main_pawn`, а не только до common locomotion
- в последних живых трассах уже есть `ch300_job07_Run_Blade4.user`, `ch300_job07_RunAttackNormal.user`, `ch300_job07_MagicBindLeap.user` и повторяющийся `Job07_ShortRangeAttack`
- `DragonStinger` по умолчанию заблокирован data-driven stability gate, потому что прямой live run стабильно падал в `app.Job07DragonStinger.update`
- product runtime теперь также консервативно уважает `min_job_level`, даже когда уровень известен только как `assumed_minimum_job_level`; старые заметки, где предлагалось так не делать, остаются историческим research-контекстом, а не текущим runtime-поведением
- главный блокер сейчас уже не первый admission в бой, а удержание ближнего контакта и hit conversion после первого успешного engage, потому что landing или recovery output вместе с `native_output_backoff_active` слишком легко выталкивают пешку обратно из follow-through

Ключевые живые артефакты для handoff:

- `PawnHybridVocationsAI.session_20260329_080636.log`
- `PawnHybridVocationsAI.nicktrace_20260329_080636.log`
- `actor_burst_combat_trace_sigurd_job07_20260328_145935.json`
- `actor_burst_combat_trace_sigurd_job07_20260328_145907.json`

Что сейчас полезнее всего проверить автору `_NickCore`:

- почему `MagicBindLeap` и `Job07_ShortRangeAttack` уже исполняются, но всё ещё плохо конвертируются в реальный урон
- не теряется ли на execution-layer continuity по target, lock-on или hit-confirm между `setBBValuesToExecuteActInter(...)` и последующим `requestActionCore(...)`
- `_NickCore` нужно держать dev-only tracer'ом и reference surface, а не превращать в жёсткую product dependency

### Снимок кодового аудита (`2026-03-29`)

Сильные стороны:

- product runtime и CE research теперь чисто разделены
- scheduler фиксирует timestamp только после успешного scheduled run
- у `main_pawn` появился общий stable snapshot, который уже переиспользуют progression, unlock, combat и dev tracer
- cached reflected-field и method-fallback readers теперь живут в общих runtime helper'ах, а не расползаются по модулям
- общий surface-слой для `pack/path/name/node/collection` уже вынесен отдельно и переиспользуется combat'ом и `_NickCore` tracer'ом
- `execution_contracts`, `vocations`, `hybrid_combat_profiles` и `_NickCore` tracer уже достаточно data-driven, чтобы их можно было нормально обсуждать и расширять с внешним разработчиком

Текущие структурные риски:

- `game/hybrid_combat_fix.lua` всё ещё объединяет context resolution, target normalization, output classification, support-heal guards, skill gating, stage routing, selection scoring, bridge execution, quarantine, telemetry и logs в одном модуле примерно на `3.6k` строк
- глубокие target/context helper'ы всё ещё в основном сосредоточены внутри `game/hybrid_combat_fix.lua`; readers и общий runtime surface-слой уже вынесены, но enemy-target bridging и shaping боевого context ещё нет
- `allow_unmapped_skill_phases = true` теперь задокументирован и логируется честнее, но по смыслу всё ещё уже своего широкого названия: `selector_owned` контракты всё равно блокируются как `selector_owned_unbridgeable`
- в hot combat target path всё ещё остаются опциональные `resolve_game_object(..., true)` и component-based fallback, поэтому грязные боевые кадры всё ещё хрупче, чем хотелось бы
- в репозитории по-прежнему нет автоматического Lua syntax или regression harness; главным safety net остаётся in-game validation

Рекомендуемый порядок рефактора:

1. разрезать `game/hybrid_combat_fix.lua` на более узкие runtime-модули вроде `context`, `target`, `gates`, `selector`, `bridge`
2. централизовать `call_first` и `field_first` в shared helpers вместо копирования по модулям
3. вынести enemy-target bridging и shaping боевого context в отдельные runtime helper'ы, а не продолжать раздувать их внутри `game/hybrid_combat_fix.lua`
4. вынести close-contact hold и hit-conversion logic в отдельный follow-through слой, а не продолжать раздувать общий selector
5. оставить `_NickCore` tracing опциональным и внешним, а product mod должен потреблять только минимальные dev-only callbacks

### Подтвержденные боевые выводы

#### `main_pawn`

Подтверждено:

- `main_pawn` резолвится достаточно надежно для runtime inspection
- progression state, current job и базовый runtime context читаются

#### `Job01`

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

#### `main_pawn Job07`

Подтверждено CE dumps и burst traces:

- `current_job = 7`
- `Job07ActionCtrl` жив и через `field`, и через `getter`
- primary decision module - `app.DecisionEvaluationModule`
- `DecisionExecutor` жив
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

#### `Sigurd Job07`

Валидные контрольные `Sigurd` traces уже существуют.

Подтверждено:

- `Sigurd` входит в реальные `Job07`-specific NPC packs
- `Sigurd` входит в реальные `Combat.Job07_*` node families
- primary decision module - `app.ThinkTableModule`
- `DecisionExecutor` и `ExecutingDecision` отсутствуют в наблюдаемом `Sigurd Job07` pipeline

Примеры pack:

- `ch300_job07_SideWalkB_Blade4`
- `ch300_job07_SideWalkL_Blade4`
- `ch300_job07_SideWalkR_Blade4`
- `ch300_job07_SkyDive`
- `ch300_job07_MagicBindLeap`
- `ch300_job07_Run_Blade4`
- `ch300_job07_RunAttackNormal`
- `ch300_job07_QuickShield`
- `ch300_job07_SpiralSlash`

Примеры node:

- `Job07_ShortRangeAttack`
- `Job07_MagicBindJustLeap`
- `Job07_MagicBindComplete`
- `Job07_SkyDive`
- `Job07_SkyDiveLanding`
- `Job07_SpiralSlash`

#### Архитектура decision pipeline

Точечные CE compares теперь показывают структурный разрыв:

- `main_pawn Job07` идет через pawn pipeline `app.DecisionEvaluationModule`
- `Sigurd Job07` идет через NPC pipeline `app.ThinkTableModule`
- `ThinkTableModule` не найден рядом с наблюдаемой decision chain у `main_pawn` в протестированных сценах
- прежний вопрос про `selector / admission / context` теперь уже сужен до вопроса о pawn-specific decision content или decision output

#### Боевая популяция `MainDecisions`

Точечные боевые captures теперь показывают второй, более сильный разрыв уже внутри pawn pipeline:

- вне боя selected-job-only snapshots еще могут выглядеть одинаково между `main_pawn Job01` и `main_pawn Job07`
- в бою `main_pawn Job01` повторяемо показывает `42` `MainDecisions`
- в бою `main_pawn Job07` повторяемо показывает только `11` `MainDecisions`
- по повторным captures у `main_pawn Job07` нет уникальных боевых `scalar_profile` или `combined_profile`
- наблюдаемые боевые `main_pawn Job07` `MainDecisions` являются строгим подмножеством боевых `main_pawn Job01` `MainDecisions`
- значит оставшийся blocker уже виден внутри боевой популяции решений pawn `DecisionEvaluationModule`

#### Семантический боевой разрыв внутри `MainDecisions`

Семантический compare усиливает тот же вывод:

- повторные semantic captures показывают `main_pawn Job01` на уровне `47-48` боевых `MainDecisions`
- повторные semantic captures показывают `main_pawn Job07` на уровне `11` боевых `MainDecisions`
- `main_pawn Job07` не дает ни одной уникальной боевой `semantic_signature`; все наблюдаемые `Job07` semantic signatures уже присутствуют у `Job01`
- сохраненный боевой слой `Job07` доминируется common/generic utility-поведением: movement, carry, talk, catch, cliff, keep-distance
- в этих боевых captures у `main_pawn Job07` все еще не наблюдаются `Job07_*` action-pack identities
- `main_pawn Job01` содержит много дополнительных attack-oriented packs и behavior, которые не доживают до боевого `Job07`, включая множественные `Job01_Fighter/*` packs и несколько `GenericJob/*Attack*` packs
- у сокращенного боевого слоя `Job07` также пропадает значительная часть более богатой популяции `EvaluationCriteria`, `TargetConditions` и start/end-process c `SetAttackRange`, которая есть у боевого `Job01`

### Усиленные выводы

Эти выводы сейчас сильные:

- блокер не объясняется отсутствием `Job07ActionCtrl`
- блокер не объясняется отсутствием decision state
- `Job07` content существует и работает в движке
- текущий разрыв специфичен для `main_pawn`
- `main_pawn Job07` и `Sigurd Job07` не используют одну и ту же primary decision architecture
- `main_pawn Job07` использует `app.DecisionEvaluationModule`
- `Sigurd Job07` использует `app.ThinkTableModule`
- текущий разрыв теперь лучше объясняется как gap в pawn decision-pipeline, а не только как generic selector/admission surface gap
- в бою `main_pawn Job07` недонаселен до action output, а не только misrouted после selection
- наблюдаемые боевые `main_pawn Job07` `MainDecisions` являются строгим подмножеством боевых `main_pawn Job01` `MainDecisions`
- наблюдаемый боевой semantic layer у `main_pawn Job07` остается generic/common-heavy и не показывает подтвержденного `Job07` attack-oriented decision cluster
- timed combat output bursts теперь закрывают следующий bridge-step:
- стабильные боевые burst-срезы `Job01` показывают `attack_populated` decision state, который в основном уходит в `job_specific_output_candidate`, включая `Job01_*` actions, `Job01_*` FSM nodes и attack-oriented `decision_pack_path`
- стабильный боевой burst у `Job07` все еще показывает только `11` `MainDecisions`, `current_job_pack_count=0`, `generic_attack_pack_count=0`, utility-only pack identities и `common_utility_output` вроде `Strafe`, `NormalLocomotion` и `Common/MoveToPosition_Walk_Target`
- значит отсутствующее боевое поведение теперь прослежено до output surfaces, а не только выведено из differences в decision population

### Ослабленные или отвергнутые выводы

Эти старые выводы больше не активны:

- "`Job07` отсутствует у `main_pawn`"
- "`ce_dump=nil` доказывает отсутствие `Job07ActionCtrl`"
- "`target kind mismatch` всегда является корнем проблемы"
- "`getter` сам по себе доказывает живой attack path"

### Текущая сильнейшая гипотеза

Текущая рабочая гипотеза:

- `main_pawn Job07` не ломается внутри NPC `ThinkTableModule` path, потому что в наблюдаемых сценах он вообще не использует этот path
- боевой content pawn `DecisionEvaluationModule` для `Job07` не просто отличается; он недонаселен относительно боевого `Job01`
- следующий вопрос - какие именно отсутствующие attack-oriented боевые `MainDecisions` соответствуют потерянному `Job07` combat behavior и как это сокращение доходит до evaluation output или action output
- самые сильные локальные кандидаты сейчас - отсутствующие `Job01_Fighter/*`, `GenericJob/*Attack*` и `SetAttackRange`-bearing combat decisions, которые присутствуют у боевого `Job01`, но не появляются у боевого `Job07`

### Поверхность определений профессий

`vocation_definition_surface_20260326_195656.json` подтверждает, что через CE Console мы можем вытаскивать не только actor или NPC snapshots, но и реальную class-definition surface профессий.

- `app.HumanCustomSkillID` теперь дает подтвержденные hybrid custom-skill bands:
- `Job07 = 70..79`
- `Job08 = 80..91`
- `Job09 = 92..99`
- `Job10 = 100`
- `app.HumanAbilityID` также дает подтвержденные hybrid ability bands:
- `Job07 = 34..38`
- `Job08 = 39..43`
- `Job09 = 44..48`
- `Job10 = 49..50`
- `Job07Parameter` раскрывает реальные боевые поверхности вроде `NormalAttackParam`, `HeavyAttackParam`, `MagicBindParam`, `SpiralSlashParam`, `SkyDiveParam`, `DragonStingerParam`, `FarThrowParam`, `EnergyDrainParam` и `DanceOfDeathParam`
- `Job08Parameter` раскрывает `NormalAttackParam`, `FlameLanceParam`, `BurningLightParam`, `FrostBlockParam`, `ThunderChainParam`, `CounterArrowParam`, `SeriesArrowParam` и `SpiritArrowParam`
- `Job09Parameter` раскрывает `_NormalAttackParam`, `_ThrowSmokeParam`, `_SmokeDecoyParam`, `_DetectFregranceParam` и `_AstralBodyParam`
- `Job10Parameter` пока показывает только `Job10_00Param`
- `Job07`, `Job08` и `Job09` имеют живые `InputProcessor`, `ActionController` и `ActionSelector`, тогда как у `Job10` наблюдаются controller и selector surfaces, но не наблюдается `Job10InputProcessor`
- `Job07InputProcessor` и `Job07ActionSelector` уже показывают конкретные точки входа вроде `processMagicBind`, `processNormalAttack`, `processSpiralSlash`, `processCustomSkill`, `getCustomSkillAction`, `getNormalAttackAction` и `requestActionImpl`
- `Job08` и `Job09` тоже показывают конкретные job-specific `processCustomSkill` и normal-attack selector surfaces, так что профили для `08` и `09` можно строить уже не вслепую
- исходные профессии тоже дают сильный control baseline:
- у `Job01` through `Job06` в captured `vocation_definition_surface` стабильно читаются `AbilityParam` bands без неоднозначности:
- `Job01 = 4..8`
- `Job02 = 9..13`
- `Job03 = 14..18`
- `Job04 = 19..23`
- `Job05 = 24..28`
- `Job06 = 29..33`
- `Job01` through `Job06` также показывают богатые parameter-family surfaces, которые помогают отличать реальные боевые families от custom-skill families:
- `Job01`: `NormalAttack`, `TuskToss`, `Guard`, `BlinkStrike`, `ViolentStab`, `HindsightSlash`, `FullMoonGuard`, `ShieldCounter`, `DivineDefense`
- `Job02`: bow и arrow families вроде `NormalArrow`, `FullBend`, `QuickLoose`, `Threehold`, `Triad`, `MeteorShot`, `AcrobatShot`, `WhirlingArrow`, `FullBlast`
- `Job03`: staff или spell families вроде `Anodyne`, `FireStrom`, `Levin`, `Frigor`, `GuardBit`, `HolyShine`, `CureSpot`, `HasteSpot`, `Boon`, `Enchant`
- `Job04`: dagger или rogue families вроде `_NormalAttack`, `_LoopAttack`, `_Pickpocket`, `_CuttingWind`, `_Guillotine`, `_ParryCounter`, `_AbsoluteAvoidance`, `_Stealth`
- `Job05`: greatsword families вроде `NormalAttack`, `ChargeNormalAttack`, `HeavyAttack`, `CrescentSlash`, `GroundDrill`, `WarCry`, `IndomitableLash`, `CycloneSlash`, `ArcOfObliteration`
- `Job06`: sorcerer families вроде `_NormalAttack`, `_RapidShot`, `_Salamander`, `_Blizzard`, `_MineVolt`, `_SaintDrain`, `_MeteorFall`, `_VortexRage`
- off-job доступ к `SkillContext` сильный: и `player`, и `main_pawn` показывают per-job equip lists для `Job07` through `Job10`, даже если в момент capture они были не на этих профессиях
- эта off-job visibility не является чем-то сугубо hybrid-specific: даже когда в recorded snapshot `player = Mage`, а `main_pawn = Fighter`, live skill scan всё равно показывает enabled или level-positive entries по `Job01` through `Job08`, включая `Job01_BlinkStrike`, `Job02_ThreefoldArrow`, `Job03_Firestorm`, `Job04_CuttingWind` и `Job05_CrescentSlash`
- это значит, что движок готов раскрывать широкое cross-job progression state без фактического переключения актёра на нужную профессию, поэтому в будущих progression tools исходные профессии нужно использовать как control group, а не как “чужой” контент
- в записанном snapshot и `player`, и `main_pawn` имели `Job07 slot0 = Job07_DragonStinger`, `Job08 slot0 = Job08_FrostTrace`, а `Job09` и `Job10` были пустыми
- `SkillAvailability` в этом snapshot остался unresolved, тогда как `SkillContext` и `CustomSkillState` были живыми, значит runtime-gating лучше опирать на `SkillContext`, per-job equip lists, `hasEquipedSkill(...)`, `isCustomSkillEnable(...)` и `getCustomSkillLevel(...)`
- `SkyDive` подтвержден как custom skill `76`
- `SpiralSlash` присутствует в `Job07Parameter` и `Job07InputProcessor`, но отсутствует в `app.HumanCustomSkillID`; пока не появится противоположное CE evidence, его правильно считать core или non-custom move, а не custom-skill gate
- `Job10` структурно особый и должен идти отдельной implementation track, когда runtime bridge будет расширяться с `Job07` на `Job08` through `Job10`
- два caution signal из live skill scan тоже стоит сохранить:
- placeholder-like `None` entry всё ещё может появляться как enabled с `level = 1`
- `Job01_BravesRaid` в этом snapshot появлялся как enabled без явного equipped-job list
- значит live skill scan очень полезен, но любой progression reader всё равно должен фильтровать placeholder rows и не считать, что `enabled = true` всегда автоматически означает чистый equipped-slot origin

### Матрица прогрессии профессий

`vocation_progression_matrix_20260326_214421.json` подтверждает, что новый progression-oriented extractor уже может разделять несколько слоев, которые раньше смешивались.

- `Job07` теперь раскладывается достаточно чисто:
- base или core families: `CustomSkillLv2`, `Flow`, `HeavyAttack`, `JustLeap`, `MagicBind`, `NormalAttack`, `SpiralSlash`
- custom-skill families: `BladeShoot`, `DanceOfDeath`, `DragonStinger`, `EnergyDrain`, `FarThrow`, `Gungnir`, `PsychoShoot`, `QuickShield`, `SkyDive`, `TwoSeconds`
- `Job08` тоже раскладывается достаточно чисто:
- base или core families: `AimArrow`, `Effect`, `JustRelease`, `NormalAttack`, `RemainArrow`
- custom-skill families: `AbsorbArrow`, `BurningLight`, `CounterArrow`, `FlameLance`, `FrostBlock`, `FrostTrace`, `LifeReturn`, `ReflectThunder`, `SeriesArrow`, `SleepArrow`, `SpiritArrow`, `ThunderChain`
- `Job09` пока не маппится так же чисто через enum-name heuristic; его parameter families всё ещё выглядят как smoke, fragrance, possession, decoy и astral groups, значит для `Job09` нужен отдельный family mapping, а не прямой enum-name join
- `Job10` на этом уровне всё ещё остаётся opaque; наблюдаемая parameter family surface пока сводится только к `Job10_00`
- live off-job progression state в этом snapshot совпадает и у `player`, и у `main_pawn`:
- `Job07_DragonStinger` стоит в экипировке, включён и показывает `level = 1`
- `Job08_FrostTrace` стоит в экипировке, включён и показывает `level = 1`
- активных `Job09` или `Job10` custom skills в этом snapshot не наблюдалось
- в live `AbilityContext` snapshot для обоих акторов не наблюдалось экипированных hybrid augments или abilities
- `current_job_level` и per-hybrid `getJobLevel(...)` у обоих записанных акторов остались `nil`, значит прямые runtime reads уровня всё ещё ненадёжны и не должны жёстко блокировать базовые атаки или level-0 fallback phases
- первый прогон progression-matrix выявил новое правило чтения для hybrid augment data: `AbilityParam.JobAbilityParameters` ведёт себя как коллекция с индексом `job_id - 1`, поэтому прямое индексирование по `job_id` сдвигает `Job07` на `Job08`, `Job08` на `Job09` и так далее
- из-за этой indexing hazard первый progression-matrix JSON уже надёжен для base/core families и custom-skill state, но per-job hybrid augment matrix нужно переснять после фикса extractor, прежде чем считать её канонической

### Подтвержденное направление реализации

Следующий шаг теперь уже не blind pack guessing.

- держать diagnosis по decision-pipeline как основное объяснение проблемы `main_pawn Job07`
- использовать extracted class-definition surface для построения progression-aware hybrid profiles
- рассматривать `Job07` как первый grounded profile:
- core phases могут опираться на подтвержденные non-custom surfaces вроде `SpiralSlash`
- custom-skill phases должны опираться на подтвержденные ids вроде `SkyDive = 76`
- ту же profile architecture нужно расширять на `Job08` и `Job09`, а `Job10` вести как отдельный structural case

### Последняя заметка по стабилизации runtime

Последний `Job07` runtime-session добавил ещё один заземлённый вывод.

- bridge уже способен входить в несколько реальных `Job07` действий до stall, включая `Job07_BladeShoot`, carrier-backed `ch300_job07_Run_Blade4`, `Job07_MagicBindJustLeap` и `Job07_ShortRangeAttack`
- значит следующий blocker уже нельзя лучше всего описывать как чистый phase-selection failure
- тот же session вскрыл дефект диагностики: blocked-phase summaries теряли metadata execution contract и могли ложно печатать `selector_owned` даже для `direct_safe`, `carrier_required` или `controller_stateful`
- тот же session также показал проблему runtime-stability: несколько hot paths всё ещё звали `via.Component.get_GameObject`, а REFramework всё равно пишет такие internal exceptions в log, даже если Lua ловит вызов
- поэтому field-backed `GameObject` resolution теперь считается основным hot-path правилом для combat target resolution и actor-state collection
- следующий runtime-fix теперь заключается не в ещё одной теории admission для `Job07`, а в возврате к уже заземлённому execution-contract solution: держать `carrier_required` phases на carrier bridge, оставлять direct `requestActionCore(...)` только как путь `direct_safe` и не считать raw action forcing универсальным ответом
- live bridge теперь использует короткоживущий enemy target cache и throttled secondary target scans, чтобы однофреймовое колебание `ExecutingDecision` больше не выбрасывало `carrier_required` phases до срабатывания pack bridge
- свежие bursts публикации target для `Job07` уточнили следующий runtime gate: enemy target может оставаться живым через `ExecutingDecision` или `_EnemyList`, пока output временно сидит в `Damage.DmgShrink*`, поэтому bridge должен допускать узкое окно damage-recovery, а не входить только из locomotion или utility-like output
- следующие две session после этого фикса оказались почти пустыми и записали только bootstrap, а значит runtime всё ещё выходил раньше phase logging и остаточная слепая зона сместилась в early skip paths, а не в саму phase execution
- поэтому runtime теперь пишет throttled skip telemetry и для тихих выходов вроде unresolved context, non-utility output, unresolved target, unresolved target `GameObject` или unresolved bridge context
- сравнение атакующего session `2026-03-26 22:58:44` и stalled session `2026-03-26 23:27:31` показывает, что текущий blocker лежит в target acquisition, а не в action execution: поздний прогон уже не держал стабильный enemy target и переключался между `self`-targeted и unresolved surfaces ещё до запуска любой phase
- поэтому диагностика combat target теперь отдельно опрашивает `ExecutingDecision`, `AIBlackBoardController`, `HumanActionSelector`, `CommonActionSelector`, `OrderTargetController` и `JobXXActionCtrl`, а не схлопывает всё в один selector root

### Дополнение по target

- успешный session `2026-03-26 22:58:44` ещё держал одну стабильную enemy target, а stalled session `2026-03-26 23:27:31` уже не удерживал врага и переключался между `self` и `nil`
- теперь runtime-диагностика по target логирует `ExecutingDecision`, `AIBlackBoardController`, `HumanActionSelector`, `CommonActionSelector`, `OrderTargetController` и `JobXXActionCtrl` по отдельности, чтобы target regression было видно ещё до phase execution
- старые CE compare-слепки уже показали полезную асимметрию для `main_pawn Job07`: живым был именно `ExecutingDecision.Target`, а target-поверхности `AIBlackBoard`, `HumanActionSelector` и `Job07ActionCtrl` оставались `nil`, поэтому selector-facing roots нельзя считать нашим основным историческим target contract
- те же старые CE и git-данные также подтвердили `LockOnCtrl`, `AIMetaController` и cached pawn controllers вроде `CachedPawnOrderTargetController`, поэтому именно их теперь правильно возвращать как самые grounded secondary target roots до расширения поиска в более широкие battle/request surfaces
- старый релевантный боевой session всё же дал один grounded-факт: `executing_decision_target` уже мог нести валидный `via.GameObject`, а выбранным персонажем всё равно оставалась сама пешка, так что для той сборки target identity точно был подтверждённым блокером
- однако последующие runtime-правки заменили несколько hot-path вызовов `get_GameObject` на field-backed `resolve_game_object(..., false)`, поэтому более новые `re2_framework_log.txt` уже нельзя использовать как чистый негативный тест для гипотезы про `via.Component.get_GameObject`
- теперь есть `docs/ce_scripts/main_pawn_target_surface_screen.lua` как узкий CE Console extractor для target-bearing roots; он пишет `main_pawn_target_surface_<timestamp>.json` и снимает `ExecutingDecision`, `LockOnCtrl`, `AIMetaController`, cached pawn controllers, selectors, `JobXXActionCtrl`, `CurrentAction` и `SelectedRequest`
- три свежих `main_pawn_target_surface` слепка добавили более сильную точку сравнения: и `Job07`, и `Job01` могут показывать валидного врага напрямую через `ExecutingDecision.<Target>.<Character>`, а `LockOnCtrl`, `AIBlackBoard.Target`, selectors и `JobXXActionCtrl.Target` в тех же samples остаются пустыми
- те же слепки также показали, что `app.PawnOrderTargetController` на самом деле не пустой; он несёт `_EnemyTargetNum`, `_EnemyList`, `_FrontTargetList`, `_InCameraTargetList` и `_SensorHitResult`, а значит этот контроллер target-bearing именно через collections, а не через обычное поле `Target`
- из-за этого runtime fallback по target теперь должен уметь collection-based extraction из `PawnOrderTargetController`, а не только всё глубже опрашивать `Target/CurrentTarget/OrderTarget`
- последний game-side session-log всё ещё не печатает `ai_meta_controller` или cached-controller probes, а значит этот запуск, вероятно, шёл на более старой синхронизированной сборке мода, чем текущий локальный target-root patch
- следующий `Job07` target-surface-триплет (`2026-03-27 00:22:52`, `00:22:55`, `00:22:58`) уточнил ту же картину: `ExecutingDecision` переключался между `self` и реальным врагом, `PlayerOfAITarget` стабильно резолвил пару `player + owner-self`, а selector-facing roots всё ещё оставались пустыми
- те же слепки также показали конкретные типы элементов внутри `PawnOrderTargetController`: `_EnemyList -> via.GameObject`, `_FrontTargetList/_InCameraTargetList -> app.VisionMarker`, `_SensorHitResult -> app.PawnOrderTargetController.HitResultData`
- из-за этого и runtime, и CE extraction теперь должны отдельно уметь читать `VisionMarker.<CachedCharacter>` и `HitResultData.Obj`, а не только обычные поля `Character` или `Target`
- следующий `Job07` триплет (`2026-03-27 06:58:07`, `06:58:12`, `06:58:15`) наконец заземлил самый сильный fallback root на текущий момент: `_EnemyList` оказался не просто “не пустым”, а его первый элемент был прямым `via.GameObject`, который резолвил `other` enemy `app.Character` даже тогда, когда `ExecutingDecision` уже успевал вернуться в `self`
- тот же триплет также не показал расхождения `field` против `method` для самого `ExecutingDecision`: `game_object_paths.target_field` и `game_object_paths.target_method` оба резолвили один и тот же `via.GameObject`, так что этот root сейчас сильнее указывает на identity-instability, чем на перекос доступа к `GameObject`
- `VisionMarker` остался более слабым именно в этих captures, потому что `<CachedCharacter>` там был `nil`, а `get_GameObject()` при этом возвращал `via.GameObject`; `HitResultData` же показывал `Obj` в reflective field snapshots, но обычный индексный доступ это поле всё ещё не видел, а значит для перевода `SensorHitResult` в runtime fallback понадобятся reflection-backed named field reads
- из-за этого runtime target selector теперь считает `cached_pawn_order_target_controller` и другие order-target-controller roots первым fallback-tier до более широких blackboard- и selector-surfaces всякий раз, когда `ExecutingDecision` проваливается в `self` или `nil`
- runtime также теперь допускает более узкий method-backed retry по `GameObject` только тогда, когда field-backed target extraction не дал пригодного enemy character; это даёт `VisionMarker` живой path, не возвращая при этом полную зависимость всего hot path от `get_GameObject`
- `HitResultData.Obj` пока остаётся second-tier path: runtime `resolve_game_object(...)` теперь уже умеет reflection-backed named field reads, но `_SensorHitResult` стоит поднимать в primary fallback только после live combat-прогона, который докажет, что он реально даёт пригодных enemy characters, а не только дополнительный шум
- следующий `Job07` триплет (`2026-03-27 07:17:05`, `07:17:10`, `07:17:12`) показал уже другой target-mode, а не опроверг прошлый вывод про `_EnemyList`: `_EnemyList`, `_FrontTargetList` и `_InCameraTargetList` там были пустыми, зато `_SensorHitResult` вырос сразу до `49` элементов
- каждый первый `HitResultData` элемент в этом триплете всё равно показывал `Obj -> via.GameObject` в reflective field snapshots, а значит `_SensorHitResult` теперь уже подтверждён как sensor-side carrier объектов сцены, даже если CE extractor пока ещё не поднимал эти entries до выбранных enemy characters
- парный runtime-log для этого окна снова не был полноценным боевым циклом; он застрял в `special_output_state` с `Common/HumanTurn_Target_Talking`, поэтому этот триплет пока правильнее считать non-combat или transitional target-mode, а не окончательной опорой для fallback-дизайна атак
- поскольку по визуалу в игре недостаточно надёжно отличить “настоящий боевой stall” от `HumanTurn_Target_Talking`, runtime теперь сознательно возвращён к более method-enabled `via.GameObject` baseline, близкому к периоду до отключения; следующий screening правильнее сравнивать уже с этой базой, а не со строгой field-only фазой
- следующая post-rollback пара (`2026-03-27 07:27:29`, `07:27:34`) показала уже третий target-mode: все collection-поля `PawnOrderTargetController` снова оказались пустыми, а `ExecutingDecision` успел переключиться из `self` в `other` между двумя captures вообще без какой-либо помощи коллекций
- парный runtime-session для этого окна стал первым полезным method-enabled baseline после rollback и всё равно в основном упирался в `executing_decision_unresolved`; summary по target probes также показал `cached_pawn_order_target_controller_target_unresolved`, а значит в тот момент живой блокер был не в плохой identity внутри заполненной коллекции, а в полном отсутствии опубликованного target-state
- поскольку одной только позы в игре недостаточно, чтобы надёжно отличать настоящий боевой stall от `HumanTurn_Target_Talking` или других utility-like transitions, следующим grounded screening tool теперь становится `docs/ce_scripts/main_pawn_target_publication_burst.lua`, который сэмплирует `ExecutingDecision`, `selected_request`, `current_action`, `full_node` и коллекции `PawnOrderTargetController` во времени вместо заморозки одного кадра

### Архив удаленного research layer

Старый research layer удален из продуктового hot path.

Архивированные домены:

- orchestration: `app/module_specs.lua`, `app/runtime_driver.lua`, `core/module_system.lua`
- logging and traces: старый `core/log.lua`, session logs, discovery logs, guild trace logs
- research modules: `action_research`, `combat_research`, `loadout_research`, `pawn_ai_data_research`, `guild_flow_research`, `sigurd_observer`, `npc_spawn_prototype`, `talk_event_trace`
- progression probes: `game/progression/trace.lua`, `probe.lua`, `correlation.lua`
- synthetic и adapter layer
- runtime debug UI

Остаточная полезная ценность старых логов перед удалением:

- оставшиеся session logs от `2026-03-25` подтверждают, что `main_pawn Job07` мог дойти до правильного hybrid runtime surface (`main_pawn_job=7`, `main_pawn_weapon_job=7`) и все равно оставаться в common runtime output вроде `NormalLocomotion`, `DrawWeapon` и `Common/Common_MoveToHighFive.user`
- в одной записанной `Job07` session сохранялся живой current-job loadout `73,0,0,0`, но output все равно оставался generic/common; значит сбой не объяснялся полной пустотой видимого custom-skill state
- старые discovery/action-research hooks давали высокий hook volume, но низкий payload yield: даже при повторных `actinter_requests` можно было получать `decision_probe_hits=0`, `decision_snapshot_hits=0` и `decision_actionpack_snapshot_hits=0`
- этот исторический сигнал поддерживает текущее правило CE-first: старые логи стоит держать только как archived evidence, а не как diagnostic path по умолчанию

Правило возврата:

- возвращать только один конкретный механизм и только после того, как CE scripts докажут, что narrowed question нельзя решить без hooks

### Граница производительности и сети

Все еще действующие правила:

- предпочитать компактные summaries широким reflective scans
- избегать getter-heavy probing в продуктовом hot path
- держать core branch local-runtime-first
- не вносить online, rental и pawn-share logic в main implementation branch

### Архивный ручной Content Editor path

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

## Как сделать

### Как исследовать сейчас

Использовать CE Console scripts.

Стандартный цикл:

1. сформулировать один конкретный вопрос
2. выбрать один скрипт под этот вопрос
3. записать результат в файл
4. сравнить его с baseline или control actor
5. сначала обновить этот файл
6. обновить `ROADMAP.md` только если изменились приоритеты
7. обновить `CHANGELOG.md`, если изменились код или документация

### Как оценивать силу вывода

Вывод достаточно силен для этого файла только если:

- скрипт записал структурированный результат в файл
- результат воспроизводим
- формулировка прямо следует из записанных полей
- конфликтующие старые формулировки удалены или явно ослаблены

### Как решать, можно ли вернуть hooks

Не возвращаться к hooks по умолчанию.

Возврат допустим только если одновременно выполнены условия:

- вопрос уже сужен до одного runtime transition
- screen и burst CE scripts не ловят его
- без hooks нельзя доказать причину
- необходимость задокументирована до начала реализации
- product branch остается изолированным от широкого research logging

## Таксономия методов воздействия на REFramework / RE Engine
Этот раздел объединяет межмодовую таксономию методов, повторяющиеся паттерны и компактную карту по модам из отдельного исследования модов. Он дополняет проектные заметки в этом репозитории и намеренно размещён рядом со справочными разделами.

### Область охвата
Эта база знаний собрана из локальных файлов `temp_*.md` по одиннадцати модам и организована по способам воздействия на REFramework и RE Engine.

### Таксономия техник
#### 1. Runtime bootstrap и lifecycle callbacks
- Базовый паттерн: использовать `reframework/autorun/*.lua` как точку входа и вешать логику на lifecycle callbacks.
- Частые callbacks: `re.on_application_entry(...)`, `re.on_pre_application_entry(...)`, `re.on_frame(...)`, `re.on_draw_ui(...)`, `re.on_script_reset(...)`, `re.on_config_save(...)`.
- Сильные примеры: `NickCore`, `ScriptCore`, `Bestiary`, `Dullahan`, `Skill Maker`, `JobChanger`, `HiredPawnOverride`, `Nick's Devtools`.

#### 2. Method hooks и управление оригинальным вызовом
- Базовый паттерн: перехватывать managed/native методы через `sdk.hook(...)`.
- Основные варианты воздействия:
  - менять аргументы в pre-hook
  - подменять return value в post-hook
  - отменять оригинальную логику через `sdk.PreHookResult.SKIP_ORIGINAL`
  - переносить состояние между стадиями через `thread.get_hook_storage()`
- Сильные примеры:
  - `NickCore` как обобщённая hook-шина
  - `SkillUnlocker` и `Pawns Use All Skills` как минимальные bypass-патчи
  - `Bestiary`, `Dullahan`, `Skill Maker`, `Nick's Devtools` как широкие gameplay interception-моды

#### 3. Shared abstraction cores
- Базовый паттерн: выносить хрупкую SDK/hook-логику в переиспользуемые utility-слои.
- `NickCore` даёт:
  - hook buses в `fns.on_*`
  - кэш состояния игрока
  - startup/readiness checks
  - install markers
  - timers
- `ScriptCore` даёт:
  - hotkeys
  - ImGui helpers и themes
  - reflection/object helpers
  - cloning и запись value types
  - file picker
  - physics casts
  - dynamic motion-bank helpers

#### 4. Прямая мутация live objects и backing fields
- Базовый паттерн: редактировать живые engine-объекты напрямую, а не только через hooks.
- Типичные цели:
  - `DamageInfo`
  - `AttackUserData`
  - `PawnDataContext`
  - данные экипировки и storage
  - motion layers
  - shell request structures
  - generate/prefab structures
- Сильные примеры:
  - `HiredPawnOverride` меняет экипировку, personality, specialization и voice
  - `Bestiary` и `Dullahan` меняют damage/status/shell state
  - `Skill Maker` меняет motion, VFX, target, speed, corpse и relationship state

#### 5. UI и tooling injection
- Базовый паттерн: встраивать in-game editors, debug panels, tracers и control surfaces через `imgui`.
- Типовые применения:
  - конфиг-меню
  - редактирование hotkeys
  - search/filter UI
  - live authoring tools
  - tracing toggles
  - devtool panels
- Сильные примеры:
  - editor в `Skill Maker`
  - `JobChanger`
  - `HiredPawnOverride`
  - `Nick's Devtools`
  - config и UI patching в `Dullahan`

#### 6. Input и HID capture
- Базовый паттерн: опрашивать keyboard/mouse/gamepad и перенаправлять или подавлять ввод.
- Ключевые точки входа:
  - `via.hid.Keyboard`
  - `via.hid.Gamepad`
  - `via.hid.Mouse`
  - `re.on_application_entry("UpdateHID", ...)`
  - методы player input processor
- Сильные примеры:
  - hotkey-система `ScriptCore`
  - использование hotkeys в `JobChanger`
  - input remapping в `Skill Maker`
  - input suppression в position/flight-инструментах `Nick's Devtools`

#### 7. Runtime spawning и resource injection
- Shells и projectiles:
  - `app.ShellManager.requestCreateShell(...)`
  - `app.Shell.checkFinish()`
  - `sdk.create_userdata("app.ShellParamData", path)`
- Enemies и prefabs:
  - `app.GenerateManager.requestCreateInstance(...)`
  - `sdk.create_instance("app.GenerateInfo.GenerateInfoContainer")`
  - `sdk.create_instance("via.Prefab")`
  - `sdk.create_instance("app.PrefabController")`
  - `sdk.create_instance("app.InstanceInfo")`
- Effects и sound:
  - `via.effect.script.ObjectEffectManager2.requestEffect(...)`
  - Wwise trigger surfaces
- Motion resources:
  - `via.motion.DynamicMotionBank`
  - `via.motion.MotionListResource`
- Сильные примеры:
  - `Bestiary`
  - `Dullahan`
  - `Skill Maker`
  - `Nick's Devtools`
  - `ScriptCore` как инфраструктура

#### 8. Combat, damage, status и shell pipelines
- Частые hook surfaces:
  - `app.HitController.damageProc(...)`
  - `app.HitController.calcDamageValue(...)`
  - `app.ExceptPlayerDamageCalculator.calcDamageValueDefence(...)`
  - `app.HitController.calcRegionDamageRate(...)`
  - `app.HitController.calcDamageReaction(...)`
  - `app.StatusConditionCtrl.reqStatusConditionApplyCore(...)`
  - `app.StatusConditionInfo.applyStatusConditionDamage(...)`
- Типовые вмешательства:
  - менять raw damage
  - патчить reaction type или stagger
  - менять поведение shell
  - переписывать status application
  - обходить stamina costs
- Сильные примеры:
  - `NickCore`
  - `Bestiary`
  - `Dullahan`
  - `Skill Maker`
  - `Nick's Devtools`

#### 9. AI, action, relationship и target control
- Частые точки входа:
  - `app.ActionManager.requestActionCore(...)`
  - `app.AIBlackBoardExtensions.setBBValuesToExecuteActInter(...)`
  - `app.BattleRelationshipHolder.getRelationshipFromTo(...)`
  - `app.TargetController.setTarget(...)`
  - методы monster action selector
- Типовые применения:
  - форсировать выбор action/skill
  - переписывать поведение summon
  - менять faction/ally/enemy relations
  - перенаправлять target logic
  - внедрять AI behavior packs
- Сильные примеры:
  - `NickCore`
  - `Bestiary`
  - `Dullahan`
  - `Skill Maker`
  - `Nick's Devtools`

#### 10. Data-driven execution и persistence
- Базовый паттерн: держать runtime-логику универсальной, а authored content выносить в JSON или Lua-таблицы.
- Частые инструменты:
  - `json.load_file(...)`
  - `json.dump_file(...)`
  - `fs.glob(...)`
- Сильные примеры:
  - node graphs и каталоги контента в `Skill Maker`
  - каталог предметов и per-pawn config в `HiredPawnOverride`
  - hotkey-конфиг в `JobChanger`
  - persistence hotkeys в `ScriptCore`
  - config toggles в `Dullahan`

#### 11. Статическая замена RE Engine assets
- Базовый паттерн: заменять сериализованные RE Engine assets вместо runtime-скриптов.
- Зафиксированная форма:
  - `KPKA` `.pak`
  - заменённые `.user.2` generation tables
- Сильный пример:
  - `Durnehviir`

### Конкретные точки входа
- Основные managers и singletons:
  - `app.CharacterManager`, `app.PawnManager`, `app.ItemManager`, `app.GuiManager`, `app.ShellManager`, `app.GenerateManager`, `app.BattleManager`, `app.BattleRelationshipHolder`, `app.QuestManager`, `app.WeatherManager`, `app.EnemyManager`, `via.SceneManager`, `via.Application`, `via.physics.System`
- Высокоценные методы:
  - `app.ActionManager.requestActionCore(...)`
  - `app.ShellManager.requestCreateShell(...)`
  - `app.GenerateManager.requestCreateInstance(...)`
  - `app.HitController.calcDamageValue(...)`
  - `app.HitController.calcDamageReaction(...)`
  - `app.StatusConditionCtrl.reqStatusConditionApplyCore(...)`
  - `app.AIBlackBoardExtensions.setBBValuesToExecuteActInter(...)`
  - `app.BattleRelationshipHolder.getRelationshipFromTo(...)`
  - `app.GuiManager.OnChangeSceneType`
  - `app.HumanSkillAvailability.*`
  - `app.HumanSkillContext.*`

### Повторяющиеся паттерны
- Один shared core владеет hooks, а feature-моды подписываются на него.
- Per-frame caches используются для нестабильных или поздно появляющихся объектов.
- Таблицы, индексированные по request ID или address, используются для shell/enemy/pawn tracking.
- Повторное использование штатных `.user` resources предпочтительнее, чем полное создание контента с нуля.
- Маленькие моды часто решают задачу через 1-7 validation hooks.
- Большие моды сочетают hook-логику с in-game tooling и JSON persistence.

### Переиспользуемые реализации
- Event bus из `NickCore` для композиции нескольких модов.
- Hotkeys, file picker, reflection, clone, physics и ImGui helpers из `ScriptCore`.
- Spawn pipelines для shells и prefabs.
- Boolean и numeric validator bypass через принудительную подмену return value.
- Apply-until-success per-frame mutation для transient actors.
- Форсирование действий через `requestActionCore(...)`.
- Внедрение AI packs через `app.ActInterPackData`.
- Статическая `.pak`-замена для детерминированных data edits.

### Краткая привязка по модам
- `NickCore`: низкоуровневая hook-шина, startup gate, timers, player cache.
- `ScriptCore`: общие hotkeys, reflection, ImGui/file tools, physics, motion-bank helpers.
- `Bestiary`: overhaul enemy AI и movesets, shell/effect spawning, variants, Dragonsplague/Silence rewrites.
- `Dullahan`: modular vocation overhaul с shell-driven skills и UI patching.
- `Durnehviir`: `.pak`-замена encounter tables.
- `Skill Maker`: data-driven skill editor/runtime с shells, summons, AI packs и motion/VFX control.
- `SkillUnlocker`: набор validation bypass hooks для skills.
- `HiredPawnOverride`: per-frame мутация экипировки и атрибутов hired pawns.
- `JobChanger`: utility для смены vocation с hotkeys и auto-equip.
- `Nick's Devtools`: tracing, spawning, shell/effect/audio testing, combat и world-state tools.
- `Pawns Use All Skills`: ультра-минимальный bypass доступности pawn skills.

## Справка

### Активные CE scripts

- `docs/ce_scripts/job07_runtime_resolution_screen.lua`
Что делает:
one-shot screen по runtime-resolution для `main_pawn Job07`
Как можно использовать:
быстро проверить, живы ли корневые roots, job controller и action surfaces до написания более тяжелого extractor

- `docs/ce_scripts/job07_burst_combat_trace.lua`
Что делает:
ранний timed combat trace для `Job07`
Как можно использовать:
грубый контрольный trace, когда нужно понять, происходит ли вообще хоть что-то похожее на бой

- `docs/ce_scripts/actor_burst_combat_trace.lua`
Что делает:
универсальная burst-trace family для акторов
Как можно использовать:
сравнивать актеров и сцены без жесткой привязки к одной профессии

- `docs/ce_scripts/job07_selector_admission_compare_screen.lua`
Что делает:
сравнивает selector/admission surfaces между `main_pawn Job07` и Sigurd `Job07`
Как можно использовать:
заземлять различия pawn-vs-NPC до правок runtime-логики

- `docs/ce_scripts/job07_decision_pipeline_compare_screen.lua`
Что делает:
сравнивает primary AI pipeline family между актерами
Как можно использовать:
решать, переносим ли вообще NPC-path на pawn по архитектуре

- `docs/ce_scripts/main_pawn_decision_list_screen.lua`
Что делает:
считает и дампит entries decision list
Как можно использовать:
инвентаризация decision pool и сравнение плотности популяции между состояниями

- `docs/ce_scripts/main_pawn_main_decision_profile_screen.lua`
Что делает:
профилирует `MainDecisions` по pack identity
Как можно использовать:
разводить attack-heavy и utility-heavy decision populations

- `docs/ce_scripts/main_pawn_main_decision_semantic_screen.lua`
Что делает:
дампит semantic fields у `app.AIDecision`
Как можно использовать:
смотреть preconditions, target policy, criteria, tags и metadata решения

- `docs/ce_scripts/main_pawn_target_surface_screen.lua`
Что делает:
one-shot extractor target surfaces
Как можно использовать:
сравнивать target-bearing roots, entries коллекций и field-vs-method пути в одном кадре

- `docs/ce_scripts/main_pawn_target_publication_burst.lua`
Что делает:
timed burst по target, output, requests, actions, FSM nodes и `MainDecisions`
Как можно использовать:
лучший единый CE script, чтобы разводить провал target-publication, utility masking и decision-population gap во времени

- `docs/ce_scripts/main_pawn_output_bridge_burst.lua`
Что делает:
timed burst, который связывает population решений с action/output surfaces
Как можно использовать:
доказывать, что у актора есть attack-populated decisions, но он все равно не выдает боевой output

- `docs/ce_scripts/vocation_definition_surface_screen.lua`
Что делает:
достает vocation-definition surfaces и runtime job metadata
Как можно использовать:
заземлять enum values, vocation descriptors и job-definition references без продуктовых probes

- `docs/ce_scripts/vocation_progression_matrix_screen.lua`
Что делает:
достает progression surfaces и custom-skill matrix
Как можно использовать:
заземлять job-level progression, custom-skill IDs и bands навыков для любой профессии

### Обязательные свойства CE script

Каждый CE script должен:

- решать одну конкретную задачу
- писать результат в файл
- выдавать данные, пригодные для compare и дальнейшего обновления документации

### Текущие implementation files

- `mod/reframework/autorun/PawnHybridVocationsAI/bootstrap.lua`
Что делает:
верхнеуровневый entrypoint продукта и wiring scheduler
Как можно использовать:
понимать, что у нас тикает каждый кадр, что идет по интервалу и где вообще начинается product runtime

- `mod/reframework/autorun/PawnHybridVocationsAI/config.lua`
Что делает:
хранит tuning продукта, refresh intervals и log throttles
Как можно использовать:
менять cadence и verbosity без правки боевой логики напрямую

- `mod/reframework/autorun/PawnHybridVocationsAI/core/runtime.lua`
Что делает:
объединяет runtime state, guarded execution и interval scheduling
Как можно использовать:
кэшировать actor references, snapshots и timestamps задач без разнесения runtime orchestration по нескольким мелким файлам

- `mod/reframework/autorun/PawnHybridVocationsAI/core/log.lua`
Что делает:
пишет session-log и крутит ротацию файлов
Как можно использовать:
держать ограниченную диагностику в продуктоподобном runtime без бесконечного роста папки логов

- `mod/reframework/autorun/PawnHybridVocationsAI/core/access.lua`
Что делает:
объединяет engine-access, reflection, runtime-surface и skill/job helper-логику
Как можно использовать:
централизовать рискованные engine calls, reflected fallback, pack/node lookup, collection access и общие skill-state reader'ы, чтобы gameplay-модули не тащили параллельные helper-реализации

- `mod/reframework/autorun/PawnHybridVocationsAI/core/execution_contracts.lua`
Что делает:
нормализует `execution_contract` и `bridge_mode`
Как можно использовать:
держать selector data, combat profiles и bridge logic на одной общей классификации

- `mod/reframework/autorun/PawnHybridVocationsAI/data/vocations.lua`
Что делает:
канонический vocation registry для skill IDs, vocation bands, hybrid metadata и progression hints
Как можно использовать:
заземлять skill names, IDs, action prefixes, controller metadata и hybrid-job lookup без россыпи литеральных чисел и дублирующихся vocation-таблиц по runtime-коду

- `mod/reframework/autorun/PawnHybridVocationsAI/data/hybrid_combat_profiles.lua`
Что делает:
хранит phase-selection data для hybrid combat behavior
Как можно использовать:
описывать priorities, skill requirements, range hints и execution contracts данными, а не жесткими ветками

- `mod/reframework/autorun/PawnHybridVocationsAI/game/main_pawn_properties.lua`
Что делает:
резолвит и обновляет `main_pawn`, `player` и их минимальный live runtime context
Как можно использовать:
служить actor-resolution слоем для любой pawn-focused runtime-системы

- `mod/reframework/autorun/PawnHybridVocationsAI/game/progression/state.lua`
Что делает:
строит кэш progression snapshots, per-job level state и lifecycle state навыков
Как можно использовать:
вынести progression и skill-state checks из combat hot path

- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_unlock.lua`
Что делает:
восстанавливает hybrid unlock state у `main_pawn`
Как можно использовать:
зеркалить progression или qualification state, не смешивая unlock path с боевой логикой

- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua`
Что делает:
содержит runtime combat bridge, target resolution, phase selection и execution
Как можно использовать:
это главный продуктовый runtime для превращения кэшированного progression state и live combat surfaces в реальное поведение

### Исторические native decision-pool signals

Ранний native-first branch многократно использовал эти containers как безопасные структурные сигналы:

- `_CurrentGoalList`
- `_CurrentAddDecisionList`
- `MainDecisions`
- `PreDecisions`
- `PostDecisions`
- `ActiveDecisionPacks`

Они остаются полезной исторической справкой, даже если текущий путь исследования теперь CE-first.

### Дополнение 2026-03-26: hybrid custom-skill matrix

Это короткое дополнение фиксирует выводы из `vocation_progression_matrix_20260326_214421.json`, которые полезны даже вне текущей задачи.

- Полная подтверждённая hybrid `custom-skill` matrix сейчас выглядит так:
- Полная подтверждённая all-job `custom-skill` bands сейчас выглядят так:
- `Job01 = 1..12`, `Job02 = 13..23`, `Job03 = 24..37`, `Job04 = 38..49`, `Job05 = 50..61`, `Job06 = 62..69`, `Job07 = 70..79`, `Job08 = 80..91`, `Job09 = 92..99`, `Job10 = 100`
- `Job07`: `70 = PsychoShoot`, `71 = FarThrow`, `72 = EnergyDrain`, `73 = DragonStinger`, `74 = QuickShield`, `75 = BladeShoot`, `76 = SkyDive`, `77 = Gungnir`, `78 = TwoSeconds`, `79 = DanceOfDeath`
- `Job08`: `80 = FlameLance`, `81 = BurningLight`, `82 = FrostTrace`, `83 = FrostBlock`, `84 = ThunderChain`, `85 = ReflectThunder`, `86 = AbsorbArrow`, `87 = LifeReturn`, `88 = CounterArrow`, `89 = SleepArrow`, `90 = SeriesArrow`, `91 = SpiritArrow`
- `Job09`: `92 = SmokeWall`, `93 = SmokeGround`, `94 = TripFregrance`, `95 = AttentionFregrance`, `96 = PossessionSmoke`, `97 = RageFregrance`, `98 = DetectFregrance`, `99 = SmokeDragon`
- `Job10`: `100 = Job10_00`
- Canonical data-layer для этой матрицы теперь лежит в `mod/reframework/autorun/PawnHybridVocationsAI/data/vocations.lua`
- Для `Job07` первым live-grounded custom skill теперь надо считать `DragonStinger = 73`: он подтверждён в enum, в `Job07Parameter`, и в live equip/enabled state у `player` и `main_pawn`
- Для `Job08` аналогичным первым live-grounded custom skill сейчас является `FrostTrace = 82`
- `current_job_level` и per-job `getJobLevel(...)` по-прежнему могут оставаться `nil`, поэтому жёстко гейтить базовые атаки по этому сигналу нельзя
- `AbilityParam.JobAbilityParameters` нужно читать с приоритетом `job_id - 1`, иначе hybrid augment layer сдвигается на одну профессию

### Контракты исполнения и unsafe skill probes

Теперь runtime bridge должен знать не только `skill id`, но и контракт исполнения каждого навыка.

- `skill id` отвечает на вопрос, что это за навык
- `execution contract` отвечает на вопрос, как его можно безопасно запускать
- рабочие категории сейчас выглядят так:
- `direct_safe`
- `carrier_required`
- `controller_stateful`
- `selector_owned`
- каноническая all-job матрица теперь хранит `execution_contract` placeholder для каждого custom skill от `Job01` до `Job10`
- этот placeholder специально консервативный: пока CE или runtime не заземлят навык, он остаётся в данных как `selector_owned`
- `Job07` теперь стал первым профилем, где контракты уже явно живут в коде, а не только в документации:
- базовые direct action вроде `Job07_ShortRangeAttack` моделируются как `direct_safe`
- carrier-backed core-фазы вроде `MagicBindLeap` и `SpiralSlash` моделируются как `carrier_required`
- `DragonStinger` моделируется как `controller_stateful` и остаётся в probe-режиме, пока не станет понятен нужный ему native context
- runtime bridge теперь резолвит класс контракта и `bridge_mode` из данных фазы, а не опирается только на россыпь специальных флагов вроде `unsafe_direct_action`
- session-логи теперь пишут `contract` и `bridge_mode` у применённых и упавших фаз, чтобы результаты probe можно было быстрее переводить обратно в обычные runtime-правила
- нормализация контрактов теперь живёт в отдельном shared runtime-модуле, так что matrix, profile builder и bridge больше не держат три разные частичные версии одной и той же логики
- probe-snapshot теперь тоже контрактно-управляемый: stateful skills могут объявлять `controller_state_fields`, а runtime пишет именно эти поля из соответствующего `JobXXActionCtrl` вместо жёстко прошитого `Job07`-только пути
- `DragonStinger` стал первым подтверждённым доказательством, что это различие реально важно:
- прямой `requestActionCore("Job07_DragonStinger")` смог довести `main_pawn` до видимой `Job07_*` анимации
- но затем игра упала внутри `app.Job07DragonStinger.update`
- CE surface при этом показывает отдельный `Job07ActionCtrl` state именно для этого навыка: `DragonStingerVec`, `DragonStingerSpeed` и `DragonStingerHit`
- значит `DragonStinger` нельзя считать “обычным direct action skill” только потому, что он один раз стартовал
- текущий runtime теперь ведёт его как probe-gated unsafe-skill path, а не как окончательно решённый direct-action путь
- текущие probe-режимы такие:
- `off`
- `action_only`
- `carrier_only`
- `carrier_then_action`
- probe-логи теперь снимают текущий output и состояние `Job07ActionCtrl` до попытки unsafe skill
- этот же шаблон дальше надо расширять с `Job07` на всю vocation matrix, включая исходные профессии, чтобы мод классифицировал навыки по execution contract, а не только по имени action
- выбор фаз теперь system-first, а не skill-first:
- raw `priority` каждого навыка сохраняется
- но больше не является единственным селектором
- итоговый phase score теперь учитывает роль фазы, дистанцию, safe fallback при assumed job level, повторы и недавний skill streak
- это нужно, чтобы пешка не спамила навык с самым высоким приоритетом и выглядела нативно за счёт обычных атак, engage-мувов, gap-close и уже потом skill follow-up

### Архивный snapshot перед очисткой логов

Этот раздел теперь считается основной опорной точкой перед удалением старых логов и JSON.

- `PawnHybridVocationsAI.session_*.log`
Откуда:
runtime file logs за `2026-03-26` и `2026-03-27`
Что делает:
фиксирует skip reasons, applied phases, target-probe summaries и bridge results
Как можно использовать:
разбирать runtime-регрессии и сравнивать сессии между собой

- `main_pawn_output_bridge_burst_*.json`
Откуда:
`docs/ce_scripts/main_pawn_output_bridge_burst.lua`
Что делает:
связывает population `MainDecisions` с `decision_pack_path`, `SelectedRequest`, `CurrentAction` и FSM output
Как можно использовать:
отделять пустой decision pool от attack-populated decision pool, который всё равно выдаёт utility output

- `main_pawn_target_publication_burst_*.json`
Откуда:
`docs/ce_scripts/main_pawn_target_publication_burst.lua`
Что делает:
показывает target publication во времени через `ExecutingDecision`, collections `PawnOrderTargetController`, requests, actions и FSM nodes
Как можно использовать:
разводить настоящий combat stall и talking или utility transition

- `main_pawn_target_surface_*.json`
Откуда:
`docs/ce_scripts/main_pawn_target_surface_screen.lua`
Что делает:
one-shot snapshot target roots и order-target collections
Как можно использовать:
смотреть root-level surfaces, collection entries и field-vs-method paths

- `job07_selector_admission_compare_*.json`
Что делает:
сравнивает `main_pawn Job07` и Sigurd `Job07` на selector или admission layer
Как можно использовать:
доказывать pawn-vs-NPC differences до правок runtime

- `job07_decision_pipeline_compare_*.json`
Что делает:
сравнивает primary AI module types между акторами
Как можно использовать:
понимать, переносим ли NPC path на pawn вообще по архитектуре

- `main_pawn_decision_list_screen_*.json`, `main_pawn_main_decision_profile_*.json`, `main_pawn_main_decision_semantic_screen_*.json`
Что делают:
дают count, profile и semantic view по `MainDecisions`
Как можно использовать:
инвентаризация и interpretation decision pool

### Агрегированные выводы из архива

- На текущем архивном наборе причины в session-log распределяются так:
- `main_pawn_data_unresolved = 135`
- `main_pawn_not_hybrid_job = 113`
- `invalid_target_identity = 33`
- `special_output_state = 25`
- `executing_decision_unresolved = 13`
- `decision_target_character_unresolved = 6`

- Архив уже доказывает, что bridge реально входил в боевые `Job07` фазы:
- `skill_blade_shoot_mid_far = 2`
- `core_bind_close = 2`
- `skill_dragon_stinger_mid = 2`
- `core_bind_mid = 1`
- `core_gapclose_far = 1`
- `core_short_attack_mid = 1`
- `core_short_attack_close = 1`

- Архивные block patterns показывают, что часть старых сбоев была вызвана не отсутствием навыков, а runtime heuristics:
- `job_level_above_assumed_minimum = 7`
- `skill_not_equipped = 5`
- `unsafe_probe_disabled = 1`

- `special_output_state` — это не только talking.
В архиве под этот reason попадали:
- `Common/HumanTurn_Target_Talking.user`
- `Common/Pawn_SortItem.user`
- `Common/Interact_Gimmick_TreasureBox.user`
- `Common/Common_WinBattle_Well_02.user`

- `executing_decision_unresolved` — это не один плохой getter.
Архивные target-probe summaries показывают, что в такие окна одновременно разваливались `ExecutingDecision`, `AIBlackBoardController`, `AIMetaController`, `HumanActionSelector`, `SelectedRequest`, `CurrentAction`, `Job07ActionCtrl` и `PawnOrderTargetController`.

- Output bridge bursts уже зафиксировали контрольную разницу:
- `main_pawn_output_bridge_burst_job01_main_pawn_output_auto_20260326_185648.json` дал `attack_populated = 24` и в основном `job_specific_output_candidate = 22`
- `main_pawn_output_bridge_burst_job07_main_pawn_output_auto_20260326_190100.json` дал `attack_populated = 24`, но при этом `common_utility_output = 24`

- Target publication bursts уже зафиксировали и healthy control для `Job01`, и несколько разных `Job07` publication modes:
- `...075607` показал `executing_decision_other = 28` и реальные `Job01_*` combat nodes
- `...075916` показал `front_target_list_other = 27`, но output остался locomotion
- `...075943` показал смесь `executing_decision_other` и `enemy_list_other` при output в locomotion и `Damage.DmgShrink*`
- `...082519` показал live enemy target во время `Damage.DmgShrinkL/M`

- Target surface screens уже доказали как минимум четыре `Job07` target mode:
- mixed collections
- stable `_EnemyList` mode
- sensor-heavy `_SensorHitResult` mode
- empty-collection mode

- `job07_selector_admission_compare_*.json` зафиксировали stall до полноценного `Job07` pack selection.

- `job07_decision_pipeline_compare_*.json` зафиксировали структурное расхождение:
- `main_pawn = app.DecisionEvaluationModule`
- `sigurd = app.ThinkTableModule`

### Каталог grounded surfaces

- `app.JobContext:getJobLevel(job_id)`
Откуда:
progression runtime, progression research и example tooling
Что делает:
читает per-job level актора
Как можно использовать:
unlock gating, progression snapshots, UI parity
Важно:
`assumed_minimum_job_level` не является proof реального уровня

- `getCustomSkillLevel(skill_id)`
Откуда:
example skill tooling и текущий lifecycle cache
Что делает:
читает, изучен ли custom skill
Как можно использовать:
разводить `unlockable` и `learned`

- `hasEquipedSkill(job_id, skill_id)`
Откуда:
runtime gate и example mods
Что делает:
проверяет, экипирован ли skill
Как можно использовать:
не давать selector’у выбирать неслотнутые навыки

- `isCustomSkillEnable(skill_id)`
Откуда:
runtime gate и example mods
Что делает:
проверяет, разрешён ли skill текущим skill context
Как можно использовать:
runtime legality check после ownership и equip

- `isCustomSkillAvailable(skill_id)`
Откуда:
example mods, lifecycle research, runtime probes
Что делает:
проверяет, можно ли skill использовать прямо сейчас
Как можно использовать:
context-sensitive `combat_ready` gate
Важно:
это более volatile слой, чем `learned`, `equipped` и `enabled`

- `current_job_skill_lifecycle`
Откуда:
текущий progression cache
Что делает:
кэширует `potential -> unlockable -> learned -> equipped -> combat_ready`
Как можно использовать:
выносить skill-state проверки из combat hot path

- `app.DecisionExecutor.ExecutingDecision`
Откуда:
runtime target probes, publication bursts, target surfaces
Что делает:
surface текущего executing decision и часто его target или action pack
Как можно использовать:
дешёвый first-pass target publication check

- `app.DecisionEvaluationModule.MainDecisions`
Откуда:
decision-list/profile/semantic screens и output bursts
Что делает:
surface основного AI decision pool
Как можно использовать:
мерить attack-vs-utility population и вытаскивать pack identities

- `app.ActionManager.SelectedRequest`
Откуда:
runtime probes и CE bursts
Что делает:
surface action/request, который action manager хочет следующим
Как можно использовать:
сравнивать request intent с `CurrentAction`

- `app.ActionManager.CurrentAction`
Откуда:
runtime probes и CE bursts
Что делает:
surface action/request, активный сейчас
Как можно использовать:
классифицировать текущий output mode

- `Fsm.getCurrentNodeName(layer)`
Откуда:
CE bursts и session-log interpretation
Что делает:
читает имена FSM nodes по слоям
Как можно использовать:
разводить locomotion, damage, utility и job-specific combat output

- `app.Character:get_AIBlackBoardController()`
Откуда:
runtime target probes и target-surface screens
Что делает:
даёт корневой доступ к AI blackboard surfaces
Как можно использовать:
смотреть AI targets, order/update controllers и action-interface staging

- `app.Character:get_LockOnCtrl()`
Откуда:
target-surface screens и runtime target probes
Что делает:
surface состояния lock-on target
Как можно использовать:
secondary target source или reseat candidate

- `app.AIMetaController.<CachedPawnOrderTargetController>`
Откуда:
target-surface screens, publication bursts и runtime target probes
Что делает:
даёт доступ к pawn order-target collections
Как можно использовать:
брать fallback enemy/front/camera/sensor targets без recursive scans

- `app.PawnOrderTargetController._EnemyList`
Откуда:
target-surface wave `065555` – `065815` и later bursts
Что делает:
enemy-target collection
Как можно использовать:
primary grounded fallback root

- `app.PawnOrderTargetController._FrontTargetList`
Откуда:
target-surface captures и burst `075916`
Что делает:
front-priority target collection
Как можно использовать:
secondary fallback root

- `app.PawnOrderTargetController._InCameraTargetList`
Откуда:
target-surface captures
Что делает:
camera-visible target collection
Как можно использовать:
camera-filtered target publication

- `app.PawnOrderTargetController._SensorHitResult`
Откуда:
sensor-heavy target-surface captures
Что делает:
sensor-side container hit results и scene objects
Как можно использовать:
tertiary или emergency target/object carrier

- `app.PawnManager._MainPawn` и `app.PawnManager.get_MainPawn()`
Откуда:
`DD2_Scraper/_meta_app_PawnManager.json`
Что делает:
заземлённый primary singleton surface для получения настоящего объекта main pawn
Как можно использовать:
использовать как первый root для `main_pawn`, а `CharacterManager` оставлять fallback-helper слоем

- `app.PawnManager.get_PawnOrderTargetController()`
Откуда:
`DD2_Scraper/_meta_app_PawnManager.json`
Что делает:
даёт grounded getter для pawn order-target controller на том же singleton, где живёт `_MainPawn`
Как можно использовать:
предпочитать при проверке target-publication surfaces внутри реального pipeline главной пешки

- `HitResultData.Obj`
Откуда:
reflective field snapshots в sensor-heavy captures
Что делает:
достаёт `via.GameObject` из hit-result entry
Как можно использовать:
reflection-backed object extraction

- `app.AITargetGameObject`
Откуда:
current bridge и example mod `AdditionalPawnCommands`
Что делает:
упаковывает target в AI/ActInter-compatible carrier
Как можно использовать:
blackboard target injection и carrier-backed action requests

- `app.AITargetGeneralPoint`
Откуда:
`usercontent/rsz/dd2.json` и `usercontent/cache/typecache.json`
Что делает:
нативный target-shape для general scene points и non-character targeting
Как можно использовать:
считать полноценным `AITarget*` root в runtime normalization, а не предполагать, что валиден только `app.AITargetGameObject`

- `app.AITargetPosition`
Откуда:
`usercontent/rsz/dd2.json`, `usercontent/cache/typecache.json` и CE target dumps
Что делает:
нативный target-shape для position-oriented AI requests
Как можно использовать:
сильный сигнал, что actor идёт к точке, а не прямо таргетит персонажа; полезно для support/recovery и move-to-position guard

- `app.Human.<Job07ActionCtrl>k__BackingField` и `app.Human.get_Job07ActionCtrl()`
Откуда:
`DD2_Scraper/_meta_app_Human.json`
Что делает:
заземлённый `Job07`-specific action-controller surface на `app.Human`
Как можно использовать:
безопасная job-specific foothold для исследования `main_pawn Job07` без выдумывания custom skill-side state

- `app.decision.condition.IsEnterTimingNonMaxMainPawnHP`
Откуда:
`usercontent/rsz/dd2.json`
Что делает:
нативный decision-condition type, который показывает, что low-HP timing у main pawn реально существует на engine-side
Как можно использовать:
заземлять low-HP retreat/support heuristics в native decision architecture, а не считать их модовой догадкой

- `app.HumanEnemyParameterBase.NPCCombatParamTemplate`
Откуда:
`usercontent/enums/app.HumanEnemyParameterBase.NPCCombatParamTemplate.json`
Что делает:
enum surface для нативных NPC combat templates, включая `Job07`, `Job07_6`, `Job07_7` и `Job07_Master`
Как можно использовать:
использовать как reference для Sigurd-like и NPC-like combat archetypes, не предполагая общий decision pipeline с main pawn

- `app.MainPawnDataContext`
Откуда:
`usercontent/rsz/dd2.json`
Что делает:
schema-level main-pawn context type с favorability и persistent pawn-side data
Как можно использовать:
заземлять future progression и pawn-context research в реальном engine type, а не в ad-hoc naming

- `set_ReqMainActInterPackData(app.ActInterPackData)`
Откуда:
current bridge и example carrier patterns
Что делает:
запрашивает main action-interface pack
Как можно использовать:
carrier-backed action execution

- `special_output_state`
Откуда:
archived session logs и runtime skip telemetry
Что делает:
skip reason для interaction, talking и utility-special output
Как можно использовать:
не запускать combat bridge во время non-combat states

- `executing_decision_unresolved`
Откуда:
archived session logs, runtime target-probe summaries и publication research
Что делает:
skip reason для провала target publication по executing decision
Как можно использовать:
маркер, что пора идти во внешний CE screening, а не расширять hot-path probes

- `app.DecisionEvaluationModule` против `app.ThinkTableModule`
Откуда:
`job07_decision_pipeline_compare_*.json`
Что делает:
показывает, к какой AI pipeline family относится actor
Как можно использовать:
решать, переносим ли NPC research path на pawn

### Каталог engine data, skill-state и execution surfaces

- `app.HumanCustomSkillID`
Откуда:
enum inspection, research по progression matrix и example skill tooling
Что делает:
каноническая enum-family для human custom-skill identifiers
Как можно использовать:
маппить числовые custom-skill IDs обратно в стабильные символические имена

- `AbilityParam.JobAbilityParameters`
Откуда:
research по progression matrix и архивная инспекция augment-layer
Что делает:
container для per-job ability и augment parameter blocks
Как можно использовать:
исследовать augment layers и job-indexed ability data
Что важно:
архив заземляет доступ как `job_id - 1`, а не raw `job_id`

- `Job07Parameter`
Откуда:
research по progression и custom-skill matrix
Что делает:
job-specific parameter block для профессии `Job07`
Как можно использовать:
проверять, что custom skill, parameter slot или skill band реально существуют в engine data до правок runtime

- `NormalAttackParam`
Откуда:
semantic research по `MainDecisions` и архивные CE semantic captures
Что делает:
parameter surface для baseline attack behavior
Как можно использовать:
сравнивать поведение обычной атаки с custom-skill и job-specific attack layers

- `SetAttackRange`
Откуда:
semantic research и архивные combat compare data
Что делает:
criterion или process token, связанный с управлением дистанцией атаки
Как можно использовать:
проверять, осталась ли в decision pool более богатая combat range-management логика

- `SkillContext`
Откуда:
runtime skill gates, дизайн lifecycle-cache и архивные skill-state probes
Что делает:
engine-side context, который отвечает на вопросы ownership, enablement и родственные skill-state вопросы
Как можно использовать:
разводить learned/equipped state и более широкий runtime legality layer

- `getCustomSkillLevel(skill_id)`
Откуда:
example skill tooling и текущий lifecycle cache
Что делает:
читает, реально ли custom skill изучен
Как можно использовать:
разводить `unlockable` и `learned`

- `hasEquipedSkill(job_id, skill_id)`
Откуда:
текущий runtime gate и example mods
Что делает:
проверяет, стоит ли skill в слотах
Как можно использовать:
не давать selector’у выбирать неэкипированные навыки

- `isCustomSkillEnable(skill_id)`
Откуда:
текущий runtime gate и example mods
Что делает:
проверяет, разрешен ли skill текущим skill context
Как можно использовать:
runtime legality check после ownership и equip gates

- `isCustomSkillAvailable(skill_id)`
Откуда:
example mods, lifecycle research и runtime probes
Что делает:
проверяет, можно ли skill использовать прямо сейчас в текущих игровых условиях
Как можно использовать:
volatile `combat_ready` gate для context-sensitive skills
Что важно:
это более volatile сигнал, чем `learned`, `equipped` и `enabled`

- `current_job_skill_lifecycle`
Откуда:
текущий progression cache
Что делает:
кэширует staged skill state `potential -> unlockable -> learned -> equipped -> combat_ready`
Как можно использовать:
вынести skill lifecycle checks из combat hot path и сделать selector-решения проверяемыми

- `JobXXActionCtrl`
Откуда:
runtime probes, CE target screens и архивное research по controller-state
Что делает:
общее имя family для per-job action controllers, например `Job07ActionCtrl`
Как можно использовать:
смотреть controller-owned state у навыков, которые выглядят частично stateful или unsafe для прямого форса

- `Job07InputProcessor`
Откуда:
архивное research по controller и execution path у `Job07`
Что делает:
job-specific input-side processing surface для `Job07`
Как можно использовать:
проверять, требует ли профессия input-processor context помимо pack или direct action request

- `processCustomSkill`
Откуда:
архивное research execution paths и example skill tooling
Что делает:
engine-side processing entry для custom-skill requests
Как можно использовать:
исследовать альтернативные execution paths, когда `requestActionCore(...)` оказывается слишком поверхностным или unsafe

- `requestActionCore(...)`
Откуда:
текущий runtime bridge, архивные unsafe-skill probes и example mods
Что делает:
surface прямого action-request, которым пользуется runtime bridge
Как можно использовать:
быстрый execution path для `direct_safe` phases или вторая половина `carrier_then_action`
Что важно:
архив уже показал, что “action стартовал” не доказывает, что окружающий controller state валиден

- `via.Component.get_GameObject` и `via.GameObject.getComponent(System.Type)`
Откуда:
текущий utility layer, target-surface research и REFramework exception logs
Что делает:
строит bridge от произвольного engine object или component к `via.GameObject`, а затем к typed component вроде `app.Character`
Как можно использовать:
component resolution, target normalization и scene-object extraction
Что важно:
использовать аккуратно в hot path; архив уже показал, что слишком широкое getter-heavy использование может вызывать дорогие exceptions

### Каталог unlock, контрактов и классификаций

- `player.QualifiedJobBits`
Откуда:
текущий unlock runtime и код восстановления unlock на guild-side
Что делает:
bitfield профессий, на которые квалифицирован player actor
Как можно использовать:
progression gating, unlock mirroring и UI parity checks

- `main_pawn.JobContext.QualifiedJobBits`
Откуда:
текущий runtime hybrid unlock
Что делает:
bitfield профессий, на которые квалифицирован `main_pawn`
Как можно использовать:
зеркалить недостающие qualification bits между актерами и проверять unlock state без открытия UI

- `app.ui040101_00.getJobInfoParam`
Откуда:
текущий guild-side unlock override
Что делает:
UI-facing accessor job info, который использует экран guild jobs
Как можно использовать:
ставить узкие UI overrides, когда runtime unlock уже существует, а view layer еще его скрывает

- `_EnablePawn`
Откуда:
текущий guild-side unlock override и UI inspection
Что делает:
job-info flag, который контролирует, может ли pawn использовать или видеть профессию в UI
Как можно использовать:
чинить UI parity и отлаживать view-layer

- `execution_contract`
Откуда:
текущая runtime data model, combat profiles и архивное research по контрактам
Что делает:
классифицирует, как skill или phase можно безопасно запускать
Как можно использовать:
разделять идентичность навыка и семантику его исполнения в любом action bridge

- `direct_safe`
Откуда:
архивное research по контрактам и текущие runtime data
Что делает:
label для фаз, которые можно безопасно запускать прямым action forcing
Как можно использовать:
прямой путь через `requestActionCore(...)` или похожий low-risk trigger

- `carrier_required`
Откуда:
архивное research по контрактам, текущий bridge и carrier-backed example mods
Что делает:
label для фаз, которым нужен AI-target или ActInter carrier path
Как можно использовать:
pack-based execution, blackboard target staging и более безопасный bridge admission для context-heavy skills

- `controller_stateful`
Откуда:
архивное исследование `DragonStinger` и текущий runtime probe mode
Что делает:
label для фаз, которые зависят от dedicated controller state сверх простого action request
Как можно использовать:
маркировать unsafe или частично исследованные пути, которым перед имплементацией нужны controller snapshots

- `selector_owned`
Откуда:
текущая data model и архивная conservative placeholder policy
Что делает:
label для фаз, которые пока лучше оставить нативному selector’у
Как можно использовать:
безопасный default для еще не заземленных actions

- `action_only`
Откуда:
текущие bridge modes и архивное unsafe-probe research
Что делает:
bridge mode, который шлет только direct action request
Как можно использовать:
low-overhead execution path для действительно direct-safe actions

- `carrier_only`
Откуда:
текущие bridge modes и архивное unsafe-probe research
Что делает:
bridge mode, который шлет только carrier или pack
Как можно использовать:
staging или экспериментальные случаи, где дальнейший native follow-up должен произойти после carrier

- `carrier_then_action`
Откуда:
текущие bridge modes и архивное contract research
Что делает:
bridge mode, который сначала ставит carrier context, а затем шлет direct action path
Как можно использовать:
hybrid execution для context-heavy actions

- `priority-first`
Откуда:
текущий rollback selector’а и архивный анализ регрессии
Что делает:
selection rule, где ordering определяет raw phase `priority`, а contracts влияют только на execution
Как можно использовать:
возвращать детерминированное поведение, когда heuristic selector становится слишком непрозрачным

- `assumed_minimum_job_level`
Откуда:
текущий runtime fallback и архивные logs по blocked phases
Что делает:
диагностический fallback, означающий, что runtime не смог подтвердить реальный job level
Как можно использовать:
telemetry и guardrail diagnostics
Что важно:
это не замена настоящему job level

- `attack_populated`
Откуда:
classification из output-bridge burst
Что делает:
label decision pool, означающий, что attack-oriented packs присутствуют в `MainDecisions`
Как можно использовать:
разводить проблему admission/output и проблему отсутствующей decision population

- `no_pack_population`
Откуда:
classification из output-bridge burst
Что делает:
label decision pool, означающий, что в просканированной популяции не найдено pack-bearing decisions
Как можно использовать:
находить пустые или недоинструментированные decision windows

- `common_utility_output`
Откуда:
classification из output-bridge burst и текущая интерпретация output
Что делает:
label output для locomotion и utility-like packs, requests и nodes
Как можно использовать:
отделять небоевой output от job-specific и attack-like output

- `job_specific_output_candidate`
Откуда:
classification из output-bridge burst
Что делает:
label output, означающий, что текущие surfaces содержат job-specific pack или node tokens
Как можно использовать:
детектировать правдоподобный боевой output без хардкода на одну конкретную анимацию

- `executing_decision_other`, `enemy_list_other`, `front_target_list_other`, `in_camera_target_list_other`
Откуда:
classifications из target-publication burst
Что делает:
labels publication mode, которые показывают, какой target source сейчас несет `other` enemy target
Как можно использовать:
выбирать fallback roots по реально наблюдаемой live publication, а не по теории

### Каталог lifecycle-labels и skip reasons

- `potential`
Откуда:
текущий дизайн skill-lifecycle cache
Что делает:
label для навыков, которые существуют в matrix, но еще не прошли unlock requirements
Как можно использовать:
разводить “навык известен данным” и “навык уже можно открывать”

- `unlockable`
Откуда:
текущий skill-lifecycle cache и research по progression
Что делает:
label для навыков, у которых уже выполнен job-level gate
Как можно использовать:
показывать, что навык уже должен появляться для покупки или дальнейших ownership checks

- `learned`
Откуда:
текущий skill-lifecycle cache и skill-state research
Что делает:
label для навыков, которые реально изучены или принадлежат актеру
Как можно использовать:
жестко не пускать в combat candidates навыки, которыми актер не владеет

- `equipped`
Откуда:
текущий skill-lifecycle cache и research по equip-state
Что делает:
label для навыков, которые сейчас стоят в слотах
Как можно использовать:
ограничивать selector активным боевым loadout актера

- `combat_ready`
Откуда:
текущий дизайн skill-lifecycle cache
Что делает:
финальный staged label, означающий, что навык изучен, экипирован и сейчас runtime-legal
Как можно использовать:
дешевый selector-facing summary вместо повторной проверки всех gates в combat hot path

- `bridge_mode`
Откуда:
текущий combat bridge и архивная нормализация контрактов
Что делает:
runtime execution-mode label, который выводится из phase contract
Как можно использовать:
логировать и сравнивать, как bridge реально пытался исполнять выбранную фазу

- `invalid_target_identity`
Откуда:
session logs и архивные target-gate failures
Что делает:
skip reason, который появляется, когда резолвнутый target схлопывается в `self`, `player` или другую недопустимую identity
Как можно использовать:
разводить отсутствие target publication и плохую target classification

- `skill_not_learned`
Откуда:
текущий lifecycle-backed skill gate
Что делает:
skip reason, который появляется, когда phase требует skill, которым актер реально не владеет
Как можно использовать:
доказывать lifecycle failure до того, как обвинять target или output logic

- `skill_not_equipped`
Откуда:
текущая и архивная skill-gate telemetry
Что делает:
skip reason, который появляется, когда required skill изучен, но не стоит в слотах
Как можно использовать:
разводить проблемы loadout и более глубокие execution problems

- `skill_not_enabled`
Откуда:
текущая skill-gate telemetry
Что делает:
skip reason, который появляется, когда required skill экипирован, но не разрешен текущим skill context
Как можно использовать:
находить runtime legality failures после успешных ownership и equip checks

- `skill_not_available`
Откуда:
текущая skill-gate telemetry и example-mod availability checks
Что делает:
skip reason, который появляется, когда skill в принципе разрешен, но недоступен в текущих игровых условиях
Как можно использовать:
отделять volatile combat gating от стабильного lifecycle state

- `job_level_above_assumed_minimum`
Откуда:
архивные logs по blocked phases и текущая fallback diagnostics
Что делает:
skip или warning reason, который показывает, что phase требовал более высокий уровень, чем fallback runtime смог подтвердить
Как можно использовать:
помечать unresolved progression data, не выдавая fallback level за настоящий progression

### Каталог семейств output-state

- `Locomotion.*`
Откуда:
session logs, CE output bursts и FSM node captures
Что делает:
семейство базовых состояний движения и навигации вроде `Locomotion.NormalLocomotion` и `Locomotion.Strafe`
Как можно использовать:
считать нормальным pre-attack или combat-positioning окном; обычно это безопасное семейство для bridge admission

- `Common/*`
Откуда:
session logs, CE output bursts и captures identity у action packs
Что делает:
семейство общих utility, interaction, social и non-vocation-specific состояний
Как можно использовать:
отделять настоящий combat output от utility masking, talking, carry, sorting, treasure interactions и других общих состояний
Важно:
часть `Common/*` состояний является валидным hard non-combat block, но некоторые talking-like окна всё же могут требовать узкого recovery rule

- `Damage.DmgShrink*`
Откуда:
CE output bursts и damage-side FSM node captures
Что делает:
семейство hit-reaction или damage-recovery состояний вроде `Damage.Damage_Root.DmgShrinkM`
Как можно использовать:
считать коротким recovery-окном после получения урона; иногда это может быть узкое bridge-admission окно, если live enemy target ещё существует

- `Damage.DieCollapse`
Откуда:
CE output bursts и damage-side FSM node captures
Что делает:
collapse или death-like damage state
Как можно использовать:
считать жёстким stop-state, а не recoverable attack-admission окном

### Каталог исследовательских инструментов

- `Content Editor`
Откуда:
внешний tool mod, который уже использовался в проектном research
Что делает:
главная среда live inspection для CE console scripts, AI overview, blackboard viewers и direct dumps
Как можно использовать:
интерактивно исследовать engine state без shipping probes в product runtime

- `ce_find(...)`
Откуда:
console workflow внутри Content Editor
Что делает:
ищет engine-side objects, types, fields и resources через CE environment
Как можно использовать:
быстро находить surface до написания отдельного extractor

- `ce_dump(...)`
Откуда:
console workflow внутри Content Editor
Что делает:
пишет structured CE inspection output в файл
Как можно использовать:
получать повторяемые evidence captures для архива и оффлайн compare

- `DD2_DataScraper`
Откуда:
внешний research tool из utility pack
Что делает:
bulk one-shot exporter для больших data snapshots
Как можно использовать:
выносить тяжелый discovery и catalog extraction из product runtime

- `DD2_Scraper/`
Откуда:
внешний dump-catalog в `reframework/data/DD2_Scraper`
Что делает:
offline metadata/export set с singleton lists, `_meta_*` snapshots, enum dumps и skill parameter bundles
Как можно использовать:
подтверждать engine surfaces и singleton ownership без добавления новых runtime probes

- `DD2_Scraper/all_singletons.json`
Откуда:
`DD2_Scraper`
Что делает:
даёт каталог exported singleton types вроде `app.PawnManager`, `app.CharacterManager`, `app.BattleManager` и соседних managers
Как можно использовать:
выбирать grounded singleton entry points до того, как гадать о manager ownership в runtime code

- `DD2_Scraper/_meta_*.json`
Откуда:
`DD2_Scraper`
Что делает:
даёт per-type exports по fields и methods для `app.PawnManager`, `app.Character`, `app.Human`, `app.HitController` и других классов
Как можно использовать:
проверять getters, backing fields и job-specific controller surfaces до написания reflection fallbacks

- `DD2_Scraper/skill_params.json`
Откуда:
`DD2_Scraper`
Что делает:
offline bundle с ability, job, level-up и stamina parameter tables
Как можно использовать:
использовать как background parameter reference при проверке skill/job datasets без live runtime scraping

- `DD2_Scraper/character_roster.json`
Откуда:
`DD2_Scraper`
Что делает:
point-in-time roster snapshot для player, pawns, NPCs и enemies
Как можно использовать:
лёгкая sanity-check проверка roster
Важно:
не считать богатым live-combat source; snapshot может быть sparse или partially unresolved

- `usercontent/`
Откуда:
support-directory Content Editor в `reframework/data/usercontent`
Что делает:
offline CE workspace с RSZ schema exports, enum dumps, type caches, presets и editor state
Как можно использовать:
использовать как schema/tooling reference, а не как primary live gameplay evidence

- `usercontent/rsz/dd2.json`
Откуда:
`usercontent/rsz`
Что делает:
даёт schema/import-surface export для AI classes, `AITarget*` variants, decision-condition types, `Job07` classes и main-pawn context types
Как можно использовать:
подтверждать существование типа или поля в engine schema до того, как опираться на него в архитектуре мода

- `usercontent/enums/*.json`
Откуда:
`usercontent/enums`
Что делает:
даёт focused enum exports вроде `app.Character.JobEnum`, `app.CharacterData.JobDefine` и `app.HumanEnemyParameterBase.NPCCombatParamTemplate`
Как можно использовать:
заземлять job IDs, NPC template names и combat-template labels без выдумывания локальной nomenclature

- `usercontent/dumps/enums_2026-03-24 20-59-33/*`
Откуда:
архивный Content Editor enum dump внутри `usercontent/dumps`
Что делает:
даёт более богатый historical enum snapshot, чем сокращённый `usercontent/enums`
Как можно использовать:
использовать как fallback source, когда нужного enum нет в коротком текущем наборе

- `usercontent/cache/typecache.json`
Откуда:
`usercontent/cache`
Что делает:
большой offline type index по классам, generic containers и engine-side symbol names
Как можно использовать:
быстрый discovery index для проверки существования type family до более глубокого CE или runtime probing

- `usercontent/editor_settings.json`
Откуда:
workspace state Content Editor
Что делает:
хранит CE UI state, recent selections и embedded editor/script session data
Как можно использовать:
восстанавливать operator workflow context
Важно:
не считать live gameplay truth или authoritative runtime evidence

- `reframework/data/`
Откуда:
полный top-level обзор установленного дерева `reframework/data` от `2026-03-28`
Что делает:
даёт рабочую source-map для всего, что сейчас пишут CE, product mod, offline dump tools и dev-only helper mods
Как можно использовать:
считать `ce_dump/` и `PawnHybridVocationsAI/logs/` primary live evidence layer, `DD2_Scraper/` и `usercontent/` schema/reference layer, а остальные top-level папки mostly service или tool-state directories

- `reframework/data/ce_dump/`
Откуда:
Content Editor scripts и наши repo-local CE dump scripts
Что делает:
хранит one-shot и burst JSON captures вроде output-classification screens и target-publication bursts
Как можно использовать:
основной point-in-time live evidence слой для проверки target publication, output classification и admission-family state
Важно:
frame snapshots лучше читать вместе с session logs, когда расследование чувствительно к таймингу

- `reframework/data/PawnHybridVocationsAI/logs/`
Откуда:
session telemetry product runtime
Что делает:
хранит собственные session logs мода, skip reasons, target-source probe summaries и bridge-admission telemetry
Как можно использовать:
основной runtime evidence слой для ответа на вопрос, что именно увидел shipped mod и почему он skipped или failed
Важно:
если эти логи расходятся с `ce_dump/`, считать это признаком нестабильного runtime acquisition/normalization path, а не автоматической ошибкой CE

- `reframework/data/NickCore/`
Откуда:
state dev-only helper mod
Что делает:
маленькая state-папка, где сейчас лежат только launch и script-reset markers
Как можно использовать:
только как tooling sanity check
Важно:
не считать gameplay-evidence source

- `reframework/data/NicksDevtools/`
Откуда:
config dev-only helper mod
Что делает:
хранит trace и visualization settings для Nick's Devtools
Как можно использовать:
как operator config reference при воспроизведении внешней trace session
Важно:
не считать gameplay-evidence source

- `reframework/data/reframework/`
Откуда:
текущее installed tree
Что делает:
сейчас это просто пустой nested scaffold внутри `reframework/data`
Как можно использовать:
игнорировать в project research, пока какой-нибудь future tool действительно не начнёт писать туда файлы

- `Nick's Devtools` и `_NickCore`
Откуда:
внешний dev-only tooling, который загружался во время исследования
Что делает:
дают bounded live tracing и вспомогательную dev infrastructure
Как можно использовать:
включать только для узких live traces, когда CE scripts и dumps уже не отвечают на вопрос

- `Skill Maker`
Откуда:
внешний example mod, использованный как reference set
Что делает:
дает reference catalog action names, skill metadata и user-facing datasets
Как можно использовать:
заземлять naming и interpretation skill IDs без выдумывания собственной номенклатуры

- `docs/ce_scripts/*`
Откуда:
наш текущий research layer внутри репозитория
Что делает:
содержит одноразовые и burst-oriented extractor scripts, которые пишут evidence в файл
Как можно использовать:
держать исследование вне product runtime и обновлять документацию по воспроизводимым file outputs

## Внешний разбор мода Bestiary (2026-04-01)

Источник:
`E:\[Codex]\Dragons Dogma 2\Примеры модов\Bestiary-1196-2-0-5-1775046237`

### Главный вывод

`Bestiary` не "открывает скрытые нативные заклинания" монстрам в узком смысле.
Он строит собственный слой исполнения боевых movesets поверх `_NickCore` и REFramework hooks.

Монстры начинают "колдовать" там не потому, что их ванильный AI вдруг начал понимать новые спеллы, а потому что мод:

- подхватывает врага как `handled character`
- следит за его нативными action requests
- иногда заменяет нативный action своим move
- запускает авторскую sequence
- по кадрам проводит эту sequence
- внутри нод sequence сам вызывает:
  - нативные action nodes
  - принудительные motion swaps
  - эффекты
  - звуки
  - shell/projectile spawn
  - summon spawn
  - правки урона / attack data
- на время sequence не даёт ванильному AI слишком легко всё это перебить

То есть ответ на вопрос "как он заставил мобов кастовать" такой:

- не через восстановление ванильного decision graph
- а через собственный sequence executor

### Из чего мод состоит

Важные слои:

- `Bestiary.lua`
  - bootstrap, загрузка enemy/variant файлов, cleanup, debug UI
- `MovesetHandler/*`
  - главное боевое ядро
- `ShellHandler/*`
  - слой создания и модификации shell'ов
- `EnemySpawner.lua`
  - спавн существ для summon-нод
- `Utils/*`
  - низкоуровневые helper-методы
- `VariantHandler.lua`
  - система enemy variants, цветов, scale, healthbars, damage multipliers
- `SilenceRework.lua`
  - отдельная переработка silence
- `DragonsplagueRework.lua`
  - отдельная переработка dragonsplague

### Что делает bootstrap

`Bestiary.lua`:

- грузит `VariantHandler`, `SilenceRework`, `DragonsplagueRework`
- читает `Config.lua`
- загружает все enabled `Enemies/*.lua`
- загружает enabled `EnemyVariants/*.lua`
- обновляет variant list и variant names
- обновляет debug UI списка movesets
- чистит:
  - summons
  - shells
  - efx
  при смерти, destroy hit и script reset

Это не боевой мозг, а точка сборки мода.

### Как враг подключается к системе

Главная функция:
`Bestiary/MovesetHandler/Setup.lua -> setup.setup_character(params)`

Она делает сразу несколько вещей.

1. Регистрирует `on_pre_action_request`
- ловит нативные action requests врага
- при первом попадании создаёт `characterInfo`
- дальше может заменить нативный action своим кастомным move

2. Регистрирует `on_frame`
- обновляет live state врага
- если враг не занят кастомным move, проверяет idle окна
- может запустить idle move

3. Регистрирует cleanup для summons и shells

`setup_info(data, params)` создаёт runtime state врага:

- `character`
- `lastMoveTimes`
- `idleTime`
- `position`
- `targetPosition`
- `targetDistance`
- `fullNode`
- `trackingDistance`
- `isInMove`
- `frame`
- `actionsTable`

И в этот же объект внедряет utility methods:

- `kill_shell`
- `kill_all_shells`
- `kill_summon`
- `kill_all_summons`
- `destroy_summon`
- `destroy_all_summons`
- `kill_all_efx`

### Как он решает, можно ли вообще запускать кастомный move

`can_play_move(characterInfo)` проверяет:

- враг не в специальном dragon исключении
- есть текущий full node
- враг не несёт объект
- враг реально в combat state
- враг не в stagger/damage node
- у `EnemyCtrl.Ch2` есть валидный attack target
- target для большинства врагов резолвится в character или допустимый special target

То есть мод не кастует "в вакууме".
Он всё равно опирается на нативный target врага.

### Как выбирается move

`Bestiary/MovesetHandler/Selection.lua`

Методы:

- `selection.is_valid_move(characterInfo, name, move)`
  - cooldown
  - target distance
  - hp threshold
  - status
  - angle to target
  - custom predicate
- `selection.get_valid_moves(...)`
  - фильтрует только допустимые moves
- `selection.pick_random_move(...)`
  - делает weighted random
- `selection.choose_move(...)`
  - публичная точка выбора
  - ещё и пишет timestamp в `lastMoveTimes`
- `selection.get_idle_move_chance(...)`
  - плавно повышает шанс idle-move, если враг долго тупит

Важно:
`Bestiary` выбирает move не по строгому priority, а по weighted selection среди валидных кандидатов.

### Как он заменяет ванильные атаки

`handle_replace_moves(characterInfo, data, params)`

Логика:

- смотрит в `actionsTable[data.node]`
- проверяет шанс замены
- если враг уже в кастомном move или combat preconditions провалены:
  - "specific replacement" всё равно может запретить нативный action
- если всё хорошо:
  - выбирает move через `selection.choose_move(..., "replaceWeight")`
  - запускает его через `executor.play_sequence(...)`
  - возвращает `true`, чтобы скипнуть ванильный node

Вот это и есть главная точка, где мод реально "перехватывает бой".

### Как запускается sequence

`Bestiary/MovesetHandler/Executor.lua -> executor.play_sequence(characterInfo, sequence, addMotionBank)`

Что делает:

- собирает runtime context:
  - transform
  - combatStateControl
  - workRate
  - motion
  - ch2
  - track
  - address
- создаёт `ctx`
- abort'ит старые move functions
- ставит `characterInfo.isInMove = true`
- при необходимости добавляет dynamic motion bank
- вешает helper methods:
  - `go_to_node`
  - `go_to_next_node`
  - `abort_fns`
- переводит sequence на первый node
- запускает per-frame driver
- запускает interrupt prevention

### Как работает sequence runtime

`Bestiary/MovesetHandler/NodeCore.lua`

Ключевые методы:

- `get_layer(ctx)`
- `play_node(characterInfo, ctx)`
- `is_in_node(characterInfo, ctx)`
- `go_to_node(characterInfo, ctx, number)`
- `go_to_next_node(...)`
- `set_character_frame(...)`
- `set_character_speed(...)`
- `set_character_rotation(...)`
- `on_frame(...)`

Смысл:

- управляет активной нодой
- считает frame progression
- крутит скорость и разворот
- спавнит payloads
- двигает sequence дальше или abort'ит

### Как он не даёт ванили всё перебить

`Bestiary/MovesetHandler/PreventInterrupts.lua`

Методы:

- `disable_ai(ctx)`
- `skip_ai(ctx)`
- `skip_locomotion(ctx)`
- `on_pre_action_request(characterInfo, ctx)`
- `prevent_interrupts(characterInfo, ctx)`

Это один из самых важных слоёв мода:
пока sequence активна, мод агрессивно удерживает ownership над врагом.

### Как он завершает move

`Bestiary/MovesetHandler/NodeAborts.lua`

Методы:

- `enable_ai(characterInfo, ctx)`
- `flush_functions(characterInfo, ctx)`
- `abort_fns(characterInfo, ctx, delay?)`
- `soft_abort(characterInfo, ctx)`

### Как sequence ноды создают магию, эффекты и summons

`NodeHooks.lua`

- `attach_damage_info_hook`
- `attach_attack_data_hook`
- `attach_cast_colors_hook`

`NodeFX.lua`

- `play_efx`
- `play_sfx`

`NodeShells.lua`

- `get_shell_position`
- `get_shell_rotation`
- `cast_shell`
- `summon`

Именно `cast_shell(...)` и `summon(...)` превращают authored node payload в реальную боевую сущность в игре.

### Как работает shell слой

`Bestiary/ShellHandler.lua -> shellHandler.cast_shell(owner, udataPath, shellID, params)`

Он:

- находит нужный `ShellParamData`
- создаёт `ShellCreateInfo`
- временно правит shell params
- вызывает `app.ShellManager.requestCreateShell(...)`
- вешает набор временных hooks на зарегистрированный shell

`ShellParams.lua`

- `modify_base_params`
- `modify_gravity`

`ShellHooks.lua`

- `attach_regist_hook`
- `attach_follow_joint_fn`
- `attach_on_frame_fn`
- `attach_color_hook`
- `attach_absolute_lifetime_hook`
- `attach_attack_data_hook`
- `attach_damage_info_hook`
- `handle_special_cases`
- `flush_shell_hooks`

`ShellUdatas.lua`

- заранее грузит огромный каталог `shellparamdata.user`
- это и есть библиотека projectile/spell ресурсов

### Что находится в enemy файлах

Enemy files пишут не runtime ядро, а данные.

Они обычно:

1. Описывают `movesetHandler.movesets.<EnemyName>`
2. Описывают:
   - `actionsTable`
   - `idleTable`
3. Вызывают:
   - `movesetHandler.setup_character({...})`

Move может содержать:

- `targetDistance`
- `cooldownSeconds`
- `hpThreshold`
- `validStatus`
- `angles`
- `idleWeight`
- `replaceWeight`
- `custom_condition`
- `addMotionBank`
- `sequence`

Sequence node может содержать:

- `nodeName`
- `motionData`
- `nextFrame`
- `trackingFrames`
- `trackingForce`
- `speed`
- `interruptible`
- `uninterruptible`
- `on_start`
- `on_frame`
- `on_end`
- `on_stagger`
- `modify_attack_data`
- `modify_damage_info`
- `castingColors`
- `efx`
- `sfx`
- `shell`
- `summon`

### Примеры

`SacredArborPurgener.lua`

- реальные "спеллы":
  - `Summon Rattlers`
  - `Brine Meteor`
  - `Brine Meteor - Multi Target`
- состоят из:
  - windup VFX/SFX
  - shell spawn
  - summon spawn
  - cooldown bookkeeping

`GoblinLeader.lua`

- показывает, что система не только про магов
- `Throwblast Frenzy`
  - native nodes + forced motions + repeated shell spawns
- `Suicide Bomber`
  - attach shell к руке
  - tracking по target
  - branch по дистанции прямо внутри `on_frame`

### Вспомогательные side системы

`VariantHandler.lua`

- variants
- recolor
- scale
- healthbars
- exp multiplier
- status resistance
- damage/stagger mults
- element swaps

`SilenceRework.lua`

- меняет поведение silence на боссах

`DragonsplagueRework.lua`

- меняет dragonsplague и связанные последствия

### Что из этого полезно нам

Полезно концептуально:

- жёсткое разделение на:
  - eligibility
  - selection
  - execution
  - anti-interrupt
  - payload injection
  - abort cleanup
- sequence runtime вместо одношагового bridge
- один move как цепочка timed nodes
- богатая payload model на ноду

Полезно технически:

- `requestActionCore(...)`
- `changeMotion(...)`
- dynamic motion banks
- callbacks:
  - `on_start`
  - `on_frame`
  - `on_end`
  - `on_stagger`
- gates:
  - distance
  - hp
  - angle
  - cooldown
  - custom predicate

Полезно скорее для research/dev:

- `_NickCore` callback fabric
- shell creation / mutation
- force-play debug UI

Что нам не подходит как готовая product architecture:

- полное владение enemy AI
- широкое выключение `ActInter`
- полное подавление locomotion
- shell-heavy monster control как основная схема для main pawn

### Самый полезный вывод для нас

Если что-то и забирать из `Bestiary`, то не monster override целиком.
Брать надо его архитектурный паттерн:

- selected move = sequence
- sequence = timed steps
- selection отдельно от execution
- execution отдельно от anti-interrupt
- payload отдельно от cleanup

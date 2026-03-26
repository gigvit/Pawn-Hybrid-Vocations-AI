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
- the override enables `_EnablePawn` on hybrid job info for `main_pawn` and otherwise returns the original UI result

Confirmed in game:

- the crash introduced by the earlier risky guild-hook path is gone
- the restored unlock path works again for `main_pawn`

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
- the primary decision module is `app.DecisionEvaluationModule`
- `DecisionExecutor` is live
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
- the primary decision module is `app.ThinkTableModule`
- `DecisionExecutor` and `ExecutingDecision` are absent in the observed `Sigurd Job07` pipeline

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

##### Decision pipeline architecture

Focused CE compares now show a structural split:

- `main_pawn Job07` is routed through the pawn `app.DecisionEvaluationModule` pipeline
- `Sigurd Job07` is routed through the NPC `app.ThinkTableModule` pipeline
- `ThinkTableModule` was not found near the observed `main_pawn` decision chain in the tested scenes
- the earlier `selector / admission / context` question is now narrowed to a pawn-specific decision-content or decision-output question

##### Combat main-decision population

Focused combat captures now show a second, stronger split inside the pawn pipeline itself:

- outside combat, selected-job-only snapshots can still look identical between `main_pawn Job01` and `main_pawn Job07`
- in combat, `main_pawn Job01` repeatedly exposes `42` `MainDecisions`
- in combat, `main_pawn Job07` repeatedly exposes only `11` `MainDecisions`
- across repeated captures, `main_pawn Job07` contributes no unique combat `scalar_profile` or `combined_profile`
- the observed `main_pawn Job07` combat `MainDecisions` are a strict subset of the observed `main_pawn Job01` combat `MainDecisions`
- the remaining blocker is therefore already visible inside the pawn `DecisionEvaluationModule` combat decision population

##### Combat semantic split inside `MainDecisions`

The semantic compare sharpens the same conclusion:

- repeated semantic captures show `main_pawn Job01` at `47-48` combat `MainDecisions`
- repeated semantic captures show `main_pawn Job07` at `11` combat `MainDecisions`
- `main_pawn Job07` contributes no unique combat `semantic_signature`; all observed `Job07` semantic signatures are already present in `Job01`
- the retained `Job07` combat layer is dominated by common movement / carry / talk / catch / cliff / keep-distance behavior
- `main_pawn Job07` still surfaces no observed `Job07_*` action-pack identities in these combat captures
- `main_pawn Job01` includes many additional attack-oriented packs and behaviors that do not survive into combat `Job07`, including multiple `Job01_Fighter/*` packs and several `GenericJob/*Attack*` packs
- the reduced `Job07` combat layer also loses much of the richer `EvaluationCriteria`, `TargetConditions`, and `SetAttackRange` start/end-process population seen in combat `Job01`

#### Strengthened conclusions

These conclusions are now strong:

- the blocker is not best explained by a missing `Job07ActionCtrl`
- the blocker is not best explained by a missing decision state
- `Job07` content exists and works in the engine
- the current gap is `main_pawn`-specific
- `main_pawn Job07` and `Sigurd Job07` do not share the same primary decision architecture
- `main_pawn Job07` uses `app.DecisionEvaluationModule`
- `Sigurd Job07` uses `app.ThinkTableModule`
- the current gap is now best explained as a pawn decision-pipeline gap, not only as a generic selector/admission surface gap
- in combat, `main_pawn Job07` is under-populated before action output, not only misrouted after selection
- the observed combat `main_pawn Job07` `MainDecisions` form a strict subset of combat `main_pawn Job01` `MainDecisions`
- the observed combat `main_pawn Job07` semantic layer is still generic/common-heavy and does not expose a confirmed `Job07` attack-oriented decision cluster
- timed combat output bursts now close the next bridge step:
- stable combat `Job01` bursts show `attack_populated` decision state feeding mostly `job_specific_output_candidate` output, including `Job01_*` actions, `Job01_*` FSM nodes, and attack-oriented `decision_pack_path` values
- stable combat `Job07` bursts still show only `11` `MainDecisions`, `current_job_pack_count=0`, `generic_attack_pack_count=0`, utility-only pack identities, and `common_utility_output` such as `Strafe`, `NormalLocomotion`, and `Common/MoveToPosition_Walk_Target`
- the missing combat behavior is therefore now traced through to output surfaces, not only inferred from decision-population differences

#### Weakened or rejected conclusions

These older conclusions are no longer active:

- "`Job07` is absent for `main_pawn`"
- "`ce_dump=nil` proves the absence of `Job07ActionCtrl`"
- "`target kind mismatch` is always the root cause"
- "`getter` alone proves a live attack path"

#### Current strongest hypothesis

Current working hypothesis:

- `main_pawn Job07` does not fail inside the NPC `ThinkTableModule` path because it is not using that path in the observed scenes
- the pawn `DecisionEvaluationModule` content for combat `Job07` is not simply different; it is under-populated versus combat `Job01`
- the next question is which missing attack-oriented combat `MainDecisions` correspond to the lost `Job07` combat behavior and how that reduction propagates into evaluation output or action output
- the strongest local candidates are the missing `Job01_Fighter/*`, `GenericJob/*Attack*`, and `SetAttackRange`-bearing combat decisions that appear in combat `Job01` but not in combat `Job07`

#### Vocation definition surface

`vocation_definition_surface_20260326_195656.json` confirms that CE Console can extract real vocation-definition data, not only actor or NPC snapshots.

- `app.HumanCustomSkillID` now gives confirmed hybrid custom-skill bands:
- `Job07 = 70..79`
- `Job08 = 80..91`
- `Job09 = 92..99`
- `Job10 = 100`
- `app.HumanAbilityID` also resolves hybrid ability bands:
- `Job07 = 34..38`
- `Job08 = 39..43`
- `Job09 = 44..48`
- `Job10 = 49..50`
- `Job07Parameter` exposes real combat surfaces such as `NormalAttackParam`, `HeavyAttackParam`, `MagicBindParam`, `SpiralSlashParam`, `SkyDiveParam`, `DragonStingerParam`, `FarThrowParam`, `EnergyDrainParam`, and `DanceOfDeathParam`
- `Job08Parameter` exposes `NormalAttackParam`, `FlameLanceParam`, `BurningLightParam`, `FrostBlockParam`, `ThunderChainParam`, `CounterArrowParam`, `SeriesArrowParam`, and `SpiritArrowParam`
- `Job09Parameter` exposes `_NormalAttackParam`, `_ThrowSmokeParam`, `_SmokeDecoyParam`, `_DetectFregranceParam`, and `_AstralBodyParam`
- `Job10Parameter` currently exposes only `Job10_00Param`
- `Job07`, `Job08`, and `Job09` all expose live `InputProcessor`, `ActionController`, and `ActionSelector` types, while `Job10` exposes controller and selector surfaces but no observed `Job10InputProcessor`
- `Job07InputProcessor` and `Job07ActionSelector` expose concrete entry points such as `processMagicBind`, `processNormalAttack`, `processSpiralSlash`, `processCustomSkill`, `getCustomSkillAction`, `getNormalAttackAction`, and `requestActionImpl`
- `Job08` and `Job09` also expose concrete job-specific `processCustomSkill` and normal-attack selector surfaces, so later profiles for `08` and `09` do not need to start from blind guesses
- off-job `SkillContext` access is strong: both `player` and `main_pawn` expose per-job equip lists for `Job07` through `Job10` even while the recorded snapshot was `player=Mage` and `main_pawn=Fighter`
- in the recorded snapshot both `player` and `main_pawn` carried `Job07 slot0 = Job07_DragonStinger`, `Job08 slot0 = Job08_FrostTrace`, and empty `Job09` / `Job10` slots
- `SkillAvailability` stayed unresolved in this snapshot while `SkillContext` and `CustomSkillState` were live, so runtime gating should prefer `SkillContext`, per-job equip lists, `hasEquipedSkill(...)`, `isCustomSkillEnable(...)`, and `getCustomSkillLevel(...)`
- `SkyDive` is confirmed custom skill `76`
- `SpiralSlash` appears in `Job07Parameter` and `Job07InputProcessor` but not in `app.HumanCustomSkillID`; until contrary evidence appears it should be treated as a core or non-custom move, not as a custom-skill gate
- `Job10` is structurally special and should stay a separate implementation track when the runtime bridge expands from `Job07` to `Job08` through `Job10`

#### Confirmed implementation direction

The next implementation step is no longer blind pack guessing.

- keep the decision-pipeline diagnosis as the main blocker explanation for `main_pawn Job07`
- use the extracted class-definition surface to build progression-aware hybrid profiles
- treat `Job07` as the first grounded profile:
- core phases can use confirmed non-custom surfaces such as `SpiralSlash`
- custom-skill phases should use confirmed ids such as `SkyDive = 76`
- expand the same profile architecture to `Job08` and `Job09`, then handle `Job10` as a separate structural case

#### Archived research layer

The old research layer was removed from the product hot path.

Archived domains:

- orchestration: `app/module_specs.lua`, `app/runtime_driver.lua`, `core/module_system.lua`
- logging and traces: old `core/log.lua`, session logs, discovery logs, guild trace logs
- research modules: `action_research`, `combat_research`, `loadout_research`, `pawn_ai_data_research`, `guild_flow_research`, `sigurd_observer`, `npc_spawn_prototype`, `talk_event_trace`
- progression probes: `game/progression/trace.lua`, `probe.lua`, `correlation.lua`
- synthetic and adapter layer
- runtime debug UI

Residual value preserved from the old logs before deletion:

- the remaining `2026-03-25` session logs confirm that `main_pawn Job07` could reach the correct hybrid runtime surface (`main_pawn_job=7`, `main_pawn_weapon_job=7`) and still remain stuck in common runtime output such as `NormalLocomotion`, `DrawWeapon`, and `Common/Common_MoveToHighFive.user`
- one recorded `Job07` session still showed a live current-job loadout `73,0,0,0` while output stayed generic/common, so the failure was not explained by a totally empty visible custom-skill slot state
- the old discovery and action-research hooks produced high hook volume but poor payload yield: repeated `actinter_requests` could still end with `decision_probe_hits=0`, `decision_snapshot_hits=0`, and `decision_actionpack_snapshot_hits=0`
- this historical signal supports the current CE-first rule: keep the old logs only as archived evidence, not as the default diagnostic path

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
- `docs/ce_scripts/main_pawn_main_decision_profile_screen.lua`
- `docs/ce_scripts/main_pawn_main_decision_semantic_screen.lua`
- `docs/ce_scripts/main_pawn_output_bridge_burst.lua`
- `docs/ce_scripts/vocation_definition_surface_screen.lua`

#### Required CE script properties

Each CE script must:

- solve one concrete task
- write output to file
- produce data suitable for compare and later documentation updates

#### Current implementation files

- `mod/reframework/autorun/PawnHybridVocationsAI/bootstrap.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/data/hybrid_combat_profiles.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/discovery.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat_fix.lua`
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
- override включает `_EnablePawn` для hybrid job info у `main_pawn` и в остальных случаях возвращает исходный UI result

Подтверждено в игре:

- краш, внесенный прежним рискованным guild-hook path, устранен
- восстановленный unlock path снова работает для `main_pawn`

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

##### `Sigurd Job07`

Валидные контрольные `Sigurd` traces уже существуют.

Подтверждено:

- `Sigurd` входит в реальные `Job07`-specific NPC packs
- `Sigurd` входит в реальные `Combat.Job07_*` node families
- primary decision module - `app.ThinkTableModule`
- `DecisionExecutor` и `ExecutingDecision` отсутствуют в наблюдаемом `Sigurd Job07` pipeline

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

##### Архитектура decision pipeline

Точечные CE compares теперь показывают структурный разрыв:

- `main_pawn Job07` идет через pawn pipeline `app.DecisionEvaluationModule`
- `Sigurd Job07` идет через NPC pipeline `app.ThinkTableModule`
- `ThinkTableModule` не найден рядом с наблюдаемой decision chain у `main_pawn` в протестированных сценах
- прежний вопрос про `selector / admission / context` теперь уже сужен до вопроса о pawn-specific decision content или decision output

##### Боевая популяция `MainDecisions`

Точечные боевые captures теперь показывают второй, более сильный разрыв уже внутри pawn pipeline:

- вне боя selected-job-only snapshots еще могут выглядеть одинаково между `main_pawn Job01` и `main_pawn Job07`
- в бою `main_pawn Job01` повторяемо показывает `42` `MainDecisions`
- в бою `main_pawn Job07` повторяемо показывает только `11` `MainDecisions`
- по повторным captures у `main_pawn Job07` нет уникальных боевых `scalar_profile` или `combined_profile`
- наблюдаемые боевые `main_pawn Job07` `MainDecisions` являются строгим подмножеством боевых `main_pawn Job01` `MainDecisions`
- значит оставшийся blocker уже виден внутри боевой популяции решений pawn `DecisionEvaluationModule`

##### Семантический боевой разрыв внутри `MainDecisions`

Семантический compare усиливает тот же вывод:

- повторные semantic captures показывают `main_pawn Job01` на уровне `47-48` боевых `MainDecisions`
- повторные semantic captures показывают `main_pawn Job07` на уровне `11` боевых `MainDecisions`
- `main_pawn Job07` не дает ни одной уникальной боевой `semantic_signature`; все наблюдаемые `Job07` semantic signatures уже присутствуют у `Job01`
- сохраненный боевой слой `Job07` доминируется common/generic utility-поведением: movement, carry, talk, catch, cliff, keep-distance
- в этих боевых captures у `main_pawn Job07` все еще не наблюдаются `Job07_*` action-pack identities
- `main_pawn Job01` содержит много дополнительных attack-oriented packs и behavior, которые не доживают до боевого `Job07`, включая множественные `Job01_Fighter/*` packs и несколько `GenericJob/*Attack*` packs
- у сокращенного боевого слоя `Job07` также пропадает значительная часть более богатой популяции `EvaluationCriteria`, `TargetConditions` и start/end-process c `SetAttackRange`, которая есть у боевого `Job01`

#### Усиленные выводы

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

#### Ослабленные или отвергнутые выводы

Эти старые выводы больше не активны:

- "`Job07` отсутствует у `main_pawn`"
- "`ce_dump=nil` доказывает отсутствие `Job07ActionCtrl`"
- "`target kind mismatch` всегда является корнем проблемы"
- "`getter` сам по себе доказывает живой attack path"

#### Текущая сильнейшая гипотеза

Текущая рабочая гипотеза:

- `main_pawn Job07` не ломается внутри NPC `ThinkTableModule` path, потому что в наблюдаемых сценах он вообще не использует этот path
- боевой content pawn `DecisionEvaluationModule` для `Job07` не просто отличается; он недонаселен относительно боевого `Job01`
- следующий вопрос - какие именно отсутствующие attack-oriented боевые `MainDecisions` соответствуют потерянному `Job07` combat behavior и как это сокращение доходит до evaluation output или action output
- самые сильные локальные кандидаты сейчас - отсутствующие `Job01_Fighter/*`, `GenericJob/*Attack*` и `SetAttackRange`-bearing combat decisions, которые присутствуют у боевого `Job01`, но не появляются у боевого `Job07`

#### Поверхность определений профессий

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
- off-job доступ к `SkillContext` сильный: и `player`, и `main_pawn` показывают per-job equip lists для `Job07` through `Job10`, даже если в момент capture они были не на этих профессиях
- в записанном snapshot и `player`, и `main_pawn` имели `Job07 slot0 = Job07_DragonStinger`, `Job08 slot0 = Job08_FrostTrace`, а `Job09` и `Job10` были пустыми
- `SkillAvailability` в этом snapshot остался unresolved, тогда как `SkillContext` и `CustomSkillState` были живыми, значит runtime-gating лучше опирать на `SkillContext`, per-job equip lists, `hasEquipedSkill(...)`, `isCustomSkillEnable(...)` и `getCustomSkillLevel(...)`
- `SkyDive` подтвержден как custom skill `76`
- `SpiralSlash` присутствует в `Job07Parameter` и `Job07InputProcessor`, но отсутствует в `app.HumanCustomSkillID`; пока не появится противоположное CE evidence, его правильно считать core или non-custom move, а не custom-skill gate
- `Job10` структурно особый и должен идти отдельной implementation track, когда runtime bridge будет расширяться с `Job07` на `Job08` through `Job10`

#### Подтвержденное направление реализации

Следующий шаг теперь уже не blind pack guessing.

- держать diagnosis по decision-pipeline как основное объяснение проблемы `main_pawn Job07`
- использовать extracted class-definition surface для построения progression-aware hybrid profiles
- рассматривать `Job07` как первый grounded profile:
- core phases могут опираться на подтвержденные non-custom surfaces вроде `SpiralSlash`
- custom-skill phases должны опираться на подтвержденные ids вроде `SkyDive = 76`
- ту же profile architecture нужно расширять на `Job08` и `Job09`, а `Job10` вести как отдельный structural case

#### Архив удаленного research layer

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
- `docs/ce_scripts/vocation_definition_surface_screen.lua`

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

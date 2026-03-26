# ROADMAP

## English

### Active goal

Make `Job07` usable for `main_pawn` with real combat behavior, not only with unlock or runtime presence.

### Current stage

The project is in the post-cleanup, CE-first stage:

- the mod contains product runtime only
- research is done through CE scripts
- unlock was restored as a product runtime path
- the restored unlock path is verified in game after the crash-fix

### Current priorities

#### Priority 1. Classify the missing combat `MainDecisions` for `main_pawn Job07`

Need:

- use the combat captures from `main_pawn_main_decision_profile_screen.lua` and `main_pawn_main_decision_semantic_screen.lua`
- inspect the `Job01`-only `combined_profile` and `semantic_signature` entries that never appear for combat `Job07`
- focus first on missing `Job01_Fighter/*`, `GenericJob/*Attack*`, and `SetAttackRange`-bearing decisions
- determine which missing combat decision slice is most likely tied to lost hybrid attack behavior

Success condition:

- one missing combat decision cluster is described semantically enough to trace its downstream effect

#### Priority 2. Trace the next output step after the reduced combat decision population

Completed:

- timed combat bursts now correlate the missing attack-oriented combat decision cluster with `decision_pack_path`, `selected_request`, `current_action`, and FSM output
- no additional broad CE narrowing step is currently needed before a runtime fix

Success condition:

- achieved: one concrete chain is now visible from `under-populated combat MainDecisions` to `missing combat behavior`

#### Priority 3. Implement the smallest confirmed combat fix

Need:

- one product-scoped runtime change based on CE evidence

Success condition:

- `main_pawn Job07` gains one confirmed step toward a real `Job07` combat family

### Out of scope for now

Do not do now:

- restore the old research layer
- return broad session or guild trace hooks
- add a new debug UI
- re-enable synthetic adapters in the hot path
- expand the project to `Job08`, `Job09`, or `Job10`

### Conditions for returning to hooks

Return to hooks only if:

- CE scripts already narrowed the question to one transition
- burst and screen traces do not capture that transition
- hooks are required to prove causality

## Русский

### Активная цель

Сделать `Job07` пригодным для `main_pawn` в реальном бою, а не только на уровне unlock или runtime presence.

### Текущий этап

Проект находится на этапе post-cleanup и CE-first:

- мод содержит только продуктовый runtime
- исследование идет через CE scripts
- unlock восстановлен как продуктовый runtime path
- восстановленный unlock path подтвержден в игре после crash-fix

### Текущие приоритеты

#### Приоритет 1. Семантически классифицировать отсутствующие боевые `MainDecisions` у `main_pawn Job07`

Нужно:

- использовать боевые captures из `main_pawn_main_decision_profile_screen.lua` и `main_pawn_main_decision_semantic_screen.lua`
- разобрать `Job01`-only `combined_profile` и `semantic_signature`, которые никогда не появляются у боевого `Job07`
- сначала сфокусироваться на отсутствующих `Job01_Fighter/*`, `GenericJob/*Attack*` и `SetAttackRange`-bearing decisions
- определить, какой отсутствующий боевой decision-cluster вероятнее всего связан с потерянным hybrid attack behavior

Условие успеха:

- один отсутствующий боевой decision-cluster описан семантически достаточно хорошо, чтобы проследить его downstream effect

#### Приоритет 2. Проследить следующий output step после сокращенной боевой популяции решений

Завершено:

- timed combat bursts уже сопоставили отсутствующий attack-oriented боевой decision-cluster с `decision_pack_path`, `selected_request`, `current_action` и FSM output
- перед runtime-fix сейчас не нужен еще один широкий шаг с CE-сужением

Условие успеха:

- достигнуто: видна одна конкретная цепочка от `under-populated combat MainDecisions` до `missing combat behavior`

#### Приоритет 3. Внести минимальный подтвержденный combat fix

Нужно:

- одно product-scoped runtime изменение, основанное на CE evidence

Условие успеха:

- `main_pawn Job07` получает один подтвержденный шаг к реальной `Job07` combat family

### Что сейчас вне области работы

Сейчас не делать:

- возврат старого research layer
- возврат широких session или guild trace hooks
- новый debug UI
- повторное включение synthetic adapters в hot path
- расширение проекта на `Job08`, `Job09` или `Job10`

### Условия возврата к hooks

Возврат к hooks допустим только если:

- CE scripts уже сузили вопрос до одного transition
- burst и screen traces не ловят этот transition
- hooks нужны именно для доказательства причинности

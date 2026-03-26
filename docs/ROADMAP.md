# ROADMAP

## English

### Active goal

Make hybrid jobs `Job07` through `Job10` usable for `main_pawn` with progression-aware combat behavior, starting with `Job07` as the first fully grounded profile.

### Current stage

The project is in the post-cleanup, CE-first, definition-informed stage:

- the mod contains product runtime only
- research is done through CE scripts
- unlock was restored as a product runtime path
- the restored unlock path is verified in game after the crash-fix
- CE now resolves class-definition surfaces for `Job07` through `Job10`, including custom-skill ids, ability ids, per-job equip lists, job parameters, and job-specific controller or selector types
- the current runtime bridge is no longer blind: it can now be tightened against confirmed vocation data

### Current priorities

#### Priority 1. Convert `Job07` from proof-of-mechanism to a grounded progression-aware profile

Need:

- keep the combat bridge, but replace guessed gates with confirmed vocation data
- treat `SpiralSlash` as a core or non-custom `Job07` move unless later CE evidence disproves it
- gate `SkyDive` by confirmed `HumanCustomSkillID 76`
- populate runtime skill-gate state from `SkillContext` equip lists and enabled-state APIs instead of empty placeholders
- extend `Job07` with more confirmed base, core, and custom phases as CE output names and pack paths are verified

Success condition:

- `Job07` chooses between base and advanced phases according to distance, job level, and real equipped or enabled skills

#### Priority 2. Build grounded profiles for `Job08` and `Job09`

Need:

- use confirmed custom-skill bands `80..91` and `92..99`
- map base or core candidates from extracted parameter, input-processor, and selector surfaces
- capture first live combat output for each job and translate the confirmed surfaces into minimal product profiles

Success condition:

- `Job08` and `Job09` each have one non-placeholder combat profile that is grounded in extracted class data, not in guesswork

#### Priority 3. Handle `Job10` as a structural special case

Need:

- keep `Job10` separate from the `07` to `09` path because the extraction shows no observed `Job10InputProcessor`
- determine whether `Warfarer` needs delegated per-weapon behavior, a thinner bridge, or a different fallback path

Success condition:

- `Job10` has an explicit implementation strategy instead of being treated like a normal hybrid profile by default

#### Priority 4. Keep the research loop focused on real phase choice

Need:

- log which phase was selected, which phases were blocked, and which equip or enable signals existed at selection time
- keep CE follow-up narrow and use it only to confirm why the pawn chose one grounded phase over another

Success condition:

- the next CE captures answer concrete profile questions such as "why this phase" and "why blocked", not broad existence questions

### Out of scope for now

Do not do now:

- restore the old research layer
- return broad session or guild trace hooks
- add a new debug UI
- re-enable synthetic adapters in the hot path
- pretend that `Job10` can be implemented by copying the `Job07` to `Job09` path without evidence

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

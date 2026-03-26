# ROADMAP

## English

### Active goal

Make `main_pawn` hybrid vocations look and behave as native-like as possible, while building a reusable combat architecture that can later cover all vocations, not only `Job07` through `Job10`.

### Current stage

The project is now in the CE-grounded, execution-contract stage:

- unlock is restored as product runtime code
- CE scripts now extract vocation definitions, progression state, and class surfaces
- the runtime bridge has already reached real `Job07_*` actions
- the first direct `DragonStinger` run proved that visible animation alone is not enough: some skills need additional native context
- the mod therefore needs execution contracts per skill family, not only skill ids and raw priorities

### Current priorities

#### Priority 1. Formalize execution contracts across the vocation matrix

Need:

- keep `data/vocation_skill_matrix.lua` as the canonical all-job source for ids, families, and progression hints
- extend that matrix with execution-contract knowledge, not only `skill_id -> name`
- use the following working contract classes:
- `direct_safe`
- `carrier_required`
- `controller_stateful`
- `selector_owned`
- start with the full `Job07` family, then carry the same model to `Job08`, `Job09`, `Job10`, and later the original vocations

Success condition:

- the runtime can explain not only what a skill is, but how it must be entered safely

#### Priority 2. Finish `Job07` as the first fully grounded full-family profile

Need:

- keep basic or core attacks as the base combat layer
- keep the current system-first selector, where raw per-skill priority is preserved but no longer dominates the whole fight
- keep `SpiralSlash` as a core or non-custom move unless later CE evidence disproves it
- keep the whole confirmed `Job07` custom-skill family in the profile
- investigate `DragonStinger` through the new unsafe-skill probe modes instead of removing it from the end-state design
- classify each `Job07` skill as safe direct action, carrier-driven, controller-stateful, or selector-owned

Success condition:

- `Job07` fights through ordinary attacks, engagement moves, gap-closing, and skill follow-up in a native-like rhythm, with every custom skill assigned a grounded execution contract

#### Priority 3. Turn probe results into reusable runtime rules

Need:

- keep `unsafe_skill_probe_mode` available for targeted investigation
- use `action_only`, `carrier_only`, and `carrier_then_action` to isolate what native context a crashing or unstable skill actually needs
- keep controller snapshots in logs when a skill appears to be stateful
- convert every confirmed probe result into normal runtime data so the hot path becomes simpler over time

Success condition:

- each resolved probe removes guesswork from the runtime and moves one skill from investigation mode to grounded product behavior

#### Priority 4. Expand the same architecture to `Job08`, `Job09`, and `Job10`

Need:

- build `Job08` and `Job09` from extracted parameter, input-processor, controller, and selector surfaces
- use original vocations `Job01` through `Job06` as the control baseline for “normal” execution behavior
- keep `Job10` separate as a structural special case until its execution contract is better understood

Success condition:

- hybrid jobs no longer depend on `Job07`-specific hacks, and the same system can scale across the full vocation set

### Out of scope for now

Do not do now:

- restore the old broad research layer
- reintroduce wide session or guild trace hooks
- add a new debug UI
- pretend that raw `requestActionCore(...)` is a universal answer for every skill
- treat `Job10` as a copy of `Job07` to `Job09`

### Conditions for returning to broader hooks

Return to broader hooks only if:

- CE scripts and runtime probes already narrowed the question to one transition
- logs and current probes still cannot show the missing context
- a hook is required to prove causality for that single unresolved transition

## Русский

### Активная цель

Сделать hybrid-профессии `main_pawn` максимально нативными по ощущению и внешнему поведению, при этом строя такую боевую архитектуру, которую потом можно будет расширить не только на `Job07` through `Job10`, но и на весь набор профессий.

### Текущий этап

Проект сейчас находится на CE-grounded этапе с execution-contract логикой:

- unlock уже восстановлен как продуктовый runtime-код
- CE scripts уже вытаскивают vocation definitions, progression state и class surfaces
- runtime bridge уже смог дойти до реальных `Job07_*` actions
- первый прямой прогон `DragonStinger` показал, что одной видимой анимации недостаточно: части навыков нужен дополнительный native context
- значит мод теперь должен опираться не только на `skill id` и raw priority, а на execution contract каждого семейства навыков

### Текущие приоритеты

#### Приоритет 1. Формализовать execution contracts по всей vocation matrix

Нужно:

- держать `data/vocation_skill_matrix.lua` каноническим all-job источником для id, families и progression hints
- расширить эту матрицу знаниями об execution contract, а не только связкой `skill_id -> name`
- использовать такие рабочие классы контрактов:
- `direct_safe`
- `carrier_required`
- `controller_stateful`
- `selector_owned`
- начать с полного семейства `Job07`, а потом перенести ту же модель на `Job08`, `Job09`, `Job10`, а позже и на исходные профессии

Условие успеха:

- runtime умеет объяснить не только что это за навык, но и как его надо безопасно запускать

#### Приоритет 2. Довести `Job07` до первого полностью grounded full-family profile

Нужно:

- оставить basic или core атаки базовым слоем боя
- сохранить текущий system-first selector, где raw priority навыка не исчезает, но больше не управляет всем боем в одиночку
- продолжать считать `SpiralSlash` core или non-custom move, пока новое CE evidence не покажет обратное
- держать в профиле всё подтверждённое custom-skill family `Job07`
- расследовать `DragonStinger` через новые unsafe-skill probe-режимы, а не выбрасывать его из конечного дизайна
- классифицировать каждый `Job07` skill как safe direct action, carrier-driven, controller-stateful или selector-owned

Условие успеха:

- `Job07` дерётся в нативном ритме через обычные атаки, engage-мувы, gap-close и skill follow-up, а у каждого custom skill есть grounded execution contract

#### Приоритет 3. Переводить результаты probe в обычные runtime-правила

Нужно:

- оставить `unsafe_skill_probe_mode` как узкий инструмент расследования
- использовать `action_only`, `carrier_only` и `carrier_then_action`, чтобы изолировать тот native context, который реально нужен падающему или нестабильному навыку
- сохранять в логах controller snapshots там, где навык выглядит stateful
- каждый подтверждённый probe-result переносить в обычные runtime-данные, чтобы hot path со временем упрощался

Условие успеха:

- каждый завершённый probe убирает ещё один кусок догадок из runtime и переводит один навык из investigation mode в grounded product behavior

#### Приоритет 4. Расширить ту же архитектуру на `Job08`, `Job09` и `Job10`

Нужно:

- строить `Job08` и `Job09` от extracted parameter, input-processor, controller и selector surfaces
- использовать исходные профессии `Job01` through `Job06` как control baseline для “нормального” execution behavior
- держать `Job10` отдельно как structural special case, пока его execution contract не станет понятнее

Условие успеха:

- hybrid jobs больше не зависят от `Job07`-специфичных костылей, а одна и та же система масштабируется на весь vocation set

### Что сейчас вне области работы

Сейчас не делать:

- возврат старого broad research layer
- возврат широких session или guild trace hooks
- новый debug UI
- делать вид, что raw `requestActionCore(...)` является универсальным ответом для любого навыка
- считать `Job10` простой копией `Job07` through `Job09`

### Когда можно возвращаться к более широким hooks

Возвращаться к более широким hooks только если:

- CE scripts и runtime probes уже сузили вопрос до одного transition
- логи и текущие probes всё ещё не показывают недостающий context
- hook действительно нужен, чтобы доказать причинность именно для этого одного неразрешённого transition

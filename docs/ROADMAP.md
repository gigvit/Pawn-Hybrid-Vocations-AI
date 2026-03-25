# ROADMAP

## English

### Active goal

Make `Job07` usable for `main_pawn` with real combat behavior, not only with unlock or runtime presence.

### Current stage

The project is in the post-cleanup, CE-first stage:

- the mod contains product runtime only
- research is done through CE scripts
- unlock was restored as a product runtime path

### Current priorities

#### Priority 1. Verify the restored unlock path

Need:

- in-game confirmation that `main_pawn` can see and use the intended hybrid unlock state in the guild

Success condition:

- `main_pawn` hybrid unlock works without restoring the old research layer

#### Priority 2. Narrow the `main_pawn Job07` combat gap

Need:

- a focused compare between `main_pawn Job07` and `Sigurd Job07`
- confirmed evidence around selector, admission, context, and pack transition

Success condition:

- one narrow combat-path blocker remains

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

### Текущие приоритеты

#### Приоритет 1. Проверить восстановленный unlock path

Нужно:

- in-game подтверждение, что `main_pawn` видит и использует нужное hybrid unlock state в guild

Условие успеха:

- hybrid unlock для `main_pawn` работает без возврата старого research layer

#### Приоритет 2. Сузить боевой разрыв `main_pawn Job07`

Нужно:

- точечное сравнение `main_pawn Job07` и `Sigurd Job07`
- подтвержденные данные по selector, admission, context и pack transition

Условие успеха:

- остается один узкий combat-path blocker

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

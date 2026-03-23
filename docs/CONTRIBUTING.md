# CONTRIBUTING

## English

### Working Style

This project is research-driven. Changes should move the project toward usable hybrid-vocation AI, not just toward bigger code.

Preferred order:

1. confirm the current hypothesis
2. make the smallest useful code change
3. validate syntax
4. run an in-game scenario
5. update docs and changelog

### Source of Truth Order

When sources disagree, trust them in this order:

1. live runtime behavior
2. project session logs
3. direct engine data inspection
4. local reference mods
5. theory and guesses

### Code Rules

- Keep research code and synthetic AI code separate when possible.
- Prefer narrow, testable changes over broad rewrites.
- Avoid reintroducing live-donor dependency on `Sigurd`.
- Prefer `native-first` reasoning and implementation when choosing between native research and synthetic expansion.
- Treat synthetic `Job07` as fallback, harness, and bounded diagnostic tooling unless the docs explicitly state otherwise.
- Treat `Job07` as a combat-context and carrier problem first, not a pure unlock problem.
- Keep the core AI branch isolated from online pawn-share hooks.
- Use `apply_patch` for manual file edits.

### Consolidation Rules

- Prefer domain consolidation when two sibling modules share the same actors, cadence, and dependency chain.
- Preserve compatibility runtime fields while collapsing sibling modules so logs and UI do not break mid-refactor.
- Do not merge hook-heavy runtime observation with synthetic write-path modules unless there is a strong reason and a clear test plan.

### Validation

Before closing a code change, run Lua syntax validation.

Current local validator:

```powershell
$lua='path\to\luac55.exe'
$root='mod\reframework\autorun\PawnHybridVocationsAI'
$files=Get-ChildItem -LiteralPath $root -Recurse -Filter '*.lua'
foreach($f in $files){ & $lua -p $f.FullName }
```

Expected result:

- `SYNTAX_OK`

### Documentation Rules

- Main docs must stay bilingual.
- English comes first.
- Russian comes second.
- Save documentation as UTF-8.
- Keep docs aligned with actual observed runtime, not outdated plans.

### Licensing and Security

- This repository uses the `MIT` license.
- By contributing, you agree that your changes are provided under the same license.
- If you find a potentially sensitive network/share-side issue, follow [`SECURITY.md`](../SECURITY.md) before posting full details publicly.

### Current Preferred Areas of Work

- repairing native controller/data resolution
- native candidate and native context admission research
- hook verification for newly discovered external-reference hooks
- `Job07` combat carrier adoption
- target tracking and hit-functional behavior
- `_BattleAIData` / `_JobDecisions` inspection
- phase-bound AI data capture and comparison
- phased `Sigurd`-inspired adapter tuning
- offline-safe state lookup and data-layer inspection

### Avoid

- treating unlock as if it solves AI
- treating synthetic `Job07` as the final answer before native research is exhausted
- adding random extra packs without a phase model
- building new UI probes unless they are needed for a concrete question
- reactivating unstable guild UI hooks without a specific reason
- touching `PawnRentalValidator`, `OnlinePawnDataFormatter`, `PawnServerController`, or `PawnApiRequester` in the core AI branch without a very specific isolated reason
- disabling root validator paths such as `validationPlaydata` in the main branch

---

## Русский

### Стиль работы

Этот проект driven by research. Изменения должны двигать проект к usable hybrid-vocation AI, а не просто к росту объёма кода.

Предпочтительный порядок:

1. подтвердить текущую гипотезу
2. внести минимальное полезное изменение в код
3. проверить синтаксис
4. провести игровой сценарий
5. обновить docs и changelog

### Порядок доверия к источникам

Если источники противоречат друг другу, доверять им в таком порядке:

1. live runtime behavior
2. project session logs
3. direct engine data inspection
4. local reference mods
5. theory и guesses

### Правила по коду

- По возможности держать research code и synthetic AI code раздельно.
- Предпочитать узкие, проверяемые изменения широким переписываниям.
- Не возвращать live-donor dependency на `Sigurd`.
- При выборе между native research и расширением synthetic-ветки предпочитать `native-first` reasoning и implementation.
- Рассматривать synthetic `Job07` как fallback, harness и bounded diagnostic tooling, если docs явно не говорят обратное.
- Рассматривать `Job07` прежде всего как проблему combat-context и carrier, а не как чистую unlock-проблему.
- Держать core AI-ветку изолированной от online pawn-share hook-путей.
- Использовать `apply_patch` для ручного редактирования файлов.

### Правила консолидации

- Предпочитать консолидацию доменов, когда у двух соседних модулей одни и те же акторы, одинаковая частота обновления и одна цепочка зависимостей.
- При схлопывании соседних модулей сохранять совместимые runtime-поля, чтобы логи и UI не ломались посреди рефакторинга.
- Не сливать hook-heavy observation-модули с synthetic write-path модулями без сильной причины и ясного плана проверки.

### Валидация

Перед завершением code change нужно прогонять Lua syntax validation.

Текущий локальный валидатор:

```powershell
$lua='path\to\luac55.exe'
$root='mod\reframework\autorun\PawnHybridVocationsAI'
$files=Get-ChildItem -LiteralPath $root -Recurse -Filter '*.lua'
foreach($f in $files){ & $lua -p $f.FullName }
```

Ожидаемый результат:

- `SYNTAX_OK`

### Правила по документации

- Основной комплект docs должен оставаться двуязычным.
- Сначала идёт английский.
- Затем идёт русский.
- Документацию нужно сохранять в UTF-8.
- Docs должны отражать реальный observed runtime, а не устаревшие планы.

### Лицензия и security

- Этот репозиторий использует лицензию `MIT`.
- Отправляя изменения, вы соглашаетесь, что они публикуются под той же лицензией.
- Если вы нашли потенциально чувствительную network/share-side проблему, сначала ориентируйтесь на [`SECURITY.md`](../SECURITY.md), а не публикуйте все детали сразу публично.

### Текущие предпочтительные зоны работы

- починка native controller/data resolution
- исследование native candidate и native context admission
- валидация новых hooks из внешних reference-модов
- `Job07` combat carrier adoption
- target tracking и hit-functional behavior
- inspection `_BattleAIData` / `_JobDecisions`
- phase-bound AI data capture и comparison
- tuning phased `Sigurd`-inspired adapter
- offline-safe state lookup и data-layer inspection

### Чего избегать

- считать, что unlock сам решает AI
- считать synthetic `Job07` финальным ответом до исчерпания native research
- добавлять случайные pack-и без фазовой модели
- строить новые UI probes без конкретного вопроса
- заново активировать нестабильные guild UI hooks без точной причины
- трогать `PawnRentalValidator`, `OnlinePawnDataFormatter`, `PawnServerController` или `PawnApiRequester` в core AI-ветке без очень конкретной и изолированной причины
- отключать root validator пути вроде `validationPlaydata` в основной ветке

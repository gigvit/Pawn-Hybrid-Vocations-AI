# CONTRIBUTING

## English

### Working Style

This project is research-driven. Changes should move the project toward usable hybrid-vocation AI, not just toward more code.

Preferred order:

1. confirm the current hypothesis
2. make the smallest useful change
3. validate syntax
4. run an in-game scenario
5. update docs and changelog

### Source-of-Truth Order

When sources disagree, trust them in this order:

1. live runtime behavior
2. project session logs
3. direct engine data inspection
4. local reference mods
5. theory and guesses

### Code Rules

- Keep research code and synthetic AI code separate when possible.
- Prefer narrow, testable changes over broad rewrites.
- Prefer `native-first` reasoning and implementation when choosing between native research and synthetic expansion.
- Treat synthetic `Job07` as preserved fallback and diagnostic tooling, not as the active default runtime path.
- Treat `Job07` as a combat-context and carrier problem first, not as a pure unlock problem.
- Avoid reintroducing live-donor dependency on `Sigurd` before the native toolchain is stable again.
- Keep the core AI branch isolated from online pawn-share hooks.
- Use `apply_patch` for manual file edits.

### Performance Rules

- Favor cheap semantic summaries over broad object dumps.
- Prefer stable counts and compact signatures over volatile object descriptions.
- Avoid getter-heavy probing on unstable native types in the hot path.
- If a new probe causes FPS collapse, treat that as a bug in the research toolchain and reduce the probe immediately.

### Consolidation Rules

- Prefer domain consolidation when sibling modules share the same actors, cadence, and dependency chain.
- Preserve compatibility runtime fields while collapsing sibling modules so logs and UI do not break mid-refactor.
- Do not merge hook-heavy observation modules with synthetic write-path modules unless there is a strong reason and a clear test plan.

### Validation

Before closing a code change, run Lua syntax validation.

Current local validator example:

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
- Do not remove historical conclusions just because the project pivoted; preserve them and label their current status clearly.
- Do not keep local absolute filesystem paths in public docs.

### Licensing and Security

- This repository uses the `MIT` license.
- By contributing, you agree that your changes are provided under the same license.
- If you find a potentially sensitive network/share-side issue, follow [`SECURITY.md`](../SECURITY.md) before posting full details publicly.

### Current Preferred Areas of Work

- safe native telemetry and decision-pool summaries
- native candidate and native context admission research
- `_BattleAIData` / `_JobDecisions` / `OrderData` inspection
- `Job01` vs `Job07` structural comparison
- role-gating and admission-loss evidence
- hook verification for newly discovered external-reference hooks
- unlock stability and guild-flow safety
- low-overhead data-layer inspection
- later `Sigurd` control-scenario preparation

### Avoid

- treating unlock as if it solves AI
- treating synthetic `Job07` as the final answer before native research is exhausted
- re-expanding synthetic into the default hot path without a bounded reason
- adding random extra packs without a phase model and real gameplay evidence
- building new UI probes unless they answer a concrete question
- reactivating unstable guild UI hooks without a specific reason
- touching `PawnRentalValidator`, `OnlinePawnDataFormatter`, `PawnServerController`, or `PawnApiRequester` in the core AI branch without a very specific isolated reason
- disabling validator paths such as `validationPlaydata` in the main branch

---

## Русский

### Стиль работы

Этот проект driven by research. Изменения должны двигать проект к usable hybrid-vocation AI, а не просто к росту объёма кода.

Предпочтительный порядок:

1. подтвердить текущую гипотезу
2. внести минимально полезное изменение
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
- При выборе между native research и расширением synthetic-ветки предпочитать `native-first` reasoning и implementation.
- Рассматривать synthetic `Job07` как сохранённый fallback и диагностический инструмент, а не как активный runtime path по умолчанию.
- Рассматривать `Job07` прежде всего как проблему combat-context и carrier, а не как чистую unlock-проблему.
- Не возвращать live-donor dependency на `Sigurd`, пока native toolchain снова не станет стабильным.
- Держать core AI-ветку изолированной от online pawn-share hooks.
- Использовать `apply_patch` для ручного редактирования файлов.

### Правила производительности

- Предпочитать дешёвые семантические summary вместо широких object dump.
- Предпочитать стабильные counts и компактные signatures вместо volatile object descriptions.
- Избегать getter-heavy probing на нестабильных native типах в hot path.
- Если новый probe вызывает FPS collapse, считать это багом research toolchain и сразу упрощать probe.

### Правила консолидации

- Предпочитать консолидацию доменов, когда у соседних модулей одни и те же акторы, одинаковая частота обновления и одна цепочка зависимостей.
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
- Нельзя выбрасывать старые проектные выводы только потому, что стратегия изменилась; их нужно сохранять и явно помечать текущий статус.
- В публичных docs не должно оставаться локальных абсолютных путей.

### Лицензия и security

- Этот репозиторий использует лицензию `MIT`.
- Отправляя изменения, вы соглашаетесь, что они публикуются под той же лицензией.
- Если вы нашли потенциально чувствительную network/share-side проблему, сначала ориентируйтесь на [`SECURITY.md`](../SECURITY.md), а не публикуйте детали сразу.

### Текущие предпочтительные зоны работы

- safe native telemetry и decision-pool summaries
- исследование native candidate и native context admission
- inspection `_BattleAIData` / `_JobDecisions` / `OrderData`
- структурное сравнение `Job01` vs `Job07`
- evidence по role-gating и admission-loss
- валидация новых hooks из внешних reference-источников
- стабильность unlock и безопасность guild-flow
- low-overhead data-layer inspection
- позже — подготовка `Sigurd` как control scenario

### Чего избегать

- считать, что unlock сам решает AI
- считать synthetic `Job07` финальным ответом до исчерпания native research
- снова раздувать synthetic до default hot path без ограниченной причины
- добавлять случайные packs без фазовой модели и подтверждения геймплеем
- строить новые UI probes без конкретного вопроса
- заново активировать нестабильные guild UI hooks без точной причины
- трогать `PawnRentalValidator`, `OnlinePawnDataFormatter`, `PawnServerController` или `PawnApiRequester` в core AI-ветке без очень конкретной и изолированной причины
- отключать validator paths вроде `validationPlaydata` в основной ветке

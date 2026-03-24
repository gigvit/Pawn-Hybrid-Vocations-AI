# SECURITY

## English

### Scope

`Pawn Hybrid Vocations AI` is a local-runtime-first REFramework mod and research project.

The main branch is intentionally designed to avoid online or pawn-share hot paths.

### What Counts as a Security Issue

Please report issues that may:

- affect online or pawn-share behavior unexpectedly
- touch upload, download, rental, or validator code paths in unsafe ways
- expose a way to corrupt saves, progression, or persistent pawn state
- create clearly dangerous unintended behavior outside the expected local-mod scope

Examples of sensitive paths for this project:

- `app.PawnRentalValidator`
- `app.OnlinePawnDataFormatter`
- `app.PawnServerController`
- `app.network.PawnApiRequester`
- validator paths such as `validationPlaydata`

### How to Report

For potentially sensitive issues, please avoid posting full exploit details in a public issue first.

Preferred first contact:

- open a GitHub issue with a minimal description and mark it as security-related
- or contact the maintainer privately first if private contact details are available

### What Is Usually Not a Security Issue

The following are usually normal bug reports, not security issues:

- AI behavior regressions
- broken combat adapters
- missing native `Job07` behavior
- UI/debug window issues
- logging noise or missing research events

### Current Security Posture

Current project rule set:

- keep the core AI branch local-runtime-first
- keep online-aware work isolated, opt-in, and disabled by default
- avoid network/share hooks in the hot path unless there is a very specific reason
- keep experimental synthetic write-paths out of the default hot path unless they are part of a bounded test

---

## Русский

### Область действия

`Pawn Hybrid Vocations AI` — это local-runtime-first REFramework-мод и исследовательский проект.

Основная ветка намеренно устроена так, чтобы не трогать online- и pawn-share hot path.

### Что считать security issue

Пожалуйста, сообщайте о проблемах, которые могут:

- неожиданно затрагивать online или pawn-share поведение
- небезопасно заходить в upload, download, rental или validator code path
- создавать риск порчи сохранений, progression или persistent pawn state
- вызывать явно опасное unintended behavior вне ожидаемого локального scope мода

Примеры чувствительных путей для этого проекта:

- `app.PawnRentalValidator`
- `app.OnlinePawnDataFormatter`
- `app.PawnServerController`
- `app.network.PawnApiRequester`
- validator paths вроде `validationPlaydata`

### Как репортить

Для потенциально чувствительных проблем лучше не публиковать полный exploit detail сразу в публичном issue.

Предпочтительный первый шаг:

- открыть GitHub issue с минимальным описанием и пометить его как security-related
- или сначала связаться с maintainer приватно, если приватные контакты доступны

### Что обычно не является security issue

Следующее обычно относится к обычным bug report, а не к security:

- регрессии AI-поведения
- сломанные combat adapters
- отсутствие native `Job07` behavior
- проблемы UI/debug window
- шум в логах или пропавшие research events

### Текущая security-позиция

Текущий набор правил проекта:

- держать core AI branch local-runtime-first
- выносить online-aware работу в отдельные opt-in модули, выключенные по умолчанию
- не использовать network/share hooks в hot path без очень конкретной причины
- держать экспериментальные synthetic write-paths вне default hot path, если они не нужны для ограниченного теста

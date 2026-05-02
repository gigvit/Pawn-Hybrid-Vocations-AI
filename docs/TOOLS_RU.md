# Logs, Content Editor И Захват Данных

Этот документ заменяет прежние отдельные инструкции по CE, DevTools и external capture.

## Правило Безопасности

Codex работает только в папке проекта.

Папка игры используется как read-only источник:

- runtime logs
- CE dumps
- crash evidence
- DevTools traces

Установку в игру выполняет пользователь вручную.

## Runtime Logs

Новая canonical-версия пишет сюда:

```text
reframework/data/PawnHybridVocationsAI/logs/PawnHybridVocationsAI.session_<timestamp>.log
```

Смотреть:

- `Bootstrapping Pawn Hybrid Vocations AI 2.0.0-alpha23-archive`
- `JobXX target`
- `JobXX selector`
- `JobXX start`
- `JobXX executor`
- `JobXX damage`
- `Job07 bind_chain`
- `Job07 direct_damage_fallback`
- `JobXX snapshot`

Если после архивации видны `PawnHybridVocationsAIv2` logs, значит в игре установлен старый билд.

## Content Editor

Если Content Editor установлен, мод добавляет вкладку:

```text
Pawn Hybrid Capture
```

Основные действия:

- `Dump ALL jobs static snapshot`: статический снимок Job01-10, params, skills, action candidates.
- `Dump attack graph research`: быстрый снимок поверх текущего graph/runtime.
- `Dump current attack frame`: один frame текущего боя.
- `Start attack trace` / `Stop attack trace and dump`: live trace для action/FSM/hit window.

Дампы пишутся в:

```text
reframework/data/ce_dump/PawnHybridVocationsAI_<label>_<timestamp>.json
```

## Nick DevTools

Использовать только как внешний live-inspection инструмент:

- смотреть controller state
- смотреть action/FSM surfaces
- сравнивать target/decision data
- исследовать DragonStinger и controller-stateful skills

Не превращать DevTools в runtime dependency.

## Bestiary Reference

Bestiary остаётся архитектурным эталоном, потому что он заставляет монстров исполнять не родные атаки через:

- weighted selector
- custom executor
- tracking/rotation
- interrupt suppression
- authored move definitions
- direct engine-side effects where needed

Наш мод не копирует Bestiary буквально, но следует тому же принципу: move должен быть owned на протяжении sequence, а не просто запущен одним action call.

## Минимальный Debug Цикл

1. Запустить игру с canonical `PawnHybridVocationsAI`.
2. Проверить bootstrap version в логе.
3. В бою с Job07 записать 30-60 секунд.
4. Если поведение плохое, сохранить свежий session log.
5. Если нужна структура данных, снять CE snapshot.
6. Если нужен frame-level timing, снять attack trace.
7. По логу классифицировать сбой: target, availability, selector, executor, output, hit/damage, chain, recovery, crash safety.

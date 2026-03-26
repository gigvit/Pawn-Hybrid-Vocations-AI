# Pawn Hybrid Vocations AI

## English

### What this project is

`Pawn Hybrid Vocations AI` is a REFramework mod for `Dragon's Dogma 2`.

The mod keeps only product runtime code:

- `player` and `main_pawn` runtime resolution
- progression and job-bit state
- hybrid unlock path for `main_pawn`
- minimal guild-side hybrid job info override
- future confirmed runtime fixes for hybrid-vocation behavior

Research and diagnostics are done through CE Console scripts in `docs/ce_scripts/`.

### Why this project exists

The project exists because hybrid vocations for `main_pawn` are not solved by unlock alone.

Project invariant:

`unlock != equipment != skills != combat runtime != pawn combat context != AI parity`

Current main target:

- make hybrid jobs `Job07` through `Job10` usable for `main_pawn` with progression-aware combat behavior
- use `Job07` as the first fully grounded combat profile and template for the later hybrid jobs

### Quick start

1. Install REFramework for `Dragon's Dogma 2`.
2. Copy the contents of `mod/` into the game's REFramework directory.
3. Launch the game.
4. Open a vocation guild and verify that `main_pawn` sees the expected hybrid unlock state.
5. If you need diagnostics, run the CE scripts from `docs/ce_scripts/`.

### Usage example

Typical runtime use:

1. Qualify the player for a hybrid vocation such as `Job07`.
2. Open the guild menu for `main_pawn`.
3. The mod mirrors the required hybrid access bit to `main_pawn` and enables the guild-side job info path needed for selection.

Typical research use:

1. Open CE Console.
2. Run one focused CE script such as `docs/ce_scripts/vocation_definition_surface_screen.lua` or `docs/ce_scripts/main_pawn_output_bridge_burst.lua`.
3. Let the trace write a JSON file.
4. Use `docs/KNOWLEDGE_BASE.md` as the source of truth for interpretation.

### Repository guide

- Main source of truth: `docs/KNOWLEDGE_BASE.md`
- Workflow and project rules: `docs/CONTRIBUTING.md`
- Future plans: `docs/ROADMAP.md`
- Change history: `docs/CHANGELOG.md`

## Русский

### Что это за проект

`Pawn Hybrid Vocations AI` - это REFramework-мод для `Dragon's Dogma 2`.

В моде оставлен только продуктовый runtime-код:

- разрешение `player` и `main_pawn`
- состояние progression и job bits
- hybrid unlock path для `main_pawn`
- минимальный guild-side override для hybrid job info
- будущие подтвержденные runtime-фиксы для hybrid-vocation behavior

Исследование и диагностика выполняются через CE Console scripts в `docs/ce_scripts/`.

### Зачем нужен проект

Проект нужен потому, что hybrid-профессии для `main_pawn` не сводятся только к unlock.

Инвариант проекта:

`unlock != equipment != skills != combat runtime != pawn combat context != AI parity`

Текущая главная цель:

- сделать `Job07` пригодным для `main_pawn` в реальном бою

### Быстрый старт

1. Установить REFramework для `Dragon's Dogma 2`.
2. Скопировать содержимое `mod/` в директорию REFramework игры.
3. Запустить игру.
4. Открыть guild menu и проверить, что `main_pawn` видит ожидаемое состояние unlock для hybrid vocation.
5. Если нужна диагностика, запускать CE scripts из `docs/ce_scripts/`.

### Пример использования

Обычное использование runtime:

1. Открыть игроку hybrid-профессию, например `Job07`.
2. Открыть guild menu для `main_pawn`.
3. Мод зеркалит нужный hybrid access bit в `main_pawn` и включает guild-side path, нужный для выбора профессии.

Обычное использование исследования:

1. Открыть CE Console.
2. Запустить `docs/ce_scripts/actor_burst_combat_trace.lua`.
3. Дождаться записи JSON-файла.
4. Использовать `docs/KNOWLEDGE_BASE.md` как основной источник интерпретации.

### Навигация по репозиторию

- Основной источник знаний: `docs/KNOWLEDGE_BASE.md`
- Правила работы с проектом: `docs/CONTRIBUTING.md`
- Планы развития: `docs/ROADMAP.md`
- История изменений: `docs/CHANGELOG.md`

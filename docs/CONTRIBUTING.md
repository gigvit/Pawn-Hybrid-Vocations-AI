# CONTRIBUTING

## English

### Workflow

Use this order for non-trivial work:

1. define the goal
2. narrow the question
3. decide whether the task belongs to `mod/` or to CE research
4. make the smallest useful change
5. verify the result
6. update documentation
7. update `CHANGELOG.md`

Use `mod/` for:

- product runtime behavior
- confirmed implementation
- narrow product-scoped hooks that are part of the feature

Use CE scripts for:

- research
- diagnostics
- compare work
- one-off runtime inspection

### Coding rules

- keep the product runtime small
- do not reintroduce the old research layer into the hot path
- prefer narrow fixes over broad rewrites
- keep unlock logic separate from combat-AI claims
- treat `Job07` as a selector/admission/context problem until data proves otherwise
- keep online and pawn-share logic out of the core branch
- prefer compact summaries over expensive reflective probing
- use UTF-8 for documentation files

### CE script rules

Each CE script must:

- solve one concrete task
- write its result to file
- be reproducible
- emit data that can be compared later

CE script outputs belong in `ce_dump`.

Do not use console text alone as the final source of evidence.

### Documentation rules

The allowed project documentation set is:

- `README.md`
- `docs/KNOWLEDGE_BASE.md`
- `docs/CONTRIBUTING.md`
- `docs/ROADMAP.md`
- `docs/CHANGELOG.md`

Do not add new standalone documentation files under `docs/` outside this set.

Exceptions:

- repository and Git/GitHub support files
- generated `ce_dump` outputs
- CE Lua scripts in `docs/ce_scripts/`

If temporary documentation appears outside the allowed set, move its useful content into the allowed files and remove the temporary file.

Role rules:

- `README.md` stays minimal
- `KNOWLEDGE_BASE.md` is the main source of truth
- `ROADMAP.md` contains future work only
- `CHANGELOG.md` records changes
- keep the main documentation bilingual, with English first and Russian second

### Documentation update rules

After a significant change:

1. update `KNOWLEDGE_BASE.md`
2. update `ROADMAP.md` if priorities changed
3. update `CHANGELOG.md`
4. update `README.md` only if the entry point, quick start, or usage example changed

### Validation

Before closing a code change:

- review the changed Lua files
- run syntax validation if a local Lua validator exists
- test the feature in game when the change affects runtime behavior

Current practical note:

- in this environment `lua/luac` may be unavailable, so in-game validation through REFramework can be the only available check

## Русский

### Workflow

Для нетривиальной работы использовать такой порядок:

1. определить цель
2. сузить вопрос
3. решить, относится ли задача к `mod/` или к CE research
4. внести минимально полезное изменение
5. проверить результат
6. обновить документацию
7. обновить `CHANGELOG.md`

Использовать `mod/` для:

- продуктового runtime behavior
- подтвержденной реализации
- узких product-scoped hooks, которые являются частью фичи

Использовать CE scripts для:

- исследования
- диагностики
- compare-задач
- разового runtime inspection

### Правила по коду

- держать продуктовый runtime маленьким
- не возвращать старый research layer в hot path
- предпочитать узкие фиксы широким переписываниям
- держать unlock logic отдельно от утверждений про combat AI
- считать `Job07` проблемой selector/admission/context, пока данные не докажут иное
- держать online и pawn-share logic вне core branch
- предпочитать компактные summaries дорогому reflective probing
- сохранять файлы документации в UTF-8

### Правила для CE scripts

Каждый CE script должен:

- решать одну конкретную задачу
- писать результат в файл
- быть воспроизводимым
- выдавать данные, пригодные для последующего сравнения

Выходы CE scripts должны попадать в `ce_dump`.

Нельзя использовать только текст из консоли как финальный источник доказательств.

### Правила по документации

Разрешенный комплект документации проекта:

- `README.md`
- `docs/KNOWLEDGE_BASE.md`
- `docs/CONTRIBUTING.md`
- `docs/ROADMAP.md`
- `docs/CHANGELOG.md`

Не добавлять новые standalone doc-файлы в `docs/` вне этого набора.

Исключения:

- repository и Git/GitHub support files
- generated `ce_dump` outputs
- CE Lua scripts в `docs/ce_scripts/`

Если временная документация появилась вне разрешенного набора, полезное содержимое нужно перенести в разрешенные файлы, а временный файл удалить.

Правила ролей:

- `README.md` остается кратким
- `KNOWLEDGE_BASE.md` является главным источником истины
- `ROADMAP.md` содержит только future work
- `CHANGELOG.md` фиксирует изменения
- основной комплект документации остается двуязычным: сначала English, затем Russian

### Правила обновления документации

После значимого изменения:

1. обновить `KNOWLEDGE_BASE.md`
2. обновить `ROADMAP.md`, если поменялись приоритеты
3. обновить `CHANGELOG.md`
4. обновить `README.md` только если изменились entry point, quick start или usage example

### Валидация

Перед завершением code change:

- просмотреть измененные Lua files
- запустить syntax validation, если локальный Lua validator существует
- проверить фичу в игре, если изменение влияет на runtime behavior

Текущая практическая оговорка:

- в этой среде `lua/luac` может отсутствовать, поэтому единственной доступной проверкой может быть in-game validation через REFramework

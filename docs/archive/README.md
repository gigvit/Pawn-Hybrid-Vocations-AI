# Historical Knowledge Archive

Эта папка хранит длинную базу знаний проекта. Верхнеуровневые документы в `docs/` являются текущим entry point, а файлы здесь нужны для глубокого восстановления контекста.

Это не мусорная папка и не кандидат на автоматическое удаление. Архив содержит историю решений, гипотез, ошибок, live-evidence, CE/DevTools выводов, Bestiary-разбора и причин перехода к graph/executor архитектуре.

## Как Читать

1. Сначала открыть `docs/ARCHIVE_HANDOFF_RU.md`.
2. Затем открыть `docs/ATTACK_GRAPHS_RU.md` и `docs/TOOLS_RU.md`.
3. Если нужно понять, почему было принято решение, искать здесь.
4. Если архив противоречит текущим top-level документам, считать архив историческим свидетельством, а не текущей инструкцией.

## Состав

- `KNOWLEDGE_BASE_RU.md`: основная русская база. Темы: модель проекта, состояние unlock, target/runtime выводы, CE scripts, skill-state surfaces, lifecycle labels, output-state families, Bestiary analysis.
- `KNOWLEDGE_BASE_EN.md`: английский срез базы. Темы: source-of-truth order, code audit snapshot, combat findings, execution contracts, grounded surfaces, external Bestiary analysis.
- `KNOWLEDGE_BASE_LEGACY.md`: самый старый объединённый legacy snapshot до финальной консолидации. Содержит английский и русский исторические блоки.

## Что Считать Историческим

В архиве могут встречаться старые имена и пути: `mod_v2`, `PawnHybridVocationsAIv2`, `hybrid_combat_fix`, старые CE scripts и прежние docs files. Это важно сохранить как контекст, но не нужно использовать как актуальную структуру проекта.

Текущая структура после архивации:

```text
mod/                         canonical installable mod
docs/ARCHIVE_HANDOFF_RU.md   current state and restart plan
docs/ATTACK_GRAPHS_RU.md     current attack graph/combat brain reference
docs/TOOLS_RU.md             current logs/CE/DevTools workflow
docs/archive/                preserved historical knowledge
```

## Правило Чистки

Разрешено добавлять индекс, переносить выводы в короткие документы и помечать сведения как исторические. Нельзя удалять knowledge base файлы только потому, что они большие или повторяют часть текущих документов.

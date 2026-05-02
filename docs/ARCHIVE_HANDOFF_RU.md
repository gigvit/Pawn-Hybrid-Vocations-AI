# Архивный Handoff

Дата архивации: `2026-05-02`

Финальная рабочая ветка в репозитории: `main`

Единственная installable-версия: `mod/`

Версия мода: `2.0.0-alpha23-archive`

## Итоговое Решение

Проект законсервирован как одна цельная версия. Старое дерево `mod/` и экспериментальное `mod_v2/` больше не существуют как две параллельные ветки: актуальный код из `mod_v2` перенесён в канонический `mod/`, namespace снова называется `PawnHybridVocationsAI`, а `PawnHybridVocationsAIv2` удалён из runtime-путей.

Мы не считаем проект завершённым по gameplay-качеству. Это архивный snapshot для будущего возврата: код собран в одну понятную форму, документация верхнего уровня сокращена до handoff-уровня, а длинные historical knowledge bases сохранены в `docs/archive/`.

## Что Доказано

- Unlock hybrid jobs сам по себе не даёт пешке нативный бой.
- Пешка может входить в кастомный combat layer через REFramework hooks и runtime context.
- `Job07` реально достигает `Job07_*` actions, concrete packs и Magic Bind shell telemetry.
- Bestiary-style подход полезен: нужен не одиночный `requestActionCore`, а selector, executor, target ownership, cooldowns, chain-state и telemetry.
- Damage pipeline работает для части gapclose/native events.
- Core melee Job07 может проигрывать output/FSM без native damage event.
- `DragonStinger` опасен: live execution падал в `app.Job07DragonStinger.update`.

## Текущая Архитектура

```text
main pawn runtime context
-> target resolver/cache
-> attack_graphs.get(CurrentJob)
-> combat_brain score/select
-> hybrid_executor sequence
-> interrupt_guard/target hold
-> combat_telemetry/damage/direct fallback
-> cooldown/recovery/next decision
```

Главные runtime-файлы:

- `mod/reframework/autorun/PawnHybridVocationsAI/bootstrap.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/config.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_combat.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/combat_brain.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/hybrid_executor.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/combat_telemetry.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/game/direct_damage.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/data/attack_graphs.lua`
- `mod/reframework/autorun/PawnHybridVocationsAI/data/job07_moves.lua`

## Историческая База Знаний

Для быстрого входа читать этот handoff, `docs/ATTACK_GRAPHS_RU.md` и `docs/TOOLS_RU.md`.

Для глубокого восстановления контекста читать:

- `docs/archive/KNOWLEDGE_BASE_RU.md`
- `docs/archive/KNOWLEDGE_BASE_EN.md`
- `docs/archive/KNOWLEDGE_BASE_LEGACY.md`

Эти файлы специально оставлены как архив решений, ошибок, live-evidence и прежних гипотез. Они не являются текущей инструкцией к разработке, но сохраняют историю того, почему проект пришёл к graph/executor/Bestiary-style архитектуре.

## Текущее Поведение

`Job07` является единственным по-настоящему grounded combat pilot.

Текущее состояние:

- В бой пешка входит лучше, чем в ранних версиях.
- Graph router работает для `Job01-Job10`.
- Selector уже видит стадии, cooldowns, lockouts, chain phases и failure memory.
- Bind больше не должен открывать follow-up после простого промаха: follow-up ждёт `bolt_hit`.
- Gapclose расширен до дальних дистанций, чтобы уменьшить `move=none`.
- Melee имеет `direct_damage_fallback`, если output подтверждён, но native hit не пришёл.

Ограничения:

- Это не native-quality AI.
- Direct fallback является практическим мостом, а не идеальным решением.
- Не все custom skills live-validated.
- Не все графы имеют точные animation/hit windows.

## Если Возвращаться К Проекту

Рекомендуемый порядок:

1. Установить `mod/` в игру и проверить, что лог пишет `PawnHybridVocationsAI.session_*.log`.
2. Протестировать `Job07` с простыми врагами.
3. Проверить в логе `selector`, `start`, `executor`, `damage`, `bind_chain`, `direct_damage_fallback`.
4. Если melee HP двигается только через fallback, продолжить исследование native hit conversion.
5. Не включать `allow_crash_prone_moves` для обычной игры.
6. DragonStinger исследовать отдельной сборкой с максимально подробным controller snapshot.
7. После Job07 переходить к `Job10`, но учитывать weapon-dependent поведение Warfarer.

## Что Не Делать

- Не возвращать параллельные `mod/` и `mod_v2/`.
- Не смешивать старые `PawnHybridVocationsAIv2` логи с новой canonical-версией.
- Не считать прямой вызов action универсальным решением.
- Не удалять safety-gate с DragonStinger без отдельной исследовательской цели.

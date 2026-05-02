# Attack Graphs И Combat Brain

Этот документ заменяет прежнюю россыпь заметок про атаки. Он фиксирует только то, что нужно для будущего возврата к разработке.

## Модель Графа

Каждый класс имеет отдельный graph file:

```text
data/job01_moves.lua
...
data/job10_moves.lua
```

Router:

```text
data/attack_graphs.lua
```

Каждый move может содержать:

- `key`, `family`, `label`
- `selection`: роль, bucket, дистанции, приоритет, required skill, chain conditions
- `availability`: проверка custom skill / equipped / learned / enabled
- `damage`: expected damage kind, target match, fallback/assist settings
- `entry`: action name, action layer, action priority, optional ActInter pack
- `sequence`: authored executor steps
- `chain`: grant/clear follow-up state
- `brain`: lockout/recovery hints
- `stability`: safety class, включая `crash_prone`

## Executor Steps

Поддерживаемые шаги:

- `bridge`: применить action/pack entry через `hybrid_payloads`.
- `wait_output`: дождаться native output token в action/FSM/decision surfaces.
- `hold_target`: удерживать active target и optionally reissue entry.
- `wait_damage`: держать active move открытым для hit/damage telemetry.
- `end`: завершить move, записать outcome и cooldown.

Outcome vocabulary:

- `hit_confirmed`
- `wrong_target`
- `hit_unmatched`
- `no_damage_window`
- `output_confirmed`
- `output_timeout`
- `timed_out`
- `failed`
- `aborted`

## Combat Brain

`game/combat_brain.lua` работает не только с Job07. Он получает текущий graph и оценивает moves через:

- target distance
- stage (`opener`, `ranged_or_gapclose`, `close_in`, `melee_probe`, `follow_through`, etc.)
- cooldowns
- chain phase
- last move/family
- recent outcomes
- move lockout
- safety gates
- skill availability

Это ещё не идеальный мозг, но это правильная точка продолжения. Не возвращаться к плоскому “самый высокий priority всегда побеждает”.

## Job07 Состояние

Grounded nodes:

| Move | Состояние |
|---|---|
| `job07_magic_bind_bolt` | старт Bind, priority 78, lockout 10.5s, follow-up только от real `bolt_hit` |
| `job07_magic_bind_just_explosion` | требует `bolt_hit`, открывает `bind_confirmed` |
| `job07_magic_bind_leap` | требует `bind_confirmed`, закрывает цепочку |
| `job07_gapclose_run_blade` | gapclose через `ch300_job07_Run_Blade4.user`, 3.25-35m |
| `job07_gapclose_run_attack` | gapclose через `ch300_job07_RunAttackNormal.user`, 3-24m |
| `job07_short_attack` | `Job07_NormalAttack`, native hit unreliable, fallback 64 |
| `job07_heavy_attack` | `Job07_HeavyAttack`, native hit unreliable, fallback 92 |
| `job07_spiral_slash` | pack + `Job07_SpiralSlash`, native hit unreliable, fallback 110 |
| `job07_dragon_stinger` | present but `crash_prone`, blocked by default |

Important Job07 rule:

`MagicBindJustLeap` must not fire freely. It belongs after:

```text
MagicBindComplete -> bind shell hit -> JustExplosion -> JustLeap
```

## Damage Notes

Native damage telemetry is hooked through:

- `app.HitController.calcDamageValue`
- `app.HitController.damageProc`
- `app.HitController.calcDamageReaction`
- `app.Job07MagicBindShell.Hit_AttackHitHandler` when available

`direct_damage_fallback` exists because Job07 melee can reach visible output without producing a native hit event. It is gated by:

- move opted in via graph data
- output confirmed
- target valid
- target was close enough during the move
- no native damage arrived during `wait_damage`

If future work finds native hit conversion, prefer native hit over fallback.

## Safety Notes

- `DragonStinger` remains blocked unless `config.combat.allow_crash_prone_moves = true`.
- Do not enable crash-prone moves in normal runtime.
- Keep logs flushed around crash-prone experiments.
- Treat controller-stateful skills as separate research, not normal selector nodes.

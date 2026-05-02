# Pawn Hybrid Vocations AI

REFramework mod for `Dragon's Dogma 2`.

Archive version: `2.0.0-alpha23-archive`

This repository is now consolidated into one canonical mod version. The old experimental split between `mod/` and `mod_v2/` has been removed; `mod/` is the only installable mod tree.

## What This Mod Tries To Do

The goal is to let the main pawn use hybrid vocations and fight through a bounded custom combat layer.

The project moved away from the early assumption that unlocking a hybrid vocation would automatically give pawns native combat behavior. The current architecture is closer to a Bestiary-style combat takeover:

```text
native pawn context
-> target and combat perception
-> current job attack graph
-> condition/stage selector
-> authored executor sequence
-> hit/damage/follow-up telemetry
-> cooldown, recovery, next decision
```

`Job07` remains the grounded pilot. Graph files for `Job01` through `Job10` exist so future development can continue from an all-job model rather than another Job07-only rewrite.

## Current State

Working or implemented:

- Hybrid vocation access is unlocked without intentionally cloning the player's vocation level.
- Pawn progression/loadout reads `JobContext`, `SkillContext`, equipped custom skills, learned skills and availability.
- Combat uses one graph router: `CurrentJob -> data/attack_graphs.lua -> data/jobXX_moves.lua`.
- The all-job `Combat Brain` scores moves by stage, cadence, outcome memory, cooldowns, lockouts and safety gates.
- `Job07` has authored core, gapclose, Magic Bind and custom-skill nodes.
- `MagicBindComplete -> bolt_hit -> JustExplosion -> JustLeap` is modeled as a chain instead of unconditional teleport spam.
- `DragonStinger` remains present in the graph but blocked by default because live testing crashed in `app.Job07DragonStinger.update`.
- A gated `direct_damage_fallback` exists for Job07 core melee when output is confirmed but native hit conversion fails.
- Content Editor integration is included as a dev-only capture helper, not as a runtime dependency.

Still unresolved:

- The pawn does not yet have fully native-quality hybrid combat behavior.
- Job07 melee native damage conversion is still unreliable; alpha23 uses direct fallback as a practical bridge.
- Most non-Job07 graphs are structural and need live validation.
- Exact animation assets and frame-perfect hit windows are not fully mapped.
- DragonStinger needs a controller-stateful investigation before it can be safely enabled.

## Install

1. Install REFramework for `Dragon's Dogma 2`.
2. Copy the contents of `mod/` into the game root.
3. The game root should contain `modinfo.ini` and `reframework/autorun/PawnHybridVocationsAI.lua`.
4. Do not install any older `PawnHybridVocationsAIv2` build at the same time.
5. Test with `Job07` first.

## Runtime Logs

The mod writes session logs to:

```text
reframework/data/PawnHybridVocationsAI/logs/PawnHybridVocationsAI.session_<timestamp>.log
```

Important log markers:

- `JobXX target`: target source and target distance.
- `JobXX selector`: chosen move, stage, candidate score and blocked reasons.
- `JobXX start`: executor started a move.
- `JobXX executor`: move outcome, damage summary and cooldown result.
- `JobXX damage`: native pawn damage telemetry.
- `Job07 bind_chain`: Magic Bind hit-confirm chain state.
- `Job07 direct_damage_fallback`: controlled fallback damage for Job07 melee.
- `JobXX snapshot`: periodic combat/context snapshot.

## Repository Layout

```text
mod/                         installable REFramework mod
docs/ARCHIVE_HANDOFF_RU.md   current state, risks and restart plan
docs/ATTACK_GRAPHS_RU.md     graph/executor model and Job07 attack notes
docs/TOOLS_RU.md             CE, logs and capture workflow
docs/CHANGELOG.md            condensed project history
docs/archive/                preserved long-form knowledge bases
```

Historical long-form research is preserved under `docs/archive/`. The short top-level docs are the recommended entry point; the archive files are for deep context recovery.

## Development Rules

- Work inside this repository, not in the game folder.
- Treat the game folder as read-only evidence unless manually installing a release for testing.
- Keep `mod/` as the only active implementation.
- Preserve crash-prone safety gates unless doing a dedicated research build.
- Prefer graph data and guarded runtime code over ad hoc combat special cases.

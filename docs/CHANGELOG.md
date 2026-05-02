# Changelog

## 2026-05-02 Archive Consolidation

- Consolidated the repository into one canonical installable mod under `mod/`.
- Removed the parallel `mod_v2/` development tree from the working layout.
- Renamed the runtime namespace back from `PawnHybridVocationsAIv2` to `PawnHybridVocationsAI`.
- Renamed logs and CE dumps to canonical `PawnHybridVocationsAI` prefixes.
- Reduced documentation to archive handoff, attack graph reference, tooling guide and condensed changelog.
- Preserved historical details through Git history instead of keeping large duplicated knowledge-base files in the working tree.

## 2026-04-30 Alpha23

- Added gated `direct_damage_fallback` for Job07 melee when output is confirmed but native hit conversion fails.
- Removed synthetic `bolt_released` grant from `MagicBindComplete`; Bind follow-up now depends on real `bolt_hit`.
- Reduced Bind reopen priority and increased lockout.
- Extended Job07 gapclose distance windows to reduce selector `move=none` stalls.

## 2026-04-30 Alpha21-22

- Generalized the Job07 combat brain into an all-job graph-backed `Combat Brain`.
- Added `wait_damage` executor step.
- Added data-driven move lockouts.
- Improved executor outcome vocabulary and logging.

## 2026-04-29 Alpha18-20

- Introduced explicit Job07 attack graph and then separate `Job01` through `Job10` graph files.
- Added `attack_graphs.lua` router.
- Added first stage-aware Job07 brain.
- Added Content Editor capture helper for all-job snapshots and attack traces.

## Earlier Work

- Built the original hybrid vocation unlock path.
- Moved from monolithic `hybrid_combat_fix` experimentation toward graph/executor architecture.
- Established Bestiary as the closest practical reference for non-native attack execution.
- Confirmed that DragonStinger is crash-prone in direct runtime execution.

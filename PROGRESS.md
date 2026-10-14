# Progress

## Milestone 0 — project skeleton ✅
- Folder structure (`scenes/ scripts/{player,enemies,combat,ui,world,systems} resources/ assets/ tests/ tools/`).
- `project.godot`: Forward+, Jolt, physics interpolation, physics layer names, autoloads, Input Map (keyboard + mouse +
  gamepad for every action), global shader uniforms.
- Autoloads: `Settings`, `GameState`, `SaveSystem`, `AudioManager`, `HitStop`, `CameraShake`, `Vfx`, `DebugOverlay`.
- Data resources generated: AttackData / EnemyAttackData / EnemyData / PlayerStats / BalanceConfig / LevelingConfig /
  AnimationMap.
- Verification: `godot --headless --import` clean, `godot --headless --quit-after 60` clean,
  `sh tools/check.sh` → 33 scripts, 0 warnings/errors.

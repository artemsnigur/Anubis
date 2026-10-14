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

## Milestone 1 — player, camera, test arena ✅
- `Combatant` base (local hitstop via manual AnimationTree advance, knockback, flash, procedural layers).
- Hero placeholder rig: ushabti figurine (faience shader with kintsugi gold veins, lapis wig, usekh collar,
  procedural khopesh mesh). 20+ generated clips (idle/walk/run, 3 light attacks, heavy windup/charge/release,
  dodge roll, hits, death, heal, cast, rest, grabbed, interact) with anticipation, squash & stretch.
- AnimationTree: state machine + BlendSpace1D locomotion, built from the `AnimationMap` resource.
- Player states: Move, Attack (3-hit chain), Heavy (chargeable), Dodge (i-frames, passes through enemies),
  Cast (Eye of Ra), Heal (Ankh), Hurt, Grabbed, Busy, Dead. Input buffer 0.15 s, cancel windows, aim assist.
- `GameCamera`: 35° FOV, 52° pitch, 45° yaw, 14 m, ortho toggle, damped follow + look-ahead (movement, aim,
  lock target), zoom, trauma² FastNoiseLite shake scaled by the settings slider.
- Dithered occlusion fade of walls/columns between camera and player (verified on screenshots).
- Level kit (walls, lotus columns, stairs with ramp colliders, obelisks, statues, torches, braziers, arches).
- Tests: `tests/player_motion_test.tscn` (run speed 6.0 m/s, full speed in 0.1 s, stop in <0.12 s, dodge ≈4.5 m,
  i-frames 0.217 s, chain to hit 3, dodge-cancel) — all PASS. `tests/smoke_test.tscn` runs 10 s with a bot.
- Visual harness: `tests/visual/capture.tscn` and `tests/visual/pose_sheet.tscn` render screenshots in a window.

## Milestone 2 — combat core ✅
- Light chain / heavy charge / Eye of Ra / heal fully wired to hitboxes (`HitboxComponent` shape queries,
  hit-once-per-activation), hurtboxes with factions, local hitstop for attacker + target, trauma shake
  (one shake per frame even on multi-hits), white hit flash overlay, additive recoil, sparks + sand bursts,
  faience shards when the hero is hit, weapon trail ribbon (Catmull-Rom, HDR so it blooms).
- `EnemyBase` + shared AI states (Idle/Alert/Chase/Strafe/Attack/Flinch/Stagger/Return/Dead/Retreat/Evade),
  `AIDirector` attack tokens (max 2), telegraphs (glint / red flash), poise & stagger damage window.
- Training dummy (`scenes/enemies/training_dummy.tscn`): flinches, staggers, refills HP, damage numbers.
- `tests/combat_test.tscn`: 18 checks (damage values, hitstop on both sides, energy gain, charged heavy 57.6,
  poise break + stagger multiplier, dodge i-frames, heal + punished heal, Eye of Ra, input buffer out of a dodge,
  lock-on toggle) — all PASS.
- Visual check (screenshots): flash, sparks, sand puffs, trail visible during swings.

## Milestone 3 — enemies, AI, navigation ✅
- Shared AI state machine (Idle/Patrol → Alert → Chase → Strafe → Attack → Flinch/Stagger → Dead, plus Return,
  Retreat, Evade) driven by `EnemyData` / `EnemyAttackData` resources; NavigationAgent3D on a navmesh baked at
  runtime from static colliders (`NavBaker`); separation steering; wall probes while strafing.
- Attack tokens (`AIDirector`, max 2), readable telegraphs (gold glint / red flash for the grab, green for venom).
- **Mummy Guardian**: hyper armour, overhead slam, grab (red flash cue → dodge; caught = lifted, 3 squeeze ticks,
  thrown). **Scarab**: fast lunging bite, flips on its back when staggered. **Jackal Warrior**: 3-hit combo,
  gap-closing lunge, sidestep hops, evades the player's swings (35 %). **Cobra Priestess**: hood-flare venom spit
  (lobbed, leads the target) leaving a poison puddle (damage over time), retreats when approached, tail swipe when
  cornered.
- Placeholder rigs for all four with generated clips (idle/walk/run/attacks/alert/hit/stagger/death).
- `tests/ai_test.tscn`: pathing around a wall, token limit (max 2 simultaneous attackers in a 6-scarab swarm) — PASS.
  Smoke test: all enemies cycle through Alert/Chase/Strafe/Attack/Flinch/Stagger/Dead and land hits.

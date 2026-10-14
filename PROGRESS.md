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

## Milestone 4 — souls-like loop ✅
- `Level` base: builds world, bakes navmesh, spawns player/camera/UI, death flow, rest flow, world reset.
- **Altars of Osiris** (kindle → rest): restore HP + Ankh charges, respawn every enemy, level-up menu, save;
  last altar = respawn point. Green Osiris fire.
- **Ka**: dropped by enemies (orbs fly to the player). On death all Ka goes into a pulsing **heart** at the last safe
  ground position; touching it restores the Ka; dying again before that loses it for good.
- Death screen "YOUR HEART HAS BEEN WEIGHED" (scales: heart sinks, feather rises).
- **Leveling** (Vitality / Strength / Spirit), cost grows by 18 % per level (`resources/balance/leveling.tres`).
- **Saving** to `user://duat_save.json`: last altar, Ka, levels, flags (shortcuts, boss, altars), collected rewards,
  the heart (position + Ka), bonus Ankh, deaths, play time.
- UI: HUD (HP with trailing damage bar, stamina, sun-disc energy, ankh charges, Ka plate, boss bar, prompts, banners),
  level-up menu, pause + settings (volumes, shake, fullscreen), title screen (3D ushabti on a plinth).
- Graphics: animated billboard flame shader (fbm teardrop, additive bloom) for torches / braziers / altars.
- `tests/loop_test.tscn`: 23 checks (Ka from kills, rest restore/respawn/save, leveling, heart drop & pickup, heart
  loss, respawn at altar, save/load round trip) — all PASS.
- Fixed: Area3D pickups spawned in the same frame as a teleport saw the player's stale physics position
  (heart now arms after 0.5 s and checks real distance).

## Milestone 5 — the Necropolis + lighting & atmosphere ✅
- One interconnected zone (`scenes/levels/necropolis.tscn`, built by `scripts/levels/necropolis.gd`):
  1. **Sunlit Courtyard** (y 0): pylon gate, obelisks, broken statues and columns, wind-blown sand, first altar,
     2 mummies + scarab swarm (tutorial).
  2. **Descent into the Tomb** (y −4): antechamber (cobra + scarabs), **spike-trap corridor** (3 telegraphed
     pressure plates: gold-eye plate, holed floor, click + dust + spike tips before the strike).
  3. **Hall of Pillars**: jackal **ambush** bursting out of the sand, cobra, patrolling mummy.
     West: **Chamber of the Canopic Shrine** (+1 Ankh reward, jackal + scarab ambush).
  4. East: **Gallery of the Dead** (mummy, cobra, jackal, scarabs) → stairs up → vestibule → **lever** opens the
     **shortcut gate** into the courtyard next to the first altar.
  5. **Antechamber of Judgement** (second altar, light shaft) → **sand veil** → **Hall of Two Truths** (36×36 m).
- Rooms are carved out of solid rock with greedy-meshed blocks (27 boxes); low 2.8 m tomb walls with dark rock tops
  keep the 3/4 camera readable; gates are baked into the navmesh and re-baked (threaded) when they open.
- Atmosphere zones (courtyard / tomb / hall / hall_rage presets: sun, ambient, volumetric fog, exposure, glow, grade,
  music, ambience, reverb) and area banners on first entry.
- Graphics: sand ripples + glitter, pigment-painted hieroglyphs with khekher friezes, basalt walls with glowing gold
  inscriptions, glossy animated venom pools, dust motes, post-process (vignette, grade, grain, hit aberration,
  low-HP pulse).
- `tests/level_test.tscn` — 17 checks: navmesh paths to every key point, 2 altars, 3 traps, gate/lever/veil,
  28 enemies, **physical walk start → arena (142 m) and gallery loop → lever without getting stuck**, lever opens the
  gate, flag saved, navmesh re-bake shortens the route to 33 m — all PASS.
- Performance (Apple M5, 1080p, MSAA 4x, SSAO, volumetric fog): 77–83 FPS, 107–350 draw calls.
- Human check: walk the level; look at the camera framing in narrow corridors and at the stairs.

## Milestone 6 — Ammit, Devourer of Hearts ✅
- Placeholder rig: crocodile head with hinged toothed jaw and red eyes, lion forequarters + mane, hippo hindquarters,
  armoured croc tail; full-timeline clips for charge, double snap, tail sweep, leap, roar, summon, burrow/erupt.
- **Phase 1**: turning charge (limited turn rate; crashing into a wall or the scales stuns her for 2.2 s), double jaw
  snap, sweeping 360° tail strike (favoured when the player is behind), leap onto a telegraphed circle with a
  dodgeable expanding shockwave.
- **Phase 2** (< 50 % HP): roar (pause, push-back, red lighting `hall_rage`), four quicksand pools (slow + damage over
  time), scarab summons (max 6), faster combos (+15 % speed, snap-snap-tail), burrow → sand trail chasing the player →
  ground circle → eruption.
- Hall of Two Truths: giant swaying scales of Ma'at (heart vs feather), sand veil seals the entrance during the fight,
  boss bar with name, camera zoom-out ×1.35, boss music. Victory: slow motion, white flash, Ka reward, exit gate opens,
  veil drops, banner. Death / rest resets the hall (dormant Ammit, veil open, camera, pools).
- `tests/boss_test.tscn`: fight start, veil, zoom, damage, phase 2 (lighting + quicksand), all seven attack types
  observed across runs, victory flag, slow motion restored, exit gate, veil, minions, arena reset — PASS.
- Fixed: the arena built the scales before its own position was set, which blocked the courtyard gate (caught by the
  level test's navmesh checks).
- Balance: Ammit 1300 HP / 300 poise.
- Tooling: `tools/bg_godot.sh` runs windowed screenshot captures without stealing focus.

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

## Milestone 7 — UI, menus, audio, polish, performance ✅
- **Audio**: `tools/gen_audio.py` synthesises 51 sounds (whooshes, flesh/stone/heavy impacts, cracking faience,
  dodge, footsteps, chimes, creature voices, Ammit roar/snap, shockwaves, gate grind, traps, UI) plus four
  Hijaz-scale music loops (title, courtyard, tomb, boss: Karplus-Strong strings, drones, frame drums, ney flute)
  and two ambience beds. `AudioManager`: Master / Music / SFX buses (reverb on SFX per zone, limiter on Master),
  pooled 3D voices, one event table for every combat event, music crossfades, loop handling, clean shutdown.
- **UI**: HUD, boss bar, prompts with device-aware glyphs, area banners, notifications, death screen, level-up menu,
  pause + settings (volumes, camera shake, fullscreen, orthographic camera), title screen, end-of-slice screen.
- **Asset pipeline**: `ModelRig` plays any imported humanoid (BoneMap + SkeletonProfileHumanoid) through the same
  AnimationTree; events are injected from AttackData into imported clips; shared clips are duplicated per action.
  `tests/model_rig_test.tscn` verifies it with a code-built "imported" skeleton model — PASS.
- Clean runs: `godot --headless --quit-after 600` (main + level) print no ERROR / WARNING; all 8 test scenes pass
  with zero errors and zero warnings (headless runs play no audio).
- Documentation: `README.md` (Russian), `CREDITS.md`.

## Graphics pass (after M7)
- Soft blob shadows under every character, enemies crumble into glowing sand on death, reflecting lotus pool with
  swaying papyrus in the courtyard, lower courtyard side walls (less occlusion), start moved off the south wall.

## Milestone 8 — final verification ✅
| Acceptance criterion | How it is verified |
|---|---|
| Opens in Godot 4 and runs with F5 without console errors | `godot --headless --editor --quit`, `godot --headless --quit-after 600` (main) and the level: no ERROR / WARNING lines |
| Completable start → boss victory, no dead ends / stuck geometry | `tests/full_run_test.tscn` (bot plays the whole slice incl. side reward, both altars, Ammit, exit) and `tests/level_test.tscn` (navmesh paths + physical walks + shortcut) |
| Responsive combat: buffer, cancels, hitstop, shake, VFX, trail, telegraphs | `tests/player_motion_test.tscn`, `tests/combat_test.tscn`, screenshots of trail / sparks / flash / glints |
| Death, Ka heart, altars, leveling, saving | `tests/loop_test.tscn` (23 checks) |
| All balance parameters in Resource files | `resources/attacks`, `resources/enemies`, `resources/balance`, `resources/animation` |
| No TODO / pass stubs | `grep -rnE 'TODO|FIXME|^\s*pass\s*$' scripts tests tools` → 0 matches |
| README in Russian (controls, running, model replacement) | `README.md` |
| CREDITS.md | `CREDITS.md` (no external assets) |

Bot playthrough: ~130 s of game time at full aggression with god mode (it absorbed ~850 damage). A human who
explores, dodges and dies a few times should land in the 10–15 minute target; Ammit has 1300 HP / 300 poise.

### What a human should look at (cannot be judged from logs)
- Combat feel on real hardware: hitstop length, shake strength, input buffer, dodge distance.
- Readability of the placeholder animations from the 3/4 camera, especially Ammit's telegraphs (charge, tail, leap
  circle, burrow circle) — are the windups long enough?
- Camera framing on the tomb stairs and in the 4 m trap corridor; dither radius around the hero.
- Audio mix of the synthesised sounds and the seams of the music loops.
- Difficulty curve (mummy grab, jackal combos, cobra puddles, boss phase 2) and the Ka / level costs.
- Performance on a mid-range PC (measured: 77–83 FPS at 1080p on an Apple M5 laptop GPU, MSAA 4×, SSAO,
  volumetric fog).
- Gamepad mapping and prompt glyphs on a physical controller.

## Fix after review
- Bug: **New Game loaded the test arena** — `title_menu.gd` still pointed to `test_arena.tscn` (written in milestone 4,
  before the Necropolis existed). Now loads `necropolis.tscn`. Regression test `tests/menu_flow_test.tscn` drives the
  real title screen: New Game → Necropolis at the courtyard start; Continue → Necropolis at the saved altar — PASS.

## Feel pass — responsive movement and lively combat (branch `feel-pass`)
Measured first, then fixed; numbers in `FEEL_REPORT.md` (Before / After tables, causes, changes).
- **Step 1 — measure:** `FeelProbe` autoload (F3 FEEL section, `[feel]` log) and `tests/feel_test.tscn`
  (simulated device input, empirical lockouts / cancel windows).
- **Step 3 — movement:** input polled at the start of the hero's tick, same-tick state transitions,
  acceleration / deceleration / reversal rates, exponential turning + pivot, stick deadzone and response
  curve, foot-locked walk / run (leg IK, speed-matched playback), camera lead that holds on stop.
- **Step 4 — combat:** AnimationTree transitions primed (anticipation on the input frame), cancel-window
  API + F3 timeline, combo queue from mid-active, hit-confirm dodge cancel, windup steering + magnetism,
  momentum and ease-out lunges, instant dodge with i-frames from the first tick, buffer survives hitstop,
  dodge breaks the hero's own hitstop, per-preset hitstop, every hit pushes / shakes the target, rolling
  through enemies no longer drags them.
- **Step 5 — alive:** spring leans (overshoot), anticipation / dodge / landing squash & stretch, skid on
  pivots and hard stops, run-start dust, footstep dust at the planted foot, breathing (heavier after
  exertion), head / torso look-at, spring-driven kilt panel, wig lappets, linen sash and weapon sway, blade
  smear on the fastest frames.
- **Step 6 — presets:** `FeelPreset` resources Old / Snappy (default) / Weighty in `resources/feel/`;
  **F7** cycles them (stored in the settings), **F6** opens a live tuning panel (edit, reload, save .tres,
  toggle the `[feel]` log). Title screen → **Training Arena** opens the test arena as a sandbox (never
  saves); **F8** there spawns sparring enemies (scarab, jackal, mummy, cobra in turn).
- Tests: `feel_test` (all targets + exact window frames, buffered presses, hitstop, alive layers),
  `preset_test` (F6 / F7 with real key events), `menu_flow_test` (arena sandbox, F8) — plus the whole
  previous suite, all green; `tools/run_tests.sh` keeps the player's save and settings safe.

### Try this in the arena (title screen → Training Arena; F3 shows the numbers live)
1. Stand still, tap a direction: does the ushabti turn and start moving on the very first frame?
2. Run and reverse direction sharply (D → A): does it pivot almost instantly, lean back with a puff of
   dust, and run the other way without a slide?
3. Run and let go: does it stop within a step, with a small counter-lean and skid dust? Does the camera
   stop with it (no drift) and only recentre gently a moment later?
4. Watch the feet at full run (zoom in with a screen recorder if needed): do the planted feet stay put?
5. Mash light attack: three hits with a clear rhythm (hit 2 and 3 come at the chain point, not at the end
   of each animation)? Now mash, then press dodge mid-chain — does the roll come out immediately, even
   during the hit freeze?
6. Press light attack once, then once more early in the first swing: does hit 2 still come out?
7. Run at a dummy and attack: does the swing carry your momentum (longer lunge) and ease into the hit?
8. Attack with the stick / cursor slightly off the dummy: does the first frames' steering + magnetism
   snap you onto it?
9. Dodge from a standstill and from a run: instant start, fast burst then glide, squash → stretch → small
   landing squash? Dodge, then attack at the end of the roll.
10. Hit the dummy: hitstop short on light hits, longer on the 3rd hit and the heavy; the dummy flinches and
    is visibly pushed. Press F8 for a scarab / jackal (flinch on every light hit) and a mummy (armoured
    swings: shake + flash instead of flinch).
11. Idle near an enemy: does the head / torso track it? Does the hero breathe harder after a long combo?
    Do the kilt panel, sash tails and wig lappets swing and settle when you run, pivot and stop?
12. Press **F7** to compare **Old ↔ Snappy ↔ Weighty** back to back on the same moves; press **F6** to tune
    any value live and "Save .tres" when it feels right.
13. Gamepad: light stick tilt should walk smoothly (response curve), full tilt runs; diagonals on the
    keyboard should not be faster.

Things only a human can judge: whether Snappy or Weighty should be the default, the size of the spring
leans / squash on screen, the smear look, the camera lead distance, and the feel on a physical gamepad.

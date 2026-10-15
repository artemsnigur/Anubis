# Design & technical decisions

Routine decisions taken autonomously while building the slice. Newest at the bottom of each section.

## Engine / project
- **Godot 4.7.2 stable** (installed via Homebrew), Forward+ renderer, statically typed GDScript only.
- **Jolt Physics** is selected explicitly (`physics/3d/physics_engine`) for stable character collisions.
- **Physics interpolation ON**, 60 physics ticks. Gameplay runs in `_physics_process`; camera and UI run in
  `_process` using interpolated transforms, so movement is smooth on 120/144 Hz displays.
- **Input Map and global shader uniforms are written by `tools/setup_project.gd`** (the engine serialises the
  InputEvent objects, so the format is always valid). Key/mouse events use device `-1` (all devices).
- Balance resources (`resources/**/*.tres`) were created by `tools/generate_resources.gd`. After generation the
  `.tres` files are the source of truth (edit them in the inspector). Re-running the tool resets defaults.
- Procedural textures (noise + hieroglyph atlas) are generated once by `tools/generate_textures.gd` and committed
  as PNG assets.
- `tools/check.sh` compiles every script with *all* GDScript warnings promoted to errors (temporary `override.cfg`).
  `integer_division` is disabled project-wide because integer division is used intentionally (grid math).

## Combat architecture
- `Combatant` (CharacterBody3D) is the shared base of the player and enemies: Health/Poise/Hurtbox components,
  local time scale for hitstop, knockback, flash, procedural motion layers.
- **Hitboxes** are `Area3D` nodes that run an immediate shape query (`intersect_shape`) every physics frame while
  active. This makes resizing/moving the box at activation exact (no one-frame overlap lag). Each activation hits an
  entity at most once; a hit absorbed by i-frames also counts (an attack passes through a dodge only once).
- **Local hitstop**: each combatant advances its AnimationTree manually (`ANIMATION_CALLBACK_MODE_PROCESS_MANUAL`)
  with `delta * local_time_scale`; during hitstop the scale is 0, so animation, state timers and movement freeze
  while the rest of the world runs. `Engine.time_scale` is only used for the boss-kill slow motion.
- **Animation-driven events**: clips contain method tracks calling `anim_event(event, tag)` on the rig
  (`hitbox_on`, `hitbox_off`, `swing`, `telegraph`, `footstep`, `heal_apply`, `cast_fire` ...). States react to
  them; the tag (clip name) filters events from clips that are only cross-fading out. A time-based fallback from
  AttackData guarantees gameplay never soft-locks if an imported clip lacks events.
- Attack timings live in `AttackData` resources. Placeholder clips are *generated from those timings*, and for
  imported models the same timings are injected as method tracks — editing the `.tres` retimes everything.

## Animation / characters
- Placeholder characters are hierarchies of `Node3D` "bones" with primitive meshes (`PlaceholderRig`), animated by
  clips authored in code with a small keyframe DSL (`AnimBuilder`) that bakes easing (anticipation, overshoot,
  squash & stretch) at 30 Hz. Generated `AnimationLibrary`s are cached per rig type.
- Every character uses an `AnimationTree`: root `AnimationNodeStateMachine`, `locomotion` = `BlendSpace1D`
  (idle/walk/run), one state per action clip. Clip names are resolved through one `AnimationMap` resource per
  character (logical name -> clip name + fallbacks), so swapping a model never touches gameplay code.
- Procedural layers (lean into turns, stretch on dashes, additive hit recoil, hitstop jitter) act on a `Visual`
  node above the rig, so they also work on imported models.
- Hit flash uses a temporary `material_overlay` (additive white), so it works on any imported model's materials.

## Rendering
- Occluding walls use `world.gdshader`: triplanar noise materials + Bayer-dithered discard of fragments that are
  between the camera and the player (view-space test against a global `player_position` uniform). No alpha
  blending, so no sorting problems; floors are excluded via a height test.

## Level
- The level is built in code (`necropolis.gd`) from a small modular kit rather than authored by hand in the editor:
  it can be reasoned about in coordinates, verified by tests (paths, physical walk) and re-tuned quickly.
- Tomb rooms are carved out of rock (`Carver`, greedy meshing). Walls are kept low (2.8 m) with dark tops so the
  narrow-FOV 3/4 camera keeps seeing the floor; anything taller hides too much of the room.
- Closed gates are baked into the navmesh (gate layer is parsed); opening one re-bakes on a worker thread.
- Atmosphere zones are rectangles checked every 0.2 s (more robust than Area3D signals across teleports).

## Audio
- All audio is synthesised by `tools/gen_audio.py` (stdlib-only Python), so the slice has no licensing questions.
  Music uses the Hijaz (Phrygian dominant) scale for an Egyptian colour without copying any existing piece.
- Headless runs (tests) play no audio: the dummy driver does not always release playbacks before exit, which Godot
  reports as leaked resources. Real runs quit through `AudioManager.quit_game()` (stop all, wait two frames).

## Asset swapping
- `ModelRig` + `AnimationMap` are the only things that change when real models arrive. Gameplay timings stay in
  AttackData; the rig injects method tracks at those times. Several actions may share one imported clip — the rig
  duplicates it per action so event tags stay unique.

## Graphics pass
- Characters get a soft blob-shadow `Decal` (character meshes on render layer 2, decal cull mask = layer 1) so they
  stay grounded in the tomb where the sun casts no shadows.
- Enemy deaths: every mesh switches to a shared "crumble" shader (noise + height threshold with an ember edge) —
  the body turns to sand from the top down; works on any model.
- Fire is a Y-billboard fbm shader (`flame.gdshader`) with per-instance seeds; water is a raised basin
  (`water.gdshader`) because the courtyard floor is a single slab.
- Creature `StandardMaterial3D`s have a soft rim term for silhouette readability from above.

## Feel pass (branch `feel-pass`)
- **Measure first, from outside.** `FeelProbe` samples the raw input before any gameplay node runs (physics
  priority −1000) and the result after everything (+1000), so it measures what a player feels without
  hooks inside the code it measures; the same probe drives the F3 FEEL section and `tests/feel_test`.
  The harness injects input with `Input.action_press` at the end of a tick, which the engine exposes to
  `is_action_just_pressed` in the next tick — exactly like a key press arriving between ticks.
- **Input is polled by the Player at the start of its own tick** (`Combatant._early_update` →
  `PlayerInput.poll`) instead of in the child node's `_physics_process` (which ran after the Player).
- **Same-tick state transitions for the hero only** (`StateMachine.immediate_transitions`): a state entered
  from inside the update gets its first update in the same tick, so its timer and the animation it started
  stay in lock-step and windows can be expressed in state time. Enemies keep the old behaviour (their AI was
  tuned and tested with it).
- **60 Hz physics + physics interpolation (kept).** Interpolation adds at most one tick of display latency
  but removes jitter on 120/144 Hz screens; doubling the tick rate would double AI / shape-query cost and
  every timing table is in 60 Hz frames.
- **Movement model:** exponential approach toward the target velocity plus a linear floor, with separate
  acceleration, deceleration and reversal rates; facing uses an exponential approach with a minimum angular
  speed, snaps instantly when starting from a standstill and pivots faster on a reversal. Run speed stays
  6 m/s in every preset so level timings and enemy balance do not change.
- **Foot-locked locomotion:** walk and run are generated with 2-bone leg IK so the stance foot is planted
  while the hips travel `stride` metres per cycle; both clips have the same length and the blend space is
  synced, and the animator scales playback by speed / stride. No hip yaw in the cycle (it slid the planted
  foot); the twist is in spine and chest.
- **Camera lead hold:** the movement look-ahead holds when the hero stops and only recentres after
  `camera_recenter_delay`, at a slower rate — the camera never drifts on its own right after a stop.
- **Presets:** all feel values are in `FeelPreset` resources (`resources/feel/`). **Old** reproduces the
  pre-pass *values* (rates, windows, i-frames, camera, no procedural extras) but runs on the new code, so the
  structural fixes (input in the same tick, buffer that survives hitstop, same-tick transitions) apply to it
  too; the "Before" table in FEEL_REPORT.md was measured on the untouched commit. Attack timings stay in
  AttackData (the placeholder clips are generated from them) and are shared by all presets.
- The prompt mentions a pixel-art isometric style; this project is a low-poly 3D 3/4 view. "Pixel-stable"
  is read as: camera follows the interpolated transform with no sub-tick lag or snapping.
- **AnimationTree priming (hero only):** `AnimationNodeStateMachinePlayback.travel()` takes effect two
  advances later and `start()` one later, so a new clip sat on its first frame for 1–2 ticks. The hero's
  animator calls `advance(0)` right after a transition so the clip starts in the requested tick and clip
  time equals state time. Enemies keep the old behaviour (their telegraph timings were tuned with it).
- **Light windup 0.10 → 0.11 s:** with the frame of input delay gone the hit would land on frame 5; 0.11 puts
  the first active hitbox on frame 6 (target 6–8) and the dodge-cancel on frame 11 (target ≤ 12).
- **Window comparisons use a 0.5 ms tolerance** (`PlayerState.reached`): the state clock is a float sum of
  ticks, and a window at exactly 0.20 s must open on tick 12, not 13.
- **Combo queue:** a light-attack press from mid-active on is stored without expiry and fires at the chain
  point; earlier presses live in the (hitstop-proof) buffer, which reaches mid-active, so a single press
  anywhere in the swing chains.
- **Dodge cancels hitstop** only when the current state would accept the dodge (hit-confirm cancel), so it
  never shortens the impact of a swing that cannot be cancelled anyway.
- **Rolling through enemies:** both collision directions are released during a roll (the enemies' mask
  bit for the player too); before, enemies depenetrated out of the rolling capsule and were dragged up to
  3 m. Only masks that had the bit are restored (Ammit toggles hers during leaps).
- **Alive layers on bones are additive and self-cleaning:** offsets written after the AnimationTree are
  removed again when the animation did not re-pose the bone (hitstop advances by 0), so nothing drifts.
  Secondary springs freeze with hitstop (freeze-frame look).
- **Training Arena from the title is a sandbox** (`GameState.sandbox`): resting there never overwrites the
  real save. Tests keep using the arena with saving enabled. `tools/run_tests.sh` backs up and restores the
  player's save and settings because several tests delete / write them.
- **Default preset: Snappy.** Weighty also meets every target (heavier momentum, 2-frame crossfades, longer
  heavy hitstop); Old is only for comparison. The choice of default is left to a human playtest.

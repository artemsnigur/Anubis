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

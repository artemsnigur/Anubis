# Feel report — movement and combat responsiveness

All numbers are **60 Hz physics frames**. Frame 0 is the tick in which the input is first visible to
the game. Latencies are frame offsets (0 = same frame); durations (0 → 90 % speed, stop, turn, hitstop)
count the ticks it took.

How the numbers are produced:
- `scripts/systems/feel_probe.gd` (autoload `FeelProbe`) watches the hero from outside: a pre-sample before
  any gameplay node (physics priority −1000) reads the raw input, a post-sample after everything (+1000)
  reads velocity, facing, the largest bone rotation since the last tick (visible pose change, threshold
  0.75°), the procedural `Visual` transform, hitbox, i-frames and hitstop. Results are shown live in the
  **F3** overlay (FEEL section, green = on target, plus the cancel-window timeline of the current action)
  and printed as `[feel]` lines with `-- --feel-log` or the F6 panel toggle.
- `tests/feel_test.tscn` drives the hero in the test arena with **simulated device input**
  (`Input.action_press`, applied at the end of a tick, which the engine exposes in the next tick — like a key
  press arriving between ticks) and builds the tables below. Lockouts / cancel windows are measured
  empirically: the follow-up input is mashed (every other frame) and the frame it actually executes is
  recorded. `godot --headless res://tests/feel_test.tscn` checks the targets (default preset),
  `-- --measure-only --preset=old|weighty` only measures.
- The **Before** column was measured on the untouched commit `d69cd4e` (a git worktree with only the probe
  and the harness copied in), with exactly the same instruments as the After columns.

## Before (commit d69cd4e)

| Metric | Measured | Target | |
|---|---|---|---|
| Input → first velocity change | 0 f | same frame (0) | ✅ |
| Input → first visible pose change | 0 f | ≤ 1 f | ✅ |
| Idle → 90 % of top speed | 5 f (83 ms) | 0.08–0.12 s (5–7 f) | ✅ |
| Top speed → full stop | 5 f (83 ms) | 0.06–0.10 s (4–6 f) | ✅ |
| 180° turn (facing ≤ 10° and ≥ 50 % speed the new way) | 12 f (200 ms) | ≤ 0.10 s (≤ 6 f) | ❌ |
|   ↳ facing within 10° | 12 f | – | |
|   ↳ velocity ≥ 50 % in the new direction | 8 f | – | |
| Camera: input → camera starts moving | 1 f | – | |
| Camera: lag behind its target (hero + look-ahead) at full run | 1.00 m | – | |
| Camera: comes to rest after the hero stops (still for 10 f) | 103 f (1717 ms) | – | |
| Foot sliding at full run: planted-foot speed (0 = locked) | 0.59 m/s | – | |
| Camera: offset player ↔ screen centre at full run (+ = player behind centre) | 0.72 m | – | |
| Light: input → first anticipation (state + pose) | 1 f | same frame (0) | ❌ |
| Light: input → first active hitbox frame | 8 f | 6–8 f | ✅ |
| Light: input → dodge-cancel (dodge mashed) | 14 f | ≤ 12 f | ❌ |
| Light: input → next attack of the chain (attack mashed) | 15 f | – | |
| Light: input → movement accepted (move held) | 21 f | – | |
| Buffered dodge (pressed 6 f early) fires on the first legal frame | 14 f | = 10 f |  |
| Light: total lockout (frames until any of move / attack / dodge is accepted) | 14 f | – | |
| Light chain rhythm: hit 1 / 2 / 3 start at frame | 1 / 15 / 29 | – | |
| Attack pressed once early in the windup chains into hit 2 | NO | yes | ❌ |
|   ↳ hit 2 starts at frame | -1 f | – | |
| Heavy (tap): input → anticipation | 2 f | – | |
| Heavy (tap): input → active hitbox | 26 f | – | |
| Heavy: input → dodge-cancel (dodge mashed) | 43 f | – | |
| Dodge: input → movement | 2 f | same frame (0) | ❌ |
| Dodge: input → first i-frame | 5 f | ≤ 2 f | ❌ |
| Dodge: i-frame window length | 13 f | = 12 f (preset) |  |
| Dodge: input → attack accepted (attack mashed) | 17 f | = 14 f (preset) |  |
| Dodge: input → movement accepted (move held) | 22 f | = 20 f (preset) |  |
| Crossfade locomotion → light_1 | 3 f | 0–3 f | ✅ |
| Crossfade light_1 → light_2 | 3 f | 0–3 f | ✅ |
| Crossfade locomotion → dodge | 3 f | 0–3 f | ✅ |
| Crossfade light_1 → locomotion | 3 f | ≤ 6 f | ✅ |
| Locomotion idle ↔ walk ↔ run | BlendSpace1D driven by speed every frame (no crossfade) | – | |
| Light hit: hitstop on the hero | 4 f (67 ms) | – | |
| Light hit: hitstop on the target | 3 f (50 ms) | – | |
| Light hit: target reaction | flinch=true | – | |
| Dodge pressed once during hitstop is executed | yes | yes | ✅ |
|   ↳ dodge press (in hitstop) → dodge starts | 8 f | – | |
| Attack pressed once during hitstop chains into the next hit | yes | yes | ✅ |
|   ↳ attack press (in hitstop) → next hit starts | 9 f | – | |
| Alive layers | off in this preset | – | |
| Physics interpolation | true | – | |
| Physics ticks per second | 60 | – | |

(The "buffered dodge … 6 f early" row has no meaningful target on the old code: its first legal dodge
frame was 14, and the press did fire there.)

### Causes found

| # | Symptom | Cause |
|---|---|---|
| 1 | Every button answers one frame late (anticipation 1 f, dodge 2 f, light hit 8 f) | `PlayerInput` read `Input.is_action_just_pressed` in its own `_physics_process`. It is a **child** of the Player, so it ran *after* the Player in the same tick: the press was buffered after the state machine had already looked at the buffer. |
| 2 | Dodge moves 2 f after the press, first i-frame at 5 f | State transitions took effect on the **next tick**: the new state's first `physics_update` ran one tick later, so the roll velocity was set a tick late and the i-frame timer (`iframe_start` 0.05 s) only started counting then. I-frames were also evaluated *before* the state machine ran. |
| 3 | The anticipation pose shows 1–2 frames after the state starts (heavy: 2 f) | `AnimationNodeStateMachinePlayback.travel()` is applied **two advances later** (path, then fade start) and `start()` one later — the new clip sat on its first frame while the state timer was already running, so the clip lagged the gameplay windows. |
| 4 | Windows open later than they should | Cancel windows depended on the `RECOVERY` phase, which the clip's `hitbox_off` event set during the *animation* step after the states had run, on top of causes 1–3. |
| 5 | 180° turn takes 12 f (200 ms) | Facing turned at a constant 900°/s, and a reversal used the normal 70 m/s² acceleration (no separate reversal rate) — 8 f just to reach 50 % speed the other way. No pivot / skid. |
| 6 | Light attack → dodge-cancel at 14 f (target ≤ 12) | Causes 1, 4: dodge was only accepted in `RECOVERY`; landing a hit gave no earlier cancel. |
| 7 | A single attack press early in the swing is **lost** | The buffer (0.15 s) aged in real time and the chain point came later than the press + 0.15 s (worse when hitstop froze the attacker in between). Presses *during* the hitstop survived only because the chain point came soon enough after it. |
| 8 | No movement out of a light attack until 21 f | Walk-out only after 70 % of the recovery. |
| 9 | Running attacks stop dead, then step | Entering an attack cut velocity to 25 %, then the lunge moved at a **constant** speed — no momentum, no ease-out. |
| 10 | Camera floats: takes 1.7 s to come to rest after the hero stops, trails 1.0 m behind its target at a run | Follow damping 7/s plus a look-ahead that settles at 2.5/s and re-centres immediately when the input stops. |
| 11 | Floaty run: planted foot slides at 0.6 m/s | The hand-keyed run cycle (0.56 s) did not match 6 m/s, walk and run had different lengths (the blend drifted out of phase), and playback speed never followed the actual velocity. The hip twist also swung the planted leg. |
| 12 | Hitstop rounding: 55 ms froze the hero 4 ticks (67 ms) | `hitstop_left > 0` froze for every partial tick (ceil instead of nearest). |
| 13 | Rolling through an enemy dragged it along (up to 3 m) | Only the hero stopped colliding with enemies during the roll; the enemies still collided with the hero and depenetrated out of the rolling capsule every tick. |
| 14 | Hits on armoured targets feel like hitting a wall | Light hits flinch weak enemies, but the training dummy (knockback resist 1.0), armoured mummy swings and Ammit only flashed — nothing pushed or shook them. |
| – | Checked, not a cause | Crossfades were 3 f with immediate switch mode (no "At End" transitions); locomotion is a BlendSpace1D driven by speed every tick; physics interpolation was already on (no jitter) and the camera follows the interpolated transform; acceleration (5 f) and stop (5 f) were already inside the target range. |

## After

Targets: every row with a target is met by **Snappy** (the default) and by **Weighty**. **Old** keeps the old
*values* (rates, windows, i-frames, camera, no procedural layers) on the new code, so it is the "before"
feel minus the structural bugs — the turn, camera, windup press and walk-out numbers show what the values
alone did.

| Metric | Target | Before (d69cd4e) | Snappy (default) | Weighty | Old preset |
|---|---|---|---|---|---|
| Input → first velocity change | same frame (0) | 0 f ✅ | 0 f ✅ | 0 f ✅ | 0 f ✅ |
| Input → first visible pose change | ≤ 1 f | 0 f ✅ | 0 f ✅ | 0 f ✅ | 0 f ✅ |
| Idle → 90 % of top speed | 0.08–0.12 s (5–7 f) | 5 f (83 ms) ✅ | 5 f (83 ms) ✅ | 6 f (100 ms) ✅ | 5 f (83 ms) ✅ |
| Top speed → full stop | 0.06–0.10 s (4–6 f) | 5 f (83 ms) ✅ | 4 f (67 ms) ✅ | 5 f (83 ms) ✅ | 5 f (83 ms) ✅ |
| 180° turn | ≤ 0.10 s (≤ 6 f) | 12 f (200 ms) ❌ | 3 f (50 ms) ✅ | 5 f (83 ms) ✅ | 12 f (200 ms) ❌ |
| ↳ facing within 10° | – | 12 f | 2 f | 5 f | 12 f |
| ↳ velocity ≥ 50 % in the new direction | – | 8 f | 3 f | 4 f | 8 f |
| Camera: input → camera starts moving | – | 1 f | 1 f | 1 f | 1 f |
| Camera: lag behind its target (hero + look-ahead) at full run | – | 1.00 m | 0.41 m | 0.56 m | 1.00 m |
| Camera: comes to rest after the hero stops | – | 103 f (1717 ms) | 17 f (283 ms) | 24 f (400 ms) | 102 f (1700 ms) |
| Foot sliding at full run: planted-foot speed | – | 0.59 m/s | 0.00 m/s | 0.00 m/s | 0.95 m/s |
| Camera: offset player ↔ screen centre at full run (+ = player behind centre) | – | 0.72 m | 1.04 m | 1.10 m | 0.69 m |
| Light: input → first anticipation (state + pose) | same frame (0) | 1 f ❌ | 0 f ✅ | 0 f ✅ | 0 f ✅ |
| Light: input → first active hitbox frame | 6–8 f | 8 f ✅ | 6 f ✅ | 6 f ✅ | 6 f ✅ |
| Light: input → dodge-cancel (dodge mashed) | ≤ 12 f | 14 f ❌ | 11 f ✅ | 11 f ✅ | 11 f ✅ |
| Light: input → next attack of the chain (attack mashed) | – | 15 f | 13 f | 13 f | 13 f |
| Light: input → movement accepted (move held) | – | 21 f | 17 f | 18 f | 19 f |
| ↳ dodge window opens on its frame (w+a+cancel_delay) | = 11 f | – | 11 f ✅ | – | – |
| ↳ chain window opens on its frame (w+a+chain_delay) | = 13 f | – | 13 f ✅ | – | – |
| ↳ walk-out window opens on its frame | = 17 f | – | 17 f ✅ | – | – |
| Buffered dodge fires on the first legal frame | = 11 f | 14 f | 11 f ✅ | 11 f | 11 f |
| Light: total lockout (frames until any of move / attack / dodge is accepted) | – | 14 f | 11 f | 11 f | 11 f |
| Light chain rhythm: hit 1 / 2 / 3 start at frame | – | 1 / 15 / 29 | 0 / 13 / 27 | 0 / 13 / 27 | 0 / 13 / 27 |
| Attack pressed once early in the windup chains into hit 2 | yes | NO ❌ | yes ✅ | yes ✅ | NO ❌ |
| ↳ hit 2 starts at frame | – | -1 f | 13 f | 13 f | -1 f |
| Heavy (tap): input → anticipation | – | 2 f | 0 f | 0 f | 0 f |
| Heavy (tap): input → active hitbox | – | 26 f | 24 f | 24 f | 24 f |
| Heavy: input → dodge-cancel (dodge mashed) | – | 43 f | 1 f | 1 f | 41 f |
| Dodge: input → movement | same frame (0) | 2 f ❌ | 0 f ✅ | 0 f ✅ | 0 f ✅ |
| Dodge: input → first i-frame | ≤ 2 f | 5 f ❌ | 0 f ✅ | 0 f ✅ | 2 f ✅ |
| Dodge: i-frame window length | = 13 f (preset) | 13 f | 13 f ✅ | 14 f | 12 f |
| Dodge: input → attack accepted (attack mashed) | = 11 f (preset) | 17 f | 11 f ✅ | 14 f | 14 f |
| Dodge: input → movement accepted (move held) | = 15 f (preset) | 22 f | 15 f ✅ | 17 f | 20 f |
| Crossfade locomotion → light_1 | 0–3 f | 3 f ✅ | 1 f ✅ | 2 f ✅ | 3 f ✅ |
| Crossfade light_1 → light_2 | 0–3 f | 3 f ✅ | 1 f ✅ | 2 f ✅ | 3 f ✅ |
| Crossfade locomotion → dodge | 0–3 f | 3 f ✅ | 1 f ✅ | 2 f ✅ | 3 f ✅ |
| Crossfade light_1 → locomotion | ≤ 6 f | 3 f ✅ | 5 f ✅ | 6 f ✅ | 3 f ✅ |
| Locomotion idle ↔ walk ↔ run | – | BlendSpace1D driven by speed every frame (no crossfade) | BlendSpace1D driven by speed every frame (no crossfade) | BlendSpace1D driven by speed every frame (no crossfade) | BlendSpace1D driven by speed every frame (no crossfade) |
| Light hit: hitstop on the hero | – | 4 f (67 ms) | 3 f (50 ms) | 3 f (50 ms) | 3 f (50 ms) |
| Light hit: hitstop on the target | – | 3 f (50 ms) | 3 f (50 ms) | 3 f (50 ms) | 3 f (50 ms) |
| Light hit: target reaction | – | flinch=true | flinch=true | flinch=true | flinch=true |
| Dodge pressed once during hitstop is executed | yes | yes ✅ | yes ✅ | yes ✅ | yes ✅ |
| ↳ dodge press (in hitstop) → dodge starts | – | 8 f | 0 f | 0 f | 6 f |
| Attack pressed once during hitstop chains into the next hit | yes | yes ✅ | yes ✅ | yes ✅ | yes ✅ |
| ↳ attack press (in hitstop) → next hit starts | – | 9 f | 8 f | 8 f | 8 f |
| Secondary motion: kilt panel swings at a run and settles at rest | yes | – | yes ✅ | yes ✅ | – |
| Footstep events report the planted foot | yes | – | yes ✅ | yes ✅ | – |
| No additive drift during a 1 s freeze | yes | – | yes ✅ | yes ✅ | – |
| Head turns toward a nearby enemy | yes | – | yes ✅ | yes ✅ | – |
| Physics interpolation | – | true | true | true | true |
| Physics ticks per second | – | 60 | 60 | 60 | 60 |

Full Snappy table (as printed by `godot --headless res://tests/feel_test.tscn`):

| Metric | Measured | Target | |
|---|---|---|---|
| Input → first velocity change | 0 f | same frame (0) | ✅ |
| Input → first visible pose change | 0 f | ≤ 1 f | ✅ |
| Idle → 90 % of top speed | 5 f (83 ms) | 0.08–0.12 s (5–7 f) | ✅ |
| Top speed → full stop | 4 f (67 ms) | 0.06–0.10 s (4–6 f) | ✅ |
| 180° turn (facing ≤ 10° and ≥ 50 % speed the new way) | 3 f (50 ms) | ≤ 0.10 s (≤ 6 f) | ✅ |
|   ↳ facing within 10° | 2 f | – | |
|   ↳ velocity ≥ 50 % in the new direction | 3 f | – | |
| Camera: input → camera starts moving | 1 f | – | |
| Camera: lag behind its target (hero + look-ahead) at full run | 0.41 m | – | |
| Camera: comes to rest after the hero stops (still for 10 f) | 17 f (283 ms) | – | |
| Foot sliding at full run: planted-foot speed (0 = locked) | 0.00 m/s | – | |
| Camera: offset player ↔ screen centre at full run (+ = player behind centre) | 1.04 m | – | |
| Light: input → first anticipation (state + pose) | 0 f | same frame (0) | ✅ |
| Light: input → first active hitbox frame | 6 f | 6–8 f | ✅ |
| Light: input → dodge-cancel (dodge mashed) | 11 f | ≤ 12 f | ✅ |
| Light: input → next attack of the chain (attack mashed) | 13 f | – | |
| Light: input → movement accepted (move held) | 17 f | – | |
|   ↳ dodge window opens on its frame (w+a+cancel_delay) | 11 f | = 11 f | ✅ |
|   ↳ chain window opens on its frame (w+a+chain_delay) | 13 f | = 13 f | ✅ |
|   ↳ walk-out window opens on its frame | 17 f | = 17 f | ✅ |
| Buffered dodge (pressed 6 f early) fires on the first legal frame | 11 f | = 11 f | ✅ |
| Light: total lockout (frames until any of move / attack / dodge is accepted) | 11 f | – | |
| Light chain rhythm: hit 1 / 2 / 3 start at frame | 0 / 13 / 27 | – | |
| Attack pressed once early in the windup chains into hit 2 | yes | yes | ✅ |
|   ↳ hit 2 starts at frame | 13 f | – | |
| Heavy (tap): input → anticipation | 0 f | – | |
| Heavy (tap): input → active hitbox | 24 f | – | |
| Heavy: input → dodge-cancel (dodge mashed) | 1 f | – | |
| Dodge: input → movement | 0 f | same frame (0) | ✅ |
| Dodge: input → first i-frame | 0 f | ≤ 2 f | ✅ |
| Dodge: i-frame window length | 13 f | = 13 f (preset) | ✅ |
| Dodge: input → attack accepted (attack mashed) | 11 f | = 11 f (preset) | ✅ |
| Dodge: input → movement accepted (move held) | 15 f | = 15 f (preset) | ✅ |
| Crossfade locomotion → light_1 | 1 f | 0–3 f | ✅ |
| Crossfade light_1 → light_2 | 1 f | 0–3 f | ✅ |
| Crossfade locomotion → dodge | 1 f | 0–3 f | ✅ |
| Crossfade light_1 → locomotion | 5 f | ≤ 6 f | ✅ |
| Locomotion idle ↔ walk ↔ run | BlendSpace1D driven by speed every frame (no crossfade) | – | |
| Light hit: hitstop on the hero | 3 f (50 ms) | – | |
| Light hit: hitstop on the target | 3 f (50 ms) | – | |
| Light hit: target reaction | flinch=true | – | |
| Dodge pressed once during hitstop is executed | yes | yes | ✅ |
|   ↳ dodge press (in hitstop) → dodge starts | 0 f | – | |
| Attack pressed once during hitstop chains into the next hit | yes | yes | ✅ |
|   ↳ attack press (in hitstop) → next hit starts | 8 f | – | |
| Secondary motion: kilt panel swings at a run (40°) and settles at rest (0.5°) | yes | yes | ✅ |
| Footstep events report the planted foot (4 steps) | yes | yes | ✅ |
| No additive drift during a 1 s freeze (0.04°) | yes | yes | ✅ |
| Head turns toward a nearby enemy (75°) | yes | yes | ✅ |
| Physics interpolation | true | – | |
| Physics ticks per second | 60 | – | |

## What changed and why

**Movement (step 3)**
- Input is polled by the Player at the start of its own tick (`Combatant._early_update` →
  `PlayerInput.poll`); hero state transitions take effect in the same tick
  (`StateMachine.immediate_transitions`) → velocity, dodge movement and i-frames on frame 0.
- `FeelPreset` movement model: exponential approach + linear floor with separate acceleration,
  deceleration and **reversal** rates; exponential turning with a minimum angular speed; instant facing from a
  standstill; faster pivot turn on a reversal → 180° in 3 f (Snappy) / 5 f (Weighty) instead of 12 f.
- Stick: radial deadzone rescaled to 0..1 + response curve; keyboard diagonals normalised.
- Foot-locked walk / run: generated with 2-bone leg IK (planted stance foot, toe roll, swing arc), same length,
  synced blend space, `stride` metadata; the animator plays the cycle at speed / stride → planted foot
  0.00 m/s. No hip yaw in the cycle (twist moved to spine / chest).
- Camera: follow 16/s (Snappy), look-ahead from the preset, **lead holds** when the hero stops and only
  recentres after 0.7 s at a calmer rate → at rest in 17 f instead of 103 f, lag 0.41 m instead of 1.0 m.
- Hitstop rounded to the nearest whole tick.

**Combat (step 4)**
- AnimationTree transitions are primed with zero-time advances for the hero → anticipation on frame 0,
  clip time == state time, windows open exactly on their frames (checked by the test).
- Cancel-window API on every player state (`accepts(kind)`, `windows()`), drawn as a timeline in F3.
- Light windup 0.10 → 0.11 s: first active hitbox on frame 6 (target 6–8), dodge-cancel from frame 11 or right
  after a hit connects, chain point frame 13, walk-out frame 17.
- Combo queue: from mid-active a light press is stored without expiry and fires at the chain point; the
  buffer ages in the hero's local time, so it survives hitstop → a single press anywhere in the swing chains.
- Windup steering (first 0.07 s) with aim-assist magnetism; momentum carry from a run (decaying) + ease-out
  lunge; heavy windup / charge can be dodge-cancelled; hit-confirm dodge cancel on light and heavy.
- Dodge: moves and is invulnerable in the input tick, direction from input, front-loaded curve
  (exact-distance integration), windows into attack / dodge / move, clip retimed to the preset.
- A dodge press cuts the hero's own hitstop when the dodge is legal (0 f instead of 8 f); Hurt no longer
  clears the buffer.
- Hitstop scaled per preset (light 0.9× / heavy 1.0× in Snappy → 3 ticks on a light hit, both sides).
- Every hit pushes the target's visual (independent of knockback resistance); armoured targets that do not
  flinch shake; rolling through enemies releases both collision directions.

**Alive (step 5)** — `HeroAlive` + `ProceduralMotion`
- Spring leans into turns and acceleration with overshoot, counter-lean when braking; anticipation squash on
  attacks, squash → stretch on the dodge, landing squash at its end.
- Skid (lean back + dust + scuff) on pivots and hard stops, dust on run start, footstep dust at the planted
  foot (events tell which foot).
- Breathing on chest / neck / shoulders, faster and deeper after exertion; head / neck / chest turn toward the
  nearest enemy (or the aim direction).
- Spring pendulums: gold kilt panel, wig lappets, two new linen sash tails; weapon sway; all freeze with
  hitstop. Additive bone offsets clean themselves up, so nothing drifts during a freeze (tested).
- Smear frames: blade stretched along its arc + brighter trail on the active frames.

**Presets (step 6)**
- `resources/feel/old.tres`, `snappy.tres` (default), `weighty.tres`; **F7** cycles them (persisted in the
  settings), **F6** opens the live tuning panel (every exported value, reload, save .tres, log toggle).
- Title screen → **Training Arena** (sandbox, never saves); **F8** spawns sparring enemies.

## What only a human can judge
- Snappy vs Weighty as the default; the size of leans, squash, smear and secondary swing on screen.
- Camera lead distance and recentre delay; whether the 1-frame combat crossfade reads as snappy or as a pop.
- The physics-interpolated display adds up to one tick of display latency on top of the frame-0 logic
  response (kept: it removes jitter on 120/144 Hz screens).
- Gamepad response curve on a physical controller.
- The checklist is in `PROGRESS.md` → "Try this in the arena".

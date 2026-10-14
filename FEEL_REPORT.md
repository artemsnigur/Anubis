# Feel report — movement and combat responsiveness

All numbers are **60 Hz physics frames**. Frame 0 is the tick in which the input is first visible to
the game. Latencies are frame offsets (0 = same frame); durations (0 → 90 % speed, stop, turn, hitstop)
count the ticks it took.

How the numbers are produced:
- `scripts/systems/feel_probe.gd` (autoload `FeelProbe`) watches the hero from outside: a pre-sample before
  any gameplay node (physics priority −1000) reads the raw input, a post-sample after everything (+1000)
  reads velocity, facing, animation state / blend, the procedural `Visual` transform, hitbox, i-frames and
  hitstop. Results are shown live in the **F3** overlay (FEEL section, green = on target) and printed as
  `[feel]` lines with `-- --feel-log` (or the F6 panel toggle).
- `tests/feel_test.tscn` drives the hero in the test arena with **simulated device input**
  (`Input.action_press`, applied at the end of a tick like a real key press arriving between ticks) and
  builds the table below. Lockouts / cancel windows are measured empirically: the follow-up input is
  mashed (every other frame) and the frame it actually executes is recorded.
  `godot --headless res://tests/feel_test.tscn` checks the targets; `-- --measure-only` only measures.

## Before (commit d69cd4e, measured with the harness on the unchanged code)

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
| Camera: hero's largest distance from screen centre in the first 0.5 s of a run | 0.25 m | – | |
| Camera: still drifting after the hero stopped for | 93 f (1550 ms) | – | |
| Foot sliding at full run: planted-foot speed (0 = locked) | 1.40 m/s | – | |
| Camera: offset player ↔ screen centre at full run (+ = player behind centre) | 0.61 m | – | |
| Light: input → first anticipation (state + pose) | 1 f | same frame (0) | ❌ |
| Light: input → first active hitbox frame | 8 f | 6–8 f | ✅ |
| Light: input → dodge-cancel (dodge mashed) | 14 f | ≤ 12 f | ❌ |
| Light: input → next attack of the chain (attack mashed) | 15 f | – | |
| Light: input → movement accepted (move held) | 22 f | – | |
| Light: total lockout (frames until any of move / attack / dodge is accepted) | 14 f | – | |
| Light chain rhythm: hit 1 / 2 / 3 start at frame | 1 / 15 / 29 | – | |
| Heavy (tap): input → anticipation | 1 f | – | |
| Heavy (tap): input → active hitbox | 26 f | – | |
| Heavy: input → dodge-cancel (dodge mashed) | 43 f | – | |
| Dodge: input → movement | 2 f | same frame (0) | ❌ |
| Dodge: input → first i-frame | 5 f | ≤ 2 f | ❌ |
| Dodge: i-frame window | 13 f | – | |
| Dodge: input → attack accepted (attack mashed) | 17 f | – | |
| Dodge: input → movement accepted (move held) | 23 f | – | |
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
| Attack pressed once during hitstop chains into the next hit | NO | yes | ❌ |
|   ↳ attack press (in hitstop) → next hit starts | -1 f | – | |
| Physics interpolation | true | – | |
| Physics ticks per second | 60 | – | |

### Causes found

| # | Symptom | Cause (file) |
|---|---|---|
| 1 | Every button answers one frame late (anticipation 1 f, dodge 2 f, light hit 8 f) | `PlayerInput` read `Input.is_action_just_pressed` in its own `_physics_process`. It is a **child** of the Player, so it runs *after* the Player in the same tick: the press was buffered after the state machine had already looked at the buffer (`player_input.gd`). |
| 2 | Dodge moves 2 f after the press, first i-frame at 5 f | State transitions took effect on the **next tick**: the new state's first `physics_update` ran one tick later, so the roll velocity was set a tick late, and the i-frame timer (`iframe_start = 0.05 s`) only started counting then. I-frames were also evaluated *before* the state machine (`player.gd _pre_update`). |
| 3 | Windows open one frame later than the animation shows | The state timer started one tick behind the animation (the clip was advanced on the entry tick, the timer was not), and cancel windows depended on the `RECOVERY` phase that the clip's `hitbox_off` event sets during the *animation* step, after the states had run. |
| 4 | 180° turn takes 12 f (200 ms) | Facing turned at a constant 900°/s (`face_toward`), and a reversal used the normal 70 m/s² acceleration (no separate, higher reversal rate) — 8 f just to get 50 % speed the other way. No pivot / skid. |
| 5 | Light attack → dodge-cancel at 14 f (target ≤ 12) | Dodge was only accepted in `RECOVERY`, which started after the `hitbox_off` event (cause 3) plus cause 1. Landing a hit gave no earlier cancel. |
| 6 | A chain press made during hitstop is **lost** | The input buffer aged in real time while the hero was frozen by hitstop: a press during the active frames expired (0.15 s) before the chain point. |
| 7 | Movement out of a light attack only at 22 f | Walk-out allowed only after 70 % of the recovery. |
| 8 | Running attacks stop dead, then step | Entering an attack cut velocity to 25 %, then the lunge moved at a **constant** speed — no momentum, no ease-out. |
| 9 | Camera "floats": still drifting 1.5 s after the hero stops | Follow damping 7/s plus a look-ahead that settles at 2.5/s; the look-ahead keeps sliding long after the hero has stopped. |
| 10 | Floaty run: planted foot slides at 1.4 m/s | The run cycle (0.56 s, keyed by hand) does not match 6 m/s; the walk and run clips have different lengths, so blending them also drifts out of phase. Animation speed was never scaled to the actual velocity. |
| 11 | Hitstop rounding: 55 ms became 4 ticks (67 ms) on the hero | `hitstop_left > 0` froze for every partial tick (ceil instead of nearest). |
| 12 | Hit reactions on armoured targets are weak | Light hits flinch weak enemies, but the training dummy (knockback resist 1.0) and Ammit only flash; nothing pushes or shakes them. |
| – | Checked, not a cause | Crossfades are 3 f (0.05 s) with immediate switch mode, no "At End" transitions; locomotion is a BlendSpace1D driven by speed every tick; physics interpolation is on (no jitter), camera follows the interpolated transform; acceleration (5 f) and stop (5 f) were already inside the target range. |

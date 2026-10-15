class_name FeelPreset
extends Resource
## Every "game feel" parameter of the hero in one resource (movement, input buffer,
## cancel windows, dodge, impact, camera, procedural animation layers).
## Presets live in resources/feel/: grounded.tres (default: weight, momentum, commitment),
## snappy.tres (the first feel pass) and old.tres (values before any feel pass). F7 cycles
## them in game, F6 edits the active one live. Attack timings (windup / active / recovery,
## chain and cancel delays) stay in AttackData because the placeholder clips are generated
## from them; attack_tempo replays them faster for the lighter presets.

@export var id: StringName = &"snappy"
@export var display_name: String = "Snappy"

@export_group("Input")
@export var buffer_time: float = 0.15
## Buffered presses age in the hero's local time, so they survive hitstop.
@export var buffer_in_local_time: bool = true
## A dodge press cuts the hero's own hitstop short.
@export var dodge_breaks_hitstop: bool = true
## Radial deadzone of the move stick (the remaining range is rescaled to 0..1).
@export_range(0.0, 0.5) var stick_deadzone: float = 0.15
## Response curve of the move stick: magnitude^exponent (1 = linear).
@export_range(0.5, 3.0) var stick_response_exponent: float = 1.3

@export_group("Movement")
## Multiplies PlayerStats.run_speed.
@export var run_speed_mult: float = 1.0
## Heading model: the body turns toward the input at a limited rate and moves where it
## faces; a sharp reversal at speed brakes first, then pivots. Off = velocity vector model.
@export var heading_locomotion: bool = false
## Turn rate (deg/s) standing / walking and at full run (heading model).
@export var turn_rate_slow_deg: float = 600.0
@export var turn_rate_run_deg: float = 300.0
## Input this far behind the facing at more than brake_speed_frac of run speed: brake first.
@export var brake_turn_angle_deg: float = 115.0
@export_range(0.0, 1.0) var brake_speed_frac: float = 0.35
## Braking deceleration = decel_linear * this.
@export var brake_mult: float = 1.3
## Speeding up: exponential approach rate (1/s) toward the target velocity ...
@export var accel_sharpness: float = 16.0
## ... plus a linear rate (m/s²) so the exponential tail never drags.
@export var accel_linear: float = 24.0
@export var decel_sharpness: float = 22.0
@export var decel_linear: float = 36.0
## Used when the input points against the current velocity (angle > reverse_angle_deg).
@export var reverse_sharpness: float = 30.0
@export var reverse_linear: float = 60.0
@export var reverse_angle_deg: float = 100.0
## Facing: exponential rate (1/s) toward the input direction plus a minimum angular speed.
@export var turn_sharpness: float = 28.0
@export var turn_rate_deg: float = 900.0
## Facing rate while pivoting on a sharp reversal.
@export var pivot_turn_sharpness: float = 45.0
## Starting from (almost) standing still, a new direction is faced instantly.
@export var snap_face_speed: float = 1.2

@export_group("Animation")
## Crossfade into combat states (attacks, dodge, hit reactions), seconds.
@export var combat_xfade: float = 0.017
## Crossfade from an action back into locomotion, seconds.
@export var recover_xfade: float = 0.08
## Plays the walk / run cycle at the rate that matches the actual speed (no foot sliding).
@export var speed_matched_locomotion: bool = true

@export_group("Attacks")
## Playback / state speed of attacks and casts (1 = the AttackData timings).
@export var attack_tempo: float = 1.0
## Fraction of the entry speed (along the swing) carried into an attack ...
@export var attack_entry_keep: float = 1.0
## ... decaying at this rate (1/s). keep / decay = extra metres when attacking from a run.
@export var attack_entry_decay: float = 14.0
## Lunge window starts at this fraction of the windup and ends with the active frames.
@export var lunge_start: float = 0.25
## Lunge speed curve: 1 = constant speed, 2+ = ease-out (fast step, soft landing).
@export var lunge_ease: float = 2.0
@export var lunge_scale: float = 1.0
## Seconds at the start of the windup during which the swing can still be re-aimed.
@export var windup_steer_time: float = 0.07
## From this fraction of the active phase a new attack press is queued for the combo and
## never expires; it fires at the chain point. Negative = off (plain input buffer only).
@export var combo_queue_from_active: float = 0.5
## Once a swing connects, it can be dodge-cancelled right away.
@export var dodge_cancel_on_hit: bool = true
## Fraction of the recovery after which movement input walks out of the attack.
@export_range(0.0, 1.0) var walk_out_recovery: float = 0.5
## The heavy attack's windup (before hyper armour) can be dodge-cancelled.
@export var heavy_windup_dodge_cancel: bool = true

@export_group("Dodge")
## Push-off: the roll speeds up over this time before the front-loaded burst.
@export var dodge_ramp_time: float = 0.0
@export var dodge_duration: float = 0.34
@export var dodge_distance: float = 4.75
## Distance curve 1-(1-u)^p: higher = more front-loaded burst.
@export var dodge_curve_power: float = 2.6
@export var iframe_start: float = 0.0
@export var iframe_end: float = 0.22
## Times into the dodge after which an attack / another dodge / walking is accepted.
@export var dodge_attack_cancel: float = 0.2
@export var dodge_dodge_cancel: float = 0.26
@export var dodge_move_cancel: float = 0.26
## Fraction of the run speed kept when the roll ends into movement.
@export var dodge_exit_carry: float = 0.6

@export_group("Impact")
@export var hitstop_light_mult: float = 0.9
@export var hitstop_heavy_mult: float = 1.0
@export var shake_mult: float = 0.9
## Visual push (metres) of whatever the hero hits, even if it resists knockback.
@export var hit_push: float = 0.12
## After the freeze the hero's swing is dragged (slowed) for a moment - the blade bites.
@export var hit_drag_time: float = 0.0
@export_range(0.05, 1.0) var hit_drag_factor: float = 1.0
## The hero's body jolts back on contact (recoil strength) ...
@export var attacker_recoil: float = 0.0
## ... the camera is kicked along the blow (metres) ...
@export var camera_kick: float = 0.0
## ... and the gamepad rumbles.
@export var rumble: bool = false

@export_group("Camera")
## Follow rate (1/s): higher = tighter.
@export var camera_follow: float = 16.0
## Look-ahead distance at full input (metres) and how fast it settles (1/s).
@export var camera_look_ahead: float = 1.4
@export var camera_look_ahead_rate: float = 5.0
## After the move input is released the look-ahead holds this long (no drift when the
## hero stops), then recentres at camera_recenter_rate (1/s).
@export var camera_recenter_delay: float = 0.7
@export var camera_recenter_rate: float = 1.6

@export_group("Alive")
## Roll into turns (radians per rad/s of yaw rate at full speed) and its limit.
@export var lean_turn: float = 0.13
@export var lean_max_deg: float = 16.0
## Pitch into acceleration / counter-lean when braking (radians per m/s²).
@export var lean_accel: float = 0.01
## Lean springs (0 = plain exponential smoothing like the old layer).
@export var lean_stiffness: float = 170.0
@export var lean_damping: float = 15.0
## Squash before a dodge / attack, stretch during it, squash on landing.
@export var squash: float = 1.0
## Skid pose + dust on sharp turns and stops, dust on run start.
@export var skid_fx: bool = true
## Footstep dust at the planted foot.
@export var footstep_dust: bool = true
## Spring-driven secondary motion (kilt panel, wig lappets, linen sash, weapon sway).
@export_range(0.0, 2.0) var secondary_motion: float = 1.0
## Head / torso turn toward the nearest enemy or the aim direction (0 = off).
@export_range(0.0, 1.0) var look_at: float = 1.0
## Procedural idle breathing amount.
@export_range(0.0, 2.0) var breathing: float = 1.0
## Blade smear (stretched blade + brighter trail) on the fastest frames of a swing.
@export var smear: bool = true

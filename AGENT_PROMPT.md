# Task: 3D souls-like vertical slice in Godot 4 — "Heart of the Duat"

You are an experienced Godot 4 (GDScript) game developer. Starting from scratch in the current folder, build a **playable vertical slice** of a 3D action game: a 3/4 top-down camera (like isometric action games), fast and responsive souls-like combat, set in Ancient Egypt — the underworld of the Duat.

Top priority is **how combat and movement feel**: responsive controls, readable animations, weighty hits. Less content that is polished beats more content that is rough.

Work autonomously, milestone by milestone, until every acceptance criterion (section 16) is met. Don't ask permission for routine decisions: make sensible choices and log them in `DECISIONS.md`.

---

## 1. Technical constraints

- Godot 4.x, latest stable release. Check `godot --version` (or `godot4`). If Godot isn't installed, download the official build for your OS from the releases at `github.com/godotengine/godot`. Renderer: Forward+.
- Statically typed GDScript only. No C#, no paid assets, no paid plugins.
- Godot 4 syntax only: `CharacterBody3D`, `move_and_slide()` with no arguments, `@export`, `@onready`, `signal.connect(callable)`, `await` instead of `yield`, `create_tween()`. If unsure about an API, check the Godot 4 docs rather than relying on memory of Godot 3.
- Performance: stable 60 FPS on a mid-range PC.
- Input: keyboard + mouse and gamepad at the same time, all actions through the Input Map.
- Git: initialize a repository and commit after every milestone with a clear message.

## 2. Concept

- **Hero**: an awakened ushabti — a funerary figurine of turquoise faience with gold veins that has come to life in the Duat. Weapon: a khopesh.
- **Slice goal**: make it through the Necropolis and defeat **Ammit**, the Devourer of Hearts (crocodile head, lion body, hippopotamus hindquarters), in the Hall of Two Truths.
- All content must be original: do not copy characters, names, assets or levels from existing games.

## 3. Camera

- Fixed 3/4 angle: perspective camera with a narrow FOV (~35°), pitched ~50–55° down, rotated 45° on Y, distance ~14 m. Expose all parameters with `@export`. Add a switchable orthographic variant.
- Smooth follow (damping) with look-ahead in the direction of movement and aim.
- Slight zoom-out during the boss fight so the arena fits in frame.
- Walls and pillars between the camera and the player fade out via a **dither shader** (not alpha transparency, to avoid sorting issues).
- Trauma-based camera shake: `FastNoiseLite` noise, strength = trauma², decaying over time. Intensity adjustable in the settings menu.

## 4. Player controls and movement

- Camera-relative movement. Snappy acceleration and deceleration with no "ice" feel; smooth body rotation with a capped turn rate.
- Actions: light attack (3-hit chain), heavy attack (chargeable), dodge roll with i-frames, ranged attack, heal, interact, target lock-on (with switching between targets).
- Aiming: on mouse, attacks go toward the cursor (ray projected onto the floor plane); on gamepad, toward the right stick, otherwise the movement direction.
- Soft aim assist: attacks rotate slightly toward the nearest enemy within a ~60° cone and take a small step toward it.
- Input buffer ~0.15 s: a press during recovery executes at the first opportunity.
- Cancel windows: attack recovery can be cancelled into a dodge; the end of a dodge can go straight into an attack.

Timing targets (in seconds; all stored in Resource files and easy to tweak):

| Action | Windup | Active | Recovery |
|---|---|---|---|
| Light 1 / 2 / 3 | 0.10 / 0.10 / 0.16 | 0.08 | 0.20 / 0.20 / 0.35 |
| Heavy | 0.40 (+ charge up to 0.8) | 0.12 | 0.45 |

Dodge: 0.35 s, i-frames from 0.05 to 0.25 s, ~4.5 m distance. Run speed ~6 m/s.

## 5. Combat feel (top priority)

- **Hitboxes**: `Area3D`, enabled only during the active phase. Hurtboxes on every character. Factions so enemies don't hit each other.
- **Hitstop** of 50–90 ms on hit (longer for heavy attacks). Local by default: freeze animation and movement of the attacker and the target while the rest of the world keeps running. Use global `Engine.time_scale` only for special moments (the boss kill).
- **Hit reactions**: white material flash, decaying knockback, micro-stagger, particles (sand, sparks; faience shards for the hero), sound hook.
- **Weapon trail**: ribbon mesh (`ImmediateMesh` or `ArrayMesh`) built from two points on the blade, faded out by a shader.
- **Enemy telegraphs**: every enemy attack has a readable windup — pose, glint on the weapon, sound — long enough to react to.
- **Poise and stagger**: enemies have a poise meter. Breaking it causes a long stagger and opens a damage window.
- **Player resources**:
  - HP.
  - Stamina: spent on dodges and attacks, regenerates quickly. Toggled by a flag in the balance settings (on by default).
  - Solar energy: 4 charges for the "Eye of Ra" ranged attack. Charges refill by landing melee hits — this rewards aggression.
- **"Ankh" heal**: 3 charges, 0.7 s animation, during which the player can only walk slowly. Healing can be punished.

## 6. Animation

You can't author art, so build everything so that final quality depends on assets, not on rewriting code.

- Characters: `AnimationTree` with a state machine. Locomotion via `BlendSpace1D` (idle → walk → run). Attacks, dodge, hit reaction and death are separate states. Where possible, hitbox activation, footsteps and sounds are driven by animation tracks (method/call tracks), not by timers in code.
- A single animation-name mapping table (dictionary), so a model can be swapped without touching logic. Support humanoid skeleton retargeting (`BoneMap` + `SkeletonProfileHumanoid` in import settings) so animations from Mixamo, Quaternius or KayKit work.
- If you have network access, you may download free CC0 animated character packs (e.g. Quaternius or KayKit). Verify the license on the source page and record it in `CREDITS.md`. Without network access, use placeholders.
- **Placeholders must look decent**: stylized characters built from primitives (capsules, boxes, cylinders with their own materials) arranged in a "skeleton" hierarchy, animated in `AnimationPlayer` with anticipation, squash & stretch, body lean into turns, run bob and hit recoil. Combat must read clearly even with placeholders.
- Procedural layers on top of any animation: lean into turns, additive hit reaction, stretch on dashes.

## 7. Enemies and AI

Shared state machine: Idle/Patrol → Alert → Chase → Strafe (circles at range) → Attack (windup → strike → recovery) → Stagger → Dead. Navigation via `NavigationRegion3D` + `NavigationAgent3D`.

**Attack tokens**: at most 2 enemies attack at once; the rest circle. Fights must feel fair.

1. **Mummy Guardian** — slow, tanky, high poise. Overhead slam and a grab (escapable by dodging at the moment of the flash).
2. **Scarabs** — small and fast, in swarms of 4–6. Lunging bite, low HP.
3. **Jackal Warrior** — agile, 3-hit combo, sidesteps, sometimes dodges the player's attacks.
4. **Cobra Priestess** — ranged: venom spit with a clear windup that leaves a poison puddle on the floor for a few seconds. Retreats when the player gets close.

## 8. Boss: Ammit

- **Arena**: the Hall of Two Truths with giant scales in the center. The entrance closes behind the player with a "sand veil".
- **Phase 1**: turning charge, double jaw snap, sweeping tail strike, leap with a shockwave.
- **Phase 2** (HP < 50%): roar with a short pause and a lighting change, part of the floor sinks into quicksand, scarab summons, faster combos, burrow under the sand and strike from below (telegraphed by a circle on the floor).
- Boss health bar with name. Victory: slow-motion, flash, reward, gate opens.

## 9. Souls-like loop

- **Altars of Osiris** are checkpoints. Resting restores HP and Ankh charges, respawns enemies and opens the level-up menu.
- **"Ka" currency** drops from enemies. On death, all Ka stays in a "heart" at the death location. Pick it up — otherwise it's lost on the next death. Death screen: "YOUR HEART HAS BEEN WEIGHED".
- **Leveling** with Ka: Vitality, Strength, Spirit (energy and Eye of Ra damage). Cost rises with each level.
- **Saving** to `user://` (JSON): last altar, Ka, levels, opened shortcuts, boss defeated, collected rewards.

## 10. Level: the Necropolis

One interconnected zone, 10–15 minutes to complete:

1. Sunlit courtyard: sand, broken statues, first altar. Tutorial on mummies and scarabs.
2. Descent into the tomb: torchlit corridors, fog, pressure-plate spike traps (telegraphed), jackal and cobra ambushes.
3. Side room with a reward (+1 Ankh charge).
4. Shortcut: a lever opens a gate back to the courtyard and the first altar.
5. Second altar before the arena, sand veil, boss.

Build the level from a modular kit (walls, lotus-capital columns, stairs, arches, statues, obelisks) — from primitives/CSG or via `GridMap` + `MeshLibrary`. Materials: sandstone (triplanar shader with noise), lapis lazuli, turquoise, gold, terracotta, black basalt. Hieroglyphs as procedurally generated textures or decals.

## 11. Visuals and atmosphere

- `WorldEnvironment`: glow, SSAO, ACES or AgX tonemapping, volumetric fog in the tomb.
- Outside: warm sunlight `DirectionalLight3D`; inside: flickering `OmniLight3D` torches. Shadows only on key lights.
- Particles: dust in light shafts, sand kicked up by feet, sparks, torch embers.
- Palette: sand gold, deep lapis, turquoise, black basalt.

## 12. Audio

`AudioManager` (autoload) with Master / Music / SFX buses and hooks on every combat event. If no sounds are available, generate simple placeholders (blade whoosh, hit, dodge, footsteps) with a script and place them in `assets/audio/`. Bus volumes in settings.

## 13. UI

HP, stamina, energy and Ankh charges, Ka counter, boss bar, interaction prompts, death screen, pause menu, settings (volume, camera shake strength, fullscreen). Style: gold on dark lapis, papyrus frames.

## 14. Architecture

- Folders: `scenes/`, `scripts/` (subfolders `player/`, `enemies/`, `combat/`, `ui/`, `world/`, `systems/`), `resources/`, `assets/`, `tests/`.
- Components: `HealthComponent`, `HitboxComponent`, `HurtboxComponent`, `PoiseComponent`, `StateMachine` / `State`.
- Autoloads: `GameState`, `SaveSystem`, `AudioManager`, a hitstop and camera-shake service.
- Combat data in Resources (`.tres`): `AttackData` (damage, timings, hitstop, knockback, poise damage, stamina cost), `EnemyData`, `PlayerStats`.
- Debug: **F3** — overlay with FPS and current state-machine states; **F4** — show hitboxes and hurtboxes.

## 15. Workflow

Milestones:

0. Project, folder structure, Input Map, git; an empty main scene runs.
1. Player + camera + test arena: movement and dodge feel great.
2. Combat core: attack chain, hitboxes, training dummy, hitstop, shake, VFX, trail.
3. Four enemy types + AI + navigation.
4. Souls-like loop: altars, death and heart, healing, leveling, saving.
5. The Necropolis level + lighting and atmosphere.
6. Ammit boss fight.
7. UI, menus, audio, polish, performance.
8. Final verification and documentation.

After **every** milestone:

- Import resources: `godot --headless --import` (on older 4.x versions: `godot --headless --editor --quit`).
- Run the main and test scenes: `godot --headless --quit-after 600`. The output must contain no `ERROR` or `SCRIPT ERROR`. Fix all errors and warnings.
- Smoke test `tests/smoke_test.tscn`: instantiates the player, every enemy and the boss, runs ~10 seconds of simulation with a bot spamming attacks and dodges, and logs the result.
- Update `PROGRESS.md` and make a git commit.

You can't see the screen, so verify through logic and logs. If something can only be checked visually, note in `PROGRESS.md` what a human should look at.

## 16. Acceptance criteria

- The project opens in Godot 4 and runs with F5 with no errors in the console.
- The slice is completable from start to boss victory in 10–15 minutes, with no dead ends or getting stuck in geometry.
- Combat is responsive: input buffer, cancels, hitstop, shake, VFX, trail and enemy telegraphs all work.
- Death, the Ka heart, altars, leveling and saving all work.
- All balance parameters live in Resource files.
- No `TODO` / `pass` stubs in place of real game logic.
- `README.md` in Russian: controls (keyboard and gamepad), how to run, how to replace placeholders with real models and animations (CC0 packs, Mixamo) via retargeting.
- `CREDITS.md` listing all external assets and their licenses.

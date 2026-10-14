#!/usr/bin/env python3
"""Dev tool: writes the enemy .tscn files (shared layout, per-type parameters).
Run from the project root: python3 tools/gen_enemy_scenes.py
The generated scenes are plain Godot scenes and can be edited in the editor afterwards."""

COMMON_STATES = ["Idle", "Alert", "Chase", "Strafe", "Attack", "Flinch", "Stagger", "Return", "Dead"]
STATE_SCRIPTS = {
    "Idle": "idle_state.gd", "Alert": "alert_state.gd", "Chase": "chase_state.gd",
    "Strafe": "strafe_state.gd", "Attack": "attack_state.gd", "Flinch": "flinch_state.gd",
    "Stagger": "stagger_state.gd", "Return": "return_state.gd", "Dead": "dead_state.gd",
    "Retreat": "retreat_state.gd", "Evade": "evade_state.gd",
}

ENEMIES = {
    "training_dummy": dict(script="res://scripts/enemies/training_dummy.gd", rig="res://scripts/rigs/dummy_rig.gd",
                           anim="res://resources/animation/dummy_anim_map.tres", data="res://resources/enemies/dummy.tres",
                           radius=0.45, height=2.0, hurt_r=0.55, hurt_h=2.0, lock=1.4, extra=[], states=["Idle", "Flinch", "Stagger", "Dead"],
                           sound="hit_stone", burst="sand", layer=4),
    "mummy": dict(script="res://scripts/enemies/mummy.gd", rig="res://scripts/rigs/mummy_rig.gd",
                  anim="res://resources/animation/mummy_anim_map.tres", data="res://resources/enemies/mummy.tres",
                  radius=0.48, height=2.0, hurt_r=0.6, hurt_h=2.0, lock=1.4, extra=[], sound="hit_enemy", burst="sand", voice="mummy_groan"),
    "scarab": dict(script="res://scripts/enemies/scarab.gd", rig="res://scripts/rigs/scarab_rig.gd",
                   anim="res://resources/animation/scarab_anim_map.tres", data="res://resources/enemies/scarab.tres",
                   radius=0.32, height=0.7, hurt_r=0.45, hurt_h=0.9, lock=0.5, extra=[], sound="hit_stone", burst="sparks", voice="scarab_chitter"),
    "jackal": dict(script="res://scripts/enemies/jackal.gd", rig="res://scripts/rigs/jackal_rig.gd",
                   anim="res://resources/animation/jackal_anim_map.tres", data="res://resources/enemies/jackal.tres",
                   radius=0.4, height=1.9, hurt_r=0.5, hurt_h=1.9, lock=1.3, extra=["Evade"], sound="hit_enemy", burst="sand", voice="jackal_growl"),
    "cobra": dict(script="res://scripts/enemies/cobra.gd", rig="res://scripts/rigs/cobra_rig.gd",
                  anim="res://resources/animation/cobra_anim_map.tres", data="res://resources/enemies/cobra.tres",
                  radius=0.45, height=1.9, hurt_r=0.55, hurt_h=1.9, lock=1.3, extra=["Retreat"], sound="hit_enemy", burst="sand", voice="cobra_hiss"),
}


def scene(name, p):
    states = p.get("states", COMMON_STATES) + p["extra"]
    ext = [
        ("Script", p["script"]), ("Script", p["rig"]), ("Resource", p["anim"]), ("Resource", p["data"]),
        ("Script", "res://scripts/combat/health_component.gd"), ("Script", "res://scripts/combat/poise_component.gd"),
        ("Script", "res://scripts/combat/hurtbox_component.gd"), ("Script", "res://scripts/combat/hitbox_component.gd"),
        ("Script", "res://scripts/systems/fsm/state_machine.gd"),
    ]
    for s in states:
        ext.append(("Script", "res://scripts/enemies/states/" + STATE_SCRIPTS[s]))
    out = ["[gd_scene format=3]", ""]
    for i, (t, path) in enumerate(ext):
        out.append('[ext_resource type="%s" path="%s" id="%d"]' % (t, path, i + 1))
    out.append("")
    h = p["height"]
    out += ['[sub_resource type="CapsuleShape3D" id="body_shape"]', "radius = %s" % p["radius"], "height = %s" % h, "",
            '[sub_resource type="CapsuleShape3D" id="hurt_shape"]', "radius = %s" % p["hurt_r"], "height = %s" % p["hurt_h"], "",
            '[sub_resource type="BoxShape3D" id="hit_shape"]', "size = Vector3(1.5, 1.4, 1.5)", ""]
    title = "".join(w.capitalize() for w in name.split("_"))
    out += ['[node name="%s" type="CharacterBody3D"]' % title,
            "collision_layer = 4", "collision_mask = 39", "floor_max_angle = 0.82", "floor_snap_length = 0.45",
            'script = ExtResource("1")', "faction = 1", "lock_height = %s" % p["lock"], "body_radius = %s" % p["radius"],
            'data = ExtResource("4")', 'hit_sound = &"%s"' % p["sound"], 'hit_burst = &"%s"' % p["burst"]]
    if p.get("voice"):
        out.append('voice_sound = &"%s"' % p["voice"])
    out.append("")
    out += ['[node name="CollisionShape3D" type="CollisionShape3D" parent="."]',
            "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, %s, 0)" % (h / 2.0), 'shape = SubResource("body_shape")', "",
            '[node name="Visual" type="Node3D" parent="."]', "",
            '[node name="Rig" type="Node3D" parent="Visual"]', 'script = ExtResource("2")', 'anim_map = ExtResource("3")', "",
            '[node name="Health" type="Node" parent="."]', 'script = ExtResource("5")', "",
            '[node name="Poise" type="Node" parent="."]', 'script = ExtResource("6")', "",
            '[node name="Hurtbox" type="Area3D" parent="."]', 'script = ExtResource("7")', "faction = 1", "",
            '[node name="CollisionShape3D" type="CollisionShape3D" parent="Hurtbox"]',
            "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, %s, 0)" % (p["hurt_h"] / 2.0), 'shape = SubResource("hurt_shape")', "",
            '[node name="Hitbox" type="Area3D" parent="."]', 'script = ExtResource("8")', "faction = 1", "",
            '[node name="CollisionShape3D" type="CollisionShape3D" parent="Hitbox"]', 'shape = SubResource("hit_shape")', "",
            '[node name="NavAgent" type="NavigationAgent3D" parent="."]', "path_height_offset = 0.5", "",
            '[node name="StateMachine" type="Node" parent="."]', 'script = ExtResource("9")', 'initial_state = &"Idle"', ""]
    for i, s in enumerate(states):
        out += ['[node name="%s" type="Node" parent="StateMachine"]' % s, 'script = ExtResource("%d")' % (10 + i), ""]
    with open("scenes/enemies/%s.tscn" % name, "w") as f:
        f.write("\n".join(out))


if __name__ == "__main__":
    import sys
    names = sys.argv[1:] or list(ENEMIES)
    for n in names:
        scene(n, ENEMIES[n])
        print("wrote scenes/enemies/%s.tscn" % n)

class_name DummyRig
extends PlaceholderRig
## Training dummy: wooden post with a linen-wrapped straw body and a painted target.


func _build_body() -> void:
	var wood := Mats.get_mat(&"wood")
	var linen := Mats.get_mat(&"linen")
	add_bone("Body", "", Vector3.ZERO)
	part("Body", cylinder(0.35, 0.45, 0.25, 10), Mats.get_mat(&"basalt"), Vector3(0, 0.12, 0))
	add_bone("Post", "Body", Vector3(0, 0.25, 0))
	part("Post", cylinder(0.07, 0.08, 1.4, 8), wood, Vector3(0, 0.7, 0))
	add_bone("Torso", "Post", Vector3(0, 0.9, 0))
	part("Torso", capsule(0.3, 0.9), linen, Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	part("Torso", cylinder(0.04, 0.04, 1.4, 6), wood, Vector3(0, 0.55, 0), Vector3(0, 0, 90))
	part("Torso", sphere(0.12), linen, Vector3(0.7, 0.55, 0))
	part("Torso", sphere(0.12), linen, Vector3(-0.7, 0.55, 0))
	part("Torso", cylinder(0.18, 0.18, 0.03, 16), Mats.get_mat(&"red_cloth"), Vector3(0, 0.3, -0.24), Vector3(90, 0, 0))
	part("Torso", cylinder(0.1, 0.1, 0.035, 16), Mats.get_mat(&"gold"), Vector3(0, 0.3, -0.25), Vector3(90, 0, 0))
	add_bone("Head", "Torso", Vector3(0, 0.8, 0))
	part("Head", sphere(0.2), linen, Vector3(0, 0.12, 0))
	part("Head", box(Vector3(0.18, 0.03, 0.02)), Mats.get_mat(&"black_glaze"), Vector3(0, 0.15, -0.19))
	add_socket(&"head", "Head", Vector3(0, 0.2, -0.1))


func _build_clips(lib: AnimationLibrary) -> void:
	var rest := {"Post": Vector3.ZERO, "Torso": Vector3.ZERO, "Head": Vector3.ZERO}
	var idle := AnimBuilder.new(self, &"idle", 3.0, true)
	idle.key(0.0, rest)
	idle.key(1.5, {"Torso": Vector3(2, 0, 2), "Head": Vector3(-2, 0, 0)})
	lib.add_animation(&"idle", idle.build())
	lib.add_animation(&"walk", idle.build())
	lib.add_animation(&"run", idle.build())
	var hit := AnimBuilder.new(self, &"hit", float(clip_table.get(&"hit", {}).get("length", 0.3)))
	hit.key(0.0, rest)
	hit.key(0.06, {"Post": Vector3(14, 0, 0), "Torso": Vector3(10, 0, 0), "Head": Vector3(12, 0, 0)}, AnimBuilder.SNAP)
	hit.key(0.16, {"Post": Vector3(-6, 0, 0), "Torso": Vector3(-4, 0, 0), "Head": Vector3(-6, 0, 0)}, AnimBuilder.INOUT)
	hit.key(hit.length, rest, AnimBuilder.INOUT)
	lib.add_animation(&"hit", hit.build())
	var st := AnimBuilder.new(self, &"stagger", float(clip_table.get(&"stagger", {}).get("length", 2.0)))
	st.key(0.0, rest)
	st.key(0.12, {"Post": Vector3(28, 0, 6), "Torso": Vector3(20, 0, 10), "Head": Vector3(25, 0, 0)}, AnimBuilder.SNAP)
	st.key(0.5, {"Post": Vector3(-16, 0, -6), "Torso": Vector3(-10, 0, -8)}, AnimBuilder.INOUT)
	st.key(0.9, {"Post": Vector3(9, 0, 4), "Torso": Vector3(6, 0, 4)}, AnimBuilder.INOUT)
	st.key(1.3, {"Post": Vector3(-4, 0, -2), "Torso": Vector3(-2, 0, 0)}, AnimBuilder.INOUT)
	st.key(st.length, rest, AnimBuilder.INOUT)
	lib.add_animation(&"stagger", st.build())

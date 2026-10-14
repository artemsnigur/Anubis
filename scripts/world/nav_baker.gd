class_name NavBaker
extends RefCounted
## Configures and bakes a NavigationRegion3D from the static colliders under it.


static func configure(region: NavigationRegion3D) -> void:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 46.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = CombatTypes.LAYER_WORLD | CombatTypes.LAYER_GATE
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	nm.region_min_size = 4.0
	nm.edge_max_error = 1.2
	region.navigation_mesh = nm


static func bake(region: NavigationRegion3D) -> void:
	if region.navigation_mesh == null:
		configure(region)
	var t0 := Time.get_ticks_msec()
	region.bake_navigation_mesh(false)
	print("NavBaker: baked %s in %d ms (%d polygons)" % [region.name, Time.get_ticks_msec() - t0, region.navigation_mesh.get_polygon_count()])


## Re-bake on a worker thread (geometry is parsed on the main thread first).
static func rebake_async(region: NavigationRegion3D) -> void:
	if region.is_baking():
		region.bake_finished.connect(func() -> void: region.bake_navigation_mesh(true), CONNECT_ONE_SHOT)
		return
	region.bake_navigation_mesh(true)

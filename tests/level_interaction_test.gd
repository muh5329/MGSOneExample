extends SceneTree

const LEVEL_PATH := "res://scenes/levels/substation_6.tscn"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(LEVEL_PATH) as PackedScene
	if packed == null:
		failures.append("Substation 6 scene does not load.")
		_finish()
		return
	var level := packed.instantiate() as Substation6
	get_root().add_child(level)
	await process_frame
	await physics_frame
	await physics_frame
	_validate_content_budget(level)
	_validate_geometry_and_navigation(level)
	_validate_focus_order(level)
	await _validate_progression_seams(level)
	level.queue_free()
	await process_frame
	_finish()


func _validate_content_budget(level: Substation6) -> void:
	_expect_count(get_nodes_in_group(&"mission_rooms"), 7, "mission rooms")
	_expect_count(get_nodes_in_group(&"camera_zones"), 10, "camera zones")
	_expect_count(get_nodes_in_group(&"doors"), 3, "authored doors")
	_expect_count(get_nodes_in_group(&"mission_markers"), 6, "mission markers")
	_expect_count(get_nodes_in_group(&"guard_patrol_routes"), 4, "guard patrol routes")
	_expect_count(get_nodes_in_group(&"debug_spawn_points"), 9, "checkpoint/debug spawns")
	var checkpoints := get_nodes_in_group(&"checkpoint_targets")
	_expect_count(checkpoints, 2, "checkpoint triggers")
	for room_id in [
		&"R0_DRAINAGE", &"R1_LOADING_YARD", &"R2_SUPPLY_CAGE",
		&"R3_SECURITY_HALL", &"R4_MAINTENANCE", &"R5_SWITCH_FLOOR", &"R6_CONTROL",
	]:
		if level.geometry_root.get_node_or_null(NodePath(String(room_id))) == null:
			failures.append("Missing authored room '%s'." % room_id)
	for marker_id in [
		&"W1_PISTOL", &"A1_PISTOL_AMMO", &"I1_RATION",
		&"K1_LEVEL_1_CARD", &"O1_RELAY_TERMINAL", &"X1_DRAINAGE_GATE",
	]:
		if level.mission_root.get_node_or_null(NodePath(String(marker_id))) == null:
			failures.append("Missing mission object '%s'." % marker_id)
	for transition_point in [
		Vector3(-28, 0.02, 0), Vector3(7, 0.02, 0), Vector3(-10, 0.02, 14.5),
		Vector3(20, 0.02, 9), Vector3(20, 0.02, -10),
		Vector3(3, 0.02, -28), Vector3(-10, 0.02, -15.5),
	]:
		var containing_zones := 0
		for zone_node in get_nodes_in_group(&"camera_zones"):
			if (zone_node as CameraZone3D).contains_world_point(transition_point):
				containing_zones += 1
		if containing_zones == 0:
			failures.append("Camera coverage gap at connection point %s." % transition_point)


func _validate_geometry_and_navigation(level: Substation6) -> void:
	for cover_id in [
		&"R1_CARGO_WEST", &"R1_CARGO_CENTER", &"R1_CARGO_EAST",
		&"R4_PIPE_BANK_A", &"R4_PIPE_BANK_B",
		&"R5_TRANSFORMER_W", &"R5_TRANSFORMER_C", &"R5_TRANSFORMER_E",
	]:
		var cover := level.geometry_root.get_node_or_null(NodePath(String(cover_id)))
		if cover == null:
			failures.append("Missing occlusion cluster '%s'." % cover_id)
			continue
		var body := cover.get_node_or_null("Collision") as StaticBody3D
		if body == null or body.collision_layer != 33:
			failures.append("Cover '%s' is not consistent world/perception collision." % cover_id)
	var navigation_root := get_first_node_in_group(&"mission_navigation") as Node3D
	if navigation_root == null:
		failures.append("Mission navigation authoring root is missing.")
	else:
		var polygon_count := 0
		for child in navigation_root.get_children():
			if child is NavigationRegion3D and (child as NavigationRegion3D).navigation_mesh != null:
				polygon_count += (child as NavigationRegion3D).navigation_mesh.get_polygon_count()
		if polygon_count < 14:
			failures.append("Mission navigation does not cover all rooms and connections.")
	for door_node in get_nodes_in_group(&"doors"):
		var door := door_node as Door3D
		if door.navigation_link == null:
			failures.append("Door '%s' has no navigation boundary link." % door.door_id)
		if door.door_body.collision_layer != 33:
			failures.append("Closed door '%s' is not a world/perception blocker." % door.door_id)
	for route_node in get_nodes_in_group(&"guard_patrol_routes"):
		if route_node.get_child_count() != 4:
			failures.append("Patrol '%s' does not expose four authored points." % route_node.name)


func _validate_focus_order(level: Substation6) -> void:
	var alpha := Interactable3D.new()
	alpha.interaction_id = &"ALPHA"
	alpha.interaction_priority = 5
	alpha.position = level.player.position + Vector3(0.5, 0.0, 0.0)
	var beta := Interactable3D.new()
	beta.interaction_id = &"BETA"
	beta.interaction_priority = 5
	beta.position = alpha.position
	level.add_child(beta)
	level.add_child(alpha)
	var candidates: Array[Interactable3D] = [beta, alpha]
	if level.interaction_focus._select_focus(candidates) != alpha:
		failures.append("Equal focus candidates are not resolved by stable interaction ID.")
	beta.interaction_priority = 6
	if level.interaction_focus._select_focus(candidates) != beta:
		failures.append("Interaction priority does not override distance/ID ties.")
	alpha.queue_free()
	beta.queue_free()


func _validate_progression_seams(level: Substation6) -> void:
	var d1 := level.mission_root.get_node("D1_ACCESS") as Door3D
	var d2 := level.mission_root.get_node("D2_SHORTCUT") as Door3D
	var card := level.mission_root.get_node("K1_LEVEL_1_CARD") as MissionMarker3D
	var pistol := level.mission_root.get_node("W1_PISTOL") as MissionMarker3D
	var pistol_ammo := level.mission_root.get_node("A1_PISTOL_AMMO") as MissionMarker3D
	var objective := level.mission_root.get_node("O1_RELAY_TERMINAL") as MissionMarker3D
	var extraction := level.mission_root.get_node("X1_DRAINAGE_GATE") as MissionMarker3D
	var weapon := level.player.get_node("VisualRoot/WeaponController") as WeaponController
	var inventory := level.player.get_node("Inventory") as InventoryComponent
	if d1.interactable.is_available(level.player):
		failures.append("D1 is available before the LEVEL_1 access query succeeds.")
	if d1.interactable.get_unavailable_reason(level.player) != &"LEVEL_1_REQUIRED":
		failures.append("D1 does not expose LEVEL_1_REQUIRED while locked.")
	if extraction.is_available(level.player):
		failures.append("Extraction is available before the objective event.")
	if extraction.get_unavailable_reason(level.player) != &"OBJECTIVE_INCOMPLETE":
		failures.append("Extraction does not expose OBJECTIVE_INCOMPLETE.")
	if weapon.state != WeaponController.WeaponState.HOLSTERED:
		failures.append("Mission pistol is not holstered before the W1 pickup event.")
	if not pistol.interact(level.player):
		failures.append("W1 pickup did not emit its mission event.")
	weapon.advance_runtime(1.0)
	if weapon.definition == null or weapon.definition.weapon_id != &"W1_PISTOL" or weapon.magazine != 8:
		failures.append("W1 pickup did not equip the real loaded pistol runtime.")
	if not pistol_ammo.interact(level.player) or inventory.get_ammo_count(&"pistol_round") != 12:
		failures.append("A1 pickup did not reach the authoritative inventory ammo source.")
	if not card.interact(level.player) or not inventory.has_access_level(&"LEVEL_1"):
		failures.append("K1 pickup did not reach the authoritative access inventory.")
	if not d1.interactable.is_available(level.player):
		failures.append("D1 did not become available after K1 acquisition.")
	if not d1.interactable.interact(level.player) or not d1.is_open or d1.is_locked:
		failures.append("D1 did not unlock and open through its public access query.")
	await process_frame
	if d1.door_body.collision_layer != 0 or not d1.door_collision.disabled or not d1.navigation_link.enabled:
		failures.append("Opening D1 did not synchronize collision, occlusion, and navigation.")
	if objective.hold_duration != 1.25:
		failures.append("Objective terminal does not own the specified 1.25-second hold duration.")
	if not objective.interact(level.player) or not level.mission_state.objective_complete:
		failures.append("Objective event did not reach the authoritative mission coordinator.")
	await process_frame
	if not d2.is_open or d2.is_locked or not d2.navigation_link.enabled:
		failures.append("Objective completion did not expose the D2 shortcut state seam.")
	if not extraction.is_available(level.player):
		failures.append("Extraction did not become available after objective completion.")
	await physics_frame
	await physics_frame
	var navigation_map := level.get_mission_navigation_map()
	if navigation_map.is_valid():
		var route := NavigationServer3D.map_get_path(
			navigation_map,
			Vector3(-46.0, 0.02, 0.0),
			Vector3(-10.0, 0.02, -31.0),
			true
		)
		if route.size() < 2 or route[-1].distance_to(Vector3(-10.0, 0.02, -31.0)) > 0.6:
			failures.append("Open-door navigation cannot route from R0 to the R6 objective recess: %s" % route)
		var closed_supply_route := NavigationServer3D.map_get_path(
			navigation_map,
			Vector3(-10.0, 0.02, 8.0),
			Vector3(-10.0, 0.02, 24.0),
			true
		)
		if not closed_supply_route.is_empty() and closed_supply_route[-1].distance_to(Vector3(-10.0, 0.02, 24.0)) <= 0.6:
			failures.append("Closed supply door did not split its navigation boundary: %s" % closed_supply_route)
		var supply_door := level.mission_root.get_node("D0_SUPPLY_CAGE") as Door3D
		supply_door.set_open(true)
		await physics_frame
		await physics_frame
		var open_supply_route := NavigationServer3D.map_get_path(
			navigation_map,
			Vector3(-10.0, 0.02, 8.0),
			Vector3(-10.0, 0.02, 24.0),
			true
		)
		if open_supply_route.size() < 2 or open_supply_route[-1].distance_to(Vector3(-10.0, 0.02, 24.0)) > 0.6:
			failures.append("Open supply door did not reconnect its navigation boundary: %s" % open_supply_route)


func _expect_count(nodes: Array[Node], expected: int, label: String) -> void:
	if nodes.size() != expected:
		failures.append("Expected %d %s, found %d." % [expected, label, nodes.size()])


func _finish() -> void:
	if failures.is_empty():
		print("LEVEL PASS: geometry, placements, navigation seams, focus, doors, and mission events are valid.")
		quit(0)
		return
	for failure in failures:
		push_error("LEVEL FAIL: %s" % failure)
	quit(1)

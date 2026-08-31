class_name Substation6
extends Node3D

const DOOR_SCENE := preload("res://scenes/components/door_3d.tscn")
const MARKER_SCENE := preload("res://scenes/components/mission_marker_3d.tscn")
const PICKUP_SCENE := preload("res://scenes/components/inventory_pickup_3d.tscn")
const GUARD_SCENE := preload("res://scenes/actors/guard.tscn")
const GAME_PHASE_NAMES := ["INITIALIZING", "PLAYING", "PAUSED", "PLAYER_DEAD", "COMPLETED", "RESTARTING"]

@onready var geometry_root: Node3D = %Geometry
@onready var mission_root: Node3D = %MissionObjects
@onready var camera_zone_root: Node3D = %CameraZones
@onready var route_root: Node3D = %PatrolRoutes
@onready var spawn_root: Node3D = %SpawnPoints
@onready var guard_root: Node3D = %Guards
@onready var player: PlayerController = %Player
@onready var camera_rig: GameplayCameraRig = %GameplayCameraRig
@onready var interaction_focus: InteractionFocus3D = %InteractionFocus
@onready var inventory: InventoryComponent = player.get_node("Inventory") as InventoryComponent
@onready var mission_state: MissionStateCoordinator = %MissionStateCoordinator
@onready var alert_coordinator: AlertCoordinator = %AlertCoordinator
@onready var inventory_panels: InventoryPanels = %InventoryPanels
@onready var tactical_radar: TacticalRadar = %TacticalRadar
@onready var feedback_manager: FeedbackManager = %FeedbackManager
@onready var mission_hud: MissionHUD = %MissionHUD
@onready var room_label: Label = %RoomLabel
@onready var prompt_label: Label = %PromptLabel
@onready var status_label: Label = %StatusLabel
@onready var health_label: Label = %HealthLabel

var _materials: Dictionary = {}
var _navigation_rects: Array[Rect2] = []
var _navigation_surfaces: Array[Dictionary] = []
var _current_room: StringName = &"R0_DRAINAGE"
var _last_prompt: String = ""
var _radar_map_segments: Array[Dictionary] = []


func _ready() -> void:
	_create_materials()
	_build_rooms_and_connections()
	_build_cover_and_landmarks()
	_build_navigation()
	_build_camera_zones()
	_build_spawns_and_patrols()
	_build_guards()
	_build_mission_objects()
	_configure_runtime_contracts()


func _process(_delta: float) -> void:
	room_label.text = "ROOM  %s    ZONE  %s" % [
		_current_room,
		String(camera_rig.active_zone.get_zone_id()) if camera_rig.active_zone != null else "FALLBACK",
	]
	var snapshot := interaction_focus.get_prompt_snapshot()
	if snapshot.target == null:
		prompt_label.text = ""
	elif snapshot.available:
		prompt_label.text = "[F / A]  %s" % snapshot.prompt
	else:
		prompt_label.text = "%s  —  %s" % [snapshot.prompt, snapshot.reason]
	health_label.text = "HEALTH  %d / %d    CHECKPOINT  %s    PHASE  %s" % [
		roundi(player.health.current_health),
		roundi(player.health.maximum_health),
		mission_state.active_checkpoint_id,
		GAME_PHASE_NAMES[int(get_node("/root/GameState").phase)],
	]


func get_debug_snapshot() -> Dictionary:
	var weapon := player.get_node_or_null("WeaponController") as WeaponController
	var guards: Array[Dictionary] = []
	for guard_value in guard_root.get_children():
		var guard := guard_value as GuardActor
		if guard == null:
			continue
		var guard_snapshot := guard.get_radar_snapshot()
		guards.append({
			&"guard_id": guard_snapshot.get(&"guard_id", &""),
			&"state": guard_snapshot.get(&"state", &"UNKNOWN"),
			&"suspicion": guard_snapshot.get(&"suspicion", 0.0),
			&"visible": guard_snapshot.get(&"target_visible", false),
		})
	return {
		&"room": _current_room,
		&"checkpoint": mission_state.active_checkpoint_id,
		&"player": {
			&"position": player.global_position,
			&"stance": player.stance,
			&"speed": Vector2(player.velocity.x, player.velocity.z).length(),
			&"noise": player.movement_noise_intensity,
			&"control_enabled": player.control_enabled,
			&"weapon_state": weapon.state if weapon != null else -1,
		},
		&"camera": {
			&"zone": camera_rig.active_zone.get_zone_id() if camera_rig.active_zone != null else &"FALLBACK",
			&"mode": camera_rig.mode,
			&"transitioning": camera_rig.is_transitioning,
			&"obstructed": camera_rig.aim_is_obstructed,
			&"aim_direction": camera_rig.get_aim_direction(),
		},
		&"alert": alert_coordinator.get_alert_snapshot(),
		&"feedback": feedback_manager.get_feedback_snapshot(),
		&"guards": guards,
	}


func _create_materials() -> void:
	_materials = {
		&"R0": _material(Color(0.08, 0.22, 0.24, 1.0)),
		&"R1": _material(Color(0.12, 0.2, 0.3, 1.0)),
		&"R2": _material(Color(0.12, 0.28, 0.2, 1.0)),
		&"R3": _material(Color(0.3, 0.23, 0.11, 1.0)),
		&"R4": _material(Color(0.28, 0.25, 0.13, 1.0)),
		&"R5": _material(Color(0.24, 0.12, 0.12, 1.0)),
		&"R6": _material(Color(0.1, 0.26, 0.24, 1.0)),
		&"CORRIDOR": _material(Color(0.1, 0.13, 0.14, 1.0)),
		&"WALL": _material(Color(0.18, 0.22, 0.22, 1.0)),
		&"COVER": _material(Color(0.28, 0.32, 0.3, 1.0)),
		&"HAZARD": _material(Color(0.5, 0.18, 0.06, 1.0), Color(0.12, 0.02, 0.0, 1.0)),
		&"INTERACTABLE": _material(Color(0.08, 0.58, 0.42, 1.0), Color(0.01, 0.2, 0.1, 1.0)),
		&"TRENCH": _material(Color(0.025, 0.045, 0.05, 1.0)),
	}


func _build_rooms_and_connections() -> void:
	_add_room(&"R0_DRAINAGE", Vector2(-41.0, 0.0), Vector2(18.0, 14.0), &"R0", {
		&"east": [Vector2(0.0, 4.0)],
	})
	_add_room(&"R1_LOADING_YARD", Vector2(-10.0, 0.0), Vector2(28.0, 22.0), &"R1", {
		&"west": [Vector2(0.0, 4.0)],
		&"east": [Vector2(0.0, 4.0)],
		&"north": [Vector2(-10.0, 4.0)],
		&"south": [Vector2(-10.0, 4.0)],
	})
	_add_room(&"R2_SUPPLY_CAGE", Vector2(-10.0, 24.0), Vector2(14.0, 12.0), &"R2", {
		&"north": [Vector2(0.0, 4.0)],
	})
	_add_room(&"R3_SECURITY_HALL", Vector2(20.0, 0.0), Vector2(20.0, 12.0), &"R3", {
		&"west": [Vector2(0.0, 4.0)],
		&"north": [Vector2(0.0, 4.0)],
		&"south": [Vector2(0.0, 4.0)],
	})
	_add_room(&"R4_MAINTENANCE", Vector2(20.0, 22.0), Vector2(18.0, 20.0), &"R4", {
		&"north": [Vector2(0.0, 4.0)],
	})
	_add_room(&"R5_SWITCH_FLOOR", Vector2(20.0, -24.0), Vector2(24.0, 20.0), &"R5", {
		&"south": [Vector2(0.0, 4.0)],
		&"west": [Vector2(-4.0, 4.0)],
	})
	_add_room(&"R6_CONTROL", Vector2(-10.0, -28.0), Vector2(16.0, 16.0), &"R6", {
		&"east": [Vector2(0.0, 4.0)],
		&"south": [Vector2(0.0, 4.0)],
	})

	_add_corridor(&"C_R0_R1", Vector2(-28.0, 0.0), Vector2(8.0, 4.0))
	_add_corridor(&"C_R1_R3", Vector2(7.0, 0.0), Vector2(6.0, 4.0))
	_add_corridor(&"C_R1_R2", Vector2(-10.0, 14.5), Vector2(4.0, 7.0), 14.5)
	_add_corridor(&"C_R3_R4", Vector2(20.0, 9.0), Vector2(4.0, 6.0))
	_add_corridor(&"C_R3_R5", Vector2(20.0, -10.0), Vector2(4.0, 8.0), -10.0)
	_add_corridor(&"C_R5_R6", Vector2(3.0, -28.0), Vector2(10.0, 4.0))
	_add_corridor(&"C_R6_R1_SHORTCUT", Vector2(-10.0, -15.5), Vector2(4.0, 9.0), -15.5)


func _build_cover_and_landmarks() -> void:
	_add_cover(&"R0_PIPE_COVER", Vector3(-42.5, 0.5, 2.5), Vector3(5.0, 1.0, 1.0), &"COVER")
	_add_cover(&"R1_CARGO_WEST", Vector3(-17.0, 1.2, -4.5), Vector3(4.0, 2.4, 4.0), &"COVER")
	_add_cover(&"R1_CARGO_CENTER", Vector3(-9.0, 1.2, 1.0), Vector3(4.5, 2.4, 4.5), &"COVER")
	_add_cover(&"R1_CARGO_EAST", Vector3(-2.0, 1.2, 6.0), Vector3(3.5, 2.4, 3.5), &"COVER")
	_add_cover(&"R3_SIGHTLINE_DIVIDER", Vector3(20.0, 1.4, 2.0), Vector3(7.0, 2.8, 0.7), &"WALL")
	_add_cover(&"R4_PIPE_BANK_A", Vector3(15.5, 1.2, 18.0), Vector3(2.0, 2.4, 6.0), &"COVER")
	_add_cover(&"R4_PIPE_BANK_B", Vector3(24.5, 1.2, 26.0), Vector3(2.0, 2.4, 6.0), &"COVER")
	_add_cover(&"R4_LOCKER", Vector3(26.5, 1.3, 15.0), Vector3(1.4, 2.6, 1.4), &"INTERACTABLE")
	_add_cover(&"R5_TRANSFORMER_W", Vector3(14.0, 1.45, -24.0), Vector3(3.0, 2.9, 7.0), &"HAZARD")
	_add_cover(&"R5_TRANSFORMER_C", Vector3(20.0, 1.45, -24.0), Vector3(3.0, 2.9, 7.0), &"HAZARD")
	_add_cover(&"R5_TRANSFORMER_E", Vector3(26.0, 1.45, -24.0), Vector3(3.0, 2.9, 7.0), &"HAZARD")
	_add_box_visual_and_collision(
		geometry_root, &"R5_SERVICE_TRENCH", Vector3(20.0, 0.025, -31.2),
		Vector3(16.0, 0.05, 2.2), _materials[&"TRENCH"], 0
	)
	_add_cover(&"R6_CONSOLE_RECESS", Vector3(-10.0, 1.0, -33.0), Vector3(7.0, 2.0, 1.0), &"COVER")


func _build_navigation() -> void:
	var navigation_root := Node3D.new()
	navigation_root.name = "MissionNavigation"
	navigation_root.add_to_group(&"mission_navigation")
	%Navigation.add_child(navigation_root)
	var surface_index := 0
	for surface in _navigation_surfaces:
		_add_navigation_region(navigation_root, "RoomSurface%d" % surface_index, _navigation_cells(surface))
		surface_index += 1
	for corridor_index in _navigation_rects.size():
		_add_navigation_region(
			navigation_root,
			"ConnectionSurface%d" % corridor_index,
			[_navigation_rects[corridor_index]]
		)


func _add_navigation_region(parent: Node3D, region_name: String, rects: Array[Rect2]) -> void:
	var navigation_region := NavigationRegion3D.new()
	navigation_region.name = region_name
	navigation_region.use_edge_connections = true
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.agent_radius = 0.45
	navigation_mesh.agent_height = 1.8
	navigation_mesh.agent_max_climb = 0.35
	navigation_mesh.agent_max_slope = 42.0
	var vertices := PackedVector3Array()
	var polygons: Array[PackedInt32Array] = []
	for rect in rects:
		var first := vertices.size()
		vertices.append(Vector3(rect.position.x, 0.02, rect.position.y))
		vertices.append(Vector3(rect.end.x, 0.02, rect.position.y))
		vertices.append(Vector3(rect.end.x, 0.02, rect.end.y))
		vertices.append(Vector3(rect.position.x, 0.02, rect.end.y))
		polygons.append(PackedInt32Array([first, first + 1, first + 2, first + 3]))
	navigation_mesh.vertices = vertices
	for polygon in polygons:
		navigation_mesh.add_polygon(polygon)
	navigation_region.navigation_mesh = navigation_mesh
	parent.add_child(navigation_region)


func get_mission_navigation_map() -> RID:
	var navigation_root := get_tree().get_first_node_in_group(&"mission_navigation")
	if navigation_root == null:
		return RID()
	for child in navigation_root.get_children():
		if child is NavigationRegion3D:
			return (child as NavigationRegion3D).get_navigation_map()
	return RID()


func _build_camera_zones() -> void:
	_add_camera_zone(&"Z0", Vector2(-41.0, 0.0), Vector2(34.0, 16.0), Vector3(11.0, 13.0, 12.0), Vector2(6.0, 4.0), 0.0)
	_add_camera_zone(&"Z1S", Vector2(-10.0, 5.5), Vector2(29.0, 12.0), Vector3(-10.0, 14.0, 13.0), Vector2(9.0, 4.0), 0.35)
	_add_camera_zone(&"Z1N", Vector2(-10.0, -5.5), Vector2(29.0, 12.0), Vector3(11.0, 14.0, -13.0), Vector2(9.0, 4.0), 0.35)
	_add_camera_zone(&"Z2S", Vector2(-10.0, 24.0), Vector2(16.0, 26.0), Vector3(8.0, 10.0, 9.0), Vector2(5.0, 4.0), 0.3)
	_add_camera_zone(&"Z3", Vector2(20.0, 0.0), Vector2(32.0, 16.0), Vector3(11.0, 13.0, 10.0), Vector2(7.0, 4.0), 0.35)
	_add_camera_zone(&"Z4A", Vector2(20.0, 17.0), Vector2(20.0, 18.0), Vector3(-9.0, 12.0, 10.0), Vector2(6.0, 4.0), 0.3)
	_add_camera_zone(&"Z4B", Vector2(20.0, 27.0), Vector2(20.0, 12.0), Vector3(9.0, 12.0, -10.0), Vector2(6.0, 4.0), 0.3)
	_add_camera_zone(&"Z5W", Vector2(14.0, -24.0), Vector2(13.0, 32.0), Vector3(-9.0, 14.0, 12.0), Vector2(4.0, 7.0), 0.4)
	_add_camera_zone(&"Z5E", Vector2(26.0, -24.0), Vector2(13.0, 32.0), Vector3(9.0, 14.0, -12.0), Vector2(4.0, 7.0), 0.4)
	_add_camera_zone(&"Z6", Vector2(-10.0, -28.0), Vector2(36.0, 34.0), Vector3(-10.0, 12.0, 10.0), Vector2(5.0, 5.0), 0.35)


func _build_spawns_and_patrols() -> void:
	_add_spawn(&"CP0_INSERTION", Vector3(-46.0, 0.02, 0.0), &"checkpoint")
	_add_spawn(&"CP1_SWITCH_ENTRY", Vector3(20.0, 0.02, -16.0), &"checkpoint")
	_add_spawn(&"R0_DEBUG", Vector3(-41.0, 0.02, -3.0), &"debug")
	_add_spawn(&"R1_DEBUG", Vector3(-20.0, 0.02, 7.0), &"debug")
	_add_spawn(&"R2_DEBUG", Vector3(-10.0, 0.02, 27.0), &"debug")
	_add_spawn(&"R3_DEBUG", Vector3(14.0, 0.02, -3.0), &"debug")
	_add_spawn(&"R4_DEBUG", Vector3(20.0, 0.02, 29.0), &"debug")
	_add_spawn(&"R5_DEBUG", Vector3(29.0, 0.02, -31.0), &"debug")
	_add_spawn(&"R6_DEBUG", Vector3(-15.0, 0.02, -24.0), &"debug")
	_add_patrol(&"G1", [Vector3(-20, 0.02, -7), Vector3(-2, 0.02, -7), Vector3(-2, 0.02, 8), Vector3(-20, 0.02, 8)], 0, 2.0, Vector3.FORWARD)
	_add_patrol(&"G2", [Vector3(14, 0.02, 15), Vector3(14, 0.02, 29), Vector3(26, 0.02, 29), Vector3(26, 0.02, 18)], 3, 1.5)
	_add_patrol(&"G3", [Vector3(10, 0.02, -32), Vector3(10, 0.02, -16), Vector3(30, 0.02, -16), Vector3(30, 0.02, -32)], -1, 0.0)
	_add_patrol(&"G4", [Vector3(17, 0.02, -31), Vector3(17, 0.02, -17), Vector3(23, 0.02, -17), Vector3(23, 0.02, -31)], -1, 0.0)


func _build_guards() -> void:
	var navigation_map := get_mission_navigation_map()
	for guard_id in [&"G1", &"G2", &"G3", &"G4"]:
		var route := route_root.get_node_or_null(NodePath(String(guard_id))) as PatrolRoute3D
		if route == null:
			push_error("Missing authored patrol route for guard %s." % guard_id)
			continue
		var guard := GUARD_SCENE.instantiate() as GuardActor
		guard.name = String(guard_id)
		guard.guard_id = guard_id
		guard_root.add_child(guard)
		if not guard.configure(guard_id, route, player, navigation_map):
			push_error("Could not configure guard %s." % guard_id)


func _build_mission_objects() -> void:
	var supply_door := _add_door(&"D0_SUPPLY_CAGE", Vector3(-10.0, 0.0, 14.5), false, &"")
	var access_door := _add_door(&"D1_ACCESS", Vector3(20.0, 0.0, -10.0), true, &"LEVEL_1")
	access_door.locked_reason = &"LEVEL_1_REQUIRED"
	var shortcut_door := _add_door(&"D2_SHORTCUT", Vector3(-10.0, 0.0, -15.5), true, &"")
	shortcut_door.locked_reason = &"OBJECTIVE_INCOMPLETE"

	var pistol := _add_inventory_pickup(&"W1_PISTOL", Vector3(-14.0, 0.0, 25.5), "Take pistol", 1, 8, true, {&"magazine": 8})
	var ammo := _add_inventory_pickup(&"A1_PISTOL_AMMO", Vector3(-10.0, 0.0, 26.5), "Take pistol ammo", 12, -1, false, {&"quantity": 12})
	var ration := _add_inventory_pickup(&"I1_RATION", Vector3(-6.0, 0.0, 25.5), "Take ration", 1, -1, false, {&"quantity": 1})
	var access_card := _add_inventory_pickup(&"K1_LEVEL_1_CARD", Vector3(20.0, 0.0, 29.5), "Take Level 1 card", 1, -1, false, {&"access_level": &"LEVEL_1"})
	var objective := _add_marker(&"O1_RELAY_TERMINAL", Vector3(-10.0, 0.0, -31.8), MissionMarker3D.MarkerKind.OBJECTIVE, "Copy relay manifest", 1.25, {})
	objective.scale = Vector3(1.3, 1.3, 1.3)
	var extraction := _add_marker(&"X1_DRAINAGE_GATE", Vector3(-47.0, 0.0, 4.0), MissionMarker3D.MarkerKind.EXTRACTION, "Extract through drainage gate", 0.0, {})

	var cp0 := _add_trigger(&"CP0_INSERTION", MissionTrigger3D.TriggerKind.CHECKPOINT, Vector3(-46.0, 1.0, 0.0), Vector3(3.0, 2.0, 4.0), true)
	var cp1 := _add_trigger(&"CP1_SWITCH_ENTRY", MissionTrigger3D.TriggerKind.CHECKPOINT, Vector3(20.0, 1.0, -16.0), Vector3(4.0, 2.0, 3.0), true)
	for room_data in [
		[&"R0_DRAINAGE", Vector3(-41, 1.5, 0), Vector3(18, 3, 14)],
		[&"R1_LOADING_YARD", Vector3(-10, 1.5, 0), Vector3(28, 3, 22)],
		[&"R2_SUPPLY_CAGE", Vector3(-10, 1.5, 24), Vector3(14, 3, 12)],
		[&"R3_SECURITY_HALL", Vector3(20, 1.5, 0), Vector3(20, 3, 12)],
		[&"R4_MAINTENANCE", Vector3(20, 1.5, 22), Vector3(18, 3, 20)],
		[&"R5_SWITCH_FLOOR", Vector3(20, 1.5, -24), Vector3(24, 3, 20)],
		[&"R6_CONTROL", Vector3(-10, 1.5, -28), Vector3(16, 3, 16)],
	]:
		var room_trigger := _add_trigger(room_data[0], MissionTrigger3D.TriggerKind.ROOM, room_data[1], room_data[2], false)
		room_trigger.triggered.connect(_on_room_entered)

	for marker in [pistol, ammo, ration, access_card, objective, extraction]:
		mission_state.register_marker(marker)
	mission_state.register_trigger(cp0)
	mission_state.register_trigger(cp1)
	for door in [supply_door, access_door, shortcut_door]:
		mission_state.register_door(door)
	mission_state.configure(
		access_door,
		shortcut_door,
		objective,
		extraction,
		camera_rig,
		inventory,
		player,
		player.health,
		interaction_focus
	)
	mission_state.initialize_mission(&"CP0_INSERTION")
	supply_door.state_changed.connect(_on_door_state_changed)
	access_door.state_changed.connect(_on_door_state_changed)
	shortcut_door.state_changed.connect(_on_door_state_changed)


func _configure_runtime_contracts() -> void:
	interaction_focus.set_actor(player, player.interaction_origin)
	interaction_focus.set_camera_rig(camera_rig)
	interaction_focus.prompt_changed.connect(_on_prompt_changed)
	interaction_focus.hold_progressed.connect(_on_hold_progressed)
	mission_state.status_changed.connect(_on_status_changed)
	alert_coordinator.phase_changed.connect(_on_alert_phase_changed)
	alert_coordinator.detection_announced.connect(_on_detection_announced)
	var guards: Array = guard_root.get_children()
	if not alert_coordinator.configure(guards):
		push_error("Alert coordinator could not register the authored mission guards.")
	if not tactical_radar.configure(player, alert_coordinator, guards, _radar_map_segments):
		push_error("Tactical radar could not bind its approved mission sources.")
	camera_rig.set_tracked_actor(player)
	var weapon := player.get_node("WeaponController") as WeaponController
	inventory_panels.configure(inventory, player, camera_rig, weapon, interaction_focus, player)
	feedback_manager.configure(camera_rig)
	var doors: Array = []
	var pickups: Array = []
	for child in mission_root.get_children():
		if child is Door3D:
			doors.append(child)
		elif child is InventoryPickup3D:
			pickups.append(child)
	feedback_manager.bind_runtime(player, weapon, inventory, inventory_panels, alert_coordinator, mission_state, guards, doors, pickups)
	mission_hud.configure(player, inventory, weapon, alert_coordinator, interaction_focus, mission_state, camera_rig)
	get_node("/root/SettingsService").call(&"apply_camera_settings", camera_rig)
	camera_rig.refresh_zones()
	camera_rig.reset_camera_state()
	status_label.text = "INFILTRATE SUBSTATION 6 — FIND THE RELAY TERMINAL"


func _add_room(room_id: StringName, center: Vector2, size: Vector2, material_key: StringName, exits: Dictionary) -> void:
	var room := Node3D.new()
	room.name = String(room_id)
	room.add_to_group(&"mission_rooms")
	room.set_meta(&"room_id", room_id)
	geometry_root.add_child(room)
	_add_box_visual_and_collision(room, &"Floor", Vector3(center.x, -0.1, center.y), Vector3(size.x, 0.2, size.y), _materials[material_key], 1)
	_navigation_surfaces.append({
		&"rect": Rect2(center - size * 0.5, size),
		&"obstacles": [],
	})
	_add_partitioned_wall(room, center, size, &"north", exits.get(&"north", []))
	_add_partitioned_wall(room, center, size, &"south", exits.get(&"south", []))
	_add_partitioned_wall(room, center, size, &"west", exits.get(&"west", []))
	_add_partitioned_wall(room, center, size, &"east", exits.get(&"east", []))


func _add_partitioned_wall(room: Node3D, center: Vector2, size: Vector2, side: StringName, openings: Array) -> void:
	var length := size.x if side == &"north" or side == &"south" else size.y
	var cursor := -length * 0.5
	var ordered := openings.duplicate()
	ordered.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for opening: Vector2 in ordered:
		var opening_start := clampf(opening.x - opening.y * 0.5, -length * 0.5, length * 0.5)
		var opening_end := clampf(opening.x + opening.y * 0.5, -length * 0.5, length * 0.5)
		_add_wall_segment(room, center, size, side, cursor, opening_start)
		cursor = maxf(cursor, opening_end)
	_add_wall_segment(room, center, size, side, cursor, length * 0.5)


func _add_wall_segment(room: Node3D, center: Vector2, size: Vector2, side: StringName, start: float, end: float) -> void:
	var length := end - start
	if length <= 0.05:
		return
	var midpoint := (start + end) * 0.5
	var position: Vector3
	var wall_size: Vector3
	if side == &"north" or side == &"south":
		var z := center.y + (-size.y * 0.5 if side == &"north" else size.y * 0.5)
		position = Vector3(center.x + midpoint, 1.5, z)
		wall_size = Vector3(length, 3.0, 0.3)
		_add_radar_segment(Vector3(center.x + start, 0.0, z), Vector3(center.x + end, 0.0, z))
	else:
		var x := center.x + (-size.x * 0.5 if side == &"west" else size.x * 0.5)
		position = Vector3(x, 1.5, center.y + midpoint)
		wall_size = Vector3(0.3, 3.0, length)
		_add_radar_segment(Vector3(x, 0.0, center.y + start), Vector3(x, 0.0, center.y + end))
	_add_box_visual_and_collision(room, StringName("%s_Wall" % side), position, wall_size, _materials[&"WALL"], 33)


func _add_corridor(corridor_id: StringName, center: Vector2, size: Vector2, navigation_gap: float = INF) -> void:
	var corridor := Node3D.new()
	corridor.name = String(corridor_id)
	geometry_root.add_child(corridor)
	_add_box_visual_and_collision(corridor, &"Floor", Vector3(center.x, -0.1, center.y), Vector3(size.x, 0.2, size.y), _materials[&"CORRIDOR"], 1)
	if size.x > size.y:
		_add_box_visual_and_collision(corridor, &"NorthRail", Vector3(center.x, 0.65, center.y - size.y * 0.5), Vector3(size.x, 1.3, 0.25), _materials[&"WALL"], 33)
		_add_box_visual_and_collision(corridor, &"SouthRail", Vector3(center.x, 0.65, center.y + size.y * 0.5), Vector3(size.x, 1.3, 0.25), _materials[&"WALL"], 33)
		_add_radar_segment(Vector3(center.x - size.x * 0.5, 0.0, center.y - size.y * 0.5), Vector3(center.x + size.x * 0.5, 0.0, center.y - size.y * 0.5))
		_add_radar_segment(Vector3(center.x - size.x * 0.5, 0.0, center.y + size.y * 0.5), Vector3(center.x + size.x * 0.5, 0.0, center.y + size.y * 0.5))
	else:
		_add_box_visual_and_collision(corridor, &"WestRail", Vector3(center.x - size.x * 0.5, 0.65, center.y), Vector3(0.25, 1.3, size.y), _materials[&"WALL"], 33)
		_add_box_visual_and_collision(corridor, &"EastRail", Vector3(center.x + size.x * 0.5, 0.65, center.y), Vector3(0.25, 1.3, size.y), _materials[&"WALL"], 33)
		_add_radar_segment(Vector3(center.x - size.x * 0.5, 0.0, center.y - size.y * 0.5), Vector3(center.x - size.x * 0.5, 0.0, center.y + size.y * 0.5))
		_add_radar_segment(Vector3(center.x + size.x * 0.5, 0.0, center.y - size.y * 0.5), Vector3(center.x + size.x * 0.5, 0.0, center.y + size.y * 0.5))
	if is_inf(navigation_gap):
		_navigation_rects.append(Rect2(center - size * 0.5, size))
	elif size.y >= size.x:
		var start := center.y - size.y * 0.5
		var end := center.y + size.y * 0.5
		_navigation_rects.append(Rect2(Vector2(center.x - size.x * 0.5, start), Vector2(size.x, navigation_gap - 0.75 - start)))
		_navigation_rects.append(Rect2(Vector2(center.x - size.x * 0.5, navigation_gap + 0.75), Vector2(size.x, end - navigation_gap - 0.75)))
	else:
		var start := center.x - size.x * 0.5
		var end := center.x + size.x * 0.5
		_navigation_rects.append(Rect2(Vector2(start, center.y - size.y * 0.5), Vector2(navigation_gap - 0.75 - start, size.y)))
		_navigation_rects.append(Rect2(Vector2(navigation_gap + 0.75, center.y - size.y * 0.5), Vector2(end - navigation_gap - 0.75, size.y)))


func _add_cover(cover_id: StringName, position: Vector3, size: Vector3, material_key: StringName) -> void:
	var cover := _add_box_visual_and_collision(geometry_root, cover_id, position, size, _materials[material_key], 33)
	var footprint := Rect2(
		Vector2(position.x - size.x * 0.5, position.z - size.z * 0.5),
		Vector2(size.x, size.z)
	).grow(0.48)
	cover.set_meta(&"navigation_footprint", footprint)
	_add_radar_rectangle(position, size)
	for surface in _navigation_surfaces:
		var room_rect: Rect2 = surface.rect
		if room_rect.has_point(Vector2(position.x, position.z)):
			(surface.obstacles as Array).append(footprint.intersection(room_rect))
			break


func _navigation_cells(surface: Dictionary) -> Array[Rect2]:
	var cells: Array[Rect2] = []
	var room_rect: Rect2 = surface.rect
	var obstacles: Array = surface.obstacles
	var x_edges: Array[float] = [room_rect.position.x, room_rect.end.x]
	var z_edges: Array[float] = [room_rect.position.y, room_rect.end.y]
	for obstacle: Rect2 in obstacles:
		if obstacle.has_area():
			x_edges.append(obstacle.position.x)
			x_edges.append(obstacle.end.x)
			z_edges.append(obstacle.position.y)
			z_edges.append(obstacle.end.y)
	x_edges.sort()
	z_edges.sort()
	for x_index in range(x_edges.size() - 1):
		for z_index in range(z_edges.size() - 1):
			var cell := Rect2(
				Vector2(x_edges[x_index], z_edges[z_index]),
				Vector2(
					x_edges[x_index + 1] - x_edges[x_index],
					z_edges[z_index + 1] - z_edges[z_index]
				)
			)
			if cell.size.x <= 0.05 or cell.size.y <= 0.05:
				continue
			var blocked := false
			for obstacle: Rect2 in obstacles:
				if obstacle.has_point(cell.get_center()):
					blocked = true
					break
			if not blocked:
				cells.append(cell)
	return cells


func _add_box_visual_and_collision(parent: Node3D, object_name: StringName, position: Vector3, size: Vector3, material: Material, layer: int) -> Node3D:
	var root := Node3D.new()
	root.name = String(object_name)
	parent.add_child(root)
	var visible := MeshInstance3D.new()
	visible.name = "Visible"
	visible.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	visible.mesh = mesh
	visible.material_override = material
	root.add_child(visible)
	if layer != 0:
		var body := StaticBody3D.new()
		body.name = "Collision"
		body.position = position
		body.collision_layer = layer
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		root.add_child(body)
	return root


func _add_camera_zone(zone_id: StringName, center: Vector2, size: Vector2, camera_offset: Vector3, tracking: Vector2, blend: float) -> CameraZone3D:
	var zone := CameraZone3D.new()
	zone.name = String(zone_id)
	zone.position = Vector3(center.x, 3.0, center.y)
	zone.data = CameraZoneData.new()
	zone.data.zone_id = zone_id
	zone.data.volume_size = Vector3(size.x, 6.0, size.y)
	zone.data.camera_offset = camera_offset
	zone.data.look_target_offset = Vector3(0.0, -2.1, 0.0)
	zone.data.tracking_extents = tracking
	zone.data.blend_duration = blend
	zone.data.field_of_view = 52.0
	camera_zone_root.add_child(zone)
	return zone


func _add_door(id: StringName, position: Vector3, locked: bool, access_level: StringName) -> Door3D:
	var door := DOOR_SCENE.instantiate() as Door3D
	door.name = String(id)
	door.door_id = id
	door.position = position
	door.starts_locked = locked
	door.access_level = access_level
	mission_root.add_child(door)
	return door


func _add_marker(id: StringName, position: Vector3, kind: MissionMarker3D.MarkerKind, prompt: String, hold: float, payload: Dictionary) -> MissionMarker3D:
	var marker := MARKER_SCENE.instantiate() as MissionMarker3D
	marker.name = String(id)
	marker.interaction_id = id
	marker.event_id = id
	marker.position = position
	marker.marker_kind = kind
	marker.prompt_text = prompt
	marker.hold_duration = hold
	marker.payload = payload
	marker.one_shot = kind == MissionMarker3D.MarkerKind.PICKUP or kind == MissionMarker3D.MarkerKind.OBJECTIVE
	marker.interaction_priority = 10 if kind == MissionMarker3D.MarkerKind.PICKUP else 30
	mission_root.add_child(marker)
	return marker


func _add_inventory_pickup(
	id: StringName,
	position: Vector3,
	prompt: String,
	quantity: int,
	initial_magazine: int,
	auto_equip: bool,
	payload: Dictionary
) -> InventoryPickup3D:
	var pickup := PICKUP_SCENE.instantiate() as InventoryPickup3D
	pickup.name = String(id)
	pickup.interaction_id = id
	pickup.event_id = id
	pickup.inventory_entry_id = id
	pickup.position = position
	pickup.prompt_text = prompt
	pickup.quantity = quantity
	pickup.initial_magazine = initial_magazine
	pickup.auto_equip = auto_equip
	pickup.payload = payload
	pickup.interaction_priority = 10
	pickup.set_inventory(inventory)
	mission_root.add_child(pickup)
	return pickup


func _add_trigger(id: StringName, kind: MissionTrigger3D.TriggerKind, position: Vector3, size: Vector3, one_shot: bool) -> MissionTrigger3D:
	var trigger := MissionTrigger3D.new()
	trigger.name = String(id)
	trigger.trigger_id = id
	trigger.trigger_kind = kind
	trigger.one_shot = one_shot
	trigger.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	trigger.add_child(collision)
	mission_root.add_child(trigger)
	return trigger


func _add_spawn(id: StringName, position: Vector3, kind: StringName) -> void:
	var spawn := Marker3D.new()
	spawn.name = String(id)
	spawn.position = position
	spawn.add_to_group(&"debug_spawn_points")
	spawn.set_meta(&"spawn_id", id)
	spawn.set_meta(&"spawn_kind", kind)
	spawn_root.add_child(spawn)


func _add_patrol(
		id: StringName,
		points: Array[Vector3],
		wait_index: int,
		wait_seconds: float,
		wait_look_direction: Vector3 = Vector3.ZERO
) -> void:
	var route := PatrolRoute3D.new()
	route.name = String(id)
	route.route_id = id
	route.add_to_group(&"guard_patrol_routes")
	route.set_meta(&"guard_id", id)
	for index in points.size():
		var point := Marker3D.new()
		point.name = "P%d" % (index + 1)
		point.position = points[index]
		point.set_meta(&"wait_seconds", wait_seconds if index == wait_index else 0.0)
		if index == wait_index and not wait_look_direction.is_zero_approx():
			point.set_meta(&"look_direction", wait_look_direction.normalized())
		route.add_child(point)
	route_root.add_child(route)


func _material(color: Color, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
	return material


func _add_radar_rectangle(position: Vector3, size: Vector3) -> void:
	var half_x := size.x * 0.5
	var half_z := size.z * 0.5
	var north_west := Vector3(position.x - half_x, 0.0, position.z - half_z)
	var north_east := Vector3(position.x + half_x, 0.0, position.z - half_z)
	var south_east := Vector3(position.x + half_x, 0.0, position.z + half_z)
	var south_west := Vector3(position.x - half_x, 0.0, position.z + half_z)
	_add_radar_segment(north_west, north_east)
	_add_radar_segment(north_east, south_east)
	_add_radar_segment(south_east, south_west)
	_add_radar_segment(south_west, north_west)


func _add_radar_segment(a: Vector3, b: Vector3) -> void:
	_radar_map_segments.append({&"a": a, &"b": b})


func _on_room_entered(room_id: StringName, _actor: Node3D) -> void:
	_current_room = room_id


func _on_prompt_changed(prompt: String, reason: StringName, available: bool) -> void:
	_last_prompt = prompt if available else "%s — %s" % [prompt, reason]


func _on_hold_progressed(target: Interactable3D, progress: float) -> void:
	if progress > 0.0:
		status_label.text = "%s  %d%%" % [target.get_prompt(player).to_upper(), roundi(progress * 100.0)]


func _on_status_changed(message: String) -> void:
	status_label.text = message


func _on_detection_announced(report: Dictionary) -> void:
	status_label.text = "DETECTED BY %s  —  BREAK LINE OF SIGHT" % report.get(&"observer_id", &"UNKNOWN")


func _on_alert_phase_changed(
		_previous: AlertCoordinator.AlertPhase,
		current: AlertCoordinator.AlertPhase,
		_snapshot: Dictionary
) -> void:
	match current:
		AlertCoordinator.AlertPhase.ALERT:
			status_label.text = "FACILITY ALERT  —  BREAK CONTACT"
		AlertCoordinator.AlertPhase.EVASION:
			status_label.text = "EVASION  —  STAY OUT OF SIGHT"
		AlertCoordinator.AlertPhase.SEARCH:
			status_label.text = "SEARCH  —  GUARDS CHECKING LAST-KNOWN AREA"
		AlertCoordinator.AlertPhase.NORMAL:
			status_label.text = "FACILITY NORMAL  —  PATROLS RESUMING"


func _on_door_state_changed(door_id: StringName, opened: bool, locked: bool) -> void:
	status_label.text = "%s — %s" % [door_id, "LOCKED" if locked else ("OPEN" if opened else "CLOSED")]

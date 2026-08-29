class_name EnemyAITestRoom
extends Node3D

@onready var player: PlayerController = %Player
@onready var guard: GuardActor = %Guard
@onready var route: PatrolRoute3D = %LabRoute
@onready var navigation_root: Node3D = %Navigation
@onready var status_label: Label = %StatusLabel

var _debug_visible: bool = true


func _ready() -> void:
	_build_navigation()
	player.set_camera_basis(%Camera3D.global_basis)
	guard.configure(&"LAB_GUARD", route, player, _get_navigation_map())
	guard.detection_reported.connect(_on_detection_reported)
	guard.attack_telegraphed.connect(_on_attack_telegraphed)


func _process(_delta: float) -> void:
	var snapshot := guard.get_state_snapshot()
	status_label.text = "%s   SUSPICION %d%%   HEALTH %d\nVISIBLE %s   LAST KNOWN %s" % [
		snapshot.state,
		roundi(float(snapshot.suspicion) * 100.0),
		roundi(float(snapshot.health)),
		"YES" if bool(snapshot.target_visible) else "NO",
		str(snapshot.last_known_position),
	]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle") and OS.is_debug_build():
		_debug_visible = not _debug_visible
		get_tree().call_group(&"guard_debug_visuals", &"set_debug_visible", _debug_visible)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"interact"):
		var event_bus := get_node_or_null("/root/EventBus")
		if event_bus != null:
			event_bus.call(&"emit_noise", NoiseEvent3D.new(player, player.global_position, 1.0, &"player_movement"))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"reload"):
		var event_bus := get_node_or_null("/root/EventBus")
		if event_bus != null:
			event_bus.call(&"emit_noise", NoiseEvent3D.new(player, player.global_position, 30.0, &"gunshot"))
		get_viewport().set_input_as_handled()


func _build_navigation() -> void:
	var region := NavigationRegion3D.new()
	region.name = "LabNavigationRegion"
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.agent_radius = 0.4
	navigation_mesh.agent_height = 1.8
	var vertices := PackedVector3Array()
	var polygons: Array[PackedInt32Array] = []
	var cells := [
		Rect2(-10.0, -10.0, 8.0, 20.0),
		Rect2(2.0, -10.0, 8.0, 20.0),
		Rect2(-2.0, -10.0, 4.0, 8.0),
		Rect2(-2.0, 2.0, 4.0, 8.0),
	]
	for cell: Rect2 in cells:
		var first := vertices.size()
		vertices.append(Vector3(cell.position.x, 0.02, cell.position.y))
		vertices.append(Vector3(cell.end.x, 0.02, cell.position.y))
		vertices.append(Vector3(cell.end.x, 0.02, cell.end.y))
		vertices.append(Vector3(cell.position.x, 0.02, cell.end.y))
		polygons.append(PackedInt32Array([first, first + 1, first + 2, first + 3]))
	navigation_mesh.vertices = vertices
	for polygon in polygons:
		navigation_mesh.add_polygon(polygon)
	region.navigation_mesh = navigation_mesh
	navigation_root.add_child(region)


func _get_navigation_map() -> RID:
	for child in navigation_root.get_children():
		if child is NavigationRegion3D:
			return (child as NavigationRegion3D).get_navigation_map()
	return RID()


func _on_detection_reported(_guard_id: StringName, _position: Vector3, evidence: StringName) -> void:
	status_label.text = "DETECTED BY %s" % evidence


func _on_attack_telegraphed(_guard_id: StringName, _position: Vector3, duration: float) -> void:
	status_label.text = "ATTACK TELEGRAPH  %.2fs" % duration

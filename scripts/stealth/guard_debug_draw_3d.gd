class_name GuardDebugDraw3D
extends MeshInstance3D

@export var enabled: bool = true
@export var guard_path: NodePath = ^".."

var _guard: GuardActor
var _material := StandardMaterial3D.new()


func _ready() -> void:
	add_to_group(&"guard_debug_visuals")
	_guard = get_node_or_null(guard_path) as GuardActor
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.no_depth_test = true
	visible = enabled and OS.is_debug_build()
	set_process(visible)


func _process(_delta: float) -> void:
	if visible:
		_rebuild_mesh()


func set_debug_visible(show: bool) -> void:
	visible = show and enabled and OS.is_debug_build()
	set_process(visible)
	if not visible:
		mesh = null


func _rebuild_mesh() -> void:
	if _guard == null or not is_instance_valid(_guard) or _guard.config == null:
		return
	var label := get_node_or_null("StateLabel") as Label3D
	if label != null:
		label.text = "%s  %s\nSUSPICION %d%%  %.1fs" % [
			_guard.guard_id,
			GuardActor.STATE_NAMES[int(_guard.state)],
			roundi(_guard.perception.suspicion * 100.0),
			float(_guard.get_state_snapshot().state_time),
		]
	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, _material)
	var range := _guard.config.standing_vision_range
	var half_angle := deg_to_rad(_guard.config.horizontal_cone_degrees * 0.5)
	var origin := Vector3.UP * _guard.config.eye_height
	var previous := Vector3(sin(-half_angle) * range, 0.0, -cos(-half_angle) * range) + origin
	_add_line(immediate, origin, previous, _state_color())
	for index in range(1, 17):
		var angle := lerpf(-half_angle, half_angle, float(index) / 16.0)
		var point := Vector3(sin(angle) * range, 0.0, -cos(angle) * range) + origin
		_add_line(immediate, previous, point, _state_color())
		previous = point
	_add_line(immediate, origin, previous, _state_color())
	var observation := _guard.perception.get_observation_snapshot()
	var sample: Vector3 = observation.visible_sample
	if sample != Vector3.ZERO:
		_add_line(
			immediate,
			origin,
			_guard.to_local(sample),
			Color(0.2, 1.0, 0.35, 1.0) if observation.target_visible else Color(1.0, 0.2, 0.2, 1.0)
		)
	var destination := _guard.get_debug_destination()
	if destination != Vector3.ZERO:
		_add_line(immediate, Vector3.UP * 0.08, _guard.to_local(destination) + Vector3.UP * 0.08, Color(0.3, 0.75, 1.0, 1.0))
	immediate.surface_end()
	mesh = immediate


func _add_line(immediate: ImmediateMesh, from: Vector3, to: Vector3, color: Color) -> void:
	immediate.surface_set_color(color)
	immediate.surface_add_vertex(from)
	immediate.surface_set_color(color)
	immediate.surface_add_vertex(to)


func _state_color() -> Color:
	if _guard == null:
		return Color.WHITE
	match _guard.state:
		GuardActor.GuardState.PATROL, GuardActor.GuardState.RETURN:
			return Color(0.2, 1.0, 0.45, 0.9)
		GuardActor.GuardState.SUSPICIOUS, GuardActor.GuardState.INVESTIGATE:
			return Color(1.0, 0.85, 0.15, 0.95)
		GuardActor.GuardState.SEARCH:
			return Color(1.0, 0.5, 0.1, 0.95)
		GuardActor.GuardState.DEAD:
			return Color(0.35, 0.35, 0.35, 0.7)
		_:
			return Color(1.0, 0.12, 0.12, 1.0)

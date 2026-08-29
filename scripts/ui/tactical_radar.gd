class_name TacticalRadar
extends Control

signal mode_changed(previous: RadarMode, current: RadarMode)
signal render_snapshot_updated(snapshot: Dictionary)

enum RadarMode {
	ACTIVE,
	JAMMED,
	DISABLED,
	HIDDEN,
}

const MODE_NAMES := [&"ACTIVE", &"JAMMED", &"DISABLED", &"HIDDEN"]
const PHASE_COLORS := {
	&"NORMAL": Color(0.2, 0.9, 0.5, 1.0),
	&"SUSPICIOUS": Color(1.0, 0.82, 0.24, 1.0),
	&"ALERT": Color(1.0, 0.2, 0.18, 1.0),
	&"EVASION": Color(1.0, 0.5, 0.14, 1.0),
	&"SEARCH": Color(1.0, 0.72, 0.2, 1.0),
}

@export_range(4.0, 100.0, 0.5, "suffix:m") var world_radius: float = 22.0
@export_range(8.0, 150.0, 0.5, "suffix:m") var maximum_contact_distance: float = 42.0
@export_range(1.0, 10.0, 0.5, "suffix:m") var alert_contact_grid: float = 4.0
@export_range(0.2, 5.0, 0.05, "suffix:s") var evasion_pulse_period: float = 1.5
@export_range(0.05, 1.0, 0.05) var evasion_pulse_duty: float = 0.4
@export_range(30.0, 180.0, 1.0, "suffix:px") var radar_radius_pixels: float = 92.0

@onready var status_label: Label = get_node_or_null("%StatusLabel") as Label
@onready var debug_label: Label = get_node_or_null("%DebugLabel") as Label

var radar_mode: RadarMode = RadarMode.ACTIVE
var player: Node3D
var alert_coordinator: AlertCoordinator
var _guards: Array[Node] = []
var _map_segments: Array[Dictionary] = []
var _debug_visible: bool = false
var _last_render_snapshot: Dictionary = {}


func _ready() -> void:
	add_to_group(&"alert_debug_visuals")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_update_visibility()


func _process(_delta: float) -> void:
	_last_render_snapshot = get_render_snapshot()
	_update_labels(_last_render_snapshot)
	render_snapshot_updated.emit(_last_render_snapshot.duplicate(true))
	queue_redraw()


func configure(
		tracked_player: Node3D,
		coordinator: AlertCoordinator,
		guard_nodes: Array,
		map_segments: Array = []
) -> bool:
	if tracked_player == null or coordinator == null:
		return false
	player = tracked_player
	alert_coordinator = coordinator
	_guards.clear()
	for candidate in guard_nodes:
		var guard := candidate as Node
		if guard != null and guard.has_method(&"get_radar_snapshot"):
			_guards.append(guard)
	set_map_segments(map_segments)
	return true


func set_map_segments(segments: Array) -> void:
	_map_segments.clear()
	for segment_value in segments:
		if not segment_value is Dictionary:
			continue
		var segment := segment_value as Dictionary
		if typeof(segment.get(&"a", null)) != TYPE_VECTOR3 or typeof(segment.get(&"b", null)) != TYPE_VECTOR3:
			continue
		var a: Vector3 = segment.a
		var b: Vector3 = segment.b
		if a.is_finite() and b.is_finite():
			_map_segments.append({&"a": a, &"b": b})


func set_radar_mode(next_mode: RadarMode) -> void:
	if radar_mode == next_mode:
		return
	var previous := radar_mode
	radar_mode = next_mode
	_update_visibility()
	mode_changed.emit(previous, radar_mode)


func set_debug_visible(enabled: bool) -> void:
	_debug_visible = enabled and OS.is_debug_build()
	if is_instance_valid(debug_label):
		debug_label.visible = _debug_visible


func get_render_snapshot() -> Dictionary:
	var alert_snapshot := alert_coordinator.get_alert_snapshot() if alert_coordinator != null else {
		&"phase": &"NORMAL", &"phase_elapsed": 0.0, &"time_remaining": 0.0,
	}
	var phase_name := StringName(alert_snapshot.get(&"phase", &"NORMAL"))
	var base := {
		&"mode": MODE_NAMES[int(radar_mode)],
		&"orientation": &"NORTH_UP",
		&"phase": phase_name,
		&"walls": [],
		&"contacts": [],
		&"cones_visible": false,
		&"alert": alert_snapshot.duplicate(true),
	}
	if radar_mode != RadarMode.ACTIVE or player == null or not is_instance_valid(player):
		return base
	var pixels_per_meter := radar_radius_pixels / maxf(world_radius, 0.001)
	var walls: Array[Dictionary] = []
	for segment in _map_segments:
		var a: Vector3 = segment.a
		var b: Vector3 = segment.b
		if _distance_to_segment_xz(player.global_position, a, b) > world_radius * 1.25:
			continue
		walls.append({
			&"a": _clamp_radar_point(world_to_radar(a, player.global_position, pixels_per_meter), radar_radius_pixels),
			&"b": _clamp_radar_point(world_to_radar(b, player.global_position, pixels_per_meter), radar_radius_pixels),
		})
	base.walls = walls
	var show_cones := phase_name in [&"NORMAL", &"SUSPICIOUS", &"SEARCH"]
	var show_contacts := true
	if phase_name == &"EVASION":
		var elapsed := float(alert_snapshot.get(&"phase_elapsed", 0.0))
		show_contacts = fmod(elapsed, evasion_pulse_period) <= evasion_pulse_period * evasion_pulse_duty
	if not show_contacts:
		base.cones_visible = false
		return base
	var contacts: Array[Dictionary] = []
	for guard in _guards:
		if guard == null or not is_instance_valid(guard):
			continue
		var guard_snapshot: Dictionary = guard.call(&"get_radar_snapshot")
		if not bool(guard_snapshot.get(&"alive", false)):
			continue
		var world_position: Vector3 = guard_snapshot.get(&"world_position", Vector3.ZERO)
		if phase_name in [&"ALERT", &"EVASION"]:
			world_position.x = snappedf(world_position.x, alert_contact_grid)
			world_position.z = snappedf(world_position.z, alert_contact_grid)
		var projection := project_contact(
			world_position, player.global_position, pixels_per_meter,
			radar_radius_pixels, maximum_contact_distance
		)
		if bool(projection.culled):
			continue
		var direction: Vector3 = guard_snapshot.get(&"facing_direction", Vector3.FORWARD)
		contacts.append({
			&"guard_id": StringName(guard_snapshot.get(&"guard_id", &"")),
			&"position": projection.position,
			&"direction": facing_to_radar(direction),
			&"distance": projection.distance,
			&"clamped": projection.clamped,
			&"coarse": phase_name in [&"ALERT", &"EVASION"],
			&"cone_visible": show_cones and not bool(projection.clamped),
			&"vision_range_pixels": minf(float(guard_snapshot.get(&"vision_range", 0.0)) * pixels_per_meter, radar_radius_pixels),
			&"vision_angle_degrees": float(guard_snapshot.get(&"vision_angle_degrees", 0.0)),
			&"suspicion": clampf(float(guard_snapshot.get(&"suspicion", 0.0)), 0.0, 1.0),
			&"state": StringName(guard_snapshot.get(&"state", &"UNKNOWN")),
		})
	base.contacts = contacts
	base.cones_visible = show_cones
	return base


static func world_to_radar(world_position: Vector3, player_position: Vector3, pixels_per_meter: float) -> Vector2:
	var offset := world_position - player_position
	return Vector2(offset.x, offset.z) * pixels_per_meter


static func facing_to_radar(world_direction: Vector3) -> Vector2:
	var direction := Vector2(world_direction.x, world_direction.z)
	return direction.normalized() if not direction.is_zero_approx() else Vector2.UP


static func project_contact(
		world_position: Vector3,
		player_position: Vector3,
		pixels_per_meter: float,
		radius_pixels: float,
		maximum_distance: float
) -> Dictionary:
	var world_distance := Vector2(
		world_position.x - player_position.x,
		world_position.z - player_position.z
	).length()
	if world_distance > maximum_distance:
		return {&"position": Vector2.ZERO, &"distance": world_distance, &"clamped": false, &"culled": true}
	var projected := world_to_radar(world_position, player_position, pixels_per_meter)
	var clamped := projected.length() > radius_pixels
	if clamped:
		projected = projected.normalized() * radius_pixels
	return {&"position": projected, &"distance": world_distance, &"clamped": clamped, &"culled": false}


static func _clamp_radar_point(point: Vector2, radius: float) -> Vector2:
	return point.normalized() * radius if point.length() > radius else point


func _draw() -> void:
	var center := Vector2(size.x * 0.5, radar_radius_pixels + 12.0)
	var phase_name := StringName(_last_render_snapshot.get(&"phase", &"NORMAL"))
	var phase_color: Color = PHASE_COLORS.get(phase_name, Color.WHITE)
	draw_circle(center, radar_radius_pixels + 5.0, Color(0.01, 0.025, 0.03, 0.88))
	draw_arc(center, radar_radius_pixels + 4.0, 0.0, TAU, 64, phase_color, 2.0, true)
	draw_line(center + Vector2(0, -radar_radius_pixels), center + Vector2(0, radar_radius_pixels), Color(0.2, 0.5, 0.38, 0.2), 1.0)
	draw_line(center + Vector2(-radar_radius_pixels, 0), center + Vector2(radar_radius_pixels, 0), Color(0.2, 0.5, 0.38, 0.2), 1.0)
	if radar_mode != RadarMode.ACTIVE:
		draw_line(center + Vector2(-32, -32), center + Vector2(32, 32), phase_color, 4.0)
		draw_line(center + Vector2(32, -32), center + Vector2(-32, 32), phase_color, 4.0)
		return
	for wall in _last_render_snapshot.get(&"walls", []):
		draw_line(center + wall.a, center + wall.b, Color(0.3, 0.8, 0.62, 0.65), 2.0, true)
	for contact in _last_render_snapshot.get(&"contacts", []):
		var contact_position: Vector2 = center + contact.position
		var direction: Vector2 = contact.direction
		if bool(contact.cone_visible):
			var half_angle := deg_to_rad(float(contact.vision_angle_degrees) * 0.5)
			var length := float(contact.vision_range_pixels)
			var left := direction.rotated(-half_angle) * length
			var right := direction.rotated(half_angle) * length
			draw_colored_polygon(PackedVector2Array([contact_position, contact_position + left, contact_position + right]), Color(1.0, 0.72, 0.2, 0.12))
		draw_circle(contact_position, 4.5, phase_color)
		draw_line(contact_position, contact_position + direction * 11.0, phase_color, 2.0, true)
		if bool(contact.clamped):
			draw_arc(contact_position, 7.0, 0.0, TAU, 16, phase_color, 1.0, true)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -7), center + Vector2(5, 6), center + Vector2(-5, 6),
	]), Color(0.76, 1.0, 0.9, 1.0))


func _update_labels(snapshot: Dictionary) -> void:
	if not is_instance_valid(status_label) or not is_instance_valid(debug_label):
		return
	var phase_name := StringName(snapshot.get(&"phase", &"NORMAL"))
	var alert_snapshot: Dictionary = snapshot.get(&"alert", {})
	var remaining := float(alert_snapshot.get(&"time_remaining", 0.0))
	status_label.text = "%s%s  //  NORTH" % [
		phase_name,
		"  %.1f" % remaining if remaining > 0.0 else "",
	]
	status_label.modulate = PHASE_COLORS.get(phase_name, Color.WHITE)
	debug_label.text = "RADAR %s  CONTACTS %d  REPORTS %d\nSIGHT %s  SHARED %.1fs" % [
		MODE_NAMES[int(radar_mode)],
		(snapshot.get(&"contacts", []) as Array).size(),
		int(alert_snapshot.get(&"report_count", 0)),
		"YES" if bool(alert_snapshot.get(&"any_confirmed_sight", false)) else "NO",
		float(alert_snapshot.get(&"knowledge_expires_in", 0.0)),
	]
	debug_label.visible = _debug_visible


func _update_visibility() -> void:
	visible = radar_mode != RadarMode.HIDDEN
	if is_instance_valid(debug_label):
		debug_label.visible = _debug_visible


static func _distance_to_segment_xz(point: Vector3, a: Vector3, b: Vector3) -> float:
	var point_2d := Vector2(point.x, point.z)
	var a_2d := Vector2(a.x, a.z)
	var b_2d := Vector2(b.x, b.z)
	var segment := b_2d - a_2d
	if segment.is_zero_approx():
		return point_2d.distance_to(a_2d)
	var t := clampf((point_2d - a_2d).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point_2d.distance_to(a_2d + segment * t)

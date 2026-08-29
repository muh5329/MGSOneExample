class_name GameplayCameraRig
extends Node3D

signal mode_changed(previous: CameraMode, current: CameraMode)
signal active_zone_changed(previous: CameraZone3D, current: CameraZone3D)
signal transition_state_changed(is_transitioning: bool)
signal aim_rejected(reason: StringName)
signal aim_obstruction_changed(is_obstructed: bool)
signal reticle_visibility_requested(visible: bool)

enum CameraMode {
	EXPLORATION,
	AIM,
}

const AIM_REJECTED_NO_WEAPON: StringName = &"NO_WEAPON_EQUIPPED"
const AIM_REJECTED_ZONE: StringName = &"AIM_NOT_ALLOWED"
const AIM_REJECTED_MODAL: StringName = &"MODAL_ACTIVE"
const AIM_REJECTED_INTERACTION: StringName = &"INTERACTION_ACTIVE"
const AIM_REJECTED_BLOCKED: StringName = &"AIM_ORIGIN_BLOCKED"
const GAME_PHASE_PLAYER_DEAD := 3
const GAME_PHASE_COMPLETED := 4
const GAME_PHASE_RESTARTING := 5

@export var settings: CameraAimSettings
@export var tracked_actor_path: NodePath
@export var fallback_camera_transform := Transform3D(
	Basis.IDENTITY,
	Vector3(10.0, 12.0, 12.0)
)
@export var fallback_look_target: Vector3 = Vector3(0.0, 0.9, 0.0)
@export_flags_3d_physics var obstruction_mask: int = 1
@export var input_enabled: bool = true
@export var debug_enabled: bool = false

@onready var gameplay_camera: Camera3D = %GameplayCamera
@onready var debug_label: Label = %DebugLabel
@onready var debug_aim_ray: MeshInstance3D = %DebugAimRay

var mode: CameraMode = CameraMode.EXPLORATION
var active_zone: CameraZone3D
var is_transitioning: bool = false
var aim_is_obstructed: bool = false

var _tracked_actor: Node3D
var _zones: Array[CameraZone3D] = []
var _pending_zone: CameraZone3D
var _weapon_equipped: bool = false
var _modal_active: bool = false
var _interaction_active: bool = false
var _zone_hold_time: float = 0.0

var _transition_start := Transform3D.IDENTITY
var _transition_elapsed: float = 0.0
var _transition_duration: float = 0.0
var _transition_start_fov: float = 54.0

var _aim_entry_yaw: float = 0.0
var _aim_yaw_offset: float = 0.0
var _aim_pitch: float = 0.0
var _mouse_mode_before_aim: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

var _impulse_position: Vector3 = Vector3.ZERO
var _impulse_rotation_degrees: Vector3 = Vector3.ZERO
var _impulse_duration: float = 0.0
var _impulse_remaining: float = 0.0


func _ready() -> void:
	assert(settings != null, "GameplayCameraRig requires CameraAimSettings.")
	process_mode = Node.PROCESS_MODE_ALWAYS
	gameplay_camera.current = true
	gameplay_camera.near = settings.aim_near_plane
	if not tracked_actor_path.is_empty():
		set_tracked_actor(get_node_or_null(tracked_actor_path) as Node3D)
	refresh_zones()
	_connect_game_state()
	_set_debug_visible(debug_enabled)
	_snap_to_exploration_pose()


func _process(delta: float) -> void:
	if _tracked_actor == null or not is_instance_valid(_tracked_actor):
		_tracked_actor = null
		_apply_camera_pose(_fallback_pose(), settings.exploration_fov, delta)
		_update_debug_display()
		return

	if mode == CameraMode.AIM:
		if input_enabled and not get_tree().paused:
			_update_controller_look(delta)
		_apply_camera_pose(_aim_pose(), settings.aim_fov, delta)
		_update_aim_obstruction()
	else:
		_apply_camera_pose(_exploration_pose(), _exploration_fov(), delta)
		_update_actor_camera_basis()
	_update_debug_display()


func _physics_process(delta: float) -> void:
	_zone_hold_time += delta
	if _tracked_actor == null or not is_instance_valid(_tracked_actor):
		return
	var selected := choose_zone(_zones_at_point(_tracked_actor.global_position), active_zone)
	if mode == CameraMode.AIM:
		_pending_zone = selected
		return
	if selected == active_zone:
		_pending_zone = null
		return
	_pending_zone = selected
	if active_zone == null or _zone_hold_time >= settings.minimum_zone_hold_time:
		_commit_pending_zone()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event.is_action_pressed(&"aim"):
		request_aim(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_released(&"aim") and mode == CameraMode.AIM:
		request_aim(false)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and mode == CameraMode.AIM and not get_tree().paused:
		_apply_mouse_look(event.relative)
		get_viewport().set_input_as_handled()


func set_tracked_actor(actor: Node3D) -> void:
	_tracked_actor = actor
	if _tracked_actor != null:
		_update_actor_camera_basis()


func get_tracked_actor() -> Node3D:
	return _tracked_actor


func set_weapon_equipped(is_equipped: bool) -> void:
	_weapon_equipped = is_equipped
	if not _weapon_equipped and mode == CameraMode.AIM:
		request_aim(false)


func set_modal_active(is_active: bool) -> void:
	_modal_active = is_active
	if _modal_active and mode == CameraMode.AIM:
		request_aim(false)


func set_interaction_active(is_active: bool) -> void:
	_interaction_active = is_active
	if _interaction_active and mode == CameraMode.AIM:
		request_aim(false)


func request_aim(should_aim: bool) -> bool:
	if not should_aim:
		if mode == CameraMode.AIM:
			_exit_aim()
		return true
	if mode == CameraMode.AIM:
		return true
	var rejection := _aim_rejection_reason()
	if not rejection.is_empty():
		aim_rejected.emit(rejection)
		return false
	_enter_aim()
	return true


func get_camera_mode() -> CameraMode:
	return mode


func get_view_basis() -> Basis:
	return gameplay_camera.global_basis.orthonormalized()


func get_aim_origin() -> Vector3:
	return gameplay_camera.global_position


func get_aim_direction() -> Vector3:
	return -gameplay_camera.global_basis.z.normalized()


func get_aim_ray(max_distance: float = 1000.0) -> Dictionary:
	var origin := get_aim_origin()
	var direction := get_aim_direction()
	return {
		&"origin": origin,
		&"direction": direction,
		&"end": origin + direction * maxf(max_distance, 0.0),
	}


func query_aim_hit(max_distance: float = 1000.0, collision_mask: int = 0) -> Dictionary:
	if not is_inside_tree():
		return {}
	var ray := get_aim_ray(max_distance)
	var query := PhysicsRayQueryParameters3D.create(ray.origin, ray.end)
	query.collision_mask = obstruction_mask if collision_mask == 0 else collision_mask
	if _tracked_actor is CollisionObject3D:
		query.exclude = [(_tracked_actor as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


func add_camera_impulse(
		position_offset: Vector3,
		rotation_degrees: Vector3,
		duration: float = 0.18
) -> void:
	_impulse_position += position_offset
	_impulse_rotation_degrees += rotation_degrees
	_impulse_duration = maxf(duration, 0.001)
	_impulse_remaining = _impulse_duration


func reset_camera_state() -> void:
	if mode == CameraMode.AIM:
		_exit_aim()
	refresh_zones()
	_pending_zone = choose_zone(
		_zones_at_point(_tracked_actor.global_position) if _tracked_actor != null else [],
		active_zone
	)
	_commit_pending_zone(true)
	_snap_to_exploration_pose()


func refresh_zones() -> void:
	_zones.clear()
	for node in get_tree().get_nodes_in_group(&"camera_zones"):
		if node is CameraZone3D:
			_zones.append(node as CameraZone3D)


static func choose_zone(
		candidates: Array[CameraZone3D],
		current: CameraZone3D = null
) -> CameraZone3D:
	if candidates.is_empty():
		return null
	var highest_priority := -2147483648
	for zone in candidates:
		highest_priority = maxi(highest_priority, zone.get_zone_priority())
	if current != null and current in candidates and current.get_zone_priority() == highest_priority:
		return current
	var selected: CameraZone3D
	for zone in candidates:
		if zone.get_zone_priority() != highest_priority:
			continue
		if selected == null or String(zone.get_zone_id()) < String(selected.get_zone_id()):
			selected = zone
	return selected


func _zones_at_point(world_point: Vector3) -> Array[CameraZone3D]:
	var candidates: Array[CameraZone3D] = []
	for zone in _zones:
		if is_instance_valid(zone) and zone.contains_world_point(world_point):
			candidates.append(zone)
	return candidates


func _commit_pending_zone(force: bool = false) -> void:
	if not force and _pending_zone == active_zone:
		return
	var previous := active_zone
	active_zone = _pending_zone
	_pending_zone = null
	_zone_hold_time = 0.0
	active_zone_changed.emit(previous, active_zone)
	_start_transition(_zone_blend_duration())


func _start_transition(duration: float) -> void:
	_transition_start = gameplay_camera.global_transform
	_transition_start_fov = gameplay_camera.fov
	_transition_elapsed = 0.0
	_transition_duration = maxf(duration, 0.0)
	_set_transitioning(_transition_duration > 0.0)


func _apply_camera_pose(target: Transform3D, target_fov: float, delta: float) -> void:
	var base_pose := target
	var base_fov := target_fov
	if is_transitioning:
		_transition_elapsed += delta
		var linear_weight := minf(_transition_elapsed / _transition_duration, 1.0)
		var eased_weight := smoothstep(0.0, 1.0, linear_weight)
		base_pose = _transition_start.interpolate_with(target, eased_weight)
		base_fov = lerpf(_transition_start_fov, target_fov, eased_weight)
		if linear_weight >= 1.0:
			base_pose = target
			base_fov = target_fov
			_set_transitioning(false)
	gameplay_camera.global_transform = _pose_with_impulse(base_pose, delta)
	gameplay_camera.fov = base_fov


func _pose_with_impulse(base_pose: Transform3D, delta: float) -> Transform3D:
	if _impulse_remaining <= 0.0:
		return base_pose
	_impulse_remaining = maxf(_impulse_remaining - delta, 0.0)
	var weight := _impulse_remaining / _impulse_duration
	var pose := base_pose.translated_local(_impulse_position * weight)
	pose.basis = pose.basis * Basis.from_euler(_impulse_rotation_degrees * weight * (PI / 180.0))
	if _impulse_remaining <= 0.0:
		_impulse_position = Vector3.ZERO
		_impulse_rotation_degrees = Vector3.ZERO
	return pose


func _exploration_pose() -> Transform3D:
	var target := _fallback_pose()
	var look_target := global_transform * fallback_look_target
	if active_zone != null and is_instance_valid(active_zone):
		target = active_zone.get_camera_transform(_tracked_actor.global_position)
		look_target = active_zone.get_look_target(_tracked_actor.global_position)
	return _resolve_exploration_obstruction(target, look_target)


func _fallback_pose() -> Transform3D:
	var camera_position := global_transform * fallback_camera_transform.origin
	var target_position := global_transform * fallback_look_target
	return Transform3D(Basis.IDENTITY, camera_position).looking_at(target_position, Vector3.UP)


func _resolve_exploration_obstruction(
		desired_pose: Transform3D,
		look_target: Vector3
) -> Transform3D:
	if not is_inside_tree() or obstruction_mask == 0:
		return desired_pose
	var ray_vector := desired_pose.origin - look_target
	var ray_length := ray_vector.length()
	if ray_length <= settings.minimum_camera_distance:
		return desired_pose
	var query := PhysicsRayQueryParameters3D.create(look_target, desired_pose.origin)
	query.collision_mask = obstruction_mask
	if _tracked_actor is CollisionObject3D:
		query.exclude = [(_tracked_actor as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired_pose
	var direction := ray_vector / ray_length
	var hit_distance := look_target.distance_to(hit.position)
	var resolved_distance := maxf(
		hit_distance - settings.obstruction_margin,
		settings.minimum_camera_distance
	)
	var resolved_position := look_target + direction * resolved_distance
	return Transform3D(Basis.IDENTITY, resolved_position).looking_at(look_target, Vector3.UP)


func _exploration_fov() -> float:
	if active_zone != null and is_instance_valid(active_zone) and active_zone.data != null:
		return active_zone.data.field_of_view
	return settings.exploration_fov


func _zone_blend_duration() -> float:
	if active_zone != null and is_instance_valid(active_zone) and active_zone.data != null:
		return active_zone.data.blend_duration
	return 0.25


func _aim_pose() -> Transform3D:
	var origin := _aim_origin_position()
	var yaw := _aim_entry_yaw + _aim_yaw_offset
	var basis := Basis.from_euler(Vector3(_aim_pitch, yaw, 0.0)).orthonormalized()
	return Transform3D(basis, origin)


func _aim_origin_position() -> Vector3:
	if _tracked_actor == null:
		return gameplay_camera.global_position
	var marker := _tracked_actor.get_node_or_null("AimOrigin") as Node3D
	if marker != null:
		return marker.global_position
	return _tracked_actor.global_position + Vector3.UP * 1.5


func _aim_rejection_reason() -> StringName:
	if not _weapon_equipped:
		return AIM_REJECTED_NO_WEAPON
	if _modal_active or get_tree().paused:
		return AIM_REJECTED_MODAL
	if _interaction_active:
		return AIM_REJECTED_INTERACTION
	if active_zone != null and active_zone.data != null and not active_zone.data.aim_allowed:
		return AIM_REJECTED_ZONE
	if _aim_origin_is_blocked():
		return AIM_REJECTED_BLOCKED
	return &""


func _aim_origin_is_blocked() -> bool:
	if not is_inside_tree() or _tracked_actor == null:
		return false
	var origin := _aim_origin_position()
	var forward := _tracked_forward()
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + forward * settings.near_wall_check_distance
	)
	query.collision_mask = obstruction_mask
	if _tracked_actor is CollisionObject3D:
		query.exclude = [(_tracked_actor as CollisionObject3D).get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _enter_aim() -> void:
	var previous := mode
	mode = CameraMode.AIM
	# A tap that enters and exits between physics ticks must preserve the current zone.
	_pending_zone = active_zone
	var forward := _tracked_forward()
	_aim_entry_yaw = atan2(-forward.x, -forward.z)
	_aim_yaw_offset = 0.0
	_aim_pitch = 0.0
	_set_actor_aim_lock(true)
	_mouse_mode_before_aim = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_start_transition(0.10)
	mode_changed.emit(previous, mode)
	reticle_visibility_requested.emit(true)


func _exit_aim() -> void:
	var previous := mode
	mode = CameraMode.EXPLORATION
	_set_actor_aim_lock(false)
	Input.mouse_mode = _mouse_mode_before_aim
	_set_aim_obstructed(false)
	_commit_pending_zone()
	_start_transition(_zone_blend_duration())
	mode_changed.emit(previous, mode)
	reticle_visibility_requested.emit(false)


func _tracked_forward() -> Vector3:
	if _tracked_actor == null:
		return Vector3.FORWARD
	var forward := -_tracked_actor.global_basis.z
	if _tracked_actor is PlayerController:
		forward = (_tracked_actor as PlayerController).facing_direction
	if forward.is_zero_approx():
		forward = -_tracked_actor.global_basis.z
	forward.y = 0.0
	return forward.normalized() if not forward.is_zero_approx() else Vector3.FORWARD


func _set_actor_aim_lock(locked: bool) -> void:
	if _tracked_actor != null and _tracked_actor.has_method(&"set_aim_movement_locked"):
		_tracked_actor.call(&"set_aim_movement_locked", locked)


func _update_actor_camera_basis() -> void:
	if _tracked_actor != null and _tracked_actor.has_method(&"set_camera_basis"):
		_tracked_actor.call(&"set_camera_basis", gameplay_camera.global_basis)


func _apply_mouse_look(relative: Vector2) -> void:
	var horizontal_sign := -1.0 if not settings.invert_horizontal else 1.0
	var vertical_sign := -1.0 if not settings.invert_vertical else 1.0
	_apply_look_delta(Vector2(
		relative.x * settings.mouse_sensitivity * horizontal_sign,
		relative.y * settings.mouse_sensitivity * vertical_sign
	))


func _update_controller_look(delta: float) -> void:
	var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	var magnitude := look.length()
	if magnitude <= settings.controller_dead_zone:
		return
	var scaled_magnitude := inverse_lerp(settings.controller_dead_zone, 1.0, minf(magnitude, 1.0))
	look = look.normalized() * scaled_magnitude
	var horizontal_sign := -1.0 if not settings.invert_horizontal else 1.0
	var vertical_sign := -1.0 if not settings.invert_vertical else 1.0
	_apply_look_delta(Vector2(
		look.x * settings.controller_sensitivity * delta * horizontal_sign,
		look.y * settings.controller_sensitivity * delta * vertical_sign
	))


func _apply_look_delta(delta_degrees: Vector2) -> void:
	_aim_yaw_offset = clampf(
		_aim_yaw_offset + deg_to_rad(delta_degrees.x),
		-deg_to_rad(settings.yaw_limit_degrees),
		deg_to_rad(settings.yaw_limit_degrees)
	)
	_aim_pitch = clampf(
		_aim_pitch + deg_to_rad(delta_degrees.y),
		deg_to_rad(settings.pitch_down_limit_degrees),
		deg_to_rad(settings.pitch_up_limit_degrees)
	)


func _update_aim_obstruction() -> void:
	var was_obstructed := aim_is_obstructed
	aim_is_obstructed = not query_aim_hit(settings.near_wall_check_distance).is_empty()
	if aim_is_obstructed != was_obstructed:
		aim_obstruction_changed.emit(aim_is_obstructed)


func _set_aim_obstructed(is_obstructed: bool) -> void:
	if aim_is_obstructed == is_obstructed:
		return
	aim_is_obstructed = is_obstructed
	aim_obstruction_changed.emit(aim_is_obstructed)


func _set_transitioning(value: bool) -> void:
	if is_transitioning == value:
		return
	is_transitioning = value
	transition_state_changed.emit(is_transitioning)


func _snap_to_exploration_pose() -> void:
	if not is_node_ready():
		return
	_set_transitioning(false)
	gameplay_camera.global_transform = _exploration_pose() if _tracked_actor != null else _fallback_pose()
	gameplay_camera.fov = _exploration_fov()
	_update_actor_camera_basis()


func _connect_game_state() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	if game_state.has_signal(&"pause_changed"):
		game_state.pause_changed.connect(_on_pause_changed)
	if game_state.has_signal(&"phase_changed"):
		game_state.phase_changed.connect(_on_phase_changed)


func _on_pause_changed(is_paused: bool) -> void:
	if is_paused and mode == CameraMode.AIM:
		request_aim(false)


func _on_phase_changed(_previous: int, current: int) -> void:
	# Constants mirror the accepted GameState phase contract without importing its script.
	if current in [GAME_PHASE_PLAYER_DEAD, GAME_PHASE_COMPLETED, GAME_PHASE_RESTARTING] and mode == CameraMode.AIM:
		request_aim(false)


func _set_debug_visible(visible: bool) -> void:
	var allowed := visible and OS.is_debug_build()
	debug_label.visible = allowed
	debug_aim_ray.visible = allowed


func _update_debug_display() -> void:
	if not debug_label.visible:
		return
	var zone_name := String(active_zone.get_zone_id()) if active_zone != null else "FALLBACK"
	debug_label.text = "CAMERA %s  ZONE %s  BLEND %s  AIM BLOCKED %s" % [
		"AIM" if mode == CameraMode.AIM else "EXPLORATION",
		zone_name,
		"YES" if is_transitioning else "NO",
		"YES" if aim_is_obstructed else "NO",
	]
	var immediate_mesh := debug_aim_ray.mesh as ImmediateMesh
	immediate_mesh.clear_surfaces()
	if mode != CameraMode.AIM:
		return
	var ray := get_aim_ray(25.0)
	debug_aim_ray.global_transform = Transform3D.IDENTITY
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	immediate_mesh.surface_set_color(Color(1.0, 0.25, 0.12, 1.0) if aim_is_obstructed else Color(0.25, 1.0, 0.55, 1.0))
	immediate_mesh.surface_add_vertex(ray.origin)
	immediate_mesh.surface_add_vertex(ray.end)
	immediate_mesh.surface_end()

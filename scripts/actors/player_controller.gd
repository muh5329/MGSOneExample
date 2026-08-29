class_name PlayerController
extends CharacterBody3D

signal stance_changed(previous: Stance, current: Stance)
signal control_enabled_changed(enabled: bool)
signal movement_noise_changed(intensity: float)
signal movement_noise_emitted(event: NoiseEvent3D)
signal aim_state_changed(active: bool)
signal animation_parameters_updated(
	local_planar_velocity: Vector2,
	speed_ratio: float,
	grounded: bool,
	stance: Stance
)

enum Stance {
	STANDING,
	CROUCHED,
}

enum ControlLock {
	MENU = 1,
	DEATH = 2,
	SCRIPTED = 4,
	AIM = 8,
	EXTERNAL = 16,
}

@export var config: PlayerMovementConfig

@onready var body_origin: Marker3D = %BodyOrigin
@onready var body_collision: CollisionShape3D = %BodyCollision
@onready var interaction_origin: Marker3D = %InteractionOrigin
@onready var aim_origin: Marker3D = %AimOrigin
@onready var health: HealthComponent = %Health

var stance: Stance = Stance.STANDING
var facing_direction: Vector3 = Vector3.FORWARD
var grounded: bool = false
var speed_ratio: float = 0.0
var movement_noise_intensity: float = 0.0
var surface_noise_multiplier: float = 1.0
var control_enabled: bool = true

var _control_locks: int = 0
var _camera_basis: Basis = Basis.IDENTITY
var _latched_movement_basis: Basis = Basis.IDENTITY
var _has_latched_movement_basis: bool = false
var _noise_event_time: float = 0.0


func _ready() -> void:
	assert(config != null, "PlayerController requires a PlayerMovementConfig resource.")
	floor_snap_length = config.floor_snap_length
	floor_max_angle = deg_to_rad(config.maximum_slope_degrees)
	floor_stop_on_slope = true
	_apply_stance_geometry(stance)
	facing_direction = -global_basis.z


func _physics_process(delta: float) -> void:
	var input_vector := Vector2.ZERO
	if control_enabled:
		input_vector = Input.get_vector(
			&"move_left", &"move_right", &"move_forward", &"move_back"
		).limit_length(1.0)
		_handle_crouch_input()

	var movement_direction := _movement_direction_for_input(input_vector)
	_update_horizontal_velocity(movement_direction, delta)
	_update_vertical_velocity(delta)
	_update_facing(movement_direction, delta)
	move_and_slide()
	_update_outputs(delta)


func set_camera_basis(camera_basis: Basis) -> void:
	_camera_basis = camera_basis.orthonormalized()


func set_control_lock(reason: int, locked: bool) -> void:
	var was_enabled := control_enabled
	if locked:
		_control_locks |= reason
	else:
		_control_locks &= ~reason
	control_enabled = _control_locks == 0
	if not control_enabled:
		_stop_planar_motion()
		_release_movement_basis()
	if control_enabled != was_enabled:
		control_enabled_changed.emit(control_enabled)


func set_control_enabled(enabled: bool) -> void:
	set_control_lock(ControlLock.EXTERNAL, not enabled)


func set_aim_movement_locked(locked: bool) -> void:
	var was_locked := _control_locks & ControlLock.AIM != 0
	set_control_lock(ControlLock.AIM, locked)
	if locked != was_locked:
		aim_state_changed.emit(locked)


func set_surface_noise_multiplier(multiplier: float) -> void:
	surface_noise_multiplier = maxf(multiplier, 0.0)


func request_crouch(should_crouch: bool) -> bool:
	return request_stance(Stance.CROUCHED if should_crouch else Stance.STANDING)


func request_stance(next_stance: Stance) -> bool:
	if next_stance == stance:
		return true
	if next_stance == Stance.STANDING and not _has_standing_clearance():
		return false
	var previous := stance
	stance = next_stance
	_apply_stance_geometry(stance)
	stance_changed.emit(previous, stance)
	return true


func get_control_locks() -> int:
	return _control_locks


func receive_damage(amount: float, context: HitContext3D = null) -> bool:
	return health.receive_damage(amount, context)


func can_receive_item_effect(effect_id: StringName, amount: float) -> bool:
	return health.can_receive_item_effect(effect_id, amount)


func receive_item_effect(effect_id: StringName, amount: float, context: Dictionary) -> bool:
	return health.receive_item_effect(effect_id, amount, context)


static func camera_relative_direction(input_vector: Vector2, camera_basis: Basis) -> Vector3:
	var clamped_input := input_vector.limit_length(1.0)
	if clamped_input.is_zero_approx():
		return Vector3.ZERO
	var camera_forward := -camera_basis.z
	camera_forward.y = 0.0
	if camera_forward.is_zero_approx():
		camera_forward = Vector3.FORWARD
	else:
		camera_forward = camera_forward.normalized()
	var camera_right := camera_basis.x
	camera_right.y = 0.0
	if camera_right.is_zero_approx():
		camera_right = Vector3.RIGHT
	else:
		camera_right = camera_right.normalized()
	return (camera_right * clamped_input.x + camera_forward * -clamped_input.y).limit_length(1.0)


static func normalized_noise(
		planar_speed: float,
		maximum_speed: float,
		stance_multiplier: float,
		surface_multiplier: float,
		is_grounded: bool
) -> float:
	if not is_grounded or maximum_speed <= 0.0:
		return 0.0
	return clampf(
		(planar_speed / maximum_speed) * stance_multiplier * maxf(surface_multiplier, 0.0),
		0.0,
		1.0
	)


func _movement_direction_for_input(input_vector: Vector2) -> Vector3:
	if input_vector.is_zero_approx():
		_release_movement_basis()
		return Vector3.ZERO
	if not _has_latched_movement_basis:
		_latched_movement_basis = _camera_basis
		_has_latched_movement_basis = true
	return camera_relative_direction(input_vector, _latched_movement_basis)


func _update_horizontal_velocity(direction: Vector3, delta: float) -> void:
	var maximum_speed := _maximum_speed()
	var target_velocity := direction * maximum_speed
	var current_planar := Vector3(velocity.x, 0.0, velocity.z)
	var rate := config.acceleration if not target_velocity.is_zero_approx() else config.deceleration
	var next_planar := current_planar.move_toward(target_velocity, rate * delta)
	velocity.x = next_planar.x
	velocity.z = next_planar.z


func _update_vertical_velocity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= config.gravity * delta


func _update_facing(movement_direction: Vector3, delta: float) -> void:
	if movement_direction.is_zero_approx():
		facing_direction = -global_basis.z
		return
	var target_yaw := atan2(-movement_direction.x, -movement_direction.z)
	rotation.y = rotate_toward(
		rotation.y,
		target_yaw,
		deg_to_rad(config.turn_speed_degrees) * delta
	)
	facing_direction = -global_basis.z


func _update_outputs(delta: float) -> void:
	grounded = is_on_floor()
	var planar_velocity := Vector3(velocity.x, 0.0, velocity.z)
	speed_ratio = clampf(planar_velocity.length() / _maximum_speed(), 0.0, 1.0)
	var noise_multiplier := (
		config.crouch_noise_multiplier
		if stance == Stance.CROUCHED
		else config.standing_noise_multiplier
	)
	var next_noise := normalized_noise(
		planar_velocity.length(),
		_maximum_speed(),
		noise_multiplier,
		surface_noise_multiplier,
		grounded
	)
	_set_movement_noise(next_noise)
	_emit_periodic_noise(delta)

	var local_velocity := global_basis.inverse() * planar_velocity
	animation_parameters_updated.emit(
		Vector2(local_velocity.x, local_velocity.z),
		speed_ratio,
		grounded,
		stance
	)


func _emit_periodic_noise(delta: float) -> void:
	if movement_noise_intensity < config.minimum_noise_event:
		_noise_event_time = 0.0
		return
	_noise_event_time += delta
	if _noise_event_time < config.noise_event_interval:
		return
	_noise_event_time = fmod(_noise_event_time, config.noise_event_interval)
	var event := NoiseEvent3D.new(
		self,
		global_position,
		movement_noise_intensity,
		&"player_movement"
	)
	movement_noise_emitted.emit(event)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.emit_noise(event)


func _handle_crouch_input() -> void:
	if Input.is_action_just_pressed(&"crouch"):
		request_crouch(stance == Stance.STANDING)


func _has_standing_clearance() -> bool:
	if not is_inside_tree():
		return true
	var query_shape := CapsuleShape3D.new()
	query_shape.radius = maxf(config.capsule_radius - config.clearance_margin, 0.01)
	query_shape.height = maxf(
		config.standing_height - config.clearance_margin * 2.0,
		query_shape.radius * 2.0
	)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = query_shape
	query.transform = global_transform.translated_local(
		Vector3.UP * config.standing_height * 0.5
	)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _apply_stance_geometry(next_stance: Stance) -> void:
	var height := config.crouch_height if next_stance == Stance.CROUCHED else config.standing_height
	var capsule := body_collision.shape as CapsuleShape3D
	assert(capsule != null, "Player BodyCollision must use CapsuleShape3D.")
	capsule.radius = config.capsule_radius
	capsule.height = maxf(height, config.capsule_radius * 2.0)
	body_origin.position.y = height * 0.5
	body_collision.position.y = height * 0.5
	interaction_origin.position.y = height * 0.72
	aim_origin.position.y = height * 0.84


func _maximum_speed() -> float:
	return config.crouch_speed if stance == Stance.CROUCHED else config.standing_speed


func _stop_planar_motion() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_set_movement_noise(0.0)
	_noise_event_time = 0.0


func _set_movement_noise(intensity: float) -> void:
	if is_equal_approx(intensity, movement_noise_intensity):
		return
	movement_noise_intensity = intensity
	movement_noise_changed.emit(movement_noise_intensity)


func _release_movement_basis() -> void:
	_has_latched_movement_basis = false

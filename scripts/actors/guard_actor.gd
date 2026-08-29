class_name GuardActor
extends CharacterBody3D

signal state_changed(guard_id: StringName, previous: GuardState, current: GuardState)
signal suspicion_changed(guard_id: StringName, previous: float, current: float)
signal detection_reported(guard_id: StringName, world_position: Vector3, evidence: StringName)
signal target_lost(guard_id: StringName, last_known_position: Vector3)
signal combat_requested(guard_id: StringName, target: Node3D, context: HitContext3D)
signal attack_telegraphed(guard_id: StringName, target_position: Vector3, duration: float)
signal radar_snapshot_changed(snapshot: Dictionary)
signal animation_parameters_updated(local_velocity: Vector2, speed_ratio: float, state: GuardState)

enum GuardState {
	PATROL,
	SUSPICIOUS,
	INVESTIGATE,
	ALERT_CHASE,
	ATTACK,
	SEARCH,
	RETURN,
	STUNNED,
	DEAD,
}

const STATE_NAMES := [
	&"PATROL", &"SUSPICIOUS", &"INVESTIGATE", &"ALERT_CHASE", &"ATTACK",
	&"SEARCH", &"RETURN", &"STUNNED", &"DEAD",
]

@export var guard_id: StringName = &"GUARD"
@export var config: GuardConfig

@onready var navigation_agent: NavigationAgent3D = %NavigationAgent
@onready var perception: GuardPerception3D = %Perception
@onready var health: HealthComponent = %Health
@onready var body_collision: CollisionShape3D = %BodyCollision
@onready var damage_hitbox: Area3D = %DamageHitbox

var state: GuardState = GuardState.PATROL
var facing_direction: Vector3 = Vector3.FORWARD
var target: Node3D
var patrol_route: PatrolRoute3D
var authored_transform: Transform3D
var patrol_index: int = 0

var _state_time: float = 0.0
var _wait_remaining: float = 0.0
var _lost_sight_time: float = 0.0
var _unreachable_time: float = 0.0
var _attack_time: float = 0.0
var _attack_sequence: int = 0
var _search_index: int = 0
var _destination: Vector3 = Vector3.ZERO
var _has_destination: bool = false
var _stun_duration: float = 0.0
var _authored_collision_layer: int
var _authored_collision_mask: int
var _search_offsets: Array[Vector3] = []


func _ready() -> void:
	assert(config != null and config.is_valid_config(), "GuardActor requires a valid GuardConfig.")
	add_to_group(&"guards")
	add_to_group(&"checkpoint_reset_targets")
	authored_transform = global_transform
	_authored_collision_layer = collision_layer
	_authored_collision_mask = collision_mask
	perception.config = config
	perception.position.y = config.eye_height
	perception.suspicion_changed.connect(_on_suspicion_changed)
	perception.detection_confirmed.connect(_on_detection_confirmed)
	perception.target_lost.connect(_on_target_lost)
	perception.noise_heard.connect(_on_noise_heard)
	health.died.connect(_on_died)
	navigation_agent.path_desired_distance = config.destination_tolerance
	navigation_agent.target_desired_distance = config.destination_tolerance
	navigation_agent.avoidance_enabled = false
	_search_offsets = [
		Vector3(config.search_radius, 0.0, 0.0),
		Vector3(0.0, 0.0, config.search_radius),
		Vector3(-config.search_radius, 0.0, 0.0),
		Vector3(0.0, 0.0, -config.search_radius),
	]
	facing_direction = -global_basis.z


func _physics_process(delta: float) -> void:
	advance_runtime(delta)
	_update_motion(delta)


func configure(
		new_guard_id: StringName,
		route: PatrolRoute3D,
		observable_target: Node3D,
		navigation_map: RID = RID()
) -> bool:
	if new_guard_id.is_empty() or route == null or route.get_point_count() <= 0:
		return false
	guard_id = new_guard_id
	patrol_route = route
	target = observable_target
	perception.set_target(target)
	patrol_index = 0
	global_position = patrol_route.get_point_world_position(0)
	authored_transform = global_transform
	if navigation_map.is_valid():
		navigation_agent.set_navigation_map(navigation_map)
	_set_destination(patrol_route.get_point_world_position(0))
	return true


func advance_runtime(delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta) or state == GuardState.DEAD:
		return
	_state_time += delta
	perception.advance_perception(delta)
	if target == null or not is_instance_valid(target) or _target_is_dead():
		if state not in [GuardState.PATROL, GuardState.RETURN, GuardState.STUNNED]:
			_set_state(GuardState.RETURN)
	_tick_state(delta)
	radar_snapshot_changed.emit(get_radar_snapshot())


func set_target(observable_target: Node3D) -> void:
	target = observable_target
	perception.set_target(observable_target)


func receive_alert_broadcast(world_position: Vector3, source_guard_id: StringName = &"") -> bool:
	if state == GuardState.DEAD or not world_position.is_finite():
		return false
	if source_guard_id == guard_id and state in [GuardState.ALERT_CHASE, GuardState.ATTACK]:
		return true
	perception.last_known_position = world_position
	perception.last_stimulus_position = world_position
	_set_state(GuardState.ALERT_CHASE)
	return true


func receive_damage(amount: float, context: HitContext3D = null) -> bool:
	return health.receive_damage(amount, context)


func stun(duration: float) -> bool:
	if state == GuardState.DEAD or not is_finite(duration) or duration <= 0.0:
		return false
	_stun_duration = duration
	_set_state(GuardState.STUNNED)
	return true


func reset_transient_state(_checkpoint_id: StringName) -> void:
	global_transform = authored_transform
	velocity = Vector3.ZERO
	collision_layer = _authored_collision_layer
	collision_mask = _authored_collision_mask
	body_collision.set_deferred(&"disabled", false)
	damage_hitbox.collision_layer = 8
	health.restore_checkpoint_snapshot({
		&"current_health": health.maximum_health,
		&"maximum_health": health.maximum_health,
		&"is_dead": false,
	})
	perception.set_perception_enabled(true)
	perception.reset_perception()
	patrol_index = 0
	_wait_remaining = 0.0
	_lost_sight_time = 0.0
	_unreachable_time = 0.0
	_attack_time = 0.0
	_attack_sequence = 0
	_search_index = 0
	_stun_duration = 0.0
	_set_state(GuardState.PATROL, true)
	if patrol_route != null and patrol_route.get_point_count() > 0:
		_set_destination(patrol_route.get_point_world_position(0))


func get_radar_snapshot() -> Dictionary:
	return {
		&"guard_id": guard_id,
		&"world_position": global_position,
		&"facing_direction": facing_direction,
		&"state": STATE_NAMES[int(state)],
		&"suspicion": perception.suspicion,
		&"target_visible": perception.target_visible,
		&"last_known_position": perception.last_known_position,
		&"vision_range": config.standing_vision_range,
		&"vision_angle_degrees": config.horizontal_cone_degrees,
		&"alive": state != GuardState.DEAD,
	}


func get_state_snapshot() -> Dictionary:
	return {
		&"guard_id": guard_id,
		&"state": STATE_NAMES[int(state)],
		&"state_time": _state_time,
		&"patrol_index": patrol_index,
		&"destination": _destination,
		&"suspicion": perception.suspicion,
		&"target_visible": perception.target_visible,
		&"last_known_position": perception.last_known_position,
		&"health": health.current_health,
	}


func get_debug_destination() -> Vector3:
	return _destination if _has_destination else Vector3.ZERO


func _tick_state(delta: float) -> void:
	match state:
		GuardState.PATROL:
			_tick_patrol(delta)
		GuardState.SUSPICIOUS:
			_face_world_position(perception.last_stimulus_position, delta)
			if perception.target_visible:
				return
			if _state_time >= config.suspicious_pause_duration:
				_set_destination(perception.last_stimulus_position)
				_set_state(GuardState.INVESTIGATE)
		GuardState.INVESTIGATE:
			_tick_investigate(delta)
		GuardState.ALERT_CHASE:
			_tick_alert_chase(delta)
		GuardState.ATTACK:
			_tick_attack(delta)
		GuardState.SEARCH:
			_tick_search(delta)
		GuardState.RETURN:
			_tick_return(delta)
		GuardState.STUNNED:
			_stun_duration = maxf(_stun_duration - delta, 0.0)
			if _stun_duration <= 0.0:
				_set_state(GuardState.RETURN)


func _tick_patrol(delta: float) -> void:
	if patrol_route == null or patrol_route.get_point_count() <= 0:
		_stop_planar_motion()
		return
	if _wait_remaining > 0.0:
		_wait_remaining = maxf(_wait_remaining - delta, 0.0)
		_stop_planar_motion()
		var look := patrol_route.get_look_direction(patrol_index)
		if not look.is_zero_approx():
			_face_direction(look, delta)
		if _wait_remaining <= 0.0:
			patrol_index = patrol_route.get_next_index(patrol_index)
			_set_destination(patrol_route.get_point_world_position(patrol_index))
		return
	if _destination_reached():
		_wait_remaining = patrol_route.get_wait_seconds(patrol_index)
		if _wait_remaining <= 0.0:
			patrol_index = patrol_route.get_next_index(patrol_index)
			_set_destination(patrol_route.get_point_world_position(patrol_index))
	elif navigation_agent != null and not navigation_agent.is_target_reachable():
		_unreachable_time += delta
		if _unreachable_time >= config.unreachable_timeout:
			_unreachable_time = 0.0
			patrol_index = patrol_route.get_next_index(patrol_index)
			_set_destination(patrol_route.get_point_world_position(patrol_index))
	else:
		_unreachable_time = 0.0


func _tick_investigate(delta: float) -> void:
	if perception.target_visible:
		return
	if _destination_reached() or _state_time >= config.investigate_duration:
		_set_state(GuardState.SEARCH)
	else:
		_handle_unreachable(delta, GuardState.SEARCH)


func _tick_alert_chase(delta: float) -> void:
	if perception.target_visible and target != null:
		_lost_sight_time = 0.0
		_set_destination(perception.last_known_position)
		var distance := global_position.distance_to(target.global_position)
		if distance <= config.attack_range:
			_set_state(GuardState.ATTACK)
	else:
		_lost_sight_time += delta
		_set_destination(perception.last_known_position)
		if _lost_sight_time >= config.lost_sight_grace or _destination_reached():
			_set_state(GuardState.SEARCH)
		else:
			_handle_unreachable(delta, GuardState.SEARCH)


func _tick_attack(_delta: float) -> void:
	_stop_planar_motion()
	if target == null or not is_instance_valid(target) or _target_is_dead():
		_set_state(GuardState.RETURN)
		return
	_face_world_position(target.global_position, _delta)
	_attack_time += _delta
	if not perception.target_visible or global_position.distance_to(target.global_position) > config.attack_range:
		_set_state(GuardState.ALERT_CHASE)
		return
	if _attack_time < config.attack_telegraph_duration:
		return
	if _attack_time >= config.attack_cadence:
		_attack_time = 0.0
		_submit_attack()
		attack_telegraphed.emit(guard_id, target.global_position, config.attack_telegraph_duration)


func _tick_search(delta: float) -> void:
	if perception.target_visible:
		_set_state(GuardState.ALERT_CHASE)
		return
	if _state_time >= config.local_search_duration:
		_set_state(GuardState.RETURN)
		return
	if _destination_reached():
		_search_index = (_search_index + 1) % _search_offsets.size()
		_set_destination(perception.last_known_position + _search_offsets[_search_index])
	else:
		_handle_unreachable(delta, GuardState.RETURN)


func _tick_return(delta: float) -> void:
	if patrol_route == null or patrol_route.get_point_count() <= 0:
		_set_state(GuardState.PATROL)
		return
	if not _has_destination:
		patrol_index = patrol_route.get_closest_point_index(global_position)
		_set_destination(patrol_route.get_point_world_position(patrol_index))
	if _destination_reached():
		perception.reset_perception()
		_set_state(GuardState.PATROL)
		_wait_remaining = patrol_route.get_wait_seconds(patrol_index)
	else:
		_handle_unreachable(delta, GuardState.PATROL)


func _set_state(next_state: GuardState, force: bool = false) -> void:
	if not force and next_state == state:
		return
	var previous := state
	state = next_state
	_state_time = 0.0
	_unreachable_time = 0.0
	if state != GuardState.ATTACK:
		_attack_time = 0.0
	match state:
		GuardState.PATROL:
			if patrol_route != null and patrol_route.get_point_count() > 0:
				_set_destination(patrol_route.get_point_world_position(patrol_index))
		GuardState.SUSPICIOUS:
			_clear_destination()
		GuardState.ALERT_CHASE:
			_lost_sight_time = 0.0
			_set_destination(perception.last_known_position)
		GuardState.ATTACK:
			_clear_destination()
			attack_telegraphed.emit(guard_id, target.global_position if target != null else perception.last_known_position, config.attack_telegraph_duration)
		GuardState.SEARCH:
			_search_index = 0
			_set_destination(perception.last_known_position + _search_offsets[0])
		GuardState.RETURN:
			_clear_destination()
		GuardState.STUNNED, GuardState.DEAD:
			_clear_destination()
			_stop_planar_motion()
	state_changed.emit(guard_id, previous, state)


func _update_motion(delta: float) -> void:
	if state in [GuardState.DEAD, GuardState.STUNNED, GuardState.SUSPICIOUS, GuardState.ATTACK]:
		_stop_planar_motion()
	else:
		var desired := Vector3.ZERO
		if _has_destination and navigation_agent != null and not navigation_agent.is_navigation_finished():
			var next_position := navigation_agent.get_next_path_position()
			desired = next_position - global_position
			desired.y = 0.0
			if not desired.is_zero_approx():
				desired = desired.normalized() * _movement_speed()
		var planar := Vector3(velocity.x, 0.0, velocity.z).move_toward(desired, config.acceleration * delta)
		velocity.x = planar.x
		velocity.z = planar.z
		if not planar.is_zero_approx():
			_face_direction(planar.normalized(), delta)
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()
	var local := global_basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
	animation_parameters_updated.emit(
		Vector2(local.x, local.z),
		clampf(Vector2(velocity.x, velocity.z).length() / maxf(config.pursuit_speed, 0.001), 0.0, 1.0),
		state
	)


func _movement_speed() -> float:
	match state:
		GuardState.ALERT_CHASE:
			return config.pursuit_speed
		GuardState.SUSPICIOUS, GuardState.INVESTIGATE, GuardState.SEARCH:
			return config.suspicious_speed
		_:
			return config.patrol_speed


func _set_destination(world_position: Vector3) -> void:
	if not world_position.is_finite():
		return
	_destination = world_position
	_has_destination = true
	if navigation_agent != null and navigation_agent.is_inside_tree():
		navigation_agent.target_position = world_position


func _clear_destination() -> void:
	_has_destination = false
	_destination = Vector3.ZERO


func _destination_reached() -> bool:
	return _has_destination and global_position.distance_to(_destination) <= config.destination_tolerance


func _handle_unreachable(delta: float, fallback: GuardState) -> void:
	if navigation_agent == null or navigation_agent.is_target_reachable():
		_unreachable_time = 0.0
		return
	_unreachable_time += delta
	if _unreachable_time >= config.unreachable_timeout:
		_set_state(fallback)


func _face_world_position(world_position: Vector3, delta: float) -> void:
	var direction := world_position - global_position
	direction.y = 0.0
	if not direction.is_zero_approx():
		_face_direction(direction.normalized(), delta)


func _face_direction(direction: Vector3, delta: float) -> void:
	if direction.is_zero_approx():
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = rotate_toward(rotation.y, target_yaw, deg_to_rad(config.turn_speed_degrees) * delta)
	facing_direction = -global_basis.z


func _stop_planar_motion() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _submit_attack() -> void:
	if target == null or not target.has_method(&"receive_damage"):
		return
	_attack_sequence += 1
	var direction := target.global_position - global_position
	if direction.is_zero_approx():
		direction = facing_direction
	direction = direction.normalized()
	var context := HitContext3D.new(
		self,
		&"GUARD_SERVICE_WEAPON",
		_attack_sequence,
		target.global_position,
		-direction,
		direction,
		config.attack_damage,
		PackedStringArray(["ballistic", "enemy"]),
		target
	)
	combat_requested.emit(guard_id, target, context)
	target.call(&"receive_damage", config.attack_damage, context)


func _target_is_dead() -> bool:
	if target == null or not is_instance_valid(target):
		return true
	var target_health := target.get_node_or_null("Health")
	return target_health != null and bool(target_health.get(&"is_dead"))


func _on_suspicion_changed(previous: float, current: float) -> void:
	suspicion_changed.emit(guard_id, previous, current)
	if current > 0.0 and state in [GuardState.PATROL, GuardState.RETURN]:
		_set_state(GuardState.SUSPICIOUS)
	elif current <= 0.0 and state == GuardState.SUSPICIOUS:
		_set_state(GuardState.RETURN)


func _on_detection_confirmed(_observed: Node3D, world_position: Vector3, evidence: StringName) -> void:
	if state == GuardState.DEAD:
		return
	detection_reported.emit(guard_id, world_position, evidence)
	_set_state(GuardState.ALERT_CHASE)


func _on_target_lost(last_position: Vector3) -> void:
	target_lost.emit(guard_id, last_position)


func _on_noise_heard(
		_event: NoiseEvent3D,
		world_position: Vector3,
		_strength: float,
		_occluded: bool
) -> void:
	if state in [GuardState.PATROL, GuardState.RETURN, GuardState.SUSPICIOUS]:
		perception.last_stimulus_position = world_position
		_set_state(GuardState.SUSPICIOUS)


func _on_died(_context: HitContext3D) -> void:
	perception.set_perception_enabled(false)
	collision_layer = 0
	collision_mask = 0
	damage_hitbox.collision_layer = 0
	body_collision.set_deferred(&"disabled", true)
	_set_state(GuardState.DEAD)

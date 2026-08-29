class_name GuardPerception3D
extends Node3D

signal observation_updated(snapshot: Dictionary)
signal suspicion_changed(previous: float, current: float)
signal detection_confirmed(target: Node3D, world_position: Vector3, evidence: StringName)
signal target_lost(last_known_position: Vector3)
signal noise_heard(event: NoiseEvent3D, perceived_position: Vector3, strength: float, occluded: bool)

const PLAYER_CROUCHED_STANCE := 1

@export var config: GuardConfig

var target: Node3D
var suspicion: float = 0.0
var target_visible: bool = false
var last_known_position: Vector3 = Vector3.ZERO
var last_stimulus_position: Vector3 = Vector3.ZERO
var last_visible_sample: Vector3 = Vector3.ZERO
var last_ray_blocked: bool = false
var perception_enabled: bool = true

var _confirmed_current_contact: bool = false
var _last_observation: Dictionary = {}


func _ready() -> void:
	_connect_event_bus()


func set_target(observable_target: Node3D) -> void:
	target = observable_target


func set_perception_enabled(enabled: bool) -> void:
	perception_enabled = enabled
	if not perception_enabled:
		target_visible = false


func advance_perception(delta: float) -> Dictionary:
	if config == null or delta <= 0.0 or not is_finite(delta) or not perception_enabled:
		return get_observation_snapshot()
	var observation := scan_target()
	var was_visible := target_visible
	target_visible = bool(observation.visible)
	last_ray_blocked = bool(observation.blocked)
	last_visible_sample = observation.sample_position
	if target_visible:
		last_known_position = observation.target_position
		last_stimulus_position = last_known_position
		var distance_ratio := clampf(float(observation.distance) / maxf(float(observation.range), 0.001), 0.0, 1.0)
		var exposure_scale := lerpf(1.15, 0.55, distance_ratio)
		var next_suspicion := suspicion + delta * exposure_scale / config.sight_confirmation_time
		if float(observation.distance) <= config.close_range_confirmation:
			next_suspicion = 1.0
		_set_suspicion(next_suspicion)
		if suspicion >= 1.0 and not _confirmed_current_contact:
			_confirmed_current_contact = true
			detection_confirmed.emit(target, last_known_position, &"VISION")
	else:
		_set_suspicion(suspicion - delta / config.suspicion_decay_time)
		if suspicion <= 0.0:
			_confirmed_current_contact = false
		if was_visible:
			target_lost.emit(last_known_position)
	_last_observation = observation
	observation_updated.emit(get_observation_snapshot())
	return get_observation_snapshot()


func scan_target() -> Dictionary:
	var empty := {
		&"visible": false,
		&"blocked": false,
		&"distance": INF,
		&"range": 0.0,
		&"target_position": last_known_position,
		&"sample_position": Vector3.ZERO,
	}
	if target == null or not is_instance_valid(target) or config == null:
		return empty
	if _target_is_dead():
		return empty
	var eye := global_position
	var forward := -global_basis.z
	forward.y = 0.0
	if forward.is_zero_approx():
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var target_range := _target_vision_range()
	var closest_distance := global_position.distance_to(target.global_position)
	empty[&"distance"] = closest_distance
	empty[&"range"] = target_range
	empty[&"target_position"] = target.global_position
	var any_broad_phase := false
	for height in config.target_sample_heights:
		var sample := target.global_position + Vector3.UP * float(height)
		if not is_point_in_view(
			eye, forward, sample, target_range,
			config.horizontal_cone_degrees, config.vertical_cone_degrees
		):
			continue
		any_broad_phase = true
		if empty.sample_position == Vector3.ZERO:
			empty[&"sample_position"] = sample
		var hit := _query_sight(eye, sample)
		if hit.is_empty() or _collider_belongs_to_target(hit.get(&"collider", null)):
			return {
				&"visible": true,
				&"blocked": false,
				&"distance": eye.distance_to(sample),
				&"range": target_range,
				&"target_position": target.global_position,
				&"sample_position": sample,
			}
	empty[&"blocked"] = any_broad_phase
	return empty


func receive_noise(event: NoiseEvent3D) -> bool:
	if (
		event == null or config == null or not perception_enabled
		or event.source == get_parent() or not is_finite(event.loudness) or event.loudness <= 0.0
	):
		return false
	var maximum_distance := event.loudness
	if event.category == &"player_movement":
		maximum_distance *= config.movement_hearing_radius
	var distance := global_position.distance_to(event.world_position)
	var occluded := _is_hearing_occluded(event.world_position)
	if occluded:
		maximum_distance *= config.occluded_hearing_multiplier
	if maximum_distance <= 0.0 or distance > maximum_distance:
		return false
	var strength := clampf(1.0 - distance / maximum_distance, 0.0, 1.0)
	last_stimulus_position = event.world_position
	last_known_position = event.world_position
	var stimulus := maxf(config.minimum_suspicion_stimulus, strength)
	if event.category == &"gunshot":
		stimulus = 1.0
	_set_suspicion(maxf(suspicion, stimulus))
	noise_heard.emit(event, event.world_position, strength, occluded)
	if event.category == &"gunshot" and not _confirmed_current_contact:
		_confirmed_current_contact = true
		detection_confirmed.emit(event.source, event.world_position, &"GUNSHOT")
	return true


func reset_perception() -> void:
	target_visible = false
	last_known_position = Vector3.ZERO
	last_stimulus_position = Vector3.ZERO
	last_visible_sample = Vector3.ZERO
	last_ray_blocked = false
	_confirmed_current_contact = false
	_last_observation = {}
	_set_suspicion(0.0)


func get_observation_snapshot() -> Dictionary:
	return {
		&"target_visible": target_visible,
		&"suspicion": suspicion,
		&"last_known_position": last_known_position,
		&"last_stimulus_position": last_stimulus_position,
		&"visible_sample": last_visible_sample,
		&"ray_blocked": last_ray_blocked,
		&"distance": float(_last_observation.get(&"distance", INF)),
		&"vision_range": _target_vision_range() if config != null else 0.0,
	}


static func is_point_in_view(
		eye: Vector3,
		forward: Vector3,
		point: Vector3,
		maximum_range: float,
		horizontal_degrees: float,
		vertical_degrees: float
) -> bool:
	var offset := point - eye
	if offset.is_zero_approx():
		return true
	if offset.length() > maximum_range:
		return false
	var planar_offset := Vector3(offset.x, 0.0, offset.z)
	var planar_forward := Vector3(forward.x, 0.0, forward.z)
	if planar_offset.is_zero_approx() or planar_forward.is_zero_approx():
		return false
	var horizontal_angle := rad_to_deg(acos(clampf(
		planar_forward.normalized().dot(planar_offset.normalized()), -1.0, 1.0
	)))
	var vertical_angle := rad_to_deg(atan2(absf(offset.y), planar_offset.length()))
	return horizontal_angle <= horizontal_degrees * 0.5 and vertical_angle <= vertical_degrees * 0.5


func _set_suspicion(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	if is_equal_approx(next, suspicion):
		return
	var previous := suspicion
	suspicion = next
	suspicion_changed.emit(previous, suspicion)


func _target_vision_range() -> float:
	if config == null:
		return 0.0
	if target != null and is_instance_valid(target):
		var target_stance: Variant = target.get(&"stance")
		if target_stance != null and int(target_stance) == PLAYER_CROUCHED_STANCE:
			return config.crouched_vision_range
	return config.standing_vision_range


func _target_is_dead() -> bool:
	if target == null or not is_instance_valid(target):
		return true
	var target_health := target.get_node_or_null("Health")
	return target_health != null and bool(target_health.get(&"is_dead"))


func _query_sight(origin: Vector3, end: Vector3) -> Dictionary:
	if not is_inside_tree() or config.perception_mask == 0:
		return {}
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = config.perception_mask
	query.collide_with_areas = true
	query.exclude = _owner_collision_rids()
	return get_world_3d().direct_space_state.intersect_ray(query)


func _is_hearing_occluded(world_position: Vector3) -> bool:
	if not is_inside_tree() or config.hearing_occlusion_mask == 0:
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position, world_position)
	query.collision_mask = config.hearing_occlusion_mask
	query.collide_with_areas = false
	query.exclude = _owner_collision_rids()
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _owner_collision_rids() -> Array[RID]:
	var result: Array[RID] = []
	var owner := get_parent()
	if owner == null:
		return result
	var nodes: Array[Node] = [owner]
	nodes.append_array(owner.find_children("*", "CollisionObject3D", true, false))
	for node in nodes:
		if node is CollisionObject3D:
			result.append((node as CollisionObject3D).get_rid())
	return result


func _collider_belongs_to_target(collider: Object) -> bool:
	var current := collider as Node
	while current != null:
		if current == target:
			return true
		current = current.get_parent()
	return false


func _connect_event_bus() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and not event_bus.noise_emitted.is_connected(receive_noise):
		event_bus.noise_emitted.connect(receive_noise)

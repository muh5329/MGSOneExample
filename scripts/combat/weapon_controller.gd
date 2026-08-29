class_name WeaponController
extends Node3D

signal state_changed(previous: WeaponState, current: WeaponState)
signal equipped_changed(definition: WeaponDefinition, equipped: bool)
signal ammo_state_changed(magazine: int, reserve: int)
signal shot_fired(context: HitContext3D)
signal dry_fired(reason: StringName)
signal reload_started(duration: float)
signal reload_completed(rounds_loaded: int)
signal reload_cancelled(reason: StringName)
signal impact_resolved(context: HitContext3D, collider: Object)
signal damage_submitted(receiver: Object, amount: float, context: HitContext3D)
signal feedback_requested(feedback_id: StringName, payload: Dictionary)

enum WeaponState {
	HOLSTERED,
	EQUIPPING,
	READY,
	FIRING_COOLDOWN,
	RELOADING,
	DISABLED,
}

const HITSCAN_MASK: int = 1 | 8
const WORLD_MASK: int = 1
const GAME_PHASE_PLAYER_DEAD := 3
const GAME_PHASE_COMPLETED := 4
const GAME_PHASE_RESTARTING := 5

@export var input_enabled: bool = true
@export var require_aim_mode: bool = true
@export var muzzle_path: NodePath = ^"Muzzle"
@export_flags_3d_physics var hitscan_mask: int = HITSCAN_MASK
@export_flags_3d_physics var muzzle_clearance_mask: int = WORLD_MASK

var definition: WeaponDefinition
var state: WeaponState = WeaponState.HOLSTERED
var magazine: int = 0
var control_enabled: bool = true

var _state_time_remaining: float = 0.0
var _aim_provider: Node
var _ammo_source: Object
var _combat_owner: Node
var _shot_sequence: int = 0
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	_connect_game_state()


func _process(delta: float) -> void:
	advance_runtime(delta)
	if (
		definition != null
		and definition.automatic
		and input_enabled
		and Input.is_action_pressed(&"fire")
	):
		request_fire()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not control_enabled:
		return
	if event.is_action_pressed(&"fire"):
		request_fire()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"reload"):
		request_reload()
		get_viewport().set_input_as_handled()


func set_aim_provider(provider: Node) -> void:
	_aim_provider = provider
	_sync_aim_equipment_gate()


func set_ammo_source(source: Object) -> void:
	_ammo_source = source
	refresh_ammo_state()


func set_combat_owner(owner_node: Node) -> void:
	_combat_owner = owner_node


func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled
	if not control_enabled and state == WeaponState.RELOADING:
		_cancel_reload(&"CONTROL_DISABLED")


func request_equip(new_definition: WeaponDefinition, initial_magazine: int = -1) -> bool:
	if new_definition == null or not new_definition.is_valid_definition():
		return false
	if state == WeaponState.DISABLED:
		return false
	if state == WeaponState.RELOADING:
		_cancel_reload(&"EQUIPMENT_CHANGED")
	var definition_changed := definition != new_definition
	definition = new_definition
	if initial_magazine >= 0:
		magazine = clampi(initial_magazine, 0, definition.magazine_capacity)
	elif definition_changed:
		magazine = 0
	else:
		magazine = mini(magazine, definition.magazine_capacity)
	_set_state(WeaponState.EQUIPPING, definition.equip_duration)
	_sync_aim_equipment_gate()
	equipped_changed.emit(definition, true)
	refresh_ammo_state()
	if definition.equip_duration <= 0.0:
		_complete_timed_state()
	return true


func request_unequip() -> bool:
	if state == WeaponState.DISABLED:
		return false
	if state == WeaponState.HOLSTERED:
		return true
	if state == WeaponState.RELOADING:
		_cancel_reload(&"EQUIPMENT_CHANGED")
	_set_state(WeaponState.HOLSTERED)
	_sync_aim_equipment_gate()
	equipped_changed.emit(definition, false)
	return true


func set_disabled(disabled: bool) -> void:
	if disabled:
		if state == WeaponState.RELOADING:
			_cancel_reload(&"WEAPON_DISABLED")
		_set_state(WeaponState.DISABLED)
	else:
		_set_state(WeaponState.HOLSTERED)
	_sync_aim_equipment_gate()


func request_fire() -> bool:
	if not _can_accept_combat_input() or state != WeaponState.READY:
		return false
	if require_aim_mode and not _is_aim_mode_active():
		return false
	if magazine <= 0:
		_set_state(WeaponState.FIRING_COOLDOWN, definition.fire_interval)
		_emit_dry_fire(&"MAGAZINE_EMPTY")
		return false
	var aim_ray := _get_aim_ray()
	if aim_ray.is_empty():
		_set_state(WeaponState.FIRING_COOLDOWN, definition.fire_interval)
		_emit_dry_fire(&"AIM_RAY_UNAVAILABLE")
		return false
	magazine -= 1
	_shot_sequence += 1
	_set_state(WeaponState.FIRING_COOLDOWN, definition.fire_interval)
	_resolve_shot(aim_ray)
	refresh_ammo_state()
	if definition.fire_interval <= 0.0:
		_complete_timed_state()
	return true


func request_reload() -> bool:
	if not _can_accept_combat_input() or state != WeaponState.READY or definition == null:
		return false
	if magazine >= definition.magazine_capacity:
		return false
	if _available_reserve() <= 0:
		return false
	_set_state(WeaponState.RELOADING, definition.reload_duration)
	reload_started.emit(definition.reload_duration)
	feedback_requested.emit(definition.reload_feedback_id, {
		&"weapon_id": definition.weapon_id,
		&"duration": definition.reload_duration,
	})
	if definition.reload_duration <= 0.0:
		_complete_timed_state()
	return true


func advance_runtime(delta: float) -> void:
	if delta <= 0.0 or state not in [
		WeaponState.EQUIPPING,
		WeaponState.FIRING_COOLDOWN,
		WeaponState.RELOADING,
	]:
		return
	_state_time_remaining = maxf(_state_time_remaining - delta, 0.0)
	if _state_time_remaining <= 0.0:
		_complete_timed_state()


func get_runtime_snapshot() -> Dictionary:
	return {
		&"weapon_id": definition.weapon_id if definition != null else &"",
		&"magazine": magazine,
		&"equipped": state not in [WeaponState.HOLSTERED, WeaponState.DISABLED],
	}


func restore_runtime(snapshot: Dictionary) -> bool:
	if definition == null:
		return false
	var snapshot_weapon: StringName = snapshot.get(&"weapon_id", &"")
	if snapshot_weapon != definition.weapon_id:
		return false
	if state == WeaponState.RELOADING:
		_cancel_reload(&"CHECKPOINT_RESTORE")
	magazine = clampi(int(snapshot.get(&"magazine", 0)), 0, definition.magazine_capacity)
	_set_state(
		WeaponState.READY if bool(snapshot.get(&"equipped", false)) else WeaponState.HOLSTERED
	)
	_sync_aim_equipment_gate()
	refresh_ammo_state()
	return true


func refresh_ammo_state() -> void:
	ammo_state_changed.emit(magazine, _available_reserve())


func _complete_timed_state() -> void:
	match state:
		WeaponState.EQUIPPING, WeaponState.FIRING_COOLDOWN:
			_set_state(WeaponState.READY)
		WeaponState.RELOADING:
			_complete_reload()


func _complete_reload() -> void:
	var requested := definition.magazine_capacity - magazine
	var loaded := _take_reserve(requested)
	magazine += loaded
	_set_state(WeaponState.READY)
	reload_completed.emit(loaded)
	refresh_ammo_state()


func _cancel_reload(reason: StringName) -> void:
	if state != WeaponState.RELOADING:
		return
	reload_cancelled.emit(reason)
	_set_state(WeaponState.READY)


func _set_state(new_state: WeaponState, duration: float = 0.0) -> void:
	var previous := state
	state = new_state
	_state_time_remaining = maxf(duration, 0.0)
	if previous != state:
		state_changed.emit(previous, state)
	var placeholder_visual := get_node_or_null("PlaceholderPistol") as Node3D
	if placeholder_visual != null:
		placeholder_visual.visible = state not in [WeaponState.HOLSTERED, WeaponState.DISABLED]


func _resolve_shot(aim_ray: Dictionary) -> void:
	var origin: Vector3 = aim_ray.origin
	var direction := _direction_with_spread(aim_ray.direction)
	var end := origin + direction * definition.maximum_range
	var hit := _query_muzzle_clearance(origin, direction)
	if hit.is_empty():
		hit = _query_hitscan(origin, end, hitscan_mask)
	var hit_position: Vector3 = hit.get(&"position", end)
	var hit_normal: Vector3 = hit.get(&"normal", Vector3.ZERO)
	var collider: Object = hit.get(&"collider", null)
	var context := HitContext3D.new(
		_combat_owner if _combat_owner != null else self,
		definition.weapon_id,
		_shot_sequence,
		hit_position,
		hit_normal,
		direction,
		definition.damage,
		definition.damage_tags,
		collider
	)
	shot_fired.emit(context)
	feedback_requested.emit(definition.fire_feedback_id, {
		&"weapon_id": definition.weapon_id,
		&"origin": origin,
		&"direction": direction,
		&"camera_impulse_position": definition.camera_impulse_position,
		&"camera_impulse_rotation_degrees": definition.camera_impulse_rotation_degrees,
		&"camera_impulse_duration": definition.camera_impulse_duration,
	})
	_emit_gunshot_noise(origin)
	if hit.is_empty():
		return
	impact_resolved.emit(context, collider)
	feedback_requested.emit(definition.impact_feedback_id, {
		&"weapon_id": definition.weapon_id,
		&"position": hit_position,
		&"normal": hit_normal,
		&"collider": collider,
	})
	var receiver := _find_damage_receiver(collider)
	if receiver != null:
		receiver.call(&"receive_damage", definition.damage, context)
		damage_submitted.emit(receiver, definition.damage, context)


func _get_aim_ray() -> Dictionary:
	if _aim_provider == null or not is_instance_valid(_aim_provider):
		return {}
	if not _aim_provider.has_method(&"get_aim_ray"):
		return {}
	var ray: Dictionary = _aim_provider.call(&"get_aim_ray", definition.maximum_range)
	if not ray.has(&"origin") or not ray.has(&"direction"):
		return {}
	var direction: Vector3 = ray.direction
	if direction.is_zero_approx():
		return {}
	direction = direction.normalized()
	return {
		&"origin": ray.origin,
		&"direction": direction,
		&"end": ray.origin + direction * definition.maximum_range,
	}


func _direction_with_spread(direction: Vector3) -> Vector3:
	if definition.spread_degrees <= 0.0:
		return direction.normalized()
	var forward := direction.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	if right.is_zero_approx():
		right = Vector3.RIGHT
	var up := right.cross(forward).normalized()
	var radius := tan(deg_to_rad(definition.spread_degrees)) * sqrt(_random.randf())
	var angle := _random.randf_range(0.0, TAU)
	return (forward + right * cos(angle) * radius + up * sin(angle) * radius).normalized()


func _query_muzzle_clearance(aim_origin: Vector3, aim_direction: Vector3) -> Dictionary:
	if muzzle_clearance_mask == 0:
		return {}
	var muzzle := get_node_or_null(muzzle_path) as Node3D
	if muzzle == null or muzzle.global_position.distance_squared_to(aim_origin) <= 0.000001:
		return {}
	var muzzle_distance := aim_origin.distance_to(muzzle.global_position)
	return _query_hitscan(
		aim_origin,
		aim_origin + aim_direction.normalized() * muzzle_distance,
		muzzle_clearance_mask
	)


func _query_hitscan(origin: Vector3, end: Vector3, collision_mask: int) -> Dictionary:
	if not is_inside_tree() or collision_mask == 0:
		return {}
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.exclude = _owner_collision_rids()
	return get_world_3d().direct_space_state.intersect_ray(query)


func _owner_collision_rids() -> Array[RID]:
	var excluded: Array[RID] = []
	if _combat_owner == null or not is_instance_valid(_combat_owner):
		return excluded
	var candidates: Array[Node] = [_combat_owner]
	candidates.append_array(_combat_owner.find_children("*", "CollisionObject3D", true, false))
	for candidate in candidates:
		if candidate is CollisionObject3D:
			excluded.append((candidate as CollisionObject3D).get_rid())
	return excluded


func _find_damage_receiver(collider: Object) -> Object:
	var current := collider as Node
	while current != null:
		if current.has_method(&"receive_damage"):
			return current
		current = current.get_parent()
	return null


func _emit_dry_fire(reason: StringName) -> void:
	dry_fired.emit(reason)
	feedback_requested.emit(definition.dry_fire_feedback_id, {
		&"weapon_id": definition.weapon_id,
		&"reason": reason,
	})


func _emit_gunshot_noise(origin: Vector3) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus == null or definition.gunshot_loudness <= 0.0:
		return
	var source := _combat_owner as Node3D
	if source == null:
		source = self
	event_bus.call(&"emit_noise", NoiseEvent3D.new(
		source,
		origin,
		definition.gunshot_loudness,
		&"gunshot"
	))


func _available_reserve() -> int:
	if (
		_ammo_source == null
		or not is_instance_valid(_ammo_source)
		or not _ammo_source.has_method(&"get_ammo_count")
		or definition == null
	):
		return 0
	return maxi(int(_ammo_source.call(&"get_ammo_count", definition.ammo_type)), 0)


func _take_reserve(requested: int) -> int:
	if (
		requested <= 0
		or _ammo_source == null
		or not is_instance_valid(_ammo_source)
		or not _ammo_source.has_method(&"take_ammo")
	):
		return 0
	return clampi(
		int(_ammo_source.call(&"take_ammo", definition.ammo_type, requested)),
		0,
		requested
	)


func _can_accept_combat_input() -> bool:
	return (
		control_enabled
		and state != WeaponState.DISABLED
		and definition != null
		and is_inside_tree()
		and not get_tree().paused
	)


func _is_aim_mode_active() -> bool:
	if _aim_provider == null or not is_instance_valid(_aim_provider):
		return false
	if not _aim_provider.has_method(&"get_camera_mode"):
		return true
	return int(_aim_provider.call(&"get_camera_mode")) == GameplayCameraRig.CameraMode.AIM


func _sync_aim_equipment_gate() -> void:
	if _aim_provider != null and is_instance_valid(_aim_provider) and _aim_provider.has_method(&"set_weapon_equipped"):
		_aim_provider.call(
			&"set_weapon_equipped",
			state not in [WeaponState.HOLSTERED, WeaponState.DISABLED] and definition != null
		)


func _connect_game_state() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	if game_state.has_signal(&"pause_changed"):
		game_state.pause_changed.connect(_on_pause_changed)
	if game_state.has_signal(&"phase_changed"):
		game_state.phase_changed.connect(_on_phase_changed)


func _on_pause_changed(is_paused: bool) -> void:
	if is_paused and state == WeaponState.RELOADING:
		_cancel_reload(&"PAUSED")


func _on_phase_changed(_previous: int, current: int) -> void:
	if current in [GAME_PHASE_PLAYER_DEAD, GAME_PHASE_COMPLETED, GAME_PHASE_RESTARTING]:
		set_disabled(true)

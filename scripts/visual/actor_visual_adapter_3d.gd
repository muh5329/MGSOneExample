class_name ActorVisualAdapter3D
extends Node3D

signal configuration_reported(report: Dictionary)
signal semantic_state_changed(snapshot: Dictionary)
signal action_triggered(action: StringName, duration: float)
signal model_replaced(model_scene: PackedScene)

enum ActorKind {
	PLAYER,
	GUARD,
}

const ALERT_COLORS: Dictionary = {
	&"NORMAL": Color(0.2, 0.9, 0.55, 1.0),
	&"SUSPICIOUS": Color(1.0, 0.78, 0.18, 1.0),
	&"ALERT": Color(1.0, 0.12, 0.08, 1.0),
	&"EVASION": Color(1.0, 0.42, 0.08, 1.0),
	&"SEARCH": Color(1.0, 0.66, 0.16, 1.0),
	&"DEAD": Color(0.18, 0.18, 0.2, 1.0),
}

const DEFAULT_SEMANTICS: Dictionary = {
	&"planar_velocity": Vector2.ZERO,
	&"speed_ratio": 0.0,
	&"grounded": true,
	&"crouched": false,
	&"aiming": false,
	&"weapon_equipped": false,
	&"reloading": false,
	&"dead": false,
	&"alert_state": &"NORMAL",
}

@export var actor_kind: ActorKind = ActorKind.PLAYER
@export var procedural_motion_enabled: bool = true
@export var model_root_path: NodePath = ^"ModelRoot"
@export var body_path: NodePath = ^"ModelRoot/ModelPayload/Body"
@export var head_path: NodePath = ^"ModelRoot/ModelPayload/Head"
@export var left_leg_path: NodePath = ^"ModelRoot/ModelPayload/LeftLeg"
@export var right_leg_path: NodePath = ^"ModelRoot/ModelPayload/RightLeg"
@export var facing_marker_path: NodePath = ^"ModelRoot/ModelPayload/FacingMarker"
@export var alert_indicator_path: NodePath = ^"ModelRoot/ModelPayload/AlertIndicator"
@export var damage_flash_path: NodePath = ^"ModelRoot/ModelPayload/DamageFlash"
@export var weapon_visual_path: NodePath = ^"Sockets/WeaponSocket/WeaponProxy"
@export var animation_player_path: NodePath
@export var animation_tree_path: NodePath
@export var required_clips: PackedStringArray = PackedStringArray()
@export var optional_action_clips: Dictionary = {
	&"fire": &"fire",
	&"reload": &"reload",
	&"damaged": &"damage",
	&"death": &"death",
}
@export var animation_tree_parameter_map: Dictionary = {
	&"planar_velocity": ^"parameters/semantic/planar_velocity",
	&"speed_ratio": ^"parameters/semantic/speed_ratio",
	&"grounded": ^"parameters/semantic/grounded",
	&"crouched": ^"parameters/semantic/crouched",
	&"aiming": ^"parameters/semantic/aiming",
	&"reloading": ^"parameters/semantic/reloading",
	&"dead": ^"parameters/semantic/dead",
	&"alert_state": ^"parameters/semantic/alert_state",
}
@export var weapon_socket_path: NodePath = ^"Sockets/WeaponSocket"
@export var muzzle_socket_path: NodePath = ^"Sockets/WeaponSocket/MuzzleSocket"
@export var head_socket_path: NodePath = ^"Sockets/HeadSocket"
@export var eyes_socket_path: NodePath = ^"Sockets/EyesSocket"
@export var effect_origin_path: NodePath = ^"Sockets/EffectOrigin"

var _semantic_state: Dictionary = DEFAULT_SEMANTICS.duplicate(true)
var _action_remaining: Dictionary = {
	&"fire": 0.0,
	&"reload": 0.0,
	&"damaged": 0.0,
	&"death": 0.0,
}
var _actor: Node3D
var _health: HealthComponent
var _weapon: WeaponController
var _model_root: Node3D
var _body: Node3D
var _head: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _facing_marker: Node3D
var _alert_indicator: GeometryInstance3D
var _damage_flash: Node3D
var _weapon_visual: Node3D
var _animation_player: AnimationPlayer
var _animation_tree: AnimationTree
var _base_transforms: Dictionary = {}
var _animation_tree_properties: Dictionary = {}
var _elapsed: float = 0.0
var _last_configuration_report: Dictionary = {}


func _ready() -> void:
	_cache_nodes()
	validate_configuration(true)
	call_deferred(&"_bind_default_sources")


func _process(delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta):
		return
	_elapsed += delta
	for action: StringName in _action_remaining.keys():
		_action_remaining[action] = maxf(float(_action_remaining[action]) - delta, 0.0)
	if procedural_motion_enabled:
		_apply_procedural_pose()


func bind_actor(actor: Node3D) -> bool:
	if actor == null:
		return false
	_actor = actor
	if actor is PlayerController:
		actor_kind = ActorKind.PLAYER
		_connect_signal(actor, &"animation_parameters_updated", _on_player_animation_parameters)
		_connect_signal(actor, &"aim_state_changed", _on_player_aim_state_changed)
		set_semantic_state({
			&"crouched": int(actor.get(&"stance")) == PlayerController.Stance.CROUCHED,
			&"aiming": int(actor.call(&"get_control_locks")) & PlayerController.ControlLock.AIM != 0,
		})
	elif actor is GuardActor:
		actor_kind = ActorKind.GUARD
		_connect_signal(actor, &"animation_parameters_updated", _on_guard_animation_parameters)
		_connect_signal(actor, &"state_changed", _on_guard_state_changed)
		_connect_signal(actor, &"combat_requested", _on_guard_combat_requested)
		set_semantic_state({
			&"weapon_equipped": true,
			&"alert_state": _guard_alert_state(int(actor.get(&"state"))),
			&"dead": int(actor.get(&"state")) == GuardActor.GuardState.DEAD,
		})
	_health = actor.get_node_or_null("Health") as HealthComponent
	if _health != null:
		_connect_signal(_health, &"damaged", _on_damaged)
		_connect_signal(_health, &"died", _on_died)
		_connect_signal(_health, &"revived", _on_revived)
	_weapon = actor.get_node_or_null("WeaponController") as WeaponController
	if _weapon != null:
		_connect_signal(_weapon, &"state_changed", _on_weapon_state_changed)
		_connect_signal(_weapon, &"equipped_changed", _on_weapon_equipped_changed)
		_connect_signal(_weapon, &"shot_fired", _on_shot_fired)
		_connect_signal(_weapon, &"reload_started", _on_reload_started)
		_connect_signal(_weapon, &"reload_completed", _on_reload_finished)
		_connect_signal(_weapon, &"reload_cancelled", _on_reload_cancelled)
		_weapon.set_muzzle_provider(get_socket(&"muzzle"))
		set_semantic_state({
			&"weapon_equipped": _weapon.definition != null and _weapon.state not in [
				WeaponController.WeaponState.HOLSTERED,
				WeaponController.WeaponState.DISABLED,
			],
			&"reloading": _weapon.state == WeaponController.WeaponState.RELOADING,
		})
	return true


func set_semantic_state(values: Dictionary) -> void:
	var changed := false
	for key: Variant in values:
		if not _semantic_state.has(key):
			continue
		var value: Variant = values[key]
		if _semantic_state[key] == value:
			continue
		_semantic_state[key] = value
		changed = true
	if not changed:
		return
	_publish_animation_tree_parameters()
	_update_indicator_color()
	semantic_state_changed.emit(get_semantic_snapshot())


func get_semantic_snapshot() -> Dictionary:
	return _semantic_state.duplicate(true)


func trigger_action(action: StringName, duration: float = 0.15) -> bool:
	if not _action_remaining.has(action) or not is_finite(duration) or duration < 0.0:
		return false
	_action_remaining[action] = duration
	_try_play_action_clip(action)
	action_triggered.emit(action, duration)
	return true


func get_socket(socket_id: StringName) -> Marker3D:
	var path := NodePath()
	match socket_id:
		&"weapon":
			path = weapon_socket_path
		&"muzzle":
			path = muzzle_socket_path
		&"head":
			path = head_socket_path
		&"eyes":
			path = eyes_socket_path
		&"effect_origin":
			path = effect_origin_path
		_:
			return null
	return get_node_or_null(path) as Marker3D


func replace_model(model_scene: PackedScene) -> bool:
	if model_scene == null:
		return false
	_model_root = get_node_or_null(model_root_path) as Node3D
	if _model_root == null:
		return false
	var replacement := model_scene.instantiate() as Node3D
	if replacement == null:
		return false
	var previous := _model_root.get_node_or_null("ModelPayload")
	if previous != null:
		_model_root.remove_child(previous)
	replacement.name = &"ModelPayload"
	_model_root.add_child(replacement)
	_cache_nodes()
	var report := validate_configuration(true)
	if not bool(report.valid):
		_model_root.remove_child(replacement)
		replacement.free()
		if previous != null:
			previous.name = &"ModelPayload"
			_model_root.add_child(previous)
		_cache_nodes()
		return false
	if previous != null:
		previous.queue_free()
	model_replaced.emit(model_scene)
	return true


func validate_configuration(report_errors: bool = false) -> Dictionary:
	var errors := PackedStringArray()
	var warnings := PackedStringArray()
	if get_node_or_null(model_root_path) == null:
		errors.append("MODEL_ROOT_MISSING:%s" % model_root_path)
	if get_node_or_null(body_path) == null:
		errors.append("REQUIRED_VISUAL_MISSING:body:%s" % body_path)
	for socket_id: StringName in [&"weapon", &"muzzle", &"head", &"eyes", &"effect_origin"]:
		if get_socket(socket_id) == null:
			errors.append("REQUIRED_SOCKET_MISSING:%s" % socket_id)
	if not required_clips.is_empty():
		if _animation_player == null:
			errors.append("ANIMATION_PLAYER_MISSING_FOR_REQUIRED_CLIPS")
		else:
			for clip: String in required_clips:
				if not _animation_player.has_animation(StringName(clip)):
					errors.append("REQUIRED_CLIP_MISSING:%s" % clip)
	if _animation_player != null:
		for action: Variant in optional_action_clips:
			var clip := StringName(optional_action_clips[action])
			if not clip.is_empty() and not _animation_player.has_animation(clip):
				warnings.append("OPTIONAL_CLIP_MISSING:%s:%s" % [action, clip])
	elif not optional_action_clips.is_empty():
		warnings.append("OPTIONAL_ANIMATION_PLAYER_MISSING_USING_PROCEDURAL_FALLBACK")
	_last_configuration_report = {
		&"valid": errors.is_empty(),
		&"errors": errors,
		&"warnings": warnings,
		&"model_path": String(get_path()) if is_inside_tree() else String(name),
	}
	if report_errors and not errors.is_empty():
		push_error("ActorVisualAdapter3D configuration invalid: %s" % "; ".join(errors))
	configuration_reported.emit(_last_configuration_report.duplicate(true))
	return _last_configuration_report.duplicate(true)


func get_configuration_report() -> Dictionary:
	return _last_configuration_report.duplicate(true)


func _bind_default_sources() -> void:
	if get_parent() is Node3D:
		bind_actor(get_parent() as Node3D)


func _cache_nodes() -> void:
	_model_root = get_node_or_null(model_root_path) as Node3D
	_body = get_node_or_null(body_path) as Node3D
	_head = get_node_or_null(head_path) as Node3D
	_left_leg = get_node_or_null(left_leg_path) as Node3D
	_right_leg = get_node_or_null(right_leg_path) as Node3D
	_facing_marker = get_node_or_null(facing_marker_path) as Node3D
	_alert_indicator = get_node_or_null(alert_indicator_path) as GeometryInstance3D
	_damage_flash = get_node_or_null(damage_flash_path) as Node3D
	_weapon_visual = get_node_or_null(weapon_visual_path) as Node3D
	_animation_player = get_node_or_null(animation_player_path) as AnimationPlayer
	_animation_tree = get_node_or_null(animation_tree_path) as AnimationTree
	_base_transforms.clear()
	for node: Node3D in [
		_model_root, _body, _head, _left_leg, _right_leg, _facing_marker,
		_damage_flash, _weapon_visual, get_socket(&"weapon"), get_socket(&"head"),
		get_socket(&"eyes"), get_socket(&"effect_origin"),
	]:
		if node != null:
			_base_transforms[node] = node.transform
	_animation_tree_properties.clear()
	if _animation_tree != null:
		for property: Dictionary in _animation_tree.get_property_list():
			_animation_tree_properties[StringName(property.name)] = true
	if _alert_indicator != null and _alert_indicator.material_override != null:
		_alert_indicator.material_override = _alert_indicator.material_override.duplicate()
	_update_indicator_color()


func _apply_procedural_pose() -> void:
	for node: Node3D in _base_transforms:
		if is_instance_valid(node):
			node.transform = _base_transforms[node]
	var dead := bool(_semantic_state.dead)
	var crouched := bool(_semantic_state.crouched)
	var aiming := bool(_semantic_state.aiming)
	var speed := clampf(float(_semantic_state.speed_ratio), 0.0, 1.0)
	var walk_phase := _elapsed * lerpf(3.0, 9.0, speed)
	var stride := sin(walk_phase) * speed * (0.36 if not crouched else 0.22)
	var bob := absf(sin(walk_phase)) * speed * 0.035
	var crouch_drop := 0.38 if crouched else 0.0
	if _model_root != null:
		if dead:
			_model_root.rotation.z = -PI * 0.5
			_model_root.position += Vector3(0.0, 0.42, 0.0)
		elif bool(_semantic_state.reloading):
			_model_root.rotation.y += sin(_elapsed * 8.0) * 0.08
	if _body != null and not dead:
		_body.position.y += bob - crouch_drop * 0.42
		_body.rotation.x += -0.14 if aiming else 0.0
		if crouched:
			_body.scale.y *= 0.78
	if _head != null and not dead:
		_head.position.y -= crouch_drop
		_head.rotation.y += sin(_elapsed * 1.8) * (0.025 if speed < 0.05 else 0.0)
	if _left_leg != null and not dead:
		_left_leg.position.y -= crouch_drop * 0.72
		_left_leg.rotation.x += stride
	if _right_leg != null and not dead:
		_right_leg.position.y -= crouch_drop * 0.72
		_right_leg.rotation.x -= stride
	for socket_id: StringName in [&"weapon", &"head", &"eyes", &"effect_origin"]:
		var socket := get_socket(socket_id)
		if socket != null and not dead:
			socket.position.y -= crouch_drop
	if _weapon_visual != null:
		_weapon_visual.visible = bool(_semantic_state.weapon_equipped) and not dead
		if _weapon_visual.visible:
			_weapon_visual.rotation.x += -0.28 if aiming else 0.0
			if float(_action_remaining.fire) > 0.0:
				_weapon_visual.position.z += 0.08
				_weapon_visual.rotation.x += 0.22
			elif bool(_semantic_state.reloading):
				_weapon_visual.rotation.z += sin(_elapsed * 10.0) * 0.35
	if _facing_marker != null:
		_facing_marker.visible = not dead
		_facing_marker.scale *= 1.15 if aiming else 1.0
	if _damage_flash != null:
		_damage_flash.visible = float(_action_remaining.damaged) > 0.0 and not dead
	if _alert_indicator != null:
		_alert_indicator.visible = StringName(_semantic_state.alert_state) != &"NORMAL" and not dead
		_alert_indicator.rotation.y = _elapsed * 2.8


func _publish_animation_tree_parameters() -> void:
	if _animation_tree == null:
		return
	for semantic: Variant in animation_tree_parameter_map:
		if not _semantic_state.has(semantic):
			continue
		var parameter := StringName(animation_tree_parameter_map[semantic])
		if _animation_tree_properties.has(parameter):
			_animation_tree.set(parameter, _semantic_state[semantic])


func _try_play_action_clip(action: StringName) -> void:
	if _animation_player == null:
		return
	var clip := StringName(optional_action_clips.get(action, &""))
	if not clip.is_empty() and _animation_player.has_animation(clip):
		_animation_player.play(clip)


func _update_indicator_color() -> void:
	if _alert_indicator == null:
		return
	var material := _alert_indicator.material_override as StandardMaterial3D
	if material == null:
		return
	var state := StringName(_semantic_state.get(&"alert_state", &"NORMAL"))
	var color: Color = ALERT_COLORS.get(state, ALERT_COLORS[&"NORMAL"])
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 0.45


func _connect_signal(source: Object, signal_name: StringName, callable: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _on_player_animation_parameters(
		local_planar_velocity: Vector2,
		speed_ratio: float,
		grounded: bool,
		stance: int
) -> void:
	set_semantic_state({
		&"planar_velocity": local_planar_velocity,
		&"speed_ratio": speed_ratio,
		&"grounded": grounded,
		&"crouched": stance == PlayerController.Stance.CROUCHED,
	})


func _on_guard_animation_parameters(local_velocity: Vector2, speed_ratio: float, guard_state: int) -> void:
	set_semantic_state({
		&"planar_velocity": local_velocity,
		&"speed_ratio": speed_ratio,
		&"grounded": true,
		&"alert_state": _guard_alert_state(guard_state),
		&"dead": guard_state == GuardActor.GuardState.DEAD,
	})


func _on_player_aim_state_changed(active: bool) -> void:
	set_semantic_state({&"aiming": active})


func _on_guard_state_changed(_guard_id: StringName, _previous: int, current: int) -> void:
	set_semantic_state({
		&"alert_state": _guard_alert_state(current),
		&"aiming": current == GuardActor.GuardState.ATTACK,
		&"dead": current == GuardActor.GuardState.DEAD,
	})


func _on_guard_combat_requested(
		_guard_id: StringName,
		_target: Node3D,
		_context: HitContext3D
) -> void:
	trigger_action(&"fire", 0.14)


func _on_weapon_state_changed(_previous: int, current: int) -> void:
	set_semantic_state({
		&"reloading": current == WeaponController.WeaponState.RELOADING,
		&"weapon_equipped": _weapon != null and _weapon.definition != null and current not in [
			WeaponController.WeaponState.HOLSTERED,
			WeaponController.WeaponState.DISABLED,
		],
	})


func _on_weapon_equipped_changed(_definition: WeaponDefinition, equipped: bool) -> void:
	set_semantic_state({&"weapon_equipped": equipped})


func _on_shot_fired(_context: HitContext3D) -> void:
	trigger_action(&"fire", 0.14)


func _on_reload_started(duration: float) -> void:
	set_semantic_state({&"reloading": true})
	trigger_action(&"reload", duration)


func _on_reload_finished(_rounds_loaded: int) -> void:
	set_semantic_state({&"reloading": false})


func _on_reload_cancelled(_reason: StringName) -> void:
	set_semantic_state({&"reloading": false})


func _on_damaged(_applied: float, _context: HitContext3D) -> void:
	trigger_action(&"damaged", 0.22)


func _on_died(_context: HitContext3D) -> void:
	set_semantic_state({&"dead": true, &"alert_state": &"DEAD", &"aiming": false})
	trigger_action(&"death", 1.0)


func _on_revived(_current: float, _maximum: float) -> void:
	set_semantic_state({
		&"dead": false,
		&"alert_state": &"NORMAL",
	})


func _guard_alert_state(guard_state: int) -> StringName:
	match guard_state:
		GuardActor.GuardState.SUSPICIOUS, GuardActor.GuardState.INVESTIGATE:
			return &"SUSPICIOUS"
		GuardActor.GuardState.ALERT_CHASE, GuardActor.GuardState.ATTACK:
			return &"ALERT"
		GuardActor.GuardState.SEARCH:
			return &"SEARCH"
		GuardActor.GuardState.DEAD:
			return &"DEAD"
		_:
			return &"NORMAL"

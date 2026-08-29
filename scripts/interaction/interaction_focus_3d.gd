class_name InteractionFocus3D
extends Node

signal focus_changed(previous: Interactable3D, current: Interactable3D)
signal prompt_changed(prompt: String, reason: StringName, available: bool)
signal hold_progressed(target: Interactable3D, normalized_progress: float)
signal interaction_attempted(target: Interactable3D, accepted: bool)

const DEFAULT_QUERY_MASK := (1 << 4) | (1 << 6)

@export var actor_path: NodePath
@export var origin_path: NodePath
@export var camera_rig_path: NodePath
@export_range(0.25, 5.0, 0.05, "suffix:m") var maximum_distance: float = 2.0
@export_flags_3d_physics var query_mask: int = DEFAULT_QUERY_MASK
@export var input_enabled: bool = true

var focused_target: Interactable3D
var _actor: Node3D
var _origin: Node3D
var _camera_rig: GameplayCameraRig
var _hold_target: Interactable3D
var _hold_elapsed: float = 0.0


func _ready() -> void:
	if not actor_path.is_empty():
		_actor = get_node_or_null(actor_path) as Node3D
	if not origin_path.is_empty():
		_origin = get_node_or_null(origin_path) as Node3D
	if not camera_rig_path.is_empty():
		_camera_rig = get_node_or_null(camera_rig_path) as GameplayCameraRig


func _physics_process(delta: float) -> void:
	if _actor == null or not is_instance_valid(_actor):
		_set_focus(null)
		_cancel_hold()
		return
	_set_focus(_select_focus(_query_candidates()))
	_update_hold(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or focused_target == null or get_tree().paused:
		return
	if event.is_action_pressed(&"interact"):
		if _camera_rig != null and _camera_rig.mode == GameplayCameraRig.CameraMode.AIM:
			return
		if focused_target.hold_duration > 0.0:
			_begin_hold(focused_target)
		else:
			_attempt_interaction(focused_target)
		get_viewport().set_input_as_handled()
	elif event.is_action_released(&"interact") and _hold_target != null:
		_cancel_hold()
		get_viewport().set_input_as_handled()


func set_actor(actor: Node3D, origin: Node3D = null) -> void:
	_actor = actor
	_origin = origin


func set_camera_rig(camera_rig: GameplayCameraRig) -> void:
	_camera_rig = camera_rig


func refresh_focus() -> void:
	_set_focus(_select_focus(_query_candidates()))


func get_prompt_snapshot() -> Dictionary:
	if focused_target == null:
		return {
			&"target": null,
			&"prompt": "",
			&"available": false,
			&"reason": &"",
		}
	var available := focused_target.is_available(_actor)
	return {
		&"target": focused_target,
		&"prompt": focused_target.get_prompt(_actor),
		&"available": available,
		&"reason": &"" if available else focused_target.get_unavailable_reason(_actor),
	}


func _query_candidates() -> Array[Interactable3D]:
	var candidates: Array[Interactable3D] = []
	if not is_inside_tree():
		return candidates
	var sphere := SphereShape3D.new()
	sphere.radius = maximum_distance
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, _query_origin())
	query.collision_mask = query_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in _actor.get_world_3d().direct_space_state.intersect_shape(query, 32):
		var collider := hit.get(&"collider") as Node
		var target := _interactable_from(collider)
		if target != null and target not in candidates:
			candidates.append(target)
	return candidates


func _select_focus(candidates: Array[Interactable3D]) -> Interactable3D:
	var selected: Interactable3D
	for candidate in candidates:
		if not is_instance_valid(candidate):
			continue
		if _query_origin().distance_to(candidate.get_world_anchor()) > maximum_distance + 0.05:
			continue
		if selected == null or _candidate_precedes(candidate, selected):
			selected = candidate
	return selected


func _candidate_precedes(candidate: Interactable3D, incumbent: Interactable3D) -> bool:
	if candidate.get_interaction_priority() != incumbent.get_interaction_priority():
		return candidate.get_interaction_priority() > incumbent.get_interaction_priority()
	var candidate_distance := _query_origin().distance_squared_to(candidate.get_world_anchor())
	var incumbent_distance := _query_origin().distance_squared_to(incumbent.get_world_anchor())
	if not is_equal_approx(candidate_distance, incumbent_distance):
		return candidate_distance < incumbent_distance
	return String(candidate.interaction_id) < String(incumbent.interaction_id)


func _interactable_from(node: Node) -> Interactable3D:
	var cursor := node
	while cursor != null:
		if cursor is Interactable3D:
			return cursor as Interactable3D
		cursor = cursor.get_parent()
	return null


func _query_origin() -> Vector3:
	if _origin != null and is_instance_valid(_origin):
		return _origin.global_position
	return _actor.global_position if _actor != null else Vector3.ZERO


func _set_focus(next_target: Interactable3D) -> void:
	if next_target == focused_target:
		_emit_prompt()
		return
	var previous := focused_target
	focused_target = next_target
	if _hold_target != focused_target:
		_cancel_hold()
	focus_changed.emit(previous, focused_target)
	_emit_prompt()


func _emit_prompt() -> void:
	var snapshot := get_prompt_snapshot()
	prompt_changed.emit(snapshot.prompt, snapshot.reason, snapshot.available)


func _begin_hold(target: Interactable3D) -> void:
	if not target.is_available(_actor):
		_attempt_interaction(target)
		return
	_hold_target = target
	_hold_elapsed = 0.0
	_set_interaction_lock(true)
	hold_progressed.emit(_hold_target, 0.0)


func _update_hold(delta: float) -> void:
	if _hold_target == null:
		return
	if not Input.is_action_pressed(&"interact") or focused_target != _hold_target:
		_cancel_hold()
		return
	_hold_elapsed += delta
	var progress := clampf(_hold_elapsed / maxf(_hold_target.hold_duration, 0.001), 0.0, 1.0)
	hold_progressed.emit(_hold_target, progress)
	if progress >= 1.0:
		var target := _hold_target
		_cancel_hold()
		_attempt_interaction(target)


func _cancel_hold() -> void:
	if _hold_target == null:
		return
	var target := _hold_target
	_hold_target = null
	_hold_elapsed = 0.0
	hold_progressed.emit(target, 0.0)
	_set_interaction_lock(false)


func _attempt_interaction(target: Interactable3D) -> void:
	var accepted := target.interact(_actor)
	interaction_attempted.emit(target, accepted)
	_emit_prompt()


func _set_interaction_lock(locked: bool) -> void:
	if _actor != null and _actor.has_method(&"set_control_lock"):
		_actor.call(&"set_control_lock", PlayerController.ControlLock.SCRIPTED, locked)
	if _camera_rig != null:
		_camera_rig.set_interaction_active(locked)

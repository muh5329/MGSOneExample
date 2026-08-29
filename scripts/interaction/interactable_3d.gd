class_name Interactable3D
extends Area3D

signal interacted(actor: Node)
signal interaction_rejected(actor: Node, reason: StringName)
signal availability_changed(is_enabled: bool, reason: StringName)

@export var interaction_id: StringName = &"UNNAMED_INTERACTION"
@export var prompt_text: String = "Interact"
@export var unavailable_reason: StringName = &"UNAVAILABLE"
@export var interaction_priority: int = 0
@export_range(0.0, 10.0, 0.05, "suffix:s") var hold_duration: float = 0.0
@export var one_shot: bool = false
@export var enabled: bool = true
@export var anchor_path: NodePath

var availability_query: Callable
var reason_query: Callable
var prompt_query: Callable
var _consumed: bool = false


func _ready() -> void:
	add_to_group(&"interactable")
	collision_mask = 0
	monitoring = false
	monitorable = true


func get_prompt(actor: Node = null) -> String:
	if prompt_query.is_valid():
		return String(prompt_query.call(actor))
	return prompt_text


func is_available(actor: Node = null) -> bool:
	if not enabled or _consumed:
		return false
	if availability_query.is_valid():
		return bool(availability_query.call(actor))
	return true


func get_unavailable_reason(actor: Node = null) -> StringName:
	if _consumed:
		return &"ALREADY_COLLECTED"
	if reason_query.is_valid():
		return StringName(reason_query.call(actor))
	return unavailable_reason


func get_interaction_priority() -> int:
	return interaction_priority


func get_world_anchor() -> Vector3:
	if not anchor_path.is_empty():
		var anchor := get_node_or_null(anchor_path) as Node3D
		if anchor != null:
			return anchor.global_position
	return global_position


func interact(actor: Node) -> bool:
	if not is_available(actor):
		interaction_rejected.emit(actor, get_unavailable_reason(actor))
		return false
	_perform_interaction(actor)
	interacted.emit(actor)
	if one_shot:
		set_consumed(true)
	return true


func set_enabled(next_enabled: bool, reason: StringName = &"UNAVAILABLE") -> void:
	enabled = next_enabled
	unavailable_reason = reason
	availability_changed.emit(enabled, unavailable_reason)


func set_consumed(consumed: bool) -> void:
	_consumed = consumed
	availability_changed.emit(not _consumed and enabled, get_unavailable_reason())


func is_consumed() -> bool:
	return _consumed


func _perform_interaction(_actor: Node) -> void:
	pass

class_name Door3D
extends Node3D

signal state_changed(door_id: StringName, is_open: bool, is_locked: bool)
signal access_denied(door_id: StringName, reason: StringName, actor: Node)

@export var door_id: StringName = &"UNNAMED_DOOR"
@export var access_level: StringName
@export var locked_reason: StringName = &"LOCKED"
@export var starts_open: bool = false
@export var starts_locked: bool = false
@export var close_when_interacted_open: bool = true

@onready var door_panel: MeshInstance3D = %DoorPanel
@onready var door_body: StaticBody3D = %DoorBody
@onready var door_collision: CollisionShape3D = %DoorCollision
@onready var interactable: Interactable3D = %Interactable
@onready var navigation_link: NavigationLink3D = %NavigationLink

var is_open: bool = false
var is_locked: bool = false
var _access_query: Callable


func _ready() -> void:
	add_to_group(&"doors")
	is_locked = starts_locked
	is_open = starts_open and not is_locked
	interactable.interaction_id = door_id
	interactable.interaction_priority = 20
	interactable.availability_query = _can_interact
	interactable.reason_query = func(_actor: Node) -> StringName: return locked_reason
	interactable.prompt_query = _prompt_for
	interactable.interacted.connect(_on_interacted)
	interactable.interaction_rejected.connect(_on_interaction_rejected)
	_apply_state(false)


func set_access_query(query: Callable) -> void:
	_access_query = query


func set_locked(locked: bool, reason: StringName = &"LOCKED") -> void:
	if locked and is_open:
		set_open(false)
	is_locked = locked
	locked_reason = reason
	_apply_state()


func set_open(opened: bool) -> bool:
	if opened and is_locked:
		return false
	is_open = opened
	_apply_state()
	return true


func toggle(actor: Node = null) -> bool:
	if is_open:
		if close_when_interacted_open:
			return set_open(false)
		return true
	if is_locked:
		if not _has_access(actor):
			access_denied.emit(door_id, locked_reason, actor)
			return false
		is_locked = false
	return set_open(true)


func _can_interact(actor: Node) -> bool:
	return not is_locked or _has_access(actor)


func _has_access(actor: Node) -> bool:
	if not is_locked:
		return true
	if _access_query.is_valid():
		return bool(_access_query.call(actor, access_level))
	if actor != null and actor.has_method(&"has_access_level"):
		return bool(actor.call(&"has_access_level", access_level))
	return false


func _prompt_for(actor: Node) -> String:
	if is_open:
		return "Close %s" % door_id
	if is_locked and _has_access(actor):
		return "Unlock %s" % door_id
	return "Open %s" % door_id


func _on_interacted(actor: Node) -> void:
	toggle(actor)


func _on_interaction_rejected(actor: Node, reason: StringName) -> void:
	access_denied.emit(door_id, reason, actor)


func _apply_state(emit_change: bool = true) -> void:
	if not is_node_ready():
		return
	door_panel.position.y = 3.4 if is_open else 1.5
	door_collision.set_deferred(&"disabled", is_open)
	door_body.collision_layer = 0 if is_open else ((1 << 0) | (1 << 5))
	navigation_link.enabled = is_open
	var material := StandardMaterial3D.new()
	material.roughness = 0.7
	if is_locked:
		material.albedo_color = Color(0.55, 0.12, 0.08, 1.0)
		material.emission_enabled = true
		material.emission = Color(0.12, 0.01, 0.0, 1.0)
	elif is_open:
		material.albedo_color = Color(0.12, 0.5, 0.3, 1.0)
	else:
		material.albedo_color = Color(0.2, 0.38, 0.42, 1.0)
	door_panel.material_override = material
	if emit_change:
		state_changed.emit(door_id, is_open, is_locked)

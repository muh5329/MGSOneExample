class_name MissionTrigger3D
extends Area3D

signal triggered(trigger_id: StringName, actor: Node3D)

enum TriggerKind {
	ROOM,
	CHECKPOINT,
	RECOVERY,
}

@export var trigger_id: StringName = &"UNNAMED_TRIGGER"
@export var trigger_kind: TriggerKind = TriggerKind.ROOM
@export var one_shot: bool = false

var _has_triggered: bool = false


func _ready() -> void:
	add_to_group(&"room_volumes" if trigger_kind == TriggerKind.ROOM else &"checkpoint_targets")
	collision_layer = 0
	collision_mask = 1 << 1
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if one_shot and _has_triggered:
		return
	if not body.is_in_group(&"player"):
		return
	_has_triggered = true
	triggered.emit(trigger_id, body)

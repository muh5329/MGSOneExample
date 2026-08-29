class_name MissionMarker3D
extends Interactable3D

signal mission_event(event_id: StringName, actor: Node, payload: Dictionary)

enum MarkerKind {
	PICKUP,
	OBJECTIVE,
	EXTRACTION,
}

@export var marker_kind: MarkerKind = MarkerKind.PICKUP
@export var event_id: StringName = &"UNNAMED_MISSION_EVENT"
@export var payload: Dictionary = {}


func _ready() -> void:
	super._ready()
	add_to_group(&"mission_markers")
	collision_layer = (1 << 6) if marker_kind == MarkerKind.PICKUP else (1 << 4)


func _perform_interaction(actor: Node) -> void:
	mission_event.emit(event_id, actor, payload.duplicate(true))

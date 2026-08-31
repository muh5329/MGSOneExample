class_name PresentationStressTestRoom
extends Node3D

@onready var feedback: FeedbackManager = %FeedbackManager
@onready var result_label: Label = %ResultLabel

const STRESS_EVENTS := [
	&"FOOTSTEP", &"pistol_fire", &"pistol_dry_fire", &"pistol_reload", &"bullet_impact",
	&"PICKUP", &"ITEM_USED", &"MENU_OPEN", &"MENU_MOVE", &"MENU_CLOSE", &"REJECTED",
	&"DETECTED", &"ALERT_PHASE_CHANGED", &"PLAYER_DAMAGED", &"DOOR", &"CHECKPOINT", &"OBJECTIVE",
]


func _ready() -> void:
	result_label.text = "PRESENTATION STRESS LAB\nPress Enter / A to emit a bounded event burst."


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		var snapshot := run_stress_burst(20)
		result_label.text = "STRESS RESULT\nVOICES %d/%d   EFFECTS %d/%d   SUPPRESSED %d" % [
			snapshot.active_voices, snapshot.voice_capacity,
			snapshot.active_effects, snapshot.effect_capacity, snapshot.suppressed,
		]


func run_stress_burst(loop_count: int = 20) -> Dictionary:
	for loop_index in maxi(loop_count, 0):
		for event_id: StringName in STRESS_EVENTS:
			feedback.request_feedback(event_id, {
				&"position": Vector3(float(loop_index % 5), 1.0, float(loop_index % 7)),
			})
	return feedback.get_feedback_snapshot()

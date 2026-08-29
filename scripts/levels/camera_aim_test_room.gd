extends Node3D

@onready var player: PlayerController = %Player
@onready var camera_rig: GameplayCameraRig = %GameplayCameraRig
@onready var diagnostics: Label = %Diagnostics
@onready var feedback: Label = %Feedback
@onready var reticle: Control = %Reticle

var _last_feedback: String = "Aim is enabled by the lab's test weapon."


func _ready() -> void:
	camera_rig.set_tracked_actor(player)
	camera_rig.set_weapon_equipped(true)
	camera_rig.mode_changed.connect(_on_camera_mode_changed)
	camera_rig.active_zone_changed.connect(_on_active_zone_changed)
	camera_rig.aim_rejected.connect(_on_aim_rejected)
	camera_rig.reticle_visibility_requested.connect(_on_reticle_visibility_requested)
	camera_rig.aim_obstruction_changed.connect(_on_aim_obstruction_changed)


func _process(_delta: float) -> void:
	var zone_name := (
		String(camera_rig.active_zone.get_zone_id())
		if camera_rig.active_zone != null
		else "FALLBACK"
	)
	diagnostics.text = "ZONE %s   MODE %s   TRANSITION %s   AIM RAY %s" % [
		zone_name,
		"FIRST-PERSON" if camera_rig.mode == GameplayCameraRig.CameraMode.AIM else "EXPLORATION",
		"BLENDING" if camera_rig.is_transitioning else "SETTLED",
		"BLOCKED" if camera_rig.aim_is_obstructed else "CLEAR",
	]
	feedback.text = _last_feedback


func _on_camera_mode_changed(_previous: int, current: int) -> void:
	_last_feedback = (
		"First-person aim: movement rooted, yaw/pitch bounded, release to recenter."
		if current == GameplayCameraRig.CameraMode.AIM
		else "Exploration camera restored; pending zone transition applied."
	)


func _on_active_zone_changed(_previous: CameraZone3D, current: CameraZone3D) -> void:
	_last_feedback = "Active authored zone: %s" % (
		String(current.get_zone_id()) if current != null else "FALLBACK"
	)


func _on_aim_rejected(reason: StringName) -> void:
	_last_feedback = "AIM REJECTED: %s" % reason


func _on_reticle_visibility_requested(visible: bool) -> void:
	reticle.visible = visible


func _on_aim_obstruction_changed(is_obstructed: bool) -> void:
	if is_obstructed:
		_last_feedback = "AIM BLOCKED: step back or change angle."


extends Node3D

@onready var player: PlayerController = %Player
@onready var camera_rig: GameplayCameraRig = %GameplayCameraRig
@onready var focus: InteractionFocus3D = %InteractionFocus
@onready var test_door: Door3D = %TestDoor
@onready var access_token: MissionMarker3D = %AccessToken
@onready var prompt_label: Label = %PromptLabel

var _has_access: bool = false


func _ready() -> void:
	camera_rig.set_tracked_actor(player)
	camera_rig.refresh_zones()
	camera_rig.reset_camera_state()
	focus.set_actor(player, player.interaction_origin)
	focus.set_camera_rig(camera_rig)
	test_door.set_access_query(func(_actor: Node, level: StringName) -> bool: return _has_access and level == &"TEST_ACCESS")
	access_token.mission_event.connect(_on_access_token)


func _process(_delta: float) -> void:
	var snapshot := focus.get_prompt_snapshot()
	if snapshot.target == null:
		prompt_label.text = "Move near a target to test focus."
	elif snapshot.available:
		prompt_label.text = "[F / A] %s" % snapshot.prompt
	else:
		prompt_label.text = "%s — %s" % [snapshot.prompt, snapshot.reason]


func _on_access_token(_event_id: StringName, _actor: Node, _payload: Dictionary) -> void:
	_has_access = true

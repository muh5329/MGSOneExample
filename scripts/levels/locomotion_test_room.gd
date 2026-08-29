extends Node3D

@onready var player: PlayerController = %Player
@onready var cameras: Array[Camera3D] = [%CameraSouthEast, %CameraNorthWest]
@onready var diagnostics: Label = %Diagnostics

var _active_camera_index: int = 0


func _ready() -> void:
	for camera in cameras:
		camera.look_at(Vector3(0.0, 0.8, 0.0), Vector3.UP)
	_activate_camera(0)


func _process(_delta: float) -> void:
	var planar_speed := Vector2(player.velocity.x, player.velocity.z).length()
	diagnostics.text = (
		"CAMERA %s   STANCE %s   SPEED %.2f / %.2f   NOISE %.2f\n"
		% [
			_active_camera_index + 1,
			"CROUCHED" if player.stance == PlayerController.Stance.CROUCHED else "STANDING",
			planar_speed,
			player.config.crouch_speed if player.stance == PlayerController.Stance.CROUCHED else player.config.standing_speed,
			player.movement_noise_intensity,
		]
		+ "Orange frame: crouch before entering; standing is blocked inside."
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		_activate_camera((_active_camera_index + 1) % cameras.size())
		get_viewport().set_input_as_handled()


func _activate_camera(index: int) -> void:
	_active_camera_index = index
	for camera_index in cameras.size():
		cameras[camera_index].current = camera_index == _active_camera_index
	player.set_camera_basis(cameras[_active_camera_index].global_basis)

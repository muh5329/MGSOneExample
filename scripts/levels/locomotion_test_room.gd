extends Node3D

@onready var player: PlayerController = %Player
@onready var camera_rig: GameplayCameraRig = %GameplayCameraRig
@onready var diagnostics: Label = %Diagnostics


func _ready() -> void:
	camera_rig.set_tracked_actor(player)
	camera_rig.set_weapon_equipped(false)


func _process(_delta: float) -> void:
	var planar_speed := Vector2(player.velocity.x, player.velocity.z).length()
	diagnostics.text = (
		"CAMERA %s   STANCE %s   SPEED %.2f / %.2f   NOISE %.2f\n"
		% [
			String(camera_rig.active_zone.get_zone_id()) if camera_rig.active_zone != null else "FALLBACK",
			"CROUCHED" if player.stance == PlayerController.Stance.CROUCHED else "STANDING",
			planar_speed,
			player.config.crouch_speed if player.stance == PlayerController.Stance.CROUCHED else player.config.standing_speed,
			player.movement_noise_intensity,
		]
		+ "Orange frame: crouch before entering; standing is blocked inside."
	)

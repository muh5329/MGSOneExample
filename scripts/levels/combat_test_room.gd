extends Node3D

const PISTOL := preload("res://data/weapons/w1_service_pistol.tres")

@onready var player: PlayerController = %Player
@onready var camera_rig: GameplayCameraRig = %GameplayCameraRig
@onready var weapon: WeaponController = player.get_node("WeaponController") as WeaponController
@onready var ammo_source: CombatTestAmmoSource = %AmmoSource
@onready var static_target: CombatTestReceiver3D = %StaticTarget
@onready var moving_target: CombatTestReceiver3D = %MovingTarget
@onready var diagnostics: Label = %Diagnostics
@onready var feedback: Label = %Feedback
@onready var reticle: Control = %Reticle

var _last_feedback: String = "Hold aim, then fire."


func _ready() -> void:
	camera_rig.set_tracked_actor(player)
	weapon.set_combat_owner(player)
	weapon.set_aim_provider(camera_rig)
	weapon.set_ammo_source(ammo_source)
	weapon.request_equip(PISTOL, PISTOL.magazine_capacity)
	camera_rig.reticle_visibility_requested.connect(func(visible: bool) -> void: reticle.visible = visible)
	weapon.feedback_requested.connect(_on_feedback_requested)
	weapon.reload_completed.connect(func(loaded: int) -> void: _last_feedback = "RELOAD COMPLETE  +%d" % loaded)
	weapon.dry_fired.connect(func(reason: StringName) -> void: _last_feedback = "DRY FIRE  %s" % reason)
	static_target.health_changed.connect(_on_target_health_changed.bind(static_target))
	moving_target.health_changed.connect(_on_target_health_changed.bind(moving_target))


func _process(_delta: float) -> void:
	var reserve := ammo_source.get_ammo_count(PISTOL.ammo_type)
	diagnostics.text = "%s  |  STATE %s  |  MAG %d / %d  |  RESERVE %d" % [
		PISTOL.display_name.to_upper(),
		WeaponController.WeaponState.keys()[weapon.state],
		weapon.magazine,
		PISTOL.magazine_capacity,
		reserve,
	]
	feedback.text = _last_feedback
	static_target.get_node("HealthLabel").text = "%d" % ceili(static_target.health)
	moving_target.get_node("HealthLabel").text = "%d" % ceili(moving_target.health)


func _on_feedback_requested(feedback_id: StringName, payload: Dictionary) -> void:
	_last_feedback = "FEEDBACK  %s" % feedback_id
	if feedback_id == PISTOL.fire_feedback_id:
		camera_rig.add_camera_impulse(
			payload.get(&"camera_impulse_position", Vector3.ZERO),
			payload.get(&"camera_impulse_rotation_degrees", Vector3.ZERO),
			payload.get(&"camera_impulse_duration", 0.1)
		)


func _on_target_health_changed(
		_previous: float,
		current: float,
		_context: HitContext3D,
		target: CombatTestReceiver3D
) -> void:
	_last_feedback = "IMPACT  %s  HEALTH %d" % [target.name, ceili(current)]

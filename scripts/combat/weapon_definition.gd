class_name WeaponDefinition
extends Resource

@export var weapon_id: StringName = &""
@export var display_name: String = "Weapon"
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_category("Ballistics")
@export_range(0.0, 1000.0, 0.5, "suffix:damage") var damage: float = 10.0
@export_range(0.1, 1000.0, 0.5, "suffix:m") var maximum_range: float = 50.0
@export_range(0.01, 10.0, 0.01, "suffix:s") var fire_interval: float = 0.25
@export_range(0.0, 20.0, 0.05, "degrees") var spread_degrees: float = 0.0
@export var damage_tags: PackedStringArray = PackedStringArray(["bullet"])

@export_category("Ammunition")
@export_range(1, 999, 1) var magazine_capacity: int = 8
@export var ammo_type: StringName = &"pistol_round"
@export_range(0.0, 10.0, 0.01, "suffix:s") var equip_duration: float = 0.2
@export_range(0.0, 20.0, 0.01, "suffix:s") var reload_duration: float = 1.1
@export var automatic: bool = false

@export_category("Feedback")
@export var fire_feedback_id: StringName = &"pistol_fire"
@export var dry_fire_feedback_id: StringName = &"pistol_dry_fire"
@export var reload_feedback_id: StringName = &"pistol_reload"
@export var impact_feedback_id: StringName = &"bullet_impact"
@export_range(0.0, 100.0, 0.5, "suffix:m") var gunshot_loudness: float = 30.0
@export var camera_impulse_position: Vector3 = Vector3(0.0, 0.0, -0.025)
@export var camera_impulse_rotation_degrees: Vector3 = Vector3(-1.1, 0.0, 0.0)
@export_range(0.01, 2.0, 0.01, "suffix:s") var camera_impulse_duration: float = 0.12


func is_valid_definition() -> bool:
	return (
		not weapon_id.is_empty()
		and damage >= 0.0
		and maximum_range > 0.0
		and fire_interval > 0.0
		and magazine_capacity > 0
		and not ammo_type.is_empty()
	)

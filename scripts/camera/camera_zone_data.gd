class_name CameraZoneData
extends Resource

@export var zone_id: StringName = &"UNNAMED_ZONE"
@export var priority: int = 0
@export_range(0.0, 3.0, 0.01, "suffix:s") var blend_duration: float = 0.35
@export var aim_allowed: bool = true

@export_group("Volume")
@export var volume_size: Vector3 = Vector3(8.0, 4.0, 8.0)

@export_group("Framing")
@export var camera_offset: Vector3 = Vector3(8.0, 10.0, 10.0)
@export var look_target_offset: Vector3 = Vector3(0.0, 0.9, 0.0)
@export var tracking_extents: Vector2 = Vector2.ZERO
@export_range(30.0, 100.0, 0.5, "degrees") var field_of_view: float = 54.0


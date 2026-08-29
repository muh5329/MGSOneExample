class_name CameraZone3D
extends Area3D

@export var data: CameraZoneData


func _ready() -> void:
	add_to_group(&"camera_zones")
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	assert(data != null, "CameraZone3D requires a CameraZoneData resource.")


func contains_world_point(world_point: Vector3) -> bool:
	if data == null:
		return false
	var local_point := global_transform.affine_inverse() * world_point
	var half_size := data.volume_size.abs() * 0.5
	return (
		absf(local_point.x) <= half_size.x
		and absf(local_point.y) <= half_size.y
		and absf(local_point.z) <= half_size.z
	)


func get_camera_transform(tracked_position: Vector3) -> Transform3D:
	var camera_position := global_transform * data.camera_offset
	var target_position := get_look_target(tracked_position)
	return Transform3D(Basis.IDENTITY, camera_position).looking_at(target_position, Vector3.UP)


func get_look_target(tracked_position: Vector3) -> Vector3:
	var authored_target := global_transform * data.look_target_offset
	if data.tracking_extents.is_zero_approx():
		return authored_target
	var local_actor := global_transform.affine_inverse() * tracked_position
	var tracked_local := Vector3(
		clampf(local_actor.x, -data.tracking_extents.x, data.tracking_extents.x),
		data.look_target_offset.y,
		clampf(local_actor.z, -data.tracking_extents.y, data.tracking_extents.y)
	)
	return global_transform * tracked_local


func get_zone_id() -> StringName:
	return data.zone_id if data != null else &"UNNAMED_ZONE"


func get_zone_priority() -> int:
	return data.priority if data != null else -2147483648

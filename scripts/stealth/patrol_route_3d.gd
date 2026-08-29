class_name PatrolRoute3D
extends Node3D

@export var route_id: StringName = &""
@export var loops: bool = true


func get_point_count() -> int:
	return get_child_count()


func get_point_world_position(index: int) -> Vector3:
	var point := _point_at(index)
	return point.global_position if point != null else global_position


func get_wait_seconds(index: int) -> float:
	var point := _point_at(index)
	if point == null:
		return 0.0
	return maxf(float(point.get_meta(&"wait_seconds", 0.0)), 0.0)


func get_look_direction(index: int) -> Vector3:
	var point := _point_at(index)
	if point == null:
		return Vector3.ZERO
	var authored: Variant = point.get_meta(&"look_direction", Vector3.ZERO)
	if authored is Vector3 and not (authored as Vector3).is_zero_approx():
		return (authored as Vector3).normalized()
	if get_point_count() < 2:
		return Vector3.ZERO
	var next_index := index + 1
	if next_index >= get_point_count():
		next_index = 0 if loops else index
	var direction := get_point_world_position(next_index) - point.global_position
	direction.y = 0.0
	return direction.normalized() if not direction.is_zero_approx() else Vector3.ZERO


func get_next_index(index: int) -> int:
	if get_point_count() <= 0:
		return -1
	var next_index := index + 1
	if next_index < get_point_count():
		return next_index
	return 0 if loops else get_point_count() - 1


func get_closest_point_index(world_position: Vector3) -> int:
	var best_index := -1
	var best_distance := INF
	for index in get_point_count():
		var distance := world_position.distance_squared_to(get_point_world_position(index))
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index


func get_route_snapshot() -> Dictionary:
	var points: Array[Dictionary] = []
	for index in get_point_count():
		points.append({
			&"position": get_point_world_position(index),
			&"wait_seconds": get_wait_seconds(index),
			&"look_direction": get_look_direction(index),
		})
	return {&"route_id": route_id, &"loops": loops, &"points": points}


func _point_at(index: int) -> Marker3D:
	if index < 0 or index >= get_child_count():
		return null
	return get_child(index) as Marker3D

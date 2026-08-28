class_name NoiseEvent3D
extends RefCounted

var source: Node3D
var world_position: Vector3
var loudness: float
var category: StringName


func _init(
		new_source: Node3D,
		new_world_position: Vector3,
		new_loudness: float,
		new_category: StringName = &"unspecified"
) -> void:
	source = new_source
	world_position = new_world_position
	loudness = maxf(new_loudness, 0.0)
	category = new_category


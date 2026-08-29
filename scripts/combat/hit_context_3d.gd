class_name HitContext3D
extends RefCounted

var instigator: Node
var weapon_id: StringName
var shot_id: int
var position: Vector3
var normal: Vector3
var direction: Vector3
var damage: float
var damage_tags: PackedStringArray
var collider: Object


func _init(
		new_instigator: Node,
		new_weapon_id: StringName,
		new_shot_id: int,
		new_position: Vector3,
		new_normal: Vector3,
		new_direction: Vector3,
		new_damage: float,
		new_damage_tags: PackedStringArray,
		new_collider: Object = null
) -> void:
	instigator = new_instigator
	weapon_id = new_weapon_id
	shot_id = new_shot_id
	position = new_position
	normal = new_normal
	direction = new_direction.normalized()
	damage = maxf(new_damage, 0.0)
	damage_tags = new_damage_tags.duplicate()
	collider = new_collider

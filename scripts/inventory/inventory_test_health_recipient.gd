class_name InventoryTestHealthRecipient
extends Node

signal health_changed(current: float, maximum: float)

@export var maximum_health: float = 100.0
@export var health: float = 50.0


func can_receive_item_effect(effect_id: StringName, _amount: float) -> bool:
	return effect_id == &"heal" and health < maximum_health


func receive_item_effect(effect_id: StringName, amount: float, _context: Dictionary) -> bool:
	if not can_receive_item_effect(effect_id, amount):
		return false
	health = minf(health + maxf(amount, 0.0), maximum_health)
	health_changed.emit(health, maximum_health)
	return true

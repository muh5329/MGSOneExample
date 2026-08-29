class_name CombatTestAmmoSource
extends Node

@export var pistol_rounds: int = 12


func get_ammo_count(ammo_type: StringName) -> int:
	return pistol_rounds if ammo_type == &"pistol_round" else 0


func take_ammo(ammo_type: StringName, requested: int) -> int:
	if ammo_type != &"pistol_round" or requested <= 0:
		return 0
	var taken := mini(pistol_rounds, requested)
	pistol_rounds -= taken
	return taken


func add_ammo(ammo_type: StringName, quantity: int) -> int:
	if ammo_type != &"pistol_round" or quantity <= 0:
		return 0
	pistol_rounds += quantity
	return quantity

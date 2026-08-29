class_name InventoryPickup3D
extends MissionMarker3D

signal pickup_transaction(result: Dictionary)

@export var inventory_entry_id: StringName = &""
@export_range(1, 999, 1) var quantity: int = 1
@export_range(-1, 999, 1) var initial_magazine: int = -1
@export var auto_equip: bool = false

var inventory: InventoryComponent


func _ready() -> void:
	marker_kind = MarkerKind.PICKUP
	one_shot = false
	super._ready()


func set_inventory(next_inventory: InventoryComponent) -> void:
	inventory = next_inventory


func is_available(actor: Node = null) -> bool:
	return super.is_available(actor) and inventory != null and inventory.can_add(inventory_entry_id, quantity)


func get_unavailable_reason(actor: Node = null) -> StringName:
	if inventory == null:
		return &"INVENTORY_UNAVAILABLE"
	if not inventory.can_add(inventory_entry_id, quantity):
		return &"INVENTORY_FULL"
	return super.get_unavailable_reason(actor)


func interact(actor: Node) -> bool:
	if not is_available(actor):
		interaction_rejected.emit(actor, get_unavailable_reason(actor))
		return false
	var result := inventory.add_entry(inventory_entry_id, quantity)
	if not bool(result.accepted):
		interaction_rejected.emit(actor, StringName(result.reason))
		return false
	var accepted := int(result.changed)
	quantity -= accepted
	if auto_equip:
		inventory.request_equip_weapon(inventory_entry_id, initial_magazine)
	var event_payload := payload.duplicate(true)
	event_payload[&"quantity"] = accepted
	mission_event.emit(event_id, actor, event_payload)
	pickup_transaction.emit(result.duplicate(true))
	interacted.emit(actor)
	if quantity <= 0:
		set_consumed(true)
	else:
		availability_changed.emit(is_available(actor), get_unavailable_reason(actor))
	return true

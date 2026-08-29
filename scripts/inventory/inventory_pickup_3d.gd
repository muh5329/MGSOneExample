class_name InventoryPickup3D
extends MissionMarker3D

signal pickup_transaction(result: Dictionary)

@export var inventory_entry_id: StringName = &""
@export_range(1, 999, 1) var quantity: int = 1
@export_range(-1, 999, 1) var initial_magazine: int = -1
@export var auto_equip: bool = false

var inventory: InventoryComponent
var _authored_quantity: int = 0


func _ready() -> void:
	marker_kind = MarkerKind.PICKUP
	one_shot = false
	_authored_quantity = quantity
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


func get_checkpoint_snapshot() -> Dictionary:
	return {
		&"pickup_id": event_id,
		&"entry_id": inventory_entry_id,
		&"quantity": quantity,
		&"consumed": is_consumed(),
	}


func validate_checkpoint_snapshot(snapshot: Dictionary) -> bool:
	var snapshot_quantity := int(snapshot.get(&"quantity", -1))
	return (
		StringName(snapshot.get(&"pickup_id", &"")) == event_id
		and StringName(snapshot.get(&"entry_id", &"")) == inventory_entry_id
		and snapshot_quantity >= 0
		and snapshot_quantity <= _authored_quantity
		and typeof(snapshot.get(&"consumed", null)) == TYPE_BOOL
		and bool(snapshot.get(&"consumed", false)) == (snapshot_quantity <= 0)
	)


func restore_checkpoint_snapshot(snapshot: Dictionary) -> bool:
	if not validate_checkpoint_snapshot(snapshot):
		return false
	quantity = int(snapshot.quantity)
	set_consumed(bool(snapshot.consumed))
	return true

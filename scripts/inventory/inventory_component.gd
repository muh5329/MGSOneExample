class_name InventoryComponent
extends Node

signal transaction_completed(result: Dictionary)
signal inventory_changed(snapshot: Dictionary)
signal equipped_weapon_changed(entry_id: StringName, definition: WeaponDefinition)
signal equipped_item_changed(entry_id: StringName)
signal item_use_requested(entry_id: StringName, effect_id: StringName, amount: float, recipient: Object)
signal item_used(entry_id: StringName, effect_id: StringName, amount: float)

enum TransactionCode {
	SUCCESS,
	PARTIAL,
	INVALID_REQUEST,
	UNKNOWN_ENTRY,
	CAPACITY_REACHED,
	NOT_OWNED,
	NOT_SELECTABLE,
	CONTROL_LOCKED,
	RECIPIENT_UNAVAILABLE,
	EFFECT_REJECTED,
	SNAPSHOT_INVALID,
}

const REASONS: Dictionary = {
	TransactionCode.SUCCESS: &"OK",
	TransactionCode.PARTIAL: &"PARTIAL",
	TransactionCode.INVALID_REQUEST: &"INVALID_REQUEST",
	TransactionCode.UNKNOWN_ENTRY: &"UNKNOWN_ENTRY",
	TransactionCode.CAPACITY_REACHED: &"INVENTORY_FULL",
	TransactionCode.NOT_OWNED: &"NOT_OWNED",
	TransactionCode.NOT_SELECTABLE: &"NOT_SELECTABLE",
	TransactionCode.CONTROL_LOCKED: &"CONTROL_LOCKED",
	TransactionCode.RECIPIENT_UNAVAILABLE: &"RECIPIENT_UNAVAILABLE",
	TransactionCode.EFFECT_REJECTED: &"EFFECT_REJECTED",
	TransactionCode.SNAPSHOT_INVALID: &"SNAPSHOT_INVALID",
}

@export var definitions: Array[InventoryEntryDefinition] = []
@export var weapon_controller_path: NodePath = ^"../VisualRoot/WeaponController"

var equipped_weapon_id: StringName = &""
var equipped_item_id: StringName = &""
var control_enabled: bool = true

var _definitions_by_id: Dictionary = {}
var _quantities: Dictionary = {}
var _weapon_controller: WeaponController


func _ready() -> void:
	_rebuild_catalog()
	_weapon_controller = get_node_or_null(weapon_controller_path) as WeaponController
	if _weapon_controller != null:
		_weapon_controller.set_ammo_source(self)


func set_weapon_controller(controller: WeaponController) -> void:
	_weapon_controller = controller
	if _weapon_controller != null:
		_weapon_controller.set_ammo_source(self)


func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled


func register_definition(entry: InventoryEntryDefinition) -> bool:
	if entry == null or not entry.is_valid_definition() or _definitions_by_id.has(entry.entry_id):
		return false
	definitions.append(entry)
	_definitions_by_id[entry.entry_id] = entry
	_quantities[entry.entry_id] = 0
	_emit_inventory_changed()
	return true


func get_definition(entry_id: StringName) -> InventoryEntryDefinition:
	return _definitions_by_id.get(entry_id) as InventoryEntryDefinition


func get_count(entry_id: StringName) -> int:
	return maxi(int(_quantities.get(entry_id, 0)), 0)


func has_entry(entry_id: StringName, quantity: int = 1) -> bool:
	return quantity >= 0 and get_count(entry_id) >= quantity


func get_remaining_capacity(entry_id: StringName) -> int:
	var entry := get_definition(entry_id)
	if entry == null:
		return 0
	return maxi(entry.maximum_quantity - get_count(entry_id), 0)


func can_add(entry_id: StringName, quantity: int = 1) -> bool:
	return quantity > 0 and get_remaining_capacity(entry_id) > 0


func add_entry(entry_id: StringName, quantity: int = 1) -> Dictionary:
	var entry := get_definition(entry_id)
	if entry == null:
		return _result(TransactionCode.UNKNOWN_ENTRY, entry_id, quantity)
	if quantity <= 0:
		return _result(TransactionCode.INVALID_REQUEST, entry_id, quantity)
	var accepted := mini(quantity, get_remaining_capacity(entry_id))
	if accepted <= 0:
		return _result(TransactionCode.CAPACITY_REACHED, entry_id, quantity)
	_quantities[entry_id] = get_count(entry_id) + accepted
	var code := TransactionCode.SUCCESS if accepted == quantity else TransactionCode.PARTIAL
	var result := _result(code, entry_id, quantity, accepted)
	_emit_transaction(result)
	return result


func remove_entry(entry_id: StringName, quantity: int = 1) -> Dictionary:
	if get_definition(entry_id) == null:
		return _result(TransactionCode.UNKNOWN_ENTRY, entry_id, quantity)
	if quantity <= 0:
		return _result(TransactionCode.INVALID_REQUEST, entry_id, quantity)
	var available := get_count(entry_id)
	if available <= 0:
		return _result(TransactionCode.NOT_OWNED, entry_id, quantity)
	var removed := mini(quantity, available)
	_quantities[entry_id] = available - removed
	_validate_equipped_state()
	var code := TransactionCode.SUCCESS if removed == quantity else TransactionCode.PARTIAL
	var result := _result(code, entry_id, quantity, removed)
	_emit_transaction(result)
	return result


func request_equip_weapon(entry_id: StringName, initial_magazine: int = -1) -> Dictionary:
	if not control_enabled:
		return _result(TransactionCode.CONTROL_LOCKED, entry_id, 0)
	var entry := get_definition(entry_id)
	if entry == null:
		return _result(TransactionCode.UNKNOWN_ENTRY, entry_id, 0)
	if entry.kind != InventoryEntryDefinition.EntryKind.WEAPON or not entry.selectable:
		return _result(TransactionCode.NOT_SELECTABLE, entry_id, 0)
	if get_count(entry_id) <= 0:
		return _result(TransactionCode.NOT_OWNED, entry_id, 0)
	if _weapon_controller == null or not _weapon_controller.request_equip(entry.weapon_definition, initial_magazine):
		return _result(TransactionCode.CONTROL_LOCKED, entry_id, 0)
	equipped_weapon_id = entry_id
	equipped_weapon_changed.emit(entry_id, entry.weapon_definition)
	var result := _result(TransactionCode.SUCCESS, entry_id, 0)
	_emit_transaction(result)
	return result


func request_unequip_weapon() -> Dictionary:
	if not control_enabled:
		return _result(TransactionCode.CONTROL_LOCKED, equipped_weapon_id, 0)
	if _weapon_controller != null and not _weapon_controller.request_unequip():
		return _result(TransactionCode.CONTROL_LOCKED, equipped_weapon_id, 0)
	equipped_weapon_id = &""
	equipped_weapon_changed.emit(&"", null)
	var result := _result(TransactionCode.SUCCESS, &"", 0)
	_emit_transaction(result)
	return result


func request_equip_item(entry_id: StringName) -> Dictionary:
	if not control_enabled:
		return _result(TransactionCode.CONTROL_LOCKED, entry_id, 0)
	var entry := get_definition(entry_id)
	if entry == null:
		return _result(TransactionCode.UNKNOWN_ENTRY, entry_id, 0)
	if entry.kind != InventoryEntryDefinition.EntryKind.CONSUMABLE or not entry.selectable:
		return _result(TransactionCode.NOT_SELECTABLE, entry_id, 0)
	if get_count(entry_id) <= 0:
		return _result(TransactionCode.NOT_OWNED, entry_id, 0)
	equipped_item_id = entry_id
	equipped_item_changed.emit(entry_id)
	var result := _result(TransactionCode.SUCCESS, entry_id, 0)
	_emit_transaction(result)
	return result


func request_use_item(entry_id: StringName, recipient: Object) -> Dictionary:
	if not control_enabled:
		return _result(TransactionCode.CONTROL_LOCKED, entry_id, 1)
	var entry := get_definition(entry_id)
	if entry == null:
		return _result(TransactionCode.UNKNOWN_ENTRY, entry_id, 1)
	if entry.kind != InventoryEntryDefinition.EntryKind.CONSUMABLE:
		return _result(TransactionCode.NOT_SELECTABLE, entry_id, 1)
	if get_count(entry_id) <= 0:
		return _result(TransactionCode.NOT_OWNED, entry_id, 1)
	if recipient == null or not is_instance_valid(recipient) or not recipient.has_method(&"receive_item_effect"):
		return _result(TransactionCode.RECIPIENT_UNAVAILABLE, entry_id, 1)
	if recipient.has_method(&"can_receive_item_effect") and not bool(recipient.call(&"can_receive_item_effect", entry.effect_id, entry.effect_amount)):
		var reason := &"FULL_HEALTH" if entry.effect_id == &"heal" else &"EFFECT_REJECTED"
		return _result(TransactionCode.EFFECT_REJECTED, entry_id, 1, 0, reason)
	item_use_requested.emit(entry_id, entry.effect_id, entry.effect_amount, recipient)
	var context := {
		&"source": self,
		&"entry_id": entry_id,
	}
	if not bool(recipient.call(&"receive_item_effect", entry.effect_id, entry.effect_amount, context)):
		return _result(TransactionCode.EFFECT_REJECTED, entry_id, 1)
	_quantities[entry_id] = get_count(entry_id) - 1
	_validate_equipped_state()
	item_used.emit(entry_id, entry.effect_id, entry.effect_amount)
	var result := _result(TransactionCode.SUCCESS, entry_id, 1, 1)
	_emit_transaction(result)
	return result


func request_quick_use(recipient: Object) -> Dictionary:
	if equipped_item_id.is_empty():
		return _result(TransactionCode.NOT_OWNED, &"", 1)
	return request_use_item(equipped_item_id, recipient)


func has_access_level(access_level: StringName) -> bool:
	if access_level.is_empty():
		return false
	for entry in definitions:
		if entry.kind == InventoryEntryDefinition.EntryKind.KEY_ITEM and entry.access_level == access_level and get_count(entry.entry_id) > 0:
			return true
	return false


func get_ammo_count(ammo_type: StringName) -> int:
	for entry in definitions:
		if entry.kind == InventoryEntryDefinition.EntryKind.AMMUNITION and entry.ammo_type == ammo_type:
			return get_count(entry.entry_id)
	return 0


func take_ammo(ammo_type: StringName, requested: int) -> int:
	if requested <= 0:
		return 0
	for entry in definitions:
		if entry.kind == InventoryEntryDefinition.EntryKind.AMMUNITION and entry.ammo_type == ammo_type:
			var taken := mini(requested, get_count(entry.entry_id))
			if taken > 0:
				_quantities[entry.entry_id] = get_count(entry.entry_id) - taken
				_emit_transaction(_result(TransactionCode.SUCCESS if taken == requested else TransactionCode.PARTIAL, entry.entry_id, requested, taken))
			return taken
	return 0


func get_selection_snapshot(panel: InventoryEntryDefinition.PanelKind) -> Array[Dictionary]:
	var entries: Array[InventoryEntryDefinition] = []
	for entry in definitions:
		if entry.panel == panel:
			entries.append(entry)
	entries.sort_custom(func(a: InventoryEntryDefinition, b: InventoryEntryDefinition) -> bool:
		if a.selection_order != b.selection_order:
			return a.selection_order < b.selection_order
		return String(a.entry_id) < String(b.entry_id)
	)
	var snapshot: Array[Dictionary] = []
	for entry in entries:
		snapshot.append(_entry_snapshot(entry))
	return snapshot


func get_display_snapshot() -> Dictionary:
	return {
		&"entries": get_selection_snapshot(InventoryEntryDefinition.PanelKind.WEAPON) + get_selection_snapshot(InventoryEntryDefinition.PanelKind.ITEM),
		&"equipped_weapon_id": equipped_weapon_id,
		&"equipped_item_id": equipped_item_id,
	}


func get_checkpoint_snapshot() -> Dictionary:
	return {
		&"quantities": _quantities.duplicate(true),
		&"equipped_weapon_id": equipped_weapon_id,
		&"equipped_item_id": equipped_item_id,
		&"weapon_runtime": _weapon_controller.get_runtime_snapshot() if _weapon_controller != null else {},
	}


func restore_checkpoint_snapshot(snapshot: Dictionary) -> Dictionary:
	var restored_quantities: Dictionary = snapshot.get(&"quantities", {})
	for key in restored_quantities:
		var entry := get_definition(StringName(key))
		var quantity := int(restored_quantities[key])
		if entry == null or quantity < 0 or quantity > entry.maximum_quantity:
			return _result(TransactionCode.SNAPSHOT_INVALID, StringName(key), quantity)
	var next_weapon := StringName(snapshot.get(&"equipped_weapon_id", &""))
	var next_item := StringName(snapshot.get(&"equipped_item_id", &""))
	if not _valid_equipped_id(next_weapon, InventoryEntryDefinition.EntryKind.WEAPON, restored_quantities):
		return _result(TransactionCode.SNAPSHOT_INVALID, next_weapon, 0)
	if not _valid_equipped_id(next_item, InventoryEntryDefinition.EntryKind.CONSUMABLE, restored_quantities):
		return _result(TransactionCode.SNAPSHOT_INVALID, next_item, 0)
	for entry in definitions:
		_quantities[entry.entry_id] = int(restored_quantities.get(entry.entry_id, 0))
	equipped_weapon_id = next_weapon
	equipped_item_id = next_item
	if _weapon_controller != null:
		var weapon_runtime: Dictionary = snapshot.get(&"weapon_runtime", {})
		if equipped_weapon_id.is_empty():
			_weapon_controller.request_unequip()
		else:
			var weapon_entry := get_definition(equipped_weapon_id)
			_weapon_controller.request_equip(weapon_entry.weapon_definition)
			if not weapon_runtime.is_empty():
				_weapon_controller.restore_runtime(weapon_runtime)
	equipped_weapon_changed.emit(equipped_weapon_id, get_definition(equipped_weapon_id).weapon_definition if not equipped_weapon_id.is_empty() else null)
	equipped_item_changed.emit(equipped_item_id)
	var result := _result(TransactionCode.SUCCESS, &"", 0)
	_emit_transaction(result)
	return result


func _rebuild_catalog() -> void:
	_definitions_by_id.clear()
	_quantities.clear()
	for entry in definitions:
		assert(entry != null and entry.is_valid_definition(), "Inventory definitions must be valid resources.")
		assert(not _definitions_by_id.has(entry.entry_id), "Inventory entry IDs must be unique.")
		_definitions_by_id[entry.entry_id] = entry
		_quantities[entry.entry_id] = 0


func _entry_snapshot(entry: InventoryEntryDefinition) -> Dictionary:
	var magazine := 0
	var reserve := 0
	if entry.kind == InventoryEntryDefinition.EntryKind.WEAPON and entry.weapon_definition != null:
		reserve = get_ammo_count(entry.weapon_definition.ammo_type)
		if entry.entry_id == equipped_weapon_id and _weapon_controller != null:
			magazine = _weapon_controller.magazine
	return {
		&"entry_id": entry.entry_id,
		&"display_name": entry.display_name,
		&"description": entry.description,
		&"kind": entry.kind,
		&"quantity": get_count(entry.entry_id),
		&"maximum_quantity": entry.maximum_quantity,
		&"selectable": entry.selectable,
		&"equipped": entry.entry_id == equipped_weapon_id or entry.entry_id == equipped_item_id,
		&"access_level": entry.access_level,
		&"ammo_type": entry.ammo_type,
		&"magazine": magazine,
		&"reserve": reserve,
	}


func _valid_equipped_id(entry_id: StringName, kind: InventoryEntryDefinition.EntryKind, quantities: Dictionary) -> bool:
	if entry_id.is_empty():
		return true
	var entry := get_definition(entry_id)
	return entry != null and entry.kind == kind and entry.selectable and int(quantities.get(entry_id, 0)) > 0


func _validate_equipped_state() -> void:
	if not equipped_weapon_id.is_empty() and get_count(equipped_weapon_id) <= 0:
		equipped_weapon_id = &""
		if _weapon_controller != null:
			_weapon_controller.request_unequip()
		equipped_weapon_changed.emit(&"", null)
	if not equipped_item_id.is_empty() and get_count(equipped_item_id) <= 0:
		equipped_item_id = &""
		equipped_item_changed.emit(&"")


func _result(code: TransactionCode, entry_id: StringName, requested: int, changed: int = 0, reason_override: StringName = &"") -> Dictionary:
	return {
		&"code": code,
		&"accepted": code == TransactionCode.SUCCESS or code == TransactionCode.PARTIAL,
		&"entry_id": entry_id,
		&"requested": requested,
		&"changed": changed,
		&"current": get_count(entry_id),
		&"reason": reason_override if not reason_override.is_empty() else REASONS[code],
	}


func _emit_transaction(result: Dictionary) -> void:
	transaction_completed.emit(result.duplicate(true))
	_emit_inventory_changed()
	if _weapon_controller != null:
		_weapon_controller.refresh_ammo_state()


func _emit_inventory_changed() -> void:
	inventory_changed.emit(get_display_snapshot().duplicate(true))

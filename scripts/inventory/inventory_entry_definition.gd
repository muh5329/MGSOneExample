class_name InventoryEntryDefinition
extends Resource

enum EntryKind {
	WEAPON,
	AMMUNITION,
	CONSUMABLE,
	KEY_ITEM,
}

enum PanelKind {
	HIDDEN,
	WEAPON,
	ITEM,
}

@export var entry_id: StringName = &""
@export var display_name: String = "Inventory Entry"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var kind: EntryKind = EntryKind.CONSUMABLE
@export var panel: PanelKind = PanelKind.ITEM
@export var selection_order: int = 0
@export_range(1, 999, 1) var maximum_quantity: int = 1
@export var selectable: bool = true

@export_category("Weapon / Ammunition")
@export var weapon_definition: WeaponDefinition
@export var ammo_type: StringName = &""

@export_category("Item Effect / Access")
@export var effect_id: StringName = &""
@export_range(0.0, 1000.0, 0.5) var effect_amount: float = 0.0
@export var access_level: StringName = &""


func is_valid_definition() -> bool:
	if entry_id.is_empty() or maximum_quantity <= 0:
		return false
	match kind:
		EntryKind.WEAPON:
			return weapon_definition != null and weapon_definition.is_valid_definition()
		EntryKind.AMMUNITION:
			return not ammo_type.is_empty()
		EntryKind.CONSUMABLE:
			return not effect_id.is_empty() and effect_amount > 0.0
		EntryKind.KEY_ITEM:
			return not access_level.is_empty()
	return false

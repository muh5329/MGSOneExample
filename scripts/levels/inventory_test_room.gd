class_name InventoryTestRoom
extends Node3D

@export var seed_for_demo: bool = true

@onready var player: PlayerController = %Player
@onready var camera_rig: GameplayCameraRig = %GameplayCameraRig
@onready var health_recipient: InventoryTestHealthRecipient = %HealthRecipient
@onready var panels: InventoryPanels = %InventoryPanels
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	var inventory := player.get_node("Inventory") as InventoryComponent
	var weapon := player.get_node("WeaponController") as WeaponController
	weapon.set_combat_owner(player)
	weapon.set_aim_provider(camera_rig)
	camera_rig.set_tracked_actor(player)
	camera_rig.reset_camera_state()
	panels.configure(inventory, player, camera_rig, weapon, null, health_recipient)
	inventory.transaction_completed.connect(_on_transaction)
	health_recipient.health_changed.connect(_on_health_changed)
	if seed_for_demo and inventory.get_count(&"W1_PISTOL") == 0:
		inventory.add_entry(&"W1_PISTOL", 1)
		inventory.add_entry(&"A1_PISTOL_AMMO", 12)
		inventory.add_entry(&"I1_RATION", 1)
		inventory.add_entry(&"K1_LEVEL_1_CARD", 1)
		inventory.request_equip_weapon(&"W1_PISTOL", 8)
		inventory.request_equip_item(&"I1_RATION")
	_update_status("HOLD Q/LB OR E/RB — G/Y QUICK-USES THE EQUIPPED RATION")


func _on_transaction(result: Dictionary) -> void:
	_update_status("%s — %s (%d)" % [result.entry_id, result.reason, result.changed])


func _on_health_changed(current: float, maximum: float) -> void:
	_update_status("RATION APPLIED — HEALTH %.0f / %.0f" % [current, maximum])


func _update_status(message: String) -> void:
	status_label.text = "%s\nHEALTH  %.0f / %.0f" % [message, health_recipient.health, health_recipient.maximum_health]

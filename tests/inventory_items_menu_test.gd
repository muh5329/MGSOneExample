extends SceneTree

const TEST_ROOM_PATH := "res://scenes/levels/inventory_test_room.tscn"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(TEST_ROOM_PATH) as PackedScene
	if packed == null:
		failures.append("Inventory test room does not load.")
		_finish()
		return
	var room := packed.instantiate() as InventoryTestRoom
	room.seed_for_demo = false
	get_root().add_child(room)
	await process_frame
	var player := room.player
	var inventory := player.get_node("Inventory") as InventoryComponent
	var weapon := player.get_node("VisualRoot/WeaponController") as WeaponController
	var panels := room.panels
	var health := room.health_recipient
	_reset_inventory(inventory)

	_validate_catalog_and_capacity(inventory)
	_reset_inventory(inventory)
	_validate_pickup_transactions(inventory, player)
	_reset_inventory(inventory)
	_validate_equipment_and_ammo(inventory, weapon)
	_reset_inventory(inventory)
	_validate_ration_and_access(inventory, health)
	_reset_inventory(inventory)
	_validate_snapshot_restore(inventory, weapon)
	await _validate_panels_and_mode_nesting(inventory, panels, player, weapon)

	room.queue_free()
	await process_frame
	_finish()


func _reset_inventory(inventory: InventoryComponent) -> void:
	inventory.set_control_enabled(true)
	var quantities := {}
	for entry_id in [&"W1_PISTOL", &"A1_PISTOL_AMMO", &"I1_RATION", &"K1_LEVEL_1_CARD"]:
		quantities[entry_id] = 0
	var result := inventory.restore_checkpoint_snapshot({
		&"quantities": quantities,
		&"equipped_weapon_id": &"",
		&"equipped_item_id": &"",
		&"weapon_runtime": {},
	})
	if not bool(result.accepted):
		failures.append("Valid empty inventory reset snapshot was rejected.")


func _validate_catalog_and_capacity(inventory: InventoryComponent) -> void:
	for entry_id in [&"W1_PISTOL", &"A1_PISTOL_AMMO", &"I1_RATION", &"K1_LEVEL_1_CARD"]:
		var definition := inventory.get_definition(entry_id)
		if definition == null or not definition.is_valid_definition():
			failures.append("Inventory definition '%s' is absent or invalid." % entry_id)
	var weapon_entries := inventory.get_selection_snapshot(InventoryEntryDefinition.PanelKind.WEAPON)
	var item_entries := inventory.get_selection_snapshot(InventoryEntryDefinition.PanelKind.ITEM)
	if weapon_entries.size() != 1 or weapon_entries[0].entry_id != &"W1_PISTOL":
		failures.append("Weapon selection ordering is not stable at zero quantity.")
	if item_entries.size() != 2 or item_entries[0].entry_id != &"I1_RATION" or item_entries[1].entry_id != &"K1_LEVEL_1_CARD":
		failures.append("Item/access selection ordering is not stable at zero quantity.")
	var add_result := inventory.add_entry(&"A1_PISTOL_AMMO", 30)
	if int(add_result.code) != InventoryComponent.TransactionCode.PARTIAL or int(add_result.changed) != 24 or inventory.get_count(&"A1_PISTOL_AMMO") != 24:
		failures.append("Ammo capacity did not clamp a 30-round request to the 24-round cap.")
	var full_result := inventory.add_entry(&"A1_PISTOL_AMMO", 1)
	if bool(full_result.accepted) or full_result.reason != &"INVENTORY_FULL" or inventory.get_count(&"A1_PISTOL_AMMO") != 24:
		failures.append("Full ammo inventory accepted or mutated a failed transaction.")
	var remove_result := inventory.remove_entry(&"A1_PISTOL_AMMO", 30)
	if int(remove_result.changed) != 24 or inventory.get_count(&"A1_PISTOL_AMMO") != 0:
		failures.append("Oversized removal did not clamp at zero.")
	if bool(inventory.remove_entry(&"A1_PISTOL_AMMO", 1).accepted) or bool(inventory.add_entry(&"I1_RATION", -1).accepted):
		failures.append("Empty removal or negative add was accepted.")


func _validate_pickup_transactions(inventory: InventoryComponent, player: PlayerController) -> void:
	inventory.add_entry(&"I1_RATION", 1)
	var pickup := InventoryPickup3D.new()
	pickup.inventory_entry_id = &"I1_RATION"
	pickup.event_id = &"I1_RATION"
	pickup.interaction_id = &"TEST_RATION_PICKUP"
	pickup.quantity = 1
	pickup.set_inventory(inventory)
	get_root().add_child(pickup)
	if pickup.interact(player) or pickup.is_consumed() or pickup.quantity != 1:
		failures.append("Failed full-capacity pickup was consumed or changed.")
	inventory.remove_entry(&"I1_RATION", 1)
	if not pickup.interact(player) or not pickup.is_consumed() or inventory.get_count(&"I1_RATION") != 1:
		failures.append("Successful pickup did not commit once and consume its world object.")
	if pickup.interact(player) or inventory.get_count(&"I1_RATION") != 1:
		failures.append("Consumed pickup duplicated its transaction.")
	pickup.queue_free()


func _validate_equipment_and_ammo(inventory: InventoryComponent, weapon: WeaponController) -> void:
	inventory.add_entry(&"W1_PISTOL", 1)
	inventory.add_entry(&"A1_PISTOL_AMMO", 12)
	var equip := inventory.request_equip_weapon(&"W1_PISTOL", 8)
	weapon.advance_runtime(1.0)
	if not bool(equip.accepted) or inventory.equipped_weapon_id != &"W1_PISTOL" or weapon.magazine != 8:
		failures.append("Owned W1 did not become the authoritative equipped weapon with its loaded magazine.")
	weapon.restore_runtime({&"weapon_id": &"W1_PISTOL", &"magazine": 3, &"equipped": true})
	if not weapon.request_reload():
		failures.append("Equipment-switch test could not start a reload.")
	var reserve_before := inventory.get_ammo_count(&"pistol_round")
	inventory.request_equip_weapon(&"W1_PISTOL")
	if weapon.state != WeaponController.WeaponState.EQUIPPING or inventory.get_ammo_count(&"pistol_round") != reserve_before or weapon.magazine != 3:
		failures.append("Equipment selection did not cancel reload without consuming inventory ammo.")
	weapon.advance_runtime(1.0)
	weapon.request_reload()
	weapon.advance_runtime(2.0)
	if weapon.magazine != 8 or inventory.get_count(&"A1_PISTOL_AMMO") != 7:
		failures.append("Weapon reload did not use the inventory's atomic ammo transaction boundary.")
	inventory.remove_entry(&"W1_PISTOL", 1)
	if not inventory.equipped_weapon_id.is_empty() or weapon.state != WeaponController.WeaponState.HOLSTERED:
		failures.append("Removing the final owned weapon left an invalid equipped reference.")


func _validate_ration_and_access(inventory: InventoryComponent, health: InventoryTestHealthRecipient) -> void:
	inventory.add_entry(&"I1_RATION", 1)
	inventory.request_equip_item(&"I1_RATION")
	health.health = 70.0
	var use_result := inventory.request_quick_use(health)
	if not bool(use_result.accepted) or health.health != 100.0 or inventory.get_count(&"I1_RATION") != 0 or not inventory.equipped_item_id.is_empty():
		failures.append("Ration did not heal through the recipient contract, clamp at maximum, and consume exactly once.")
	inventory.add_entry(&"I1_RATION", 1)
	inventory.request_equip_item(&"I1_RATION")
	var full_result := inventory.request_quick_use(health)
	if bool(full_result.accepted) or full_result.reason != &"FULL_HEALTH" or inventory.get_count(&"I1_RATION") != 1:
		failures.append("Full-health ration request consumed inventory or hid its rejection reason.")
	if inventory.has_access_level(&"LEVEL_1"):
		failures.append("Access level was granted before K1 ownership.")
	inventory.add_entry(&"K1_LEVEL_1_CARD", 1)
	if not inventory.has_access_level(&"LEVEL_1") or bool(inventory.request_equip_item(&"K1_LEVEL_1_CARD").accepted):
		failures.append("K1 possession and non-consumable selection rules disagree.")


func _validate_snapshot_restore(inventory: InventoryComponent, weapon: WeaponController) -> void:
	inventory.add_entry(&"W1_PISTOL", 1)
	inventory.add_entry(&"A1_PISTOL_AMMO", 9)
	inventory.add_entry(&"I1_RATION", 1)
	inventory.add_entry(&"K1_LEVEL_1_CARD", 1)
	inventory.request_equip_weapon(&"W1_PISTOL", 3)
	weapon.advance_runtime(1.0)
	inventory.request_equip_item(&"I1_RATION")
	var checkpoint := inventory.get_checkpoint_snapshot()
	inventory.take_ammo(&"pistol_round", 9)
	inventory.remove_entry(&"I1_RATION", 1)
	inventory.remove_entry(&"K1_LEVEL_1_CARD", 1)
	weapon.restore_runtime({&"weapon_id": &"W1_PISTOL", &"magazine": 0, &"equipped": false})
	var restored := inventory.restore_checkpoint_snapshot(checkpoint)
	if not bool(restored.accepted) or inventory.get_count(&"A1_PISTOL_AMMO") != 9 or inventory.get_count(&"I1_RATION") != 1 or not inventory.has_access_level(&"LEVEL_1"):
		failures.append("Checkpoint snapshot did not reproduce quantities/access exactly.")
	if inventory.equipped_weapon_id != &"W1_PISTOL" or inventory.equipped_item_id != &"I1_RATION" or weapon.magazine != 3 or weapon.state != WeaponController.WeaponState.READY:
		failures.append("Checkpoint snapshot did not reproduce equipment and weapon runtime exactly.")
	(checkpoint.quantities as Dictionary)[&"A1_PISTOL_AMMO"] = 0
	if inventory.get_count(&"A1_PISTOL_AMMO") != 9:
		failures.append("External snapshot mutation changed authoritative inventory state.")
	var invalid := inventory.restore_checkpoint_snapshot({
		&"quantities": {&"A1_PISTOL_AMMO": 99},
		&"equipped_weapon_id": &"",
		&"equipped_item_id": &"",
	})
	if bool(invalid.accepted) or inventory.get_count(&"A1_PISTOL_AMMO") != 9:
		failures.append("Invalid checkpoint snapshot partially mutated inventory.")


func _validate_panels_and_mode_nesting(
	inventory: InventoryComponent,
	panels: InventoryPanels,
	player: PlayerController,
	weapon: WeaponController
) -> void:
	if not panels.open_panel(InventoryPanels.PanelKind.ITEM):
		failures.append("Item panel did not open through its public controller path.")
	if player.get_control_locks() & PlayerController.ControlLock.MENU == 0 or weapon.control_enabled or not panels.item_panel.visible:
		failures.append("Open panel did not own the menu lock, weapon gate, and visible state together.")
	var first := panels.get_selected_entry_id()
	panels.update_navigation_repeat(1, 0.0)
	var second := panels.get_selected_entry_id()
	panels.update_navigation_repeat(1, panels.repeat_delay + 0.01)
	if first == second or panels.get_selected_entry_id() == second:
		failures.append("Held keyboard/controller navigation did not apply deterministic repeat steps.")
	panels.close_panel(false)
	if player.get_control_locks() & PlayerController.ControlLock.MENU != 0 or not weapon.control_enabled or panels.item_panel.visible:
		failures.append("Closing a panel did not restore gameplay input cleanly.")
	panels.open_panel(InventoryPanels.PanelKind.WEAPON)
	var game_state := get_root().get_node("GameState")
	game_state.call(&"set_paused", true)
	if panels.active_panel != InventoryPanels.PanelKind.NONE or player.get_control_locks() & PlayerController.ControlLock.MENU != 0:
		failures.append("Pause nesting did not close the held inventory panel before pausing.")
	game_state.call(&"set_paused", false)
	await process_frame
	panels.open_panel(InventoryPanels.PanelKind.ITEM)
	game_state.call(&"set_phase", 3)
	if panels.active_panel != InventoryPanels.PanelKind.NONE or inventory.control_enabled:
		failures.append("Death phase did not close panels and reject inventory controls.")
	game_state.call(&"reset_for_new_mission")
	if not inventory.control_enabled:
		failures.append("Returning to PLAYING did not restore inventory request authority.")


func _finish() -> void:
	get_root().get_node("GameState").call(&"set_paused", false)
	get_root().get_node("GameState").call(&"reset_for_new_mission")
	if failures.is_empty():
		print("INVENTORY PASS: transactions, pickups, equipment, ration/access, panels, pause/death, repeat, and snapshots are valid.")
		quit(0)
		return
	for failure in failures:
		push_error("INVENTORY FAIL: %s" % failure)
	quit(1)

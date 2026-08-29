extends SceneTree

const TEST_ROOM_PATH := "res://scenes/levels/health_game_state_test_room.tscn"

class ResetProbe:
	extends Node
	var reset_count: int = 0
	var last_checkpoint_id: StringName = &""

	func reset_transient_state(checkpoint_id: StringName) -> void:
		reset_count += 1
		last_checkpoint_id = checkpoint_id


var failures: Array[String] = []
var _health_death_count: int = 0
var _observed_zero_health_as_alive: bool = false
var _mission_completion_count: int = 0
var _checkpoint_restore_count: int = 0
var _snapshot_failure_count: int = 0
var _last_failure: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _validate_health_contract()
	_validate_game_state_contract()
	await _validate_mission_checkpoint_contract()
	_finish()


func _validate_health_contract() -> void:
	var health := HealthComponent.new()
	health.maximum_health = 100.0
	health.starting_health = 100.0
	health.damage_invulnerability_duration = 0.25
	get_root().add_child(health)
	health.died.connect(func(_context: HitContext3D) -> void: _health_death_count += 1)
	health.health_changed.connect(func(_previous: float, current: float, _maximum: float) -> void:
		if current <= 0.0 and not health.is_dead:
			_observed_zero_health_as_alive = true
	)
	var context := HitContext3D.new(
		null, &"TEST", 1, Vector3.ZERO, Vector3.UP, Vector3.FORWARD, 30.0, PackedStringArray()
	)
	if health.receive_damage(NAN, context) or not is_equal_approx(health.current_health, 100.0):
		failures.append("Health accepted non-finite damage or corrupted its bounds.")
	if not health.receive_damage(30.0, context) or not is_equal_approx(health.current_health, 70.0):
		failures.append("Health did not apply contextual damage within bounds.")
	if health.receive_damage(30.0, context) or not is_equal_approx(health.current_health, 70.0):
		failures.append("Health invulnerability did not reject a burst without mutation.")
	health.advance_runtime(0.25)
	if health.heal(INF) or not is_equal_approx(health.current_health, 70.0):
		failures.append("Health accepted non-finite healing or corrupted its bounds.")
	if not health.heal(50.0) or not is_equal_approx(health.current_health, 100.0) or health.heal(1.0):
		failures.append("Healing did not clamp at maximum or reject a full-health request.")
	if not health.receive_damage(150.0, context) or not health.is_dead or not is_zero_approx(health.current_health):
		failures.append("Lethal damage did not commit a dead, zero-health state.")
	if _observed_zero_health_as_alive:
		failures.append("A lethal health signal exposed zero health while the recipient was still alive.")
	if health.receive_damage(1.0, context) or health.heal(50.0) or _health_death_count != 1:
		failures.append("Dead health accepted mutation or emitted duplicate death.")
	var full_snapshot := health.get_checkpoint_snapshot(true)
	if not health.restore_checkpoint_snapshot(full_snapshot) or health.is_dead or not is_equal_approx(health.current_health, 100.0):
		failures.append("Health checkpoint restore did not revive to the normalized full-health state.")
	if health.validate_checkpoint_snapshot({&"current_health": 101.0, &"maximum_health": 100.0, &"is_dead": false}):
		failures.append("Health accepted an out-of-range checkpoint snapshot.")
	health.queue_free()
	await process_frame


func _validate_game_state_contract() -> void:
	var game_state := get_root().get_node("GameState")
	game_state.call(&"reset_for_new_mission")
	if bool(game_state.call(&"set_phase", GameState.MissionPhase.PAUSED)):
		failures.append("GameState allowed PAUSED without synchronizing SceneTree pause authority.")
	if not bool(game_state.call(&"set_paused", true)) or not paused or game_state.phase != GameState.MissionPhase.PAUSED:
		failures.append("GameState did not enter the authoritative paused state.")
	if not bool(game_state.call(&"set_paused", true)):
		failures.append("Repeated pause requests were not idempotent.")
	if bool(game_state.call(&"request_completion")):
		failures.append("GameState accepted mission completion while paused.")
	if not bool(game_state.call(&"set_paused", false)) or paused or game_state.phase != GameState.MissionPhase.PLAYING:
		failures.append("GameState did not resume phase and SceneTree together.")


func _validate_mission_checkpoint_contract() -> void:
	var packed := load(TEST_ROOM_PATH) as PackedScene
	if packed == null:
		failures.append("Health/game-state test room does not load.")
		return
	var room := packed.instantiate()
	get_root().add_child(room)
	await process_frame
	var level := room.get_node("Substation6") as Substation6
	var player := level.player
	var health := player.health
	var inventory := level.inventory
	var weapon := player.get_node("WeaponController") as WeaponController
	var coordinator := level.mission_state
	var d0 := level.mission_root.get_node("D0_SUPPLY_CAGE") as Door3D
	var d1 := level.mission_root.get_node("D1_ACCESS") as Door3D
	var d2 := level.mission_root.get_node("D2_SHORTCUT") as Door3D
	var pistol := level.mission_root.get_node("W1_PISTOL") as InventoryPickup3D
	var ammo := level.mission_root.get_node("A1_PISTOL_AMMO") as InventoryPickup3D
	var ration := level.mission_root.get_node("I1_RATION") as InventoryPickup3D
	var card := level.mission_root.get_node("K1_LEVEL_1_CARD") as InventoryPickup3D
	var objective := level.mission_root.get_node("O1_RELAY_TERMINAL") as MissionMarker3D
	var extraction := level.mission_root.get_node("X1_DRAINAGE_GATE") as MissionMarker3D
	coordinator.mission_completed.connect(func(_id: StringName) -> void: _mission_completion_count += 1)
	coordinator.checkpoint_restore_completed.connect(func(_id: StringName) -> void: _checkpoint_restore_count += 1)
	coordinator.snapshot_failure.connect(_on_snapshot_failure)

	if coordinator.active_checkpoint_id != MissionStateCoordinator.CP0_ID:
		failures.append("Mission did not initialize with the stable CP0 identifier.")
	if extraction.interact(player) or get_root().get_node("GameState").phase != GameState.MissionPhase.PLAYING:
		failures.append("Extraction succeeded before the objective requirement.")
	if coordinator.register_door(d1):
		failures.append("Mission coordinator accepted a duplicate stable door ID.")
	if _snapshot_failure_count != 1 or _last_failure.stable_id != &"D1_ACCESS" or _last_failure.reason != &"DUPLICATE_OR_INVALID_ID":
		failures.append("Duplicate stable-ID failure did not identify the affected door deterministically.")

	# Restart once from the weaponless CP0 snapshot to prove disabled combat state is recoverable.
	if not player.receive_damage(health.maximum_health, null):
		failures.append("Player did not accept lethal damage through its production health receiver.")
	coordinator.advance_death_sequence(coordinator.death_hold_duration)
	if get_root().get_node("GameState").phase != GameState.MissionPhase.PLAYING or weapon.state != WeaponController.WeaponState.HOLSTERED:
		failures.append("Weaponless CP0 restart did not restore PLAYING with an enabled holstered weapon runtime.")
	if not pistol.interact(player):
		failures.append("W1 could not be acquired after a weaponless checkpoint restart.")
	weapon.advance_runtime(1.0)
	if inventory.equipped_weapon_id != &"W1_PISTOL" or weapon.state != WeaponController.WeaponState.READY or weapon.magazine != 8:
		failures.append("Post-restart W1 auto-equip left combat disabled or restored the wrong magazine.")

	if not ration.interact(player) or not card.interact(player):
		failures.append("CP1 setup pickups did not transact through inventory.")
	if not d1.interactable.interact(player) or d1.is_locked or not d1.is_open:
		failures.append("CP1 setup could not unlock D1 with the persistent access card.")
	var checkpoint_transform := Transform3D(Basis.IDENTITY, Vector3(20.0, 0.02, -16.0))
	player.global_transform = checkpoint_transform
	if not coordinator.activate_checkpoint(MissionStateCoordinator.CP1_ID, player):
		failures.append("CP1 rejected activation after D1 was unlocked.")
	var checkpoint := coordinator.get_checkpoint_snapshot()
	if checkpoint.checkpoint_id != MissionStateCoordinator.CP1_ID or not bool(coordinator.validate_checkpoint_snapshot(checkpoint).accepted):
		failures.append("Captured CP1 snapshot did not validate against registered stable IDs.")
	if not is_equal_approx(float(checkpoint.health.current_health), health.maximum_health):
		failures.append("CP1 did not record the documented full-health restart policy.")

	# Mutate every persistent subsystem after CP1; restart must reproduce the snapshot exactly.
	if not ammo.interact(player) or inventory.get_count(&"A1_PISTOL_AMMO") != 12:
		failures.append("Post-checkpoint ammo mutation failed.")
	d0.set_open(true)
	if not objective.interact(player) or not coordinator.objective_complete or not d2.is_open:
		failures.append("Objective completion did not open the shortcut before restart testing.")
	health.receive_damage(40.0, null)
	inventory.request_equip_item(&"I1_RATION")
	var ration_result := inventory.request_quick_use(player)
	if not bool(ration_result.accepted) or inventory.get_count(&"I1_RATION") != 0 or not is_equal_approx(health.current_health, 100.0):
		failures.append("Production ration healing did not clamp and consume exactly once.")
	level.inventory_panels.open_panel(InventoryPanels.PanelKind.ITEM)
	var reset_probe := ResetProbe.new()
	reset_probe.add_to_group(&"checkpoint_reset_targets")
	get_root().add_child(reset_probe)
	var disposable := Node.new()
	disposable.add_to_group(&"checkpoint_disposable")
	get_root().add_child(disposable)
	if not player.receive_damage(health.maximum_health, null):
		failures.append("Lethal mission damage was rejected during the CP1 mutation test.")
	if get_root().get_node("GameState").phase != GameState.MissionPhase.PLAYER_DEAD:
		failures.append("Player death did not move the sole mission authority to PLAYER_DEAD.")
	if level.inventory_panels.active_panel != InventoryPanels.PanelKind.NONE or inventory.control_enabled:
		failures.append("Death did not close modal inventory and lock item transactions.")
	if objective.interact(player) or not coordinator.objective_complete:
		failures.append("Death-first event ordering accepted a new objective action or corrupted prior objective state.")
	coordinator.advance_death_sequence(coordinator.death_hold_duration)
	await process_frame
	if get_root().get_node("GameState").phase != GameState.MissionPhase.PLAYING or paused:
		failures.append("CP1 restart did not return phase and SceneTree to active play together.")
	if health.is_dead or not is_equal_approx(health.current_health, health.maximum_health):
		failures.append("CP1 restart did not revive the player at full health.")
	if player.global_position.distance_to(checkpoint_transform.origin) > 0.01:
		failures.append("CP1 restart did not restore the captured player transform.")
	if inventory.get_count(&"A1_PISTOL_AMMO") != 0 or inventory.get_count(&"I1_RATION") != 1 or not inventory.has_access_level(&"LEVEL_1"):
		failures.append("CP1 restart did not restore inventory/access quantities exactly.")
	if ammo.quantity != 12 or ammo.is_consumed() or not d1.is_open or d1.is_locked or d0.is_open:
		failures.append("CP1 restart did not restore pickup and door snapshots exactly.")
	if coordinator.objective_complete or objective.is_consumed() or d2.is_open or not d2.is_locked:
		failures.append("CP1 restart retained post-checkpoint objective or shortcut state.")
	if player.get_control_locks() & PlayerController.ControlLock.DEATH != 0 or not inventory.control_enabled or not weapon.control_enabled:
		failures.append("CP1 restart left terminal player, inventory, or combat controls locked.")
	if reset_probe.reset_count != 1 or reset_probe.last_checkpoint_id != MissionStateCoordinator.CP1_ID or is_instance_valid(disposable):
		failures.append("Restart did not reset registered transients and dispose ephemeral effects.")

	# A paused lethal request resolves to death, unpauses once, and remains repeatable.
	var game_state := get_root().get_node("GameState")
	game_state.call(&"set_paused", true)
	if not player.receive_damage(health.maximum_health, null):
		failures.append("Paused lethal request did not reach the deterministic death transition.")
	if paused or game_state.phase != GameState.MissionPhase.PLAYER_DEAD:
		failures.append("Death while paused left SceneTree and mission phase contradictory.")
	coordinator.advance_death_sequence(coordinator.death_hold_duration)
	if _checkpoint_restore_count != 3 or reset_probe.reset_count != 2:
		failures.append("Repeated checkpoint restart duplicated or skipped restore/reset events.")

	var invalid_snapshot := coordinator.get_checkpoint_snapshot()
	(invalid_snapshot.doors as Dictionary)[&"D1_ACCESS"] = {
		&"door_id": &"WRONG_ID", &"is_open": true, &"is_locked": false,
	}
	var invalid_result := coordinator.validate_checkpoint_snapshot(invalid_snapshot)
	if bool(invalid_result.accepted) or invalid_result.subsystem != &"door" or invalid_result.stable_id != &"D1_ACCESS":
		failures.append("Invalid snapshot did not report the stable subsystem and ID without mutation.")
	var missing_runtime_snapshot := coordinator.get_checkpoint_snapshot()
	(missing_runtime_snapshot.inventory as Dictionary)[&"weapon_runtime"] = {}
	var missing_runtime_result := coordinator.validate_checkpoint_snapshot(missing_runtime_snapshot)
	if bool(missing_runtime_result.accepted) or missing_runtime_result.subsystem != &"inventory" or missing_runtime_result.stable_id != &"W1_PISTOL":
		failures.append("Equipped-weapon snapshot accepted a missing combat runtime payload.")

	# Objective-first ordering may enter PLAYER_DEAD, but restart removes uncheckpointed progress.
	if not objective.interact(player) or not coordinator.objective_complete:
		failures.append("Objective-first ordering could not commit the valid objective event.")
	player.receive_damage(health.maximum_health, null)
	if game_state.phase != GameState.MissionPhase.PLAYER_DEAD or not coordinator.objective_complete:
		failures.append("Objective-first lethal ordering produced an inconsistent immediate state.")
	coordinator.advance_death_sequence(coordinator.death_hold_duration)
	if coordinator.objective_complete or objective.is_consumed():
		failures.append("Restart retained objective progress that was not in the active checkpoint.")

	if not objective.interact(player) or not extraction.interact(player):
		failures.append("Valid objective and extraction sequence did not complete the mission.")
	if game_state.phase != GameState.MissionPhase.COMPLETED or _mission_completion_count != 1:
		failures.append("Mission completion was not a single authoritative terminal transition.")
	if extraction.interact(player) or _mission_completion_count != 1 or player.receive_damage(1.0, null):
		failures.append("Completed mission accepted duplicate extraction or further player damage.")

	reset_probe.queue_free()
	room.queue_free()
	await process_frame


func _on_snapshot_failure(
	_checkpoint_id: StringName,
	subsystem: StringName,
	stable_id: StringName,
	reason: StringName
) -> void:
	_snapshot_failure_count += 1
	_last_failure = {
		&"subsystem": subsystem,
		&"stable_id": stable_id,
		&"reason": reason,
	}


func _finish() -> void:
	var game_state := get_root().get_node("GameState")
	if paused:
		game_state.call(&"set_paused", false)
	game_state.call(&"reset_for_new_mission")
	if failures.is_empty():
		print("HEALTH/STATE PASS: damage, healing, phases, checkpoints, restart, objective, extraction, and transient resets are valid.")
		quit(0)
		return
	for failure in failures:
		push_error("HEALTH/STATE FAIL: %s" % failure)
	quit(1)

class_name MissionStateCoordinator
extends Node

signal status_changed(message: String)
signal checkpoint_activated(checkpoint_id: StringName, snapshot: Dictionary)
signal checkpoint_restore_started(checkpoint_id: StringName)
signal checkpoint_restore_completed(checkpoint_id: StringName)
signal snapshot_failure(checkpoint_id: StringName, subsystem: StringName, stable_id: StringName, reason: StringName)
signal objective_completed(objective_id: StringName)
signal extraction_rejected(extraction_id: StringName, reason: StringName)
signal mission_completed(extraction_id: StringName)
signal transient_reset_requested(checkpoint_id: StringName)

const SNAPSHOT_VERSION := 1
const CP0_ID := &"CP0_INSERTION"
const CP1_ID := &"CP1_SWITCH_ENTRY"
const OBJECTIVE_ID := &"O1_RELAY_TERMINAL"
const EXTRACTION_ID := &"X1_DRAINAGE_GATE"
const GAME_PHASE_PLAYING := 1
const GAME_PHASE_PAUSED := 2
const GAME_PHASE_PLAYER_DEAD := 3

@export_range(0.0, 10.0, 0.05, "suffix:s") var death_hold_duration: float = 1.5

var objective_complete: bool = false
var active_checkpoint_id: StringName = &""
var death_time_remaining: float = 0.0

var _checkpoint_snapshot: Dictionary = {}
var _markers: Dictionary = {}
var _triggers: Dictionary = {}
var _doors: Dictionary = {}
var _pickups: Dictionary = {}
var _access_door: Door3D
var _shortcut_door: Door3D
var _objective_marker: MissionMarker3D
var _extraction: MissionMarker3D
var _camera_rig: GameplayCameraRig
var _inventory: InventoryComponent
var _player: PlayerController
var _health: HealthComponent
var _weapon: WeaponController
var _interaction_focus: InteractionFocus3D
var _game_state: Node


func _ready() -> void:
	_game_state = get_node_or_null("/root/GameState")
	set_process(false)


func _process(delta: float) -> void:
	advance_death_sequence(delta)


func configure(
		access_door: Door3D,
		shortcut_door: Door3D,
		objective_marker: MissionMarker3D,
		extraction: MissionMarker3D,
		camera_rig: GameplayCameraRig,
		inventory: InventoryComponent,
		actor: PlayerController,
		health: HealthComponent,
		interaction_focus: InteractionFocus3D = null
) -> bool:
	if (
		access_door == null or shortcut_door == null or objective_marker == null
		or extraction == null or camera_rig == null or inventory == null
		or actor == null or health == null
	):
		_emit_snapshot_failure(&"", &"coordinator", &"configuration", &"MISSING_DEPENDENCY")
		return false
	_access_door = access_door
	_shortcut_door = shortcut_door
	_objective_marker = objective_marker
	_extraction = extraction
	_camera_rig = camera_rig
	_inventory = inventory
	_player = actor
	_health = health
	_interaction_focus = interaction_focus
	_game_state = get_node_or_null("/root/GameState")
	if _game_state == null:
		_emit_snapshot_failure(&"", &"game_state", &"autoload", &"MISSING_DEPENDENCY")
		return false
	_weapon = actor.get_node_or_null("VisualRoot/WeaponController") as WeaponController
	if _weapon != null:
		_weapon.set_combat_owner(actor)
		_weapon.set_aim_provider(_camera_rig)
		_inventory.set_weapon_controller(_weapon)
	_access_door.set_access_query(_query_access)
	_objective_marker.availability_query = func(_actor: Node) -> bool:
		return not objective_complete and not _health.is_dead and _current_phase() == GAME_PHASE_PLAYING
	_objective_marker.reason_query = func(_actor: Node) -> StringName:
		return &"ALREADY_COMPLETED" if objective_complete else &"CONTROL_LOCKED"
	_extraction.availability_query = func(_actor: Node) -> bool:
		return objective_complete and _current_phase() == GAME_PHASE_PLAYING
	_extraction.reason_query = func(_actor: Node) -> StringName:
		return &"OBJECTIVE_INCOMPLETE" if not objective_complete else &"CONTROL_LOCKED"
	if not _health.died.is_connected(_on_player_died):
		_health.died.connect(_on_player_died)
	return true


func initialize_mission(initial_checkpoint_id: StringName = CP0_ID) -> bool:
	if not _is_configured() or not _triggers.has(initial_checkpoint_id):
		_emit_snapshot_failure(initial_checkpoint_id, &"checkpoint", initial_checkpoint_id, &"UNKNOWN_CHECKPOINT_ID")
		return false
	_game_state.call(&"reset_for_new_mission")
	objective_complete = false
	_health.set_damage_enabled(true)
	_set_terminal_controls(false)
	return activate_checkpoint(initial_checkpoint_id, _player)


func register_marker(marker: MissionMarker3D) -> bool:
	if marker == null or marker.event_id.is_empty() or _markers.has(marker.event_id):
		_emit_snapshot_failure(&"", &"marker", marker.event_id if marker != null else &"", &"DUPLICATE_OR_INVALID_ID")
		return false
	_markers[marker.event_id] = marker
	if marker is InventoryPickup3D:
		_pickups[marker.event_id] = marker
	marker.mission_event.connect(_on_mission_event)
	return true


func register_trigger(trigger: MissionTrigger3D) -> bool:
	if trigger == null or trigger.trigger_id.is_empty() or _triggers.has(trigger.trigger_id):
		_emit_snapshot_failure(&"", &"checkpoint", trigger.trigger_id if trigger != null else &"", &"DUPLICATE_OR_INVALID_ID")
		return false
	_triggers[trigger.trigger_id] = trigger
	trigger.triggered.connect(_on_triggered)
	return true


func register_door(door: Door3D) -> bool:
	if door == null or door.door_id.is_empty() or _doors.has(door.door_id):
		_emit_snapshot_failure(&"", &"door", door.door_id if door != null else &"", &"DUPLICATE_OR_INVALID_ID")
		return false
	_doors[door.door_id] = door
	return true


func activate_checkpoint(checkpoint_id: StringName, _actor: Node3D = null) -> bool:
	if _current_phase() != GAME_PHASE_PLAYING or not _triggers.has(checkpoint_id):
		return false
	if checkpoint_id == CP1_ID and (_access_door == null or _access_door.is_locked):
		return false
	if checkpoint_id == active_checkpoint_id and not _checkpoint_snapshot.is_empty():
		return true
	var next_snapshot := _capture_checkpoint_snapshot(checkpoint_id)
	var validation := validate_checkpoint_snapshot(next_snapshot)
	if not bool(validation.accepted):
		_emit_snapshot_failure(checkpoint_id, validation.subsystem, validation.stable_id, validation.reason)
		return false
	active_checkpoint_id = checkpoint_id
	_checkpoint_snapshot = next_snapshot
	checkpoint_activated.emit(checkpoint_id, _checkpoint_snapshot.duplicate(true))
	status_changed.emit("CHECKPOINT ACTIVE: %s" % checkpoint_id)
	return true


func get_checkpoint_snapshot() -> Dictionary:
	return _checkpoint_snapshot.duplicate(true)


func validate_checkpoint_snapshot(snapshot: Dictionary) -> Dictionary:
	if int(snapshot.get(&"version", -1)) != SNAPSHOT_VERSION:
		return _result(false, &"snapshot", &"version", &"UNSUPPORTED_SNAPSHOT_VERSION")
	var checkpoint_id := StringName(snapshot.get(&"checkpoint_id", &""))
	if checkpoint_id.is_empty() or not _triggers.has(checkpoint_id):
		return _result(false, &"checkpoint", checkpoint_id, &"UNKNOWN_CHECKPOINT_ID")
	if typeof(snapshot.get(&"player_transform", null)) != TYPE_TRANSFORM3D:
		return _result(false, &"player", &"transform", &"INVALID_PLAYER_TRANSFORM")
	var player_stance := int(snapshot.get(&"player_stance", -1))
	if player_stance not in [PlayerController.Stance.STANDING, PlayerController.Stance.CROUCHED]:
		return _result(false, &"player", &"stance", &"INVALID_PLAYER_STANCE")
	var health_snapshot: Variant = snapshot.get(&"health", null)
	if not health_snapshot is Dictionary or not _health.validate_checkpoint_snapshot(health_snapshot):
		return _result(false, &"health", &"player", &"INVALID_HEALTH_SNAPSHOT")
	if bool(health_snapshot.is_dead) or not is_equal_approx(float(health_snapshot.current_health), float(health_snapshot.maximum_health)):
		return _result(false, &"health", &"player", &"INVALID_RESTART_HEALTH_POLICY")
	var inventory_snapshot: Variant = snapshot.get(&"inventory", null)
	if not inventory_snapshot is Dictionary:
		return _result(false, &"inventory", &"player", &"INVALID_INVENTORY_SNAPSHOT")
	var inventory_validation := _inventory.validate_checkpoint_snapshot(inventory_snapshot)
	if not bool(inventory_validation.accepted):
		return _result(false, &"inventory", StringName(inventory_validation.entry_id), StringName(inventory_validation.reason))
	var door_snapshots: Variant = snapshot.get(&"doors", null)
	if not door_snapshots is Dictionary or (door_snapshots as Dictionary).size() != _doors.size():
		return _result(false, &"door", &"registry", &"DOOR_REGISTRY_MISMATCH")
	for door_id in door_snapshots:
		var door := _doors.get(StringName(door_id)) as Door3D
		if door == null:
			return _result(false, &"door", StringName(door_id), &"MISSING_STABLE_ID")
		if not door.validate_checkpoint_snapshot(door_snapshots[door_id]):
			return _result(false, &"door", StringName(door_id), &"INVALID_DOOR_SNAPSHOT")
	var pickup_snapshots: Variant = snapshot.get(&"pickups", null)
	if not pickup_snapshots is Dictionary or (pickup_snapshots as Dictionary).size() != _pickups.size():
		return _result(false, &"pickup", &"registry", &"PICKUP_REGISTRY_MISMATCH")
	for pickup_id in pickup_snapshots:
		var pickup := _pickups.get(StringName(pickup_id)) as InventoryPickup3D
		if pickup == null:
			return _result(false, &"pickup", StringName(pickup_id), &"MISSING_STABLE_ID")
		if not pickup.validate_checkpoint_snapshot(pickup_snapshots[pickup_id]):
			return _result(false, &"pickup", StringName(pickup_id), &"INVALID_PICKUP_SNAPSHOT")
	if typeof(snapshot.get(&"objective_complete", null)) != TYPE_BOOL:
		return _result(false, &"objective", OBJECTIVE_ID, &"INVALID_OBJECTIVE_STATE")
	if typeof(snapshot.get(&"objective_consumed", null)) != TYPE_BOOL:
		return _result(false, &"objective", OBJECTIVE_ID, &"INVALID_OBJECTIVE_STATE")
	if bool(snapshot.objective_complete) != bool(snapshot.objective_consumed):
		return _result(false, &"objective", OBJECTIVE_ID, &"OBJECTIVE_STATE_MISMATCH")
	var shortcut_snapshot: Dictionary = door_snapshots.get(_shortcut_door.door_id, {})
	var shortcut_matches_objective := (
		bool(shortcut_snapshot.get(&"is_open", false))
		and not bool(shortcut_snapshot.get(&"is_locked", true))
	) == bool(snapshot.objective_complete)
	if not shortcut_matches_objective:
		return _result(false, &"door", _shortcut_door.door_id, &"OBJECTIVE_DOOR_STATE_MISMATCH")
	if StringName(snapshot.get(&"transient_policy", &"")) != &"RESET_TO_AUTHORED_STATE":
		return _result(false, &"transient", &"policy", &"INVALID_TRANSIENT_POLICY")
	return _result(true)


func request_restart() -> Dictionary:
	if _current_phase() != GAME_PHASE_PLAYER_DEAD:
		return _result(false, &"game_state", &"phase", &"RESTART_UNAVAILABLE")
	var validation := validate_checkpoint_snapshot(_checkpoint_snapshot)
	if not bool(validation.accepted):
		_emit_snapshot_failure(active_checkpoint_id, validation.subsystem, validation.stable_id, validation.reason)
		return validation
	if not bool(_game_state.call(&"begin_restart")):
		return _result(false, &"game_state", &"phase", &"RESTART_TRANSITION_REJECTED")
	set_process(false)
	death_time_remaining = 0.0
	checkpoint_restore_started.emit(active_checkpoint_id)
	transient_reset_requested.emit(active_checkpoint_id)
	_reset_registered_transients()
	var restore_result := _restore_validated_snapshot(_checkpoint_snapshot)
	if not bool(restore_result.accepted):
		_game_state.call(&"abort_restart")
		_emit_snapshot_failure(active_checkpoint_id, restore_result.subsystem, restore_result.stable_id, restore_result.reason)
		return restore_result
	if not bool(_game_state.call(&"finish_restart")):
		return _result(false, &"game_state", &"phase", &"RESTART_FINISH_REJECTED")
	_set_terminal_controls(false)
	checkpoint_restore_completed.emit(active_checkpoint_id)
	status_changed.emit("CHECKPOINT RESTORED: %s" % active_checkpoint_id)
	return _result(true)


func advance_death_sequence(delta: float) -> void:
	if _current_phase() != GAME_PHASE_PLAYER_DEAD or death_time_remaining <= 0.0:
		return
	death_time_remaining = maxf(death_time_remaining - maxf(delta, 0.0), 0.0)
	if death_time_remaining <= 0.0:
		request_restart()


func _capture_checkpoint_snapshot(checkpoint_id: StringName) -> Dictionary:
	var door_snapshots := {}
	for door_id in _doors:
		door_snapshots[door_id] = (_doors[door_id] as Door3D).get_checkpoint_snapshot()
	var pickup_snapshots := {}
	for pickup_id in _pickups:
		pickup_snapshots[pickup_id] = (_pickups[pickup_id] as InventoryPickup3D).get_checkpoint_snapshot()
	return {
		&"version": SNAPSHOT_VERSION,
		&"checkpoint_id": checkpoint_id,
		&"player_transform": _player.global_transform,
		&"player_stance": _player.stance,
		&"health": _health.get_checkpoint_snapshot(true),
		&"inventory": _inventory.get_checkpoint_snapshot(),
		&"objective_complete": objective_complete,
		&"objective_consumed": _objective_marker.is_consumed(),
		&"doors": door_snapshots,
		&"pickups": pickup_snapshots,
		&"transient_policy": &"RESET_TO_AUTHORED_STATE",
	}


func _restore_validated_snapshot(snapshot: Dictionary) -> Dictionary:
	objective_complete = bool(snapshot.objective_complete)
	_objective_marker.set_consumed(bool(snapshot.objective_consumed))
	for door_id in snapshot.doors:
		if not (_doors[door_id] as Door3D).restore_checkpoint_snapshot(snapshot.doors[door_id]):
			return _result(false, &"door", StringName(door_id), &"RESTORE_REJECTED")
	for pickup_id in snapshot.pickups:
		if not (_pickups[pickup_id] as InventoryPickup3D).restore_checkpoint_snapshot(snapshot.pickups[pickup_id]):
			return _result(false, &"pickup", StringName(pickup_id), &"RESTORE_REJECTED")
	if _weapon != null and _weapon.state == WeaponController.WeaponState.DISABLED:
		_weapon.set_disabled(false)
	var inventory_result := _inventory.restore_checkpoint_snapshot(snapshot.inventory)
	if not bool(inventory_result.accepted):
		return _result(false, &"inventory", StringName(inventory_result.entry_id), StringName(inventory_result.reason))
	_player.global_transform = snapshot.player_transform
	_player.velocity = Vector3.ZERO
	_player.request_stance(int(snapshot.get(&"player_stance", PlayerController.Stance.STANDING)))
	if not _health.restore_checkpoint_snapshot(snapshot.health):
		return _result(false, &"health", &"player", &"RESTORE_REJECTED")
	_camera_rig.reset_camera_state()
	return _result(true)


func _reset_registered_transients() -> void:
	for node in get_tree().get_nodes_in_group(&"checkpoint_reset_targets"):
		if node != self and node.has_method(&"reset_transient_state"):
			node.call(&"reset_transient_state", active_checkpoint_id)
	for node in get_tree().get_nodes_in_group(&"checkpoint_disposable"):
		if node != self:
			node.queue_free()


func _set_terminal_controls(locked: bool) -> void:
	if _camera_rig != null:
		_camera_rig.request_aim(false)
	if _player != null:
		_player.set_control_lock(PlayerController.ControlLock.DEATH, locked)
	if _weapon != null:
		_weapon.set_control_enabled(not locked)
	if _inventory != null:
		_inventory.set_control_enabled(not locked)
	if _interaction_focus != null:
		_interaction_focus.input_enabled = not locked


func _on_player_died(context: HitContext3D) -> void:
	if _current_phase() == GAME_PHASE_PAUSED:
		_game_state.call(&"set_paused", false)
	if not bool(_game_state.call(&"request_player_death")):
		return
	_set_terminal_controls(true)
	death_time_remaining = death_hold_duration
	set_process(death_time_remaining > 0.0)
	status_changed.emit("PLAYER DOWN — RESTARTING FROM %s" % active_checkpoint_id)


func _on_mission_event(event_id: StringName, actor: Node, _payload: Dictionary) -> void:
	match event_id:
		&"K1_LEVEL_1_CARD":
			status_changed.emit("LEVEL 1 CARD ACQUIRED — D1 CAN NOW BE UNLOCKED")
		&"W1_PISTOL":
			status_changed.emit("SERVICE PISTOL ACQUIRED — FIRST-PERSON COMBAT ENABLED")
		&"A1_PISTOL_AMMO":
			status_changed.emit("PISTOL AMMO ACQUIRED — %d RESERVE ROUNDS" % _inventory.get_ammo_count(&"pistol_round"))
		&"I1_RATION":
			status_changed.emit("FIELD RATION ACQUIRED — EQUIP WITH ITEM PANEL")
		OBJECTIVE_ID:
			_complete_objective(event_id, actor)
		EXTRACTION_ID:
			_request_extraction(event_id)
		_:
			status_changed.emit("MISSION EVENT: %s" % event_id)


func _complete_objective(objective_id: StringName, _actor: Node) -> bool:
	if objective_complete:
		return true
	if _current_phase() != GAME_PHASE_PLAYING or _health.is_dead:
		return false
	objective_complete = true
	_objective_marker.set_consumed(true)
	_shortcut_door.set_locked(false)
	_shortcut_door.set_open(true)
	objective_completed.emit(objective_id)
	status_changed.emit("RELAY MANIFEST COPIED — D2 OPEN, RETURN TO DRAINAGE")
	return true


func _request_extraction(extraction_id: StringName) -> bool:
	if not objective_complete:
		extraction_rejected.emit(extraction_id, &"OBJECTIVE_INCOMPLETE")
		return false
	if _current_phase() != GAME_PHASE_PLAYING or _health.is_dead:
		extraction_rejected.emit(extraction_id, &"CONTROL_LOCKED")
		return false
	if not bool(_game_state.call(&"request_completion")):
		extraction_rejected.emit(extraction_id, &"INVALID_PHASE")
		return false
	_health.set_damage_enabled(false)
	_set_terminal_controls(true)
	mission_completed.emit(extraction_id)
	status_changed.emit("MISSION COMPLETE — EXTRACTION CONFIRMED")
	return true


func _on_triggered(trigger_id: StringName, actor: Node3D) -> void:
	if trigger_id == CP0_ID or trigger_id == CP1_ID:
		activate_checkpoint(trigger_id, actor)


func _query_access(_actor: Node, access_level: StringName) -> bool:
	return _inventory != null and _inventory.has_access_level(access_level)


func _current_phase() -> int:
	return int(_game_state.get(&"phase")) if _game_state != null else -1


func _is_configured() -> bool:
	return (
		_access_door != null and _shortcut_door != null and _objective_marker != null
		and _extraction != null and _camera_rig != null and _inventory != null
		and _player != null and _health != null
	)


func _result(
	accepted: bool,
	subsystem: StringName = &"",
	stable_id: StringName = &"",
	reason: StringName = &"OK"
) -> Dictionary:
	return {
		&"accepted": accepted,
		&"checkpoint_id": active_checkpoint_id,
		&"subsystem": subsystem,
		&"stable_id": stable_id,
		&"reason": reason,
	}


func _emit_snapshot_failure(
	checkpoint_id: StringName,
	subsystem: StringName,
	stable_id: StringName,
	reason: StringName
) -> void:
	snapshot_failure.emit(checkpoint_id, subsystem, stable_id, reason)
	status_changed.emit("CHECKPOINT ERROR [%s:%s] %s" % [subsystem, stable_id, reason])

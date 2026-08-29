class_name GrayboxMissionHarness
extends Node

signal status_changed(message: String)
signal checkpoint_requested(checkpoint_id: StringName, actor: Node3D)
signal objective_requested(objective_id: StringName, actor: Node)
signal extraction_requested(extraction_id: StringName, actor: Node)

var objective_complete: bool = false
var collected_pickups: Dictionary = {}

var _access_door: Door3D
var _shortcut_door: Door3D
var _extraction: MissionMarker3D
var _camera_rig: GameplayCameraRig
var _inventory: InventoryComponent


func configure(
		access_door: Door3D,
		shortcut_door: Door3D,
	extraction: MissionMarker3D,
	camera_rig: GameplayCameraRig,
	inventory: InventoryComponent,
	actor: Node
) -> void:
	_access_door = access_door
	_shortcut_door = shortcut_door
	_extraction = extraction
	_camera_rig = camera_rig
	_inventory = inventory
	var weapon := actor.get_node_or_null("VisualRoot/WeaponController") as WeaponController
	if weapon != null:
		weapon.set_combat_owner(actor)
		weapon.set_aim_provider(_camera_rig)
		_inventory.set_weapon_controller(weapon)
	_access_door.set_access_query(_query_access)
	_extraction.availability_query = func(_actor: Node) -> bool: return objective_complete
	_extraction.reason_query = func(_actor: Node) -> StringName: return &"OBJECTIVE_INCOMPLETE"


func register_marker(marker: MissionMarker3D) -> void:
	marker.mission_event.connect(_on_mission_event)


func register_trigger(trigger: MissionTrigger3D) -> void:
	trigger.triggered.connect(_on_triggered)


func _query_access(_actor: Node, access_level: StringName) -> bool:
	return _inventory != null and _inventory.has_access_level(access_level)


func _on_mission_event(event_id: StringName, actor: Node, payload: Dictionary) -> void:
	match event_id:
		&"K1_LEVEL_1_CARD":
			collected_pickups[event_id] = payload
			status_changed.emit("LEVEL 1 CARD ACQUIRED — D1 CAN NOW BE UNLOCKED")
		&"W1_PISTOL":
			collected_pickups[event_id] = payload
			status_changed.emit("SERVICE PISTOL ACQUIRED — FIRST-PERSON COMBAT ENABLED")
		&"A1_PISTOL_AMMO":
			collected_pickups[event_id] = payload
			status_changed.emit("PISTOL AMMO ACQUIRED — %d RESERVE ROUNDS" % _inventory.get_ammo_count(&"pistol_round"))
		&"I1_RATION":
			collected_pickups[event_id] = payload
			status_changed.emit("FIELD RATION ACQUIRED — EQUIP WITH ITEM PANEL")
		&"O1_RELAY_TERMINAL":
			objective_complete = true
			objective_requested.emit(event_id, actor)
			_shortcut_door.set_locked(false)
			_shortcut_door.set_open(true)
			status_changed.emit("RELAY MANIFEST COPIED — D2 OPEN, RETURN TO DRAINAGE")
		&"X1_DRAINAGE_GATE":
			extraction_requested.emit(event_id, actor)
			status_changed.emit("EXTRACTION EVENT ACCEPTED — GAME-STATE OWNER MAY COMPLETE MISSION")
		_:
			status_changed.emit("MISSION EVENT: %s" % event_id)


func _on_triggered(trigger_id: StringName, actor: Node3D) -> void:
	if trigger_id == &"CP0_INSERTION" or trigger_id == &"CP1_SWITCH_ENTRY":
		checkpoint_requested.emit(trigger_id, actor)
		status_changed.emit("CHECKPOINT EVENT: %s" % trigger_id)

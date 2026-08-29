class_name GrayboxMissionHarness
extends Node

signal status_changed(message: String)
signal checkpoint_requested(checkpoint_id: StringName, actor: Node3D)
signal objective_requested(objective_id: StringName, actor: Node)
signal extraction_requested(extraction_id: StringName, actor: Node)

var has_level_1: bool = false
var objective_complete: bool = false
var collected_pickups: Dictionary = {}

var _access_door: Door3D
var _shortcut_door: Door3D
var _extraction: MissionMarker3D
var _camera_rig: GameplayCameraRig


func configure(
		access_door: Door3D,
		shortcut_door: Door3D,
		extraction: MissionMarker3D,
		camera_rig: GameplayCameraRig
) -> void:
	_access_door = access_door
	_shortcut_door = shortcut_door
	_extraction = extraction
	_camera_rig = camera_rig
	_access_door.set_access_query(_query_access)
	_extraction.availability_query = func(_actor: Node) -> bool: return objective_complete
	_extraction.reason_query = func(_actor: Node) -> StringName: return &"OBJECTIVE_INCOMPLETE"


func register_marker(marker: MissionMarker3D) -> void:
	marker.mission_event.connect(_on_mission_event)


func register_trigger(trigger: MissionTrigger3D) -> void:
	trigger.triggered.connect(_on_triggered)


func _query_access(_actor: Node, access_level: StringName) -> bool:
	return access_level == &"LEVEL_1" and has_level_1


func _on_mission_event(event_id: StringName, actor: Node, payload: Dictionary) -> void:
	match event_id:
		&"K1_LEVEL_1_CARD":
			has_level_1 = true
			collected_pickups[event_id] = payload
			status_changed.emit("LEVEL 1 CARD ACQUIRED — D1 CAN NOW BE UNLOCKED")
		&"W1_PISTOL":
			collected_pickups[event_id] = payload
			if _camera_rig != null:
				_camera_rig.set_weapon_equipped(true)
			status_changed.emit("PISTOL PLACEHOLDER ACQUIRED — FIRST-PERSON AIM ENABLED")
		&"A1_PISTOL_AMMO", &"I1_RATION":
			collected_pickups[event_id] = payload
			status_changed.emit("%s EVENT EMITTED FOR THE FUTURE INVENTORY OWNER" % event_id)
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

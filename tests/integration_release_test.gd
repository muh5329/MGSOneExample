extends SceneTree

const MISSION_SCENE := preload("res://scenes/levels/substation_6.tscn")
const RELEASE_DEBUG := preload("res://data/debug/release_debug_config.tres")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	get_root().get_node("GameState").call(&"reset_for_new_mission")
	var mission := MISSION_SCENE.instantiate() as Substation6
	get_root().add_child(mission)
	await process_frame
	await physics_frame
	await process_frame
	_validate_mission_wiring(mission)
	_validate_release_configuration()
	_validate_transient_cleanup(mission)
	mission.queue_free()
	await process_frame
	if failures.is_empty():
		print("INTEGRATION/RELEASE PASS: mission presentation wiring, public telemetry, reset cleanup, release gating, and export configuration are valid.")
		quit(0)
		return
	for failure in failures:
		push_error("INTEGRATION/RELEASE FAIL: %s" % failure)
	quit(1)


func _validate_mission_wiring(mission: Substation6) -> void:
	for node_name in ["FeedbackManager", "MissionHUD", "TacticalRadar", "AlertCoordinator", "MissionStateCoordinator"]:
		if mission.get_node_or_null(node_name) == null and mission.get_node_or_null("Interface/%s" % node_name) == null:
			failures.append("Integrated mission is missing '%s'." % node_name)
	var debug_snapshot := mission.get_debug_snapshot()
	if StringName(debug_snapshot.get(&"room", &"")).is_empty():
		failures.append("Mission debug snapshot does not identify the active room.")
	if (debug_snapshot.get(&"guards", []) as Array).size() != 4:
		failures.append("Mission telemetry does not contain exactly four sanitized guard records.")
	var feedback: Dictionary = debug_snapshot.get(&"feedback", {})
	if int(feedback.get(&"voice_capacity", 0)) <= 0 or int(feedback.get(&"effect_capacity", 0)) <= 0:
		failures.append("Integrated feedback owner did not expose bounded capacities.")
	var hud := mission.get_node("MissionHUD") as MissionHUD
	var hud_snapshot := hud.get_display_snapshot()
	if StringName(hud_snapshot.get(&"alert_phase", &"")).is_empty() or not hud_snapshot.has(&"health"):
		failures.append("HUD did not render authoritative health and alert state after mission startup.")


func _validate_release_configuration() -> void:
	if RELEASE_DEBUG.enabled or RELEASE_DEBUG.show_fps or RELEASE_DEBUG.show_guard_perception or RELEASE_DEBUG.show_alert_radar:
		failures.append("Release debug configuration enables test/debug presentation.")
	if not FileAccess.file_exists("res://export_presets.cfg"):
		failures.append("Release export preset is missing.")
	else:
		var preset_text := FileAccess.get_file_as_string("res://export_presets.cfg")
		if not preset_text.contains("name=\"macOS\"") or not preset_text.contains("application/bundle_identifier"):
			failures.append("macOS release export preset is incomplete.")
	if ProjectSettings.get_setting("application/config/name", "") != "Shadow Circuit":
		failures.append("Release application name drifted from the documented build identity.")
	if not bool(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc", false)):
		failures.append("macOS arm64 export-compatible ETC2/ASTC import is disabled.")


func _validate_transient_cleanup(mission: Substation6) -> void:
	var feedback := mission.get_node("FeedbackManager") as FeedbackManager
	for event_id: StringName in [&"pistol_fire", &"bullet_impact", &"DETECTED", &"PLAYER_DAMAGED"]:
		feedback.request_feedback(event_id, {&"position": Vector3.ZERO})
	feedback.reset_transient_state(&"CP0_INSERTION")
	var snapshot := feedback.get_feedback_snapshot()
	if int(snapshot.active_voices) != 0 or int(snapshot.active_effects) != 0:
		failures.append("Release mission checkpoint cleanup left feedback nodes active.")

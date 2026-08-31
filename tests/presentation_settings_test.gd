extends SceneTree

const FEEDBACK_SCENE := preload("res://scenes/components/feedback_manager.tscn")
const HUD_SCENE := preload("res://scenes/ui/mission_hud.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause_settings_menu.tscn")
const STRESS_SCENE := preload("res://scenes/levels/presentation_stress_test_room.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_validate_settings_contract()
	await _validate_feedback_bounds()
	await _validate_ui_contracts()
	if failures.is_empty():
		print("PRESENTATION/SETTINGS PASS: bounded feedback, accessibility settings, remap conflicts, HUD anchors, and pause focus are valid.")
		quit(0)
		return
	for failure in failures:
		push_error("PRESENTATION/SETTINGS FAIL: %s" % failure)
	quit(1)


func _validate_settings_contract() -> void:
	var settings := get_root().get_node("SettingsService")
	if not ProjectSettings.has_setting("autoload/SettingsService"):
		failures.append("SettingsService is not a configured autoload.")
	for bus_name in [&"Master", &"Music", &"Effects", &"UI", &"Ambience"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			failures.append("Missing audio bus '%s'." % bus_name)
	settings.call(&"set_setting", &"master_volume", 2.0, false)
	if not is_equal_approx(float(settings.call(&"get_setting", &"master_volume")), 1.0):
		failures.append("User-friendly linear volume was not clamped to 0–1.")
	settings.call(&"set_setting", &"text_scale", 9.0, false)
	if not is_equal_approx(float(settings.call(&"get_setting", &"text_scale")), 1.5):
		failures.append("HUD scale was not clamped to the supported 0.8–1.5 range.")
	var duplicate_event := InputEventKey.new()
	duplicate_event.physical_keycode = KEY_F
	var conflict: Dictionary = settings.call(&"remap_action", &"reload", duplicate_event, false)
	if bool(conflict.accepted) or StringName(conflict.conflict).is_empty():
		failures.append("Remapping did not report an existing semantic-action conflict.")
	var alternate_event := InputEventKey.new()
	alternate_event.physical_keycode = KEY_V
	var remap: Dictionary = settings.call(&"remap_action", &"interact", alternate_event, false)
	if not bool(remap.accepted):
		failures.append("A non-conflicting alternate binding was rejected.")
	settings.call(&"reset_defaults", false)


func _validate_feedback_bounds() -> void:
	var manager := FEEDBACK_SCENE.instantiate() as FeedbackManager
	manager.maximum_audio_voices = 4
	manager.maximum_effects = 2
	get_root().add_child(manager)
	await process_frame
	for event_id: StringName in [&"DETECTED", &"pistol_fire", &"bullet_impact", &"OBJECTIVE", &"PICKUP", &"PLAYER_DAMAGED"]:
		manager.request_feedback(event_id, {&"position": Vector3.ONE})
	var snapshot := manager.get_feedback_snapshot()
	if int(snapshot.active_voices) > int(snapshot.voice_capacity):
		failures.append("High-priority event burst exceeded the configured audio voice limit.")
	if int(snapshot.active_effects) > int(snapshot.effect_capacity):
		failures.append("Feedback burst exceeded the configured VFX limit.")
	if int(snapshot.suppressed) <= 0:
		failures.append("Voice starvation did not fail boundedly under an oversized burst.")
	manager.reset_transient_state(&"TEST")
	snapshot = manager.get_feedback_snapshot()
	if int(snapshot.active_voices) != 0 or int(snapshot.active_effects) != 0:
		failures.append("Checkpoint reset did not clean up transient feedback voices/effects.")
	manager.queue_free()
	await process_frame
	var stress := STRESS_SCENE.instantiate() as PresentationStressTestRoom
	get_root().add_child(stress)
	await process_frame
	var stress_snapshot := stress.run_stress_burst(30)
	if int(stress_snapshot.active_voices) > int(stress_snapshot.voice_capacity) or int(stress_snapshot.active_effects) > int(stress_snapshot.effect_capacity):
		failures.append("Presentation stress room grew past its declared pools.")
	stress.queue_free()
	await process_frame


func _validate_ui_contracts() -> void:
	var hud := HUD_SCENE.instantiate() as MissionHUD
	get_root().add_child(hud)
	await process_frame
	var hud_root := hud.get_node("HUDRoot") as Control
	if hud_root.anchor_right != 1.0 or hud_root.anchor_bottom != 1.0:
		failures.append("Mission HUD root is not safe-area/aspect anchored.")
	if hud.get_node_or_null("HUDRoot/OutcomePanel") == null or hud.get_node_or_null("HUDRoot/PromptPanel") == null:
		failures.append("Mission HUD lacks outcome or contextual prompt presentation.")
	hud.queue_free()
	await process_frame
	var menu := PAUSE_SCENE.instantiate() as PauseSettingsMenu
	get_root().add_child(menu)
	await process_frame
	var game_state := get_root().get_node("GameState")
	game_state.call(&"reset_for_new_mission")
	game_state.call(&"set_paused", true)
	await process_frame
	var menu_snapshot := menu.get_menu_snapshot()
	if not bool(menu_snapshot.visible) or menu_snapshot.focused == null:
		failures.append("Pause menu did not become visible with a controller/keyboard focus owner.")
	game_state.call(&"set_paused", false)
	menu.queue_free()
	await process_frame

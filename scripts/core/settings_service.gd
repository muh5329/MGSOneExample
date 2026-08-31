extends Node

signal setting_changed(key: StringName, value: Variant)
signal settings_reset()
signal input_family_changed(family: StringName)
signal remap_rejected(action: StringName, reason: StringName, conflict: StringName)
signal remap_applied(action: StringName)

const SETTINGS_PATH := "user://shadow_circuit_settings.cfg"
const AUDIO_BUSES := {
	&"master_volume": &"Master",
	&"music_volume": &"Music",
	&"effects_volume": &"Effects",
	&"ui_volume": &"UI",
	&"ambience_volume": &"Ambience",
}
const DEFAULTS := {
	&"master_volume": 1.0,
	&"music_volume": 0.75,
	&"effects_volume": 0.9,
	&"ui_volume": 0.85,
	&"ambience_volume": 0.7,
	&"mouse_sensitivity": 0.12,
	&"controller_sensitivity": 150.0,
	&"invert_horizontal": false,
	&"invert_vertical": false,
	&"screen_effect_intensity": 0.75,
	&"retro_enabled": true,
	&"camera_shake_scale": 1.0,
	&"vibration_scale": 1.0,
	&"reduced_flash": false,
	&"text_scale": 1.0,
	&"high_contrast": false,
}
const REQUIRED_NAVIGATION_ACTIONS := [&"ui_accept", &"ui_cancel", &"ui_up", &"ui_down", &"ui_left", &"ui_right"]

var input_family: StringName = &"KEYBOARD_MOUSE"
var _values: Dictionary = DEFAULTS.duplicate(true)
var _custom_bindings: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_audio_settings()


func _input(event: InputEvent) -> void:
	var next_family := input_family
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		next_family = &"CONTROLLER"
	elif event is InputEventKey or event is InputEventMouse:
		next_family = &"KEYBOARD_MOUSE"
	if next_family != input_family:
		input_family = next_family
		input_family_changed.emit(input_family)


func get_setting(key: StringName, fallback: Variant = null) -> Variant:
	return _values.get(key, fallback)


func get_settings_snapshot() -> Dictionary:
	return _values.duplicate(true)


func set_setting(key: StringName, value: Variant, persist: bool = true) -> bool:
	if not DEFAULTS.has(key):
		return false
	var sanitized: Variant = _sanitize(key, value)
	if _values.get(key) == sanitized:
		return true
	_values[key] = sanitized
	_apply_setting(key)
	setting_changed.emit(key, sanitized)
	if persist:
		save_settings()
	return true


func reset_defaults(persist: bool = true) -> void:
	_remove_custom_bindings()
	_values = DEFAULTS.duplicate(true)
	apply_audio_settings()
	settings_reset.emit()
	for key in _values:
		setting_changed.emit(key, _values[key])
	if persist:
		save_settings()


func save_settings() -> bool:
	var config := ConfigFile.new()
	for key in _values:
		config.set_value("settings", String(key), _values[key])
	for action in _custom_bindings:
		config.set_value("bindings", String(action), _custom_bindings[action])
	return config.save(SETTINGS_PATH) == OK


func load_settings() -> bool:
	_values = DEFAULTS.duplicate(true)
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)
	if error == ERR_FILE_NOT_FOUND:
		return save_settings()
	if error != OK:
		return false
	for key in DEFAULTS:
		if config.has_section_key("settings", String(key)):
			_values[key] = _sanitize(key, config.get_value("settings", String(key)))
	var binding_keys: PackedStringArray = config.get_section_keys("bindings") if config.has_section("bindings") else PackedStringArray()
	for action_key in binding_keys:
		var action := StringName(action_key)
		if not InputMap.has_action(action):
			continue
		var events: Array = config.get_value("bindings", action_key, [])
		for event_value in events:
			var event := event_value as InputEvent
			if event != null and not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)
				if not _custom_bindings.has(action):
					_custom_bindings[action] = []
				(_custom_bindings[action] as Array).append(event)
	return true


func apply_audio_settings() -> void:
	for key in AUDIO_BUSES:
		_apply_setting(key)


func apply_camera_settings(camera_rig: Node) -> bool:
	if camera_rig == null or not is_instance_valid(camera_rig):
		return false
	var camera_settings: Resource = camera_rig.get("settings")
	if camera_settings == null:
		return false
	camera_settings.set("mouse_sensitivity", float(_values.mouse_sensitivity))
	camera_settings.set("controller_sensitivity", float(_values.controller_sensitivity))
	camera_settings.set("invert_horizontal", bool(_values.invert_horizontal))
	camera_settings.set("invert_vertical", bool(_values.invert_vertical))
	return true


func remap_action(action: StringName, event: InputEvent, persist: bool = true) -> Dictionary:
	if not InputMap.has_action(action) or event == null:
		return _remap_result(false, action, &"INVALID_REQUEST")
	var conflict := find_conflict(event, action)
	if not conflict.is_empty():
		remap_rejected.emit(action, &"CONFLICT", conflict)
		return _remap_result(false, action, &"CONFLICT", conflict)
	InputMap.action_add_event(action, event)
	if not _custom_bindings.has(action):
		_custom_bindings[action] = []
	(_custom_bindings[action] as Array).append(event)
	if persist:
		save_settings()
	remap_applied.emit(action)
	return _remap_result(true, action, &"OK")


func find_conflict(event: InputEvent, excluding_action: StringName = &"") -> StringName:
	for action_value in InputMap.get_actions():
		var action := StringName(action_value)
		if action == excluding_action:
			continue
		for existing in InputMap.action_get_events(action):
			if existing.is_match(event, true):
				return action
	return &""


func glyph_for(action: StringName) -> String:
	var controller := {
		&"interact": "A", &"ui_accept": "A", &"ui_cancel": "B", &"pause": "START",
		&"weapon_menu": "LB", &"item_menu": "RB", &"quick_use": "Y", &"reload": "X",
		&"aim": "LT", &"fire": "RT", &"crouch": "L3",
	}
	var keyboard := {
		&"interact": "F", &"ui_accept": "ENTER", &"ui_cancel": "ESC", &"pause": "ESC",
		&"weapon_menu": "Q", &"item_menu": "E", &"quick_use": "G", &"reload": "R",
		&"aim": "RMB", &"fire": "LMB", &"crouch": "C",
	}
	return String((controller if input_family == &"CONTROLLER" else keyboard).get(action, String(action).to_upper()))


func _remove_custom_bindings() -> void:
	for action in _custom_bindings:
		for event_value in _custom_bindings[action]:
			var event := event_value as InputEvent
			if event != null and InputMap.has_action(action):
				InputMap.action_erase_event(action, event)
	_custom_bindings.clear()


func _apply_setting(key: StringName) -> void:
	if AUDIO_BUSES.has(key):
		var bus_index := AudioServer.get_bus_index(StringName(AUDIO_BUSES[key]))
		if bus_index >= 0:
			var linear := float(_values[key])
			AudioServer.set_bus_mute(bus_index, linear <= 0.0001)
			AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(linear, 0.0001)))


func _sanitize(key: StringName, value: Variant) -> Variant:
	match key:
		&"master_volume", &"music_volume", &"effects_volume", &"ui_volume", &"ambience_volume":
			return clampf(float(value), 0.0, 1.0)
		&"mouse_sensitivity":
			return clampf(float(value), 0.01, 1.0)
		&"controller_sensitivity":
			return clampf(float(value), 30.0, 360.0)
		&"screen_effect_intensity", &"camera_shake_scale", &"vibration_scale":
			return clampf(float(value), 0.0, 1.0)
		&"text_scale":
			return clampf(float(value), 0.8, 1.5)
		&"invert_horizontal", &"invert_vertical", &"retro_enabled", &"reduced_flash", &"high_contrast":
			return bool(value)
	return value


func _remap_result(accepted: bool, action: StringName, reason: StringName, conflict: StringName = &"") -> Dictionary:
	return {&"accepted": accepted, &"action": action, &"reason": reason, &"conflict": conflict}

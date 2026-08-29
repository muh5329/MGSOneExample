extends SceneTree

const REQUIRED_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_forward", &"move_back",
	&"look_left", &"look_right", &"look_up", &"look_down",
	&"aim", &"fire", &"reload", &"crouch", &"interact",
	&"weapon_menu", &"item_menu", &"quick_use", &"pause",
	&"ui_accept", &"ui_cancel", &"ui_left", &"ui_right", &"ui_up", &"ui_down",
	&"ui_focus_next", &"ui_focus_prev", &"debug_toggle",
]

const REQUIRED_RESOURCES: Array[String] = [
	"res://scenes/core/bootstrap.tscn",
	"res://scenes/core/default_environment.tres",
	"res://scenes/levels/foundation_test_room.tscn",
	"res://scenes/levels/locomotion_test_room.tscn",
	"res://scenes/levels/camera_aim_test_room.tscn",
	"res://scenes/levels/substation_6.tscn",
	"res://scenes/levels/interaction_test_room.tscn",
	"res://scenes/components/interactable_3d.tscn",
	"res://scenes/components/interaction_focus_3d.tscn",
	"res://scenes/components/door_3d.tscn",
	"res://scenes/components/mission_marker_3d.tscn",
	"res://scenes/actors/player.tscn",
	"res://scenes/camera/gameplay_camera_rig.tscn",
	"res://data/player/default_player_movement_config.tres",
	"res://data/camera/default_camera_aim_settings.tres",
	"res://data/debug/development_debug_config.tres",
	"res://data/debug/release_debug_config.tres",
]

const DUAL_FAMILY_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_forward", &"move_back",
	&"aim", &"fire", &"reload", &"crouch", &"interact",
	&"weapon_menu", &"item_menu", &"quick_use", &"pause",
	&"ui_accept", &"ui_cancel", &"ui_left", &"ui_right", &"ui_up", &"ui_down",
	&"ui_focus_next", &"ui_focus_prev",
]

var failures: Array[String] = []


func _initialize() -> void:
	_validate_actions()
	_validate_resources()
	_validate_project_settings()
	_validate_scene_instantiation()
	if failures.is_empty():
		print("SMOKE PASS: foundation contracts are present and loadable.")
		quit(0)
		return
	for failure in failures:
		push_error("SMOKE FAIL: %s" % failure)
	quit(1)


func _validate_actions() -> void:
	for action in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			failures.append("Missing input action '%s'." % action)
		elif InputMap.action_get_events(action).is_empty():
			failures.append("Input action '%s' has no default bindings." % action)
	for action in DUAL_FAMILY_ACTIONS:
		_validate_input_families(action)


func _validate_input_families(action: StringName) -> void:
	if not InputMap.has_action(action):
		return
	var has_keyboard_or_mouse := false
	var has_controller := false
	for event in InputMap.action_get_events(action):
		has_keyboard_or_mouse = has_keyboard_or_mouse or event is InputEventKey or event is InputEventMouseButton
		has_controller = has_controller or event is InputEventJoypadButton or event is InputEventJoypadMotion
	if not has_keyboard_or_mouse:
		failures.append("Input action '%s' has no keyboard/mouse binding." % action)
	if not has_controller:
		failures.append("Input action '%s' has no controller binding." % action)


func _validate_resources() -> void:
	for path in REQUIRED_RESOURCES:
		if not ResourceLoader.exists(path):
			failures.append("Missing required resource '%s'." % path)


func _validate_project_settings() -> void:
	if ProjectSettings.get_setting("application/run/main_scene", "") != "res://scenes/core/bootstrap.tscn":
		failures.append("Bootstrap is not configured as the main scene.")
	for layer_number in range(1, 8):
		var key := "layer_names/3d_physics/layer_%d" % layer_number
		if String(ProjectSettings.get_setting(key, "")).is_empty():
			failures.append("Collision layer %d has no canonical name." % layer_number)
	for autoload_name in [&"GameState", &"EventBus"]:
		if not ProjectSettings.has_setting("autoload/%s" % autoload_name):
			failures.append("Missing required autoload '%s'." % autoload_name)


func _validate_scene_instantiation() -> void:
	for path in [
		"res://scenes/core/bootstrap.tscn",
		"res://scenes/levels/foundation_test_room.tscn",
		"res://scenes/levels/locomotion_test_room.tscn",
		"res://scenes/levels/camera_aim_test_room.tscn",
		"res://scenes/levels/substation_6.tscn",
		"res://scenes/levels/interaction_test_room.tscn",
		"res://scenes/actors/player.tscn",
		"res://scenes/camera/gameplay_camera_rig.tscn",
	]:
		var resource := load(path) as PackedScene
		if resource == null:
			failures.append("Could not load scene '%s'." % path)
			continue
		var instance := resource.instantiate()
		if instance == null:
			failures.append("Could not instantiate scene '%s'." % path)
		else:
			instance.free()

extends Node

const DEFAULT_LEVEL_PATH := "res://scenes/levels/substation_6.tscn"

@export_file("*.tscn") var initial_level_path: String = DEFAULT_LEVEL_PATH
@export var debug_config: DebugConfig

@onready var level_root: Node = %LevelRoot
@onready var failure_label: Label = %FailureLabel
@onready var debug_overlay: DebugOverlay = %DebugOverlay

var _guard_debug_visible: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_initial_level()
	_update_debug_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle") and OS.is_debug_build():
		debug_overlay.set_debug_visible(not debug_overlay.visible)
		_guard_debug_visible = (
			debug_overlay.visible
			and debug_config != null
			and debug_config.show_guard_perception
		)
		get_tree().call_group(&"guard_debug_visuals", &"set_debug_visible", _guard_debug_visible)
		get_tree().call_group(&"alert_debug_visuals", &"set_debug_visible", _guard_debug_visible and debug_config.show_alert_radar)
		get_viewport().set_input_as_handled()


func _load_initial_level() -> void:
	if not ResourceLoader.exists(initial_level_path, "PackedScene"):
		_fail_startup("Required initial scene is missing: %s" % initial_level_path)
		return
	var packed_scene := load(initial_level_path) as PackedScene
	if packed_scene == null:
		_fail_startup("Initial scene is not a PackedScene: %s" % initial_level_path)
		return
	var level := packed_scene.instantiate()
	level_root.add_child(level)
	debug_overlay.configure(level)


func _fail_startup(message: String) -> void:
	push_error(message)
	failure_label.text = "STARTUP FAILED\n%s" % message
	failure_label.visible = true


func _update_debug_visibility() -> void:
	debug_overlay.set_debug_visible(
		OS.is_debug_build()
		and debug_config != null
		and debug_config.enabled
		and debug_config.show_fps
	)
	_guard_debug_visible = (
		debug_overlay.visible
		and debug_config != null
		and debug_config.show_guard_perception
	)
	get_tree().call_group(&"guard_debug_visuals", &"set_debug_visible", _guard_debug_visible)
	get_tree().call_group(
		&"alert_debug_visuals",
		&"set_debug_visible",
		_guard_debug_visible and debug_config.show_alert_radar
	)

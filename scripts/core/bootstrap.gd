extends Node

const DEFAULT_LEVEL_PATH := "res://scenes/levels/substation_6.tscn"

@export_file("*.tscn") var initial_level_path: String = DEFAULT_LEVEL_PATH
@export var debug_config: DebugConfig

@onready var level_root: Node = %LevelRoot
@onready var failure_label: Label = %FailureLabel
@onready var pause_panel: Control = %PausePanel
@onready var resume_button: Button = %ResumeButton
@onready var debug_label: Label = %DebugLabel

var _guard_debug_visible: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.pause_changed.connect(_on_pause_changed)
	resume_button.pressed.connect(_on_resume_pressed)
	_load_initial_level()
	_update_debug_visibility()


func _process(_delta: float) -> void:
	if debug_label.visible:
		debug_label.text = "DEBUG  FPS %d  ROOM %s" % [
			Engine.get_frames_per_second(),
			initial_level_path.get_file().get_basename(),
		]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle") and OS.is_debug_build():
		debug_label.visible = not debug_label.visible
		_guard_debug_visible = (
			debug_label.visible
			and debug_config != null
			and debug_config.show_guard_perception
		)
		get_tree().call_group(&"guard_debug_visuals", &"set_debug_visible", _guard_debug_visible)
		get_viewport().set_input_as_handled()


func _load_initial_level() -> void:
	if not ResourceLoader.exists(initial_level_path, "PackedScene"):
		_fail_startup("Required initial scene is missing: %s" % initial_level_path)
		return
	var packed_scene := load(initial_level_path) as PackedScene
	if packed_scene == null:
		_fail_startup("Initial scene is not a PackedScene: %s" % initial_level_path)
		return
	level_root.add_child(packed_scene.instantiate())


func _fail_startup(message: String) -> void:
	push_error(message)
	failure_label.text = "STARTUP FAILED\n%s" % message
	failure_label.visible = true


func _on_pause_changed(is_paused: bool) -> void:
	pause_panel.visible = is_paused
	if is_paused:
		resume_button.grab_focus.call_deferred()
	else:
		resume_button.release_focus()


func _on_resume_pressed() -> void:
	GameState.set_paused(false)


func _update_debug_visibility() -> void:
	debug_label.visible = (
		OS.is_debug_build()
		and debug_config != null
		and debug_config.enabled
		and debug_config.show_fps
	)
	_guard_debug_visible = (
		debug_label.visible
		and debug_config != null
		and debug_config.show_guard_perception
	)
	get_tree().call_group(&"guard_debug_visuals", &"set_debug_visible", _guard_debug_visible)

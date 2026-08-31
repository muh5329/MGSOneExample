class_name PauseSettingsMenu
extends CanvasLayer

@onready var overlay: ColorRect = %Overlay
@onready var main_panel: PanelContainer = %MainPanel
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var back_button: Button = %BackButton
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var effects_slider: HSlider = %EffectsSlider
@onready var ui_slider: HSlider = %UISlider
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var text_scale_slider: HSlider = %TextScaleSlider
@onready var retro_toggle: CheckButton = %RetroToggle
@onready var shake_toggle: CheckButton = %ShakeToggle
@onready var vibration_toggle: CheckButton = %VibrationToggle
@onready var reduced_flash_toggle: CheckButton = %ReducedFlashToggle
@onready var invert_vertical_toggle: CheckButton = %InvertVerticalToggle
@onready var high_contrast_toggle: CheckButton = %HighContrastToggle
@onready var remap_action: OptionButton = %RemapAction
@onready var remap_button: Button = %RemapButton
@onready var remap_status: Label = %RemapStatus

const REMAPPABLE_ACTIONS := [
	&"interact", &"aim", &"fire", &"reload", &"crouch", &"weapon_menu", &"item_menu", &"quick_use", &"pause",
]

var _syncing: bool = false
var _awaiting_remap: bool = false
var _settings: Node
var _game_state: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_settings = get_node("/root/SettingsService")
	_game_state = get_node("/root/GameState")
	overlay.visible = false
	main_panel.visible = true
	settings_panel.visible = false
	resume_button.pressed.connect(_resume)
	settings_button.pressed.connect(_show_settings)
	back_button.pressed.connect(_show_main)
	%ResetButton.pressed.connect(_reset_settings)
	remap_button.pressed.connect(_begin_remap)
	master_slider.value_changed.connect(func(value: float) -> void: _set_value(&"master_volume", value))
	music_slider.value_changed.connect(func(value: float) -> void: _set_value(&"music_volume", value))
	effects_slider.value_changed.connect(func(value: float) -> void: _set_value(&"effects_volume", value))
	ui_slider.value_changed.connect(func(value: float) -> void: _set_value(&"ui_volume", value))
	sensitivity_slider.value_changed.connect(func(value: float) -> void: _set_value(&"controller_sensitivity", value))
	text_scale_slider.value_changed.connect(func(value: float) -> void: _set_value(&"text_scale", value))
	retro_toggle.toggled.connect(func(value: bool) -> void: _set_value(&"retro_enabled", value))
	shake_toggle.toggled.connect(func(value: bool) -> void: _set_value(&"camera_shake_scale", 1.0 if value else 0.0))
	vibration_toggle.toggled.connect(func(value: bool) -> void: _set_value(&"vibration_scale", 1.0 if value else 0.0))
	reduced_flash_toggle.toggled.connect(func(value: bool) -> void: _set_value(&"reduced_flash", value))
	invert_vertical_toggle.toggled.connect(func(value: bool) -> void: _set_value(&"invert_vertical", value))
	high_contrast_toggle.toggled.connect(func(value: bool) -> void: _set_value(&"high_contrast", value))
	for action in REMAPPABLE_ACTIONS:
		remap_action.add_item(String(action).replace("_", " ").capitalize())
		remap_action.set_item_metadata(remap_action.item_count - 1, action)
	_game_state.pause_changed.connect(_on_pause_changed)
	_sync_controls()


func _unhandled_input(event: InputEvent) -> void:
	if _awaiting_remap:
		if event is InputEventKey and event.pressed and not event.echo:
			_finish_remap(event)
		elif event is InputEventJoypadButton and event.pressed:
			_finish_remap(event)
		return
	if not overlay.visible or not event.is_action_pressed(&"ui_cancel"):
		return
	if settings_panel.visible:
		_show_main()
	else:
		_resume()
	get_viewport().set_input_as_handled()


func _on_pause_changed(paused: bool) -> void:
	overlay.visible = paused
	_awaiting_remap = false
	if paused:
		_show_main()
		resume_button.grab_focus.call_deferred()
	else:
		resume_button.release_focus()


func _resume() -> void:
	_game_state.call(&"set_paused", false)


func _show_settings() -> void:
	main_panel.visible = false
	settings_panel.visible = true
	_sync_controls()
	back_button.grab_focus.call_deferred()


func _show_main() -> void:
	_awaiting_remap = false
	remap_status.text = "Select an action, then add an alternate key or controller button."
	settings_panel.visible = false
	main_panel.visible = true
	resume_button.grab_focus.call_deferred()


func _set_value(key: StringName, value: Variant) -> void:
	if _syncing:
		return
	_settings.call(&"set_setting", key, value)


func _sync_controls() -> void:
	_syncing = true
	master_slider.value = float(_settings.call(&"get_setting", &"master_volume"))
	music_slider.value = float(_settings.call(&"get_setting", &"music_volume"))
	effects_slider.value = float(_settings.call(&"get_setting", &"effects_volume"))
	ui_slider.value = float(_settings.call(&"get_setting", &"ui_volume"))
	sensitivity_slider.value = float(_settings.call(&"get_setting", &"controller_sensitivity"))
	text_scale_slider.value = float(_settings.call(&"get_setting", &"text_scale"))
	retro_toggle.button_pressed = bool(_settings.call(&"get_setting", &"retro_enabled"))
	shake_toggle.button_pressed = float(_settings.call(&"get_setting", &"camera_shake_scale")) > 0.0
	vibration_toggle.button_pressed = float(_settings.call(&"get_setting", &"vibration_scale")) > 0.0
	reduced_flash_toggle.button_pressed = bool(_settings.call(&"get_setting", &"reduced_flash"))
	invert_vertical_toggle.button_pressed = bool(_settings.call(&"get_setting", &"invert_vertical"))
	high_contrast_toggle.button_pressed = bool(_settings.call(&"get_setting", &"high_contrast"))
	_syncing = false


func _reset_settings() -> void:
	_settings.call(&"reset_defaults")
	_sync_controls()
	remap_status.text = "Presentation and control settings restored to defaults."


func _begin_remap() -> void:
	_awaiting_remap = true
	remap_status.text = "Press one keyboard key or controller button. ESC / B remains available."


func _finish_remap(event: InputEvent) -> void:
	_awaiting_remap = false
	var action := StringName(remap_action.get_item_metadata(remap_action.selected))
	var result: Dictionary = _settings.call(&"remap_action", action, event)
	if bool(result.accepted):
		remap_status.text = "Added binding for %s." % String(action).replace("_", " ")
	else:
		remap_status.text = "Binding rejected: %s%s" % [
			result.reason,
			" (already used by %s)" % result.conflict if not StringName(result.conflict).is_empty() else "",
		]


func get_menu_snapshot() -> Dictionary:
	return {
		&"visible": overlay.visible,
		&"settings_visible": settings_panel.visible,
		&"awaiting_remap": _awaiting_remap,
		&"focused": get_viewport().gui_get_focus_owner(),
	}

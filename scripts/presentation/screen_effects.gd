class_name ScreenEffects
extends Control

var flash_color: Color = Color.TRANSPARENT
var flash_remaining: float = 0.0
var flash_duration: float = 0.0
var detection_pulse: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func _process(delta: float) -> void:
	if flash_remaining > 0.0:
		flash_remaining = maxf(flash_remaining - delta, 0.0)
	if detection_pulse > 0.0:
		detection_pulse = maxf(detection_pulse - delta, 0.0)
	queue_redraw()


func request_flash(color: Color, duration: float) -> void:
	var settings := get_node_or_null("/root/SettingsService")
	if settings != null and bool(settings.call(&"get_setting", &"reduced_flash", false)):
		duration = minf(duration, 0.08)
		color.a = minf(color.a, 0.12)
	flash_color = color
	flash_duration = maxf(duration, 0.001)
	flash_remaining = flash_duration


func request_detection_pulse(duration: float = 0.6) -> void:
	detection_pulse = maxf(duration, 0.0)


func clear_effects() -> void:
	flash_remaining = 0.0
	detection_pulse = 0.0
	queue_redraw()


func _draw() -> void:
	var settings := get_node_or_null("/root/SettingsService")
	var intensity := float(settings.call(&"get_setting", &"screen_effect_intensity", 0.75)) if settings != null else 0.75
	var retro_enabled := bool(settings.call(&"get_setting", &"retro_enabled", true)) if settings != null else true
	if retro_enabled and intensity > 0.0:
		var line_color := Color(0.0, 0.0, 0.0, 0.08 * intensity)
		for y in range(1, roundi(size.y), 4):
			draw_line(Vector2(0.0, y), Vector2(size.x, y), line_color, 1.0)
		var edge := Color(0.0, 0.04, 0.03, 0.11 * intensity)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 10.0)), edge)
		draw_rect(Rect2(Vector2(0.0, size.y - 10.0), Vector2(size.x, 10.0)), edge)
		draw_rect(Rect2(Vector2.ZERO, Vector2(10.0, size.y)), edge)
		draw_rect(Rect2(Vector2(size.x - 10.0, 0.0), Vector2(10.0, size.y)), edge)
	if detection_pulse > 0.0:
		var pulse_alpha := 0.12 + sin(detection_pulse * 24.0) * 0.04
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.08, 0.03, pulse_alpha * intensity), false, 6.0)
	if flash_remaining > 0.0:
		var color := flash_color
		color.a *= flash_remaining / flash_duration * intensity
		draw_rect(Rect2(Vector2.ZERO, size), color)

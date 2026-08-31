class_name DebugOverlay
extends PanelContainer

@onready var telemetry_label: Label = %TelemetryLabel

var source: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	var snapshot: Dictionary = source.call(&"get_debug_snapshot") if source != null and source.has_method(&"get_debug_snapshot") else {}
	var player: Dictionary = snapshot.get(&"player", {})
	var camera: Dictionary = snapshot.get(&"camera", {})
	var alert: Dictionary = snapshot.get(&"alert", {})
	var feedback: Dictionary = snapshot.get(&"feedback", {})
	var guard_lines: PackedStringArray = []
	for guard in snapshot.get(&"guards", []):
		guard_lines.append("%s %-12s S%.2f V%s" % [guard.guard_id, guard.state, guard.suspicion, "Y" if guard.visible else "N"])
	telemetry_label.text = "\n".join([
		"DEBUG / F3    FPS %d    NODES %d    OBJECTS %d" % [Engine.get_frames_per_second(), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT))],
		"ROOM %s    ZONE %s    CHECKPOINT %s" % [snapshot.get(&"room", &"?"), camera.get(&"zone", &"?"), snapshot.get(&"checkpoint", &"?")],
		"PLAYER %s    STANCE %s    SPEED %.2f    NOISE %.2f    LOCKS %s" % [player.get(&"position", Vector3.ZERO), player.get(&"stance", -1), player.get(&"speed", 0.0), player.get(&"noise", 0.0), player.get(&"control_enabled", false)],
		"CAMERA MODE %s    TRANSITION %s    OBSTRUCTED %s    AIM %s" % [camera.get(&"mode", -1), camera.get(&"transitioning", false), camera.get(&"obstructed", false), camera.get(&"aim_direction", Vector3.ZERO)],
		"ALERT %s    ELAPSED %.2f    REMAIN %.2f    SUSPICION %.2f" % [alert.get(&"phase", &"?"), alert.get(&"phase_elapsed", 0.0), alert.get(&"time_remaining", 0.0), alert.get(&"maximum_suspicion", 0.0)],
		"FEEDBACK VOICES %d/%d    FX %d/%d    SUPPRESSED %d" % [feedback.get(&"active_voices", 0), feedback.get(&"voice_capacity", 0), feedback.get(&"active_effects", 0), feedback.get(&"effect_capacity", 0), feedback.get(&"suppressed", 0)],
		"GUARDS\n%s" % "\n".join(guard_lines),
	])


func configure(debug_source: Node) -> void:
	source = debug_source


func set_debug_visible(enabled: bool) -> void:
	visible = enabled and OS.is_debug_build()

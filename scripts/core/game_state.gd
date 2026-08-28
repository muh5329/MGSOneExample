extends Node

signal phase_changed(previous: MissionPhase, current: MissionPhase)
signal pause_changed(is_paused: bool)

enum MissionPhase {
	INITIALIZING,
	PLAYING,
	PAUSED,
	PLAYER_DEAD,
	COMPLETED,
	RESTARTING,
}

var phase: MissionPhase = MissionPhase.INITIALIZING
var _phase_before_pause: MissionPhase = MissionPhase.PLAYING


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_phase(MissionPhase.PLAYING)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func set_phase(next_phase: MissionPhase) -> void:
	if next_phase == phase:
		return
	var previous := phase
	phase = next_phase
	phase_changed.emit(previous, phase)


func set_paused(should_pause: bool) -> void:
	if should_pause == get_tree().paused:
		return
	if should_pause:
		_phase_before_pause = phase
		get_tree().paused = true
		set_phase(MissionPhase.PAUSED)
	else:
		get_tree().paused = false
		set_phase(_phase_before_pause)
	pause_changed.emit(should_pause)


func toggle_pause() -> void:
	set_paused(not get_tree().paused)


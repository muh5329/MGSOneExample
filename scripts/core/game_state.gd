extends Node

signal phase_changed(previous: MissionPhase, current: MissionPhase)
signal pause_changed(is_paused: bool)
signal transition_rejected(current: MissionPhase, requested: MissionPhase, reason: StringName)

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


func can_transition_to(next_phase: MissionPhase) -> bool:
	if next_phase == phase:
		return true
	match phase:
		MissionPhase.INITIALIZING:
			return next_phase == MissionPhase.PLAYING
		MissionPhase.PLAYING:
			return next_phase in [MissionPhase.PAUSED, MissionPhase.PLAYER_DEAD, MissionPhase.COMPLETED]
		MissionPhase.PAUSED:
			return next_phase == _phase_before_pause
		MissionPhase.PLAYER_DEAD:
			return next_phase == MissionPhase.RESTARTING
		MissionPhase.RESTARTING:
			return next_phase in [MissionPhase.PLAYING, MissionPhase.PLAYER_DEAD]
		MissionPhase.COMPLETED:
			return false
	return false


func set_phase(next_phase: MissionPhase) -> bool:
	if next_phase == phase:
		return true
	if next_phase == MissionPhase.PAUSED and not get_tree().paused:
		transition_rejected.emit(phase, next_phase, &"PAUSE_API_REQUIRED")
		return false
	if phase == MissionPhase.PAUSED and get_tree().paused:
		transition_rejected.emit(phase, next_phase, &"PAUSE_API_REQUIRED")
		return false
	if not can_transition_to(next_phase):
		transition_rejected.emit(phase, next_phase, &"INVALID_PHASE_TRANSITION")
		return false
	var previous := phase
	phase = next_phase
	phase_changed.emit(previous, phase)
	return true


func set_paused(should_pause: bool) -> bool:
	if should_pause == get_tree().paused:
		var phase_matches := (
			phase == MissionPhase.PAUSED if should_pause
			else phase != MissionPhase.PAUSED
		)
		if not phase_matches:
			transition_rejected.emit(phase, MissionPhase.PAUSED, &"PAUSE_STATE_MISMATCH")
		return phase_matches
	if should_pause:
		if phase != MissionPhase.PLAYING:
			transition_rejected.emit(phase, MissionPhase.PAUSED, &"PAUSE_UNAVAILABLE")
			return false
		_phase_before_pause = phase
		get_tree().paused = true
		if not set_phase(MissionPhase.PAUSED):
			get_tree().paused = false
			return false
	else:
		if phase != MissionPhase.PAUSED:
			return false
		get_tree().paused = false
		if not set_phase(_phase_before_pause):
			get_tree().paused = true
			return false
	pause_changed.emit(should_pause)
	return true


func toggle_pause() -> void:
	set_paused(not get_tree().paused)


func request_player_death() -> bool:
	return set_phase(MissionPhase.PLAYER_DEAD)


func begin_restart() -> bool:
	return set_phase(MissionPhase.RESTARTING)


func finish_restart() -> bool:
	return set_phase(MissionPhase.PLAYING)


func abort_restart() -> bool:
	return set_phase(MissionPhase.PLAYER_DEAD)


func request_completion() -> bool:
	return set_phase(MissionPhase.COMPLETED)


func reset_for_new_mission() -> void:
	if get_tree().paused:
		get_tree().paused = false
		pause_changed.emit(false)
	var previous := phase
	phase = MissionPhase.PLAYING
	_phase_before_pause = MissionPhase.PLAYING
	if previous != phase:
		phase_changed.emit(previous, phase)

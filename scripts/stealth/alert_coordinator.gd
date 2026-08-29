class_name AlertCoordinator
extends Node

signal phase_changed(previous: AlertPhase, current: AlertPhase, snapshot: Dictionary)
signal detection_announced(report: Dictionary)
signal report_processed(result: Dictionary)
signal shared_knowledge_expired(source_guard_id: StringName)
signal feedback_requested(event_id: StringName, payload: Dictionary)
signal telemetry_updated(snapshot: Dictionary)

enum AlertPhase {
	NORMAL,
	SUSPICIOUS,
	ALERT,
	EVASION,
	SEARCH,
}

const PHASE_NAMES := [&"NORMAL", &"SUSPICIOUS", &"ALERT", &"EVASION", &"SEARCH"]

@export_range(0.0, 60.0, 0.05, "suffix:s") var alert_minimum_duration: float = 12.0
@export_range(0.0, 15.0, 0.05, "suffix:s") var contact_loss_grace: float = 3.0
@export_range(0.0, 30.0, 0.05, "suffix:s") var evasion_duration: float = 8.0
@export_range(0.0, 60.0, 0.05, "suffix:s") var search_duration: float = 20.0
@export_range(0.1, 60.0, 0.05, "suffix:s") var shared_knowledge_duration: float = 12.0
@export_range(0.1, 5.0, 0.05, "suffix:s") var broadcast_refresh_interval: float = 0.75
@export_range(0.0, 2.0, 0.01, "suffix:s") var report_dedupe_window: float = 0.1
@export_range(0.0, 2.0, 0.01, "suffix:s") var report_future_tolerance: float = 0.25

var phase: AlertPhase = AlertPhase.NORMAL
var phase_elapsed: float = 0.0
var contact_loss_elapsed: float = 0.0
var clock_seconds: float = 0.0

var _guards: Dictionary = {}
var _last_report_times: Dictionary = {}
var _recent_reports: Array[Dictionary] = []
var _report_sequence: int = 0
var _shared_position: Vector3 = Vector3.ZERO
var _shared_source_guard_id: StringName = &""
var _shared_evidence: StringName = &""
var _shared_confidence: float = 0.0
var _shared_observed_at: float = 0.0
var _shared_expires_at: float = 0.0
var _has_shared_knowledge: bool = false
var _maximum_suspicion: float = 0.0
var _any_confirmed_sight: bool = false
var _broadcast_elapsed: float = 0.0


func _ready() -> void:
	add_to_group(&"alert_coordinators")
	add_to_group(&"checkpoint_reset_targets")


func _process(delta: float) -> void:
	advance_runtime(delta)


func configure(guard_nodes: Array) -> bool:
	for guard in _guards.values():
		_disconnect_guard(guard as Node)
	_guards.clear()
	_last_report_times.clear()
	var accepted_all := true
	for candidate in guard_nodes:
		if not register_guard(candidate as Node):
			accepted_all = false
	return accepted_all and not _guards.is_empty()


func register_guard(guard: Node) -> bool:
	if guard == null or not guard.has_method(&"get_radar_snapshot") or not guard.has_signal(&"detection_reported"):
		return false
	var snapshot: Dictionary = guard.call(&"get_radar_snapshot")
	var guard_id := StringName(snapshot.get(&"guard_id", &""))
	if guard_id.is_empty() or _guards.has(guard_id):
		return false
	_guards[guard_id] = guard
	var detection_callable := Callable(self, "_on_guard_detection_reported")
	if not guard.is_connected(&"detection_reported", detection_callable):
		guard.connect(&"detection_reported", detection_callable)
	return true


func unregister_guard(guard_id: StringName) -> bool:
	var guard := _guards.get(guard_id) as Node
	if guard == null:
		return false
	_disconnect_guard(guard)
	_guards.erase(guard_id)
	_last_report_times.erase(guard_id)
	return true


func submit_report(report: Dictionary) -> Dictionary:
	var validation := _validate_report(report)
	if not bool(validation.accepted):
		report_processed.emit(validation.duplicate(true))
		return validation
	var observer_id := StringName(report.get(&"observer_id", &""))
	var observed_at := float(report.get(&"observed_at", clock_seconds))
	var last_known_position: Vector3 = report.get(&"last_known_position", report.get(&"target_position", Vector3.ZERO))
	var confidence := clampf(float(report.get(&"confidence", 1.0)), 0.0, 1.0)
	var evidence := StringName(report.get(&"evidence", &"UNKNOWN"))
	_last_report_times[observer_id] = observed_at
	_report_sequence += 1
	var sanitized := {
		&"report_id": _report_sequence,
		&"observer_id": observer_id,
		&"last_known_position": last_known_position,
		&"confidence": confidence,
		&"observed_at": observed_at,
		&"evidence": evidence,
	}
	_recent_reports.append(sanitized)
	while _recent_reports.size() > 16:
		_recent_reports.pop_front()
	_set_shared_knowledge(last_known_position, observer_id, evidence, confidence, observed_at)
	detection_announced.emit(sanitized.duplicate(true))
	feedback_requested.emit(&"DETECTED", sanitized.duplicate(true))
	if phase != AlertPhase.ALERT:
		_set_phase(AlertPhase.ALERT)
	_broadcast_shared_position()
	var result := _result(true, &"ACCEPTED", sanitized)
	report_processed.emit(result.duplicate(true))
	return result


func advance_runtime(delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta):
		return
	if is_inside_tree() and get_tree().paused:
		return
	clock_seconds += delta
	phase_elapsed += delta
	_broadcast_elapsed += delta
	_refresh_guard_observations()
	_expire_shared_knowledge_if_needed()
	match phase:
		AlertPhase.NORMAL:
			if _maximum_suspicion > 0.0:
				_set_phase(AlertPhase.SUSPICIOUS)
		AlertPhase.SUSPICIOUS:
			if _maximum_suspicion <= 0.0:
				_set_phase(AlertPhase.NORMAL)
		AlertPhase.ALERT:
			if _any_confirmed_sight:
				contact_loss_elapsed = 0.0
				_refresh_shared_from_visible_guard()
				if _broadcast_elapsed >= broadcast_refresh_interval:
					_broadcast_shared_position()
			else:
				contact_loss_elapsed += delta
			if phase_elapsed >= alert_minimum_duration and contact_loss_elapsed >= contact_loss_grace:
				_set_phase(AlertPhase.EVASION)
		AlertPhase.EVASION:
			if _any_confirmed_sight:
				_refresh_shared_from_visible_guard()
				_set_phase(AlertPhase.ALERT)
				_broadcast_shared_position()
			elif phase_elapsed >= evasion_duration:
				_set_phase(AlertPhase.SEARCH)
				_broadcast_search_order()
		AlertPhase.SEARCH:
			if _any_confirmed_sight:
				_refresh_shared_from_visible_guard()
				_set_phase(AlertPhase.ALERT)
				_broadcast_shared_position()
			elif phase_elapsed >= search_duration:
				_clear_shared_knowledge(true)
				_set_phase(AlertPhase.SUSPICIOUS if _maximum_suspicion > 0.0 else AlertPhase.NORMAL)
	telemetry_updated.emit(get_alert_snapshot())


func reset_transient_state(_checkpoint_id: StringName) -> void:
	_clear_shared_knowledge(true)
	_recent_reports.clear()
	_last_report_times.clear()
	_report_sequence = 0
	clock_seconds = 0.0
	contact_loss_elapsed = 0.0
	_maximum_suspicion = 0.0
	_any_confirmed_sight = false
	_broadcast_elapsed = 0.0
	_set_phase(AlertPhase.NORMAL, true)
	telemetry_updated.emit(get_alert_snapshot())


func get_alert_snapshot() -> Dictionary:
	return {
		&"phase": PHASE_NAMES[int(phase)],
		&"phase_index": int(phase),
		&"phase_elapsed": phase_elapsed,
		&"time_remaining": _phase_time_remaining(),
		&"contact_loss_remaining": maxf(contact_loss_grace - contact_loss_elapsed, 0.0),
		&"any_confirmed_sight": _any_confirmed_sight,
		&"maximum_suspicion": _maximum_suspicion,
		&"shared_knowledge_valid": _has_shared_knowledge,
		&"last_known_position": _shared_position if _has_shared_knowledge else Vector3.ZERO,
		&"source_guard_id": _shared_source_guard_id if _has_shared_knowledge else &"",
		&"evidence": _shared_evidence if _has_shared_knowledge else &"",
		&"confidence": _shared_confidence if _has_shared_knowledge else 0.0,
		&"knowledge_expires_in": maxf(_shared_expires_at - clock_seconds, 0.0) if _has_shared_knowledge else 0.0,
		&"report_count": _report_sequence,
		&"registered_guard_count": _guards.size(),
	}


func get_recent_reports() -> Array[Dictionary]:
	return _recent_reports.duplicate(true)


func get_guard_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	var ids := _guards.keys()
	ids.sort()
	for guard_id in ids:
		var guard := _guards.get(guard_id) as Node
		if guard != null and is_instance_valid(guard):
			snapshots.append((guard.call(&"get_radar_snapshot") as Dictionary).duplicate(true))
	return snapshots


func get_registered_guard_count() -> int:
	return _guards.size()


func _validate_report(report: Dictionary) -> Dictionary:
	var observer_id := StringName(report.get(&"observer_id", &""))
	if observer_id.is_empty() or not _guards.has(observer_id):
		return _result(false, &"UNKNOWN_OBSERVER")
	var guard := _guards.get(observer_id) as Node
	if guard == null or not is_instance_valid(guard):
		return _result(false, &"UNKNOWN_OBSERVER")
	var guard_snapshot: Dictionary = guard.call(&"get_radar_snapshot")
	if not bool(guard_snapshot.get(&"alive", false)):
		return _result(false, &"OBSERVER_DEAD")
	var position_value: Variant = report.get(&"last_known_position", report.get(&"target_position", null))
	if typeof(position_value) != TYPE_VECTOR3 or not (position_value as Vector3).is_finite():
		return _result(false, &"INVALID_POSITION")
	var confidence_value: Variant = report.get(&"confidence", 1.0)
	if typeof(confidence_value) not in [TYPE_FLOAT, TYPE_INT]:
		return _result(false, &"INVALID_CONFIDENCE")
	var confidence := float(confidence_value)
	if not is_finite(confidence) or confidence < 0.0 or confidence > 1.0:
		return _result(false, &"INVALID_CONFIDENCE")
	var time_value: Variant = report.get(&"observed_at", clock_seconds)
	if typeof(time_value) not in [TYPE_FLOAT, TYPE_INT]:
		return _result(false, &"INVALID_TIME")
	var observed_at := float(time_value)
	if not is_finite(observed_at) or observed_at < 0.0 or observed_at > clock_seconds + report_future_tolerance:
		return _result(false, &"INVALID_TIME")
	if observed_at < clock_seconds - shared_knowledge_duration:
		return _result(false, &"STALE_REPORT")
	if _last_report_times.has(observer_id):
		var previous_time := float(_last_report_times[observer_id])
		if observed_at <= previous_time + report_dedupe_window:
			return _result(false, &"DUPLICATE_REPORT")
	return _result(true, &"VALID")


func _refresh_guard_observations() -> void:
	_maximum_suspicion = 0.0
	_any_confirmed_sight = false
	for snapshot in get_guard_snapshots():
		if not bool(snapshot.get(&"alive", false)):
			continue
		_maximum_suspicion = maxf(_maximum_suspicion, clampf(float(snapshot.get(&"suspicion", 0.0)), 0.0, 1.0))
		_any_confirmed_sight = _any_confirmed_sight or bool(snapshot.get(&"target_visible", false))


func _refresh_shared_from_visible_guard() -> void:
	for snapshot in get_guard_snapshots():
		if bool(snapshot.get(&"alive", false)) and bool(snapshot.get(&"target_visible", false)):
			var position: Vector3 = snapshot.get(&"last_known_position", Vector3.ZERO)
			if position.is_finite():
				_set_shared_knowledge(position, StringName(snapshot.get(&"guard_id", &"")), &"VISION", 1.0, clock_seconds)
				return


func _set_shared_knowledge(
		position: Vector3,
		source_guard_id: StringName,
		evidence: StringName,
		confidence: float,
		observed_at: float
) -> void:
	_shared_position = position
	_shared_source_guard_id = source_guard_id
	_shared_evidence = evidence
	_shared_confidence = confidence
	_shared_observed_at = observed_at
	_shared_expires_at = clock_seconds + shared_knowledge_duration
	_has_shared_knowledge = true


func _expire_shared_knowledge_if_needed() -> void:
	if not _has_shared_knowledge or clock_seconds < _shared_expires_at:
		return
	var expired_source := _shared_source_guard_id
	_clear_shared_knowledge(true)
	shared_knowledge_expired.emit(expired_source)
	feedback_requested.emit(&"SHARED_KNOWLEDGE_EXPIRED", {&"source_guard_id": expired_source})


func _clear_shared_knowledge(notify_guards: bool) -> void:
	if notify_guards:
		for guard in _guards.values():
			var guard_node := guard as Node
			if guard_node != null and is_instance_valid(guard_node) and guard_node.has_method(&"clear_alert_broadcast"):
				guard_node.call(&"clear_alert_broadcast", _shared_source_guard_id)
	_shared_position = Vector3.ZERO
	_shared_source_guard_id = &""
	_shared_evidence = &""
	_shared_confidence = 0.0
	_shared_observed_at = 0.0
	_shared_expires_at = 0.0
	_has_shared_knowledge = false


func _broadcast_shared_position() -> void:
	if not _has_shared_knowledge:
		return
	_broadcast_elapsed = 0.0
	for guard in _guards.values():
		var guard_node := guard as Node
		if guard_node != null and is_instance_valid(guard_node) and guard_node.has_method(&"receive_alert_broadcast"):
			guard_node.call(&"receive_alert_broadcast", _shared_position, _shared_source_guard_id)


func _broadcast_search_order() -> void:
	if not _has_shared_knowledge:
		return
	for guard in _guards.values():
		var guard_node := guard as Node
		if guard_node != null and is_instance_valid(guard_node) and guard_node.has_method(&"receive_alert_search"):
			guard_node.call(&"receive_alert_search", _shared_position, _shared_source_guard_id)


func _set_phase(next_phase: AlertPhase, force: bool = false) -> void:
	if not force and phase == next_phase:
		return
	var previous := phase
	phase = next_phase
	phase_elapsed = 0.0
	contact_loss_elapsed = 0.0
	var snapshot := get_alert_snapshot()
	phase_changed.emit(previous, phase, snapshot)
	feedback_requested.emit(&"ALERT_PHASE_CHANGED", {
		&"previous": PHASE_NAMES[int(previous)],
		&"current": PHASE_NAMES[int(phase)],
		&"snapshot": snapshot,
	})


func _phase_time_remaining() -> float:
	match phase:
		AlertPhase.ALERT:
			return maxf(alert_minimum_duration - phase_elapsed, 0.0)
		AlertPhase.EVASION:
			return maxf(evasion_duration - phase_elapsed, 0.0)
		AlertPhase.SEARCH:
			return maxf(search_duration - phase_elapsed, 0.0)
		_:
			return 0.0


func _on_guard_detection_reported(guard_id: StringName, world_position: Vector3, evidence: StringName) -> void:
	submit_report({
		&"observer_id": guard_id,
		&"last_known_position": world_position,
		&"confidence": 1.0,
		&"observed_at": clock_seconds,
		&"evidence": evidence,
	})


func _disconnect_guard(guard: Node) -> void:
	if guard == null or not is_instance_valid(guard):
		return
	var detection_callable := Callable(self, "_on_guard_detection_reported")
	if guard.has_signal(&"detection_reported") and guard.is_connected(&"detection_reported", detection_callable):
		guard.disconnect(&"detection_reported", detection_callable)


func _result(accepted: bool, reason: StringName, report: Dictionary = {}) -> Dictionary:
	return {
		&"accepted": accepted,
		&"reason": reason,
		&"report": report.duplicate(true),
	}

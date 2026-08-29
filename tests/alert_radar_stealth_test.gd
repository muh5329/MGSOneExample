extends SceneTree

const LEVEL_PATH := "res://scenes/levels/substation_6.tscn"

class GuardProbe:
	extends Node

	signal detection_reported(guard_id: StringName, world_position: Vector3, evidence: StringName)

	var guard_id: StringName
	var world_position: Vector3
	var facing_direction: Vector3 = Vector3.FORWARD
	var state_name: StringName = &"PATROL"
	var suspicion: float = 0.0
	var target_visible: bool = false
	var last_known_position: Vector3 = Vector3.ZERO
	var alive: bool = true
	var broadcast_count: int = 0
	var search_count: int = 0
	var clear_count: int = 0

	func _init(id: StringName, position: Vector3) -> void:
		guard_id = id
		world_position = position

	func get_radar_snapshot() -> Dictionary:
		return {
			&"guard_id": guard_id,
			&"world_position": world_position,
			&"facing_direction": facing_direction,
			&"state": state_name,
			&"suspicion": suspicion,
			&"target_visible": target_visible,
			&"last_known_position": last_known_position,
			&"vision_range": 18.0,
			&"vision_angle_degrees": 70.0,
			&"alive": alive,
		}

	func receive_alert_broadcast(position: Vector3, _source_guard_id: StringName = &"") -> bool:
		if not alive or not position.is_finite():
			return false
		broadcast_count += 1
		last_known_position = position
		state_name = &"ALERT_CHASE"
		return true

	func receive_alert_search(position: Vector3, _source_guard_id: StringName = &"") -> bool:
		if not alive or not position.is_finite():
			return false
		search_count += 1
		last_known_position = position
		state_name = &"SEARCH"
		return true

	func clear_alert_broadcast(_source_guard_id: StringName = &"") -> void:
		clear_count += 1
		last_known_position = Vector3.ZERO
		state_name = &"RETURN"

	func report(position: Vector3, evidence: StringName = &"VISION") -> void:
		last_known_position = position
		detection_reported.emit(guard_id, position, evidence)


var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _validate_alert_contract()
	_validate_radar_math()
	await _validate_mission_integration()
	_finish()


func _validate_alert_contract() -> void:
	var coordinator := AlertCoordinator.new()
	coordinator.alert_minimum_duration = 0.4
	coordinator.contact_loss_grace = 0.2
	coordinator.evasion_duration = 0.3
	coordinator.search_duration = 0.4
	coordinator.shared_knowledge_duration = 0.25
	var g1 := GuardProbe.new(&"G1", Vector3(8.0, 0.0, -4.0))
	var g2 := GuardProbe.new(&"G2", Vector3(30.0, 0.0, 0.0))
	var g3 := GuardProbe.new(&"G3", Vector3(50.0, 0.0, 0.0))
	get_root().add_child(g1)
	get_root().add_child(g2)
	get_root().add_child(g3)
	get_root().add_child(coordinator)
	coordinator.set_process(false)
	if not coordinator.configure([g1, g2, g3]) or coordinator.get_registered_guard_count() != 3:
		failures.append("Alert coordinator did not register all sanitized guard sources.")
	var invalid := coordinator.submit_report({
		&"observer_id": &"G1", &"last_known_position": Vector3.INF,
		&"confidence": 1.0, &"observed_at": 0.0,
	})
	if bool(invalid.accepted) or invalid.reason != &"INVALID_POSITION":
		failures.append("Alert coordinator accepted a non-finite report position.")
	g1.report(Vector3(4.0, 0.0, -3.0))
	g2.report(Vector3(5.0, 0.0, -3.0), &"GUNSHOT")
	var alert_snapshot := coordinator.get_alert_snapshot()
	if coordinator.phase != AlertCoordinator.AlertPhase.ALERT or int(alert_snapshot.report_count) != 2:
		failures.append("Simultaneous independent reports did not produce one authoritative ALERT with both observations recorded.")
	if g1.broadcast_count != 2 or g2.broadcast_count != 2 or g3.broadcast_count != 2:
		failures.append("Accepted reports were not broadcast as bounded position-only knowledge to every living guard.")
	var duplicate := coordinator.submit_report({
		&"observer_id": &"G2", &"last_known_position": Vector3(5.0, 0.0, -3.0),
		&"confidence": 1.0, &"observed_at": 0.0, &"evidence": &"GUNSHOT",
	})
	if bool(duplicate.accepted) or duplicate.reason != &"DUPLICATE_REPORT":
		failures.append("Same-observer duplicate evidence was not rejected deterministically.")

	# A live confirmed observer holds ALERT. The reporter may die without erasing already-shared evidence.
	g2.alive = false
	g1.target_visible = true
	g1.last_known_position = Vector3(6.0, 0.0, -2.0)
	coordinator.advance_runtime(0.7)
	if coordinator.phase != AlertCoordinator.AlertPhase.ALERT:
		failures.append("ALERT dropped while a valid living guard retained confirmed sight.")
	g1.target_visible = false
	coordinator.advance_runtime(0.21)
	if coordinator.phase != AlertCoordinator.AlertPhase.EVASION:
		failures.append("Contact loss did not enter EVASION after minimum ALERT and grace requirements.")
	paused = true
	var paused_elapsed := float(coordinator.get_alert_snapshot().phase_elapsed)
	coordinator.advance_runtime(2.0)
	if not is_equal_approx(float(coordinator.get_alert_snapshot().phase_elapsed), paused_elapsed):
		failures.append("Paused alert runtime consumed a recovery timer.")
	paused = false
	coordinator.advance_runtime(0.31)
	if coordinator.phase != AlertCoordinator.AlertPhase.SEARCH:
		failures.append("EVASION countdown did not enter bounded SEARCH.")
	g1.target_visible = true
	g1.last_known_position = Vector3(7.0, 0.0, -1.0)
	coordinator.advance_runtime(0.01)
	if coordinator.phase != AlertCoordinator.AlertPhase.ALERT:
		failures.append("SEARCH reacquisition did not return directly to ALERT.")
	g1.target_visible = false
	coordinator.advance_runtime(0.41)
	coordinator.advance_runtime(0.21)
	coordinator.advance_runtime(0.31)
	coordinator.advance_runtime(0.41)
	if coordinator.phase != AlertCoordinator.AlertPhase.NORMAL:
		failures.append("SEARCH did not eventually terminate at NORMAL with no remaining suspicion.")
	if bool(coordinator.get_alert_snapshot().shared_knowledge_valid) or g1.clear_count <= 0:
		failures.append("Shared last-known information did not expire and release guard knowledge.")

	# Radar authorization uses the same phase snapshot and never returns data while jammed/hidden.
	g2.alive = true
	coordinator.reset_transient_state(&"TEST")
	g2.report(Vector3(8.0, 0.0, 0.0))
	var player := Node3D.new()
	get_root().add_child(player)
	var radar := TacticalRadar.new()
	radar.size = Vector2(248.0, 260.0)
	get_root().add_child(radar)
	radar.set_process(false)
	if not radar.configure(player, coordinator, [g1, g2, g3], [
		{&"a": Vector3(-5.0, 0.0, -5.0), &"b": Vector3(5.0, 0.0, -5.0)},
	]):
		failures.append("Radar rejected valid player, alert, guard, or approved-map sources.")
	var alert_radar := radar.get_render_snapshot()
	if bool(alert_radar.cones_visible) or (alert_radar.contacts as Array).size() != 2:
		failures.append("ALERT radar did not hide cones, clamp in-range contacts, or cull contacts beyond authorization range.")
	var found_clamped := false
	for contact in alert_radar.contacts:
		if bool(contact.clamped):
			found_clamped = true
		if not bool(contact.coarse):
			failures.append("ALERT radar leaked a precise guard contact.")
	if not found_clamped:
		failures.append("Out-of-local-range radar contact was not clamped to the radar boundary.")
	radar.set_radar_mode(TacticalRadar.RadarMode.JAMMED)
	var jammed := radar.get_render_snapshot()
	if not (jammed.contacts as Array).is_empty() or not (jammed.walls as Array).is_empty():
		failures.append("Jammed radar leaked contacts or approved map geometry through its render snapshot.")
	radar.set_radar_mode(TacticalRadar.RadarMode.HIDDEN)
	var hidden := radar.get_render_snapshot()
	if radar.visible or not (hidden.contacts as Array).is_empty() or not (hidden.walls as Array).is_empty():
		failures.append("Hidden radar remained visible or leaked tactical data.")
	radar.set_radar_mode(TacticalRadar.RadarMode.ACTIVE)
	coordinator.reset_transient_state(&"TEST")
	var normal_radar := radar.get_render_snapshot()
	if not bool(normal_radar.cones_visible) or (normal_radar.walls as Array).size() != 1:
		failures.append("NORMAL radar did not restore honest cones and approved local map geometry.")

	radar.queue_free()
	player.queue_free()
	coordinator.queue_free()
	g1.queue_free()
	g2.queue_free()
	g3.queue_free()
	await process_frame


func _validate_radar_math() -> void:
	var player_position := Vector3(10.0, 0.0, 20.0)
	var east := TacticalRadar.world_to_radar(Vector3(15.0, 0.0, 20.0), player_position, 2.0)
	var north := TacticalRadar.world_to_radar(Vector3(10.0, 0.0, 15.0), player_position, 2.0)
	if east.distance_to(Vector2(10.0, 0.0)) > 0.001 or north.distance_to(Vector2(0.0, -10.0)) > 0.001:
		failures.append("North-up world-to-radar conversion changed with world origin or axis orientation.")
	if TacticalRadar.facing_to_radar(Vector3.FORWARD).distance_to(Vector2.UP) > 0.001:
		failures.append("World-forward facing did not align with north-up radar facing.")
	var boundary := TacticalRadar.project_contact(Vector3(40.0, 0.0, 20.0), player_position, 2.0, 20.0, 40.0)
	if bool(boundary.culled) or not bool(boundary.clamped) or absf((boundary.position as Vector2).length() - 20.0) > 0.001:
		failures.append("Radar boundary projection did not preserve direction while clamping distance.")
	var culled := TacticalRadar.project_contact(Vector3(60.0, 0.0, 20.0), player_position, 2.0, 20.0, 40.0)
	if not bool(culled.culled):
		failures.append("Radar exposed a contact beyond the maximum authorized distance.")


func _validate_mission_integration() -> void:
	var packed := load(LEVEL_PATH) as PackedScene
	if packed == null:
		failures.append("Substation 6 does not load with Build 09 alert/radar integration.")
		return
	var level := packed.instantiate() as Substation6
	get_root().add_child(level)
	await process_frame
	await physics_frame
	if level.alert_coordinator.get_registered_guard_count() != 4:
		failures.append("Production alert coordinator did not bind exactly G1-G4.")
	var radar_snapshot := level.tactical_radar.get_render_snapshot()
	if radar_snapshot.orientation != &"NORTH_UP" or (radar_snapshot.walls as Array).is_empty():
		failures.append("Production radar lacks north-up policy or approved Substation 6 wall data.")
	var guards := level.guard_root.get_children()
	if guards.size() == 4:
		var reporter := guards[0] as GuardActor
		reporter.detection_reported.emit(reporter.guard_id, level.player.global_position, &"VISION")
		if level.alert_coordinator.phase != AlertCoordinator.AlertPhase.ALERT:
			failures.append("Production guard report did not reach the sole alert authority.")
		for guard in guards:
			if (guard as GuardActor).state not in [GuardActor.GuardState.ALERT_CHASE, GuardActor.GuardState.ATTACK]:
				failures.append("Production facility broadcast did not coordinate every living guard from position-only knowledge.")
				break
	level.alert_coordinator.reset_transient_state(&"CP0_INSERTION")
	var reset_snapshot := level.alert_coordinator.get_alert_snapshot()
	if reset_snapshot.phase != &"NORMAL" or bool(reset_snapshot.shared_knowledge_valid) or int(reset_snapshot.report_count) != 0:
		failures.append("Checkpoint reset left a stale alert phase, report, or shared position.")
	level.queue_free()
	await process_frame


func _finish() -> void:
	if paused:
		paused = false
	if failures.is_empty():
		print("ALERT/RADAR PASS: reports, recovery, pause/reset, north-up conversion, restrictions, and mission integration are valid.")
		quit(0)
		return
	for failure in failures:
		push_error("ALERT/RADAR FAIL: %s" % failure)
	quit(1)

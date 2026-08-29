extends SceneTree

const LAB_PATH := "res://scenes/levels/enemy_ai_test_room.tscn"
const LEVEL_PATH := "res://scenes/levels/substation_6.tscn"

var failures: Array[String] = []
var _detection_reports: int = 0
var _combat_requests: int = 0
var _mission_reports: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_validate_cone_math()
	await _validate_lab_perception_and_states()
	await _validate_mission_integration()
	_finish()


func _validate_cone_math() -> void:
	var eye := Vector3(0.0, 1.5, 0.0)
	if not GuardPerception3D.is_point_in_view(eye, Vector3.FORWARD, Vector3(0.0, 1.5, -10.0), 18.0, 70.0, 70.0):
		failures.append("A centered in-range target failed the cone broad phase.")
	if GuardPerception3D.is_point_in_view(eye, Vector3.FORWARD, Vector3(10.0, 1.5, 0.0), 18.0, 70.0, 70.0):
		failures.append("A target outside the horizontal cone passed broad phase.")
	if GuardPerception3D.is_point_in_view(eye, Vector3.FORWARD, Vector3(0.0, 15.0, -3.0), 18.0, 70.0, 70.0):
		failures.append("A target outside the vertical cone passed broad phase.")
	if GuardPerception3D.is_point_in_view(eye, Vector3.FORWARD, Vector3(0.0, 1.5, -19.0), 18.0, 70.0, 70.0):
		failures.append("An out-of-range target passed broad phase.")


func _validate_lab_perception_and_states() -> void:
	var packed := load(LAB_PATH) as PackedScene
	if packed == null:
		failures.append("Enemy AI laboratory scene does not load.")
		return
	var lab := packed.instantiate() as EnemyAITestRoom
	if lab == null:
		failures.append("Enemy AI laboratory scene did not instantiate with its typed owner.")
		return
	get_root().add_child(lab)
	await process_frame
	await physics_frame
	await physics_frame
	var guard := lab.guard
	var player := lab.player
	guard.detection_reported.connect(func(_id: StringName, _position: Vector3, _evidence: StringName) -> void:
		_detection_reports += 1
	)
	guard.combat_requested.connect(func(_id: StringName, _target: Node3D, _context: HitContext3D) -> void:
		_combat_requests += 1
	)

	# The solid center block occupies both world and perception layers.
	guard.global_position = Vector3(0.0, 0.02, -7.0)
	player.global_position = Vector3(0.0, 0.02, 7.0)
	guard.look_at(player.global_position + Vector3.UP, Vector3.UP)
	await physics_frame
	var blocked := guard.perception.scan_target()
	if bool(blocked.visible) or not bool(blocked.blocked):
		failures.append("Solid perception geometry did not block every target sample.")

	# Moving around the blocker makes the exact same target visible.
	player.global_position = Vector3(6.0, 0.02, -2.0)
	guard.look_at(player.global_position + Vector3.UP, Vector3.UP)
	await physics_frame
	var visible := guard.perception.scan_target()
	if not bool(visible.visible) or bool(visible.blocked):
		failures.append("An in-cone, unobstructed target was not reported visible.")

	# Suspicion accumulation is delta-based and brief exposure remains sub-confirmation.
	guard.perception.reset_perception()
	guard.perception.advance_perception(0.2)
	var coarse_suspicion := guard.perception.suspicion
	if coarse_suspicion <= 0.0 or coarse_suspicion >= 1.0 or _detection_reports != 0:
		failures.append("Brief edge exposure did not produce readable partial suspicion.")
	guard.perception.reset_perception()
	for _step in 12:
		guard.perception.advance_perception(1.0 / 60.0)
	if absf(guard.perception.suspicion - coarse_suspicion) > 0.015:
		failures.append("Suspicion accumulation changed materially with physics step size.")
	guard.perception.reset_perception()
	guard.perception.advance_perception(guard.config.suspicion_decay_time)
	if guard.perception.suspicion < 0.0 or guard.perception.suspicion > 1.0:
		failures.append("Suspicion escaped normalized bounds during decay.")

	# Crouching changes range but never overrides occlusion.
	guard.global_position = Vector3(-7.0, 0.02, -7.0)
	player.global_position = Vector3(7.0, 0.02, -2.0)
	guard.look_at(player.global_position + Vector3.UP, Vector3.UP)
	player.request_crouch(false)
	await physics_frame
	if not bool(guard.perception.scan_target().visible):
		failures.append("Standing target inside 18 m was not visible in a clear lane.")
	player.request_crouch(true)
	await physics_frame
	if bool(guard.perception.scan_target().visible):
		failures.append("Crouched target outside the 13 m tuning range remained visible.")
	player.request_crouch(false)

	# Hearing records an event location and never follows the source afterward.
	guard.perception.reset_perception()
	var heard_position := guard.global_position + Vector3(0.0, 0.0, 3.0)
	var movement_noise := NoiseEvent3D.new(player, heard_position, 1.0, &"player_movement")
	if not guard.perception.receive_noise(movement_noise):
		failures.append("Audible normalized movement noise did not create a local stimulus.")
	player.global_position += Vector3(5.0, 0.0, 0.0)
	if guard.perception.last_stimulus_position.distance_to(heard_position) > 0.001:
		failures.append("Noise investigation became omniscient source tracking.")
	var far_noise := NoiseEvent3D.new(player, guard.global_position + Vector3(0.0, 0.0, 6.0), 1.0, &"player_movement")
	if guard.perception.receive_noise(far_noise):
		failures.append("Movement noise outside its configured hearing radius was accepted.")
	guard.global_position = Vector3(0.0, 0.02, -4.0)
	await physics_frame
	var occluded_noise := NoiseEvent3D.new(player, Vector3(0.0, 0.02, 0.0), 1.0, &"player_movement")
	if guard.perception.receive_noise(occluded_noise):
		failures.append("Layer-6 occlusion did not attenuate nominally in-range movement noise.")

	# A gunshot is identifying evidence, but sharing still leaves through a report signal.
	guard.perception.reset_perception()
	var before_reports := _detection_reports
	var gunshot_position := guard.global_position + Vector3(10.0, 0.0, 0.0)
	if not guard.perception.receive_noise(NoiseEvent3D.new(player, gunshot_position, 30.0, &"gunshot")):
		failures.append("In-range gunshot evidence was not heard.")
	if _detection_reports != before_reports + 1 or guard.state != GuardActor.GuardState.ALERT_CHASE:
		failures.append("Gunshot identification did not produce one guard-to-alert report.")

	# Lost information produces bounded search and a recoverable return state.
	player.global_position = Vector3(100.0, 0.02, 100.0)
	guard.advance_runtime(guard.config.lost_sight_grace + 0.05)
	if guard.state != GuardActor.GuardState.SEARCH:
		failures.append("Losing confirmed information did not enter bounded SEARCH.")
	guard.advance_runtime(guard.config.local_search_duration + 0.05)
	if guard.state != GuardActor.GuardState.RETURN:
		failures.append("Bounded local search did not recover toward the authored patrol.")
	if guard.receive_alert_broadcast(Vector3.INF, &"OTHER"):
		failures.append("Guard accepted a non-finite alert position.")

	# Attack damage is delayed until the telegraph/cadence boundary and uses typed context.
	guard.reset_transient_state(&"TEST")
	player.global_position = guard.global_position + Vector3(0.0, 0.0, -5.0)
	guard.look_at(player.global_position + Vector3.UP, Vector3.UP)
	guard.perception.reset_perception()
	guard.receive_alert_broadcast(player.global_position, &"OTHER")
	guard.perception.advance_perception(guard.config.sight_confirmation_time)
	guard.advance_runtime(0.01)
	var health_before := player.health.current_health
	guard.advance_runtime(guard.config.attack_telegraph_duration - 0.02)
	if not is_equal_approx(player.health.current_health, health_before):
		failures.append("Guard attack applied damage before its readable telegraph completed.")
	guard.advance_runtime(guard.config.attack_cadence)
	if not is_equal_approx(player.health.current_health, health_before - guard.config.attack_damage) or _combat_requests != 1:
		failures.append("Guard attack did not submit one 20-damage typed combat request at cadence.")

	var lethal_context := HitContext3D.new(
		player, &"TEST", 1, guard.global_position, Vector3.UP, Vector3.FORWARD, 100.0,
		PackedStringArray(["test"])
	)
	player.receive_damage(player.health.current_health, lethal_context)
	guard.advance_runtime(0.05)
	if guard.state in [GuardActor.GuardState.ALERT_CHASE, GuardActor.GuardState.ATTACK]:
		failures.append("Target death left guard attack/navigation logic active.")
	player.health.restore_checkpoint_snapshot({
		&"current_health": player.health.maximum_health,
		&"maximum_health": player.health.maximum_health,
		&"is_dead": false,
	})

	# Guard death, pause, and checkpoint reset halt and restore all transient work.
	guard.receive_damage(guard.health.maximum_health, lethal_context)
	if guard.state != GuardActor.GuardState.DEAD or guard.perception.perception_enabled:
		failures.append("Guard death left decision or perception processing active.")
	player.global_position = Vector3(100.0, 0.02, 100.0)
	guard.reset_transient_state(&"CP1_SWITCH_ENTRY")
	await process_frame
	if guard.state != GuardActor.GuardState.PATROL or guard.health.is_dead or not is_equal_approx(guard.health.current_health, guard.health.maximum_health):
		failures.append("Checkpoint reset did not restore a living guard to authored patrol state.")
	var state_time_before_pause := float(guard.get_state_snapshot().state_time)
	paused = true
	await process_frame
	await process_frame
	if not is_equal_approx(float(guard.get_state_snapshot().state_time), state_time_before_pause):
		failures.append("SceneTree pause advanced a guard decision timer.")
	paused = false

	var radar := guard.get_radar_snapshot()
	for required_key in [
		&"guard_id", &"world_position", &"facing_direction", &"state", &"suspicion",
		&"target_visible", &"last_known_position", &"vision_range", &"vision_angle_degrees", &"alive",
	]:
		if not radar.has(required_key):
			failures.append("Sanitized radar snapshot is missing '%s'." % required_key)
	if radar.has(&"state_machine") or radar.has(&"target") or radar.has(&"navigation_agent"):
		failures.append("Radar snapshot leaked guard state-machine objects.")

	lab.queue_free()
	await process_frame


func _validate_mission_integration() -> void:
	var packed := load(LEVEL_PATH) as PackedScene
	if packed == null:
		failures.append("Substation 6 does not load with production guards.")
		return
	var level := packed.instantiate() as Substation6
	get_root().add_child(level)
	await process_frame
	await physics_frame
	var guards := get_nodes_in_group(&"guards")
	if guards.size() != 4:
		failures.append("Expected four production guards, found %d." % guards.size())
	var ids: Dictionary = {}
	var mission_guards: Array[GuardActor] = []
	for node in guards:
		var guard := node as GuardActor
		if guard == null or guard.patrol_route == null or guard.target != level.player:
			failures.append("A production guard is missing its route or observable target adapter.")
			continue
		ids[guard.guard_id] = true
		mission_guards.append(guard)
		if not guard.is_in_group(&"checkpoint_reset_targets"):
			failures.append("Guard %s is absent from the transient checkpoint reset contract." % guard.guard_id)
		if guard.patrol_route.route_id != guard.guard_id:
			failures.append("Guard %s is not bound to its same-ID authored patrol route." % guard.guard_id)
	for expected_id in [&"G1", &"G2", &"G3", &"G4"]:
		if not ids.has(expected_id):
			failures.append("Mission guard %s is missing." % expected_id)
	_mission_reports = 0
	for index in mini(2, mission_guards.size()):
		var guard := mission_guards[index]
		guard.detection_reported.connect(_on_mission_report)
		guard.perception.reset_perception()
		guard.perception.receive_noise(NoiseEvent3D.new(level.player, guard.global_position, 30.0, &"gunshot"))
	if _mission_reports != 2:
		failures.append("Multiple guards did not submit independent observations through report signals.")
	level.queue_free()
	await process_frame


func _on_mission_report(_id: StringName, _position: Vector3, _evidence: StringName) -> void:
	_mission_reports += 1


func _finish() -> void:
	if paused:
		paused = false
	if failures.is_empty():
		print("ENEMY AI PASS: vision, occlusion, suspicion, hearing, states, combat, reset, and mission guards are valid.")
		quit(0)
		return
	for failure in failures:
		push_error("ENEMY AI FAIL: %s" % failure)
	quit(1)

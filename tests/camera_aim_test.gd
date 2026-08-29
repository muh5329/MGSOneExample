extends SceneTree

const RIG_SCENE_PATH := "res://scenes/camera/gameplay_camera_rig.tscn"
const TEST_ROOM_PATH := "res://scenes/levels/camera_aim_test_room.tscn"
const SETTINGS_PATH := "res://data/camera/default_camera_aim_settings.tres"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_validate_resources()
	_validate_zone_selection()
	await _validate_rig_contract()
	if failures.is_empty():
		print("CAMERA PASS: zones, transitions, aim locks, limits, ray, pause, and fallback are valid.")
		quit(0)
		return
	for failure in failures:
		push_error("CAMERA FAIL: %s" % failure)
	quit(1)


func _validate_resources() -> void:
	for path in [RIG_SCENE_PATH, TEST_ROOM_PATH, SETTINGS_PATH]:
		if not ResourceLoader.exists(path):
			failures.append("Missing camera resource '%s'." % path)
	var room_scene := load(TEST_ROOM_PATH) as PackedScene
	var room := room_scene.instantiate() if room_scene != null else null
	if room == null:
		failures.append("Camera test room does not instantiate.")
	else:
		room.free()


func _validate_zone_selection() -> void:
	var low := _make_zone(&"LOW", 1)
	var alpha := _make_zone(&"ALPHA", 2)
	var beta := _make_zone(&"BETA", 2)
	var zone_root := Node3D.new()
	get_root().add_child(zone_root)
	zone_root.add_child(low)
	zone_root.add_child(alpha)
	zone_root.add_child(beta)
	var candidates: Array[CameraZone3D] = [low, beta, alpha]
	if GameplayCameraRig.choose_zone(candidates) != alpha:
		failures.append("Equal-priority zone selection is not stable by zone ID.")
	if GameplayCameraRig.choose_zone(candidates, beta) != beta:
		failures.append("Current zone does not win equal-priority overlap hysteresis.")
	if GameplayCameraRig.choose_zone(candidates, low) != alpha:
		failures.append("A lower-priority current zone blocked a higher-priority zone.")
	if not alpha.contains_world_point(Vector3(1.9, 0.0, 1.9)):
		failures.append("Camera zone rejected an interior point.")
	if alpha.contains_world_point(Vector3(2.1, 0.0, 0.0)):
		failures.append("Camera zone accepted a point beyond its bounds.")
	zone_root.free()


func _validate_rig_contract() -> void:
	var world := Node3D.new()
	get_root().add_child(world)
	var player_scene := load("res://scenes/actors/player.tscn") as PackedScene
	var player := player_scene.instantiate() as PlayerController
	world.add_child(player)
	var zone_a := _make_zone(&"ZONE_A", 1)
	zone_a.data.camera_offset = Vector3(6.0, 8.0, 8.0)
	zone_a.data.blend_duration = 0.01
	world.add_child(zone_a)
	var zone_b := _make_zone(&"ZONE_B", 1)
	zone_b.position.x = 6.0
	zone_b.data.camera_offset = Vector3(-6.0, 8.0, -8.0)
	zone_b.data.blend_duration = 0.01
	world.add_child(zone_b)
	var rig_scene := load(RIG_SCENE_PATH) as PackedScene
	var rig := rig_scene.instantiate() as GameplayCameraRig
	rig.input_enabled = false
	world.add_child(rig)
	rig.set_tracked_actor(player)
	await process_frame
	await physics_frame
	if rig.active_zone != zone_a:
		failures.append("Rig did not select the authored zone containing the player.")

	var rejection: Array[StringName] = []
	rig.aim_rejected.connect(func(reason: StringName) -> void: rejection.append(reason))
	if rig.request_aim(true):
		failures.append("Aim entered without an equipped weapon.")
	if rejection.is_empty() or rejection.back() != GameplayCameraRig.AIM_REJECTED_NO_WEAPON:
		failures.append("No-weapon aim rejection did not expose its reason.")

	rig.set_weapon_equipped(true)
	if not rig.request_aim(true):
		failures.append("Aim was rejected with valid context.")
	rig.request_aim(false)
	if rig.active_zone != zone_a:
		failures.append("An immediate aim tap incorrectly discarded the active zone.")
	if not rig.request_aim(true):
		failures.append("Aim did not re-enter after a valid tap exit.")
	if player.control_enabled:
		failures.append("First-person aim did not root player translation.")
	await process_frame
	var aim_direction := rig.get_aim_direction()
	_expect_near(aim_direction.length(), 1.0, 0.0001, "Aim direction is not normalized.")
	var center := rig.gameplay_camera.get_viewport().get_visible_rect().size * 0.5
	var projected_direction := rig.gameplay_camera.project_ray_normal(center)
	if aim_direction.distance_to(projected_direction) > 0.001:
		failures.append("Aim ray does not match the viewport center.")

	rig._apply_look_delta(Vector2(10000.0, 10000.0))
	_expect_near(
		absf(rig._aim_yaw_offset),
		deg_to_rad(rig.settings.yaw_limit_degrees),
		0.0001,
		"Aim yaw did not clamp to the configured limit."
	)
	_expect_near(
		rig._aim_pitch,
		deg_to_rad(rig.settings.pitch_up_limit_degrees),
		0.0001,
		"Aim pitch did not clamp to the configured upper limit."
	)
	player.global_position.x = 6.0
	await physics_frame
	await physics_frame
	if rig.active_zone != zone_a:
		failures.append("Zone transition was not deferred during first-person aim.")
	if rig._pending_zone != zone_b:
		failures.append("Latest zone was not queued while first-person aim was active (player: %s, contains: %s)." % [
			player.global_position,
			zone_b.contains_world_point(player.global_position),
		])

	var game_state := get_root().get_node("GameState")
	game_state.set_paused(true)
	if rig.mode != GameplayCameraRig.CameraMode.EXPLORATION:
		failures.append("Pause did not exit first-person aim.")
	if not player.control_enabled:
		failures.append("Pause exit left the aim movement lock active.")
	game_state.set_paused(false)
	await physics_frame
	if rig.active_zone != zone_b:
		failures.append("Deferred zone transition was not applied after aim exited (active: %s)." % (
			String(rig.active_zone.get_zone_id()) if rig.active_zone != null else "FALLBACK"
		))
	for _frame in 4:
		await process_frame
	if rig.is_transitioning:
		failures.append("Short camera blend did not settle on its authored target.")

	zone_b.data.aim_allowed = false
	if rig.request_aim(true):
		failures.append("Aim entered inside a zone that disallows first-person mode.")
	if rejection.is_empty() or rejection.back() != GameplayCameraRig.AIM_REJECTED_ZONE:
		failures.append("No-aim zone rejection did not expose its reason.")
	zone_b.data.aim_allowed = true
	rig.set_modal_active(true)
	if rig.request_aim(true):
		failures.append("Aim entered while a modal owner was active.")
	rig.set_modal_active(false)
	rig.set_interaction_active(true)
	if rig.request_aim(true):
		failures.append("Aim entered during an interaction owner lock.")
	rig.set_interaction_active(false)
	if not rig.request_aim(true):
		failures.append("Aim did not recover after modal closure.")
	rig.set_weapon_equipped(false)
	if rig.mode != GameplayCameraRig.CameraMode.EXPLORATION:
		failures.append("Unequipping the weapon did not exit aim.")

	var current_cameras := 0
	for camera in world.find_children("*", "Camera3D", true, false):
		if (camera as Camera3D).current:
			current_cameras += 1
	if current_cameras != 1:
		failures.append("The camera rig did not leave exactly one gameplay camera current.")
	world.queue_free()
	await process_frame


func _make_zone(zone_id: StringName, priority: int) -> CameraZone3D:
	var zone := CameraZone3D.new()
	zone.data = CameraZoneData.new()
	zone.data.zone_id = zone_id
	zone.data.priority = priority
	zone.data.volume_size = Vector3(4.0, 4.0, 4.0)
	return zone


func _expect_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s Expected %.4f, got %.4f." % [message, expected, actual])

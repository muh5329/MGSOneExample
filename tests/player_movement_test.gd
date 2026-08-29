extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/actors/player.tscn"
const TEST_ROOM_PATH := "res://scenes/levels/locomotion_test_room.tscn"
const CONFIG_PATH := "res://data/player/default_player_movement_config.tres"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_validate_resources()
	_validate_direction_math()
	_validate_camera_basis_latch()
	_validate_noise_math()
	_validate_player_contract()
	await _validate_blocked_uncrouch()
	if failures.is_empty():
		print("MOVEMENT PASS: direction, speed, locks, noise, scenes, and blocked uncrouch are valid.")
		quit(0)
		return
	for failure in failures:
		push_error("MOVEMENT FAIL: %s" % failure)
	quit(1)


func _validate_resources() -> void:
	for path in [PLAYER_SCENE_PATH, TEST_ROOM_PATH, CONFIG_PATH]:
		if not ResourceLoader.exists(path):
			failures.append("Missing movement resource '%s'." % path)
	var room_scene := load(TEST_ROOM_PATH) as PackedScene
	if room_scene == null:
		failures.append("Locomotion test room does not instantiate.")
	else:
		var room := room_scene.instantiate()
		if room == null:
			failures.append("Locomotion test room does not instantiate.")
		else:
			room.free()


func _validate_direction_math() -> void:
	var diagonal := PlayerController.camera_relative_direction(Vector2(1.0, -1.0), Basis.IDENTITY)
	_expect_near(diagonal.length(), 1.0, 0.0001, "Diagonal input exceeds normalized speed.")
	var half_tilt := PlayerController.camera_relative_direction(Vector2(0.0, -0.5), Basis.IDENTITY)
	_expect_near(half_tilt.length(), 0.5, 0.0001, "Analog input magnitude is not preserved linearly.")
	var forward := PlayerController.camera_relative_direction(Vector2(0.0, -1.0), Basis.IDENTITY)
	_expect_vector_near(forward, Vector3.FORWARD, 0.0001, "Identity camera forward is incorrect.")
	var rotated_basis := Basis(Vector3.UP, PI * 0.5)
	var rotated_forward := PlayerController.camera_relative_direction(Vector2(0.0, -1.0), rotated_basis)
	var expected_forward := -rotated_basis.z.normalized()
	_expect_vector_near(
		rotated_forward,
		expected_forward,
		0.0001,
		"Movement is not camera-relative after a 90-degree camera change."
	)


func _validate_camera_basis_latch() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var player := player_scene.instantiate() as PlayerController
	player.set_camera_basis(Basis.IDENTITY)
	var initial_direction := player._movement_direction_for_input(Vector2(0.0, -1.0))
	player.set_camera_basis(Basis(Vector3.UP, PI))
	var held_direction := player._movement_direction_for_input(Vector2(0.0, -1.0))
	_expect_vector_near(
		held_direction,
		initial_direction,
		0.0001,
		"Held input changed world direction during a camera-basis transition."
	)
	player._movement_direction_for_input(Vector2.ZERO)
	var released_direction := player._movement_direction_for_input(Vector2(0.0, -1.0))
	_expect_vector_near(
		released_direction,
		Vector3.BACK,
		0.0001,
		"New input did not adopt the current camera basis after release."
	)
	player.free()


func _validate_noise_math() -> void:
	_expect_near(
		PlayerController.normalized_noise(4.5, 4.5, 1.0, 1.0, true),
		1.0,
		0.0001,
		"Full-speed standing noise should be normalized to 1.0."
	)
	_expect_near(
		PlayerController.normalized_noise(2.6, 2.6, 0.3, 1.0, true),
		0.3,
		0.0001,
		"Full-speed crouch noise should match the 0.3 stance multiplier."
	)
	_expect_near(
		PlayerController.normalized_noise(4.5, 4.5, 1.0, 1.0, false),
		0.0,
		0.0001,
		"Airborne motion must not emit footstep noise."
	)


func _validate_player_contract() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		failures.append("Player scene does not load.")
		return
	var player := player_scene.instantiate() as PlayerController
	if player == null:
		failures.append("Player scene root is not PlayerController.")
		return
	if player.collision_layer != 2 or player.collision_mask != 5:
		failures.append("Player collision contract must be layer 2 with world/enemy mask 1|3.")
	var body_collision := player.get_node("BodyCollision") as CollisionShape3D
	var capsule := body_collision.shape as CapsuleShape3D
	_expect_near(capsule.radius, 0.4, 0.0001, "Player capsule radius does not match tuning.")
	_expect_near(capsule.height, 1.8, 0.0001, "Player standing capsule height does not match tuning.")
	player.velocity = Vector3(2.0, -3.0, -1.0)
	player.set_aim_movement_locked(true)
	if player.control_enabled:
		failures.append("Aim lock did not disable movement control.")
	_expect_near(Vector2(player.velocity.x, player.velocity.z).length(), 0.0, 0.0001, "Control lock left residual planar velocity.")
	_expect_near(player.velocity.y, -3.0, 0.0001, "Control lock incorrectly erased gravity velocity.")
	player.set_control_lock(PlayerController.ControlLock.MENU, true)
	player.set_aim_movement_locked(false)
	if player.control_enabled:
		failures.append("Clearing one reason incorrectly cleared another active control lock.")
	player.set_control_lock(PlayerController.ControlLock.MENU, false)
	if not player.control_enabled:
		failures.append("Clearing every lock did not restore movement control.")
	player.free()


func _validate_blocked_uncrouch() -> void:
	var world := Node3D.new()
	get_root().add_child(world)
	var ceiling := StaticBody3D.new()
	ceiling.collision_layer = 1
	ceiling.collision_mask = 0
	var ceiling_collision := CollisionShape3D.new()
	var ceiling_shape := BoxShape3D.new()
	ceiling_shape.size = Vector3(3.0, 0.2, 3.0)
	ceiling_collision.shape = ceiling_shape
	ceiling.add_child(ceiling_collision)
	ceiling.position = Vector3(0.0, 1.45, 0.0)
	world.add_child(ceiling)

	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var player := player_scene.instantiate() as PlayerController
	world.add_child(player)
	await physics_frame
	await physics_frame
	if not player.request_crouch(true):
		failures.append("Player could not enter crouch stance.")
	if player.request_crouch(false):
		failures.append("Player stood through a low ceiling.")
	if player.stance != PlayerController.Stance.CROUCHED:
		failures.append("Blocked uncrouch desynchronized stance state.")
	world.queue_free()
	await process_frame


func _expect_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s Expected %.4f, got %.4f." % [message, expected, actual])


func _expect_vector_near(actual: Vector3, expected: Vector3, tolerance: float, message: String) -> void:
	if actual.distance_to(expected) > tolerance:
		failures.append("%s Expected %s, got %s." % [message, expected, actual])

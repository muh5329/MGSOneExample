extends SceneTree

const TEST_ROOM_PATH := "res://scenes/levels/combat_test_room.tscn"
const PISTOL := preload("res://data/weapons/w1_service_pistol.tres")

var failures: Array[String] = []
var _shot_contexts: Array[HitContext3D] = []
var _dry_fire_reasons: Array[StringName] = []
var _impact_colliders: Array[Object] = []
var _feedback_ids: Array[StringName] = []
var _gunshot_noise_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(TEST_ROOM_PATH) as PackedScene
	if packed == null:
		failures.append("Combat test room does not load.")
		_finish()
		return
	var room := packed.instantiate()
	get_root().add_child(room)
	await process_frame
	await physics_frame

	var player := room.get_node("Player") as PlayerController
	var camera_rig := room.get_node("GameplayCameraRig") as GameplayCameraRig
	var weapon := player.get_node("VisualRoot/WeaponController") as WeaponController
	var ammo_source := room.get_node("AmmoSource") as CombatTestAmmoSource
	var static_target := room.get_node("StaticTarget") as CombatTestReceiver3D
	var moving_target := room.get_node("MovingTarget") as CombatTestReceiver3D
	var near_wall := room.get_node("NearWall") as StaticBody3D
	weapon.input_enabled = false
	weapon.set_process(false)
	moving_target.moves = false
	weapon.shot_fired.connect(func(context: HitContext3D) -> void: _shot_contexts.append(context))
	weapon.dry_fired.connect(func(reason: StringName) -> void: _dry_fire_reasons.append(reason))
	weapon.impact_resolved.connect(func(_context: HitContext3D, collider: Object) -> void: _impact_colliders.append(collider))
	weapon.feedback_requested.connect(func(feedback_id: StringName, _payload: Dictionary) -> void: _feedback_ids.append(feedback_id))
	get_root().get_node("EventBus").connect(&"noise_emitted", func(event: NoiseEvent3D) -> void:
		if event.category == &"gunshot" and event.loudness == PISTOL.gunshot_loudness:
			_gunshot_noise_count += 1
	)

	_validate_definition()
	weapon.advance_runtime(1.0)
	if weapon.state != WeaponController.WeaponState.READY:
		failures.append("Initial pistol equip did not settle to READY.")
	var initial_magazine := weapon.magazine
	if weapon.request_fire() or weapon.magazine != initial_magazine:
		failures.append("Exploration-mode fire was not ignored.")
	if not camera_rig.request_aim(true):
		failures.append("Equipped pistol did not enable the public aim gate.")
	await process_frame
	camera_rig._process(0.2)

	_validate_hitscan_and_cadence(weapon, camera_rig, static_target)
	_validate_dry_fire(weapon)
	_validate_reload_transactions(weapon, camera_rig, ammo_source)
	await _validate_pause_and_restore(weapon, camera_rig, ammo_source)
	_validate_disabled_state(weapon, camera_rig)
	await _validate_near_wall(weapon, camera_rig, static_target, near_wall)
	await _validate_owner_exclusion(weapon, camera_rig, player, static_target, near_wall)
	await _validate_moving_receiver(weapon, camera_rig, static_target, moving_target)

	room.queue_free()
	await process_frame
	_finish()


func _validate_definition() -> void:
	if not PISTOL.is_valid_definition():
		failures.append("Pistol resource does not satisfy definition invariants.")
	if PISTOL.damage != 50.0 or PISTOL.magazine_capacity != 8:
		failures.append("Pistol resource does not match the vertical-slice 50 damage / 8-round target.")
	if PISTOL.gunshot_loudness != 30.0:
		failures.append("Pistol gunshot does not expose the 30 m hearing target.")


func _validate_hitscan_and_cadence(
		weapon: WeaponController,
		camera_rig: GameplayCameraRig,
		target: CombatTestReceiver3D
) -> void:
	var expected_direction := camera_rig.get_aim_direction()
	if not weapon.request_fire():
		failures.append("Ready aimed pistol rejected a valid shot.")
		return
	if target.health != 50.0:
		failures.append("A compliant receiver did not accept the pistol's 50 damage submission.")
	if _shot_contexts.is_empty() or _shot_contexts[-1].direction.distance_to(expected_direction) > 0.0001:
		failures.append("Shot direction did not match the camera-owned public aim ray.")
	if PISTOL.fire_feedback_id not in _feedback_ids or PISTOL.impact_feedback_id not in _feedback_ids:
		failures.append("Shot/impact feedback hooks were not emitted from weapon data IDs.")
	if _gunshot_noise_count != 1:
		failures.append("Valid pistol shot did not emit exactly one typed gunshot noise event.")
	var magazine_after_shot := weapon.magazine
	if weapon.request_fire() or weapon.magazine != magazine_after_shot:
		failures.append("Rapid fire duplicated a shot or ammunition transaction during cooldown.")
	weapon.advance_runtime(1.0)
	if weapon.state != WeaponController.WeaponState.READY or weapon.magazine != magazine_after_shot:
		failures.append("A low-frame-time cadence step changed ammunition or failed to settle once.")
	if not weapon.request_fire() or not target.is_dead:
		failures.append("Two pistol body hits did not defeat a 100-health compliant receiver.")
	if target.last_hit_context == null or target.last_hit_context.damage_tags != PISTOL.damage_tags:
		failures.append("Damage receiver did not receive the typed hit context and tags.")


func _validate_dry_fire(weapon: WeaponController) -> void:
	weapon.advance_runtime(1.0)
	weapon.restore_runtime({
		&"weapon_id": PISTOL.weapon_id,
		&"magazine": 0,
		&"equipped": true,
	})
	var shot_count := _shot_contexts.size()
	if weapon.request_fire():
		failures.append("Empty magazine reported a successful shot.")
	if _dry_fire_reasons.is_empty() or _dry_fire_reasons[-1] != &"MAGAZINE_EMPTY":
		failures.append("Empty magazine did not emit the typed dry-fire reason.")
	if PISTOL.dry_fire_feedback_id not in _feedback_ids:
		failures.append("Dry fire did not expose its data-defined feedback hook.")
	var dry_fire_count := _dry_fire_reasons.size()
	if weapon.request_fire() or _dry_fire_reasons.size() != dry_fire_count:
		failures.append("Empty-magazine spam bypassed the weapon cadence.")
	if _shot_contexts.size() != shot_count:
		failures.append("Dry fire emitted a shot context.")


func _validate_reload_transactions(
		weapon: WeaponController,
		camera_rig: GameplayCameraRig,
		ammo_source: CombatTestAmmoSource
) -> void:
	weapon.restore_runtime({
		&"weapon_id": PISTOL.weapon_id,
		&"magazine": 3,
		&"equipped": true,
	})
	ammo_source.pistol_rounds = 12
	if not weapon.request_reload():
		failures.append("Valid partial-magazine reload was rejected.")
	weapon.request_unequip()
	if ammo_source.pistol_rounds != 12 or weapon.magazine != 3:
		failures.append("Interrupted reload consumed reserve ammunition before completion.")
	if weapon.state != WeaponController.WeaponState.HOLSTERED:
		failures.append("Unequip did not cancel reload into HOLSTERED.")
	weapon.request_equip(PISTOL, 3)
	weapon.advance_runtime(1.0)
	if camera_rig.mode != GameplayCameraRig.CameraMode.EXPLORATION:
		failures.append("Equipment change did not cancel first-person aim.")
	if not weapon.request_reload():
		failures.append("Reload could not restart after an equipment interruption.")
	weapon.advance_runtime(PISTOL.reload_duration + 0.1)
	if weapon.magazine != 8 or ammo_source.pistol_rounds != 7:
		failures.append("Completed reload was not one atomic 5-round reserve transaction.")


func _validate_pause_and_restore(
		weapon: WeaponController,
		camera_rig: GameplayCameraRig,
		ammo_source: CombatTestAmmoSource
) -> void:
	weapon.restore_runtime({
		&"weapon_id": PISTOL.weapon_id,
		&"magazine": 4,
		&"equipped": true,
	})
	if not weapon.request_reload():
		failures.append("Pause test could not enter RELOADING.")
	var reserve_before_pause := ammo_source.pistol_rounds
	var game_state := get_root().get_node("GameState")
	game_state.call(&"set_paused", true)
	if weapon.state != WeaponController.WeaponState.READY:
		failures.append("Pause did not cancel the in-progress reload.")
	if ammo_source.pistol_rounds != reserve_before_pause:
		failures.append("Pause cancellation consumed reserve ammunition.")
	var magazine_before_fire := weapon.magazine
	if weapon.request_fire() or weapon.magazine != magazine_before_fire:
		failures.append("Paused combat accepted a shot.")
	game_state.call(&"set_paused", false)
	await process_frame
	var checkpoint := weapon.get_runtime_snapshot()
	weapon.restore_runtime({
		&"weapon_id": PISTOL.weapon_id,
		&"magazine": 1,
		&"equipped": false,
	})
	if not weapon.restore_runtime(checkpoint) or weapon.magazine != 4 or weapon.state != WeaponController.WeaponState.READY:
		failures.append("Weapon checkpoint snapshot did not restore magazine/equipment state cleanly.")
	if not camera_rig.request_aim(true):
		failures.append("Aim could not resume after pause and checkpoint restore.")
	await process_frame
	camera_rig._process(0.2)


func _validate_near_wall(
		weapon: WeaponController,
		camera_rig: GameplayCameraRig,
		target: CombatTestReceiver3D,
		wall: StaticBody3D
) -> void:
	target.reset_receiver()
	weapon.restore_runtime({
		&"weapon_id": PISTOL.weapon_id,
		&"magazine": 8,
		&"equipped": true,
	})
	if camera_rig.mode != GameplayCameraRig.CameraMode.AIM:
		camera_rig.request_aim(true)
		await process_frame
	camera_rig._process(0.2)
	wall.position = Vector3(0.0, 1.25, -0.35)
	await physics_frame
	if not weapon.request_fire():
		failures.append("Near-wall shot was not resolved into the blocking surface.")
	if target.health != target.maximum_health:
		failures.append("Near-wall firing damaged a target through solid cover.")
	if _impact_colliders.is_empty() or _impact_colliders[-1] != wall:
		failures.append("Near-wall firing did not resolve its impact against the blocking wall.")


func _validate_disabled_state(
		weapon: WeaponController,
		camera_rig: GameplayCameraRig
) -> void:
	var magazine_before_disable := weapon.magazine
	weapon.set_disabled(true)
	if weapon.state != WeaponController.WeaponState.DISABLED:
		failures.append("Weapon did not enter its explicit DISABLED state.")
	if weapon.request_fire() or weapon.request_unequip() or weapon.request_equip(PISTOL, magazine_before_disable):
		failures.append("Normal combat/equipment requests escaped the DISABLED state.")
	if camera_rig.mode != GameplayCameraRig.CameraMode.EXPLORATION:
		failures.append("Disabling the weapon did not release first-person aim.")
	weapon.set_disabled(false)
	if not weapon.request_equip(PISTOL, magazine_before_disable):
		failures.append("Weapon could not be explicitly re-equipped after re-enabling.")
	weapon.advance_runtime(1.0)


func _validate_owner_exclusion(
		weapon: WeaponController,
		camera_rig: GameplayCameraRig,
		player: PlayerController,
		target: CombatTestReceiver3D,
		wall: StaticBody3D
) -> void:
	weapon.advance_runtime(1.0)
	wall.position.x = 5.0
	player.collision_layer = 2 | 8
	target.reset_receiver()
	await physics_frame
	if camera_rig.mode != GameplayCameraRig.CameraMode.AIM:
		camera_rig.request_aim(true)
		await process_frame
	camera_rig._process(0.2)
	if not weapon.request_fire() or target.health != 50.0:
		failures.append("Owner exclusion prevented the intended downstream damageable hit.")
	if not _impact_colliders.is_empty() and _impact_colliders[-1] == player:
		failures.append("Hitscan selected the combat owner's collision identity.")
	player.collision_layer = 2


func _validate_moving_receiver(
		weapon: WeaponController,
		camera_rig: GameplayCameraRig,
		static_target: CombatTestReceiver3D,
		moving_target: CombatTestReceiver3D
) -> void:
	weapon.advance_runtime(1.0)
	static_target.position.x = 5.0
	moving_target.moves = false
	moving_target.position = Vector3(0.0, 0.9, -15.0)
	moving_target.reset_receiver()
	await physics_frame
	if camera_rig.mode != GameplayCameraRig.CameraMode.AIM:
		camera_rig.request_aim(true)
		await process_frame
	camera_rig._process(0.2)
	if not weapon.request_fire() or moving_target.health != 50.0:
		failures.append("The same damage contract did not resolve against the moving sandbox receiver.")


func _finish() -> void:
	get_root().get_node("GameState").call(&"set_paused", false)
	if failures.is_empty():
		print("COMBAT PASS: equip, aim, cadence, hitscan, damage, wall safety, ammo, pause, and restore are valid.")
		quit(0)
		return
	for failure in failures:
		push_error("COMBAT FAIL: %s" % failure)
	quit(1)

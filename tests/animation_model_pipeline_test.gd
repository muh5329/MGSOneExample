extends SceneTree

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const GUARD_SCENE := preload("res://scenes/actors/guard.tscn")
const PROOF_SWAP_MODEL := preload("res://scenes/visuals/proof_swap_guard_model.tscn")
const PISTOL := preload("res://data/weapons/w1_service_pistol.tres")

var failures: Array[String] = []
var _player_actions: Array[StringName] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	get_root().add_child(world)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	var guard := GUARD_SCENE.instantiate() as GuardActor
	world.add_child(player)
	world.add_child(guard)
	await process_frame
	await process_frame
	_validate_player_adapter(player)
	_validate_guard_swap(guard)
	_validate_visual_removal_isolation(guard)
	await _validate_pre_ready_visual_removal(world)
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("ANIMATION/MODEL PASS: semantics, procedural readability, sockets, graceful fallback, proof swap, and gameplay isolation are valid.")
		quit(0)
		return
	for failure in failures:
		push_error("ANIMATION/MODEL FAIL: %s" % failure)
	quit(1)


func _validate_player_adapter(player: PlayerController) -> void:
	var adapter := player.get_node("VisualRoot") as ActorVisualAdapter3D
	var weapon := player.get_node("WeaponController") as WeaponController
	if adapter == null or weapon == null:
		failures.append("Player does not keep the visual adapter and weapon runtime as separate root children.")
		return
	var report := adapter.validate_configuration()
	if not bool(report.valid):
		failures.append("Player primitive visual failed required model/socket validation: %s" % report.errors)
	if (report.warnings as PackedStringArray).is_empty():
		failures.append("Procedural primitive did not report its optional AnimationPlayer fallback explicitly.")
	for socket_id: StringName in [&"weapon", &"muzzle", &"head", &"eyes", &"effect_origin"]:
		if adapter.get_socket(socket_id) == null:
			failures.append("Player adapter is missing the stable '%s' socket." % socket_id)
	adapter.action_triggered.connect(func(action: StringName, _duration: float) -> void: _player_actions.append(action))
	player.request_crouch(true)
	player.set_aim_movement_locked(true)
	var crouched_snapshot := adapter.get_semantic_snapshot()
	if not bool(crouched_snapshot.aiming):
		failures.append("Player AIM lock did not publish the model-independent aiming semantic.")
	adapter.set_semantic_state({&"crouched": true, &"speed_ratio": 1.0})
	adapter._process(0.1)
	var body := adapter.get_node("ModelRoot/ModelPayload/Body") as Node3D
	var head := adapter.get_node("ModelRoot/ModelPayload/Head") as Node3D
	if body.scale.y >= 0.99 or head.position.y >= 1.5:
		failures.append("Procedural crouch does not read distinctly at the primitive silhouette level.")
	weapon.request_equip(PISTOL, 8)
	if not bool(adapter.get_semantic_snapshot().weapon_equipped):
		failures.append("Weapon equipment state did not drive the semantic visual contract.")
	if not adapter.trigger_action(&"fire", 0.14) or not adapter.trigger_action(&"reload", 0.5):
		failures.append("Adapter rejected supported fire/reload presentation actions.")
	player.receive_damage(10.0, null)
	if not _player_actions.has(&"damaged"):
		failures.append("Health damage did not reach the visual adapter through the existing health signal.")
	var malformed_path := adapter.body_path
	adapter.body_path = ^"ModelRoot/MissingRequiredBody"
	var malformed := adapter.validate_configuration()
	if bool(malformed.valid) or not String(";".join(malformed.errors)).contains("REQUIRED_VISUAL_MISSING"):
		failures.append("A missing required visual configuration did not produce an obvious stable error.")
	adapter.body_path = malformed_path
	adapter._cache_nodes()
	player.set_aim_movement_locked(false)
	player.remove_child(adapter)
	adapter.free()
	if player.get_node_or_null("WeaponController") != weapon:
		failures.append("Removing the player visual child removed or replaced the root-owned weapon runtime.")
	if not player.receive_damage(1.0, null) or not weapon.request_unequip():
		failures.append("Removing the player visual child broke authoritative health or weapon behavior.")


func _validate_guard_swap(guard: GuardActor) -> void:
	var adapter := guard.get_node("VisualRoot") as ActorVisualAdapter3D
	if adapter == null:
		failures.append("Guard visual root is not an ActorVisualAdapter3D.")
		return
	var collision_layer_before := guard.collision_layer
	var collision_mask_before := guard.collision_mask
	var collision_shape := guard.get_node("BodyCollision") as CollisionShape3D
	var collision_shape_id := collision_shape.shape.get_instance_id()
	var navigation_id := guard.get_node("NavigationAgent").get_instance_id()
	var perception_id := guard.get_node("Perception").get_instance_id()
	var health_id := guard.get_node("Health").get_instance_id()
	var socket_ids: Dictionary = {}
	for socket_id: StringName in [&"weapon", &"muzzle", &"head", &"eyes", &"effect_origin"]:
		socket_ids[socket_id] = adapter.get_socket(socket_id).get_instance_id()
	guard.receive_alert_broadcast(Vector3(3.0, 0.0, 0.0), &"OTHER")
	if StringName(adapter.get_semantic_snapshot().alert_state) != &"ALERT":
		failures.append("Guard ALERT_CHASE did not translate into the shared ALERT visual semantic.")
	adapter._process(0.1)
	var indicator := adapter.get_node("ModelRoot/ModelPayload/AlertIndicator") as GeometryInstance3D
	if not indicator.visible:
		failures.append("Guard alert state is not visible on the primitive shell.")
	if not adapter.replace_model(PROOF_SWAP_MODEL):
		failures.append("The convention-compatible proof model could not replace the guard payload.")
		return
	if guard.collision_layer != collision_layer_before or guard.collision_mask != collision_mask_before:
		failures.append("Model replacement changed guard physics layers or masks.")
	if collision_shape.shape.get_instance_id() != collision_shape_id:
		failures.append("Model replacement changed the authoritative guard collision shape.")
	if (
		guard.get_node("NavigationAgent").get_instance_id() != navigation_id
		or guard.get_node("Perception").get_instance_id() != perception_id
		or guard.get_node("Health").get_instance_id() != health_id
	):
		failures.append("Model replacement reconstructed a gameplay-owned guard component.")
	for socket_id: StringName in socket_ids:
		if adapter.get_socket(socket_id).get_instance_id() != int(socket_ids[socket_id]):
			failures.append("Proof swap replaced the stable '%s' attachment socket." % socket_id)
	var payload := adapter.get_node("ModelRoot/ModelPayload") as Node3D
	if String(payload.get_meta(&"source_asset_id", "")) != "INTERNAL_GUARD_PROOF_SWAP_V1":
		failures.append("Proof swap asset does not expose its provenance ID.")
	if not adapter.transform.basis.get_scale().is_equal_approx(Vector3.ONE):
		failures.append("External-model correction leaked into non-unit actor visual adapter scale.")


func _validate_visual_removal_isolation(guard: GuardActor) -> void:
	var adapter := guard.get_node("VisualRoot") as ActorVisualAdapter3D
	guard.remove_child(adapter)
	var accepted_alert := guard.receive_alert_broadcast(Vector3(2.0, 0.0, -2.0), &"OTHER")
	var accepted_damage := guard.receive_damage(10.0, null)
	if not accepted_alert or not accepted_damage:
		failures.append("Removing the guard visual child broke authoritative alert or health behavior.")
	if guard.get_node_or_null("NavigationAgent") == null or guard.get_node_or_null("Perception") == null:
		failures.append("Removing the guard visual child removed gameplay-owned navigation/perception.")
	adapter.free()


func _validate_pre_ready_visual_removal(world: Node3D) -> void:
	var stripped_player := PLAYER_SCENE.instantiate() as PlayerController
	var visual := stripped_player.get_node("VisualRoot")
	stripped_player.remove_child(visual)
	visual.free()
	world.add_child(stripped_player)
	await process_frame
	var weapon := stripped_player.get_node_or_null("WeaponController") as WeaponController
	if weapon == null or not stripped_player.request_crouch(true) or not stripped_player.receive_damage(1.0, null):
		failures.append("A player instantiated without its visual child could not initialize movement, health, and combat roots.")
	stripped_player.queue_free()
	await process_frame

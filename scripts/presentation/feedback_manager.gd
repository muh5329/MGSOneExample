class_name FeedbackManager
extends Node3D

signal feedback_played(event_id: StringName, snapshot: Dictionary)
signal feedback_suppressed(event_id: StringName, reason: StringName)
signal camera_impulse_requested(position: Vector3, rotation_degrees: Vector3, duration: float)
signal vibration_requested(weak: float, strong: float, duration: float)

const EVENT_MATRIX := {
	&"FOOTSTEP": {&"frequency": 92.0, &"duration": 0.055, &"bus": &"Effects", &"priority": 1, &"cooldown": 0.08, &"spatial": true},
	&"pistol_fire": {&"frequency": 145.0, &"duration": 0.11, &"bus": &"Effects", &"priority": 5, &"cooldown": 0.04, &"spatial": true, &"vfx": &"MUZZLE", &"flash": &"FIRE"},
	&"pistol_dry_fire": {&"frequency": 430.0, &"duration": 0.045, &"bus": &"Effects", &"priority": 3, &"cooldown": 0.12},
	&"pistol_reload": {&"frequency": 270.0, &"duration": 0.12, &"bus": &"Effects", &"priority": 2, &"cooldown": 0.2},
	&"bullet_impact": {&"frequency": 190.0, &"duration": 0.075, &"bus": &"Effects", &"priority": 3, &"cooldown": 0.03, &"spatial": true, &"vfx": &"IMPACT"},
	&"PICKUP": {&"frequency": 660.0, &"duration": 0.12, &"bus": &"UI", &"priority": 3, &"cooldown": 0.08, &"vfx": &"PICKUP"},
	&"ITEM_USED": {&"frequency": 520.0, &"duration": 0.18, &"bus": &"UI", &"priority": 4, &"cooldown": 0.2, &"flash": &"HEAL"},
	&"MENU_OPEN": {&"frequency": 330.0, &"duration": 0.06, &"bus": &"UI", &"priority": 2, &"cooldown": 0.04},
	&"MENU_MOVE": {&"frequency": 410.0, &"duration": 0.035, &"bus": &"UI", &"priority": 1, &"cooldown": 0.03},
	&"MENU_CLOSE": {&"frequency": 250.0, &"duration": 0.05, &"bus": &"UI", &"priority": 2, &"cooldown": 0.04},
	&"REJECTED": {&"frequency": 118.0, &"duration": 0.09, &"bus": &"UI", &"priority": 4, &"cooldown": 0.1},
	&"DETECTED": {&"frequency": 880.0, &"duration": 0.26, &"bus": &"UI", &"priority": 10, &"cooldown": 0.4, &"flash": &"DETECTED", &"vfx": &"DETECTED"},
	&"ALERT_PHASE_CHANGED": {&"frequency": 610.0, &"duration": 0.16, &"bus": &"UI", &"priority": 7, &"cooldown": 0.12},
	&"PLAYER_DAMAGED": {&"frequency": 105.0, &"duration": 0.14, &"bus": &"Effects", &"priority": 8, &"cooldown": 0.08, &"flash": &"DAMAGE"},
	&"PLAYER_DEATH": {&"frequency": 72.0, &"duration": 0.55, &"bus": &"Effects", &"priority": 10, &"cooldown": 1.0, &"flash": &"DEATH"},
	&"DOOR": {&"frequency": 205.0, &"duration": 0.16, &"bus": &"Effects", &"priority": 3, &"cooldown": 0.1, &"spatial": true},
	&"CHECKPOINT": {&"frequency": 740.0, &"duration": 0.22, &"bus": &"UI", &"priority": 6, &"cooldown": 0.3, &"vfx": &"OBJECTIVE"},
	&"OBJECTIVE": {&"frequency": 790.0, &"duration": 0.35, &"bus": &"UI", &"priority": 9, &"cooldown": 0.5, &"vfx": &"OBJECTIVE", &"flash": &"OBJECTIVE"},
	&"MISSION_COMPLETE": {&"frequency": 980.0, &"duration": 0.55, &"bus": &"Music", &"priority": 10, &"cooldown": 1.0, &"flash": &"OBJECTIVE"},
	&"ATTACK_TELEGRAPH": {&"frequency": 560.0, &"duration": 0.09, &"bus": &"Effects", &"priority": 6, &"cooldown": 0.12, &"spatial": true},
}

@export_range(2, 32, 1) var maximum_audio_voices: int = 12
@export_range(2, 64, 1) var maximum_effects: int = 24
@export_range(0.0, 2.0, 0.05) var maximum_impulse_rotation_degrees: float = 1.5
@export_range(0.0, 1.0, 0.05) var maximum_vibration_strength: float = 0.65
@export_range(0.0, 0.5, 0.01) var maximum_vibration_duration: float = 0.22

var _camera_rig: GameplayCameraRig
var _screen_effects: ScreenEffects
var _voices: Array[AudioStreamPlayer] = []
var _spatial_voices: Array[AudioStreamPlayer3D] = []
var _active_effects: Array[Dictionary] = []
var _cooldowns: Dictionary = {}
var _stream_cache: Dictionary = {}
var _played_count: int = 0
var _suppressed_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"checkpoint_reset_targets")
	for index in maximum_audio_voices:
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%02d" % index
		add_child(voice)
		_voices.append(voice)
		var spatial_voice := AudioStreamPlayer3D.new()
		spatial_voice.name = "SpatialVoice%02d" % index
		spatial_voice.max_distance = 34.0
		spatial_voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		spatial_voice.unit_size = 6.0
		add_child(spatial_voice)
		_spatial_voices.append(spatial_voice)
	var canvas := CanvasLayer.new()
	canvas.layer = 80
	canvas.name = "ScreenEffectsLayer"
	add_child(canvas)
	_screen_effects = ScreenEffects.new()
	_screen_effects.name = "ScreenEffects"
	canvas.add_child(_screen_effects)
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.pause_changed.connect(_on_pause_changed)


func _process(delta: float) -> void:
	for key in _cooldowns.keys():
		_cooldowns[key] = maxf(float(_cooldowns[key]) - delta, 0.0)
		if float(_cooldowns[key]) <= 0.0:
			_cooldowns.erase(key)
	for effect in _active_effects.duplicate():
		effect.remaining = maxf(float(effect.remaining) - delta, 0.0)
		var node := effect.node as Node3D
		if node != null and is_instance_valid(node):
			var ratio: float = float(effect.remaining) / maxf(float(effect.duration), 0.001)
			node.scale = Vector3.ONE * maxf(ratio, 0.05)
		if float(effect.remaining) <= 0.0:
			_remove_effect(effect)


func configure(camera_rig: GameplayCameraRig) -> void:
	_camera_rig = camera_rig
	var settings := get_node_or_null("/root/SettingsService")
	if settings != null:
		settings.call(&"apply_camera_settings", camera_rig)


func bind_runtime(
		player: PlayerController,
		weapon: WeaponController,
		inventory: InventoryComponent,
		panels: InventoryPanels,
		alert: AlertCoordinator,
		mission: MissionStateCoordinator,
		guards: Array,
		doors: Array,
		pickups: Array = []
) -> void:
	if player != null:
		_connect_once(player.movement_noise_emitted, _on_movement_noise)
		_connect_once(player.health.damaged, _on_player_damaged)
		_connect_once(player.health.healed, _on_player_healed)
		_connect_once(player.health.died, _on_player_died)
	if weapon != null:
		_connect_once(weapon.feedback_requested, request_feedback)
	if inventory != null:
		_connect_once(inventory.item_used, _on_item_used)
	if panels != null:
		_connect_once(panels.panel_opened, _on_panel_opened)
		_connect_once(panels.panel_closed, _on_panel_closed)
		_connect_once(panels.selection_changed, _on_panel_selection)
		_connect_once(panels.request_rejected, _on_request_rejected)
	if alert != null:
		_connect_once(alert.feedback_requested, request_feedback)
	if mission != null:
		_connect_once(mission.checkpoint_activated, _on_checkpoint)
		_connect_once(mission.objective_completed, _on_objective)
		_connect_once(mission.mission_completed, _on_mission_complete)
		_connect_once(mission.checkpoint_restore_started, _on_restore_started)
	for guard_value in guards:
		var guard := guard_value as GuardActor
		if guard != null:
			_connect_once(guard.attack_telegraphed, _on_attack_telegraphed)
	for door_value in doors:
		var door := door_value as Door3D
		if door != null:
			_connect_once(door.state_changed, _on_door_state)
	for pickup_value in pickups:
		var pickup := pickup_value as InventoryPickup3D
		if pickup != null:
			_connect_once(pickup.pickup_transaction, _on_pickup_transaction)


func request_feedback(event_id: StringName, payload: Dictionary = {}) -> bool:
	if not EVENT_MATRIX.has(event_id):
		feedback_suppressed.emit(event_id, &"UNMAPPED")
		_suppressed_count += 1
		return false
	if float(_cooldowns.get(event_id, 0.0)) > 0.0:
		feedback_suppressed.emit(event_id, &"COOLDOWN")
		_suppressed_count += 1
		return false
	var definition: Dictionary = EVENT_MATRIX[event_id]
	var spatial := bool(definition.get(&"spatial", false))
	var voice: Node = _available_voice(spatial, int(definition.get(&"priority", 1)))
	if voice == null:
		feedback_suppressed.emit(event_id, &"VOICE_LIMIT")
		_suppressed_count += 1
		return false
	_cooldowns[event_id] = float(definition.get(&"cooldown", 0.0))
	voice.bus = StringName(definition.get(&"bus", &"Effects"))
	voice.stream = _tone_stream(event_id, float(definition.frequency), float(definition.duration))
	voice.volume_db = clampf(float(payload.get(&"volume_db", -4.0)), -30.0, 0.0)
	voice.pitch_scale = clampf(float(payload.get(&"pitch_scale", 1.0)), 0.65, 1.4)
	if voice is AudioStreamPlayer3D:
		(voice as AudioStreamPlayer3D).global_position = payload.get(&"position", payload.get(&"origin", global_position))
	voice.set_meta(&"feedback_priority", int(definition.get(&"priority", 1)))
	voice.play()
	var position: Vector3 = payload.get(&"position", payload.get(&"origin", global_position))
	if definition.has(&"vfx"):
		_spawn_vfx(StringName(definition.vfx), position, payload)
	_apply_screen_cue(StringName(definition.get(&"flash", &"")))
	_apply_impulse(event_id, definition, payload)
	_played_count += 1
	var snapshot := {&"event_id": event_id, &"position": position, &"priority": int(definition.priority), &"active_effects": _active_effects.size()}
	feedback_played.emit(event_id, snapshot.duplicate(true))
	return true


func get_feedback_snapshot() -> Dictionary:
	var active_voices := 0
	for voice in _voices:
		if voice.playing:
			active_voices += 1
	for voice in _spatial_voices:
		if voice.playing:
			active_voices += 1
	return {
		&"voice_capacity": maximum_audio_voices,
		&"active_voices": active_voices,
		&"effect_capacity": maximum_effects,
		&"active_effects": _active_effects.size(),
		&"played": _played_count,
		&"suppressed": _suppressed_count,
	}


func reset_transient_state(_checkpoint_id: StringName) -> void:
	for voice in _voices:
		voice.stop()
	for voice in _spatial_voices:
		voice.stop()
	for effect in _active_effects.duplicate():
		_remove_effect(effect)
	_cooldowns.clear()
	if _screen_effects != null:
		_screen_effects.clear_effects()


func _available_voice(spatial: bool, priority: int) -> Node:
	var active: Array[Node] = []
	for voice in _voices:
		if voice.playing:
			active.append(voice)
	for voice in _spatial_voices:
		if voice.playing:
			active.append(voice)
	var desired: Array = _spatial_voices if spatial else _voices
	if active.size() < maximum_audio_voices:
		for voice_value in desired:
			var voice := voice_value as Node
			if not bool(voice.get("playing")):
				return voice
	var lowest: Node
	var lowest_priority := priority
	for voice in active:
		var voice_priority := int(voice.get_meta(&"feedback_priority", 0))
		if voice_priority < lowest_priority:
			lowest = voice
			lowest_priority = voice_priority
	if lowest != null:
		lowest.call(&"stop")
		for voice_value in desired:
			var voice := voice_value as Node
			if not bool(voice.get("playing")):
				return voice
	return null


func _tone_stream(event_id: StringName, frequency: float, duration: float) -> AudioStreamWAV:
	if _stream_cache.has(event_id):
		return _stream_cache[event_id] as AudioStreamWAV
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var sample_count := maxi(roundi(duration * stream.mix_rate), 1)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in sample_count:
		var time := float(index) / float(stream.mix_rate)
		var envelope := pow(1.0 - float(index) / float(sample_count), 2.0)
		var wave := sin(TAU * frequency * time) * 0.55 + sin(TAU * frequency * 1.97 * time) * 0.18
		var sample := clampi(roundi(wave * envelope * 32767.0), -32768, 32767)
		bytes[index * 2] = sample & 0xff
		bytes[index * 2 + 1] = (sample >> 8) & 0xff
	stream.data = bytes
	_stream_cache[event_id] = stream
	return stream


func _spawn_vfx(kind: StringName, position: Vector3, payload: Dictionary) -> void:
	while _active_effects.size() >= maximum_effects:
		_remove_effect(_active_effects.front())
	var visual := MeshInstance3D.new()
	visual.name = "Feedback_%s" % kind
	visual.position = position
	visual.add_to_group(&"checkpoint_disposable")
	var mesh := SphereMesh.new()
	mesh.radius = 0.08 if kind in [&"MUZZLE", &"IMPACT"] else 0.18
	mesh.height = mesh.radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = _vfx_color(kind)
	material.emission_enabled = true
	material.emission = _vfx_color(kind)
	visual.material_override = material
	add_child(visual)
	var duration := clampf(float(payload.get(&"vfx_duration", 0.24)), 0.05, 1.0)
	_active_effects.append({&"node": visual, &"duration": duration, &"remaining": duration})


func _remove_effect(effect: Dictionary) -> void:
	_active_effects.erase(effect)
	var node := effect.get(&"node") as Node
	if node != null and is_instance_valid(node):
		node.queue_free()


func _vfx_color(kind: StringName) -> Color:
	match kind:
		&"MUZZLE": return Color(1.0, 0.72, 0.18, 0.85)
		&"IMPACT": return Color(0.85, 0.9, 0.82, 0.75)
		&"PICKUP": return Color(0.1, 1.0, 0.55, 0.75)
		&"DETECTED": return Color(1.0, 0.12, 0.06, 0.75)
	return Color(0.25, 0.9, 0.72, 0.75)


func _apply_screen_cue(cue: StringName) -> void:
	if _screen_effects == null or cue.is_empty():
		return
	match cue:
		&"FIRE": _screen_effects.request_flash(Color(1.0, 0.68, 0.2, 0.08), 0.06)
		&"HEAL": _screen_effects.request_flash(Color(0.15, 1.0, 0.42, 0.18), 0.22)
		&"DAMAGE": _screen_effects.request_flash(Color(1.0, 0.04, 0.02, 0.28), 0.22)
		&"DEATH": _screen_effects.request_flash(Color(0.45, 0.0, 0.0, 0.42), 0.5)
		&"OBJECTIVE": _screen_effects.request_flash(Color(0.1, 1.0, 0.65, 0.15), 0.28)
		&"DETECTED":
			_screen_effects.request_detection_pulse()
			_screen_effects.request_flash(Color(1.0, 0.08, 0.02, 0.22), 0.15)


func _apply_impulse(event_id: StringName, _definition: Dictionary, payload: Dictionary) -> void:
	var settings := get_node_or_null("/root/SettingsService")
	var shake_scale := float(settings.call(&"get_setting", &"camera_shake_scale", 1.0)) if settings != null else 1.0
	var vibration_scale := float(settings.call(&"get_setting", &"vibration_scale", 1.0)) if settings != null else 1.0
	var position_offset: Vector3 = payload.get(&"camera_impulse_position", Vector3.ZERO)
	var rotation: Vector3 = payload.get(&"camera_impulse_rotation_degrees", Vector3.ZERO)
	var duration := clampf(float(payload.get(&"camera_impulse_duration", 0.12)), 0.0, 0.3)
	if event_id == &"PLAYER_DAMAGED":
		rotation = Vector3(-0.7, 0.35, 0.0)
		duration = 0.14
	rotation.x = clampf(rotation.x, -maximum_impulse_rotation_degrees, maximum_impulse_rotation_degrees)
	rotation.y = clampf(rotation.y, -maximum_impulse_rotation_degrees, maximum_impulse_rotation_degrees)
	rotation.z = clampf(rotation.z, -maximum_impulse_rotation_degrees, maximum_impulse_rotation_degrees)
	if _camera_rig != null and shake_scale > 0.0 and (not position_offset.is_zero_approx() or not rotation.is_zero_approx()):
		_camera_rig.add_camera_impulse(position_offset * shake_scale, rotation * shake_scale, duration)
		camera_impulse_requested.emit(position_offset * shake_scale, rotation * shake_scale, duration)
	var strong := 0.0
	if event_id == &"pistol_fire": strong = 0.32
	elif event_id == &"PLAYER_DAMAGED": strong = 0.55
	elif event_id == &"DETECTED": strong = 0.42
	if strong > 0.0 and vibration_scale > 0.0:
		strong = minf(strong * vibration_scale, maximum_vibration_strength)
		duration = minf(maxf(duration, 0.08), maximum_vibration_duration)
		Input.start_joy_vibration(0, strong * 0.45, strong, duration)
		vibration_requested.emit(strong * 0.45, strong, duration)


func _connect_once(signal_value: Signal, callable: Callable) -> void:
	if not signal_value.is_connected(callable):
		signal_value.connect(callable)


func _on_movement_noise(event: NoiseEvent3D) -> void:
	request_feedback(&"FOOTSTEP", {&"position": event.world_position, &"pitch_scale": 1.12 if event.loudness < 0.45 else 0.94, &"volume_db": lerpf(-15.0, -5.0, event.loudness)})


func _on_player_damaged(_amount: float, _context: HitContext3D) -> void:
	request_feedback(&"PLAYER_DAMAGED")


func _on_player_healed(_amount: float, _source: Object) -> void:
	request_feedback(&"ITEM_USED")


func _on_player_died(_context: HitContext3D) -> void:
	request_feedback(&"PLAYER_DEATH")


func _on_pickup_transaction(result: Dictionary) -> void:
	if bool(result.get(&"accepted", false)):
		request_feedback(&"PICKUP")


func _on_item_used(_entry_id: StringName, _effect_id: StringName, _amount: float) -> void:
	request_feedback(&"ITEM_USED")


func _on_panel_opened(_panel: int) -> void: request_feedback(&"MENU_OPEN")
func _on_panel_closed(_panel: int, _confirmed: bool) -> void: request_feedback(&"MENU_CLOSE")
func _on_panel_selection(_panel: int, _entry_id: StringName) -> void: request_feedback(&"MENU_MOVE")
func _on_request_rejected(_reason: StringName) -> void: request_feedback(&"REJECTED")
func _on_checkpoint(_checkpoint_id: StringName, _snapshot: Dictionary) -> void: request_feedback(&"CHECKPOINT")
func _on_objective(_objective_id: StringName) -> void: request_feedback(&"OBJECTIVE")
func _on_mission_complete(_extraction_id: StringName) -> void: request_feedback(&"MISSION_COMPLETE")


func _on_restore_started(_checkpoint_id: StringName) -> void:
	reset_transient_state(&"")


func _on_attack_telegraphed(_guard_id: StringName, target_position: Vector3, _duration: float) -> void:
	request_feedback(&"ATTACK_TELEGRAPH", {&"position": target_position})


func _on_door_state(_door_id: StringName, _opened: bool, _locked: bool) -> void:
	request_feedback(&"DOOR")


func _on_pause_changed(paused: bool) -> void:
	for voice in _voices:
		voice.stream_paused = paused
	for voice in _spatial_voices:
		voice.stream_paused = paused

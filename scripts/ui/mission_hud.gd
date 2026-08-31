class_name MissionHUD
extends CanvasLayer

signal display_snapshot_updated(snapshot: Dictionary)

const ALERT_TEXT := {
	&"NORMAL": "PATROL STATUS: NORMAL",
	&"SUSPICIOUS": "(?) SUSPICION — MOVE OUT OF VIEW",
	&"ALERT": "(!) ALERT — BREAK LINE OF SIGHT",
	&"EVASION": "[EVADE] CONTACT LOST — STAY HIDDEN",
	&"SEARCH": "[SEARCH] GUARDS CHECKING LAST POSITION",
}

@onready var root: Control = %HUDRoot
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_value: Label = %HealthValue
@onready var weapon_label: Label = %WeaponLabel
@onready var item_label: Label = %ItemLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var alert_label: Label = %AlertLabel
@onready var suspicion_bar: ProgressBar = %SuspicionBar
@onready var prompt_panel: PanelContainer = %PromptPanel
@onready var prompt_label: Label = %PromptLabel
@onready var hold_bar: ProgressBar = %HoldBar
@onready var banner_label: Label = %BannerLabel
@onready var outcome_panel: ColorRect = %OutcomePanel
@onready var outcome_title: Label = %OutcomeTitle
@onready var outcome_detail: Label = %OutcomeDetail
@onready var reticle: Control = %Reticle

var _player: PlayerController
var _inventory: InventoryComponent
var _weapon: WeaponController
var _alert: AlertCoordinator
var _focus: InteractionFocus3D
var _mission: MissionStateCoordinator
var _banner_remaining: float = 0.0
var _hold_progress: float = 0.0
var _display_snapshot: Dictionary = {}
var _font_baselines: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	prompt_panel.visible = false
	hold_bar.visible = false
	banner_label.visible = false
	outcome_panel.visible = false
	reticle.visible = false
	_cache_font_baselines(root)
	var settings := get_node_or_null("/root/SettingsService")
	if settings != null:
		settings.setting_changed.connect(_on_setting_changed)
		_apply_settings()
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.phase_changed.connect(_on_game_phase_changed)


func _process(delta: float) -> void:
	if _banner_remaining > 0.0:
		_banner_remaining = maxf(_banner_remaining - delta, 0.0)
		banner_label.visible = _banner_remaining > 0.0
	_update_from_sources()
	display_snapshot_updated.emit(_display_snapshot.duplicate(true))


func configure(
		player: PlayerController,
		inventory: InventoryComponent,
		weapon: WeaponController,
		alert: AlertCoordinator,
		focus: InteractionFocus3D,
		mission: MissionStateCoordinator,
		camera_rig: GameplayCameraRig
) -> void:
	_player = player
	_inventory = inventory
	_weapon = weapon
	_alert = alert
	_focus = focus
	_mission = mission
	if _focus != null:
		_focus.hold_progressed.connect(_on_hold_progressed)
	if _mission != null:
		_mission.status_changed.connect(show_banner)
		_mission.objective_completed.connect(_on_objective_completed)
		_mission.mission_completed.connect(_on_mission_completed)
		_mission.checkpoint_activated.connect(_on_checkpoint_activated)
	if _alert != null:
		_alert.detection_announced.connect(_on_detection_announced)
	if camera_rig != null:
		camera_rig.reticle_visibility_requested.connect(_on_reticle_visibility_requested)
	_update_from_sources()


func show_banner(message: String, duration: float = 3.0) -> void:
	banner_label.text = message
	banner_label.visible = true
	_banner_remaining = maxf(duration, 0.2)


func get_display_snapshot() -> Dictionary:
	return _display_snapshot.duplicate(true)


func _update_from_sources() -> void:
	if _player == null or _inventory == null or _alert == null or _focus == null or _mission == null:
		return
	var health := _player.health
	health_bar.max_value = health.maximum_health
	health_bar.value = health.current_health
	health_value.text = "%d / %d" % [roundi(health.current_health), roundi(health.maximum_health)]
	var inventory_snapshot := _inventory.get_display_snapshot()
	var weapon_text := "WEAPON  —  NONE"
	var item_text := "ITEM  —  NONE"
	for entry in inventory_snapshot.entries:
		if bool(entry.equipped) and int(entry.kind) == InventoryEntryDefinition.EntryKind.WEAPON:
			weapon_text = "WEAPON  %s  //  %d | %d" % [entry.display_name, entry.magazine, entry.reserve]
		if bool(entry.equipped) and int(entry.kind) == InventoryEntryDefinition.EntryKind.CONSUMABLE:
			item_text = "ITEM  %s  ×%d" % [entry.display_name, entry.quantity]
	weapon_label.text = weapon_text
	item_label.text = item_text
	objective_label.text = (
		"OBJECTIVE  RETURN TO DRAINAGE GATE"
		if _mission.objective_complete
		else "OBJECTIVE  COPY THE RELAY MANIFEST"
	)
	var alert_snapshot := _alert.get_alert_snapshot()
	var phase := StringName(alert_snapshot.get(&"phase", &"NORMAL"))
	alert_label.text = String(ALERT_TEXT.get(phase, String(phase)))
	alert_label.modulate = _phase_color(phase)
	suspicion_bar.value = clampf(float(alert_snapshot.get(&"maximum_suspicion", 0.0)) * 100.0, 0.0, 100.0)
	suspicion_bar.visible = phase != &"NORMAL"
	var prompt := _focus.get_prompt_snapshot()
	prompt_panel.visible = prompt.target != null
	if prompt.target != null:
		var settings := get_node_or_null("/root/SettingsService")
		var glyph: String = String(settings.call(&"glyph_for", &"interact")) if settings != null else "F"
		prompt_label.text = "[%s]  %s%s" % [
			glyph,
			String(prompt.prompt),
			"  —  %s" % String(prompt.reason) if not bool(prompt.available) else "",
		]
		hold_bar.visible = _hold_progress > 0.0
		hold_bar.value = _hold_progress * 100.0
	_display_snapshot = {
		&"health": health.current_health,
		&"maximum_health": health.maximum_health,
		&"weapon": weapon_text,
		&"item": item_text,
		&"objective_complete": _mission.objective_complete,
		&"alert_phase": phase,
		&"suspicion": suspicion_bar.value / 100.0,
		&"prompt_visible": prompt.target != null,
		&"prompt_available": bool(prompt.available) if prompt.target != null else false,
		&"hold_progress": _hold_progress,
	}


func _phase_color(phase: StringName) -> Color:
	match phase:
		&"SUSPICIOUS": return Color(1.0, 0.85, 0.3)
		&"ALERT": return Color(1.0, 0.24, 0.18)
		&"EVASION": return Color(1.0, 0.58, 0.18)
		&"SEARCH": return Color(1.0, 0.76, 0.28)
	return Color(0.38, 1.0, 0.68)


func _on_hold_progressed(_target: Interactable3D, progress: float) -> void:
	_hold_progress = clampf(progress, 0.0, 1.0)


func _on_game_phase_changed(_previous: int, current: int) -> void:
	match current:
		GameState.MissionPhase.PLAYER_DEAD:
			outcome_panel.visible = true
			outcome_title.text = "MISSION INTERRUPTED"
			outcome_detail.text = "Restoring the latest checkpoint…"
		GameState.MissionPhase.COMPLETED:
			outcome_panel.visible = true
			outcome_title.text = "MISSION COMPLETE"
			outcome_detail.text = "Relay manifest secured. Extraction confirmed."
		GameState.MissionPhase.RESTARTING:
			outcome_panel.visible = true
			outcome_title.text = "RESTORING CHECKPOINT"
			outcome_detail.text = "Clearing transient alert and combat state…"
		_:
			outcome_panel.visible = false


func _on_objective_completed(_objective_id: StringName) -> void:
	show_banner("OBJECTIVE COMPLETE  //  D2 SHORTCUT OPEN", 4.0)


func _on_mission_completed(_extraction_id: StringName) -> void:
	show_banner("EXTRACTION CONFIRMED", 5.0)


func _on_checkpoint_activated(checkpoint_id: StringName, _snapshot: Dictionary) -> void:
	show_banner("CHECKPOINT ACTIVE  //  %s" % checkpoint_id, 2.4)


func _on_detection_announced(report: Dictionary) -> void:
	show_banner("(!) DETECTED BY %s  //  BREAK CONTACT" % report.get(&"observer_id", &"UNKNOWN"), 3.0)


func _on_reticle_visibility_requested(visible: bool) -> void:
	reticle.visible = visible


func _on_setting_changed(key: StringName, _value: Variant) -> void:
	if key in [&"text_scale", &"high_contrast"]:
		_apply_settings()


func _apply_settings() -> void:
	var settings := get_node_or_null("/root/SettingsService")
	if settings == null:
		return
	var text_scale := float(settings.call(&"get_setting", &"text_scale", 1.0))
	for baseline in _font_baselines:
		var control := baseline.node as Control
		if control != null and is_instance_valid(control):
			control.add_theme_font_size_override(&"font_size", maxi(roundi(float(baseline.size) * text_scale), 8))
	var contrast := bool(settings.call(&"get_setting", &"high_contrast", false))
	root.modulate = Color(1.0, 1.0, 1.0, 1.0) if contrast else Color(0.9, 1.0, 0.96, 1.0)


func _cache_font_baselines(node: Node) -> void:
	if node is Label or node is Button:
		var control := node as Control
		_font_baselines.append({&"node": control, &"size": control.get_theme_font_size(&"font_size")})
	for child in node.get_children():
		_cache_font_baselines(child)

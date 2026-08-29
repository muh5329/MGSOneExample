class_name InventoryPanels
extends CanvasLayer

signal panel_opened(panel: PanelKind)
signal panel_closed(panel: PanelKind, confirmed: bool)
signal selection_changed(panel: PanelKind, entry_id: StringName)
signal request_rejected(reason: StringName)

enum PanelKind {
	NONE,
	WEAPON,
	ITEM,
}

@export_range(0.05, 1.0, 0.01, "suffix:s") var repeat_delay: float = 0.32
@export_range(0.03, 0.5, 0.01, "suffix:s") var repeat_interval: float = 0.12

@onready var weapon_panel: PanelContainer = %WeaponPanel
@onready var item_panel: PanelContainer = %ItemPanel
@onready var weapon_list: Label = %WeaponList
@onready var item_list: Label = %ItemList
@onready var help_label: Label = %InventoryHelp

var active_panel: PanelKind = PanelKind.NONE
var selected_index: int = 0

var _inventory: InventoryComponent
var _player: PlayerController
var _camera_rig: GameplayCameraRig
var _weapon: WeaponController
var _interaction_focus: InteractionFocus3D
var _item_recipient: Object
var _selection: Array[Dictionary] = []
var _repeat_direction: int = 0
var _repeat_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	weapon_panel.visible = false
	item_panel.visible = false
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.pause_changed.connect(_on_pause_changed)
		game_state.phase_changed.connect(_on_phase_changed)


func _process(delta: float) -> void:
	if active_panel == PanelKind.NONE or get_tree().paused:
		return
	var direction := roundi(Input.get_axis(&"ui_up", &"ui_down"))
	update_navigation_repeat(direction, delta)


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event.is_action_pressed(&"weapon_menu"):
		open_panel(PanelKind.WEAPON)
		get_viewport().set_input_as_handled()
	elif event.is_action_released(&"weapon_menu") and active_panel == PanelKind.WEAPON:
		close_panel(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"item_menu"):
		open_panel(PanelKind.ITEM)
		get_viewport().set_input_as_handled()
	elif event.is_action_released(&"item_menu") and active_panel == PanelKind.ITEM:
		close_panel(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"quick_use") and active_panel == PanelKind.NONE:
		quick_use()
		get_viewport().set_input_as_handled()
	elif active_panel != PanelKind.NONE and event.is_action_pressed(&"ui_cancel"):
		close_panel(false)
		get_viewport().set_input_as_handled()


func configure(
	inventory: InventoryComponent,
	player: PlayerController,
	camera_rig: GameplayCameraRig,
	weapon: WeaponController,
	interaction_focus: InteractionFocus3D = null,
	item_recipient: Object = null
) -> void:
	_inventory = inventory
	_player = player
	_camera_rig = camera_rig
	_weapon = weapon
	_interaction_focus = interaction_focus
	_item_recipient = item_recipient
	if _inventory != null and not _inventory.inventory_changed.is_connected(_on_inventory_changed):
		_inventory.inventory_changed.connect(_on_inventory_changed)
	_render_panels()


func set_item_recipient(recipient: Object) -> void:
	_item_recipient = recipient


func open_panel(panel: PanelKind) -> bool:
	if panel == PanelKind.NONE or _inventory == null or not _inventory.control_enabled or get_tree().paused:
		request_rejected.emit(&"CONTROL_LOCKED")
		return false
	if active_panel != PanelKind.NONE:
		close_panel(false)
	active_panel = panel
	selected_index = 0
	_repeat_direction = 0
	_repeat_time = 0.0
	_selection = _inventory.get_selection_snapshot(
		InventoryEntryDefinition.PanelKind.WEAPON if panel == PanelKind.WEAPON else InventoryEntryDefinition.PanelKind.ITEM
	)
	if _camera_rig != null:
		_camera_rig.request_aim(false)
		_camera_rig.set_modal_active(true)
	if _player != null:
		_player.set_control_lock(PlayerController.ControlLock.MENU, true)
	if _weapon != null:
		_weapon.set_control_enabled(false)
	if _interaction_focus != null:
		_interaction_focus.input_enabled = false
	weapon_panel.visible = panel == PanelKind.WEAPON
	item_panel.visible = panel == PanelKind.ITEM
	_render_panels()
	_emit_selection()
	panel_opened.emit(panel)
	return true


func close_panel(confirm_selection: bool = true) -> Dictionary:
	if active_panel == PanelKind.NONE:
		return _empty_result()
	var closing_panel := active_panel
	var result := _empty_result()
	if confirm_selection and not _selection.is_empty():
		var entry_id := StringName(_selection[selected_index].entry_id)
		result = (
			_inventory.request_equip_weapon(entry_id)
			if closing_panel == PanelKind.WEAPON
			else _inventory.request_equip_item(entry_id)
		)
		if not bool(result.accepted):
			request_rejected.emit(StringName(result.reason))
	active_panel = PanelKind.NONE
	_selection.clear()
	_repeat_direction = 0
	weapon_panel.visible = false
	item_panel.visible = false
	if _camera_rig != null:
		_camera_rig.set_modal_active(false)
	if _player != null:
		_player.set_control_lock(PlayerController.ControlLock.MENU, false)
	if _weapon != null:
		_weapon.set_control_enabled(true)
	if _interaction_focus != null:
		_interaction_focus.input_enabled = true
	panel_closed.emit(closing_panel, confirm_selection)
	return result


func quick_use() -> Dictionary:
	if _inventory == null or active_panel != PanelKind.NONE or get_tree().paused:
		var blocked := _empty_result(&"CONTROL_LOCKED")
		request_rejected.emit(&"CONTROL_LOCKED")
		return blocked
	var result := _inventory.request_quick_use(_item_recipient)
	if not bool(result.accepted):
		request_rejected.emit(StringName(result.reason))
	return result


func move_selection(direction: int) -> void:
	if active_panel == PanelKind.NONE or _selection.is_empty() or direction == 0:
		return
	selected_index = posmod(selected_index + signi(direction), _selection.size())
	_render_panels()
	_emit_selection()


func update_navigation_repeat(direction: int, delta: float) -> void:
	direction = signi(direction)
	if direction == 0:
		_repeat_direction = 0
		_repeat_time = 0.0
		return
	if direction != _repeat_direction:
		_repeat_direction = direction
		_repeat_time = repeat_delay
		move_selection(direction)
		return
	_repeat_time -= maxf(delta, 0.0)
	while _repeat_time <= 0.0:
		move_selection(direction)
		_repeat_time += repeat_interval


func get_selected_entry_id() -> StringName:
	if _selection.is_empty():
		return &""
	return StringName(_selection[selected_index].entry_id)


func _render_panels() -> void:
	if _inventory == null:
		return
	var weapon_entries := _inventory.get_selection_snapshot(InventoryEntryDefinition.PanelKind.WEAPON)
	var item_entries := _inventory.get_selection_snapshot(InventoryEntryDefinition.PanelKind.ITEM)
	weapon_list.text = _format_entries(weapon_entries, active_panel == PanelKind.WEAPON)
	item_list.text = _format_entries(item_entries, active_panel == PanelKind.ITEM)
	help_label.visible = active_panel != PanelKind.NONE


func _format_entries(entries: Array[Dictionary], show_cursor: bool) -> String:
	var lines: PackedStringArray = []
	for index in entries.size():
		var entry := entries[index]
		var cursor := "> " if show_cursor and index == selected_index else "  "
		var equipped := " [EQUIPPED]" if bool(entry.equipped) else ""
		var availability := "" if int(entry.quantity) > 0 else " [EMPTY]"
		if int(entry.kind) == InventoryEntryDefinition.EntryKind.WEAPON and int(entry.quantity) > 0:
			lines.append("%s%s  MAG %d  RES %d%s" % [cursor, entry.display_name, entry.magazine, entry.reserve, equipped])
		else:
			lines.append("%s%s  %d/%d%s%s" % [
				cursor, entry.display_name, entry.quantity, entry.maximum_quantity, equipped, availability,
			])
	return "\n".join(lines)


func _emit_selection() -> void:
	selection_changed.emit(active_panel, get_selected_entry_id())


func _on_inventory_changed(_snapshot: Dictionary) -> void:
	if active_panel != PanelKind.NONE:
		_selection = _inventory.get_selection_snapshot(
			InventoryEntryDefinition.PanelKind.WEAPON if active_panel == PanelKind.WEAPON else InventoryEntryDefinition.PanelKind.ITEM
		)
		selected_index = mini(selected_index, maxi(_selection.size() - 1, 0))
	_render_panels()


func _on_pause_changed(is_paused: bool) -> void:
	if is_paused and active_panel != PanelKind.NONE:
		close_panel(false)


func _on_phase_changed(_previous: int, current: int) -> void:
	if _inventory == null:
		return
	var locked := current in [
		GameState.MissionPhase.PLAYER_DEAD,
		GameState.MissionPhase.COMPLETED,
		GameState.MissionPhase.RESTARTING,
	]
	_inventory.set_control_enabled(not locked)
	if locked and active_panel != PanelKind.NONE:
		close_panel(false)


func _empty_result(reason: StringName = &"NO_ACTIVE_PANEL") -> Dictionary:
	return {
		&"code": InventoryComponent.TransactionCode.INVALID_REQUEST,
		&"accepted": false,
		&"entry_id": &"",
		&"requested": 0,
		&"changed": 0,
		&"current": 0,
		&"reason": reason,
	}

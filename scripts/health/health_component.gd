class_name HealthComponent
extends Node

signal health_changed(previous: float, current: float, maximum: float)
signal damaged(amount: float, context: HitContext3D)
signal healed(amount: float, source: Object)
signal died(context: HitContext3D)
signal revived(current: float, maximum: float)
signal invulnerability_changed(is_invulnerable: bool, remaining: float)

@export_range(1.0, 10000.0, 1.0) var maximum_health: float = 100.0
@export_range(0.0, 10000.0, 1.0) var starting_health: float = 100.0
@export_range(0.0, 10.0, 0.01, "suffix:s") var damage_invulnerability_duration: float = 0.0

var current_health: float = 100.0
var is_dead: bool = false
var damage_enabled: bool = true
var invulnerability_remaining: float = 0.0


func _ready() -> void:
	current_health = clampf(starting_health, 0.0, maximum_health)
	is_dead = current_health <= 0.0
	set_process(false)


func _process(delta: float) -> void:
	advance_runtime(delta)


func receive_damage(amount: float, context: HitContext3D = null) -> bool:
	if not is_finite(amount) or amount <= 0.0 or is_dead or not damage_enabled or is_invulnerable():
		return false
	var previous := current_health
	current_health = maxf(current_health - amount, 0.0)
	var applied := previous - current_health
	if applied <= 0.0:
		return false
	var became_dead := current_health <= 0.0
	if became_dead:
		is_dead = true
		_clear_invulnerability()
	damaged.emit(applied, context)
	health_changed.emit(previous, current_health, maximum_health)
	if became_dead:
		died.emit(context)
	elif damage_invulnerability_duration > 0.0:
		set_invulnerable_for(damage_invulnerability_duration)
	return true


func heal(amount: float, source: Object = null) -> bool:
	if not is_finite(amount) or amount <= 0.0 or is_dead or current_health >= maximum_health:
		return false
	var previous := current_health
	current_health = minf(current_health + amount, maximum_health)
	var applied := current_health - previous
	if applied <= 0.0:
		return false
	healed.emit(applied, source)
	health_changed.emit(previous, current_health, maximum_health)
	return true


func can_receive_item_effect(effect_id: StringName, amount: float) -> bool:
	return effect_id == &"heal" and is_finite(amount) and amount > 0.0 and not is_dead and current_health < maximum_health


func receive_item_effect(effect_id: StringName, amount: float, context: Dictionary) -> bool:
	if not can_receive_item_effect(effect_id, amount):
		return false
	return heal(amount, context.get(&"source", null))


func set_damage_enabled(enabled: bool) -> void:
	damage_enabled = enabled
	if not damage_enabled:
		_clear_invulnerability()


func set_invulnerable_for(duration: float) -> void:
	if not is_finite(duration):
		return
	var next_remaining := maxf(duration, 0.0)
	if is_equal_approx(invulnerability_remaining, next_remaining):
		return
	invulnerability_remaining = next_remaining
	set_process(invulnerability_remaining > 0.0)
	invulnerability_changed.emit(is_invulnerable(), invulnerability_remaining)


func is_invulnerable() -> bool:
	return invulnerability_remaining > 0.0


func advance_runtime(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or invulnerability_remaining <= 0.0:
		return
	invulnerability_remaining = maxf(invulnerability_remaining - delta, 0.0)
	if invulnerability_remaining <= 0.0:
		set_process(false)
		invulnerability_changed.emit(false, 0.0)


func get_checkpoint_snapshot(force_full_health: bool = false) -> Dictionary:
	return {
		&"current_health": maximum_health if force_full_health else current_health,
		&"maximum_health": maximum_health,
		&"is_dead": false if force_full_health else is_dead,
	}


func validate_checkpoint_snapshot(snapshot: Dictionary) -> bool:
	if not snapshot.has(&"current_health") or not snapshot.has(&"maximum_health"):
		return false
	var snapshot_maximum := float(snapshot.maximum_health)
	var snapshot_current := float(snapshot.current_health)
	var snapshot_dead := bool(snapshot.get(&"is_dead", snapshot_current <= 0.0))
	return (
		is_finite(snapshot_maximum)
		and is_finite(snapshot_current)
		and snapshot_maximum > 0.0
		and is_equal_approx(snapshot_maximum, maximum_health)
		and snapshot_current >= 0.0
		and snapshot_current <= snapshot_maximum
		and snapshot_dead == (snapshot_current <= 0.0)
	)


func restore_checkpoint_snapshot(snapshot: Dictionary) -> bool:
	if not validate_checkpoint_snapshot(snapshot):
		return false
	var was_dead := is_dead
	var previous := current_health
	current_health = float(snapshot.current_health)
	is_dead = bool(snapshot.is_dead)
	damage_enabled = true
	_clear_invulnerability()
	if not is_equal_approx(previous, current_health):
		health_changed.emit(previous, current_health, maximum_health)
	if was_dead and not is_dead:
		revived.emit(current_health, maximum_health)
	return true


func _clear_invulnerability() -> void:
	if invulnerability_remaining <= 0.0:
		set_process(false)
		return
	invulnerability_remaining = 0.0
	set_process(false)
	invulnerability_changed.emit(false, 0.0)

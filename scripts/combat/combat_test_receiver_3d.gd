class_name CombatTestReceiver3D
extends AnimatableBody3D

signal health_changed(previous: float, current: float, context: HitContext3D)
signal died(context: HitContext3D)

@export_range(1.0, 10000.0, 1.0) var maximum_health: float = 100.0
@export var moves: bool = false
@export_range(0.0, 10.0, 0.05, "suffix:m") var movement_width: float = 3.0
@export_range(0.0, 5.0, 0.05, "suffix:Hz") var movement_frequency: float = 0.35

var health: float
var is_dead: bool = false
var last_hit_context: HitContext3D
var _start_position: Vector3
var _elapsed: float = 0.0


func _ready() -> void:
	health = maximum_health
	_start_position = position


func _physics_process(delta: float) -> void:
	if not moves or is_dead:
		return
	_elapsed += delta
	position.x = _start_position.x + sin(_elapsed * TAU * movement_frequency) * movement_width


func receive_damage(amount: float, context: HitContext3D) -> void:
	if is_dead or amount <= 0.0:
		return
	var previous := health
	health = maxf(health - amount, 0.0)
	last_hit_context = context
	health_changed.emit(previous, health, context)
	if health <= 0.0:
		is_dead = true
		died.emit(context)


func reset_receiver() -> void:
	health = maximum_health
	is_dead = false
	last_hit_context = null
	_elapsed = 0.0
	position = _start_position

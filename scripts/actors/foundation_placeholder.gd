extends CharacterBody3D

@export_range(1.0, 10.0, 0.1) var move_speed: float = 4.5


func _physics_process(_delta: float) -> void:
	var input_vector := Input.get_vector(
		&"move_left", &"move_right", &"move_forward", &"move_back"
	)
	velocity = Vector3(input_vector.x, 0.0, input_vector.y) * move_speed
	move_and_slide()


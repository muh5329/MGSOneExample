extends Node

signal noise_emitted(event: NoiseEvent3D)


func emit_noise(event: NoiseEvent3D) -> void:
	noise_emitted.emit(event)


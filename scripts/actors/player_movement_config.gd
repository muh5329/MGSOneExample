class_name PlayerMovementConfig
extends Resource

@export_category("Speed")
@export_range(0.1, 12.0, 0.1, "or_greater") var standing_speed: float = 4.5
@export_range(0.1, 12.0, 0.1, "or_greater") var crouch_speed: float = 2.6
@export_range(0.1, 60.0, 0.1, "or_greater") var acceleration: float = 24.0
@export_range(0.1, 60.0, 0.1, "or_greater") var deceleration: float = 30.0
@export_range(1.0, 1440.0, 1.0, "or_greater") var turn_speed_degrees: float = 720.0

@export_category("Floor Handling")
@export_range(0.1, 80.0, 0.1, "or_greater") var gravity: float = 24.0
@export_range(0.0, 1.0, 0.01) var floor_snap_length: float = 0.3
@export_range(0.0, 89.0, 0.5) var maximum_slope_degrees: float = 46.0

@export_category("Body")
@export_range(0.1, 2.0, 0.01) var capsule_radius: float = 0.4
@export_range(0.2, 3.0, 0.01) var standing_height: float = 1.8
@export_range(0.2, 3.0, 0.01) var crouch_height: float = 1.2
@export_range(0.0, 0.2, 0.005) var clearance_margin: float = 0.03

@export_category("Noise")
@export_range(0.0, 2.0, 0.01) var standing_noise_multiplier: float = 1.0
@export_range(0.0, 2.0, 0.01) var crouch_noise_multiplier: float = 0.3
@export_range(0.01, 1.0, 0.01) var noise_event_interval: float = 0.25
@export_range(0.0, 1.0, 0.005) var minimum_noise_event: float = 0.02

class_name CameraAimSettings
extends Resource

@export_group("View")
@export_range(30.0, 100.0, 0.5, "degrees") var exploration_fov: float = 54.0
@export_range(30.0, 100.0, 0.5, "degrees") var aim_fov: float = 70.0
@export_range(0.01, 1.0, 0.01, "suffix:m") var aim_near_plane: float = 0.05

@export_group("Aim Input")
@export_range(0.01, 1.0, 0.01, "suffix:deg/px") var mouse_sensitivity: float = 0.12
@export_range(30.0, 360.0, 1.0, "suffix:deg/s") var controller_sensitivity: float = 150.0
@export_range(0.0, 0.95, 0.01) var controller_dead_zone: float = 0.2
@export var invert_horizontal: bool = false
@export var invert_vertical: bool = false

@export_group("Aim Limits")
@export_range(0.0, 180.0, 1.0, "degrees") var yaw_limit_degrees: float = 70.0
@export_range(-89.0, 0.0, 1.0, "degrees") var pitch_down_limit_degrees: float = -45.0
@export_range(0.0, 89.0, 1.0, "degrees") var pitch_up_limit_degrees: float = 35.0
@export_range(0.0, 2.0, 0.01, "suffix:m") var near_wall_check_distance: float = 0.45

@export_group("Exploration")
@export_range(0.0, 1.0, 0.01, "suffix:s") var minimum_zone_hold_time: float = 0.10
@export_range(0.0, 2.0, 0.01, "suffix:m") var obstruction_margin: float = 0.30
@export_range(0.1, 20.0, 0.1, "suffix:m") var minimum_camera_distance: float = 1.25


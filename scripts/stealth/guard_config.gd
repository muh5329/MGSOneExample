class_name GuardConfig
extends Resource

@export_category("Movement")
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var patrol_speed: float = 2.4
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var suspicious_speed: float = 1.6
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var pursuit_speed: float = 4.0
@export_range(0.1, 100.0, 0.5, "suffix:m/s²") var acceleration: float = 18.0
@export_range(1.0, 1440.0, 1.0, "suffix:°/s") var turn_speed_degrees: float = 540.0
@export_range(0.05, 2.0, 0.05, "suffix:m") var destination_tolerance: float = 0.45
@export_range(0.1, 10.0, 0.1, "suffix:s") var unreachable_timeout: float = 1.0

@export_category("Vision")
@export_range(1.0, 100.0, 0.5, "suffix:m") var standing_vision_range: float = 18.0
@export_range(1.0, 100.0, 0.5, "suffix:m") var crouched_vision_range: float = 13.0
@export_range(1.0, 179.0, 1.0, "suffix:°") var horizontal_cone_degrees: float = 70.0
@export_range(1.0, 179.0, 1.0, "suffix:°") var vertical_cone_degrees: float = 70.0
@export_range(0.1, 3.0, 0.05, "suffix:m") var eye_height: float = 1.55
@export var target_sample_heights: PackedFloat32Array = PackedFloat32Array([0.45, 1.05, 1.55])
@export_flags_3d_physics var perception_mask: int = 8 | 32
@export_range(0.1, 5.0, 0.05, "suffix:s") var sight_confirmation_time: float = 0.8
@export_range(0.1, 10.0, 0.05, "suffix:s") var suspicion_decay_time: float = 1.5
@export_range(0.0, 1.0, 0.01) var minimum_suspicion_stimulus: float = 0.25
@export_range(0.1, 10.0, 0.1, "suffix:m") var close_range_confirmation: float = 2.0

@export_category("Hearing")
@export_range(0.1, 30.0, 0.1, "suffix:m") var movement_hearing_radius: float = 5.0
@export_range(0.0, 1.0, 0.05) var occluded_hearing_multiplier: float = 0.45
@export_flags_3d_physics var hearing_occlusion_mask: int = 32

@export_category("Decision")
@export_range(0.0, 5.0, 0.05, "suffix:s") var suspicious_pause_duration: float = 0.65
@export_range(0.1, 20.0, 0.1, "suffix:s") var investigate_duration: float = 3.0
@export_range(0.1, 20.0, 0.1, "suffix:s") var lost_sight_grace: float = 3.0
@export_range(0.1, 60.0, 0.5, "suffix:s") var local_search_duration: float = 8.0
@export_range(0.5, 10.0, 0.25, "suffix:m") var search_radius: float = 3.0

@export_category("Combat")
@export_range(0.5, 50.0, 0.5, "suffix:m") var attack_range: float = 12.0
@export_range(0.0, 3.0, 0.05, "suffix:s") var attack_telegraph_duration: float = 0.35
@export_range(0.05, 5.0, 0.05, "suffix:s") var attack_cadence: float = 0.75
@export_range(0.0, 1000.0, 1.0) var attack_damage: float = 20.0


func is_valid_config() -> bool:
	return (
		patrol_speed > 0.0
		and pursuit_speed > 0.0
		and standing_vision_range > 0.0
		and crouched_vision_range > 0.0
		and horizontal_cone_degrees > 0.0
		and horizontal_cone_degrees < 180.0
		and vertical_cone_degrees > 0.0
		and vertical_cone_degrees < 180.0
		and sight_confirmation_time > 0.0
		and suspicion_decay_time > 0.0
		and attack_cadence >= attack_telegraph_duration
	)

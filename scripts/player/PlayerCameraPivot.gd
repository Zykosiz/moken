class_name PlayerCameraPivot
extends Node3D

@export var mouse_sensitivity: float = 0.006
@export var pitch_min_degrees: float = -35.0
@export var pitch_max_degrees: float = 65.0
@export var spring_length: float = 6.5

@onready var spring_arm: SpringArm3D = $SpringArm3D

var _pitch: float = 0.2


func _ready() -> void:
	spring_arm.spring_length = spring_length
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(pitch_min_degrees), deg_to_rad(pitch_max_degrees))
		spring_arm.rotation.x = _pitch

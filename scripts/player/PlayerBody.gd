class_name PlayerBody
extends CharacterBody3D

@export_group("Movement")
@export var walk_speed: float = 3.2
@export var run_speed: float = 6.5
@export var acceleration: float = 12.0
@export var deceleration: float = 16.0
@export var rotation_speed: float = 10.0
@export var air_control: float = 0.35

@export_group("Jump & Gravity")
@export var jump_velocity: float = 8.0
@export var gravity: float = 20.0
@export var max_fall_speed: float = 30.0

@export_group("References")
@export var terrain_path: NodePath
@export var spawn_height_offset: float = 1.0

@onready var visuals: Node3D = $Visuals
@onready var camera_pivot: Node3D = $CameraPivot

var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var _current_speed: float = 0.0


func _ready() -> void:
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.6
	floor_stop_on_slope = true

	var terrain := get_node_or_null(terrain_path)
	if terrain != null and terrain.has_method("get_height"):
		var ground_y: float = terrain.call("get_height", global_position.x, global_position.z)
		global_position.y = ground_y + spawn_height_offset

	animation_player = _find_animation_player(self)
	animation_tree = _build_animation_tree()


func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera_yaw: float = camera_pivot.rotation.y if camera_pivot else 0.0
	var move_direction := Vector3(input_vector.x, 0.0, input_vector.y).rotated(Vector3.UP, camera_yaw)
	if move_direction.length_squared() > 0.0001:
		move_direction = move_direction.normalized()

	var target_speed := run_speed if Input.is_action_pressed("run") else walk_speed
	var target_velocity := move_direction * target_speed

	var accel_rate := acceleration if move_direction.length_squared() > 0.0 else deceleration
	if not is_on_floor():
		accel_rate *= air_control

	velocity.x = move_toward(velocity.x, target_velocity.x, accel_rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, accel_rate * delta)

	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
		else:
			velocity.y = -0.5
	else:
		velocity.y = max(velocity.y - gravity * delta, -max_fall_speed)

	move_and_slide()

	if move_direction.length_squared() > 0.0001:
		var target_angle := atan2(move_direction.x, -move_direction.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, 1.0 - exp(-rotation_speed * delta))

	_current_speed = Vector2(velocity.x, velocity.z).length()
	_update_animation()


func _update_animation() -> void:
	if animation_tree == null:
		return
	var ratio: float = clamp(_current_speed / run_speed, 0.0, 1.0)
	animation_tree.set("parameters/Locomotion/blend_position", ratio)
	animation_tree.set("parameters/GroundAir/transition_request", &"air" if not is_on_floor() else &"grounded")


func _find_animation_player(root: Node) -> AnimationPlayer:
	for child in root.get_children():
		if child is AnimationPlayer:
			return child
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _build_animation_tree() -> AnimationTree:
	if animation_player == null:
		push_warning("PlayerBody: no AnimationPlayer found under the character model.")
		return null

	var available := animation_player.get_animation_list()
	var required := ["Idle", "Walk", "Run", "Jump"]
	for anim_name in required:
		if not anim_name in available:
			push_warning("PlayerBody: animation '%s' not found on model, animation blending disabled." % anim_name)
			return null

	var idle_anim := AnimationNodeAnimation.new()
	idle_anim.animation = &"Idle"
	var walk_anim := AnimationNodeAnimation.new()
	walk_anim.animation = &"Walk"
	var run_anim := AnimationNodeAnimation.new()
	run_anim.animation = &"Run"
	var jump_anim := AnimationNodeAnimation.new()
	jump_anim.animation = &"Jump"

	var locomotion := AnimationNodeBlendSpace1D.new()
	locomotion.min_space = 0.0
	locomotion.max_space = 1.0
	locomotion.add_blend_point(idle_anim, 0.0)
	locomotion.add_blend_point(walk_anim, 0.5)
	locomotion.add_blend_point(run_anim, 1.0)

	var ground_air := AnimationNodeTransition.new()
	ground_air.add_input("grounded")
	ground_air.add_input("air")
	ground_air.xfade_time = 0.25

	var blend_tree := AnimationNodeBlendTree.new()
	blend_tree.add_node("Locomotion", locomotion, Vector2(200, 0))
	blend_tree.add_node("Jump", jump_anim, Vector2(200, 160))
	blend_tree.add_node("GroundAir", ground_air, Vector2(420, 80))
	blend_tree.connect_node("GroundAir", 0, "Locomotion")
	blend_tree.connect_node("GroundAir", 1, "Jump")
	blend_tree.connect_node("output", 0, "GroundAir")

	var tree := AnimationTree.new()
	add_child(tree)
	tree.anim_player = tree.get_path_to(animation_player)
	tree.tree_root = blend_tree
	tree.active = true
	return tree

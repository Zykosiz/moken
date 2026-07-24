class_name NpcAnimationController
extends Node

@export var body_path: NodePath = NodePath("..")
@export var rig_path: NodePath = NodePath("../VisualRoot/HumanoidRig")
@export var idle_speed_threshold: float = 0.08
@export var walk_speed: float = 1.8
@export var run_speed: float = 4.0
@export var blend_smoothing: float = 10.0

var _body: CharacterBody3D
var _rig: HumanoidRig
var _animation_tree: AnimationTree
var _blend_position := Vector2.ZERO


func _ready() -> void:
	_body = get_node_or_null(body_path) as CharacterBody3D
	_rig = get_node_or_null(rig_path) as HumanoidRig
	if _rig == null:
		push_warning("NpcAnimationController: rig_path does not point to a HumanoidRig.")
		return

	if _rig.get_animation_tree() != null:
		_bind_animation_tree()
		return

	_rig.rig_ready.connect(_bind_animation_tree)


func _process(delta: float) -> void:
	if _animation_tree == null or _body == null:
		return

	var horizontal_velocity := Vector3(_body.velocity.x, 0.0, _body.velocity.z)
	var horizontal_speed := horizontal_velocity.length()
	var target_blend := Vector2.ZERO

	if horizontal_speed > idle_speed_threshold:
		var local_velocity: Vector3 = _body.global_transform.basis.inverse() * horizontal_velocity.normalized()
		target_blend = Vector2(local_velocity.x, -local_velocity.z).limit_length(1.0)

	var smoothing: float = clamp(blend_smoothing * delta, 0.0, 1.0)
	_blend_position = _blend_position.lerp(target_blend, smoothing)

	var walk_run_blend: float = 0.0
	if run_speed > walk_speed:
		walk_run_blend = clamp((horizontal_speed - walk_speed) / (run_speed - walk_speed), 0.0, 1.0)

	_animation_tree.set("parameters/Locomotion/WalkBlend/blend_position", _blend_position)
	_animation_tree.set("parameters/Locomotion/RunBlend/blend_position", _blend_position)
	_animation_tree.set("parameters/Locomotion/SprintBlend/blend_position", _blend_position)
	_animation_tree.set("parameters/Locomotion/WalkRunBlend/blend_amount", walk_run_blend)
	_animation_tree.set("parameters/Locomotion/SpeedBlend/blend_amount", 0.0)


func _bind_animation_tree() -> void:
	_animation_tree = _rig.get_animation_tree()
	if _animation_tree == null:
		return

	_animation_tree.active = true
	if _rig.animation_player != null and _rig.animation_player.has_animation("idle"):
		_rig.animation_player.play("idle")

	_animation_tree.set("parameters/Locomotion/WalkBlend/blend_position", Vector2.ZERO)
	_animation_tree.set("parameters/Locomotion/RunBlend/blend_position", Vector2.ZERO)
	_animation_tree.set("parameters/Locomotion/SprintBlend/blend_position", Vector2.ZERO)
	_animation_tree.set("parameters/Locomotion/WalkRunBlend/blend_amount", 0.0)
	_animation_tree.set("parameters/Locomotion/SpeedBlend/blend_amount", 0.0)

	var playback: AnimationNodeStateMachinePlayback = _animation_tree.get("parameters/playback")
	if playback != null:
		playback.travel("Locomotion")

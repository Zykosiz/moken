class_name HumanoidRig
extends Node3D

signal rig_ready

@export var source_scene: PackedScene = preload("res://addons/real-controller/character.tscn")
@export var body_color: Color = Color(1.0, 0.396, 0.0, 1.0)

var rig_source: Node3D
var character_root: Node3D
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var skeleton: Skeleton3D
var body_mesh: MeshInstance3D


func _ready() -> void:
	_build_from_source()


func get_animation_tree() -> AnimationTree:
	return animation_tree


func set_body_color(value: Color) -> void:
	body_color = value
	_apply_body_color()


func _build_from_source() -> void:
	if source_scene == null:
		push_error("HumanoidRig requires a source scene.")
		return

	var source_root := source_scene.instantiate() as Node3D
	if source_root == null:
		push_error("HumanoidRig could not instantiate its source scene.")
		return

	var source_character := source_root.get_node_or_null("character") as Node3D
	var source_animation_player := source_root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var source_animation_tree := source_root.get_node_or_null("AnimationTree") as AnimationTree

	if source_character == null or source_animation_player == null or source_animation_tree == null:
		source_root.free()
		push_error("HumanoidRig source scene is missing character animation nodes.")
		return

	source_root.script = null
	source_root.set_process(false)
	source_root.set_physics_process(false)
	source_root.set_process_input(false)
	source_root.set_process_unhandled_input(false)
	source_root.set_process_unhandled_key_input(false)
	_remove_source_node(source_root, "CameraPivot")
	_remove_source_node(source_root, "CollisionShape3D")
	_remove_source_node(source_root, "Animation")

	add_child(source_root)
	source_root.name = "RigSource"
	rig_source = source_root

	character_root = source_character
	animation_player = source_animation_player
	animation_player.root_node = NodePath("../character")

	source_animation_tree.root_node = NodePath("../character")
	source_animation_tree.anim_player = NodePath("../AnimationPlayer")
	source_animation_tree.advance_expression_base_node = NodePath("../../../..")
	source_animation_tree.active = true
	animation_tree = source_animation_tree

	skeleton = character_root.get_node_or_null("GeneralSkeleton") as Skeleton3D
	if skeleton != null:
		body_mesh = skeleton.get_node_or_null("HumanM_BodyMesh") as MeshInstance3D
	_apply_body_color()

	if animation_player.has_animation("idle"):
		animation_player.play("idle")

	rig_ready.emit()


func _remove_source_node(root: Node, path: NodePath) -> void:
	var node := root.get_node_or_null(path)
	if node == null:
		return
	node.free()


func _apply_body_color() -> void:
	if body_mesh == null:
		return

	var material := StandardMaterial3D.new()
	material.albedo_color = body_color
	material.roughness = 0.75
	material.metallic = 0.0
	body_mesh.set_surface_override_material(0, material)

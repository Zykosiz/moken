@tool
class_name LayoutAssetInstance
extends Node3D

@export var source_scene: PackedScene
@export var source_scale: Vector3 = Vector3.ONE
@export var apply_tint: bool = false
@export var tint_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var align_to_surface: bool = false
@export_range(0.0, 1.0, 0.05) var normal_alignment_strength: float = 0.0
@export var random_y_rotation: bool = false
@export var random_scale_range: Vector2 = Vector2.ONE
@export var surface_offset: float = 0.08
@export var collision_enabled: bool = false
@export var collision_size: Vector3 = Vector3(2.0, 2.0, 2.0)
@export var collision_center: Vector3 = Vector3(0.0, 1.0, 0.0)
@export_flags_3d_physics var collision_layer_bits: int = 1
@export_flags_3d_physics var collision_mask_bits: int = 1

@export var rebuild: bool = false : set = _set_rebuild


func _ready() -> void:
	if get_node_or_null("Visual") == null:
		_rebuild()


func _set_rebuild(value: bool) -> void:
	if value:
		_rebuild()
	rebuild = false


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()

	var visual: Node3D
	if source_scene != null:
		visual = source_scene.instantiate() as Node3D
	else:
		visual = _make_fallback_visual()

	if visual == null:
		return

	visual.name = "Visual"
	visual.scale = source_scale
	add_child(visual)
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		visual.owner = get_tree().edited_scene_root

	# Rewire to each mesh's extracted standalone material where one exists,
	# regardless of apply_tint below -- apply_tint's per-instance override
	# (if set) still wins visually, but this keeps the underlying mesh
	# resource correct for every other instance/scene sharing it too.
	if source_scene != null:
		ExtractedMaterialMap.rewire_tree(visual, source_scene.resource_path)

	if apply_tint:
		_apply_tint_recursive(visual)

	if collision_enabled:
		_add_collision()


func _make_fallback_visual() -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 2.0, 2.0)
	mesh_instance.mesh = mesh
	return mesh_instance


func _apply_tint_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var surface_count := 1
		if mesh_instance.mesh != null:
			surface_count = max(mesh_instance.mesh.get_surface_count(), 1)
		for surface_index in surface_count:
			mesh_instance.set_surface_override_material(surface_index, _tinted_surface_material(mesh_instance, surface_index))

	for child in node.get_children():
		_apply_tint_recursive(child)


func _tinted_surface_material(mesh_instance: MeshInstance3D, surface_index: int) -> Material:
	var source_material := mesh_instance.get_surface_override_material(surface_index)
	if source_material == null and mesh_instance.mesh != null and surface_index < mesh_instance.mesh.get_surface_count():
		source_material = mesh_instance.mesh.surface_get_material(surface_index)

	var material: StandardMaterial3D
	if source_material is StandardMaterial3D:
		material = source_material.duplicate(true) as StandardMaterial3D
	elif source_material != null:
		return source_material
	else:
		material = StandardMaterial3D.new()
		material.roughness = 0.8

	material.albedo_color = Color(
		material.albedo_color.r * tint_color.r,
		material.albedo_color.g * tint_color.g,
		material.albedo_color.b * tint_color.b,
		material.albedo_color.a * tint_color.a
	)
	return material


func _add_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "PlayerCollision"
	body.collision_layer = collision_layer_bits
	body.collision_mask = collision_mask_bits
	add_child(body)

	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = collision_size
	shape.shape = box
	shape.position = collision_center
	body.add_child(shape)

	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		body.owner = get_tree().edited_scene_root
		shape.owner = get_tree().edited_scene_root

@tool
class_name IslandVegetation
extends Node3D

# Only true small props here. Kenney's Pirate Kit "*-patch*" assets (grass-patch,
# patch-sand, patch-sand-foliage) are NOT ground cover - they're standalone little
# islet props, which is why scattering them densely produced a field of tiny fake
# islands instead of undergrowth. Keep this list to single small props only.
const PALM_MESHES: Array[String] = [
	"res://Assets/Kenney/Pirate Kit/palm-straight.glb",
	"res://Assets/Kenney/Pirate Kit/palm-bend.glb",
	"res://Assets/Kenney/Pirate Kit/palm-detailed-straight.glb",
	"res://Assets/Kenney/Pirate Kit/palm-detailed-bend.glb",
]
const UNDERGROWTH_MESHES: Array[String] = [
	"res://Assets/Kenney/Pirate Kit/grass.glb",
	"res://Assets/Kenney/Pirate Kit/grass-plant.glb",
]

@export var terrain_path: NodePath
@export var random_seed: int = 1000
@export var regenerate: bool = false : set = _set_regenerate

@export_group("Palms")
@export var palm_count: int = 140
@export var palm_mask_range: Vector2 = Vector2(0.08, 0.55)
@export var palm_max_slope_deg: float = 22.0
@export var palm_scale_range: Vector2 = Vector2(0.85, 1.35)

@export_group("Undergrowth")
@export var undergrowth_count: int = 0
@export var undergrowth_mask_range: Vector2 = Vector2(0.18, 1.0)
@export var undergrowth_max_slope_deg: float = 32.0
@export var undergrowth_scale_range: Vector2 = Vector2(0.75, 1.3)

var _terrain: Node


func _ready() -> void:
	_terrain = get_node_or_null(terrain_path)
	_generate()


func _set_regenerate(value: bool) -> void:
	if value:
		_terrain = get_node_or_null(terrain_path)
		_generate()
	regenerate = false


func _generate() -> void:
	_clear()
	if _terrain == null or not _terrain.has_method("sample_scatter_point"):
		push_warning("IslandVegetation: terrain_path is not assigned to a valid terrain node.")
		return

	var palm_root := _new_layer_root("Palms")
	var palm_collision_factory := func(s: float) -> Shape3D:
		var shape := CylinderShape3D.new()
		shape.radius = 0.32 * s
		shape.height = 4.2 * s
		return shape
	_scatter_layer(
		palm_root, PALM_MESHES, palm_count,
		palm_mask_range.x, palm_mask_range.y, palm_max_slope_deg, palm_scale_range,
		random_seed, true, palm_collision_factory, 2.1
	)

	if undergrowth_count > 0:
		var undergrowth_root := _new_layer_root("Undergrowth")
		_scatter_layer(
			undergrowth_root, UNDERGROWTH_MESHES, undergrowth_count,
			undergrowth_mask_range.x, undergrowth_mask_range.y, undergrowth_max_slope_deg, undergrowth_scale_range,
			random_seed + 97, false
		)


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _new_layer_root(layer_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = layer_name
	add_child(root)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		root.owner = get_tree().edited_scene_root
	return root


func _load_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		push_warning("IslandVegetation: missing asset %s" % path)
		return null
	var packed: PackedScene = load(path)
	var instance := packed.instantiate()
	var mesh_instance := _find_mesh_instance(instance)
	var result: Mesh = null
	if mesh_instance != null:
		result = mesh_instance.mesh
	instance.queue_free()
	return result


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null


func _scatter_layer(
	layer_root: Node3D,
	mesh_paths: Array,
	count: int,
	min_mask: float,
	max_mask: float,
	max_slope_deg: float,
	scale_range: Vector2,
	seed_value: int,
	add_collision: bool = false,
	collision_shape_factory: Callable = Callable(),
	collision_y_offset: float = 0.0
) -> void:
	var meshes: Array[Mesh] = []
	for path in mesh_paths:
		var m := _load_mesh(path)
		if m != null:
			meshes.append(m)
	if meshes.is_empty():
		return

	var multimeshes: Array[MultiMeshInstance3D] = []
	for i in meshes.size():
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_Variant%d" % [layer_root.name, i]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[i]
		layer_root.add_child(mmi)
		if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
			mmi.owner = get_tree().edited_scene_root
		mmi.multimesh = mm
		multimeshes.append(mmi)

	var collision_root: Node3D = null
	if add_collision:
		collision_root = Node3D.new()
		collision_root.name = "%s_Collision" % layer_root.name
		layer_root.add_child(collision_root)
		if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
			collision_root.owner = get_tree().edited_scene_root

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var transforms_per_mesh: Array = []
	for i in meshes.size():
		transforms_per_mesh.append([])

	for i in count:
		var sample: Dictionary = _terrain.call("sample_scatter_point", rng, min_mask, max_mask, max_slope_deg)
		if sample.is_empty():
			continue
		var pos: Vector3 = sample["position"]
		var yaw := rng.randf_range(0.0, TAU)
		var s := rng.randf_range(scale_range.x, scale_range.y)
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s)
		var xform := Transform3D(basis, pos)
		var mesh_index := rng.randi_range(0, meshes.size() - 1)
		transforms_per_mesh[mesh_index].append(xform)

		if add_collision and collision_shape_factory.is_valid():
			var body := StaticBody3D.new()
			var col := CollisionShape3D.new()
			col.shape = collision_shape_factory.call(s)
			body.add_child(col)
			collision_root.add_child(body)
			if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
				body.owner = get_tree().edited_scene_root
				col.owner = get_tree().edited_scene_root
			body.transform = Transform3D(Basis(Vector3.UP, yaw), pos + Vector3.UP * collision_y_offset * s)

	for i in meshes.size():
		var list: Array = transforms_per_mesh[i]
		var mmi := multimeshes[i]
		mmi.multimesh.instance_count = list.size()
		for j in list.size():
			mmi.multimesh.set_instance_transform(j, list[j])

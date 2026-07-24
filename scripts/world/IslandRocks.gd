@tool
class_name IslandRocks
extends Node3D

const COASTAL_ROCK_MESHES: Array[String] = [
	"res://Assets/Kenney/Pirate Kit/rocks-sand-a.glb",
	"res://Assets/Kenney/Pirate Kit/rocks-sand-b.glb",
	"res://Assets/Kenney/Pirate Kit/rocks-sand-c.glb",
]
const INLAND_ROCK_MESHES: Array[String] = [
	"res://Assets/Kenney/Pirate Kit/rocks-a.glb",
	"res://Assets/Kenney/Pirate Kit/rocks-b.glb",
	"res://Assets/Kenney/Pirate Kit/rocks-c.glb",
]

@export var terrain_path: NodePath
@export var random_seed: int = 1000
@export var regenerate: bool = false : set = _set_regenerate

@export_group("Coastal Rocks")
@export var coastal_rock_count: int = 60
@export var coastal_mask_range: Vector2 = Vector2(0.0, 0.22)
@export var coastal_max_slope_deg: float = 35.0
@export var coastal_scale_range: Vector2 = Vector2(0.7, 1.4)

@export_group("Inland Rocks")
@export var inland_rock_count: int = 70
@export var inland_mask_range: Vector2 = Vector2(0.3, 0.95)
@export var inland_max_slope_deg: float = 40.0
@export var inland_scale_range: Vector2 = Vector2(0.8, 1.6)

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
		push_warning("IslandRocks: terrain_path is not assigned to a valid IslandTerrain node.")
		return

	var coastal_root := _new_layer_root("CoastalRocks")
	var coastal_collision_factory := func(s: float) -> Shape3D:
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.6, 1.1, 1.6) * s
		return shape
	_scatter_layer(
		coastal_root, COASTAL_ROCK_MESHES, coastal_rock_count,
		coastal_mask_range.x, coastal_mask_range.y, coastal_max_slope_deg, coastal_scale_range,
		random_seed + 11, true, coastal_collision_factory, 0.5
	)

	var inland_root := _new_layer_root("InlandRocks")
	var inland_collision_factory := func(s: float) -> Shape3D:
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.8, 1.4, 1.8) * s
		return shape
	_scatter_layer(
		inland_root, INLAND_ROCK_MESHES, inland_rock_count,
		inland_mask_range.x, inland_mask_range.y, inland_max_slope_deg, inland_scale_range,
		random_seed + 53, true, inland_collision_factory, 0.6
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
		push_warning("IslandRocks: missing asset %s" % path)
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

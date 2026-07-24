@tool
class_name IslandFoliageLayer
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
		push_warning("IslandFoliageLayer: terrain_path is not assigned to a valid terrain node.")
		return

	var palm_root := _new_layer_root("Palms")
	var palm_collision_factory := func(s: float) -> Dictionary:
		return {"kind": "cylinder", "dims": Vector2(0.32 * s, 4.2 * s)}
	_scatter_layer(
		palm_root, PALM_MESHES, palm_count,
		palm_mask_range.x, palm_mask_range.y, palm_max_slope_deg, palm_scale_range,
		random_seed, true, palm_collision_factory, 2.1, 0.4
	)

	if undergrowth_count > 0:
		var undergrowth_root := _new_layer_root("Undergrowth")
		_scatter_layer(
			undergrowth_root, UNDERGROWTH_MESHES, undergrowth_count,
			undergrowth_mask_range.x, undergrowth_mask_range.y, undergrowth_max_slope_deg, undergrowth_scale_range,
			random_seed + 97, false, Callable(), 0.0, 0.8
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
		push_warning("IslandFoliageLayer: missing asset %s" % path)
		return null
	var packed: PackedScene = load(path)
	var instance := packed.instantiate()
	var mesh_instance := _find_mesh_instance(instance)
	var result: Mesh = null
	if mesh_instance != null:
		result = mesh_instance.mesh
		# result is Godot's cached Mesh resource for this model path (shared
		# across every load() of the same file), so this rewires it globally
		# for all instances/scenes using this mesh, not just this MultiMesh --
		# that's the intended behavior, not an accidental side effect.
		ExtractedMaterialMap.rewire_mesh(result, path)
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


# Local-space (centered at origin) triangle soup for one collision entry, built from
# Godot's own PrimitiveMesh generators so winding/normals are guaranteed correct -
# no hand-rolled box/cylinder geometry to get wrong.
func _shape_faces(kind: String, dims: Variant) -> PackedVector3Array:
	match kind:
		"cylinder":
			var cyl := CylinderMesh.new()
			cyl.top_radius = dims.x
			cyl.bottom_radius = dims.x
			cyl.height = dims.y
			cyl.radial_segments = 8
			return cyl.get_faces()
		"box":
			var box := BoxMesh.new()
			box.size = dims
			return box.get_faces()
	return PackedVector3Array()


# Combines every scattered instance's collision geometry into a single
# ConcavePolygonShape3D under one StaticBody3D, instead of one body+shape pair per
# instance. Cuts hundreds of collision nodes down to one per layer.
func _build_combined_collision(layer_root: Node3D, entries: Array) -> void:
	if entries.is_empty():
		return

	var combined := PackedVector3Array()
	for entry in entries:
		var local_faces: PackedVector3Array = _shape_faces(entry.kind, entry.dims)
		var xform: Transform3D = entry.transform
		for v in local_faces:
			combined.append(xform * v)

	if combined.is_empty():
		return

	var body := StaticBody3D.new()
	body.name = "%s_Collision" % layer_root.name
	layer_root.add_child(body)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		body.owner = get_tree().edited_scene_root

	var col := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(combined)
	col.shape = shape
	body.add_child(col)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		col.owner = get_tree().edited_scene_root



# Blends an upright basis toward the sampled terrain normal so scattered
# instances tilt to sit flush with sloped ground instead of always standing
# perfectly vertical (which reads as "floating"/"placed" on any slope).
# align_to_normal 0.0 keeps the old pure-upright behavior; 1.0 fully matches
# the terrain's tilt. yaw is still applied around the resulting up axis so
# facing direction stays randomized per instance.
func _oriented_basis(normal: Vector3, yaw: float, align_to_normal: float) -> Basis:
	if align_to_normal <= 0.0:
		return Basis(Vector3.UP, yaw)
	var up := Vector3.UP.slerp(normal, align_to_normal).normalized()
	var reference := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
	var right := reference.cross(up).normalized()
	var forward := up.cross(right).normalized()
	return Basis(right, up, forward).rotated(up, yaw)


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
	collision_y_offset: float = 0.0,
	align_to_normal: float = 0.0
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

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var transforms_per_mesh: Array = []
	for i in meshes.size():
		transforms_per_mesh.append([])

	var collision_entries: Array = []

	for i in count:
		var sample: Dictionary = _terrain.call("sample_scatter_point", rng, min_mask, max_mask, max_slope_deg)
		if sample.is_empty():
			continue
		var pos: Vector3 = sample["position"]
		var normal: Vector3 = sample.get("normal", Vector3.UP)
		var yaw := rng.randf_range(0.0, TAU)
		var s := rng.randf_range(scale_range.x, scale_range.y)
		var basis := _oriented_basis(normal, yaw, align_to_normal).scaled(Vector3.ONE * s)
		var xform := Transform3D(basis, pos)
		var mesh_index := rng.randi_range(0, meshes.size() - 1)
		transforms_per_mesh[mesh_index].append(xform)

		if add_collision and collision_shape_factory.is_valid():
			var shape_info: Dictionary = collision_shape_factory.call(s)
			var collision_basis := _oriented_basis(normal, yaw, align_to_normal)
			var collision_xform := Transform3D(collision_basis, pos + Vector3.UP * collision_y_offset * s)
			collision_entries.append({"transform": collision_xform, "kind": shape_info.kind, "dims": shape_info.dims})

	for i in meshes.size():
		var list: Array = transforms_per_mesh[i]
		var mmi := multimeshes[i]
		mmi.multimesh.instance_count = list.size()
		for j in list.size():
			mmi.multimesh.set_instance_transform(j, list[j])

	if add_collision:
		_build_combined_collision(layer_root, collision_entries)

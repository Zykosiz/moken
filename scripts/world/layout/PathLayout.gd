@tool
class_name PathLayout
extends RefCounted

## Path tile placement along point sequences — split out of
## AuthoredIslandLayout.gd unchanged.

const TERRAIN_PLACEMENT: GDScript = preload("res://scripts/world/TerrainPlacement.gd")
const PLACEMENT: GDScript = preload("res://scripts/world/layout/PlacementPrimitives.gd")

const PATH_TILES: Array[PackedScene] = [
	preload("res://Scenes/Layout/Island/PathTileRockA.tscn"),
	preload("res://Scenes/Layout/Island/PathTileRockB.tscn"),
	preload("res://Scenes/Layout/Island/PathTileRockC.tscn"),
]


static func make_path(parent: Node3D, terrain: Node, scene_root: Node, path_name: String, points: Array, width: float, material: Material) -> void:
	var root := Node3D.new()
	root.name = path_name
	parent.add_child(root)
	PLACEMENT.own_node(root, scene_root)

	var tint_color := Color.WHITE
	if material is StandardMaterial3D:
		tint_color = (material as StandardMaterial3D).albedo_color

	var tile_index := 0
	for i in range(points.size() - 1):
		var include_end: bool = i == points.size() - 2
		tile_index = make_path_between(root, terrain, scene_root, path_name, points[i], points[i + 1], width, tint_color, tile_index, include_end)


static func make_path_between(parent: Node3D, terrain: Node, scene_root: Node, path_name: String, from_point: Vector2, to_point: Vector2, width: float, tint_color: Color, start_index: int, include_end: bool) -> int:
	var distance: float = from_point.distance_to(to_point)
	var direction: Vector2 = (to_point - from_point).normalized()
	var base_yaw: float = atan2(direction.x, direction.y)
	var perpendicular: Vector2 = Vector2(direction.y, -direction.x)
	var tile_target_size: float = clampf(width * 0.42, 1.0, 2.0)
	var spacing: float = tile_target_size * 0.8
	var step_count: int = maxi(1, int(round(distance / spacing)))
	var last_step: int = step_count if include_end else step_count - 1

	var index := start_index
	for step in range(last_step + 1):
		var t: float = float(step) / float(step_count)
		var xz: Vector2 = from_point.lerp(to_point, t)

		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s_tile_%d" % [path_name, index])
		var yaw_jitter: float = rng.randf_range(-0.35, 0.35)
		var scale_jitter: float = rng.randf_range(0.88, 1.12)
		var lateral_jitter: float = rng.randf_range(-0.3, 0.3) * tile_target_size * 0.3
		xz += perpendicular * lateral_jitter
		var tile_scene: PackedScene = PATH_TILES[rng.randi_range(0, PATH_TILES.size() - 1)]

		place_path_tile(parent, terrain, scene_root, "%s_Tile%02d" % [path_name, index], tile_scene, xz, base_yaw + yaw_jitter, tile_target_size * scale_jitter, tint_color)
		index += 1

	return index


static func place_path_tile(parent: Node3D, terrain: Node, scene_root: Node, node_name: String, tile_scene: PackedScene, xz: Vector2, yaw: float, target_size: float, tint_color: Color) -> void:
	var node: Node3D = tile_scene.instantiate() as Node3D
	if node == null:
		return
	node.name = node_name
	node.set("apply_tint", true)
	node.set("tint_color", tint_color)
	parent.add_child(node)
	PLACEMENT.own_node(node, scene_root)

	var footprint: Vector3 = measure_local_footprint(node)
	var base_size: float = maxf(maxf(footprint.x, footprint.z), 0.01)
	var scale_value: Vector3 = Vector3.ONE * (target_size / base_size)

	TERRAIN_PLACEMENT.apply_surface(node, terrain, xz, yaw, 0.05, scale_value, 0.35)


static func measure_local_footprint(node: Node3D) -> Vector3:
	var mesh_instance := find_mesh_instance(node)
	if mesh_instance == null:
		return Vector3.ONE
	var aabb: AABB = mesh_instance.get_aabb()
	var relative_xform: Transform3D = node.global_transform.affine_inverse() * mesh_instance.global_transform
	var result := AABB()
	var first := true
	for i in range(8):
		var corner: Vector3 = aabb.position + Vector3(
			aabb.size.x * float(i & 1),
			aabb.size.y * float((i >> 1) & 1),
			aabb.size.z * float((i >> 2) & 1)
		)
		var world_corner: Vector3 = relative_xform * corner
		if first:
			result = AABB(world_corner, Vector3.ZERO)
			first = false
		else:
			result = result.expand(world_corner)
	return result.size


static func find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := find_mesh_instance(child)
		if found != null:
			return found
	return null

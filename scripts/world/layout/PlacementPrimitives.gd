@tool
class_name PlacementPrimitives
extends RefCounted

## Shared low-level "instantiate a scene, position/orient/scale it, optionally
## add collision or a foundation" toolkit used by every island layout category
## script (DistrictLayout, PathLayout, GameplayAnchorLayout, NpcLayout). Plays
## the same role for scene-instancing/placement that TerrainPlacement.gd plays
## for terrain sampling — split out of AuthoredIslandLayout.gd unchanged.

const TERRAIN_PLACEMENT: GDScript = preload("res://scripts/world/TerrainPlacement.gd")

const WATER_DOCK_HEIGHT := 0.26


static func own_node(node: Node, scene_root: Node) -> void:
	if scene_root != null:
		node.owner = scene_root


static func to_world(terrain: Node, xz: Vector2, height_offset: float = 0.0) -> Vector3:
	var height: float = terrain.call("get_height", xz.x, xz.y)
	return Vector3(xz.x, height + height_offset, xz.y)


static func place_building(
	parent: Node3D,
	terrain: Node,
	scene_root: Node,
	stone_material: Material,
	scene: PackedScene,
	node_name: String,
	xz: Vector2,
	yaw: float,
	scale_value: Vector3,
	footprint: Vector2,
	max_height_delta: float
) -> Node3D:
	var node: Node3D = scene.instantiate() as Node3D
	if node == null:
		return null
	var sampled: TERRAIN_PLACEMENT.FootprintResult = TERRAIN_PLACEMENT.find_nearby_valid_building(terrain, xz, yaw, footprint, max_height_delta, 14.0, 2.0, 0.62)
	node.name = node_name
	parent.add_child(node)
	own_node(node, scene_root)
	TERRAIN_PLACEMENT.apply_upright(node, sampled, 0.1, scale_value)
	make_foundation(parent, "%sFoundation" % node_name, sampled, footprint + Vector2(1.0, 1.0), 0.34, scene_root, stone_material)
	return node


static func place_prop(
	parent: Node3D,
	terrain: Node,
	scene_root: Node,
	scene: PackedScene,
	node_name: String,
	xz: Vector2,
	yaw: float,
	scale_value: Vector3,
	add_collision: bool,
	collision_size: Vector3,
	surface_offset: float = 0.12
) -> Node3D:
	var node: Node3D = scene.instantiate() as Node3D
	if node == null:
		return null
	var sampled: TERRAIN_PLACEMENT.FootprintResult = TERRAIN_PLACEMENT.sample_footprint(terrain, xz, yaw, Vector2(2.0, 2.0))
	node.name = node_name
	parent.add_child(node)
	own_node(node, scene_root)
	node.global_position = Vector3(xz.x, sampled.center_height + surface_offset, xz.y)
	node.rotation = Vector3(0.0, yaw, 0.0)
	node.scale = scale_value
	if add_collision:
		make_collision_box(node, "PlacementCollision", Vector3(0.0, collision_size.y * 0.5, 0.0), 0.0, collision_size, scene_root)
	return node


static func place_natural(
	parent: Node3D,
	terrain: Node,
	scene_root: Node,
	scene: PackedScene,
	node_name: String,
	xz: Vector2,
	yaw: float,
	scale_value: Vector3,
	normal_alignment_strength: float,
	add_collision: bool,
	collision_size: Vector3 = Vector3.ZERO
) -> Node3D:
	var node: Node3D = scene.instantiate() as Node3D
	if node == null:
		return null
	node.name = node_name
	parent.add_child(node)
	own_node(node, scene_root)
	TERRAIN_PLACEMENT.apply_surface(node, terrain, xz, yaw, 0.08, scale_value, normal_alignment_strength)
	if add_collision:
		make_collision_box(node, "PlacementCollision", Vector3(0.0, collision_size.y * 0.5, 0.0), 0.0, collision_size, scene_root)
	return node


static func place_retaining(parent: Node3D, terrain: Node, scene_root: Node, scene: PackedScene, node_name: String, xz: Vector2, yaw: float, scale_value: Vector3) -> Node3D:
	var node: Node3D = scene.instantiate() as Node3D
	if node == null:
		return null
	var sampled: TERRAIN_PLACEMENT.FootprintResult = TERRAIN_PLACEMENT.sample_footprint(terrain, xz, yaw, Vector2(7.0, 1.4))
	node.name = node_name
	parent.add_child(node)
	own_node(node, scene_root)
	node.global_position = Vector3(xz.x, sampled.average_height + 0.08, xz.y)
	node.rotation = Vector3(0.0, yaw, 0.0)
	node.scale = scale_value
	return node


static func place_dock(parent: Node3D, scene_root: Node, scene: PackedScene, node_name: String, xz: Vector2, yaw: float, scale_value: Vector3, collision_size: Vector3) -> Node3D:
	var node: Node3D = scene.instantiate() as Node3D
	if node == null:
		return null
	node.name = node_name
	parent.add_child(node)
	own_node(node, scene_root)
	node.global_position = Vector3(xz.x, WATER_DOCK_HEIGHT, xz.y)
	node.rotation = Vector3(0.0, yaw, 0.0)
	node.scale = scale_value
	make_collision_box(node, "DockDeckCollision", Vector3(0.0, collision_size.y * 0.5, 0.0), 0.0, collision_size, scene_root)
	return node


static func place_water_scene(parent: Node3D, scene_root: Node, scene: PackedScene, node_name: String, xz: Vector2, yaw: float, scale_value: Vector3) -> Node3D:
	var node: Node3D = scene.instantiate() as Node3D
	if node == null:
		return null
	node.name = node_name
	parent.add_child(node)
	own_node(node, scene_root)
	node.global_position = Vector3(xz.x, WATER_DOCK_HEIGHT - 0.12, xz.y)
	node.rotation.y = yaw
	node.scale = scale_value
	return node


static func make_foundation(parent: Node3D, node_name: String, sampled: TERRAIN_PLACEMENT.FootprintResult, size: Vector2, minimum_height: float, scene_root: Node, stone_material: Material) -> void:
	var foundation_height: float = max(minimum_height, sampled.height_delta + 0.22)
	var foundation_y: float = sampled.min_height + foundation_height * 0.5 - 0.12
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, foundation_height, size.y)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = stone_material
	parent.add_child(mesh_instance)
	own_node(mesh_instance, scene_root)
	mesh_instance.global_position = Vector3(sampled.center.x, foundation_y, sampled.center.y)
	mesh_instance.rotation.y = sampled.yaw
	make_collision_box(mesh_instance, "FoundationCollision", Vector3.ZERO, 0.0, Vector3(size.x, foundation_height, size.y), scene_root)


static func make_collision_box(parent: Node3D, node_name: String, local_position: Vector3, yaw: float, size: Vector3, scene_root: Node) -> void:
	if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		return
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = local_position
	body.rotation.y = yaw
	parent.add_child(body)
	own_node(body, scene_root)

	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	own_node(shape, scene_root)


static func make_marker(parent: Node3D, terrain: Node, scene_root: Node, marker_name: String, xz: Vector2, height_offset: float = 0.35) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	parent.add_child(marker)
	own_node(marker, scene_root)
	marker.global_position = to_world(terrain, xz, height_offset)

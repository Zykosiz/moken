class_name TerrainPlacement
extends RefCounted


static func place_on_terrain(node: Node3D, terrain: Node, height_offset: float = 0.0) -> bool:
	if node == null or terrain == null or not terrain.has_method("get_height"):
		return false

	var ground_y: float = terrain.call("get_height", node.global_position.x, node.global_position.z)
	node.global_position.y = ground_y + height_offset
	return true

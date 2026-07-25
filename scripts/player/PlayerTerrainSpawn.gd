class_name PlayerTerrainSpawn
extends Node

@export var terrain_path: NodePath
@export var spawn_height_offset: float = 1.0


func _ready() -> void:
	var body := get_parent() as Node3D
	if body == null:
		return

	_apply_pending_spawn_point(body)

	var terrain := get_node_or_null(terrain_path)
	if terrain != null and terrain.has_method("get_height"):
		var ground_y: float = terrain.call("get_height", body.global_position.x, body.global_position.z)
		body.global_position.y = ground_y + spawn_height_offset


func _apply_pending_spawn_point(body: Node3D) -> void:
	var pending := SaveManager.consume_pending_spawn()
	if pending.is_empty():
		return

	var spawn_id: String = pending.get("spawn_point", "")
	if spawn_id.is_empty():
		return

	var save_point := _find_save_point(spawn_id)
	if save_point != null:
		body.global_position = save_point.global_position
	else:
		push_warning("PlayerTerrainSpawn: no SavePoint found for id '%s'" % spawn_id)


func _find_save_point(spawn_id: String) -> Node3D:
	for node in get_tree().get_nodes_in_group("save_points"):
		if node is Node3D and node.get("save_point_id") == spawn_id:
			return node
	return null

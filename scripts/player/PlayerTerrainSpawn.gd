class_name PlayerTerrainSpawn
extends Node

@export var terrain_path: NodePath
@export var spawn_height_offset: float = 1.0


func _ready() -> void:
	var body := get_parent() as Node3D
	if body == null:
		return

	var terrain := get_node_or_null(terrain_path)
	if terrain != null and terrain.has_method("get_height"):
		var ground_y: float = terrain.call("get_height", body.global_position.x, body.global_position.z)
		body.global_position.y = ground_y + spawn_height_offset

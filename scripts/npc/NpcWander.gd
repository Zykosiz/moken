class_name NpcWander
extends Node

@export var enabled: bool = false
@export var waypoint_paths: Array[NodePath] = []
@export var wait_time_range: Vector2 = Vector2(1.5, 3.5)
@export var loop: bool = true
@export var arrival_distance: float = 0.75

var _npc: NpcBase
var _waypoints: Array[Node3D] = []
var _current_index := -1
var _wait_remaining := 0.0


func _ready() -> void:
	_npc = get_parent() as NpcBase
	for path in waypoint_paths:
		var waypoint := get_node_or_null(path) as Node3D
		if waypoint != null:
			_waypoints.append(waypoint)

	if enabled and _waypoints.size() > 0:
		_go_to_next_waypoint()


func _process(delta: float) -> void:
	if not enabled or _npc == null or _waypoints.is_empty():
		return

	if _wait_remaining > 0.0:
		_wait_remaining -= delta
		if _wait_remaining <= 0.0:
			_go_to_next_waypoint()
		return

	if not _npc.navigation_enabled:
		_wait_remaining = randf_range(wait_time_range.x, wait_time_range.y)


func _go_to_next_waypoint() -> void:
	if _waypoints.is_empty():
		return
	_current_index += 1
	if _current_index >= _waypoints.size():
		if not loop:
			enabled = false
			return
		_current_index = 0

	var waypoint_position: Vector3 = _waypoints[_current_index].global_position
	if _npc.global_position.distance_to(waypoint_position) <= arrival_distance:
		_wait_remaining = 0.05
		return

	_npc.set_destination(waypoint_position)

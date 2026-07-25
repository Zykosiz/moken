class_name PlayerInteractor
extends Node

const INTERACT_ACTION := &"interact"

@export var interaction_area_path: NodePath = ^"InteractionArea"

@onready var interaction_area: Area3D = get_node(interaction_area_path)

var _nearby_interactables: Array[Area3D] = []


func _ready() -> void:
	if interaction_area != null:
		interaction_area.area_entered.connect(_on_area_entered)
		interaction_area.area_exited.connect(_on_area_exited)


func _unhandled_input(event: InputEvent) -> void:
	if DialogueManager.is_active:
		return
	if event.is_action_pressed(INTERACT_ACTION):
		_try_interact()


func _try_interact() -> void:
	var target := _get_nearest_interactable()
	if target == null:
		return
	if target.has_method("interact"):
		target.call("interact", get_parent())


func _get_nearest_interactable() -> Area3D:
	_nearby_interactables = _nearby_interactables.filter(func(a: Area3D) -> bool: return is_instance_valid(a))
	if _nearby_interactables.is_empty():
		return null

	var actor := get_parent() as Node3D
	if actor == null:
		return _nearby_interactables[0]

	var nearest: Area3D = _nearby_interactables[0]
	var nearest_distance := actor.global_position.distance_squared_to(nearest.global_position)
	for area in _nearby_interactables:
		var distance := actor.global_position.distance_squared_to(area.global_position)
		if distance < nearest_distance:
			nearest = area
			nearest_distance = distance
	return nearest


func _on_area_entered(area: Area3D) -> void:
	if not area.has_method("interact"):
		return
	if not _nearby_interactables.has(area):
		_nearby_interactables.append(area)


func _on_area_exited(area: Area3D) -> void:
	_nearby_interactables.erase(area)

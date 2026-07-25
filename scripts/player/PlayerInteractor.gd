class_name PlayerInteractor
extends Node

const INTERACT_ACTION := &"interact"
const MAX_RESOLVE_DEPTH := 6

@export var interaction_area_path: NodePath = ^"InteractionArea"

@onready var interaction_area: Area3D = get_node(interaction_area_path)

## Resolved interactable targets (not the raw Area3D — see _resolve_interactable).
var _nearby_interactables: Array[Node3D] = []
var _area_to_target: Dictionary = {}


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


func _get_nearest_interactable() -> Node3D:
	_nearby_interactables = _nearby_interactables.filter(func(n: Node3D) -> bool: return is_instance_valid(n))
	if _nearby_interactables.is_empty():
		return null

	var actor := get_parent() as Node3D
	if actor == null:
		return _nearby_interactables[0]

	var nearest: Node3D = _nearby_interactables[0]
	var nearest_distance := actor.global_position.distance_squared_to(nearest.global_position)
	for target in _nearby_interactables:
		var distance := actor.global_position.distance_squared_to(target.global_position)
		if distance < nearest_distance:
			nearest = target
			nearest_distance = distance
	return nearest


func _on_area_entered(area: Area3D) -> void:
	var target := _resolve_interactable(area)
	if target == null:
		return
	_area_to_target[area] = target
	if not _nearby_interactables.has(target):
		_nearby_interactables.append(target)


func _on_area_exited(area: Area3D) -> void:
	var target = _area_to_target.get(area)
	if target != null:
		_area_to_target.erase(area)
		_nearby_interactables.erase(target)


## An interactable's interact() may live on the detected Area3D itself
## (e.g. SavePoint) or on an ancestor (e.g. NpcBase, whose InteractionArea
## is a plain scriptless Area3D child of the CharacterBody3D that owns
## interact()). Walk up until something answers to it, rather than only
## checking the area directly — this covers both cases, and any future
## interactable regardless of how deep its script sits, with one code path.
func _resolve_interactable(area: Area3D) -> Node3D:
	var node: Node = area
	var depth := 0
	while node != null and depth < MAX_RESOLVE_DEPTH:
		if node.has_method("interact"):
			return node as Node3D
		node = node.get_parent()
		depth += 1
	return null

class_name NpcBase
extends CharacterBody3D

signal interaction_available(npc: NpcBase, body: Node3D)
signal interaction_unavailable(npc: NpcBase, body: Node3D)
signal interacted(npc: NpcBase, actor: Node)

@export var display_name: String = "NPC"
@export var can_interact: bool = true
@export var idle_animation: StringName = &"idle"
@export var idle_variant: StringName = &"default"
@export var movement_speed: float = 1.8
@export var current_destination: Vector3 = Vector3.ZERO
@export var navigation_enabled: bool = false
@export var use_navigation_agent_path: bool = false
@export var face_player_during_interaction: bool = true
@export var terrain_path: NodePath
@export var terrain_height_offset: float = 1.0
@export var gravity: float = 20.0
@export var acceleration: float = 12.0
@export var turn_speed: float = 10.0
@export var body_color: Color = Color(1.0, 0.396, 0.0, 1.0)
@export var debug_interactions: bool = false
@export var dialogue_sequence: DialogueSequence

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual_root: Node3D = $VisualRoot
@onready var rig: HumanoidRig = $VisualRoot/HumanoidRig
@onready var interaction_area: Area3D = $InteractionArea

var _interaction_target: Node3D


func _ready() -> void:
	if interaction_area != null:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)

	if rig != null:
		if rig.get_animation_tree() != null:
			rig.set_body_color(body_color)
		else:
			rig.rig_ready.connect(func() -> void: rig.set_body_color(body_color))

	call_deferred("_snap_to_terrain")
	if navigation_enabled and current_destination != Vector3.ZERO:
		set_destination(current_destination)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.2

	var desired_horizontal_velocity := Vector3.ZERO
	if navigation_enabled:
		desired_horizontal_velocity = _get_navigation_velocity()

	velocity.x = move_toward(velocity.x, desired_horizontal_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired_horizontal_velocity.z, acceleration * delta)

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal_velocity.length() > 0.05:
		_face_direction(horizontal_velocity.normalized(), delta)
	elif face_player_during_interaction and _interaction_target != null:
		_face_direction(_interaction_target.global_position - global_position, delta)

	move_and_slide()


func set_destination(destination: Vector3) -> void:
	current_destination = _terrain_adjusted_position(destination)
	navigation_enabled = true
	if navigation_agent != null:
		navigation_agent.target_position = current_destination


func stop_navigation() -> void:
	navigation_enabled = false
	velocity.x = 0.0
	velocity.z = 0.0


func interact(actor: Node = null) -> void:
	if not can_interact:
		return
	if debug_interactions:
		print("%s interacted with %s" % [actor.name if actor != null else "Someone", display_name])
	interacted.emit(self, actor)
	if dialogue_sequence != null:
		DialogueManager.play_sequence(dialogue_sequence)


func _get_navigation_velocity() -> Vector3:
	if global_position.distance_to(current_destination) <= 0.6:
		stop_navigation()
		return Vector3.ZERO

	var next_position := current_destination
	if use_navigation_agent_path and navigation_agent != null:
		var agent_next: Vector3 = navigation_agent.get_next_path_position()
		var agent_direction: Vector3 = agent_next - global_position
		agent_direction.y = 0.0
		if agent_next != Vector3.ZERO and agent_direction.length() > 0.1:
			next_position = agent_next

	var direction := next_position - global_position
	direction.y = 0.0
	if direction.length() <= 0.1:
		return Vector3.ZERO
	return direction.normalized() * movement_speed


func _snap_to_terrain() -> void:
	var terrain := _get_terrain()
	if terrain != null:
		TerrainPlacement.place_on_terrain(self, terrain, terrain_height_offset)


func _terrain_adjusted_position(position: Vector3) -> Vector3:
	var terrain := _get_terrain()
	if terrain != null and terrain.has_method("get_height"):
		position.y = terrain.call("get_height", position.x, position.z) + terrain_height_offset
	return position


func _get_terrain() -> Node:
	if terrain_path.is_empty():
		return null
	return get_node_or_null(terrain_path)


func _face_direction(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	var target_yaw := atan2(direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clamp(turn_speed * delta, 0.0, 1.0))


func _on_interaction_area_body_entered(body: Node3D) -> void:
	if not can_interact or body == self:
		return
	_interaction_target = body
	if debug_interactions:
		print("%s can interact with %s" % [body.name, display_name])
	interaction_available.emit(self, body)


func _on_interaction_area_body_exited(body: Node3D) -> void:
	if body == _interaction_target:
		_interaction_target = null
	if not can_interact or body == self:
		return
	interaction_unavailable.emit(self, body)

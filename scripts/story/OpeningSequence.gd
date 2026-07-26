extends Node

## Drives Moken's opening vertical-slice sequence, Beats 1-5 (wake-up through
## Halvard's interrupted philosophy speech). See docs/OPENING_SCENE.md.
##
## Beats 1 and 2 are fully cinematic (player frozen, black-screen dialogue).
## Beat 2 ends with Vyla saying she'll wait at the village center. The player
## then gets completely normal free control — nothing scripted — until they
## walk up and interact with Vyla themselves (the same NpcBase/PlayerInteractor
## path every other NPC already uses). That triggers her conversation
## (dialogue_sequence assigned directly on her, played the normal frozen way).
## Only once that finishes does she set off for the lighthouse and Zako's
## automatic follow-mode kick in for the final leg, with the last few lines
## of the conversation playing non-frozen during that walk.
##
## The follow-mode itself (character.gd's own _physics_process disabled,
## this script driving velocity/gravity/move_and_slide() directly, feeding
## animation.gd a constant input_dir so it keeps blending the walk cycle)
## survived two earlier failed approaches — see git history on this file if
## the "why not simpler" question comes up again. Movement velocity is
## derived from the character's own *smoothed facing* (after the turn-rate-
## limited rotation), not the raw target direction, specifically so the body
## never moves in a direction its facing hasn't caught up to yet (that
## mismatch is what read as sidestepping/crab-walking before).
##
## Beats 6+ (pirate attack, Horror) need cutscene tooling that doesn't exist
## yet and are intentionally not started here.

const NPC_VYLA_SCENE: PackedScene = preload("res://Scenes/Characters/NPC/NpcVyla.tscn")
const OPENING_SEEN_FLAG := "opening_sequence_seen"
const AUTO_ADVANCE_DELAY := 1.8
const ARRIVAL_RADIUS := 5.0
const FOLLOW_TRAIL_DISTANCE := 2.2
const WALK_SPEED := 3.2
const WALK_ACCELERATION := 12.0
const TURN_SPEED := 8.0
const GRAVITY := 20.0
const VYLA_EXIT_OFFSET := Vector3(-6.0, 0.0, -4.0)
const VYLA_EXIT_DELAY := 3.5
const ZAKO_HOUSE_SPAWN_OFFSET := 6.0

@export var player_path: NodePath
@export var halvard_path: NodePath
@export var zako_house_path: NodePath
@export var village_heart_path: NodePath
@export var terrain_path: NodePath

@export_group("Dialogue")
@export var beat1_sequence: DialogueSequence
@export var beat2_sequence: DialogueSequence
@export var beat3_conversation: DialogueSequence
@export var beat3_walk_d: DialogueSequence
@export var beat4_sequence: DialogueSequence
@export var beat5_sequence: DialogueSequence

@onready var _black_overlay: CanvasLayer = $BlackOverlay

var _following: bool = false
var _follow_player: CharacterBody3D
var _follow_vyla: NpcBase
var _follow_mesh: Node3D


func _ready() -> void:
	if SaveManager.get_flag(OPENING_SEEN_FLAG, false):
		_black_overlay.visible = false
		return
	SaveManager.set_flag(OPENING_SEEN_FLAG, true)
	call_deferred("_run_sequence")


func _physics_process(delta: float) -> void:
	if not _following:
		return

	var player := _follow_player
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
	elif player.velocity.y < 0.0:
		player.velocity.y = -0.2

	var target := _follow_target_position(_follow_vyla)
	var to_target := target - player.global_position
	to_target.y = 0.0
	var moving := to_target.length() > 0.1

	if moving and _follow_mesh != null:
		var target_yaw := atan2(to_target.x, -to_target.z)
		var turn := clampf(TURN_SPEED * delta, 0.0, 1.0)
		_follow_mesh.rotation.y = lerp_angle(_follow_mesh.rotation.y, target_yaw, turn)

	# Velocity follows the body's own current facing (set above), not the raw
	# target direction -- otherwise the body can move one way while still
	# visually angled another whenever the target direction changes faster
	# than the turn rate can catch up, which reads as a sidestep/crab-walk.
	var desired := Vector3.ZERO
	if moving and _follow_mesh != null:
		var facing_yaw := _follow_mesh.rotation.y
		desired = Vector3(sin(facing_yaw), 0.0, -cos(facing_yaw)) * WALK_SPEED

	player.velocity.x = move_toward(player.velocity.x, desired.x, WALK_ACCELERATION * delta)
	player.velocity.z = move_toward(player.velocity.z, desired.z, WALK_ACCELERATION * delta)
	player.move_and_slide()

	player.input_dir = Vector2(0.0, -1.0) if desired.length() > 0.05 else Vector2.ZERO
	player.is_walking = true


func _run_sequence() -> void:
	var player := get_node_or_null(player_path) as Node3D
	var halvard := get_node_or_null(halvard_path) as Node3D
	var zako_house := get_node_or_null(zako_house_path) as Node3D
	var village_heart := get_node_or_null(village_heart_path) as Node3D
	var terrain := get_node_or_null(terrain_path)

	if player == null or halvard == null or zako_house == null or village_heart == null or terrain == null:
		push_warning("OpeningSequence: missing a required node reference; aborting opening sequence.")
		_black_overlay.visible = false
		return

	_black_overlay.visible = true

	DialogueManager.play_sequence(beat1_sequence, AUTO_ADVANCE_DELAY)
	await DialogueManager.dialogue_finished

	DialogueManager.play_sequence(beat2_sequence, AUTO_ADVANCE_DELAY)
	await DialogueManager.dialogue_finished

	_black_overlay.visible = false
	var spawn_point := _spawn_point_outside_house(zako_house, village_heart)
	_teleport_to(player, terrain, spawn_point)

	# Vyla waits at the village center -- player has completely normal free
	# control from here until they walk up and interact with her themselves.
	var vyla := _spawn_vyla(village_heart.global_position, terrain)
	vyla.dialogue_sequence = beat3_conversation
	vyla.can_interact = true

	await vyla.interacted
	await DialogueManager.dialogue_finished

	vyla.can_interact = false
	vyla.set_destination(halvard.global_position)
	_start_following(player, vyla)

	DialogueManager.play_sequence(beat3_walk_d, AUTO_ADVANCE_DELAY, false)
	await DialogueManager.dialogue_finished

	while player.global_position.distance_to(halvard.global_position) > ARRIVAL_RADIUS:
		await get_tree().process_frame

	_stop_following()

	DialogueManager.play_sequence(beat4_sequence, AUTO_ADVANCE_DELAY)
	await DialogueManager.dialogue_finished

	vyla.set_destination(vyla.global_position + VYLA_EXIT_OFFSET)
	await get_tree().create_timer(VYLA_EXIT_DELAY).timeout
	vyla.queue_free()

	DialogueManager.play_sequence(beat5_sequence, AUTO_ADVANCE_DELAY)
	await DialogueManager.dialogue_finished

	# TODO(beat6): pirate attack interrupts Halvard here — see docs/OPENING_SCENE.md Beat 6+.


## Point directly behind Vyla, trailing toward wherever she's currently
## headed. Deliberately not a point beside her — targeting a lateral offset
## made the player's facing swing sideways to look at her as he closed in on
## it. Also deliberately not derived from her live velocity — that's noisy
## whenever she's blocked/shoved by an obstacle (briefly points sideways or
## backward as she's redirected), and Zako's facing inherited that noise.
## current_destination only changes when this script calls set_destination()
## for the next leg, so it stays stable regardless of her instantaneous
## movement. They don't need to look at each other for this pass.
func _follow_target_position(vyla: NpcBase) -> Vector3:
	var travel_dir := vyla.current_destination - vyla.global_position
	travel_dir.y = 0.0
	if travel_dir.length() < 0.01:
		return vyla.global_position
	travel_dir = travel_dir.normalized()
	return vyla.global_position - travel_dir * FOLLOW_TRAIL_DISTANCE


## Hands the player's body over to this script's own _physics_process for
## the duration of the walk — character.gd's own per-frame input/gravity/
## rotation/move_and_slide() is disabled so nothing fights the world-space
## movement driven here.
func _start_following(player: Node3D, vyla: NpcBase) -> void:
	var body := player as CharacterBody3D
	_follow_player = body
	_follow_vyla = vyla
	_follow_mesh = body.get("character") as Node3D
	body.frozen = false
	body.velocity = Vector3.ZERO
	body.set_physics_process(false)
	_following = true


func _stop_following() -> void:
	_following = false
	if _follow_player != null:
		_follow_player.velocity.x = 0.0
		_follow_player.velocity.z = 0.0
		_follow_player.input_dir = Vector2.ZERO
		_follow_player.is_walking = false
		_follow_player.set_physics_process(true)
	_follow_player = null
	_follow_vyla = null
	_follow_mesh = null


## zako_house is the actual house model (real collision), not an empty
## marker — spawning at its exact center used to drop the player inside its
## walls, which caused falling-through-the-floor physics glitches. Offset
## toward the village instead, so the player starts in open ground already
## facing roughly the right direction to go find Vyla.
func _spawn_point_outside_house(zako_house: Node3D, village_heart: Node3D) -> Vector3:
	var direction := village_heart.global_position - zako_house.global_position
	direction.y = 0.0
	if direction.length() < 0.01:
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()
	return zako_house.global_position + direction * ZAKO_HOUSE_SPAWN_OFFSET


func _spawn_vyla(spawn_position: Vector3, terrain: Node) -> NpcBase:
	var vyla := NPC_VYLA_SCENE.instantiate() as NpcBase
	get_tree().current_scene.add_child(vyla)
	vyla.global_position = spawn_position
	vyla.terrain_path = vyla.get_path_to(terrain)
	return vyla


func _teleport_to(body: Node3D, terrain: Node, target: Vector3) -> void:
	var y := target.y
	if terrain.has_method("get_height"):
		y = terrain.call("get_height", target.x, target.z) + 1.0
	body.global_position = Vector3(target.x, y, target.z)

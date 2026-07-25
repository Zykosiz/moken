extends Node

## Drives Moken's opening vertical-slice sequence, Beats 1-5 (wake-up through
## Halvard's interrupted philosophy speech). See docs/OPENING_SCENE.md.
##
## Beats 1, 2, 4, 5 are fully cinematic: the player is frozen, dialogue box
## open. Beat 3 walks the player automatically alongside Vyla — not player
## input. Two earlier approaches broke:
## - Driving global_position directly bypasses velocity/move_and_slide()
##   entirely, so nothing animated and nothing collided with the ground.
## - Simulating real input (holding "forward" while steering camera_pivot)
##   fixed the animation (addons/real-controller/animation.gd blends off
##   player.input_dir, not velocity/position) but routed movement through
##   character.gd's camera-relative direction math, which has a sign/
##   orientation bug that sent the player the wrong way.
## This version drives the player directly in world space, like an NPC,
## while still getting a real animated walk: character.gd's own
## _physics_process is disabled for the duration (nothing left fighting an
## externally-set velocity), this script applies simple gravity, moves
## velocity toward a world-space target and calls move_and_slide() itself,
## rotates the visible mesh child to face the travel direction (the same
## atan2(direction.x, -direction.z) formula NpcBase._face_direction already
## uses), and sets player.input_dir/is_walking to a constant "walking"
## value so animation.gd — left completely untouched, still running its own
## _process() — keeps blending the walk cycle exactly like it would from
## real input.
##
## Vyla walks via her own NpcBase.set_destination() navigation (unchanged,
## already proven correct — same system driving the other 7 world NPCs),
## routed through the VillageHeart anchor rather than straight at the
## lighthouse so she doesn't cut through ResidentialSlopes' terrace walls.
## The player continuously targets a point trailing directly behind her, so
## he reads as following her rather than facing/looking at her — no need
## for them to look at each other for this pass, that's for the portraits
## to carry later. Dialogue auto-advances so nothing can stall.
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

@export var player_path: NodePath
@export var halvard_path: NodePath
@export var zako_house_path: NodePath
@export var village_heart_path: NodePath
@export var terrain_path: NodePath

@export_group("Dialogue")
@export var beat1_sequence: DialogueSequence
@export var beat2_sequence: DialogueSequence
@export var beat3_walk_a: DialogueSequence
@export var beat3_walk_b: DialogueSequence
@export var beat3_walk_c: DialogueSequence
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

	var desired := Vector3.ZERO
	if to_target.length() > 0.1:
		desired = to_target.normalized() * WALK_SPEED

	player.velocity.x = move_toward(player.velocity.x, desired.x, WALK_ACCELERATION * delta)
	player.velocity.z = move_toward(player.velocity.z, desired.z, WALK_ACCELERATION * delta)
	player.move_and_slide()

	player.input_dir = Vector2(0.0, -1.0) if desired.length() > 0.05 else Vector2.ZERO
	player.is_walking = true

	if to_target.length_squared() > 0.01 and _follow_mesh != null:
		var target_yaw := atan2(to_target.x, -to_target.z)
		var turn := clampf(TURN_SPEED * delta, 0.0, 1.0)
		_follow_mesh.rotation.y = lerp_angle(_follow_mesh.rotation.y, target_yaw, turn)


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
	_teleport_to(player, terrain, zako_house.global_position)

	var vyla := _spawn_vyla(zako_house.global_position, terrain)
	await get_tree().process_frame
	vyla.set_destination(village_heart.global_position)

	_start_following(player, vyla)

	DialogueManager.play_sequence(beat3_walk_a, AUTO_ADVANCE_DELAY, false)
	await DialogueManager.dialogue_finished
	DialogueManager.play_sequence(beat3_walk_b, AUTO_ADVANCE_DELAY, false)
	await DialogueManager.dialogue_finished

	vyla.set_destination(halvard.global_position)

	DialogueManager.play_sequence(beat3_walk_c, AUTO_ADVANCE_DELAY, false)
	await DialogueManager.dialogue_finished
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
## whenever she's blocked/shoved by a slope (briefly points sideways or
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

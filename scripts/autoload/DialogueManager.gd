extends Node

## See docs/UI_FOUNDATION.md. Linear dialogue only — no branching. Owns the
## DialogueBox overlay, is the sole consumer of advance-input while active,
## and is the single source of truth for "is dialogue active" that other
## systems (PlayerInteractor) check to avoid double-triggering.

signal dialogue_started
signal dialogue_finished

const BOX_SCENE := preload("res://Scenes/UI/Screens/DialogueBox.tscn")

var is_active: bool = false

var _box: DialogueBox
var _sequence: DialogueSequence
var _current_index: int = -1
var _player: Node3D
var _freeze_player: bool = true
var _auto_advance_delay: float = 0.0
var _auto_advance_token: int = 0


func _ready() -> void:
	_box = BOX_SCENE.instantiate()
	add_child(_box)


## auto_advance_delay > 0 makes each line advance on its own after that many
## seconds of read time past the reveal finishing, so a fully scripted
## sequence (e.g. the opening) never stalls waiting on player input —
## pressing "interact" still skips ahead immediately as normal.
## freeze_player = false lets a sequence play out over real player movement
## (e.g. the opening's walk-and-talk beat) instead of pausing it.
func play_sequence(sequence: DialogueSequence, auto_advance_delay: float = 0.0, freeze_player: bool = true) -> void:
	if is_active or sequence == null or sequence.lines.is_empty():
		return

	_sequence = sequence
	_current_index = -1
	is_active = true
	_auto_advance_delay = auto_advance_delay
	_freeze_player = freeze_player

	_player = _find_player()
	if _player != null and _freeze_player:
		_player.frozen = true
	if _freeze_player:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_box.open()
	dialogue_started.emit()
	_advance_to_next_line()


func advance() -> void:
	if not is_active:
		return
	if _box.is_revealing():
		_box.complete_reveal()
		return
	_advance_to_next_line()


func _advance_to_next_line() -> void:
	_auto_advance_token += 1
	_current_index += 1
	if _current_index >= _sequence.lines.size():
		_finish()
		return
	var line: DialogueLine = _sequence.lines[_current_index]
	_box.show_line(line)
	if _auto_advance_delay > 0.0:
		_schedule_auto_advance(_auto_advance_token, line.text)


func _schedule_auto_advance(token: int, text: String) -> void:
	var reveal_time := 0.0
	if not UIAccessibility.reduced_motion:
		reveal_time = text.length() / DialogueBox.CHARACTERS_PER_SECOND
	await get_tree().create_timer(reveal_time + _auto_advance_delay).timeout
	if is_active and token == _auto_advance_token:
		advance()


func _finish() -> void:
	is_active = false
	_box.close()
	if _player != null and _freeze_player:
		_player.frozen = false
	_player = null
	_sequence = null
	_current_index = -1
	_auto_advance_token += 1
	dialogue_finished.emit()


## Called by anything about to change the current scene out from under a
## possibly-active dialogue (SaveManager.load_game, StartMenu's New Game) —
## drops all state and closes the box before the referenced Player/scene get
## freed, so we never touch a freed object and never leave PlayerInteractor
## permanently gated on a stuck is_active with no dialogue box visible.
func reset_for_scene_change() -> void:
	if is_active:
		is_active = false
		_box.close()
	_player = null
	_sequence = null
	_current_index = -1
	_auto_advance_token += 1


func _find_player() -> Node3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("Player") as Node3D


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event.is_action_pressed("interact"):
		advance()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advance()
		get_viewport().set_input_as_handled()

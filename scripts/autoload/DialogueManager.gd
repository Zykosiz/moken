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


func _ready() -> void:
	_box = BOX_SCENE.instantiate()
	add_child(_box)


func play_sequence(sequence: DialogueSequence) -> void:
	if is_active or sequence == null or sequence.lines.is_empty():
		return

	_sequence = sequence
	_current_index = -1
	is_active = true

	_player = _find_player()
	if _player != null:
		_player.frozen = true
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
	_current_index += 1
	if _current_index >= _sequence.lines.size():
		_finish()
		return
	_box.show_line(_sequence.lines[_current_index])


func _finish() -> void:
	is_active = false
	_box.close()
	if _player != null:
		_player.frozen = false
	_player = null
	_sequence = null
	_current_index = -1
	dialogue_finished.emit()


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

extends Control

## Minimal start menu: New Game and Load Game only. See docs/UI_FOUNDATION.md.

@onready var _new_game_button: GlassButton = $CenterContainer/VBoxContainer/NewGameButton
@onready var _load_game_button: GlassButton = $CenterContainer/VBoxContainer/LoadGameButton

var _load_slot: int = -1


func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_load_game_button.pressed.connect(_on_load_game_pressed)

	_load_slot = _find_most_recent_save_slot()
	_load_game_button.disabled = _load_slot < 0


func _on_new_game_pressed() -> void:
	var target_slot := _find_first_empty_slot()
	SaveManager.set_active_slot(target_slot)
	get_tree().change_scene_to_file.call_deferred("res://Scenes/World.tscn")


func _on_load_game_pressed() -> void:
	if _load_slot < 0:
		return
	SaveManager.load_game(_load_slot)


func _find_most_recent_save_slot() -> int:
	var best_slot := -1
	var best_timestamp := -1.0
	for slot in range(SaveManager.SLOT_COUNT):
		var meta := SaveManager.get_save_metadata(slot)
		if meta.is_empty():
			continue
		var timestamp: float = meta.get("timestamp_unix", 0)
		if timestamp > best_timestamp:
			best_timestamp = timestamp
			best_slot = slot
	return best_slot


func _find_first_empty_slot() -> int:
	for slot in range(SaveManager.SLOT_COUNT):
		if not SaveManager.has_save(slot):
			return slot
	return 0

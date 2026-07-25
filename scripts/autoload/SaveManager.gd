extends Node

signal game_saved(slot: int)
signal game_loaded(slot: int)
signal flag_changed(flag_name: String, value: Variant)

const SAVE_DIR := "user://saves/"
const SLOT_COUNT := 3
const SAVE_VERSION := 1

var active_slot: int = 0
var flags: Dictionary = {}
var inventory: Dictionary = {}      # reserved, unused for now
var world_state: Dictionary = {}    # reserved, unused for now

var _pending_scene_path: String = ""
var _pending_spawn_point: String = ""


func _ready() -> void:
	_ensure_save_dir()


func set_flag(flag_name: String, value: Variant = true) -> void:
	flags[flag_name] = value
	flag_changed.emit(flag_name, value)


func get_flag(flag_name: String, default_value: Variant = false) -> Variant:
	return flags.get(flag_name, default_value)


func has_flag(flag_name: String) -> bool:
	return flags.has(flag_name)


func clear_flag(flag_name: String) -> void:
	if flags.has(flag_name):
		flags.erase(flag_name)
		flag_changed.emit(flag_name, false)


func set_active_slot(slot: int) -> void:
	if slot < 0 or slot >= SLOT_COUNT:
		push_warning("SaveManager: slot %d out of range (0..%d)" % [slot, SLOT_COUNT - 1])
		return
	active_slot = slot


func save_game(save_point_id: String, slot: int = -1) -> bool:
	var target_slot := active_slot if slot < 0 else slot
	if target_slot < 0 or target_slot >= SLOT_COUNT:
		push_warning("SaveManager: cannot save to out-of-range slot %d" % target_slot)
		return false

	var current_scene := get_tree().current_scene
	if current_scene == null:
		push_warning("SaveManager: no current_scene, cannot save")
		return false

	var data := {
		"save_version": SAVE_VERSION,
		"timestamp_unix": Time.get_unix_time_from_system(),
		"player": {
			"scene_path": current_scene.scene_file_path,
			"spawn_point": save_point_id,
		},
		"flags": flags.duplicate(true),
		"inventory": inventory.duplicate(true),
		"world_state": world_state.duplicate(true),
	}

	_ensure_save_dir()
	var file := FileAccess.open(_slot_path(target_slot), FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: failed to open save file for writing (slot %d)" % target_slot)
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	game_saved.emit(target_slot)
	return true


func load_game(slot: int) -> bool:
	if not has_save(slot):
		push_warning("SaveManager: no save in slot %d" % slot)
		return false

	var data := _read_slot(slot)
	if data.is_empty():
		return false

	# Validate fully before mutating any state — a corrupt/incomplete save
	# must leave the currently-running session untouched, not half-apply.
	var player_data: Dictionary = data.get("player", {})
	var scene_path: String = player_data.get("scene_path", "")
	if scene_path.is_empty():
		push_warning("SaveManager: save file slot %d has no scene_path, refusing to load" % slot)
		return false

	active_slot = slot
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	inventory = (data.get("inventory", {}) as Dictionary).duplicate(true)
	world_state = (data.get("world_state", {}) as Dictionary).duplicate(true)
	_pending_scene_path = scene_path
	_pending_spawn_point = player_data.get("spawn_point", "")

	# A dialogue could conceivably still be active from whatever scene we're
	# loading away from — reset it before the scene it references gets freed.
	DialogueManager.reset_for_scene_change()

	# Deferred: change_scene_to_file() can't run safely if load_game() was
	# itself called from a node's _ready() or an input/signal callback while
	# the tree is still busy adding/removing children. Return value here means
	# "load was initiated successfully," not "scene change has completed."
	get_tree().change_scene_to_file.call_deferred(_pending_scene_path)
	game_loaded.emit(slot)
	return true


func reset_session_state() -> void:
	flags.clear()
	inventory.clear()
	world_state.clear()
	_pending_scene_path = ""
	_pending_spawn_point = ""


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func delete_save(slot: int) -> bool:
	if not has_save(slot):
		return false
	return DirAccess.remove_absolute(_slot_path(slot)) == OK


func get_save_metadata(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var data := _read_slot(slot)
	if data.is_empty():
		return {}
	var player_data: Dictionary = data.get("player", {})
	return {
		"save_version": data.get("save_version", 0),
		"timestamp_unix": data.get("timestamp_unix", 0),
		"scene_path": player_data.get("scene_path", ""),
		"spawn_point": player_data.get("spawn_point", ""),
	}


func consume_pending_spawn() -> Dictionary:
	if _pending_scene_path.is_empty() and _pending_spawn_point.is_empty():
		return {}
	var result := {
		"scene_path": _pending_scene_path,
		"spawn_point": _pending_spawn_point,
	}
	_pending_scene_path = ""
	_pending_spawn_point = ""
	return result


func _slot_path(slot: int) -> String:
	return "%sslot_%d.json" % [SAVE_DIR, slot]


func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _read_slot(slot: int) -> Dictionary:
	var file := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: save file slot %d is not valid JSON object" % slot)
		return {}
	return parsed

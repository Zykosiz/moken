@tool
extends EditorScript

# One-time batch extraction: walks every model under Assets/Kenney and
# Assets/Quaternius, pulls each mesh surface's material directly (bypassing
# Godot's Advanced Import Settings "Extract Materials" action, which is an
# interactive one-shot UI operation, not something a reimport can trigger
# automatically), and saves each unique inline material as a standalone
# .tres co-located with its source model.
#
# Run via: open this file in the Script Editor, then File > Run (or the
# "Run" toolbar button / Ctrl+Shift+X for EditorScripts).
#
# Safe to re-run: if a target .tres already exists on disk, that material is
# left untouched (whatever roughness/metallic/normal edits were made to it
# are preserved) rather than being overwritten.

const ROOTS := ["res://Assets/Kenney", "res://Assets/Quaternius"]
const MODEL_EXTENSIONS := ["glb", "gltf", "fbx", "blend"]

var _scanned_count := 0
var _extracted_count := 0
var _already_extracted_count := 0
var _skipped_count := 0
var _log: Array[String] = []


func _run() -> void:
	for root in ROOTS:
		_scan_dir(root)

	var log_path := "res://materials_extraction_log.txt"
	var f := FileAccess.open(log_path, FileAccess.WRITE)
	for line in _log:
		f.store_line(line)
	f.close()

	print("Models scanned: %d" % _scanned_count)
	print("Materials newly extracted: %d" % _extracted_count)
	print("Materials already extracted (skipped, left untouched): %d" % _already_extracted_count)
	print("Meshes/surfaces skipped (no material): %d" % _skipped_count)
	print("Full log written to: %s" % log_path)

	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()


func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		_log.append("ERROR: could not open directory %s" % path)
		return
	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "":
		if entry_name in [".", ".."]:
			entry_name = dir.get_next()
			continue
		var full := path.path_join(entry_name)
		if dir.current_is_dir():
			_scan_dir(full)
		else:
			var ext := entry_name.get_extension().to_lower()
			if ext in MODEL_EXTENSIONS:
				_process_model(full)
		entry_name = dir.get_next()
	dir.list_dir_end()


func _process_model(model_path: String) -> void:
	_scanned_count += 1
	var packed = load(model_path)
	if packed == null or not (packed is PackedScene):
		_log.append("SKIP (failed to load as PackedScene): %s" % model_path)
		return
	var instance: Node = packed.instantiate()
	if instance == null:
		_log.append("SKIP (failed to instantiate): %s" % model_path)
		return

	var seen_materials: Dictionary = {}
	_process_node(instance, model_path, seen_materials)
	instance.free()


func _process_node(node: Node, model_path: String, seen_materials: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var mesh: Mesh = node.mesh
		for i in mesh.get_surface_count():
			var mat: Material = node.get_active_material(i)
			if mat == null:
				_skipped_count += 1
				continue
			if mat.resource_path.ends_with(".tres") or mat.resource_path.ends_with(".res"):
				# Already a real standalone resource file (previously
				# extracted, or a shared/override material someone assigned
				# manually). Generated/embedded materials from glTF imports
				# get a non-empty but synthetic path like
				# "res://model.gltf::StandardMaterial3D_xxxx" -- that does
				# NOT count as extracted, so we don't just check is_empty().
				continue
			if seen_materials.has(mat):
				continue
			_extract_material(mat, model_path, node, mesh, i, seen_materials)
	for child in node.get_children():
		_process_node(child, model_path, seen_materials)


func _sanitize(s: String) -> String:
	var out := s
	for bad in [" ", "/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		out = out.replace(bad, "_")
	return out


func _extract_material(mat: Material, model_path: String, mesh_node: Node, mesh: Mesh, surface_index: int, seen_materials: Dictionary) -> void:
	var dir := model_path.get_base_dir()
	var base_name := model_path.get_file().get_basename()

	var mat_name := mat.resource_name
	if mat_name.is_empty():
		mat_name = mesh.surface_get_name(surface_index)
	if mat_name.is_empty():
		mat_name = "%s_surface%d" % [mesh_node.name, surface_index]

	var target := "%s/%s_%s.tres" % [dir, base_name, _sanitize(mat_name)]

	if ResourceLoader.exists(target):
		_already_extracted_count += 1
		seen_materials[mat] = target
		return

	var counter := 1
	var final_target := target
	while ResourceLoader.exists(final_target):
		final_target = "%s/%s_%s_%d.tres" % [dir, base_name, _sanitize(mat_name), counter]
		counter += 1

	var err := ResourceSaver.save(mat, final_target)
	if err == OK:
		seen_materials[mat] = final_target
		_extracted_count += 1
		_log.append("OK: %s  [surface %d: %s]  -> %s" % [model_path, surface_index, mat_name, final_target])
	else:
		_log.append("FAIL (error %d): %s [surface %d: %s]" % [err, model_path, surface_index, mat_name])

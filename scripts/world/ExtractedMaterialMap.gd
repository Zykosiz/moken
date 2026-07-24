class_name ExtractedMaterialMap
extends RefCounted

## Looks up the standalone .tres material extracted by
## tools/extract_kenney_quaternius_materials.gd for a given (source model
## path, surface index) pair, using materials_extraction_log.txt as the
## ground-truth mapping recorded at extraction time.
##
## Name-matching the extracted files' own naming convention at runtime would
## be fragile (name collisions within a model get a "_1", "_2" suffix during
## extraction), so this reads the exact mapping the extraction script itself
## wrote down instead of re-deriving it.

const LOG_PATH := "res://materials_extraction_log.txt"

static var _map: Dictionary = {}
static var _loaded: bool = false
static var _log_re: RegEx


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true

	if not FileAccess.file_exists(LOG_PATH):
		push_warning("ExtractedMaterialMap: %s not found; extracted materials will not be wired in." % LOG_PATH)
		return

	_log_re = RegEx.new()
	_log_re.compile(r"^OK:\s+(.+?)\s+\[surface\s+(\d+):[^\]]*\]\s+->\s+(.+)$")

	var f := FileAccess.open(LOG_PATH, FileAccess.READ)
	while not f.eof_reached():
		var line := f.get_line()
		var m := _log_re.search(line)
		if m == null:
			continue
		var model_path := m.get_string(1)
		var surface_index := int(m.get_string(2))
		var tres_path := m.get_string(3)
		_map["%s|%d" % [model_path, surface_index]] = tres_path
	f.close()


static func get_material_for(model_path: String, surface_index: int) -> Material:
	_ensure_loaded()
	var key := "%s|%d" % [model_path, surface_index]
	if not _map.has(key):
		return null
	var tres_path: String = _map[key]
	if not ResourceLoader.exists(tres_path):
		return null
	return load(tres_path) as Material


## Rewires every surface of `mesh` (as loaded from `model_path`) to use its
## extracted standalone material where the extraction log has one recorded;
## surfaces with no match keep whatever material they already had (the
## original embedded one). Mutates `mesh` directly -- callers that need an
## independent copy (e.g. because they're also modifying geometry, like
## RockLayer's normal-smoothing) should rewire their own private copy, not
## a shared/cached one.
static func rewire_mesh(mesh: Mesh, model_path: String) -> void:
	if mesh == null:
		return
	for i in mesh.get_surface_count():
		var extracted := get_material_for(model_path, i)
		if extracted != null:
			mesh.surface_set_material(i, extracted)


## Walks a node tree (e.g. a freshly instantiated model scene) and rewires
## every MeshInstance3D's mesh surfaces the same way as rewire_mesh(). All
## descendants are assumed to originate from the same `model_path`, which
## holds for every current Layout/Island wrapper scene (each instances
## exactly one raw model file).
static func rewire_tree(node: Node, model_path: String) -> void:
	if node is MeshInstance3D and node.mesh != null:
		rewire_mesh(node.mesh, model_path)
	for child in node.get_children():
		rewire_tree(child, model_path)

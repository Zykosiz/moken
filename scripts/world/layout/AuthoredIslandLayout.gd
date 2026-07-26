@tool
class_name AuthoredIslandLayout
extends Node3D

## Top-level coordinator for procedural island layout generation. Creates the
## category-root nodes and computes district anchor positions, then delegates
## to the focused generator scripts in scripts/world/layout/: DistrictLayout,
## PathLayout, GameplayAnchorLayout, NpcLayout (all backed by the shared
## PlacementPrimitives toolkit). See those files for what each category
## actually places — this script only orchestrates.
##
## NPCs are placed into an "NPCs" child node that _clear() below explicitly
## spares (everything else gets wiped and rebuilt every time, as before).
## NpcLayout's placement into it is idempotent (add-missing-only), so
## hand-authored NPC data (dialogue_sequence, etc.) survives every
## regenerate/reload instead of being wiped along with everything else.
## (An earlier version of this tried making NPCs a sibling under this node's
## parent instead — that requires mutating the parent's children from within
## this node's own _ready(), which races Godot's scene setup and throws
## "Parent node is busy" / "Invalid owner" errors. Keeping it a spared child
## of this node avoids that entirely.)

const DISTRICT_LAYOUT: GDScript = preload("res://scripts/world/layout/DistrictLayout.gd")
const PATH_LAYOUT: GDScript = preload("res://scripts/world/layout/PathLayout.gd")
const GAMEPLAY_ANCHOR_LAYOUT: GDScript = preload("res://scripts/world/layout/GameplayAnchorLayout.gd")
const NPC_LAYOUT: GDScript = preload("res://scripts/world/layout/NpcLayout.gd")
const PLACEMENT: GDScript = preload("res://scripts/world/layout/PlacementPrimitives.gd")

@export var terrain_path: NodePath = NodePath("../Terrain/TerrainMesh")
## Off once a scene has deliberately emptied this node out in favor of a
## hand-placed layout (see docs/ISLAND_LAYOUT.md) -- otherwise _ready()'s
## "no Districts child yet" check can't tell "never generated" apart from
## "generated once, then intentionally cleared", and would keep silently
## regenerating the old layout back on every load.
@export var auto_populate: bool = true
@export var regenerate: bool = false : set = _set_regenerate

var _terrain: Node
var _sand_material: StandardMaterial3D
var _stone_material: StandardMaterial3D


func _ready() -> void:
	if auto_populate and get_node_or_null("Districts") == null:
		_build_layout()


func _set_regenerate(value: bool) -> void:
	if value:
		_build_layout()
	regenerate = false


func _build_layout() -> void:
	_terrain = get_node_or_null(terrain_path)
	_clear()
	_make_materials()

	if _terrain == null or not _terrain.has_method("get_height"):
		push_warning("AuthoredIslandLayout: terrain_path does not point at IslandMesh.")
		return

	var scene_root: Node = null
	if Engine.is_editor_hint() and get_tree() != null:
		scene_root = get_tree().edited_scene_root

	var districts := Node3D.new()
	districts.name = "Districts"
	add_child(districts)
	PLACEMENT.own_node(districts, scene_root)

	var paths := Node3D.new()
	paths.name = "Paths"
	add_child(paths)
	PLACEMENT.own_node(paths, scene_root)

	var vegetation := Node3D.new()
	vegetation.name = "VegetationMasses"
	add_child(vegetation)
	PLACEMENT.own_node(vegetation, scene_root)

	var anchors := Node3D.new()
	anchors.name = "GameplayAnchors"
	add_child(anchors)
	PLACEMENT.own_node(anchors, scene_root)

	var npc_parent := _ensure_npc_container(scene_root)

	var harbour: Vector2 = DISTRICT_LAYOUT.find_best_near(_terrain, Vector2(72.0, 50.0), 34.0, 0.12, 0.48, 0.78)
	var town: Vector2 = DISTRICT_LAYOUT.find_best_near(_terrain, Vector2(48.0, 38.0), 30.0, 0.28, 0.66, 0.72)
	var heart: Vector2 = DISTRICT_LAYOUT.find_best_near(_terrain, Vector2(24.0, 24.0), 32.0, 0.42, 0.82, 0.72)
	var residential: Vector2 = DISTRICT_LAYOUT.find_best_near(_terrain, Vector2(2.0, 34.0), 38.0, 0.50, 0.90, 0.62)
	var quiet: Vector2 = DISTRICT_LAYOUT.find_best_near(_terrain, Vector2(-58.0, 34.0), 34.0, 0.16, 0.58, 0.70)
	var inland: Vector2 = DISTRICT_LAYOUT.find_best_near(_terrain, Vector2(-18.0, -12.0), 46.0, 0.58, 1.00, 0.65)
	var wild: Vector2 = DISTRICT_LAYOUT.find_best_near(_terrain, Vector2(-72.0, -48.0), 36.0, 0.26, 0.78, 0.55)
	var lighthouse: Vector2 = DISTRICT_LAYOUT.find_highest_hill(_terrain)

	DISTRICT_LAYOUT.make_district(districts, _terrain, scene_root, "MainHarbour", harbour, 18.0)
	DISTRICT_LAYOUT.make_district(districts, _terrain, scene_root, "BeachTown", town, 24.0)
	DISTRICT_LAYOUT.make_district(districts, _terrain, scene_root, "VillageHeart", heart, 16.0)
	DISTRICT_LAYOUT.make_district(districts, _terrain, scene_root, "ResidentialSlopes", residential, 28.0)
	DISTRICT_LAYOUT.make_district(districts, _terrain, scene_root, "LighthouseHill", lighthouse, 20.0)
	DISTRICT_LAYOUT.make_district(districts, _terrain, scene_root, "QuietCoast", quiet, 22.0)
	DISTRICT_LAYOUT.make_district(districts, _terrain, scene_root, "InlandGreen", inland, 30.0)
	DISTRICT_LAYOUT.make_district(districts, _terrain, scene_root, "WildCorner", wild, 24.0)

	PATH_LAYOUT.make_path(paths, _terrain, scene_root, "Primary_Harbour_To_Lighthouse", [harbour, town, heart, residential, lighthouse], 4.2, _sand_material)
	PATH_LAYOUT.make_path(paths, _terrain, scene_root, "Secondary_QuietCoast", [heart, quiet], 3.0, _sand_material)
	PATH_LAYOUT.make_path(paths, _terrain, scene_root, "Secondary_InlandGreen", [heart, inland], 3.2, _sand_material)
	PATH_LAYOUT.make_path(paths, _terrain, scene_root, "Secondary_WildCorner", [inland, wild], 2.6, _stone_material)
	PATH_LAYOUT.make_path(paths, _terrain, scene_root, "Harbour_Service_Loop", [harbour + Vector2(-8.0, -8.0), harbour, town + Vector2(8.0, -6.0)], 3.4, _sand_material)

	DISTRICT_LAYOUT.populate_harbour(districts.get_node("MainHarbour") as Node3D, _terrain, scene_root, _stone_material, harbour)
	DISTRICT_LAYOUT.populate_town(districts.get_node("BeachTown") as Node3D, _terrain, scene_root, _stone_material, town, harbour)
	DISTRICT_LAYOUT.populate_heart(districts.get_node("VillageHeart") as Node3D, _terrain, scene_root, _stone_material, heart)
	DISTRICT_LAYOUT.populate_residential(districts.get_node("ResidentialSlopes") as Node3D, _terrain, scene_root, _stone_material, residential, lighthouse)
	DISTRICT_LAYOUT.populate_lighthouse(districts.get_node("LighthouseHill") as Node3D, _terrain, scene_root, _stone_material, lighthouse, harbour)
	DISTRICT_LAYOUT.populate_quiet_coast(districts.get_node("QuietCoast") as Node3D, _terrain, scene_root, _stone_material, quiet)
	DISTRICT_LAYOUT.populate_green_space(districts.get_node("InlandGreen") as Node3D, _terrain, scene_root, inland)
	DISTRICT_LAYOUT.populate_wild_corner(districts.get_node("WildCorner") as Node3D, _terrain, scene_root, wild)
	DISTRICT_LAYOUT.populate_vegetation(vegetation, _terrain, scene_root, [harbour, town, heart, residential, quiet, inland, wild, lighthouse])
	GAMEPLAY_ANCHOR_LAYOUT.make_anchors(anchors, _terrain, scene_root, harbour, town, heart, residential, lighthouse, quiet, inland, wild)

	if npc_parent != null:
		NPC_LAYOUT.ensure_npcs_placed(npc_parent, _terrain, scene_root, harbour, heart, residential, lighthouse)


func _ensure_npc_container(scene_root: Node) -> Node3D:
	var existing := get_node_or_null(NPC_LAYOUT.CONTAINER_NAME)
	if existing != null:
		var existing_3d := existing as Node3D
		if existing_3d == null:
			push_warning("AuthoredIslandLayout: a node named '%s' exists but isn't a Node3D; NPC placement will be skipped this run." % NPC_LAYOUT.CONTAINER_NAME)
		return existing_3d

	var npc_parent := Node3D.new()
	npc_parent.name = NPC_LAYOUT.CONTAINER_NAME
	add_child(npc_parent)
	PLACEMENT.own_node(npc_parent, scene_root)
	return npc_parent


func _clear() -> void:
	for child in get_children():
		if child.name == NPC_LAYOUT.CONTAINER_NAME:
			continue
		remove_child(child)
		child.queue_free()


func _make_materials() -> void:
	_sand_material = StandardMaterial3D.new()
	_sand_material.albedo_color = Color(0.86, 0.75, 0.52, 1.0)
	_sand_material.roughness = 0.9

	_stone_material = StandardMaterial3D.new()
	_stone_material.albedo_color = Color(0.55, 0.53, 0.47, 1.0)
	_stone_material.roughness = 0.95

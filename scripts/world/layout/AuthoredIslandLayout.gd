@tool
class_name AuthoredIslandLayout
extends Node3D

const HOUSE_SMALL: PackedScene = preload("res://Scenes/Layout/Island/BeachHouseSmall.tscn")
const HOUSE_LARGE: PackedScene = preload("res://Scenes/Layout/Island/BeachHouseLarge.tscn")
const VILLAGE_INN: PackedScene = preload("res://Scenes/Layout/Island/VillageInn.tscn")
const COASTAL_SHED: PackedScene = preload("res://Scenes/Layout/Island/CoastalShed.tscn")
const MARKET_STALL: PackedScene = preload("res://Scenes/Layout/Island/MarketStall.tscn")
const DOCK_SECTION: PackedScene = preload("res://Scenes/Layout/Island/DockSection.tscn")
const LIGHTHOUSE: PackedScene = preload("res://Scenes/Layout/Island/Lighthouse.tscn")
const RETAINING_WALL: PackedScene = preload("res://Scenes/Layout/Island/RetainingWall.tscn")
const PALM_CLUSTER: PackedScene = preload("res://Scenes/Layout/Island/PalmCluster.tscn")
const GARDEN_CLUSTER: PackedScene = preload("res://Scenes/Layout/Island/GardenCluster.tscn")
const BOAT_ROW_SMALL: PackedScene = preload("res://Assets/Kenney/Pirate Kit/boat-row-small.glb")
const BOAT_ROW_LARGE: PackedScene = preload("res://Assets/Kenney/Pirate Kit/boat-row-large.glb")
const CRATE: PackedScene = preload("res://Assets/Kenney/Pirate Kit/crate.glb")
const BARREL: PackedScene = preload("res://Assets/Kenney/Pirate Kit/barrel.glb")
const ROCK_SAND: PackedScene = preload("res://Assets/Kenney/Pirate Kit/rocks-sand-b.glb")
const NPC_VILLAGER: PackedScene = preload("res://Scenes/Characters/NPC/NpcVillager.tscn")
const NPC_FISHER: PackedScene = preload("res://Scenes/Characters/NPC/NpcFisher.tscn")
const NPC_GUARD: PackedScene = preload("res://Scenes/Characters/NPC/NpcGuard.tscn")
const TERRAIN_PLACEMENT: GDScript = preload("res://scripts/world/TerrainPlacement.gd")
const PATH_TILES: Array[PackedScene] = [
	preload("res://Scenes/Layout/Island/PathTileRockA.tscn"),
	preload("res://Scenes/Layout/Island/PathTileRockB.tscn"),
	preload("res://Scenes/Layout/Island/PathTileRockC.tscn"),
]

enum PlacementCategory {
	BUILDING,
	SMALL_PROP,
	VEGETATION,
	ROCK,
	PATH,
	DOCK,
	RETAINING
}

const BUILDING_SLOPE_DELTA := 1.15
const LARGE_BUILDING_SLOPE_DELTA := 1.45
const PROP_SLOPE_DELTA := 0.75
const WATER_DOCK_HEIGHT := 0.26

@export var terrain_path: NodePath = NodePath("../Terrain/TerrainMesh")
@export var regenerate: bool = false : set = _set_regenerate

var _terrain: Node
var _sand_material: StandardMaterial3D
var _stone_material: StandardMaterial3D


func _ready() -> void:
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

	var districts := Node3D.new()
	districts.name = "Districts"
	add_child(districts)
	_own(districts)

	var paths := Node3D.new()
	paths.name = "Paths"
	add_child(paths)
	_own(paths)

	var vegetation := Node3D.new()
	vegetation.name = "VegetationMasses"
	add_child(vegetation)
	_own(vegetation)

	var anchors := Node3D.new()
	anchors.name = "GameplayAnchors"
	add_child(anchors)
	_own(anchors)

	var layout_npcs := Node3D.new()
	layout_npcs.name = "TemporaryNPCs"
	add_child(layout_npcs)
	_own(layout_npcs)

	var harbour: Vector2 = _find_best_near(Vector2(72.0, 50.0), 34.0, 0.12, 0.48, 0.78)
	var town: Vector2 = _find_best_near(Vector2(48.0, 38.0), 30.0, 0.28, 0.66, 0.72)
	var heart: Vector2 = _find_best_near(Vector2(24.0, 24.0), 32.0, 0.42, 0.82, 0.72)
	var residential: Vector2 = _find_best_near(Vector2(2.0, 34.0), 38.0, 0.50, 0.90, 0.62)
	var quiet: Vector2 = _find_best_near(Vector2(-58.0, 34.0), 34.0, 0.16, 0.58, 0.70)
	var inland: Vector2 = _find_best_near(Vector2(-18.0, -12.0), 46.0, 0.58, 1.00, 0.65)
	var wild: Vector2 = _find_best_near(Vector2(-72.0, -48.0), 36.0, 0.26, 0.78, 0.55)
	var lighthouse: Vector2 = _find_highest_hill()

	_make_district(districts, "MainHarbour", harbour, 18.0)
	_make_district(districts, "BeachTown", town, 24.0)
	_make_district(districts, "VillageHeart", heart, 16.0)
	_make_district(districts, "ResidentialSlopes", residential, 28.0)
	_make_district(districts, "LighthouseHill", lighthouse, 20.0)
	_make_district(districts, "QuietCoast", quiet, 22.0)
	_make_district(districts, "InlandGreen", inland, 30.0)
	_make_district(districts, "WildCorner", wild, 24.0)

	_make_path(paths, "Primary_Harbour_To_Lighthouse", [harbour, town, heart, residential, lighthouse], 4.2, _sand_material)
	_make_path(paths, "Secondary_QuietCoast", [heart, quiet], 3.0, _sand_material)
	_make_path(paths, "Secondary_InlandGreen", [heart, inland], 3.2, _sand_material)
	_make_path(paths, "Secondary_WildCorner", [inland, wild], 2.6, _stone_material)
	_make_path(paths, "Harbour_Service_Loop", [harbour + Vector2(-8.0, -8.0), harbour, town + Vector2(8.0, -6.0)], 3.4, _sand_material)

	_populate_harbour(districts.get_node("MainHarbour") as Node3D, harbour)
	_populate_town(districts.get_node("BeachTown") as Node3D, town, harbour)
	_populate_heart(districts.get_node("VillageHeart") as Node3D, heart)
	_populate_residential(districts.get_node("ResidentialSlopes") as Node3D, residential, lighthouse)
	_populate_lighthouse(districts.get_node("LighthouseHill") as Node3D, lighthouse, harbour)
	_populate_quiet_coast(districts.get_node("QuietCoast") as Node3D, quiet)
	_populate_green_space(districts.get_node("InlandGreen") as Node3D, inland)
	_populate_wild_corner(districts.get_node("WildCorner") as Node3D, wild)
	_populate_vegetation(vegetation, [harbour, town, heart, residential, quiet, inland, wild, lighthouse])
	_make_anchors(anchors, harbour, town, heart, residential, lighthouse, quiet, inland, wild)
	_place_layout_npcs(layout_npcs, harbour, heart, residential, lighthouse)


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _own(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root


func _make_materials() -> void:
	_sand_material = StandardMaterial3D.new()
	_sand_material.albedo_color = Color(0.86, 0.75, 0.52, 1.0)
	_sand_material.roughness = 0.9

	_stone_material = StandardMaterial3D.new()
	_stone_material.albedo_color = Color(0.55, 0.53, 0.47, 1.0)
	_stone_material.roughness = 0.95


func _find_best_near(center: Vector2, radius: float, min_mask: float, max_mask: float, min_normal_y: float) -> Vector2:
	var best := center
	var best_score := -100000.0
	var step := 4.0
	var sample_count := int(ceil(radius / step))
	for xi in range(-sample_count, sample_count + 1):
		for zi in range(-sample_count, sample_count + 1):
			var candidate := center + Vector2(float(xi) * step, float(zi) * step)
			if candidate.distance_to(center) > radius:
				continue
			var mask: float = _terrain.call("get_land_mask", candidate.x, candidate.y)
			if mask < min_mask or mask > max_mask:
				continue
			var normal: Vector3 = _terrain.call("get_normal", candidate.x, candidate.y)
			if normal.y < min_normal_y:
				continue
			var height: float = _terrain.call("get_height", candidate.x, candidate.y)
			var distance_score: float = 1.0 - candidate.distance_to(center) / max(radius, 1.0)
			var score: float = distance_score * 5.0 + normal.y * 2.0 - abs(height - 5.0) * 0.03
			if score > best_score:
				best_score = score
				best = candidate
	return best


func _find_highest_hill() -> Vector2:
	var best := Vector2(0.0, 0.0)
	var best_height := -1000.0
	for xi in range(-24, 25):
		for zi in range(-24, 25):
			var candidate := Vector2(float(xi) * 4.0, float(zi) * 4.0)
			var mask: float = _terrain.call("get_land_mask", candidate.x, candidate.y)
			if mask < 0.62:
				continue
			var normal: Vector3 = _terrain.call("get_normal", candidate.x, candidate.y)
			if normal.y < 0.58:
				continue
			var height: float = _terrain.call("get_height", candidate.x, candidate.y)
			if height > best_height:
				best_height = height
				best = candidate
	return best


func _make_district(parent: Node3D, district_name: String, center: Vector2, radius: float) -> void:
	var root := Node3D.new()
	root.name = district_name
	parent.add_child(root)
	_own(root)
	root.global_position = _to_world(center, 0.0)
	root.set_meta("district_radius", radius)


func _make_path(parent: Node3D, path_name: String, points: Array, width: float, material: Material) -> void:
	var root := Node3D.new()
	root.name = path_name
	parent.add_child(root)
	_own(root)

	var tint_color := Color.WHITE
	if material is StandardMaterial3D:
		tint_color = (material as StandardMaterial3D).albedo_color

	var tile_index := 0
	for i in range(points.size() - 1):
		var include_end: bool = i == points.size() - 2
		tile_index = _make_path_between(root, path_name, points[i], points[i + 1], width, tint_color, tile_index, include_end)


func _make_path_between(parent: Node3D, path_name: String, from_point: Vector2, to_point: Vector2, width: float, tint_color: Color, start_index: int, include_end: bool) -> int:
	var distance: float = from_point.distance_to(to_point)
	var direction: Vector2 = (to_point - from_point).normalized()
	var base_yaw: float = atan2(direction.x, direction.y)
	var perpendicular: Vector2 = Vector2(direction.y, -direction.x)
	var tile_target_size: float = clampf(width * 0.42, 1.0, 2.0)
	var spacing: float = tile_target_size * 0.8
	var step_count: int = maxi(1, int(round(distance / spacing)))
	var last_step: int = step_count if include_end else step_count - 1

	var index := start_index
	for step in range(last_step + 1):
		var t: float = float(step) / float(step_count)
		var xz: Vector2 = from_point.lerp(to_point, t)

		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s_tile_%d" % [path_name, index])
		var yaw_jitter: float = rng.randf_range(-0.35, 0.35)
		var scale_jitter: float = rng.randf_range(0.88, 1.12)
		var lateral_jitter: float = rng.randf_range(-0.3, 0.3) * tile_target_size * 0.3
		xz += perpendicular * lateral_jitter
		var tile_scene: PackedScene = PATH_TILES[rng.randi_range(0, PATH_TILES.size() - 1)]

		_place_path_tile(parent, "%s_Tile%02d" % [path_name, index], tile_scene, xz, base_yaw + yaw_jitter, tile_target_size * scale_jitter, tint_color)
		index += 1

	return index


func _place_path_tile(parent: Node3D, node_name: String, tile_scene: PackedScene, xz: Vector2, yaw: float, target_size: float, tint_color: Color) -> void:
	var node: Node3D = tile_scene.instantiate() as Node3D
	if node == null:
		return
	node.name = node_name
	node.set("apply_tint", true)
	node.set("tint_color", tint_color)
	parent.add_child(node)
	_own(node)

	var footprint: Vector3 = _measure_local_footprint(node)
	var base_size: float = maxf(maxf(footprint.x, footprint.z), 0.01)
	var scale_value: Vector3 = Vector3.ONE * (target_size / base_size)

	TERRAIN_PLACEMENT.apply_surface(node, _terrain, xz, yaw, 0.05, scale_value, 0.35)


func _measure_local_footprint(node: Node3D) -> Vector3:
	var mesh_instance := _find_mesh_instance(node)
	if mesh_instance == null:
		return Vector3.ONE
	var aabb: AABB = mesh_instance.get_aabb()
	var relative_xform: Transform3D = node.global_transform.affine_inverse() * mesh_instance.global_transform
	var result := AABB()
	var first := true
	for i in range(8):
		var corner: Vector3 = aabb.position + Vector3(
			aabb.size.x * float(i & 1),
			aabb.size.y * float((i >> 1) & 1),
			aabb.size.z * float((i >> 2) & 1)
		)
		var world_corner: Vector3 = relative_xform * corner
		if first:
			result = AABB(world_corner, Vector3.ZERO)
			first = false
		else:
			result = result.expand(world_corner)
	return result.size


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null


func _populate_harbour(parent: Node3D, center: Vector2) -> void:
	var out := center.normalized()
	if out.length() < 0.01:
		out = Vector2(1.0, 0.0)
	var tangent := Vector2(-out.y, out.x)
	for i in range(4):
		_place_dock(parent, DOCK_SECTION, "DockSection%d" % i, center + out * float(i * 5), TERRAIN_PLACEMENT.yaw_towards(center, center + out), Vector3.ONE, Vector3(4.4, 0.7, 5.2))
	_place_water_scene(parent, BOAT_ROW_LARGE, "HarbourBoatLarge", center + out * 22.0 + tangent * 5.0, atan2(out.x, out.y) + 0.3, Vector3.ONE * 1.15)
	_place_water_scene(parent, BOAT_ROW_SMALL, "HarbourBoatSmall", center + out * 16.0 - tangent * 5.5, atan2(out.x, out.y) - 0.5, Vector3.ONE)
	_place_building(parent, COASTAL_SHED, "BoatShed", center - out * 7.0 + tangent * 6.0, TERRAIN_PLACEMENT.yaw_towards(center - out * 7.0 + tangent * 6.0, center), Vector3.ONE, Vector2(5.8, 4.8), BUILDING_SLOPE_DELTA)
	_place_building(parent, COASTAL_SHED, "WarehouseLight", center - out * 11.0 - tangent * 5.0, TERRAIN_PLACEMENT.yaw_towards(center - out * 11.0 - tangent * 5.0, center), Vector3(1.2, 1.0, 1.0), Vector2(6.8, 5.2), BUILDING_SLOPE_DELTA)
	_place_prop(parent, CRATE, "HarbourCrates", center - out * 5.0, 0.3, Vector3.ONE * 1.4, true, Vector3(2.0, 1.8, 2.0))
	_place_prop(parent, BARREL, "HarbourBarrels", center - out * 8.0 - tangent * 3.0, -0.2, Vector3.ONE * 1.3, false, Vector3.ZERO)


func _populate_town(parent: Node3D, center: Vector2, harbour: Vector2) -> void:
	var to_harbour := (harbour - center).normalized()
	var tangent := Vector2(-to_harbour.y, to_harbour.x)
	var offsets: Array[Vector2] = [
		Vector2(-10.0, -6.0), Vector2(-4.0, -11.0), Vector2(5.0, -8.0), Vector2(11.0, -2.0),
		Vector2(-13.0, 4.0), Vector2(-5.0, 7.0), Vector2(5.0, 6.0), Vector2(13.0, 7.0),
	]
	for i in range(offsets.size()):
		var offset: Vector2 = tangent * offsets[i].x + to_harbour * offsets[i].y
		var scene: PackedScene = HOUSE_SMALL if i % 3 != 0 else HOUSE_LARGE
		var footprint := Vector2(5.8, 5.8) if scene == HOUSE_SMALL else Vector2(7.8, 6.8)
		var slope_limit := BUILDING_SLOPE_DELTA if scene == HOUSE_SMALL else LARGE_BUILDING_SLOPE_DELTA
		_place_building(parent, scene, "BeachTownHouse%d" % i, center + offset, TERRAIN_PLACEMENT.yaw_towards(center + offset, center), Vector3.ONE, footprint, slope_limit)


func _populate_heart(parent: Node3D, center: Vector2) -> void:
	_place_building(parent, VILLAGE_INN, "VillageInn", center + Vector2(-8.0, -5.0), TERRAIN_PLACEMENT.yaw_towards(center + Vector2(-8.0, -5.0), center), Vector3.ONE, Vector2(9.8, 8.8), LARGE_BUILDING_SLOPE_DELTA)
	for i in range(3):
		var stall_xz := center + Vector2(float(i - 1) * 5.0, 5.0)
		_place_prop(parent, MARKET_STALL, "MarketStall%d" % i, stall_xz, TERRAIN_PLACEMENT.yaw_towards(stall_xz, center), Vector3.ONE, true, Vector3(4.2, 2.6, 3.4))
	_make_plaza(parent, "VillagePlaza", center, 8.0)
	_make_marker(parent, "CommunalWellBlockout", center + Vector2(0.0, -1.5), 0.5)


func _populate_residential(parent: Node3D, center: Vector2, lighthouse: Vector2) -> void:
	var slope_axis := (lighthouse - center).normalized()
	var tangent := Vector2(-slope_axis.y, slope_axis.x)
	for i in range(6):
		var offset := slope_axis * float(i * 5 - 10) + tangent * float((i % 3 - 1) * 7)
		var house_scene: PackedScene = HOUSE_LARGE if i % 2 == 0 else HOUSE_SMALL
		var footprint := Vector2(7.2, 6.2) if house_scene == HOUSE_LARGE else Vector2(5.5, 5.5)
		_place_building(parent, house_scene, "SlopeHouse%d" % i, center + offset, TERRAIN_PLACEMENT.yaw_towards(center + offset, center), Vector3.ONE * 0.9, footprint, LARGE_BUILDING_SLOPE_DELTA)
		_place_retaining(parent, RETAINING_WALL, "TerraceWall%d" % i, center + offset - slope_axis * 3.5, atan2(tangent.x, tangent.y), Vector3(1.4, 0.8, 1.0))


func _populate_lighthouse(parent: Node3D, center: Vector2, harbour: Vector2) -> void:
	_place_building(parent, LIGHTHOUSE, "Lighthouse", center, TERRAIN_PLACEMENT.yaw_towards(center, harbour), Vector3.ONE, Vector2(8.0, 8.0), 1.8)
	var keeper_xz := center + Vector2(-8.0, -6.0)
	_place_building(parent, HOUSE_SMALL, "KeeperHouse", keeper_xz, TERRAIN_PLACEMENT.yaw_towards(keeper_xz, center), Vector3.ONE * 0.8, Vector2(5.2, 5.2), BUILDING_SLOPE_DELTA)
	_make_marker(parent, "LightBeaconMarker", center, 12.0)


func _populate_quiet_coast(parent: Node3D, center: Vector2) -> void:
	for i in range(3):
		var house_xz := center + Vector2(float(i - 1) * 7.0, float(i % 2) * 6.0)
		_place_building(parent, HOUSE_SMALL, "QuietCoastHouse%d" % i, house_xz, TERRAIN_PLACEMENT.yaw_towards(house_xz, center), Vector3.ONE * 0.82, Vector2(5.2, 5.2), BUILDING_SLOPE_DELTA)
	_place_prop(parent, BOAT_ROW_SMALL, "FishingBoatPulledUp", center + Vector2(7.0, -8.0), 1.1, Vector3.ONE, true, Vector3(3.2, 1.0, 5.0), 0.18)
	_place_natural(parent, GARDEN_CLUSTER, "CoastalGarden", center + Vector2(-7.0, 6.0), 0.0, Vector3.ONE * 1.2, 0.2, false)


func _populate_green_space(parent: Node3D, center: Vector2) -> void:
	for i in range(5):
		_place_natural(parent, GARDEN_CLUSTER, "GardenPatch%d" % i, center + Vector2(float(i - 2) * 5.0, float((i % 2) * 7 - 3)), float(i) * 0.6, Vector3.ONE, 0.15, false)
	for i in range(4):
		_place_natural(parent, PALM_CLUSTER, "OrchardPalm%d" % i, center + Vector2(float(i - 2) * 8.0, 11.0), float(i) * 0.7, Vector3.ONE, 0.18, false)


func _populate_wild_corner(parent: Node3D, center: Vector2) -> void:
	for i in range(7):
		_place_natural(parent, PALM_CLUSTER, "WildPalm%d" % i, center + Vector2(float(i % 3 - 1) * 8.0, float(i / 3) * 7.0), float(i) * 0.8, Vector3.ONE * 1.2, 0.2, false)
	for i in range(5):
		_place_natural(parent, ROCK_SAND, "WildRock%d" % i, center + Vector2(float(i - 2) * 5.0, -7.0), float(i) * 0.4, Vector3.ONE * 1.5, 0.75, true, Vector3(2.8, 1.8, 2.8))
	_make_marker(parent, "FutureCoveMysteryBlockout", center + Vector2(4.0, 4.0), 0.5)


func _populate_vegetation(parent: Node3D, centers: Array) -> void:
	for i in range(centers.size()):
		var center: Vector2 = centers[i]
		for j in range(3):
			var angle := float(i * 53 + j * 97) * 0.0174533
			var offset := Vector2(cos(angle), sin(angle)) * (14.0 + float(j) * 4.0)
			_place_natural(parent, PALM_CLUSTER, "DistrictPalm_%d_%d" % [i, j], center + offset, angle, Vector3.ONE, 0.18, false)


func _make_anchors(parent: Node3D, harbour: Vector2, town: Vector2, heart: Vector2, residential: Vector2, lighthouse: Vector2, quiet: Vector2, inland: Vector2, wild: Vector2) -> void:
	_make_marker(parent, "PlayerStart_LayoutReference", Vector2(0.0, 0.0))
	_make_marker(parent, "HarbourEntrance", harbour)
	_make_marker(parent, "VillageHeart", heart)
	_make_marker(parent, "LighthouseEntrance", lighthouse + (residential - lighthouse).normalized() * 8.0)
	_make_marker(parent, "FuturePirateLanding", harbour + harbour.normalized() * 18.0)
	_make_marker(parent, "FutureCivilianGatheringPoint", heart + Vector2(3.0, 3.0))
	_make_marker(parent, "FutureHorrorEventStaging", wild)
	_make_marker(parent, "FutureBattleTransitionTrigger", town.lerp(harbour, 0.45))
	_make_marker(parent, "QuietCoastAnchor", quiet)
	_make_marker(parent, "InlandGreenAnchor", inland)


func _place_layout_npcs(parent: Node3D, harbour: Vector2, heart: Vector2, residential: Vector2, lighthouse: Vector2) -> void:
	_place_npc(parent, NPC_FISHER, "HarbourFisherA", harbour + Vector2(-4.0, 2.0))
	_place_npc(parent, NPC_FISHER, "HarbourFisherB", harbour + Vector2(4.0, -2.0))
	_place_npc(parent, NPC_VILLAGER, "VillageVillagerA", heart + Vector2(-3.0, 3.0))
	_place_npc(parent, NPC_VILLAGER, "VillageVillagerB", heart + Vector2(4.0, 4.0))
	_place_npc(parent, NPC_VILLAGER, "VillageVillagerC", heart + Vector2(1.0, -5.0))
	_place_npc(parent, NPC_VILLAGER, "SlopeResident", residential + Vector2(5.0, -2.0))
	_place_npc(parent, NPC_GUARD, "LighthousePathWalker", lighthouse + Vector2(-8.0, -7.0))


func _place_building(parent: Node3D, scene: PackedScene, node_name: String, xz: Vector2, yaw: float, scale_value: Vector3, footprint: Vector2, max_height_delta: float) -> Node3D:
	var node: Node3D = scene.instantiate() as Node3D
	if node == null:
		return null
	var sampled: TERRAIN_PLACEMENT.FootprintResult = TERRAIN_PLACEMENT.find_nearby_valid_building(_terrain, xz, yaw, footprint, max_height_delta, 14.0, 2.0, 0.62)
	node.name = node_name
	parent.add_child(node)
	_own(node)
	TERRAIN_PLACEMENT.apply_upright(node, sampled, 0.1, scale_value)
	_make_foundation(parent, "%sFoundation" % node_name, sampled, footprint + Vector2(1.0, 1.0), 0.34)
	return node


func _place_prop(
	parent: Node3D,
	scene: PackedScene,
	node_name: String,
	xz: Vector2,
	yaw: float,
	scale_value: Vector3,
	add_collision: bool,
	collision_size: Vector3,
	surface_offset: float = 0.12
) -> Node3D:
	var node: Node3D = scene.instantiate() as Node3D
	if node == null:
		return null
	var sampled: TERRAIN_PLACEMENT.FootprintResult = TERRAIN_PLACEMENT.sample_footprint(_terrain, xz, yaw, Vector2(2.0, 2.0))
	node.name = node_name
	parent.add_child(node)
	_own(node)
	node.global_position = Vector3(xz.x, sampled.center_height + surface_offset, xz.y)
	node.rotation = Vector3(0.0, yaw, 0.0)
	node.scale = scale_value
	if add_collision:
		_make_collision_box(node, "PlacementCollision", Vector3(0.0, collision_size.y * 0.5, 0.0), 0.0, collision_size)
	return node


func _place_natural(
	parent: Node3D,
	scene: PackedScene,
	node_name: String,
	xz: Vector2,
	yaw: float,
	scale_value: Vector3,
	normal_alignment_strength: float,
	add_collision: bool,
	collision_size: Vector3 = Vector3.ZERO
) -> Node3D:
	var node: Node3D = scene.instantiate() as Node3D
	if node == null:
		return null
	node.name = node_name
	parent.add_child(node)
	_own(node)
	TERRAIN_PLACEMENT.apply_surface(node, _terrain, xz, yaw, 0.08, scale_value, normal_alignment_strength)
	if add_collision:
		_make_collision_box(node, "PlacementCollision", Vector3(0.0, collision_size.y * 0.5, 0.0), 0.0, collision_size)
	return node
	

func _place_retaining(parent: Node3D, scene: PackedScene, node_name: String, xz: Vector2, yaw: float, scale_value: Vector3) -> Node3D:
	var node: Node3D = scene.instantiate() as Node3D
	if node == null:
		return null
	var sampled: TERRAIN_PLACEMENT.FootprintResult = TERRAIN_PLACEMENT.sample_footprint(_terrain, xz, yaw, Vector2(7.0, 1.4))
	node.name = node_name
	parent.add_child(node)
	_own(node)
	node.global_position = Vector3(xz.x, sampled.average_height + 0.08, xz.y)
	node.rotation = Vector3(0.0, yaw, 0.0)
	node.scale = scale_value
	return node


func _place_dock(parent: Node3D, scene: PackedScene, node_name: String, xz: Vector2, yaw: float, scale_value: Vector3, collision_size: Vector3) -> Node3D:
	var node: Node3D = scene.instantiate() as Node3D
	if node == null:
		return null
	node.name = node_name
	parent.add_child(node)
	_own(node)
	node.global_position = Vector3(xz.x, WATER_DOCK_HEIGHT, xz.y)
	node.rotation = Vector3(0.0, yaw, 0.0)
	node.scale = scale_value
	_make_collision_box(node, "DockDeckCollision", Vector3(0.0, collision_size.y * 0.5, 0.0), 0.0, collision_size)
	return node


func _place_water_scene(parent: Node3D, scene: PackedScene, node_name: String, xz: Vector2, yaw: float, scale_value: Vector3) -> Node3D:
	var node: Node3D = scene.instantiate() as Node3D
	if node == null:
		return null
	node.name = node_name
	parent.add_child(node)
	_own(node)
	node.global_position = Vector3(xz.x, WATER_DOCK_HEIGHT - 0.12, xz.y)
	node.rotation.y = yaw
	node.scale = scale_value
	return node


func _place_npc(parent: Node3D, scene: PackedScene, node_name: String, xz: Vector2) -> void:
	var node: Node3D = scene.instantiate() as Node3D
	if node == null:
		return
	node.name = node_name
	parent.add_child(node)
	_own(node)
	node.global_position = _to_world(xz, 1.0)
	node.set("terrain_path", NodePath("../../../Terrain/TerrainMesh"))


func _make_foundation(parent: Node3D, node_name: String, sampled: TERRAIN_PLACEMENT.FootprintResult, size: Vector2, minimum_height: float) -> void:
	var foundation_height: float = max(minimum_height, sampled.height_delta + 0.22)
	var foundation_y: float = sampled.min_height + foundation_height * 0.5 - 0.12
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, foundation_height, size.y)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _stone_material
	parent.add_child(mesh_instance)
	_own(mesh_instance)
	mesh_instance.global_position = Vector3(sampled.center.x, foundation_y, sampled.center.y)
	mesh_instance.rotation.y = sampled.yaw
	_make_collision_box(mesh_instance, "FoundationCollision", Vector3.ZERO, 0.0, Vector3(size.x, foundation_height, size.y))


func _make_collision_box(parent: Node3D, node_name: String, local_position: Vector3, yaw: float, size: Vector3) -> void:
	if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		return
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = local_position
	body.rotation.y = yaw
	parent.add_child(body)
	_own(body)

	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_own(shape)


func _make_plaza(parent: Node3D, node_name: String, xz: Vector2, radius: float) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.08
	mesh.radial_segments = 32
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _stone_material
	parent.add_child(mesh_instance)
	_own(mesh_instance)
	mesh_instance.global_position = _to_world(xz, 0.04)


func _make_marker(parent: Node3D, marker_name: String, xz: Vector2, height_offset: float = 0.35) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	parent.add_child(marker)
	_own(marker)
	marker.global_position = _to_world(xz, height_offset)


func _to_world(xz: Vector2, height_offset: float = 0.0) -> Vector3:
	var height: float = _terrain.call("get_height", xz.x, xz.y)
	return Vector3(xz.x, height + height_offset, xz.y)

@tool
class_name DistrictLayout
extends RefCounted

## District site selection + per-district content (buildings, props,
## vegetation) — split out of AuthoredIslandLayout.gd unchanged. Buildings
## live here rather than in a separate BuildingLayout because they're
## hand-placed per-district content, not a district-agnostic system: each
## _populate_* function is a district's specific authored recipe.

const TERRAIN_PLACEMENT: GDScript = preload("res://scripts/world/TerrainPlacement.gd")
const PLACEMENT: GDScript = preload("res://scripts/world/layout/PlacementPrimitives.gd")

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

const BUILDING_SLOPE_DELTA := 1.15
const LARGE_BUILDING_SLOPE_DELTA := 1.45
const PROP_SLOPE_DELTA := 0.75


static func find_best_near(terrain: Node, center: Vector2, radius: float, min_mask: float, max_mask: float, min_normal_y: float) -> Vector2:
	var best := center
	var best_score := -100000.0
	var step := 4.0
	var sample_count := int(ceil(radius / step))
	for xi in range(-sample_count, sample_count + 1):
		for zi in range(-sample_count, sample_count + 1):
			var candidate := center + Vector2(float(xi) * step, float(zi) * step)
			if candidate.distance_to(center) > radius:
				continue
			var mask: float = terrain.call("get_land_mask", candidate.x, candidate.y)
			if mask < min_mask or mask > max_mask:
				continue
			var normal: Vector3 = terrain.call("get_normal", candidate.x, candidate.y)
			if normal.y < min_normal_y:
				continue
			var height: float = terrain.call("get_height", candidate.x, candidate.y)
			var distance_score: float = 1.0 - candidate.distance_to(center) / max(radius, 1.0)
			var score: float = distance_score * 5.0 + normal.y * 2.0 - abs(height - 5.0) * 0.03
			if score > best_score:
				best_score = score
				best = candidate
	return best


static func find_highest_hill(terrain: Node) -> Vector2:
	var best := Vector2(0.0, 0.0)
	var best_height := -1000.0
	for xi in range(-24, 25):
		for zi in range(-24, 25):
			var candidate := Vector2(float(xi) * 4.0, float(zi) * 4.0)
			var mask: float = terrain.call("get_land_mask", candidate.x, candidate.y)
			if mask < 0.62:
				continue
			var normal: Vector3 = terrain.call("get_normal", candidate.x, candidate.y)
			if normal.y < 0.58:
				continue
			var height: float = terrain.call("get_height", candidate.x, candidate.y)
			if height > best_height:
				best_height = height
				best = candidate
	return best


static func make_district(parent: Node3D, terrain: Node, scene_root: Node, district_name: String, center: Vector2, radius: float) -> void:
	var root := Node3D.new()
	root.name = district_name
	parent.add_child(root)
	PLACEMENT.own_node(root, scene_root)
	root.global_position = PLACEMENT.to_world(terrain, center)
	root.set_meta("district_radius", radius)


static func populate_harbour(parent: Node3D, terrain: Node, scene_root: Node, stone_material: Material, center: Vector2) -> void:
	var out := center.normalized()
	if out.length() < 0.01:
		out = Vector2(1.0, 0.0)
	var tangent := Vector2(-out.y, out.x)
	for i in range(4):
		PLACEMENT.place_dock(parent, scene_root, DOCK_SECTION, "DockSection%d" % i, center + out * float(i * 5), TERRAIN_PLACEMENT.yaw_towards(center, center + out), Vector3.ONE, Vector3(4.4, 0.7, 5.2))
	PLACEMENT.place_water_scene(parent, scene_root, BOAT_ROW_LARGE, "HarbourBoatLarge", center + out * 22.0 + tangent * 5.0, atan2(out.x, out.y) + 0.3, Vector3.ONE * 1.15)
	PLACEMENT.place_water_scene(parent, scene_root, BOAT_ROW_SMALL, "HarbourBoatSmall", center + out * 16.0 - tangent * 5.5, atan2(out.x, out.y) - 0.5, Vector3.ONE)
	PLACEMENT.place_building(parent, terrain, scene_root, stone_material, COASTAL_SHED, "BoatShed", center - out * 7.0 + tangent * 6.0, TERRAIN_PLACEMENT.yaw_towards(center - out * 7.0 + tangent * 6.0, center), Vector3.ONE, Vector2(5.8, 4.8), BUILDING_SLOPE_DELTA)
	PLACEMENT.place_building(parent, terrain, scene_root, stone_material, COASTAL_SHED, "WarehouseLight", center - out * 11.0 - tangent * 5.0, TERRAIN_PLACEMENT.yaw_towards(center - out * 11.0 - tangent * 5.0, center), Vector3(1.2, 1.0, 1.0), Vector2(6.8, 5.2), BUILDING_SLOPE_DELTA)
	PLACEMENT.place_prop(parent, terrain, scene_root, CRATE, "HarbourCrates", center - out * 5.0, 0.3, Vector3.ONE * 1.4, true, Vector3(2.0, 1.8, 2.0))
	PLACEMENT.place_prop(parent, terrain, scene_root, BARREL, "HarbourBarrels", center - out * 8.0 - tangent * 3.0, -0.2, Vector3.ONE * 1.3, false, Vector3.ZERO)


static func populate_town(parent: Node3D, terrain: Node, scene_root: Node, stone_material: Material, center: Vector2, harbour: Vector2) -> void:
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
		PLACEMENT.place_building(parent, terrain, scene_root, stone_material, scene, "BeachTownHouse%d" % i, center + offset, TERRAIN_PLACEMENT.yaw_towards(center + offset, center), Vector3.ONE, footprint, slope_limit)


static func populate_heart(parent: Node3D, terrain: Node, scene_root: Node, stone_material: Material, center: Vector2) -> void:
	PLACEMENT.place_building(parent, terrain, scene_root, stone_material, VILLAGE_INN, "VillageInn", center + Vector2(-8.0, -5.0), TERRAIN_PLACEMENT.yaw_towards(center + Vector2(-8.0, -5.0), center), Vector3.ONE, Vector2(9.8, 8.8), LARGE_BUILDING_SLOPE_DELTA)
	for i in range(3):
		var stall_xz := center + Vector2(float(i - 1) * 5.0, 5.0)
		PLACEMENT.place_prop(parent, terrain, scene_root, MARKET_STALL, "MarketStall%d" % i, stall_xz, TERRAIN_PLACEMENT.yaw_towards(stall_xz, center), Vector3.ONE, true, Vector3(4.2, 2.6, 3.4))
	make_plaza(parent, terrain, scene_root, stone_material, "VillagePlaza", center, 8.0)
	PLACEMENT.make_marker(parent, terrain, scene_root, "CommunalWellBlockout", center + Vector2(0.0, -1.5), 0.5)


static func populate_residential(parent: Node3D, terrain: Node, scene_root: Node, stone_material: Material, center: Vector2, lighthouse: Vector2) -> void:
	var slope_axis := (lighthouse - center).normalized()
	var tangent := Vector2(-slope_axis.y, slope_axis.x)
	for i in range(6):
		var offset := slope_axis * float(i * 5 - 10) + tangent * float((i % 3 - 1) * 7)
		var house_scene: PackedScene = HOUSE_LARGE if i % 2 == 0 else HOUSE_SMALL
		var footprint := Vector2(7.2, 6.2) if house_scene == HOUSE_LARGE else Vector2(5.5, 5.5)
		PLACEMENT.place_building(parent, terrain, scene_root, stone_material, house_scene, "SlopeHouse%d" % i, center + offset, TERRAIN_PLACEMENT.yaw_towards(center + offset, center), Vector3.ONE * 0.9, footprint, LARGE_BUILDING_SLOPE_DELTA)
		PLACEMENT.place_retaining(parent, terrain, scene_root, RETAINING_WALL, "TerraceWall%d" % i, center + offset - slope_axis * 3.5, atan2(tangent.x, tangent.y), Vector3(1.4, 0.8, 1.0))


static func populate_lighthouse(parent: Node3D, terrain: Node, scene_root: Node, stone_material: Material, center: Vector2, harbour: Vector2) -> void:
	PLACEMENT.place_building(parent, terrain, scene_root, stone_material, LIGHTHOUSE, "Lighthouse", center, TERRAIN_PLACEMENT.yaw_towards(center, harbour), Vector3.ONE, Vector2(8.0, 8.0), 1.8)
	var keeper_xz := center + Vector2(-8.0, -6.0)
	PLACEMENT.place_building(parent, terrain, scene_root, stone_material, HOUSE_SMALL, "KeeperHouse", keeper_xz, TERRAIN_PLACEMENT.yaw_towards(keeper_xz, center), Vector3.ONE * 0.8, Vector2(5.2, 5.2), BUILDING_SLOPE_DELTA)
	PLACEMENT.make_marker(parent, terrain, scene_root, "LightBeaconMarker", center, 12.0)


static func populate_quiet_coast(parent: Node3D, terrain: Node, scene_root: Node, stone_material: Material, center: Vector2) -> void:
	for i in range(3):
		var house_xz := center + Vector2(float(i - 1) * 7.0, float(i % 2) * 6.0)
		PLACEMENT.place_building(parent, terrain, scene_root, stone_material, HOUSE_SMALL, "QuietCoastHouse%d" % i, house_xz, TERRAIN_PLACEMENT.yaw_towards(house_xz, center), Vector3.ONE * 0.82, Vector2(5.2, 5.2), BUILDING_SLOPE_DELTA)
	PLACEMENT.place_prop(parent, terrain, scene_root, BOAT_ROW_SMALL, "FishingBoatPulledUp", center + Vector2(7.0, -8.0), 1.1, Vector3.ONE, true, Vector3(3.2, 1.0, 5.0), 0.18)
	PLACEMENT.place_natural(parent, terrain, scene_root, GARDEN_CLUSTER, "CoastalGarden", center + Vector2(-7.0, 6.0), 0.0, Vector3.ONE * 1.2, 0.2, false)


static func populate_green_space(parent: Node3D, terrain: Node, scene_root: Node, center: Vector2) -> void:
	for i in range(5):
		PLACEMENT.place_natural(parent, terrain, scene_root, GARDEN_CLUSTER, "GardenPatch%d" % i, center + Vector2(float(i - 2) * 5.0, float((i % 2) * 7 - 3)), float(i) * 0.6, Vector3.ONE, 0.15, false)
	for i in range(4):
		PLACEMENT.place_natural(parent, terrain, scene_root, PALM_CLUSTER, "OrchardPalm%d" % i, center + Vector2(float(i - 2) * 8.0, 11.0), float(i) * 0.7, Vector3.ONE, 0.18, false)


static func populate_wild_corner(parent: Node3D, terrain: Node, scene_root: Node, center: Vector2) -> void:
	for i in range(7):
		PLACEMENT.place_natural(parent, terrain, scene_root, PALM_CLUSTER, "WildPalm%d" % i, center + Vector2(float(i % 3 - 1) * 8.0, float(i / 3) * 7.0), float(i) * 0.8, Vector3.ONE * 1.2, 0.2, false)
	for i in range(5):
		PLACEMENT.place_natural(parent, terrain, scene_root, ROCK_SAND, "WildRock%d" % i, center + Vector2(float(i - 2) * 5.0, -7.0), float(i) * 0.4, Vector3.ONE * 1.5, 0.75, true, Vector3(2.8, 1.8, 2.8))
	PLACEMENT.make_marker(parent, terrain, scene_root, "FutureCoveMysteryBlockout", center + Vector2(4.0, 4.0), 0.5)


static func populate_vegetation(parent: Node3D, terrain: Node, scene_root: Node, centers: Array) -> void:
	for i in range(centers.size()):
		var center: Vector2 = centers[i]
		for j in range(3):
			var angle := float(i * 53 + j * 97) * 0.0174533
			var offset := Vector2(cos(angle), sin(angle)) * (14.0 + float(j) * 4.0)
			PLACEMENT.place_natural(parent, terrain, scene_root, PALM_CLUSTER, "DistrictPalm_%d_%d" % [i, j], center + offset, angle, Vector3.ONE, 0.18, false)


static func make_plaza(parent: Node3D, terrain: Node, scene_root: Node, stone_material: Material, node_name: String, xz: Vector2, radius: float) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.08
	mesh.radial_segments = 32
	mesh_instance.mesh = mesh
	mesh_instance.material_override = stone_material
	parent.add_child(mesh_instance)
	PLACEMENT.own_node(mesh_instance, scene_root)
	mesh_instance.global_position = PLACEMENT.to_world(terrain, xz, 0.04)

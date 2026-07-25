@tool
class_name NpcLayout
extends RefCounted

## NPC placement. Unlike every other layout category, this is idempotent:
## existing NPCs are never deleted/recreated, so hand-authored data set on a
## placed NPC (dialogue_sequence, or anything else) survives future
## regenerates/reloads. The parent node this places into is AuthoredIslandLayout's
## "NPCs" child, which its _clear() explicitly spares from the wipe-and-rebuild
## cycle every other category goes through — see AuthoredIslandLayout.gd.

const PLACEMENT: GDScript = preload("res://scripts/world/layout/PlacementPrimitives.gd")

## Name of the spared child AuthoredIslandLayout._clear() must not delete.
## Referenced from there via NPC_LAYOUT.CONTAINER_NAME rather than a second
## hardcoded literal, so the two can't drift out of sync.
const CONTAINER_NAME := "NPCs"

const NPC_VILLAGER: PackedScene = preload("res://Scenes/Characters/NPC/NpcVillager.tscn")
const NPC_FISHER: PackedScene = preload("res://Scenes/Characters/NPC/NpcFisher.tscn")
const NPC_GUARD: PackedScene = preload("res://Scenes/Characters/NPC/NpcGuard.tscn")

## Relative to the NPC container node (AuthoredLayout/NPCs/<npc>), three
## levels up reaches Island, then into Terrain/TerrainMesh — same depth as
## the original AuthoredLayout/TemporaryNPCs/<npc> nesting.
const NPC_TERRAIN_PATH := NodePath("../../../Terrain/TerrainMesh")


static func ensure_npcs_placed(parent: Node3D, terrain: Node, scene_root: Node, harbour: Vector2, heart: Vector2, residential: Vector2, lighthouse: Vector2) -> void:
	_ensure_npc(parent, terrain, scene_root, NPC_FISHER, "HarbourFisherA", harbour + Vector2(-4.0, 2.0))
	_ensure_npc(parent, terrain, scene_root, NPC_FISHER, "HarbourFisherB", harbour + Vector2(4.0, -2.0))
	_ensure_npc(parent, terrain, scene_root, NPC_VILLAGER, "VillageVillagerA", heart + Vector2(-3.0, 3.0))
	_ensure_npc(parent, terrain, scene_root, NPC_VILLAGER, "VillageVillagerB", heart + Vector2(4.0, 4.0))
	_ensure_npc(parent, terrain, scene_root, NPC_VILLAGER, "VillageVillagerC", heart + Vector2(1.0, -5.0))
	_ensure_npc(parent, terrain, scene_root, NPC_VILLAGER, "SlopeResident", residential + Vector2(5.0, -2.0))
	_ensure_npc(parent, terrain, scene_root, NPC_GUARD, "LighthousePathWalker", lighthouse + Vector2(-8.0, -7.0))


static func _ensure_npc(parent: Node3D, terrain: Node, scene_root: Node, scene: PackedScene, node_name: String, xz: Vector2) -> void:
	var existing := parent.get_node_or_null(node_name)
	if existing != null:
		# Name match alone isn't enough — verify it's actually the NPC we
		# expect (PackedScene.instantiate() stamps scene_file_path on the
		# resulting root with the source .tscn's own path, so this is a
		# reliable, no-bookkeeping-required identity check) before treating
		# it as "already placed" and skipping.
		if existing.scene_file_path != scene.resource_path:
			push_warning("NpcLayout: '%s' exists but isn't an instance of %s — leaving it alone rather than overwriting; this NPC will be missing from the layout until the name conflict is resolved by hand." % [node_name, scene.resource_path])
		return

	var node: Node3D = scene.instantiate() as Node3D
	if node == null:
		return
	node.name = node_name
	parent.add_child(node)
	PLACEMENT.own_node(node, scene_root)
	node.global_position = PLACEMENT.to_world(terrain, xz, 1.0)
	node.set("terrain_path", NPC_TERRAIN_PATH)

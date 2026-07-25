@tool
class_name GameplayAnchorLayout
extends RefCounted

## Gameplay reference Marker3D points — split out of AuthoredIslandLayout.gd
## unchanged.

const PLACEMENT: GDScript = preload("res://scripts/world/layout/PlacementPrimitives.gd")


static func make_anchors(parent: Node3D, terrain: Node, scene_root: Node, harbour: Vector2, town: Vector2, heart: Vector2, residential: Vector2, lighthouse: Vector2, quiet: Vector2, inland: Vector2, wild: Vector2) -> void:
	PLACEMENT.make_marker(parent, terrain, scene_root, "PlayerStart_LayoutReference", Vector2(0.0, 0.0))
	PLACEMENT.make_marker(parent, terrain, scene_root, "HarbourEntrance", harbour)
	PLACEMENT.make_marker(parent, terrain, scene_root, "VillageHeart", heart)
	PLACEMENT.make_marker(parent, terrain, scene_root, "LighthouseEntrance", lighthouse + (residential - lighthouse).normalized() * 8.0)
	PLACEMENT.make_marker(parent, terrain, scene_root, "FuturePirateLanding", harbour + harbour.normalized() * 18.0)
	PLACEMENT.make_marker(parent, terrain, scene_root, "FutureCivilianGatheringPoint", heart + Vector2(3.0, 3.0))
	PLACEMENT.make_marker(parent, terrain, scene_root, "FutureHorrorEventStaging", wild)
	PLACEMENT.make_marker(parent, terrain, scene_root, "FutureBattleTransitionTrigger", town.lerp(harbour, 0.45))
	PLACEMENT.make_marker(parent, terrain, scene_root, "QuietCoastAnchor", quiet)
	PLACEMENT.make_marker(parent, terrain, scene_root, "InlandGreenAnchor", inland)
	PLACEMENT.make_marker(parent, terrain, scene_root, "ZakoHouse", town + Vector2(-6.0, 4.0))

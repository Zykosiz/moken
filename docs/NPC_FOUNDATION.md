# NPC Foundation

This prototype uses a small project-owned NPC stack instead of duplicating the player controller.

## Scenes

- `res://Scenes/Characters/Rigs/HumanoidRig.tscn` loads the Real Controller humanoid visual rig at runtime and keeps only the visual and animation nodes.
- `res://Scenes/Characters/NPC/NpcBase.tscn` is the reusable NPC root with `CharacterBody3D`, collision, `NavigationAgent3D`, `VisualRoot/HumanoidRig`, animation driver, interaction area, and an optional debug marker.
- `NpcVillager.tscn`, `NpcFisher.tscn`, and `NpcGuard.tscn` instance `NpcBase.tscn` and only override simple exported settings.

## Scripts

- `NpcBase.gd` owns NPC identity, interaction signals, terrain snapping, basic movement, and destination assignment.
- `NpcAnimationController.gd` drives idle/walk/run animation blending from NPC velocity only. It does not read `Input`.
- `NpcWander.gd` sends an NPC between explicit waypoint `NodePath`s with a wait between stops.
- `TerrainPlacement.gd` is a tiny shared helper for snapping `Node3D`s to terrain objects that expose `get_height(x, z)`.

## Replacing The Model

Swap the implementation inside `HumanoidRig.tscn` or point its `source_scene` export at a different humanoid scene. Keep the public animation setup stable if NPCs should continue using `NpcAnimationController.gd`.

## World Test

`Scenes/World.tscn` contains:

- one stationary villager near the spawn area
- one stationary fisher near the spawn area
- one guard using explicit wander waypoints

Each NPC snaps to the island using `IslandMesh.get_height`, so placement does not depend on hardcoded Y values.

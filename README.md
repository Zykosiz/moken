# Pelagic

Pelagic is a small 3D island prototype built in Godot. It currently focuses on a procedural tropical island, simple water and terrain shaders, scattered foliage and rocks, and a third-person character controller for walking around the island.

## Project Notes

- Main scene: `res://Scenes/World.tscn`
- Player scene: `res://Scenes/Characters/Player.tscn`
- Terrain generator: `res://scripts/world/IslandMesh.gd`
- The large external `Assets/` and `Reference/` folders are intentionally ignored by Git.
- The Real Controller addon is included under `res://addons/real-controller/` because the active player scene depends on it.

## Controls

- Move: `W`, `A`, `S`, `D`
- Jump: `Space`
- Sprint: `Left Shift`
- Walk: `Left Alt`
- Camera: mouse
- Release mouse: `Esc`

## Running

Open the project in Godot and run `Scenes/World.tscn`.

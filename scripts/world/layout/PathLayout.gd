@tool
class_name PathLayout
extends RefCounted

## Path placement along point sequences — split out of AuthoredIslandLayout.gd.
## Renders as a single terrain-following flat-colored ribbon rather than
## individual tile meshes, which read as visual clutter once tiled across a
## long path. See docs/ISLAND_LAYOUT.md.

const TERRAIN_PLACEMENT: GDScript = preload("res://scripts/world/TerrainPlacement.gd")
const PLACEMENT: GDScript = preload("res://scripts/world/layout/PlacementPrimitives.gd")

const SAMPLE_SPACING := 1.5
const SURFACE_OFFSET := 0.05


static func make_path(parent: Node3D, terrain: Node, scene_root: Node, path_name: String, points: Array, width: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	var uv_distance := 0.0
	for i in range(points.size() - 1):
		uv_distance = _add_segment(surface, terrain, points[i], points[i + 1], width, uv_distance)

	surface.generate_normals()
	var mesh := surface.commit()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = path_name
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	PLACEMENT.own_node(mesh_instance, scene_root)


## Appends one terrain-sampled quad strip to the ribbon and returns the
## running UV distance so consecutive segments tile continuously along a
## multi-point path instead of resetting their texture coordinates.
static func _add_segment(surface: SurfaceTool, terrain: Node, from_point: Vector2, to_point: Vector2, width: float, start_uv_distance: float) -> float:
	var distance: float = from_point.distance_to(to_point)
	if distance < 0.01:
		return start_uv_distance

	var direction: Vector2 = (to_point - from_point).normalized()
	var perpendicular: Vector2 = Vector2(direction.y, -direction.x) * (width * 0.5)
	var step_count: int = maxi(1, int(round(distance / SAMPLE_SPACING)))
	var step_distance: float = distance / float(step_count)

	var previous_left := Vector3.ZERO
	var previous_right := Vector3.ZERO
	var previous_uv := start_uv_distance
	var uv_distance := start_uv_distance

	for step in range(step_count + 1):
		var t: float = float(step) / float(step_count)
		var xz: Vector2 = from_point.lerp(to_point, t)
		var left: float = TERRAIN_PLACEMENT.terrain_height(terrain, xz + perpendicular)
		var right: float = TERRAIN_PLACEMENT.terrain_height(terrain, xz - perpendicular)
		var left_point := Vector3(xz.x + perpendicular.x, left + SURFACE_OFFSET, xz.y + perpendicular.y)
		var right_point := Vector3(xz.x - perpendicular.x, right + SURFACE_OFFSET, xz.y - perpendicular.y)

		if step > 0:
			_add_quad(surface, previous_left, previous_right, left_point, right_point, previous_uv, uv_distance)

		previous_left = left_point
		previous_right = right_point
		previous_uv = uv_distance
		uv_distance += step_distance

	return uv_distance


static func _add_quad(surface: SurfaceTool, a_left: Vector3, a_right: Vector3, b_left: Vector3, b_right: Vector3, u0: float, u1: float) -> void:
	surface.set_uv(Vector2(0.0, u0))
	surface.add_vertex(a_left)
	surface.set_uv(Vector2(1.0, u0))
	surface.add_vertex(a_right)
	surface.set_uv(Vector2(1.0, u1))
	surface.add_vertex(b_right)

	surface.set_uv(Vector2(0.0, u0))
	surface.add_vertex(a_left)
	surface.set_uv(Vector2(1.0, u1))
	surface.add_vertex(b_right)
	surface.set_uv(Vector2(0.0, u1))
	surface.add_vertex(b_left)

@tool
class_name IslandMesh
extends MeshInstance3D

@export_group("Shape")
@export var island_radius: float = 110.0
@export var terrain_size: float = 280.0
@export var resolution: int = 100
@export var coastline_irregularity: float = 20.0
@export var beach_falloff_start: float = 0.72
@export var underwater_falloff_distance: float = 80.0
@export var max_seabed_depth: float = 9.0

@export_group("Hills")
@export var height_amplitude: float = 24.0
@export var noise_frequency: float = 0.013
@export var noise_seed: int = 1337

@export_group("Coloring")
@export var sand_color: Color = Color(0.87, 0.78, 0.58)
@export var wet_sand_color: Color = Color(0.72, 0.62, 0.44)
@export var grass_low_color: Color = Color(0.42, 0.62, 0.28)
@export var grass_high_color: Color = Color(0.24, 0.44, 0.22)
@export var rock_color: Color = Color(0.5, 0.47, 0.44)
@export var cliff_color: Color = Color(0.38, 0.35, 0.33)
@export var sand_level: float = 1.4
@export var grass_level: float = 10.0
@export var rock_level: float = 19.0
@export var cliff_slope_threshold: float = 0.55

@export_group("Collision")
@export var collision_shape_path: NodePath

@export var regenerate: bool = false : set = _set_regenerate

var _height_noise := FastNoiseLite.new()
var _edge_noise := FastNoiseLite.new()


func _ready() -> void:
	_configure_noise()
	if mesh == null:
		_generate_mesh()


func _set_regenerate(value: bool) -> void:
	if value:
		_configure_noise()
		_generate_mesh()
	regenerate = false


func _configure_noise() -> void:
	_height_noise.seed = noise_seed
	_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_height_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_height_noise.fractal_octaves = 4
	_height_noise.frequency = noise_frequency

	_edge_noise.seed = noise_seed + 91
	_edge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_edge_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_edge_noise.fractal_octaves = 2
	_edge_noise.frequency = 1.0


# Returns Vector2(height, land_mask) so height + placement queries share one noise sample.
# height is mathematically guaranteed >= 0 anywhere land_mask > 0, so the interior of
# the island can never dip below sea level.
func _sample_raw(x: float, z: float) -> Vector2:
	var angle := atan2(z, x)
	var edge_variation := _edge_noise.get_noise_2d(cos(angle) * 3.0, sin(angle) * 3.0)
	var local_radius: float = island_radius + edge_variation * coastline_irregularity
	var dist := Vector2(x, z).length()
	var t: float = dist / max(local_radius, 1.0)

	var land_mask: float = clamp(1.0 - smoothstep(beach_falloff_start, 1.0, t), 0.0, 1.0)

	var hill_noise: float = clamp(_height_noise.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
	var land_height: float = hill_noise * height_amplitude * land_mask * land_mask

	var height: float
	if t <= 1.0:
		height = land_height
	else:
		var beyond: float = clamp((t - 1.0) * local_radius / max(underwater_falloff_distance, 1.0), 0.0, 1.0)
		var eased: float = beyond * beyond * (3.0 - 2.0 * beyond)
		height = lerp(0.0, -max_seabed_depth, eased)

	return Vector2(height, land_mask)


func get_height(x: float, z: float) -> float:
	return _sample_raw(x, z).x


func get_land_mask(x: float, z: float) -> float:
	return _sample_raw(x, z).y


func get_normal(x: float, z: float, epsilon: float = 1.0) -> Vector3:
	var h_left := get_height(x - epsilon, z)
	var h_right := get_height(x + epsilon, z)
	var h_down := get_height(x, z - epsilon)
	var h_up := get_height(x, z + epsilon)
	return Vector3(h_left - h_right, 2.0 * epsilon, h_down - h_up).normalized()


# Rejection-samples a valid land point for foliage/rock scatter, so every scattered
# object sits exactly on the generated surface.
func sample_scatter_point(rng: RandomNumberGenerator, min_mask: float, max_mask: float, max_slope_deg: float, max_attempts: int = 40) -> Dictionary:
	var half: float = terrain_size * 0.5 * 0.96
	var max_slope_dot := cos(deg_to_rad(max_slope_deg))
	for attempt in max_attempts:
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		var sample := _sample_raw(x, z)
		var mask: float = sample.y
		if mask < min_mask or mask > max_mask:
			continue
		var normal := get_normal(x, z)
		if normal.y < max_slope_dot:
			continue
		return {"position": Vector3(x, sample.x, z), "normal": normal}
	return {}


func _height_color(height: float, normal: Vector3, mask: float) -> Color:
	var slope := 1.0 - normal.y
	var base_color: Color
	if mask < 0.02:
		base_color = wet_sand_color
	elif height < sand_level:
		var wetness: float = clamp(1.0 - (height / max(sand_level, 0.001)), 0.0, 1.0) * (1.0 - mask)
		base_color = sand_color.lerp(wet_sand_color, wetness)
	elif height < grass_level:
		var ratio: float = (height - sand_level) / max(grass_level - sand_level, 0.001)
		base_color = sand_color.lerp(grass_low_color, clamp(ratio, 0.0, 1.0))
	elif height < rock_level:
		var ratio: float = (height - grass_level) / max(rock_level - grass_level, 0.001)
		base_color = grass_low_color.lerp(grass_high_color, clamp(ratio, 0.0, 1.0))
	else:
		var ratio: float = clamp((height - rock_level) / max(height_amplitude - rock_level, 0.001), 0.0, 1.0)
		base_color = grass_high_color.lerp(rock_color, ratio)

	if slope > cliff_slope_threshold:
		var cliff_ratio: float = clamp((slope - cliff_slope_threshold) / (1.0 - cliff_slope_threshold), 0.0, 1.0)
		base_color = base_color.lerp(cliff_color, cliff_ratio)

	return base_color


func _generate_mesh() -> void:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half: float = terrain_size * 0.5
	var step: float = terrain_size / float(resolution)
	var vertex_count := resolution + 1

	for zi in vertex_count:
		for xi in vertex_count:
			var x: float = -half + xi * step
			var z: float = -half + zi * step
			var sample := _sample_raw(x, z)
			var height: float = sample.x
			var mask: float = sample.y
			var normal := get_normal(x, z, step * 0.5)
			var color := _height_color(height, normal, mask)

			surface_tool.set_color(color)
			surface_tool.set_uv(Vector2(x, z) / 8.0)
			surface_tool.set_normal(normal)
			surface_tool.add_vertex(Vector3(x, height, z))

	for zi in resolution:
		for xi in resolution:
			var i0 := zi * vertex_count + xi
			var i1 := i0 + 1
			var i2 := i0 + vertex_count
			var i3 := i2 + 1
			surface_tool.add_index(i0)
			surface_tool.add_index(i1)
			surface_tool.add_index(i2)
			surface_tool.add_index(i1)
			surface_tool.add_index(i3)
			surface_tool.add_index(i2)

	var array_mesh := surface_tool.commit()
	mesh = array_mesh
	_update_collision(array_mesh)


func _update_collision(source_mesh: Mesh) -> void:
	if collision_shape_path.is_empty():
		push_warning("IslandMesh: collision_shape_path is not assigned, skipping collision generation.")
		return
	var collision_shape := get_node_or_null(collision_shape_path)
	if collision_shape == null or not (collision_shape is CollisionShape3D):
		push_warning("IslandMesh: collision_shape_path does not point to a CollisionShape3D.")
		return
	collision_shape.shape = source_mesh.create_trimesh_shape()

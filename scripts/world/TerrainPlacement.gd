@tool
class_name WorldTerrainPlacement
extends RefCounted

const MIN_BUILDING_NORMAL_Y := 0.66


class FootprintResult:
	extends RefCounted

	var center: Vector2 = Vector2.ZERO
	var yaw: float = 0.0
	var footprint: Vector2 = Vector2.ONE
	var center_height: float = 0.0
	var min_height: float = 0.0
	var max_height: float = 0.0
	var average_height: float = 0.0
	var height_delta: float = 0.0
	var average_normal: Vector3 = Vector3.UP
	var valid: bool = false


static func terrain_height(terrain: Node, xz: Vector2) -> float:
	if terrain == null or not terrain.has_method("get_height"):
		return 0.0
	return float(terrain.call("get_height", xz.x, xz.y))


static func terrain_normal(terrain: Node, xz: Vector2) -> Vector3:
	if terrain == null or not terrain.has_method("get_normal"):
		return Vector3.UP
	var normal: Vector3 = terrain.call("get_normal", xz.x, xz.y)
	if normal.length_squared() < 0.001:
		return Vector3.UP
	return normal.normalized()


static func sample_footprint(terrain: Node, center: Vector2, yaw: float, footprint: Vector2) -> FootprintResult:
	var result := FootprintResult.new()
	result.center = center
	result.yaw = yaw
	result.footprint = footprint

	var half := footprint * 0.5
	var points: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(-half.x, half.y),
		Vector2(half.x, half.y),
		Vector2(0.0, -half.y),
		Vector2(0.0, half.y),
		Vector2(-half.x, 0.0),
		Vector2(half.x, 0.0),
	]

	var first := true
	var height_sum := 0.0
	var normal_sum := Vector3.ZERO
	for local_point in points:
		var sample_xz := center + _rotate_2d(local_point, yaw)
		var height := terrain_height(terrain, sample_xz)
		if first:
			result.min_height = height
			result.max_height = height
			first = false
		else:
			result.min_height = min(result.min_height, height)
			result.max_height = max(result.max_height, height)
		height_sum += height
		normal_sum += terrain_normal(terrain, sample_xz)

	result.center_height = terrain_height(terrain, center)
	result.average_height = height_sum / float(points.size())
	result.height_delta = result.max_height - result.min_height
	result.average_normal = normal_sum.normalized() if normal_sum.length_squared() > 0.001 else Vector3.UP
	result.valid = true
	return result


static func is_building_footprint_valid(result: FootprintResult, max_height_delta: float, min_normal_y: float = MIN_BUILDING_NORMAL_Y) -> bool:
	if result == null or not result.valid:
		return false
	return result.height_delta <= max_height_delta and result.average_normal.y >= min_normal_y


static func find_nearby_valid_building(
	terrain: Node,
	center: Vector2,
	yaw: float,
	footprint: Vector2,
	max_height_delta: float,
	search_radius: float = 12.0,
	step: float = 2.0,
	min_normal_y: float = MIN_BUILDING_NORMAL_Y
) -> FootprintResult:
	var best := sample_footprint(terrain, center, yaw, footprint)
	if is_building_footprint_valid(best, max_height_delta, min_normal_y):
		return best

	var best_score := -100000.0
	var count := int(ceil(search_radius / step))
	for xi in range(-count, count + 1):
		for zi in range(-count, count + 1):
			var offset := Vector2(float(xi) * step, float(zi) * step)
			if offset.length() > search_radius:
				continue
			var candidate := center + offset
			var sampled := sample_footprint(terrain, candidate, yaw, footprint)
			if not is_building_footprint_valid(sampled, max_height_delta, min_normal_y):
				continue
			var distance_score: float = 1.0 - offset.length() / max(search_radius, 0.001)
			var slope_score: float = 1.0 - sampled.height_delta / max(max_height_delta, 0.001)
			var score: float = distance_score * 3.0 + slope_score + sampled.average_normal.y
			if score > best_score:
				best_score = score
				best = sampled
	return best


static func apply_upright(node: Node3D, result: FootprintResult, surface_offset: float, scale_value: Vector3) -> void:
	node.global_position = Vector3(result.center.x, result.average_height + surface_offset, result.center.y)
	node.rotation = Vector3(0.0, result.yaw, 0.0)
	node.scale = scale_value


static func apply_surface(
	node: Node3D,
	terrain: Node,
	xz: Vector2,
	yaw: float,
	surface_offset: float,
	scale_value: Vector3,
	normal_alignment_strength: float
) -> void:
	var height := terrain_height(terrain, xz)
	var normal := terrain_normal(terrain, xz)
	node.global_position = Vector3(xz.x, height + surface_offset, xz.y)
	node.global_basis = blended_normal_basis(yaw, normal, normal_alignment_strength).scaled(scale_value)


static func yaw_towards(from_xz: Vector2, target_xz: Vector2) -> float:
	var direction := target_xz - from_xz
	if direction.length_squared() < 0.001:
		return 0.0
	return atan2(direction.x, direction.y)


static func blended_normal_basis(yaw: float, normal: Vector3, strength: float) -> Basis:
	var clamped_strength := clampf(strength, 0.0, 1.0)
	var up := Vector3.UP.lerp(normal.normalized(), clamped_strength).normalized()
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	forward = (forward - up * forward.dot(up)).normalized()
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	var right := up.cross(forward).normalized()
	forward = right.cross(up).normalized()
	return Basis(right, up, forward)


static func _rotate_2d(point: Vector2, yaw: float) -> Vector2:
	var c := cos(yaw)
	var s := sin(yaw)
	return Vector2(point.x * c - point.y * s, point.x * s + point.y * c)

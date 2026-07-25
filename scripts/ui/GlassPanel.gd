class_name GlassPanel
extends Control

## See docs/UI_FOUNDATION.md for the design rules this component encodes.
## Base reusable "fractured glass" panel: irregular silhouette, frosted
## background, reflection sweep, layerable fracture overlay, selection state,
## and Horror corruption — all driven by shader uniforms plus accessibility
## settings. Content should be added under ContentMargin so it stays aligned
## to the real layout grid; per the doc's hard rules, important numbers must
## never be placed so they cross a fracture line — that's a placement
## responsibility for whatever screen builds on top of this component.

enum ShardVariant { A, B, C, D }

## Curated seed presets so designers pick a named look in the Inspector
## instead of typing raw floats. The underlying silhouette math stays fully
## procedural — these are just seeds chosen to look visually distinct.
const _VARIANT_SEEDS := {
	ShardVariant.A: 12.0,
	ShardVariant.B: 87.0,
	ShardVariant.C: 234.0,
	ShardVariant.D: 501.0,
}

@export var shard_variant: ShardVariant = ShardVariant.A:
	set(value):
		shard_variant = value
		_apply_shard_seed()

@export var base_opacity: float = 0.35:
	set(value):
		base_opacity = value
		_set_param(_background_material, "base_opacity", base_opacity)

@export var edge_irregularity: float = 0.45:
	set(value):
		edge_irregularity = value
		_set_param(_background_material, "edge_irregularity", edge_irregularity)

@export var detail_size_px: float = 18.0:
	set(value):
		detail_size_px = value
		_set_param(_background_material, "detail_size_px", detail_size_px)

@export var use_horror_preset_by_default: bool = false

@export_group("Content Margins")
@export var content_margin: int = 16:
	set(value):
		content_margin = value
		_apply_content_margins()

@onready var _background: ColorRect = $Background
@onready var _fracture_overlay: ColorRect = $FractureOverlay
@onready var _content_margin_node: MarginContainer = $ContentMargin
@onready var _back_buffer: BackBufferCopy = $BackBufferCopy

var _background_material: ShaderMaterial
var _fracture_material: ShaderMaterial

var _selected: bool = false
var _horror_amount: float = 0.0
var _base_position: Vector2
var _selection_tween: Tween


func _ready() -> void:
	# CRITICAL: duplicate materials per-instance. Without this, every
	# GlassPanel in the scene shares one live ShaderMaterial resource and
	# stomps each other's uniforms (selection state, horror amount, seed...)
	# on every set.
	var source_material: ShaderMaterial = (
		preload("res://Scenes/UI/Materials/GlassReflection_Horror.tres")
		if use_horror_preset_by_default
		else preload("res://Scenes/UI/Materials/GlassReflection_Normal.tres")
	)
	_background_material = source_material.duplicate() as ShaderMaterial
	_background.material = _background_material

	var fracture_shader_material := ShaderMaterial.new()
	fracture_shader_material.shader = preload("res://shaders/ui/glass_fracture_overlay.gdshader")
	_fracture_material = fracture_shader_material
	_fracture_overlay.material = _fracture_material

	_base_position = position

	_apply_shard_seed()
	_apply_content_margins()
	_set_param(_background_material, "base_opacity", base_opacity)
	_set_param(_background_material, "edge_irregularity", edge_irregularity)
	_set_param(_background_material, "detail_size_px", detail_size_px)

	resized.connect(_on_resized)
	_on_resized()

	UIAccessibility.settings_changed.connect(_on_accessibility_changed)
	_on_accessibility_changed()


func set_selected(selected: bool) -> void:
	if _selected == selected:
		return

	if selected:
		# Refresh right before use rather than trusting the _ready()/resized
		# snapshot: `resized` only fires on size changes, not the position a
		# parent Container assigns once it finishes laying out children (e.g.
		# CenterContainer/VBoxContainer), so the cached value can be stale by
		# the time of the first hover. Safe to recapture here since we're not
		# currently selected — `position` right now is the true rest position.
		_base_position = position

	_selected = selected

	var target_selection := 1.0 if selected else 0.0
	if _selection_tween != null and _selection_tween.is_valid():
		_selection_tween.kill()
	_selection_tween = create_tween().set_parallel(true)
	_selection_tween.tween_method(
		func(v: float) -> void: _set_param(_background_material, "selection_amount", v),
		_get_param(_background_material, "selection_amount", 0.0),
		target_selection,
		0.15,
	)

	# Layout-level "separation from neighboring panes" — a shader alone can't
	# move the Control relative to siblings. Tweened relative to the cached
	# base position (set once in _ready/_on_resized), not the current live
	# position, so repeated select/deselect calls never drift. Suppressed
	# under Reduced Motion — the opacity/edge-highlight tween above still
	# runs (the doc lists those as valid non-motion selection signals), only
	# the physical bounce is motion in the sense the accessibility setting
	# means to suppress.
	var target_offset := Vector2.ZERO
	if selected and not UIAccessibility.reduced_motion:
		target_offset = Vector2(0.0, -6.0)
	_selection_tween.tween_property(self, "position", _base_position + target_offset, 0.15)


func set_horror_amount(amount: float) -> void:
	_horror_amount = clampf(amount, 0.0, 1.0)
	_set_param(_background_material, "horror_mix", _horror_amount)
	_set_param(_background_material, "horror_drift", _horror_amount)
	_set_param(_fracture_material, "horror_mix", _horror_amount)
	_set_param(_fracture_material, "crack_intensity", lerpf(0.15, 0.9, _horror_amount))
	_update_fracture_visibility()


func set_background_busyness(amount: float) -> void:
	_set_param(_background_material, "background_busyness", clampf(amount, 0.0, 1.0))


func _apply_shard_seed() -> void:
	var seed_value: float = _VARIANT_SEEDS.get(shard_variant, 0.0)
	_set_param(_background_material, "shard_seed", seed_value)
	_set_param(_fracture_material, "shard_seed", seed_value)


func _apply_content_margins() -> void:
	if _content_margin_node == null:
		return
	for side in ["left", "top", "right", "bottom"]:
		_content_margin_node.add_theme_constant_override("margin_%s" % side, content_margin)


func _on_resized() -> void:
	_base_position = position
	_set_param(_background_material, "rect_size_px", size)
	_set_param(_fracture_material, "rect_size_px", size)
	if _back_buffer != null:
		_back_buffer.rect = Rect2(Vector2.ZERO, size)


func _on_accessibility_changed() -> void:
	var motion_scale: float = 0.15 if UIAccessibility.reduced_motion else 1.0
	var refraction_scale: float = 0.0 if UIAccessibility.reduced_motion else 1.0
	var distortion_scale: float = 0.2 if UIAccessibility.reduced_motion else 1.0
	var min_opacity_floor: float = 0.75 if UIAccessibility.high_readability else 0.0

	_set_param(_background_material, "motion_scale", motion_scale)
	_set_param(_background_material, "refraction_scale", refraction_scale)
	_set_param(_background_material, "distortion_scale", distortion_scale)
	_set_param(_background_material, "min_opacity_floor", min_opacity_floor)
	_set_param(_fracture_material, "distortion_scale", distortion_scale)

	_update_fracture_visibility()


func _update_fracture_visibility() -> void:
	if _fracture_overlay == null:
		return
	# Cheap extra win: fully hide the fracture overlay when motion is reduced
	# and no Horror event is active, rather than just letting alpha go to
	# ~0 — saves the Voronoi fragment cost on accessibility-first setups.
	_fracture_overlay.visible = not (UIAccessibility.reduced_motion and _horror_amount <= 0.01)


func _set_param(material: ShaderMaterial, param: StringName, value: Variant) -> void:
	if material != null:
		material.set_shader_parameter(param, value)


func _get_param(material: ShaderMaterial, param: StringName, default_value: Variant) -> Variant:
	if material == null:
		return default_value
	var value: Variant = material.get_shader_parameter(param)
	return default_value if value == null else value

class_name SavePoint
extends Area3D

signal saved(save_point_id: String, slot: int)

const GLOW_COLOR := Color(0.25, 0.85, 1.0, 1.0)
const GLOW_ENERGY := 1.4

@export var save_point_id: String = ""
@export var interaction_prompt: String = "Save"
@export var apply_glow_override: bool = true

var _glow_material: StandardMaterial3D


func _enter_tree() -> void:
	if save_point_id.is_empty():
		save_point_id = name
	add_to_group("save_points")


func _ready() -> void:
	if apply_glow_override:
		_glow_material = _make_glow_material()
		_apply_glow_to_meshes(self)


func interact(actor: Node = null) -> void:
	var target_slot := SaveManager.active_slot
	var success := SaveManager.save_game(save_point_id)
	if success:
		saved.emit(save_point_id, target_slot)
		print("Saved at '%s' (slot %d)" % [save_point_id, target_slot])
	else:
		push_warning("SavePoint '%s': save failed" % save_point_id)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if save_point_id.is_empty():
		warnings.append("save_point_id is empty; it will default to the node name '%s' at runtime. Set it explicitly — node names are only auto-uniquified among SIBLINGS, not across the whole scene." % name)
	return warnings


func _apply_glow_to_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			var mesh := mesh_instance.mesh
			if mesh != null:
				for surface_index in mesh.get_surface_count():
					mesh_instance.set_surface_override_material(surface_index, _glow_material)
		_apply_glow_to_meshes(child)


func _make_glow_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = GLOW_COLOR
	material.emission_enabled = true
	material.emission = GLOW_COLOR
	material.emission_energy_multiplier = GLOW_ENERGY
	return material

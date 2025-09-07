extends Node

# Signal emitted when a technical rendering mode (Normal/Specular) is selected
signal technical_mode_selected(mode_name: String)

const NORMAL_MATERIAL = preload("res://PixelRenderer/data/NormalMaterial.tres")
const SPECULAR_MATERIAL = preload("res://PixelRenderer/data/SpecularMaterial.tres")

@onready var models_spawner: Node3D = %ModelsSpawner
@onready var view_mode_dropdown : OptionButton = %ViewModeDropDown

func item_selected(index : int):
	var meshes = get_all_mesh_instances(get_all_children(models_spawner))
	var selected_mode = view_mode_dropdown.get_item_text(index)
	
	match selected_mode:
		"Albedo":
			for mesh in meshes:
				mesh.set_surface_override_material(0, null)
		"Normal":
			for mesh in meshes:
				mesh.set_surface_override_material(0, NORMAL_MATERIAL)
			# Emit signal for technical mode selection
			technical_mode_selected.emit("Normal")
		"Specular":
			for mesh in meshes:
				mesh.set_surface_override_material(0, SPECULAR_MATERIAL)
			# Emit signal for technical mode selection
			technical_mode_selected.emit("Specular")
			
			
			
func get_all_children(node) -> Array:
	var nodes : Array = []
	for N in node.get_children():
		if N.get_child_count() > 0:
			nodes.append(N)
			nodes.append_array(get_all_children(N))
		else:
			nodes.append(N)
	return nodes

func get_all_mesh_instances(array : Array) -> Array[MeshInstance3D]:
	var mesh_instances : Array[MeshInstance3D] = []
	
	for N in array:
		if N is MeshInstance3D:
			mesh_instances.append(N)
	return mesh_instances

extends Control


@onready var button_axis: Button = %Button_Axis
@onready var button_origin: Button = %Button_Origin
@onready var button_floor: Button = %Button_Floor

@onready var axis: MeshInstance3D = %Axis
@onready var grid: MeshInstance3D = %Grid
@onready var origin: MeshInstance3D = %Origin

@onready var floor_color_picker: ColorPickerButton = %FloorColorPicker

const GIZMO = preload("res://PixelRenderer/data/Gizmo.tres")

# Toggle states - default to false (off)
var axis_visible: bool = false
var origin_visible: bool = false
var floor_visible: bool = false

# Color constants for visual feedback
const BUTTON_NORMAL_COLOR = Color.WHITE
const BUTTON_PRESSED_COLOR = Color(0.8, 0.7, 0.3, 1.0)  # Muted yellow

func _ready():
	# Connect button signals
	button_axis.pressed.connect(_on_axis_button_pressed)
	button_origin.pressed.connect(_on_origin_button_pressed)
	button_floor.pressed.connect(_on_floor_button_pressed)
	
	# Connect color picker signal
	floor_color_picker.color_changed.connect(_on_floor_color_changed)
	
	# Set initial mesh visibility to match default states
	axis.visible = axis_visible
	origin.visible = origin_visible
	grid.visible = floor_visible
	
	# Set initial button states and colors
	_update_button_appearance(button_axis, axis_visible)
	_update_button_appearance(button_origin, origin_visible)
	_update_button_appearance(button_floor, floor_visible)
	
	# Set initial gizmo material color
	_update_gizmo_color(floor_color_picker.color)

func _on_axis_button_pressed():
	axis_visible = !axis_visible
	_update_button_appearance(button_axis, axis_visible)
	axis.visible = axis_visible

func _on_origin_button_pressed():
	origin_visible = !origin_visible
	_update_button_appearance(button_origin, origin_visible)
	origin.visible = origin_visible

func _on_floor_button_pressed():
	floor_visible = !floor_visible
	_update_button_appearance(button_floor, floor_visible)
	grid.visible = floor_visible

func _on_floor_color_changed(color: Color):
	_update_gizmo_color(color)

func _update_gizmo_color(color: Color):
	# Update the gizmo material's albedo color for all gizmo meshes
	# We need to access the surface material from each mesh instance
	_update_mesh_material_color(axis, color)
	_update_mesh_material_color(grid, color)
	_update_mesh_material_color(origin, color)
	
	# Also update any child mesh instances (for the origin's multiple meshes)
	for child in origin.get_children():
		if child is MeshInstance3D:
			_update_mesh_material_color(child, color)

func _update_mesh_material_color(mesh_instance: MeshInstance3D, color: Color):
	# Get the surface material (it should be the gizmo material)
	var surface_material = mesh_instance.get_surface_override_material(0)
	if surface_material and surface_material is StandardMaterial3D:
		# Create a duplicate if it's the shared resource to avoid modifying the original
		if surface_material == GIZMO:
			surface_material = surface_material.duplicate()
			mesh_instance.set_surface_override_material(0, surface_material)
		surface_material.albedo_color = color

func _update_button_appearance(button: Button, is_active: bool):
	if is_active:
		button.modulate = BUTTON_PRESSED_COLOR
	else:
		button.modulate = BUTTON_NORMAL_COLOR

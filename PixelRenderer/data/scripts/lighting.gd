extends Control

@onready var key_light_check_button: CheckButton = %KeyLightCheckButton
@onready var key_light_spin_box: SpinBox = %KeyLightSpinBox
@onready var key_light_color_picker_button: ColorPickerButton = %KeyLightColorPickerButton
@onready var key_light_rot_spin: SpinBox = %KeyLightRotSpin
@onready var key_light_reset_button: Button = %KeyLightResetButton
@onready var fill_light_check_button: CheckButton = %FillLightCheckButton
@onready var fill_light_spin_box: SpinBox = %FillLightSpinBox
@onready var fill_light_color_picker_button: ColorPickerButton = %FillLightColorPickerButton
@onready var fill_light_rot_spin: SpinBox = %FillLightRotSpin
@onready var fill_light_reset_button: Button = %FillLightResetButton
@onready var rim_light_check_button: CheckButton = %RimLightCheckButton
@onready var rim_light_spin_box: SpinBox = %RimLightSpinBox
@onready var rim_light_color_picker_button: ColorPickerButton = %RimLightColorPickerButton
@onready var rim_light_rot_spin: SpinBox = %RimLightRotSpin
@onready var rim_light_reset_button: Button = %RimLightResetButton

@onready var key_light: DirectionalLight3D = %KeyLight
@onready var fill_light: DirectionalLight3D = %FillLight
@onready var rim_light: DirectionalLight3D = %RimLight

# Configuration file path for saving/loading lighting settings
const LIGHTING_CONFIG_FILE = "user://lighting_config.cfg"

# Default lighting settings
const DEFAULT_SETTINGS = {
	"key_light": {
		"enabled": true,
		"intensity": 1.0,
		"color": Color.WHITE,
		"rotation": Vector3(-60, 60, 0)
	},
	"fill_light": {
		"enabled": true,
		"intensity": 0.2,
		"color": Color.WHITE,
		"rotation": Vector3(60, -30, 0)
	},
	"rim_light": {
		"enabled": true,
		"intensity": 100.0,
		"color": Color.WHITE,
		"rotation": Vector3(-30, 160, 0)
	}
}

func _ready():
	_initialize_controls()
	_connect_signals()
	_load_settings()
	_apply_default_settings()

func _initialize_controls():
	# Initialize spin boxes with proper ranges
	key_light_spin_box.min_value = 0.0
	key_light_spin_box.max_value = 10.0
	key_light_spin_box.step = 0.1
	key_light_spin_box.value = DEFAULT_SETTINGS.key_light.intensity
	
	fill_light_spin_box.min_value = 0.0
	fill_light_spin_box.max_value = 10.0
	fill_light_spin_box.step = 0.1
	fill_light_spin_box.value = DEFAULT_SETTINGS.fill_light.intensity
	
	rim_light_spin_box.min_value = 0.0
	rim_light_spin_box.max_value = 200.0
	rim_light_spin_box.step = 1.0
	rim_light_spin_box.value = DEFAULT_SETTINGS.rim_light.intensity
	
	# Initialize rotation spin boxes
	key_light_rot_spin.min_value = -180.0
	key_light_rot_spin.max_value = 180.0
	key_light_rot_spin.step = 1.0
	key_light_rot_spin.value = 0.0
	
	fill_light_rot_spin.min_value = -180.0
	fill_light_rot_spin.max_value = 180.0
	fill_light_rot_spin.step = 1.0
	fill_light_rot_spin.value = 0.0
	
	rim_light_rot_spin.min_value = -180.0
	rim_light_rot_spin.max_value = 180.0
	rim_light_rot_spin.step = 1.0
	rim_light_rot_spin.value = 0.0
	
	# Initialize color pickers with default colors
	key_light_color_picker_button.color = DEFAULT_SETTINGS.key_light.color
	fill_light_color_picker_button.color = DEFAULT_SETTINGS.fill_light.color
	rim_light_color_picker_button.color = DEFAULT_SETTINGS.rim_light.color
	
	# Initialize check buttons
	key_light_check_button.button_pressed = DEFAULT_SETTINGS.key_light.enabled
	fill_light_check_button.button_pressed = DEFAULT_SETTINGS.fill_light.enabled
	rim_light_check_button.button_pressed = DEFAULT_SETTINGS.rim_light.enabled

func _connect_signals():
	# Key Light signals
	key_light_check_button.toggled.connect(_on_key_light_toggled)
	key_light_spin_box.value_changed.connect(_on_key_light_intensity_changed)
	key_light_color_picker_button.color_changed.connect(_on_key_light_color_changed)
	key_light_rot_spin.value_changed.connect(_on_key_light_rotation_changed)
	key_light_reset_button.pressed.connect(_on_key_light_reset)
	
	# Fill Light signals
	fill_light_check_button.toggled.connect(_on_fill_light_toggled)
	fill_light_spin_box.value_changed.connect(_on_fill_light_intensity_changed)
	fill_light_color_picker_button.color_changed.connect(_on_fill_light_color_changed)
	fill_light_rot_spin.value_changed.connect(_on_fill_light_rotation_changed)
	fill_light_reset_button.pressed.connect(_on_fill_light_reset)
	
	# Rim Light signals
	rim_light_check_button.toggled.connect(_on_rim_light_toggled)
	rim_light_spin_box.value_changed.connect(_on_rim_light_intensity_changed)
	rim_light_color_picker_button.color_changed.connect(_on_rim_light_color_changed)
	rim_light_rot_spin.value_changed.connect(_on_rim_light_rotation_changed)
	rim_light_reset_button.pressed.connect(_on_rim_light_reset)

func _apply_default_settings():
	# Apply default settings to lights
	if key_light:
		key_light.visible = DEFAULT_SETTINGS.key_light.enabled
		key_light.light_energy = DEFAULT_SETTINGS.key_light.intensity
		key_light.light_color = DEFAULT_SETTINGS.key_light.color
		key_light.rotation_degrees = DEFAULT_SETTINGS.key_light.rotation
		key_light_check_button.button_pressed = DEFAULT_SETTINGS.key_light.enabled
	
	if fill_light:
		fill_light.visible = DEFAULT_SETTINGS.fill_light.enabled
		fill_light.light_energy = DEFAULT_SETTINGS.fill_light.intensity
		fill_light.light_color = DEFAULT_SETTINGS.fill_light.color
		fill_light.rotation_degrees = DEFAULT_SETTINGS.fill_light.rotation
		fill_light_check_button.button_pressed = DEFAULT_SETTINGS.fill_light.enabled
	
	if rim_light:
		rim_light.visible = DEFAULT_SETTINGS.rim_light.enabled
		rim_light.light_energy = DEFAULT_SETTINGS.rim_light.intensity
		rim_light.light_color = DEFAULT_SETTINGS.rim_light.color
		rim_light.rotation_degrees = DEFAULT_SETTINGS.rim_light.rotation
		rim_light_check_button.button_pressed = DEFAULT_SETTINGS.rim_light.enabled

# Key Light handlers
func _on_key_light_toggled(enabled: bool):
	if key_light:
		key_light.visible = enabled
	_save_settings()

func _on_key_light_intensity_changed(value: float):
	if key_light:
		key_light.light_energy = value
	_save_settings()

func _on_key_light_color_changed(color: Color):
	if key_light:
		key_light.light_color = color
	_save_settings()

func _on_key_light_rotation_changed(z_rotation: float):
	if key_light:
		# Apply rotation around global Z-axis while preserving default X,Y rotation
		var default_rotation = DEFAULT_SETTINGS.key_light.rotation
		key_light.rotation_degrees = Vector3(default_rotation.x, default_rotation.y, default_rotation.z)
		key_light.rotate(Vector3.FORWARD, deg_to_rad(z_rotation))
	_save_settings()

func _on_key_light_reset():
	key_light_check_button.button_pressed = DEFAULT_SETTINGS.key_light.enabled
	key_light_spin_box.value = DEFAULT_SETTINGS.key_light.intensity
	key_light_color_picker_button.color = DEFAULT_SETTINGS.key_light.color
	key_light_rot_spin.value = 0.0
	if key_light:
		key_light.visible = DEFAULT_SETTINGS.key_light.enabled
		key_light.light_energy = DEFAULT_SETTINGS.key_light.intensity
		key_light.light_color = DEFAULT_SETTINGS.key_light.color
		key_light.rotation_degrees = DEFAULT_SETTINGS.key_light.rotation
	_save_settings()

# Fill Light handlers
func _on_fill_light_toggled(enabled: bool):
	if fill_light:
		fill_light.visible = enabled
	_save_settings()

func _on_fill_light_intensity_changed(value: float):
	if fill_light:
		fill_light.light_energy = value
	_save_settings()

func _on_fill_light_color_changed(color: Color):
	if fill_light:
		fill_light.light_color = color
	_save_settings()

func _on_fill_light_rotation_changed(z_rotation: float):
	if fill_light:
		# Apply rotation around global Z-axis while preserving default X,Y rotation
		var default_rotation = DEFAULT_SETTINGS.fill_light.rotation
		fill_light.rotation_degrees = Vector3(default_rotation.x, default_rotation.y, default_rotation.z)
		fill_light.rotate(Vector3.FORWARD, deg_to_rad(z_rotation))
	_save_settings()

func _on_fill_light_reset():
	fill_light_check_button.button_pressed = DEFAULT_SETTINGS.fill_light.enabled
	fill_light_spin_box.value = DEFAULT_SETTINGS.fill_light.intensity
	fill_light_color_picker_button.color = DEFAULT_SETTINGS.fill_light.color
	fill_light_rot_spin.value = 0.0
	if fill_light:
		fill_light.visible = DEFAULT_SETTINGS.fill_light.enabled
		fill_light.light_energy = DEFAULT_SETTINGS.fill_light.intensity
		fill_light.light_color = DEFAULT_SETTINGS.fill_light.color
		fill_light.rotation_degrees = DEFAULT_SETTINGS.fill_light.rotation
	_save_settings()

# Rim Light handlers
func _on_rim_light_toggled(enabled: bool):
	if rim_light:
		rim_light.visible = enabled
	_save_settings()

func _on_rim_light_intensity_changed(value: float):
	if rim_light:
		rim_light.light_energy = value
	_save_settings()

func _on_rim_light_color_changed(color: Color):
	if rim_light:
		rim_light.light_color = color
	_save_settings()

func _on_rim_light_rotation_changed(z_rotation: float):
	if rim_light:
		# Apply rotation around global Z-axis while preserving default X,Y rotation
		var default_rotation = DEFAULT_SETTINGS.rim_light.rotation
		rim_light.rotation_degrees = Vector3(default_rotation.x, default_rotation.y, default_rotation.z)
		rim_light.rotate(Vector3.FORWARD, deg_to_rad(z_rotation))
	_save_settings()

func _on_rim_light_reset():
	rim_light_check_button.button_pressed = DEFAULT_SETTINGS.rim_light.enabled
	rim_light_spin_box.value = DEFAULT_SETTINGS.rim_light.intensity
	rim_light_color_picker_button.color = DEFAULT_SETTINGS.rim_light.color
	rim_light_rot_spin.value = 0.0
	if rim_light:
		rim_light.visible = DEFAULT_SETTINGS.rim_light.enabled
		rim_light.light_energy = DEFAULT_SETTINGS.rim_light.intensity
		rim_light.light_color = DEFAULT_SETTINGS.rim_light.color
		rim_light.rotation_degrees = DEFAULT_SETTINGS.rim_light.rotation
	_save_settings()

# Settings save/load functionality
func _save_settings():
	var config = ConfigFile.new()
	
	# Save Key Light settings
	config.set_value("key_light", "enabled", key_light_check_button.button_pressed)
	config.set_value("key_light", "intensity", key_light_spin_box.value)
	config.set_value("key_light", "color", key_light_color_picker_button.color)
	config.set_value("key_light", "z_rotation", key_light_rot_spin.value)
	
	# Save Fill Light settings
	config.set_value("fill_light", "enabled", fill_light_check_button.button_pressed)
	config.set_value("fill_light", "intensity", fill_light_spin_box.value)
	config.set_value("fill_light", "color", fill_light_color_picker_button.color)
	config.set_value("fill_light", "z_rotation", fill_light_rot_spin.value)
	
	# Save Rim Light settings
	config.set_value("rim_light", "enabled", rim_light_check_button.button_pressed)
	config.set_value("rim_light", "intensity", rim_light_spin_box.value)
	config.set_value("rim_light", "color", rim_light_color_picker_button.color)
	config.set_value("rim_light", "z_rotation", rim_light_rot_spin.value)
	
	var error = config.save(LIGHTING_CONFIG_FILE)
	if error != OK:
		print("Failed to save lighting settings: ", error)

func _load_settings():
	var config = ConfigFile.new()
	var error = config.load(LIGHTING_CONFIG_FILE)
	
	if error != OK:
		print("No lighting config file found or failed to load, using defaults")
		return
	
	# Load Key Light settings
	if config.has_section("key_light"):
		key_light_check_button.button_pressed = config.get_value("key_light", "enabled", DEFAULT_SETTINGS.key_light.enabled)
		key_light_spin_box.value = config.get_value("key_light", "intensity", DEFAULT_SETTINGS.key_light.intensity)
		key_light_color_picker_button.color = config.get_value("key_light", "color", DEFAULT_SETTINGS.key_light.color)
		var z_rotation = config.get_value("key_light", "z_rotation", 0.0)
		key_light_rot_spin.value = z_rotation
		if key_light:
			key_light.visible = key_light_check_button.button_pressed
			key_light.light_energy = key_light_spin_box.value
			key_light.light_color = key_light_color_picker_button.color
			key_light.rotation_degrees = DEFAULT_SETTINGS.key_light.rotation
			key_light.rotate(Vector3.FORWARD, deg_to_rad(z_rotation))
	
	# Load Fill Light settings
	if config.has_section("fill_light"):
		fill_light_check_button.button_pressed = config.get_value("fill_light", "enabled", DEFAULT_SETTINGS.fill_light.enabled)
		fill_light_spin_box.value = config.get_value("fill_light", "intensity", DEFAULT_SETTINGS.fill_light.intensity)
		fill_light_color_picker_button.color = config.get_value("fill_light", "color", DEFAULT_SETTINGS.fill_light.color)
		var z_rotation = config.get_value("fill_light", "z_rotation", 0.0)
		fill_light_rot_spin.value = z_rotation
		if fill_light:
			fill_light.visible = fill_light_check_button.button_pressed
			fill_light.light_energy = fill_light_spin_box.value
			fill_light.light_color = fill_light_color_picker_button.color
			fill_light.rotation_degrees = DEFAULT_SETTINGS.fill_light.rotation
			fill_light.rotate(Vector3.FORWARD, deg_to_rad(z_rotation))
	
	# Load Rim Light settings
	if config.has_section("rim_light"):
		rim_light_check_button.button_pressed = config.get_value("rim_light", "enabled", DEFAULT_SETTINGS.rim_light.enabled)
		rim_light_spin_box.value = config.get_value("rim_light", "intensity", DEFAULT_SETTINGS.rim_light.intensity)
		rim_light_color_picker_button.color = config.get_value("rim_light", "color", DEFAULT_SETTINGS.rim_light.color)
		var z_rotation = config.get_value("rim_light", "z_rotation", 0.0)
		rim_light_rot_spin.value = z_rotation
		if rim_light:
			rim_light.visible = rim_light_check_button.button_pressed
			rim_light.light_energy = rim_light_spin_box.value
			rim_light.light_color = rim_light_color_picker_button.color
			rim_light.rotation_degrees = DEFAULT_SETTINGS.rim_light.rotation
			rim_light.rotate(Vector3.FORWARD, deg_to_rad(z_rotation))
	
	print("Lighting settings loaded successfully")

extends Node3D
class_name ModelsHandler

signal added_checkpoint(index: int)

# --- Constants ---
const DEFAULT_ROTATION_DELTA := 45.0
const DEFAULT_CAMERA_POS := Vector3(0, 1, 55)
const DEFAULT_CAMERA_ROT := Vector3.ZERO
const DEFAULT_ZOOM := 4.0

## Camera presets (position + rotation)
const CAMERA_PRESETS := {
	"Front":     { pos = Vector3(0, 1, 55),  rot = Vector3(0, 0, 0) },
	"Left":      { pos = Vector3(-55, 1, 0), rot = Vector3(0, -90, 0) },
	"Right":     { pos = Vector3(55, 1, 0),  rot = Vector3(0, 90, 0) },
	"Top":       { pos = Vector3(0, 55, 0),  rot = Vector3(-90, 0, 0) },
	"Isometric": { pos = Vector3(0, 56, 55), rot = Vector3(-45, 0, 0) }
}

# --- UI groups (model + camera controls) ---
@onready var model := {
	pos = { x = %XPosSpin, y = %YPosSpin, z = %ZPosSpin },
	rot = { x = %XRotSpin, y = %YRotSpin, z = %ZRotSpin },
	buttons = { up = %Button_Model_Up, down = %Button_Model_Down, left = %Button_Model_Left, right = %Button_Model_Right },
	delta_spin = %RotationModelDeltaSpinBox,
	rot_reset = %RotResetButton,
	pos_reset = %PosResetButton
}

@onready var camera_ctl := {
	pos = { x = %XPosCameraSpin, y = %YPosCameraSpin, z = %ZPosCameraSpin },
	rot = { x = %XRotCameraSpin, y = %YRotCameraSpin, z = %ZRotCameraSpin },
	buttons = { up = %Button_Camera_Up, down = %Button_Camera_Down, left = %Button_Camera_Left, right = %Button_Camera_Right },
	delta_spin = %RotationCameraDeltaSpinBox,
	rot_reset = %RotCameraResetButton,
	pos_reset = %PosCameraResetButton,
	zoom_spin = %CameraZoomSpin,
	zoom_reset = %ZoomResetButton,
	preset_select = %CameraConfigOptionButton
}

@onready var camera: Camera3D = %Camera

# --- Exported properties ---
@export var rotation_model_delta: float = DEFAULT_ROTATION_DELTA
@export var rotation_camera_delta: float = DEFAULT_ROTATION_DELTA

# --- Data storage ---
var checkpoints: Array = []   # массив точек сохранения

# --- Delta getters/setters ---
func _get_rotation_model_delta() -> float: return rotation_model_delta
func _set_rotation_model_delta(v: float) -> void: rotation_model_delta = v

func _get_rotation_camera_delta() -> float: return rotation_camera_delta
func _set_rotation_camera_delta(v: float) -> void: rotation_camera_delta = v

# --- Ready ---
func _ready() -> void:
	# Init model controls
	_init_controls(model, _update_model_position, _update_model_rotation,
		Callable(self, "_get_rotation_model_delta"), Callable(self, "_set_rotation_model_delta"),
		_reset_model_position, _reset_model_rotation)

	# Init camera controls
	_init_controls(camera_ctl, _update_camera_position, _update_camera_rotation,
		Callable(self, "_get_rotation_camera_delta"), Callable(self, "_set_rotation_camera_delta"),
		_reset_camera_position, _reset_camera_rotation)

	# Zoom and presets
	camera_ctl.zoom_spin.value_changed.connect(_update_zoom)
	camera_ctl.zoom_reset.pressed.connect(_reset_zoom)
	_setup_camera_presets()
	camera_ctl.preset_select.item_selected.connect(_on_camera_preset_selected)

	reset_all()

# --- Initialize a control group (model or camera) ---
func _init_controls(group, update_pos, update_rot, get_delta: Callable, set_delta: Callable, reset_pos, reset_rot) -> void:
	for axis in group.pos: 
		if group.pos[axis] and group.pos[axis].has_signal("value_changed"):
			group.pos[axis].value_changed.connect(update_pos)
	
	for axis in group.rot: 
		if group.rot[axis] and group.rot[axis].has_signal("value_changed"):
			group.rot[axis].value_changed.connect(update_rot)

	if group.buttons.up and group.buttons.up.has_signal("pressed"):
		group.buttons.up.pressed.connect(func(): _rotate_spinbox(group.rot.x, -get_delta.call(), update_rot))

	if group.buttons.down and group.buttons.down.has_signal("pressed"):
		group.buttons.down.pressed.connect(func(): _rotate_spinbox(group.rot.x, get_delta.call(), update_rot))

	if group.buttons.left and group.buttons.left.has_signal("pressed"):
		group.buttons.left.pressed.connect(func(): _rotate_spinbox(group.rot.y, -get_delta.call(), update_rot))

	if group.buttons.right and group.buttons.right.has_signal("pressed"):
		group.buttons.right.pressed.connect(func(): _rotate_spinbox(group.rot.y, get_delta.call(), update_rot))


	if group.delta_spin and group.delta_spin.has_signal("value_changed"):
		group.delta_spin.value_changed.connect(set_delta)
	
	if group.pos_reset and group.pos_reset.has_signal("pressed"):
		group.pos_reset.pressed.connect(reset_pos)
	
	if group.rot_reset and group.rot_reset.has_signal("pressed"):
		group.rot_reset.pressed.connect(reset_rot)

# --- Reset all state ---
func reset_all() -> void:
	_reset_model_position()
	_reset_model_rotation()
	_reset_camera_position()
	_reset_camera_rotation()
	_reset_zoom()

# --- Helpers ---
func _rotate_spinbox(spinbox: SpinBox, delta: float, callback: Callable) -> void:
	if spinbox:
		spinbox.value += delta
		callback.call(0)

func _vector_from_spinboxes(spin_group: Dictionary) -> Vector3:
	return Vector3(
		spin_group.x.value if spin_group.x else 0,
		spin_group.y.value if spin_group.y else 0,
		spin_group.z.value if spin_group.z else 0
	)

# --- Model logic ---
func _update_model_position(_v: float = 0) -> void: 
	position = _vector_from_spinboxes(model.pos)

func _update_model_rotation(_v: float = 0) -> void: 
	rotation_degrees = _vector_from_spinboxes(model.rot)

func _reset_model_position() -> void: 
	for a in model.pos: 
		if model.pos[a]:
			model.pos[a].value = 0
	_update_model_position()

func _reset_model_rotation() -> void: 
	for a in model.rot: 
		if model.rot[a]:
			model.rot[a].value = 0
	_update_model_rotation()

# --- Camera logic ---
func _update_camera_position(_v: float = 0) -> void:
	if camera:
		camera.position = DEFAULT_CAMERA_POS + _vector_from_spinboxes(camera_ctl.pos)

func _update_camera_rotation(_v: float = 0) -> void:
	if camera:
		camera.rotation_degrees = DEFAULT_CAMERA_ROT + _vector_from_spinboxes(camera_ctl.rot)

func _reset_camera_position() -> void: 
	for a in camera_ctl.pos: 
		if camera_ctl.pos[a]:
			camera_ctl.pos[a].value = 0
	_update_camera_position()

func _reset_camera_rotation() -> void: 
	for a in camera_ctl.rot: 
		if camera_ctl.rot[a]:
			camera_ctl.rot[a].value = 0
	_update_camera_rotation()

# --- Zoom logic ---
func _update_zoom(v: float) -> void: 
	if camera and v > 0:
		camera.size = v

func _reset_zoom() -> void: 
	if camera_ctl.zoom_spin:
		camera_ctl.zoom_spin.value = DEFAULT_ZOOM
	if camera:
		camera.size = DEFAULT_ZOOM

# --- Camera presets ---
func _setup_camera_presets() -> void:
	if not camera_ctl.preset_select:
		return
		
	camera_ctl.preset_select.clear()
	for n in CAMERA_PRESETS: 
		camera_ctl.preset_select.add_item(n)

func _on_camera_preset_selected(i: int) -> void:
	if not camera_ctl.preset_select or not camera:
		return
		
	var preset_name = camera_ctl.preset_select.get_item_text(i)
	if preset_name in CAMERA_PRESETS:
		var p = CAMERA_PRESETS[preset_name]
		camera.position = p.pos
		camera.rotation_degrees = p.rot
		_sync_camera_ui()

func _sync_camera_ui() -> void:
	if not camera:
		return
		
	var pos_offset = camera.position - DEFAULT_CAMERA_POS
	if camera_ctl.pos.x: camera_ctl.pos.x.value = pos_offset.x
	if camera_ctl.pos.y: camera_ctl.pos.y.value = pos_offset.y
	if camera_ctl.pos.z: camera_ctl.pos.z.value = pos_offset.z

	var rot_offset = camera.rotation_degrees - DEFAULT_CAMERA_ROT
	if camera_ctl.rot.x: camera_ctl.rot.x.value = rot_offset.x
	if camera_ctl.rot.y: camera_ctl.rot.y.value = rot_offset.y
	if camera_ctl.rot.z: camera_ctl.rot.z.value = rot_offset.z

# --- Save/Load state ---
func get_state() -> Dictionary:
	return {
		"model": {
			"position": position,
			"rotation": rotation_degrees
		},
		"camera": {
			"position": camera.position if camera else DEFAULT_CAMERA_POS,
			"rotation": camera.rotation_degrees if camera else DEFAULT_CAMERA_ROT,
			"zoom": camera.size if camera else DEFAULT_ZOOM
		}
	}

func set_state(state: Dictionary) -> void:
	if state.has("model"):
		if state.model.has("position"):
			position = state.model.position
			for axis in model.pos:
				if model.pos[axis]:
					model.pos[axis].value = position[axis]
		if state.model.has("rotation"):
			rotation_degrees = state.model.rotation
			for axis in model.rot:
				if model.rot[axis]:
					model.rot[axis].value = rotation_degrees[axis]

	if state.has("camera") and camera:
		if state.camera.has("position"):
			camera.position = state.camera.position
			var pos_offset = camera.position - DEFAULT_CAMERA_POS
			if camera_ctl.pos.x: camera_ctl.pos.x.value = pos_offset.x
			if camera_ctl.pos.y: camera_ctl.pos.y.value = pos_offset.y
			if camera_ctl.pos.z: camera_ctl.pos.z.value = pos_offset.z

		if state.camera.has("rotation"):
			camera.rotation_degrees = state.camera.rotation
			var rot_offset = camera.rotation_degrees - DEFAULT_CAMERA_ROT
			if camera_ctl.rot.x: camera_ctl.rot.x.value = rot_offset.x
			if camera_ctl.rot.y: camera_ctl.rot.y.value = rot_offset.y
			if camera_ctl.rot.z: camera_ctl.rot.z.value = rot_offset.z

		if state.camera.has("zoom"):
			camera.size = state.camera.zoom
			if camera_ctl.zoom_spin: camera_ctl.zoom_spin.value = state.camera.zoom

# --- Public methods for checkpoint creation ---
func create_checkpoint() -> int:
	checkpoints.append(get_state())
	var index = checkpoints.size() - 1
	added_checkpoint.emit(index)
	print("Checkpoint saved! Total:", checkpoints.size())
	return index

func add_checkpoint() -> int:
	return create_checkpoint()

# --- Simple getters ---
func get_model_position() -> Vector3: return position
func get_model_rotation() -> Vector3: return rotation_degrees
func get_camera_position() -> Vector3: return camera.position if camera else DEFAULT_CAMERA_POS
func get_camera_rotation() -> Vector3: return camera.rotation_degrees if camera else DEFAULT_CAMERA_ROT

extends Node3D
class_name ModelsSpawner

signal model_loaded(model: Node3D)
signal animation_player_setup(animation_player: AnimationPlayer)

# UI References
@onready var load_scene_button: Button = %LoadSceneButton
@onready var load_scene_path: Label = %LoadScenePath
@onready var load_texture_button: Button = %LoadTextureButton

@onready var add_track_button: Button = %AddTrackButton
@onready var tracks_container: VBoxContainer = %TracksContainer

@onready var temp_model: Node3D = %TempModel
@onready var console: Console = %Console

var active_track: Track = null

# File dialogs
var file_dialog: FileDialog
var texture_dialog: FileDialog

# Current model
var loaded_model: Node3D = null
var current_model_path: String = ""
var current_animation_player: AnimationPlayer = null

# Auto-refresh
var auto_refresh_timer: Timer
var last_animation_count: int = 0
var last_model_node_count: int = 0
var refresh_check_interval: float = 2.0  # Increase from 1.0 to 2.0 seconds

# Reference to pixel_material
var pixel_material_script: Node

func _ready():
	_setup_file_dialog()

	load_scene_button.pressed.connect(_on_load_button_pressed)
	load_texture_button.pressed.connect(_on_load_texture_pressed)
	add_track_button.pressed.connect(_on_add_track_pressed)

	# Use temp model as starting point
	loaded_model = temp_model
	model_loaded.emit(loaded_model)
	_update_path_label()
	_setup_animation_player()

	_setup_auto_refresh()
	_find_pixel_material_reference()

# ------------------------------------------------
# AUTO REFRESH
# ------------------------------------------------
func _setup_auto_refresh():
	auto_refresh_timer = Timer.new()
	auto_refresh_timer.wait_time = refresh_check_interval
	auto_refresh_timer.timeout.connect(_on_auto_refresh_timer_timeout)
	add_child(auto_refresh_timer)
	auto_refresh_timer.start()

func _on_auto_refresh_timer_timeout():
	if loaded_model == null:
		return

	var current_node_count = _count_nodes_recursive(loaded_model)
	var current_anim_count = 0

	if current_animation_player != null:
		current_anim_count = _get_animation_count(current_animation_player)

	var needs_refresh := false

	if current_node_count != last_model_node_count:
		console.text += "Model structure changed - refreshing\n"
		needs_refresh = true
		last_model_node_count = current_node_count

	if current_anim_count != last_animation_count:
		console.text += "Animation count changed - refreshing\n"
		needs_refresh = true
		last_animation_count = current_anim_count

	var found_player = _find_animation_player(loaded_model)
	if (found_player == null) != (current_animation_player == null):
		console.text += "AnimationPlayer availability changed - refreshing\n"
		needs_refresh = true

	if needs_refresh:
		_setup_animation_player()

func _get_animation_count(player: AnimationPlayer) -> int:
	var count = 0
	for lib_name in player.get_animation_library_list():
		var library = player.get_animation_library(lib_name)
		count += library.get_animation_list().size()
	return count

func _count_nodes_recursive(node: Node) -> int:
	var count = 1
	for child in node.get_children():
		count += _count_nodes_recursive(child)
	return count

# ------------------------------------------------
# TRACK MANAGEMENT
# ------------------------------------------------
func _on_add_track_pressed():
	var track_scene = preload("res://PixelRenderer/data/components/track.tscn")
	var track: Track = track_scene.instantiate()
	tracks_container.add_child(track)

	track.request_become_active.connect(_on_track_request_become_active)
	
	# Pass models_handler reference if available
	var pixel_renderer = get_node_or_null("../../")
	if pixel_renderer and pixel_renderer.has_node("ModelsHandler"):
		track.models_handler = pixel_renderer.get_node("ModelsHandler")

	if current_animation_player != null:
		track.set_animation_player(current_animation_player)

func _on_track_request_become_active(track: Track):
	for t in tracks_container.get_children():
		if t is Track:
			t.set_active(t == track)
	active_track = track

func _update_tracks_with_player(player: AnimationPlayer):
	for t in tracks_container.get_children():
		if t is Track:
			t.set_animation_player(player)
			t.set_active(false)
	active_track = null

# ------------------------------------------------
# ANIMATION PLAYER
# ------------------------------------------------
func _setup_animation_player():
	current_animation_player = _find_animation_player(loaded_model)

	if current_animation_player != null:
		var anim_count = _get_animation_count(current_animation_player)
		console.text += "Found AnimationPlayer with " + str(anim_count) + " animations\n"
		last_animation_count = anim_count
	else:
		console.text += "No AnimationPlayer found in loaded model\n"
		last_animation_count = 0

	if loaded_model != null:
		last_model_node_count = _count_nodes_recursive(loaded_model)

	_update_tracks_with_player(current_animation_player)
	animation_player_setup.emit(current_animation_player)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var res = _find_animation_player(child)
		if res != null:
			return res
	return null

# ------------------------------------------------
# MODEL / TEXTURE LOADING
# ------------------------------------------------
func _setup_file_dialog():
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.glb ; GLB Files")
	file_dialog.add_filter("*.gltf ; GLTF Files")
	file_dialog.add_filter("*.fbx ; FBX Files")
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)

	texture_dialog = FileDialog.new()
	texture_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	texture_dialog.access = FileDialog.ACCESS_FILESYSTEM
	texture_dialog.add_filter("*.png ; PNG Images")
	texture_dialog.add_filter("*.jpg ; JPEG Images")
	texture_dialog.add_filter("*.jpeg ; JPEG Images")
	texture_dialog.add_filter("*.webp ; WebP Images")
	texture_dialog.file_selected.connect(_on_texture_selected)
	add_child(texture_dialog)

func _on_load_button_pressed():
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_load_texture_pressed():
	texture_dialog.popup_centered(Vector2i(800, 600))

func _on_file_selected(path: String):
	_load_model(path)

func _on_texture_selected(path: String):
	var img = Image.new()
	var err = img.load(path)
	if err != OK:
		console.text += "Failed to load texture: " + path + "\n"
		return

	var tex = ImageTexture.create_from_image(img)
	_apply_texture_to_model(tex)
	console.text += "Applied texture: " + path.get_file() + "\n"

func _apply_texture_to_model(tex: Texture2D):
	if loaded_model == null:
		console.text += "No model loaded\n"
		return
	_apply_texture_recursive(loaded_model, tex)

func _apply_texture_recursive(node: Node, tex: Texture2D):
	if node is MeshInstance3D:
		for i in range(node.get_surface_override_material_count()):
			var mat = node.get_active_material(i)
			if mat == null:
				mat = StandardMaterial3D.new()
				node.set_surface_override_material(i, mat)
			
			if mat is StandardMaterial3D:
				(mat as StandardMaterial3D).albedo_texture = tex
			else:
				# If it's not a StandardMaterial3D, create a new one with the texture
				var new_mat = StandardMaterial3D.new()
				new_mat.albedo_texture = tex
				node.set_surface_override_material(i, new_mat)

	for child in node.get_children():
		_apply_texture_recursive(child, tex)

func _load_model(path: String):
	var scene: Node3D = null
	var error: int = ERR_FILE_UNRECOGNIZED
	var ext = path.get_extension().to_lower()

	if ext in ["glb", "gltf"]:
		var gltf = GLTFDocument.new()
		var state = GLTFState.new()
		error = gltf.append_from_file(path, state)
		if error == OK:
			scene = gltf.generate_scene(state)
	elif ext == "fbx":
		var fbx = FBXDocument.new()
		var state = FBXState.new()
		error = fbx.append_from_file(path, state)
		if error == OK:
			scene = fbx.generate_scene(state)
	else:
		console.text += "Unsupported format: " + ext + "\n"
		load_scene_path.text = "Unsupported format: " + ext
		return

	if error != OK or scene == null:
		console.text += "Failed to load model: " + path + "\n"
		load_scene_path.text = "Failed to load: " + path.get_file()
		return

	# Remove previous loaded model (but keep temp_model)
	if loaded_model != null and loaded_model != temp_model:
		loaded_model.queue_free()
		await get_tree().process_frame
	elif loaded_model == temp_model:
		temp_model.queue_free()

	add_child(scene)
	loaded_model = scene
	current_model_path = path

	_update_path_label()
	_setup_animation_player()

	if pixel_material_script != null:
		await get_tree().process_frame
		await get_tree().process_frame
		pixel_material_script.sample_colors_from_render()

	console.text += "Loaded model: " + path + "\n"

# ------------------------------------------------
# HELPERS
# ------------------------------------------------
func _update_path_label():
	load_scene_path.text = current_model_path.get_file() if current_model_path != "" else "No model loaded"

func get_loaded_model() -> Node3D:
	return loaded_model

func get_current_model_path() -> String:
	return current_model_path

func clear_loaded_model():
	if loaded_model != null and loaded_model != temp_model:
		loaded_model.queue_free()
		loaded_model = temp_model
		current_model_path = ""
		_update_path_label()
		console.text += "Model cleared\n"

func _find_pixel_material_reference():
	var root_node = get_node("../../")
	pixel_material_script = root_node.get_node_or_null("PixelMaterial")
	if pixel_material_script != null:
		console.text += "Found PixelMaterial reference\n"
	else:
		console.text += "WARNING: PixelMaterial not found\n"

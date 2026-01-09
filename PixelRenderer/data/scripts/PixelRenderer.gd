extends Node3D
class_name PixelRenderer

@onready var export_dir_path: Label = %ExportDirPath
@onready var select_folder_button: Button = %SelectFolderButton
@onready var export_button: Button = %ExportButton

@onready var file_dialog: FileDialog = %FileDialog
@onready var texture_rect: TextureRect = %PixelCanvas

@onready var renderer: PanelContainer = %Renderer
@onready var models_spawner: Node3D = %ModelsSpawner

@onready var prefix_text: LineEdit = %PrefixText

@onready var sub_viewport: SubViewport = $SubViewport

@onready var bg_color_rect: ColorRect = %BgColorRect
@onready var bg_color_check_box: CheckButton = %BgColorCheckBox
@onready var bg_color_picker: ColorPickerButton = %BgColorPicker
@onready var progress_bar: ProgressBar = %ProgressBar

@export var start_frame: int = 0
@export var end_frame: int = 30
@export var fps: int = 12

@onready var resolution: SpinBox = %Resolution
@onready var preview_image_check_box: CheckButton = %PreviewImageCheckBox
@onready var view_mode_dropdown : OptionButton = %ViewModeDropDown
@onready var canvas_size_label: Label = %CanvasSizeLabel
@onready var pixel_material_script: Node = $PixelMaterial
@export var sprite_sheet_check_box: CheckButton

@onready var console: Console = %Console

@onready var models_handler: Node3D = %ModelsHandler

@onready var model_control_button_panel: GridContainer = %ModelControlButtonPanel
@onready var viewport_background_color_rect: ColorRect = %ViewportBackgroundColorRect

@onready var tracks_container: Node = %TracksContainer
@onready var model_controller: Node = %ModelsSpawner

var export_tasks: Array = []   # array of dictionaries: { "track": Track, "checkpoint_index": int }

var export_directory: String = ""
var is_exporting: bool = false
var current_export_frame: int = 0
var total_frames: int = 0

# Timer for canvas updates
var canvas_update_timer: Timer

# Cached texture for FPS-controlled display
var cached_texture: ImageTexture

# Base canvas size - always 800x800
const BASE_CANVAS_SIZE: int = 800
# Minimum intermediate size for quality downscaling
const MIN_INTERMEDIATE_SIZE: int = 256

# Animation export variables
var animation_player: AnimationPlayer = null
var was_playing_before_export: bool = false
var original_animation_position: float = 0.0
var export_frame_list: Array = []
var export_frame_index: int = 0

var export_task_index: int = 0
var export_frame_index_in_task: int = 0
var previous_checkpoint_index: int = -1

# Sprite sheet export variables
var sprite_sheet_image: Image = null
var sprite_sheet_width: int = 0
var sprite_sheet_height: int = 0
var frames_per_row: int = 0

# Reusable capture viewport for export optimization
var capture_viewport: SubViewport = null

# Export FPS tracking
var export_fps: int = 12


func _ready():
	# Initialize console
	console.log("EffectBlocks PixelRenderer", console.INFO)
	console.log("Visit https://github.com/uxerror/RetroForge", console.INFO)
	console.log("PixelRenderer initialized successfully", console.OK)
	
	# Keep SubViewport updating continuously so models run at normal speed
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Initialize cached texture
	cached_texture = ImageTexture.new()
	
	# Create and configure the canvas update timer for visual feed updates
	canvas_update_timer = Timer.new()
	canvas_update_timer.wait_time = 1.0 / fps
	canvas_update_timer.timeout.connect(_update_canvas)
	add_child(canvas_update_timer)
	canvas_update_timer.start()
	
	console.log("Canvas update timer set to " + str(fps) + " FPS", console.INFO)
	console.log("Base canvas size: " + str(BASE_CANVAS_SIZE) + "x" + str(BASE_CANVAS_SIZE), console.INFO)
	console.log("Default minion skeleton by KayKit: kaylousberg.itch.io/kaykit-skeletons", console.INFO)
	
	# Connect signals
	export_button.pressed.connect(_on_export_button_pressed)
	select_folder_button.pressed.connect(_on_select_folder_button_pressed)
	resolution.value_changed.connect(_on_resolution_changed)
	file_dialog.dir_selected.connect(_on_directory_selected)
	bg_color_check_box.toggled.connect(_on_bg_color_toggled)
	bg_color_picker.color_changed.connect(_on_bg_color_changed)
	if tracks_container:
		tracks_container.child_entered_tree.connect(_on_track_added)

	
	# Setup View Modes
	_setup_view_mode_dropdown()
	view_mode_dropdown.item_selected.connect(_view_mode_item_selected)
	
	# Connect to ViewMaterials signal for automatic color remap toggle
	var view_materials = get_node_or_null("ViewMaterials")
	if view_materials and view_materials.has_signal("technical_mode_selected"):
		view_materials.technical_mode_selected.connect(_on_technical_mode_selected)
	
	# Set up file dialog
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	
	# Connect to track signals
	if tracks_container:
		for track in tracks_container.get_children():
			_connect_track_signals(track)
	
	# Initialize resolution spin box
	resolution.value = 512
	resolution.min_value = 1
	resolution.step = 1
	
	# Initialize background color controls
	_update_bg_color_visibility()
	
	# Initialize export directory label
	_update_export_path_label()
	
	# Initialize canvas size label
	_update_canvas_size_label()
	
	# Initialize progress bar
	progress_bar.min_value = 0
	progress_bar.max_value = 100

func _connect_track_signals(track: Track):
	if track.has_signal("request_create_checkpoint"):
		track.request_create_checkpoint.connect(_on_track_request_create_checkpoint)
	if track.has_signal("request_become_active"):
		track.request_become_active.connect(_on_track_request_become_active)
	if track.has_signal("request_delete_track"):
		track.request_delete_track.connect(_on_track_request_delete)
	track.models_handler = models_handler

func _on_track_added(track: Node) -> void:
	if track is Track:
		_connect_track_signals(track)
		console.log("Track added and signals connected", console.OK)

func _on_resolution_changed(value: float):
	_update_canvas_size_label()
	console.log("Export resolution changed to " + str(int(value)) + "x" + str(int(value)), console.INFO)

func _on_export_button_pressed():
	if is_exporting:
		return
	
	if export_directory == "":
		console.log("No export directory selected, opening folder dialog...", console.WARN)
		_on_select_folder_button_pressed()
		return
		
	# Start the export process
	_start_export()

func _on_select_folder_button_pressed():
	# Open file dialog to select export directory
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_directory_selected(dir: String):
	export_directory = dir
	console.log("Export directory set to: " + export_directory, console.INFO)
	
	# Update the label to show the selected path
	_update_export_path_label()

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	
	# Recursively search children
	for child in node.get_children():
		var result = _find_animation_player(child)
		if result != null:
			return result
	
	return null

func _force_update_transforms(node: Node) -> void:
	"""Recursively force update all transforms in the node tree"""
	if node is Node3D:
		node.force_update_transform()
	for child in node.get_children():
		_force_update_transforms(child)

func _start_export():
	if is_exporting:
		return
	if export_directory == "":
		console.log("No export directory selected, opening folder dialog...", console.WARN)
		_on_select_folder_button_pressed()
		return
	
	# Validate export resolution
	var export_resolution = int(resolution.value)
	if export_resolution <= 0:
		console.log("ERROR: Invalid export resolution: " + str(export_resolution), console.WARN)
		return
	
	# Stop all tracks before export
	if tracks_container:
		for track in tracks_container.get_children():
			if track is Track:
				track.set_active(false)

	# track + checkpoint
	export_tasks = _collect_export_tasks()
	if export_tasks.size() == 0:
		console.log("No export tasks collected — aborting.", console.WARN)
		return
	
	model_control_button_panel.hide()
	viewport_background_color_rect.hide()
	
	total_frames = 0
	for task in export_tasks:
		var track: Track = task["track"]
		var settings = track.get_export_settings()
		var frames = []

		var frame_skip = int(30.0 / float(settings["fps"]))
		if frame_skip < 1:
			frame_skip = 1

		for frame_num in range(settings["start_frame"], settings["end_frame"] + 1):
			if (frame_num - settings["start_frame"]) % frame_skip == 0:
				frames.append(frame_num)

		task["frames"] = frames
		total_frames += frames.size()

	console.log("Collected " + str(export_tasks.size()) + " export tasks (track x checkpoint). Total frames: " + str(total_frames), console.INFO)

	# Store FPS for export report
	if export_tasks.size() > 0:
		var first_track: Track = export_tasks[0]["track"]
		var first_settings = first_track.get_export_settings()
		export_fps = int(first_settings["fps"])

	# Sprite sheet init
	if sprite_sheet_check_box.button_pressed:
		var max_frames = 0
		for task in export_tasks:
			max_frames = max(max_frames, task["frames"].size())

		var frame_size = int(resolution.value)
		frames_per_row = max_frames
		sprite_sheet_width = frames_per_row * frame_size
		sprite_sheet_height = export_tasks.size() * frame_size
		sprite_sheet_image = Image.create(sprite_sheet_width, sprite_sheet_height, false, Image.FORMAT_RGBA8)
		sprite_sheet_image.fill(Color(0, 0, 0, 0))
		console.log("Sprite sheet mode enabled: " + str(sprite_sheet_width) + "x" + str(sprite_sheet_height), console.INFO)

	is_exporting = true
	export_button.text = "Exporting..."
	export_button.disabled = true
	progress_bar.value = 0
	export_task_index = 0
	export_frame_index_in_task = 0
	previous_checkpoint_index = -1

	if animation_player:
		was_playing_before_export = animation_player.is_playing()
		original_animation_position = animation_player.current_animation_position
	
	_export_next_frame()


func _collect_export_tasks() -> Array:
	var tasks := []
	
	# Check if we have active tracks
	var has_active_tracks = false
	if tracks_container:
		for track in tracks_container.get_children():
			if track.has_method("is_active") and track.is_active():
				has_active_tracks = true
				break
	
	# Collect tasks from tracks
	if tracks_container:
		for track in tracks_container.get_children():
			if track.has_method("get_checkpoint_indices") and track.has_method("get_selected_animation_name"):
				# If we have active tracks, only export active ones
				if has_active_tracks and not track.is_active():
					continue
					
				var checkpoint_indices = track.get_checkpoint_indices()
				if checkpoint_indices.is_empty():
					console.log("WARNING: Track '" + track.get_selected_animation_name() + "' has no checkpoints, skipping", console.WARN)
					continue
					
				for cp_index in checkpoint_indices:
					tasks.append({"track": track, "checkpoint_index": cp_index})
	
	if tasks.size() == 0:
		console.log("No track checkpoints found — nothing to export.", console.WARN)
	return tasks

func _export_next_frame():
	if export_task_index >= export_tasks.size():
		_finish_export()
		return

	var task = export_tasks[export_task_index]
	var track = task["track"]
	var cp_index = task["checkpoint_index"]
	var frames = task["frames"]

	if export_frame_index_in_task >= frames.size():
		console.log("Task %d/%d completed (%s)" % [export_task_index + 1, export_tasks.size(), track.get_selected_animation_name()], console.OK)
		export_task_index += 1
		export_frame_index_in_task = 0
		previous_checkpoint_index = -1  # Reset for next task
		_export_next_frame()
		return

	var frame_to_render = frames[export_frame_index_in_task]
	var current_global_frame = export_task_index * export_frame_list.size() + export_frame_index_in_task
	var progress_percent = float(current_global_frame) / float(max(1, total_frames)) * 100.0
	progress_bar.value = progress_percent

	console.log(
		"Task %d/%d | Checkpoint %d | frame %d" % [
		export_task_index + 1,
		export_tasks.size(),
		cp_index + 1,
		frame_to_render
	],
	console.INFO)

	# Check if checkpoint changed (new task or different checkpoint)
	# Always treat first frame of task as checkpoint change
	var is_first_frame_of_task = (export_frame_index_in_task == 0)
	var checkpoint_changed = (cp_index != previous_checkpoint_index) or is_first_frame_of_task
	previous_checkpoint_index = cp_index
	
	if models_handler != null and models_handler.has_method("set_state"):
		if cp_index >= 0 and cp_index < models_handler.checkpoints.size():
			if checkpoint_changed:
				# Apply checkpoint and wait for signal confirmation
				models_handler.set_state(models_handler.checkpoints[cp_index], cp_index)
				
				# Wait for checkpoint_applied signal with timeout
				var signal_received = false
				var timeout_frames = 0
				var max_timeout_frames = 60  # Max 1 second at 60fps
				
				var on_checkpoint_applied = func(index: int):
					if index == cp_index:
						signal_received = true
				
				models_handler.checkpoint_applied.connect(on_checkpoint_applied)
				
				# Wait for signal or timeout
				while not signal_received and timeout_frames < max_timeout_frames:
					await get_tree().process_frame
					timeout_frames += 1
				
				models_handler.checkpoint_applied.disconnect(on_checkpoint_applied)
				
				if signal_received:
					console.log("Checkpoint %d applied and verified" % (cp_index + 1), console.OK)
				else:
					console.log("WARNING: Checkpoint %d timeout after %d frames" % [cp_index + 1, timeout_frames], console.WARN)
			else:
				# No checkpoint change, just apply directly
				models_handler.set_state(models_handler.checkpoints[cp_index], cp_index)
				console.log("Checkpoint %d reapplied" % (cp_index + 1), console.INFO)
		else:
			console.log("ERROR: checkpoint index %d out of range (total: %d)" % [cp_index, models_handler.checkpoints.size()], console.WARN)
			# Skip this frame if checkpoint is invalid
			export_frame_index_in_task += 1
			_export_next_frame()
			return

	var loaded_model = null
	if models_spawner and models_spawner.has_method("get_loaded_model"):
		loaded_model = models_spawner.get_loaded_model()
	elif models_spawner and models_spawner.has_node("TempModel"):
		loaded_model = models_spawner.get_node("TempModel")
	
	if loaded_model:
		animation_player = _find_animation_player(loaded_model)
	else:
		animation_player = null

	var anim_name = ""
	if track and track.has_method("get_selected_animation_name"):
		anim_name = track.get_selected_animation_name()

	if animation_player != null and anim_name != "":
		if animation_player.has_animation(anim_name):
			var target_time = float(frame_to_render) / 30.0
			var animation_length = animation_player.get_animation(anim_name).length
			if target_time > animation_length:
				target_time = animation_length
			
			animation_player.play(anim_name)
			animation_player.seek(target_time, true)
			animation_player.advance(0)  # Force skeleton update
			
			# Force update transforms on the entire model tree
			if loaded_model:
				_force_update_transforms(loaded_model)
			
			console.log("Animation set to '%s' at %.3fs" % [anim_name, target_time], console.INFO)
		else:
			console.log("WARNING: Animation '%s' not found in AnimationPlayer" % anim_name, console.WARN)
	else:
		console.log("No AnimationPlayer or empty anim_name", console.WARN)

	# Wait for scene to fully update
	await get_tree().process_frame
	await get_tree().process_frame

	var image = await _capture_control_node()
	if image:
		# Always scale to target resolution (preview mode shows base size)
		var target_size = int(resolution.value)
		if image.get_width() != target_size or image.get_height() != target_size:
			image = _scale_image_nearest_neighbor(image, target_size)

		if sprite_sheet_check_box.button_pressed:
			var frame_size = int(resolution.value)
			var row = export_task_index
			var col = export_frame_index_in_task
			var dest_x = col * frame_size
			var dest_y = row * frame_size
			
			# Verify dimensions before blitting
			if dest_x + frame_size <= sprite_sheet_width and dest_y + frame_size <= sprite_sheet_height:
				if image.get_width() == frame_size and image.get_height() == frame_size:
					sprite_sheet_image.blit_rect(image, Rect2i(Vector2i(0,0), Vector2i(frame_size, frame_size)), Vector2i(dest_x, dest_y))
				else:
					console.log("WARNING: Image size mismatch. Expected %dx%d, got %dx%d" % [frame_size, frame_size, image.get_width(), image.get_height()], console.WARN)
			else:
				console.log("ERROR: Sprite sheet position out of bounds: %d,%d in %dx%d sheet" % [dest_x, dest_y, sprite_sheet_width, sprite_sheet_height], console.WARN)
		else:
			var prefix = prefix_text.text.strip_edges()
			if prefix.is_empty():
				prefix = "frame"
			var track_label = "track"
			if track and track.has_method("get_selected_animation_name"):
				var track_anim_name = track.get_selected_animation_name()
				if not track_anim_name.is_empty():
					track_label = "track_" + str(track_anim_name)
			var filename = "%s_%s_cp%02d_%04d.png" % [prefix, track_label, cp_index + 1, frame_to_render]
			var filepath = export_directory.path_join(filename)
			var err = image.save_png(filepath)
			if err != OK:
				console.log("ERROR: failed to save " + filepath + " (error code: " + str(err) + ")", console.WARN)
			else:
				console.log("Saved: " + filepath, console.INFO)
	else:
		console.log("ERROR: capture failed for frame " + str(frame_to_render))

	export_frame_index_in_task += 1
	_export_next_frame()


func _capture_control_node() -> Image:
	if not renderer:
		console.log("ERROR: Renderer control node is null")
		return null
	
	# Get the size of the control node
	var size = renderer.size
	if size.x <= 0 or size.y <= 0:
		console.log("ERROR: Renderer control node has invalid size: " + str(size))
		return null
	
	console.log("Capturing frame at size: " + str(size))
	
	# Reuse existing capture viewport or create new one
	if not capture_viewport:
		capture_viewport = SubViewport.new()
		capture_viewport.transparent_bg = true
		add_child(capture_viewport)
	
	# Configure viewport for current capture
	capture_viewport.size = Vector2i(size)
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	# Clone the renderer node and its children
	var renderer_clone = renderer.duplicate(DUPLICATE_USE_INSTANTIATION)
	capture_viewport.add_child(renderer_clone)
	
	# Force the viewport to render
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame  # Wait an extra frame for safety
	
	# Get the rendered image with proper alpha channel
	var viewport_texture = capture_viewport.get_texture()
	if not viewport_texture:
		console.log("ERROR: Could not get texture from SubViewport")
		# Clean up before returning
		capture_viewport.remove_child(renderer_clone)
		renderer_clone.queue_free()
		return null
	
	var image = viewport_texture.get_image()
	
	# Clean up clone only (keep viewport for reuse)
	capture_viewport.remove_child(renderer_clone)
	renderer_clone.queue_free()
	
	if not image:
		console.log("ERROR: Could not capture image from SubViewport")
		return null
	
	# Ensure the image has an alpha channel for transparency
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
		console.log("Image converted to RGBA8 format")
	
	console.log("Frame captured successfully")
	# The image should now preserve the alpha channel from the SubViewport
	return image

func _scale_image_nearest_neighbor(source_image: Image, target_size: int) -> Image:
	"""
	Scale an image to target_size x target_size with quality preservation for low resolutions
	Uses two-stage scaling with averaging for better results at small sizes
	"""
	if not source_image:
		console.log("ERROR: Source image is null for scaling")
		return null
	
	var source_width = source_image.get_width()
	var source_height = source_image.get_height()
	
	# If already the target size, return as-is
	if source_width == target_size and source_height == target_size:
		console.log("Image already at target size (" + str(target_size) + "x" + str(target_size) + ")")
		return source_image
	
	console.log("Scaling image from " + str(source_width) + "x" + str(source_height) + " to " + str(target_size) + "x" + str(target_size))
	
	var scale_ratio = float(source_width) / float(target_size)
	
	# For very small sizes (scale ratio > 4), use two-stage scaling with averaging
	if scale_ratio > 4.0:
		return _two_stage_scale(source_image, target_size)
	else:
		# For moderate scaling, use simple nearest neighbor
		var scaled_image = source_image.duplicate()
		scaled_image.resize(target_size, target_size, Image.INTERPOLATE_NEAREST)
		console.log("Image scaling completed (single-stage)")
		return scaled_image

func _two_stage_scale(source_image: Image, target_size: int) -> Image:
	"""
	Two-stage scaling: first with averaging to intermediate size, then nearest neighbor to target
	This preserves more detail for very small target sizes
	"""
	var source_size = source_image.get_width()
	
	# Calculate intermediate size (at least 4x target, but not more than source)
	var intermediate_size = max(target_size * 4, MIN_INTERMEDIATE_SIZE)
	intermediate_size = min(intermediate_size, source_size)
	
	if intermediate_size == target_size:
		# No need for two-stage, go direct
		var result = source_image.duplicate()
		result.resize(target_size, target_size, Image.INTERPOLATE_NEAREST)
		return result
	
	console.log("Two-stage scaling: %dx%d -> %dx%d -> %dx%d" % [source_size, source_size, intermediate_size, intermediate_size, target_size, target_size])
	
	# Stage 1: Scale down to intermediate size with bilinear (averaging)
	var intermediate_image = source_image.duplicate()
	intermediate_image.resize(intermediate_size, intermediate_size, Image.INTERPOLATE_BILINEAR)
	
	# Stage 2: Scale to final size with nearest neighbor (pixel art look)
	var final_image = intermediate_image.duplicate()
	final_image.resize(target_size, target_size, Image.INTERPOLATE_NEAREST)
	
	console.log("Two-stage scaling completed")
	return final_image

func _finish_export():
	is_exporting = false
	export_button.text = "Export"
	export_button.disabled = false
	
	# Clean up capture viewport after export completes
	if capture_viewport:
		remove_child(capture_viewport)
		capture_viewport.queue_free()
		capture_viewport = null
	
	# Restore animation player state
	if animation_player:
		if was_playing_before_export:
			animation_player.seek(original_animation_position)
			if not animation_player.is_playing():
				animation_player.play()
			console.log("Animation restored to original state")
		else:
			animation_player.stop()
			animation_player.seek(original_animation_position)
			console.log("Animation stopped and restored to original position")
			
	model_control_button_panel.show()
	viewport_background_color_rect.show()
	
	# if sprite sheet
	if sprite_sheet_check_box.button_pressed and sprite_sheet_image:
		var prefix = prefix_text.text.strip_edges()
		if prefix.is_empty():
			prefix = "sprite_sheet"
		var filepath = export_directory.path_join(prefix + "_tileset.png")
		var err = sprite_sheet_image.save_png(filepath)
		if err != OK:
			console.log("ERROR: failed to save sprite sheet " + filepath + " (error code: " + str(err) + ")", console.WARN)
		else:
			console.log("Sprite sheet saved: " + filepath, console.OK)
			console.log("Sprite sheet dimensions: " + str(sprite_sheet_width) + "x" + str(sprite_sheet_height), console.INFO)

	# Complete the progress bar
	progress_bar.value = 100
	
	console.log("------------------------------")
	console.log("EXPORT COMPLETED!")
	console.log("Total frames exported: " + str(total_frames))
	console.log("Export location: " + export_directory)
	console.log("Frame rate: " + str(export_fps) + " FPS")
	if sprite_sheet_check_box.button_pressed:
		console.log("Export mode: SPRITE SHEET")
	else:
		console.log("Export mode: FRAME SEQUENCE")
	console.log("------------------------------")
	
	# Clean up sprite sheet resources
	sprite_sheet_image = null
	
	_show_completion_message(total_frames)


func _show_completion_message(frame_count: int):
	# You can implement a popup or notification here
	console.log("Animation export finished: " + str(frame_count) + " frames at " + str(export_fps) + " FPS")
	console.log("You can now create animations or GIFs from the exported frames")

func _update_canvas():
	# Capture the current frame from the SubViewport
	var viewport_texture = sub_viewport.get_texture()
	if viewport_texture:
		var image = viewport_texture.get_image()
		if image:
			# Update the cached texture with the current frame
			cached_texture.set_image(image)
			# Apply the cached texture to the display
			texture_rect.texture = cached_texture
		else:
			console.log("Could not get image from SubViewport for canvas update", console.WARN)
	else:
		console.log("Could not get texture from SubViewport for canvas update", console.WARN)

func _update_export_path_label():
	if export_directory == "":
		export_dir_path.text = "No directory selected"
	else:
		export_dir_path.text = export_directory

func _update_canvas_size_label():
	var export_resolution = int(resolution.value)
	var scale_factor = float(export_resolution) / float(BASE_CANVAS_SIZE)
	
	var scale_text = ""
	if scale_factor > 1.0:
		scale_text = " | *" + str(scale_factor) + " upscaled"
	elif scale_factor < 1.0:
		scale_text = " | *" + str(scale_factor) + " downscaled"
	else:
		scale_text = " | 1:1 scale"
	
	canvas_size_label.text = "Canvas base " + str(BASE_CANVAS_SIZE) + "px | Export resolution " + str(export_resolution) + "px" + scale_text

func _on_bg_color_toggled(button_pressed: bool):
	_update_bg_color_visibility()
	if button_pressed:
		console.log("Background color enabled")
	else:
		console.log("Background color disabled")

func _on_bg_color_changed(color: Color):
	bg_color_rect.color = color
	console.log("Background color changed to: " + str(color))

func _update_bg_color_visibility():
	var should_be_visible = bg_color_check_box.button_pressed
	bg_color_rect.visible = should_be_visible

func _setup_view_mode_dropdown():
	view_mode_dropdown.clear()
	
	view_mode_dropdown.add_item("Albedo")
	view_mode_dropdown.add_item("Normal")
	view_mode_dropdown.add_item("Specular")

func _view_mode_item_selected(index : int):
	var view_materials = get_node_or_null("ViewMaterials")
	if view_materials and view_materials.has_method("item_selected"):
		view_materials.item_selected(index)
	var selection : String = view_mode_dropdown.get_item_text(index)
	console.log("Switching View Mode To " + selection)

func _on_technical_mode_selected(mode_name: String):
	# Automatically turn off color remap when technical modes are selected
	_turn_off_color_remap_if_enabled()
	console.log("Technical mode '" + mode_name + "' selected - color remap automatically disabled")

func _turn_off_color_remap_if_enabled():
	# Check if color remap is currently enabled and turn it off
	if pixel_material_script and pixel_material_script.has_method("_on_use_palette_toggled"):
		if pixel_material_script.use_palette_check_box.button_pressed:
			pixel_material_script.use_palette_check_box.button_pressed = false
			# Trigger the toggled signal to update the shader parameter
			pixel_material_script._on_use_palette_toggled(false)
			console.log("Color remap automatically turned off for technical view mode")

func _on_track_request_create_checkpoint(track):
	console.log("Track requested checkpoint creation")
	var new_index := -1
	# Try to call create_checkpoint or add_checkpoint in models_handler
	if models_handler != null:
		if models_handler.has_method("create_checkpoint"):
			new_index = models_handler.create_checkpoint()
		elif models_handler.has_method("add_checkpoint"):
			new_index = models_handler.add_checkpoint()
		else:
			console.log("models_handler doesn't have checkpoint creation method", console.ERROR)
	else:
		console.log("models_handler not found - cannot create checkpoint", console.ERROR)

	if new_index >= 0:
		# Bind the index to the specific track
		if track and track.has_method("on_checkpoint_created"):
			track.on_checkpoint_created(new_index)
		console.log("Checkpoint " + str(new_index + 1) + " created and assigned to track")
	else:
		console.log("could not obtain created checkpoint index", console.ERROR)

func _on_track_request_become_active(track):
	# Reset activity for all tracks and set for this one
	if tracks_container:
		for t: Track in tracks_container.get_children():
			if t.has_method("set_active"):
				t.set_active(t == track)

func _on_track_request_delete(track: Track):
	print("test")
	if not track or not tracks_container:
		return
	
	# Check if this is the last track
	var track_count = 0
	for t in tracks_container.get_children():
		if t is Track:
			track_count += 1
	
	if track_count <= 1:
		console.log("Cannot delete the last track", console.WARN)
		return
	
	# Disconnect signals before removing
	if track.has_signal("request_create_checkpoint"):
		if track.request_create_checkpoint.is_connected(_on_track_request_create_checkpoint):
			track.request_create_checkpoint.disconnect(_on_track_request_create_checkpoint)
	
	if track.has_signal("request_become_active"):
		if track.request_become_active.is_connected(_on_track_request_become_active):
			track.request_become_active.disconnect(_on_track_request_become_active)
	
	if track.has_signal("request_delete_track"):
		if track.request_delete_track.is_connected(_on_track_request_delete):
			track.request_delete_track.disconnect(_on_track_request_delete)
	
	var track_name = track.get_selected_animation_name()
	tracks_container.remove_child(track)
	track.queue_free()
	
	console.log("Track '" + track_name + "' deleted", console.OK)

extends HBoxContainer
class_name Track

signal request_create_checkpoint(track: Track)
signal request_become_active(track: Track)
signal request_delete_track(track: Track)

@export var models_handler: Node = null

@onready var animation_selector: OptionButton = %AnimationSelector
@onready var anim_play_button: Button = %AnimPlayButton
@onready var anim_pause_button: Button = %AnimPauseButton
@onready var anim_stop_button: Button = %AnimStopButton
@onready var anim_loop_toggle_button: Button = %AnimLoopToggleButton
@onready var anim_slider: HSlider = %AnimSlider

@onready var start_frame_spin: SpinBox = %StartSpin
@onready var end_frame_spin: SpinBox = %EndSpin
@onready var fps_spin: SpinBox = %FpsSpin

@onready var add_checkpoint_button: Button = %AddCheckpointButton
@onready var checkpoint_buttons_container: GridContainer = %CheckpointButtonsContainer
@onready var delete_track_button: Button = %DeleteTrackButton

# Animation control
var animation_player: AnimationPlayer = null
var animation_fps: float = 30.0
var start_frame: int = 0
var end_frame: int = 0
var fps: int = 0
var total_frames: int = 0
var is_loop_enabled: bool = false
var is_slider_being_dragged: bool = false

var checkpoints: Array = []
var checkpoint_animations: Dictionary = {}

var selected_animation_name: String = ""

var is_active: bool = false

var is_playing: bool = false
var current_time: float = 0.0

# appearance
var play_active_color: Color = Color(0.6, 0.8, 0.6)
var loop_active_color: Color = Color(0.6, 0.7, 0.9)
var button_normal_color: Color = Color(1, 1, 1)

func _ready():
	if anim_play_button:
		anim_play_button.pressed.connect(_on_play_pressed)
	if anim_pause_button:
		anim_pause_button.pressed.connect(_on_pause_pressed)
	if anim_stop_button:
		anim_stop_button.pressed.connect(_on_stop_pressed)
	if anim_loop_toggle_button:
		anim_loop_toggle_button.pressed.connect(_on_loop_toggle_pressed)
	if animation_selector:
		animation_selector.item_selected.connect(_on_animation_selected)
	if anim_slider:
		anim_slider.drag_started.connect(_on_slider_drag_started)
		anim_slider.drag_ended.connect(_on_slider_drag_ended)
		anim_slider.value_changed.connect(_on_slider_value_changed)
	if start_frame_spin:
		start_frame_spin.value_changed.connect(_on_start_frame_spin_changed)
	if end_frame_spin:
		end_frame_spin.value_changed.connect(_on_end_frame_spin_changed)
	if fps_spin:
		fps_spin.value_changed.connect(_on_fps_spin_changed)

	if add_checkpoint_button:
		add_checkpoint_button.pressed.connect(_on_add_checkpoint_pressed)
	
	if delete_track_button:
		delete_track_button.pressed.connect(_on_delete_track_pressed)

	_update_loop_button_visual()
	_update_play_button_visual()
	_update_slider_range()

func set_animation_player(player: AnimationPlayer) -> void:
	animation_player = player
	if animation_player:
		animation_player.playback_process_mode = AnimationPlayer.ANIMATION_PROCESS_MANUAL
	_populate_animation_selector()
	set_active(false)

func set_active(active: bool) -> void:
	is_active = active
	modulate = Color(1,1,1, 1.0) if active else Color(0.95,0.95,0.95, 0.7)
	_update_play_button_visual()

# --- track management ---
func _on_delete_track_pressed() -> void:
	request_delete_track.emit(self)

# --- checkpoints API ---
func _on_add_checkpoint_pressed() -> void:
	request_create_checkpoint.emit(self)

func on_checkpoint_created(checkpoint_index: int) -> void:
	checkpoints.append(checkpoint_index)
	checkpoint_animations[checkpoint_index] = get_selected_animation_name()
	_add_checkpoint_button_ui(checkpoint_index)

func _add_checkpoint_button_ui(checkpoint_index: int) -> void:
	var b := Button.new()
	b.text = "CP " + str(checkpoint_index + 1)
	
	# Используем gui_input вместо pressed
	b.connect("gui_input", Callable(self, "_on_checkpoint_button_gui_input").bind(checkpoint_index))
	
	checkpoint_buttons_container.add_child(b)

func _on_checkpoint_button_gui_input(event: InputEvent, checkpoint_index: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if models_handler and models_handler.has_method("apply_checkpoint"):
				models_handler.apply_checkpoint(checkpoint_index)

			if checkpoint_animations.has(checkpoint_index):
				var anim_name = checkpoint_animations[checkpoint_index]
				if models_handler and models_handler.has_method("set_animation"):
					models_handler.set_animation(anim_name)

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_delete_checkpoint(checkpoint_index, event.get_global_position())


func _delete_checkpoint(checkpoint_index: int, mouse_pos: Vector2) -> void:
	if checkpoint_index not in checkpoints:
		return
	
	# Find and remove the checkpoint
	var checkpoint_array_index = checkpoints.find(checkpoint_index)
	if checkpoint_array_index >= 0:
		checkpoints.remove_at(checkpoint_array_index)
	
	checkpoint_animations.erase(checkpoint_index)
	
	# Find and remove the button
	for child in checkpoint_buttons_container.get_children():
		if child is Button:
			var button_cp_index = _get_checkpoint_index_from_button(child)
			if button_cp_index == checkpoint_index:
				child.queue_free()
				break
	
	print("Checkpoint " + str(checkpoint_index + 1) + " deleted")

func _get_checkpoint_index_from_button(button: Button) -> int:
	# Extract checkpoint index from button text "CP X"
	var text = button.text
	var parts = text.split(" ")
	if parts.size() >= 2:
		return int(parts[1]) - 1
	return -1

func get_checkpoint_indices() -> Array:
	if not checkpoint_buttons_container:
		return []
		
	var enabled_indices = []
	for child in checkpoint_buttons_container.get_children():
		if child is Button:
			var cp_index = _get_checkpoint_index_from_button(child)
			if cp_index >= 0 and cp_index in checkpoints:
				enabled_indices.append(cp_index)
	return enabled_indices

# --- animation population & frame controls ---
func _populate_animation_selector() -> void:
	if not animation_selector or not animation_player:
		return
		
	animation_selector.clear()
	var animation_names = []
	
	for lib_name in animation_player.get_animation_library_list():
		var library = animation_player.get_animation_library(lib_name)
		for anim_name in library.get_animation_list():
			animation_names.append(anim_name)
	
	for name in animation_names:
		animation_selector.add_item(name)
		
	if animation_selector.item_count > 0:
		animation_selector.selected = 0
		selected_animation_name = animation_selector.get_item_text(0)
		_setup_frame_controls_for(selected_animation_name)
		_update_slider_range()

func _on_animation_selected(index: int) -> void:
	if not animation_selector or not animation_player:
		return
	
	selected_animation_name = animation_selector.get_item_text(index)
	_setup_frame_controls_for(selected_animation_name)
	_update_slider_range()

# --- playback (manual) ---
func _on_play_pressed() -> void:
	if not animation_player or selected_animation_name == "":
		return
		
	request_become_active.emit(self)
	current_time = start_frame / animation_fps
	is_playing = true
	_update_play_button_visual()

func _on_pause_pressed() -> void:
	if not animation_player:
		return
	is_playing = not is_playing
	_update_play_button_visual()

func _on_stop_pressed() -> void:
	if not animation_player:
		return
		
	is_playing = false
	current_time = start_frame / animation_fps
	if anim_slider:
		anim_slider.value = 0.0
	_update_play_button_visual()

func _on_loop_toggle_pressed() -> void:
	is_loop_enabled = not is_loop_enabled
	_update_loop_button_visual()

# --- manual playback update ---
func _process(delta: float) -> void:
	if not animation_player or not is_active or selected_animation_name == "" or not is_playing:
		return
	if is_slider_being_dragged:
		return
	
	var trimmed_start_time = start_frame / animation_fps
	var trimmed_duration = _get_trimmed_duration()
	
	current_time += delta
	if current_time >= (end_frame / animation_fps):
		if is_loop_enabled:
			current_time = trimmed_start_time
		else:
			current_time = trimmed_start_time
			is_playing = false
			_update_play_button_visual()
	
	animation_player.play(selected_animation_name)
	animation_player.seek(current_time, true)
	
	# обновляем слайдер
	var pos = current_time - trimmed_start_time
	pos = clamp(pos, 0.0, trimmed_duration)
	if trimmed_duration > 0.0:
		anim_slider.value = (pos / trimmed_duration) * 100.0

# --- slider / frames ---
func _on_slider_drag_started() -> void:
	is_slider_being_dragged = true

func _on_slider_drag_ended(_changed: bool) -> void:
	is_slider_being_dragged = false

func _on_slider_value_changed(value: float) -> void:
	if not animation_player or selected_animation_name == "":
		return
	
	request_become_active.emit(self)
	if animation_player.current_animation != selected_animation_name:
		animation_player.current_animation = selected_animation_name
	
	var trimmed_duration = _get_trimmed_duration()
	var target_relative_time = (value / 100.0) * trimmed_duration
	var trimmed_start_time = start_frame / animation_fps
	current_time = trimmed_start_time + target_relative_time
	
	animation_player.play(selected_animation_name)
	animation_player.seek(current_time, true)


func _setup_frame_controls_for(anim_name: String) -> void:
	if not animation_player: 
		return
		
	var anim: Animation = animation_player.get_animation(anim_name)
	if anim == null: 
		return
		
	var length := anim.length
	total_frames = int(length * animation_fps)
	
	if start_frame_spin:
		start_frame_spin.min_value = 0
		start_frame_spin.max_value = max(0, total_frames - 1)
		start_frame_spin.value = 0
		start_frame_spin.step = 1
		
	if end_frame_spin:
		end_frame_spin.min_value = 1
		end_frame_spin.max_value = max(1, total_frames)
		end_frame_spin.value = total_frames
		end_frame_spin.step = 1
		
	start_frame = 0
	end_frame = total_frames
	current_time = 0.0

func _get_trimmed_duration() -> float:
	return max(0.0, (end_frame - start_frame) / animation_fps)

func _on_start_frame_spin_changed(value: float) -> void:
	start_frame = int(value)
	if start_frame >= end_frame:
		end_frame = start_frame + 1
		if end_frame_spin:
			end_frame_spin.value = end_frame
	if end_frame_spin:
		end_frame_spin.min_value = start_frame + 1
	_update_slider_range()

func _on_end_frame_spin_changed(value: float) -> void:
	end_frame = int(value)
	if end_frame <= start_frame:
		start_frame = end_frame - 1
		if start_frame_spin:
			start_frame_spin.value = start_frame
	if start_frame_spin:
		start_frame_spin.max_value = end_frame - 1
	_update_slider_range()

func _on_fps_spin_changed(value: float) -> void:
	fps = abs(value)
	_update_slider_range()

func _update_slider_range() -> void:
	if not anim_slider:
		return
		
	anim_slider.min_value = 0.0
	anim_slider.max_value = 100.0
	anim_slider.step = 0.1

func _update_loop_button_visual() -> void:
	if not anim_loop_toggle_button:
		return
		
	anim_loop_toggle_button.button_pressed = is_loop_enabled
	anim_loop_toggle_button.modulate = loop_active_color if is_loop_enabled else button_normal_color

func _update_play_button_visual() -> void:
	if not anim_play_button:
		return
		
	var playing_this := is_playing and is_active
	anim_play_button.modulate = play_active_color if playing_this else button_normal_color

# --- public helpers ---
func get_selected_animation_name() -> String:
	return selected_animation_name

func get_export_settings() -> Dictionary:
	return {
		"start_frame": start_frame,
		"end_frame": end_frame,
		"fps": fps_spin.value if fps_spin else animation_fps
	}

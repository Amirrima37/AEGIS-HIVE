extends Camera2D
class_name IsometricCamera

@export var pan_speed: float = 800.0
@export var min_zoom: float = 0.35
@export var max_zoom: float = 3.0
@export var zoom_step: float = 0.15
@export var zoom_smoothness: float = 12.0
@export var layer_manager: LayerManager = null

var _target_zoom: Vector2 = Vector2.ONE
var _is_dragging: bool = false
var _drag_start_mouse_pos: Vector2 = Vector2.ZERO
var _drag_start_cam_pos: Vector2 = Vector2.ZERO

func _get_layer_manager() -> LayerManager:
	if layer_manager and is_instance_valid(layer_manager):
		return layer_manager
	if is_inside_tree():
		layer_manager = get_tree().root.find_child("LayerManager", true, false)
		return layer_manager
	return null

func _ready() -> void:
	_target_zoom = zoom
	# Allow mouse to be used even without UI focus
	position_smoothing_enabled = false

func _process(delta: float) -> void:
	_handle_keyboard_pan(delta)
	_handle_zoom_lerp(delta)

func _handle_keyboard_pan(delta: float) -> void:
	var dir = Vector2.ZERO
	# Support both physical keycodes (independent of active keyboard layout) and logical keys
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	
	# Gamepad / Steam Deck left analog stick pan
	var joy_x = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var joy_y = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if abs(joy_x) > 0.15:
		dir.x += joy_x
	if abs(joy_y) > 0.15:
		dir.y += joy_y
	
	if dir != Vector2.ZERO:
		# Normalize and scale so screen movement speed feels natural regardless of zoom
		position += dir.normalized() * (pan_speed / zoom.x) * delta

func _handle_zoom_lerp(delta: float) -> void:
	if zoom.distance_to(_target_zoom) > 0.001:
		zoom = zoom.lerp(_target_zoom, delta * zoom_smoothness)
		EventBus.camera_zoom_changed.emit(zoom.x)

func _unhandled_input(event: InputEvent) -> void:
	# Mouse drag pan (Middle mouse button or Right mouse button)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_is_dragging = true
				_drag_start_mouse_pos = event.position
				_drag_start_cam_pos = position
				get_viewport().set_input_as_handled()
			else:
				if _is_dragging:
					_is_dragging = false
					get_viewport().set_input_as_handled()
		
		# Mouse wheel zoom
		elif event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at_mouse(1.0 + zoom_step, event.position)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at_mouse(1.0 - zoom_step, event.position)
				get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion and _is_dragging:
		var delta_mouse = event.position - _drag_start_mouse_pos
		position = _drag_start_cam_pos - (delta_mouse / zoom.x)
		get_viewport().set_input_as_handled()

	# Keyboard hotkeys for layer switching and creation
	elif event is InputEventKey and event.pressed and not event.echo:
		var is_shift = event.shift_pressed
		var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code == KEY_Q:
			if is_shift:
				_request_create_layer(1)
			else:
				EventBus.layer_change_requested.emit(1)
			get_viewport().set_input_as_handled()
		elif code == KEY_E:
			if is_shift:
				_request_create_layer(-1)
			else:
				EventBus.layer_change_requested.emit(-1)
			get_viewport().set_input_as_handled()
	
	# Gamepad / Steam Deck shoulder buttons for layer navigation
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			EventBus.layer_change_requested.emit(1)
			get_viewport().set_input_as_handled()
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			EventBus.layer_change_requested.emit(-1)
			get_viewport().set_input_as_handled()

func _zoom_at_mouse(factor: float, mouse_screen_pos: Vector2) -> void:
	var old_zoom_val = _target_zoom.x
	var new_zoom_val = clamp(_target_zoom.x * factor, min_zoom, max_zoom)
	if is_equal_approx(old_zoom_val, new_zoom_val):
		return
		
	# При зуме смещаем камеру так, чтобы точка под курсором оставалась неподвижной
	var viewport_size = get_viewport_rect().size
	var mouse_offset_from_center = mouse_screen_pos - viewport_size * 0.5
	var world_shift = (mouse_offset_from_center / old_zoom_val) - (mouse_offset_from_center / new_zoom_val)
	position += world_shift
	_target_zoom = Vector2(new_zoom_val, new_zoom_val)

func _request_create_layer(direction: int) -> void:
	# Direction: +1 for upper floor, -1 for underground
	var lm = _get_layer_manager()
	var prev_count: int = lm.get_existing_z_levels().size() if (lm and lm.has_method("get_existing_z_levels")) else 0
	if direction > 0:
		EventBus.request_create_layer_above.emit()
	else:
		EventBus.request_create_layer_below.emit()
	# When the player explicitly triggers layer creation via Shift+Q / Shift+E,
	# switch directly to the newly unlocked layer for clear visual feedback.
	if lm and lm.has_method("get_existing_z_levels"):
		var keys: Array = lm.get_existing_z_levels()
		if keys.size() > prev_count and not keys.is_empty():
			var target_z = keys.max() if direction > 0 else keys.min()
			EventBus.layer_jump_requested.emit(target_z)

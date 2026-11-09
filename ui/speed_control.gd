class_name SpeedControl
extends PanelContainer

const BrutalistTheme = preload("res://ui/brutalist_theme.gd")

@onready var label_tick: Label = $MarginContainer/HBoxContainer/LabelTick
@onready var btn_speed1: Button = $MarginContainer/HBoxContainer/BtnSpeed1
@onready var btn_speed2: Button = $MarginContainer/HBoxContainer/BtnSpeed2
@onready var btn_speed3: Button = $MarginContainer/HBoxContainer/BtnSpeed3
@onready var btn_pause: Button = $MarginContainer/HBoxContainer/BtnPause

var _is_compact: bool = false

func _ready() -> void:
	add_theme_stylebox_override("panel", BrutalistTheme.create_panel_style(
		BrutalistTheme.BG_PANEL,
		BrutalistTheme.BORDER_DARK,
		4,
		6
	))
	
	if btn_speed1:
		BrutalistTheme.apply_button_styles(btn_speed1)
		btn_speed1.pressed.connect(func(): set_speed(1.0))
	if btn_speed2:
		BrutalistTheme.apply_button_styles(btn_speed2)
		btn_speed2.pressed.connect(func(): set_speed(2.0))
	if btn_speed3:
		BrutalistTheme.apply_button_styles(btn_speed3)
		btn_speed3.pressed.connect(func(): set_speed(3.0))
	if btn_pause:
		BrutalistTheme.apply_button_styles(btn_pause)
		btn_pause.pressed.connect(toggle_pause)
	
	if EventBus:
		EventBus.game_speed_changed.connect(_on_speed_changed)
		EventBus.game_paused.connect(_on_pause_changed)
		if EventBus.has_signal("tick"):
			EventBus.tick.connect(_on_tick)
		
	_update_visuals()

func _on_tick(tick_count: int) -> void:
	if label_tick:
		label_tick.text = "ТИК #%d" % tick_count

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code == KEY_1:
			set_speed(1.0)
		elif code == KEY_2:
			set_speed(2.0)
		elif code == KEY_3:
			set_speed(3.0)
		elif code == KEY_SPACE:
			toggle_pause()

func set_speed(speed: float) -> void:
	GameState.game_speed = speed
	EventBus.game_speed_changed.emit(speed)
	if GameState.is_paused:
		GameState.is_paused = false
		EventBus.game_paused.emit(false)
	_update_visuals()

func toggle_pause() -> void:
	GameState.is_paused = !GameState.is_paused
	EventBus.game_paused.emit(GameState.is_paused)
	_update_visuals()

func _on_speed_changed(_speed: float) -> void:
	_update_visuals()

func _on_pause_changed(_paused: bool) -> void:
	_update_visuals()

func set_compact_mode(compact: bool) -> void:
	_is_compact = compact
	if label_tick:
		label_tick.custom_minimum_size = Vector2(56, 0) if compact else Vector2(80, 0)
		label_tick.add_theme_font_size_override("font_size", 11 if compact else 13)
	if btn_pause:
		btn_pause.custom_minimum_size = Vector2(36, 32) if compact else Vector2(80, 32)
	for b in [btn_speed1, btn_speed2, btn_speed3]:
		if is_instance_valid(b):
			b.custom_minimum_size = Vector2(32, 32) if compact else Vector2(40, 32)
	_update_visuals()

func _update_visuals() -> void:
	var paused = GameState.is_paused
	var speed = GameState.game_speed
	
	if btn_pause:
		if paused:
			btn_pause.add_theme_stylebox_override("normal", BrutalistTheme.create_active_button_style())
			btn_pause.text = "▶" if _is_compact else "▶ Старт"
			btn_pause.add_theme_color_override("font_color", BrutalistTheme.TEXT_AMBER)
		else:
			btn_pause.remove_theme_stylebox_override("normal")
			btn_pause.text = "⏸" if _is_compact else "⏸ Пауза"
			btn_pause.add_theme_color_override("font_color", BrutalistTheme.TEXT_BRIGHT)
		
	if btn_speed1:
		_highlight_speed_button(btn_speed1, speed == 1.0 and not paused)
	if btn_speed2:
		_highlight_speed_button(btn_speed2, speed == 2.0 and not paused)
	if btn_speed3:
		_highlight_speed_button(btn_speed3, speed == 3.0 and not paused)

func _highlight_speed_button(btn: Button, is_active: bool) -> void:
	if is_active:
		btn.add_theme_stylebox_override("normal", BrutalistTheme.create_active_button_style())
		btn.add_theme_color_override("font_color", BrutalistTheme.TEXT_AMBER)
	else:
		btn.remove_theme_stylebox_override("normal")
		btn.add_theme_color_override("font_color", BrutalistTheme.TEXT_MUTED)

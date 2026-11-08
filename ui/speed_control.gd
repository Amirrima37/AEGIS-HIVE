class_name SpeedControl
extends PanelContainer

@onready var btn_speed1: Button = $MarginContainer/HBoxContainer/BtnSpeed1
@onready var btn_speed2: Button = $MarginContainer/HBoxContainer/BtnSpeed2
@onready var btn_speed3: Button = $MarginContainer/HBoxContainer/BtnSpeed3
@onready var btn_pause: Button = $MarginContainer/HBoxContainer/BtnPause

func _ready() -> void:
	btn_speed1.pressed.connect(func(): set_speed(1.0))
	btn_speed2.pressed.connect(func(): set_speed(2.0))
	btn_speed3.pressed.connect(func(): set_speed(3.0))
	btn_pause.pressed.connect(toggle_pause)
	
	if EventBus:
		EventBus.game_speed_changed.connect(_on_speed_changed)
		EventBus.game_paused.connect(_on_pause_changed)
		
	_update_visuals()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			set_speed(1.0)
		elif event.keycode == KEY_2:
			set_speed(2.0)
		elif event.keycode == KEY_3:
			set_speed(3.0)
		elif event.keycode == KEY_SPACE:
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

func _update_visuals() -> void:
	var paused = GameState.is_paused
	var speed = GameState.game_speed
	
	if btn_pause:
		btn_pause.modulate = Color(1.4, 0.6, 0.6, 1.0) if paused else Color(1.0, 1.0, 1.0, 0.8)
		btn_pause.text = "▶ Продолжить" if paused else "⏸ Пауза"
		
	if btn_speed1:
		btn_speed1.modulate = Color(0.4, 1.2, 1.5, 1.0) if (speed == 1.0 and not paused) else Color(1.0, 1.0, 1.0, 0.8)
	if btn_speed2:
		btn_speed2.modulate = Color(0.4, 1.2, 1.5, 1.0) if (speed == 2.0 and not paused) else Color(1.0, 1.0, 1.0, 0.8)
	if btn_speed3:
		btn_speed3.modulate = Color(0.4, 1.2, 1.5, 1.0) if (speed == 3.0 and not paused) else Color(1.0, 1.0, 1.0, 0.8)

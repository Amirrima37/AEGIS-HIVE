extends Node

enum GameMode { STANDARD, UNLIMITED }

var current_layer: int = 0
var game_speed: float = 1.0
var is_paused: bool = false
var tick_count: int = 0
var current_game_mode: GameMode = GameMode.STANDARD

func _ready() -> void:
	if EventBus:
		EventBus.active_layer_changed.connect(_on_active_layer_changed)
		EventBus.game_speed_changed.connect(_on_game_speed_changed)
		EventBus.game_paused.connect(_on_game_paused)

func _on_active_layer_changed(z: int) -> void:
	current_layer = z

func _on_game_speed_changed(speed: float) -> void:
	game_speed = speed

func _on_game_paused(paused: bool) -> void:
	is_paused = paused

func is_unlimited_mode() -> bool:
	return current_game_mode == GameMode.UNLIMITED

func set_game_mode(mode: GameMode) -> void:
	current_game_mode = mode
	var mode_name = "unlimited" if mode == GameMode.UNLIMITED else "standard"
	if EventBus and EventBus.has_signal("game_mode_changed"):
		EventBus.game_mode_changed.emit(mode_name)

func toggle_unlimited_mode() -> void:
	if current_game_mode == GameMode.STANDARD:
		set_game_mode(GameMode.UNLIMITED)
	else:
		set_game_mode(GameMode.STANDARD)

class_name GameHUD
extends CanvasLayer

@onready var label_energy: Label = $TopBar/MarginContainer/HBoxContainer/ResEnergy
@onready var label_ore: Label = $TopBar/MarginContainer/HBoxContainer/ResOre
@onready var label_materials: Label = $TopBar/MarginContainer/HBoxContainer/ResMaterials
@onready var label_population: Label = $TopBar/MarginContainer/HBoxContainer/ResPopulation
@onready var btn_game_mode: Button = $TopBar/MarginContainer/HBoxContainer/BtnGameMode

func _ready() -> void:
	if EventBus:
		EventBus.resource_changed.connect(_on_resource_changed)
		if EventBus.has_signal("game_mode_changed"):
			EventBus.game_mode_changed.connect(_on_game_mode_changed)
			
	if btn_game_mode:
		btn_game_mode.pressed.connect(_on_btn_game_mode_pressed)
		
	_update_mode_button()
	_update_all_resources()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			if GameState and GameState.has_method("toggle_unlimited_mode"):
				GameState.toggle_unlimited_mode()
				get_viewport().set_input_as_handled()

func _on_btn_game_mode_pressed() -> void:
	if GameState and GameState.has_method("toggle_unlimited_mode"):
		GameState.toggle_unlimited_mode()

func _on_game_mode_changed(_mode_name: String) -> void:
	_update_mode_button()
	_update_all_resources()

func _update_mode_button() -> void:
	if not is_instance_valid(btn_game_mode):
		return
	var is_unl = GameState and GameState.has_method("is_unlimited_mode") and GameState.is_unlimited_mode()
	if is_unl:
		btn_game_mode.text = "♾ Режим: Неограниченный [F3]"
		btn_game_mode.modulate = Color(1.0, 0.85, 0.3) # Gold/Amber highlight
	else:
		btn_game_mode.text = "🛠 Режим: Стандарт [F3]"
		btn_game_mode.modulate = Color(0.8, 0.9, 1.0)

func _update_all_resources() -> void:
	var is_unl = GameState and GameState.has_method("is_unlimited_mode") and GameState.is_unlimited_mode()
	if label_energy:
		label_energy.text = "⚡ Энергия: %s" % ("∞" if is_unl else ("%d МВт" % ResourceManager.get_resource("energy")))
	if label_ore:
		label_ore.text = "⛏ Руда: %s" % ("∞" if is_unl else ("%d т" % ResourceManager.get_resource("ore")))
	if label_materials:
		label_materials.text = "🏗 Материалы: %s" % ("∞" if is_unl else ("%d т" % ResourceManager.get_resource("materials")))
	if label_population:
		var cur_pop = ResourceManager.get_resource("population")
		var cap_pop = ResourceManager.get_resource("population_capacity")
		if is_unl:
			label_population.text = "👥 Персонал: %d / %d [∞]" % [cur_pop, cap_pop]
		else:
			label_population.text = "👥 Персонал: %d / %d" % [cur_pop, cap_pop]

func _on_resource_changed(_res_name: String, _new_amount: int) -> void:
	_update_all_resources()

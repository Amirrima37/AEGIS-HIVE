class_name OverlayToggle
extends PanelContainer

@onready var btn_power: Button = $MarginContainer/HBoxContainer/BtnPower
@onready var btn_supply: Button = $MarginContainer/HBoxContainer/BtnSupply

func _ready() -> void:
	if btn_power:
		btn_power.toggle_mode = true
		btn_power.toggled.connect(_on_power_toggled)
	if btn_supply:
		btn_supply.toggle_mode = true
		btn_supply.toggled.connect(_on_supply_toggled)
		
	if EventBus and EventBus.has_signal("overlay_toggled"):
		EventBus.overlay_toggled.connect(_on_external_overlay_toggled)

func _on_power_toggled(pressed: bool) -> void:
	if EventBus and EventBus.has_signal("overlay_toggled"):
		EventBus.overlay_toggled.emit("power", pressed)

func _on_supply_toggled(pressed: bool) -> void:
	if EventBus and EventBus.has_signal("overlay_toggled"):
		EventBus.overlay_toggled.emit("supply", pressed)

func _on_external_overlay_toggled(overlay_name: String, is_visible: bool) -> void:
	if overlay_name == "power" and btn_power and btn_power.button_pressed != is_visible:
		btn_power.set_pressed_no_signal(is_visible)
	elif overlay_name == "supply" and btn_supply and btn_supply.button_pressed != is_visible:
		btn_supply.set_pressed_no_signal(is_visible)

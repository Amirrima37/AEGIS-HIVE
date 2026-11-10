class_name OverlayToggle
extends PanelContainer

const BrutalistTheme = preload("res://ui/brutalist_theme.gd")

@onready var vbox: VBoxContainer = $MarginContainer/VBoxContainer
@onready var btn_power: Button = $MarginContainer/VBoxContainer/BtnPower
@onready var btn_supply: Button = $MarginContainer/VBoxContainer/BtnSupply
@onready var btn_integrity: Button = $MarginContainer/VBoxContainer/BtnIntegrity
@onready var btn_sensors: Button = $MarginContainer/VBoxContainer/BtnSensors
@onready var btn_minerals: Button = $MarginContainer/VBoxContainer/BtnMinerals

var _overlay_states: Dictionary = {
	"power": false,
	"supply": false,
	"integrity": false,
	"sensors": false,
	"minerals": false
}

func _ready() -> void:
	add_theme_stylebox_override("panel", BrutalistTheme.create_panel_style(
		BrutalistTheme.BG_PANEL,
		BrutalistTheme.BORDER_DARK,
		4,
		4
	))
	
	_setup_button(btn_power, "power", "Отображение энергосети и кабельных линий [F1]")
	_setup_button(btn_supply, "supply", "Отображение транспортных связей и конвейеров [F2]")
	_setup_button(btn_integrity, "integrity", "Отображение брони и состояния прочности построек [F4]")
	_setup_button(btn_sensors, "sensors", "Зоны покрытия радаров и ПВО [в разработке]", true)
	_setup_button(btn_minerals, "minerals", "Геологическая разведка залежей недр [в разработке]", true)
		
	if EventBus and EventBus.has_signal("overlay_toggled"):
		EventBus.overlay_toggled.connect(_on_external_overlay_toggled)

func set_compact_mode(compact: bool) -> void:
	if is_instance_valid(vbox):
		vbox.add_theme_constant_override("separation", 3 if compact else 6)
	var sz := Vector2(158, 24) if compact else Vector2(170, 30)
	for b in [btn_power, btn_supply, btn_integrity, btn_sensors, btn_minerals]:
		if is_instance_valid(b):
			b.custom_minimum_size = sz
			b.add_theme_font_size_override("font_size", 11 if compact else 13)

func _setup_button(btn: Button, overlay_id: String, tip: String, is_soon: bool = false) -> void:
	if not is_instance_valid(btn):
		return
	btn.tooltip_text = tip
	BrutalistTheme.apply_button_styles(btn)
	if is_soon:
		btn.toggle_mode = false
		btn.disabled = true
		btn.add_theme_color_override("font_color", BrutalistTheme.TEXT_MUTED)
		btn.add_theme_color_override("font_disabled_color", Color(0.60, 0.66, 0.74, 0.90))
		return
	btn.toggle_mode = true
	btn.toggled.connect(func(pressed: bool): _on_button_toggled(overlay_id, pressed, btn, is_soon))

func _on_button_toggled(overlay_id: String, pressed: bool, btn: Button, is_soon: bool = false) -> void:
	_overlay_states[overlay_id] = pressed
	BrutalistTheme.set_button_active(btn, pressed)
	if pressed:
		btn.add_theme_color_override("font_color", BrutalistTheme.TEXT_AMBER)
	else:
		btn.add_theme_color_override("font_color", BrutalistTheme.TEXT_MUTED if is_soon else BrutalistTheme.TEXT_BRIGHT)
		
	if EventBus and EventBus.has_signal("overlay_toggled"):
		EventBus.overlay_toggled.emit(overlay_id, pressed)

func _on_external_overlay_toggled(overlay_name: String, is_visible: bool) -> void:
	var btn: Button = null
	var is_soon := false
	match overlay_name:
		"power": btn = btn_power
		"supply": btn = btn_supply
		"integrity": btn = btn_integrity
		"sensors":
			btn = btn_sensors
			is_soon = true
		"minerals":
			btn = btn_minerals
			is_soon = true
		
	if btn and btn.button_pressed != is_visible:
		btn.set_pressed_no_signal(is_visible)
		BrutalistTheme.set_button_active(btn, is_visible)
		if is_visible:
			btn.add_theme_color_override("font_color", BrutalistTheme.TEXT_AMBER)
		else:
			btn.add_theme_color_override("font_color", BrutalistTheme.TEXT_MUTED if is_soon else BrutalistTheme.TEXT_BRIGHT)

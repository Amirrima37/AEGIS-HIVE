class_name BuildToolbar
extends PanelContainer

@onready var buttons_container: HBoxContainer = $MarginContainer/HBoxContainer

var _building_resources: Array[BuildingData] = []
var _building_buttons: Dictionary = {} # BuildingData -> Button
var _demolish_button: Button = null

const BUILDING_PATHS = [
	"res://data/buildings/command_center.tres",
	"res://data/buildings/fusion_reactor.tres",
	"res://data/buildings/quarry.tres",
	"res://data/buildings/factory.tres",
	"res://data/buildings/habitation_block.tres",
	"res://data/buildings/support_pillar.tres",
	"res://data/buildings/excavation_rig.tres",
	"res://data/buildings/power_cable.tres",
	"res://data/buildings/conveyor.tres",
	"res://data/buildings/shaft_elevator.tres",
	"res://data/buildings/warehouse.tres",
	"res://data/buildings/defense_wall.tres",
	"res://data/buildings/autocannon_turret.tres",
	"res://data/buildings/heavy_railgun.tres",
	"res://data/buildings/shield_generator.tres",
	"res://data/buildings/munitions_factory.tres",
	"res://data/buildings/sensor_tower.tres",
	"res://data/buildings/repair_depot.tres"
]

func _ready() -> void:
	_load_building_data()
	_create_ui_buttons()
	
	if EventBus:
		EventBus.resource_changed.connect(_on_resources_updated)
		EventBus.building_placed.connect(_on_buildings_updated)
		EventBus.building_removed.connect(_on_buildings_updated)
		EventBus.build_mode_exited.connect(_update_button_highlights)
		if EventBus.has_signal("cable_mode_exited"):
			EventBus.cable_mode_exited.connect(_update_button_highlights)
		EventBus.demolish_mode_exited.connect(_update_button_highlights)
	
	_update_affordability()

func _load_building_data() -> void:
	_building_resources.clear()
	for path in BUILDING_PATHS:
		if ResourceLoader.exists(path):
			var res = load(path) as BuildingData
			if res:
				_building_resources.append(res)

func _create_ui_buttons() -> void:
	# Clear old children if any
	for c in buttons_container.get_children():
		c.queue_free()
	_building_buttons.clear()
	
	for b_data in _building_resources:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(95, 44)
		
		# Format cost string
		var cost_str = ""
		if b_data.cost_ore > 0 or b_data.cost_materials > 0:
			cost_str = "\n⛏%d 🏗%d" % [b_data.cost_ore, b_data.cost_materials]
		else:
			cost_str = "\n(Старт)"
			
		btn.text = "%s%s" % [b_data.display_name, cost_str]
		
		# Detailed tooltip
		var tip = "%s\nРазмер: %d×%d\nСтоимость: Руда %d, Материалы %d" % [
			b_data.description, b_data.tile_size.x, b_data.tile_size.y,
			b_data.cost_ore, b_data.cost_materials
		]
		if b_data.energy_production > 0:
			tip += "\nЭнергия: +%d МВт" % b_data.energy_production
		if b_data.energy_consumption > 0:
			tip += "\nПотребление: -%d МВт" % b_data.energy_consumption
		if b_data.ore_production > 0:
			tip += "\nДобыча руды: +%d т" % b_data.ore_production
		if b_data.materials_production > 0:
			tip += "\nПроизводство материалов: +%d т" % b_data.materials_production
		btn.tooltip_text = tip
		
		var captured_data = b_data
		btn.pressed.connect(func(): _on_building_button_pressed(captured_data))
		
		buttons_container.add_child(btn)
		_building_buttons[b_data] = btn
		
	# Separator
	var sep = VSeparator.new()
	buttons_container.add_child(sep)
	
	# Demolish button
	_demolish_button = Button.new()
	_demolish_button.name = "BtnDemolish"
	_demolish_button.custom_minimum_size = Vector2(80, 44)
	_demolish_button.text = "🔨 Снос"
	_demolish_button.tooltip_text = "Режим сноса зданий. Возвращает 50% стоимости."
	_demolish_button.modulate = Color(1.3, 0.6, 0.6, 1.0)
	_demolish_button.pressed.connect(_on_demolish_pressed)
	buttons_container.add_child(_demolish_button)

func _on_building_button_pressed(data: BuildingData) -> void:
	if data.is_connector and data.network_type in ["power_cable", "supply_cable"]:
		EventBus.cable_mode_entered.emit(data)
	else:
		EventBus.build_mode_entered.emit(data)
	_highlight_active_button(_building_buttons.get(data))

func _on_demolish_pressed() -> void:
	EventBus.demolish_mode_entered.emit()
	_highlight_active_button(_demolish_button)

func _highlight_active_button(active_btn: Button) -> void:
	for b in _building_buttons.values():
		b.flat = (b != active_btn)
	if _demolish_button:
		_demolish_button.flat = (_demolish_button != active_btn)

func _update_button_highlights() -> void:
	_highlight_active_button(null)

func _on_resources_updated(_res_name: String, _amount: int) -> void:
	_update_affordability()

func _on_buildings_updated(_b: Node2D) -> void:
	_update_affordability()

func _update_affordability() -> void:
	var bm = get_tree().root.find_child("BuildingManager", true, false)
	
	for b_data in _building_buttons.keys():
		var btn: Button = _building_buttons[b_data]
		if not is_instance_valid(btn):
			continue
			
		var can_afford = ResourceManager.can_afford({
			"ore": b_data.cost_ore,
			"materials": b_data.cost_materials
		})
		
		var unique_blocked = false
		if b_data.id == &"command_center" and bm and bm.has_method("get_building_count"):
			if bm.get_building_count(&"command_center") > 0:
				unique_blocked = true
				
		if can_afford and not unique_blocked:
			btn.disabled = false
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			btn.disabled = true
			btn.modulate = Color(0.7, 0.7, 0.7, 0.45)

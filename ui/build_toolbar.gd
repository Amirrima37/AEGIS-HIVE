class_name BuildToolbar
extends PanelContainer

const BrutalistTheme = preload("res://ui/brutalist_theme.gd")

signal shelf_visibility_changed(is_open: bool)

# Two-tier modular build toolbar in brutalist style.
# Tier 1: CategoryDock (Bottom Bar) - Macro categories & demolish tool
# Tier 2: BuildShelf (Popover Shelf) - Sub-category tabs & building card slots

var _building_resources: Array[BuildingData] = []
var _building_buttons: Dictionary = {} # BuildingData -> Button (Maintained for T3.6 test compliance)
var _category_buttons: Dictionary = {} # String (cat_id) -> Button
var _sub_tab_buttons: Dictionary = {} # String (tab_id) -> Button
var _demolish_button: Button = null

var _active_category: String = ""
var _active_sub_tab: String = "all"
var _selected_building: BuildingData = null

# UI Node References
var root_vbox: VBoxContainer = null
var shelf_panel: PanelContainer = null
var shelf_tabs_container: HBoxContainer = null
var shelf_scroll: ScrollContainer = null
var shelf_cards_container: HBoxContainer = null
var shelf_title_label: Label = null
var dock_panel: PanelContainer = null
var dock_buttons_container: HBoxContainer = null
var _is_compact: bool = false

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
	"res://data/buildings/repair_depot.tres",
	"res://data/buildings/armor_deck.tres"
]

const CATEGORY_DEFS = {
	"city": {
		"title": "ГОРОД",
		"icon": "🏛",
		"tabs": {
			"all": {"label": "Все", "buildings": ["command_center", "habitation_block"]},
			"admin": {"label": "Штаб и Жилье", "buildings": ["command_center", "habitation_block"]}
		}
	},
	"production": {
		"title": "ПРОИЗВОДСТВО",
		"icon": "⚙",
		"tabs": {
			"all": {"label": "Все", "buildings": ["fusion_reactor", "quarry", "excavation_rig", "factory"]},
			"power": {"label": "Генерация", "buildings": ["fusion_reactor"]},
			"mining": {"label": "Добыча", "buildings": ["quarry", "excavation_rig"]},
			"industry": {"label": "Переработка", "buildings": ["factory"]}
		}
	},
	"logistics": {
		"title": "ЛОГИСТИКА",
		"icon": "🔗",
		"tabs": {
			"all": {"label": "Все", "buildings": ["power_cable", "conveyor", "shaft_elevator", "support_pillar", "warehouse"]},
			"networks": {"label": "Сети", "buildings": ["power_cable", "conveyor"]},
			"vertical": {"label": "Вертикаль", "buildings": ["shaft_elevator", "support_pillar"]},
			"storage": {"label": "Склады", "buildings": ["warehouse"]}
		}
	},
	"defense": {
		"title": "ОБОРОНА",
		"icon": "🛡",
		"tabs": {
			"all": {"label": "Все", "buildings": ["defense_wall", "autocannon_turret", "heavy_railgun", "shield_generator", "armor_deck", "sensor_tower", "repair_depot", "munitions_factory"]},
			"combat": {"label": "Орудия и Стены", "buildings": ["defense_wall", "armor_deck", "autocannon_turret", "heavy_railgun"]},
			"support": {"label": "Щиты и Ремонт", "buildings": ["shield_generator", "sensor_tower", "repair_depot"]},
			"ammo": {"label": "Боеприпасы", "buildings": ["munitions_factory"]}
		}
	}
}

func _ready() -> void:
	_load_building_data()
	_build_ui_structure()
	
	if EventBus:
		EventBus.resource_changed.connect(_on_resources_updated)
		EventBus.building_placed.connect(_on_buildings_updated)
		EventBus.building_removed.connect(_on_buildings_updated)
		EventBus.build_mode_exited.connect(_update_button_highlights)
		if EventBus.has_signal("cable_mode_exited"):
			EventBus.cable_mode_exited.connect(_update_button_highlights)
		EventBus.demolish_mode_exited.connect(_update_button_highlights)
		if EventBus.has_signal("game_mode_changed"):
			EventBus.game_mode_changed.connect(_on_game_mode_changed)
	
	_update_affordability()

func _load_building_data() -> void:
	_building_resources.clear()
	for path in BUILDING_PATHS:
		if ResourceLoader.exists(path):
			var res = load(path) as BuildingData
			if res:
				_building_resources.append(res)

func _build_ui_structure() -> void:
	for child in get_children():
		child.queue_free()
	_building_buttons.clear()
	_category_buttons.clear()
	_sub_tab_buttons.clear()

	var empty_sb = StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", empty_sb)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	root_vbox = VBoxContainer.new()
	root_vbox.name = "RootVBox"
	root_vbox.add_theme_constant_override("separation", 8)
	root_vbox.alignment = BoxContainer.ALIGNMENT_END
	root_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_vbox)

	# --- 1. BUILD SHELF (Tier 2: Pop-up Panel above dock) ---
	shelf_panel = PanelContainer.new()
	shelf_panel.name = "BuildShelf"
	shelf_panel.visible = false
	shelf_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var shelf_sb = BrutalistTheme.create_panel_style(
		BrutalistTheme.BG_PANEL,
		BrutalistTheme.BORDER_DARK,
		4,
		10
	)
	shelf_panel.add_theme_stylebox_override("panel", shelf_sb)
	root_vbox.add_child(shelf_panel)

	var shelf_vbox = VBoxContainer.new()
	shelf_vbox.add_theme_constant_override("separation", 8)
	shelf_panel.add_child(shelf_vbox)

	# Shelf Header Bar
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	shelf_vbox.add_child(header_hbox)

	shelf_title_label = Label.new()
	shelf_title_label.name = "ShelfTitle"
	shelf_title_label.text = "ОБОРОНА"
	shelf_title_label.add_theme_color_override("font_color", BrutalistTheme.TEXT_AMBER)
	shelf_title_label.add_theme_font_size_override("font_size", 13)
	header_hbox.add_child(shelf_title_label)

	var title_sep = VSeparator.new()
	header_hbox.add_child(title_sep)

	shelf_tabs_container = HBoxContainer.new()
	shelf_tabs_container.name = "SubTabsContainer"
	shelf_tabs_container.add_theme_constant_override("separation", 6)
	shelf_tabs_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(shelf_tabs_container)

	var btn_close = Button.new()
	btn_close.name = "BtnCloseShelf"
	btn_close.text = " ✕ "
	btn_close.tooltip_text = "Закрыть панель выбора [ESC]"
	btn_close.custom_minimum_size = Vector2(28, 26)
	BrutalistTheme.apply_button_styles(btn_close)
	btn_close.pressed.connect(_close_shelf)
	header_hbox.add_child(btn_close)

	var shelf_hsep = HSeparator.new()
	shelf_vbox.add_child(shelf_hsep)

	# Cards Grid/Row (all 8 defense cards fit cleanly without scrollbar clipping on desktop)
	shelf_scroll = ScrollContainer.new()
	shelf_scroll.custom_minimum_size = Vector2(948, 128)
	shelf_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shelf_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	shelf_vbox.add_child(shelf_scroll)

	shelf_cards_container = HBoxContainer.new()
	shelf_cards_container.name = "CardsContainer"
	shelf_cards_container.add_theme_constant_override("separation", 8)
	shelf_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelf_scroll.add_child(shelf_cards_container)

	# --- 2. CATEGORY DOCK (Tier 1: Bottom Primary Bar) ---
	dock_panel = PanelContainer.new()
	dock_panel.name = "CategoryDock"
	dock_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var dock_sb = BrutalistTheme.create_panel_style(
		BrutalistTheme.BG_PANEL,
		BrutalistTheme.BORDER_DARK,
		4,
		6
	)
	dock_panel.add_theme_stylebox_override("panel", dock_sb)
	root_vbox.add_child(dock_panel)

	dock_buttons_container = HBoxContainer.new()
	dock_buttons_container.name = "DockHBox"
	dock_buttons_container.add_theme_constant_override("separation", 10)
	dock_buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_panel.add_child(dock_buttons_container)

	# Instantiate Category Buttons
	for cat_id in ["city", "production", "logistics", "defense"]:
		var cat_data = CATEGORY_DEFS[cat_id]
		var btn = Button.new()
		btn.name = "BtnCat_" + cat_id
		btn.custom_minimum_size = Vector2(142, 40)
		btn.text = "%s %s" % [cat_data["icon"], cat_data["title"]]
		BrutalistTheme.apply_button_styles(btn)
		
		var captured_id = cat_id
		btn.pressed.connect(func(): _on_category_button_pressed(captured_id))
		dock_buttons_container.add_child(btn)
		_category_buttons[cat_id] = btn

	var dock_sep = VSeparator.new()
	dock_buttons_container.add_child(dock_sep)

	# Demolish Tool Button
	_demolish_button = Button.new()
	_demolish_button.name = "BtnDemolish"
	_demolish_button.custom_minimum_size = Vector2(110, 40)
	_demolish_button.text = "🔨 СНОС"
	_demolish_button.tooltip_text = "Режим деконструкции построек.\nВозвращает 50% потраченных ресурсов."
	BrutalistTheme.apply_button_styles(_demolish_button, true)
	_demolish_button.pressed.connect(_on_demolish_pressed)
	dock_buttons_container.add_child(_demolish_button)

	_create_all_building_cards()

func _create_all_building_cards() -> void:
	for b_data in _building_resources:
		var card_btn = Button.new()
		card_btn.name = "Card_" + str(b_data.id)
		card_btn.custom_minimum_size = Vector2(110, 118)
		card_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		if b_data.icon:
			card_btn.icon = b_data.icon
			card_btn.expand_icon = true
		elif b_data.sprite:
			card_btn.icon = b_data.sprite
			card_btn.expand_icon = true
		card_btn.add_theme_constant_override("icon_max_width", 48)
		card_btn.add_theme_font_size_override("font_size", 11)
		
		var cost_str = ""
		if b_data.cost_ore > 0 or b_data.cost_materials > 0:
			cost_str = "⛏%d 🏗%d" % [b_data.cost_ore, b_data.cost_materials]
		else:
			cost_str = "(Старт)"
		
		var energy_badge = ""
		if b_data.energy_production > 0:
			energy_badge = " | ⚡+%d" % b_data.energy_production
		elif b_data.energy_consumption > 0:
			energy_badge = " | ⚡-%d" % b_data.energy_consumption

		card_btn.text = "%s\n%s%s" % [b_data.display_name, cost_str, energy_badge]
		card_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		
		# Detailed Tooltip
		var tip = "%s\nРазмер: %d×%d | Стоимость: Руда %d, Материалы %d" % [
			b_data.description,
			b_data.tile_size.x, b_data.tile_size.y,
			b_data.cost_ore, b_data.cost_materials
		]
		if b_data.energy_production > 0:
			tip += "\nЭнергия: +%d МВт" % b_data.energy_production
		if b_data.energy_consumption > 0:
			tip += "\nПотребление: -%d МВт" % b_data.energy_consumption
		if b_data.attack_damage > 0:
			tip += "\nУрон: %.0f | Скорострельность: %.1f/с" % [b_data.attack_damage, b_data.attack_rate]
		if b_data.attack_range > 0:
			tip += "\nДальность огня: %.0f тайлов" % b_data.attack_range
		if b_data.shield_radius > 0:
			tip += "\nРадиус силового поля: %.0f тайлов" % b_data.shield_radius
		if b_data.repair_rate > 0:
			tip += "\nАвторемонт: %.0f HP/с (радиус %.0f)" % [b_data.repair_rate, b_data.repair_range]
		if b_data.ammo_production > 0:
			tip += "\nПроизводство патронов: +%d/с" % b_data.ammo_production
		if b_data.unlocks_layer_above:
			tip += "\nОткрывает строительство яруса ВЫШЕ"
		if b_data.unlocks_layer_below:
			tip += "\nОткрывает проход в ГЕОФРОНТ НИЖЕ (требует энергию)"
		if b_data.allowed_layers == "above_only":
			tip += "\nТолько верхние ярусы (z >= +1): защищает нижние уровни от атак"
		card_btn.tooltip_text = tip
		
		BrutalistTheme.apply_button_styles(card_btn)
		
		var captured_data = b_data
		card_btn.pressed.connect(func(): _on_building_button_pressed(captured_data))
		
		shelf_cards_container.add_child(card_btn)
		_building_buttons[b_data] = card_btn

func _on_category_button_pressed(cat_id: String) -> void:
	if _active_category == cat_id and shelf_panel.visible:
		_close_shelf()
		return
		
	_active_category = cat_id
	_active_sub_tab = "all"
	_open_shelf_for_category(cat_id)
	_update_category_highlights()

func _open_shelf_for_category(cat_id: String) -> void:
	if not CATEGORY_DEFS.has(cat_id):
		return
		
	var cat_data = CATEGORY_DEFS[cat_id]
	shelf_title_label.text = "%s %s" % [cat_data["icon"], cat_data["title"]]
	shelf_panel.visible = true
	
	# Rebuild sub-tabs
	for child in shelf_tabs_container.get_children():
		shelf_tabs_container.remove_child(child)
		child.queue_free()
	_sub_tab_buttons.clear()
	
	var tabs_def = cat_data["tabs"]
	for tab_id in tabs_def.keys():
		var t_info = tabs_def[tab_id]
		var btn = Button.new()
		btn.name = "Tab_" + tab_id
		btn.text = "%s (%d)" % [t_info["label"], t_info["buildings"].size()]
		btn.custom_minimum_size = Vector2(0, 24) if _is_compact else Vector2(80, 26)
		BrutalistTheme.apply_button_styles(btn)
		btn.add_theme_font_size_override("font_size", 10 if _is_compact else 12)
		if _is_compact:
			for st in ["normal", "hover", "pressed", "disabled"]:
				var sb = btn.get_theme_stylebox(st) as StyleBoxFlat
				if sb:
					var dup = sb.duplicate() as StyleBoxFlat
					dup.content_margin_left = 4
					dup.content_margin_right = 4
					btn.add_theme_stylebox_override(st, dup)
		
		var captured_tab = tab_id
		btn.pressed.connect(func(): _on_sub_tab_pressed(captured_tab))
		shelf_tabs_container.add_child(btn)
		_sub_tab_buttons[tab_id] = btn
		
	_filter_cards()
	_update_sub_tab_highlights()
	_sync_panel_bounds()
	shelf_visibility_changed.emit(true)

func _on_sub_tab_pressed(tab_id: String) -> void:
	_active_sub_tab = tab_id
	_filter_cards()
	_update_sub_tab_highlights()
	_sync_panel_bounds()
	shelf_visibility_changed.emit(true)

func _filter_cards() -> void:
	if not CATEGORY_DEFS.has(_active_category):
		return
		
	var cat_data = CATEGORY_DEFS[_active_category]
	var active_tab_info = cat_data["tabs"].get(_active_sub_tab, cat_data["tabs"]["all"])
	var visible_ids: Array = active_tab_info["buildings"]
	
	for b_data in _building_resources:
		var btn: Button = _building_buttons.get(b_data)
		if btn:
			var b_id_str = str(b_data.id)
			btn.visible = visible_ids.has(b_id_str)

func _close_shelf() -> void:
	var was_visible = shelf_panel.visible if is_instance_valid(shelf_panel) else false
	if is_instance_valid(shelf_panel):
		shelf_panel.visible = false
	_active_category = ""
	_update_category_highlights()
	_sync_panel_bounds()
	if was_visible:
		shelf_visibility_changed.emit(false)

func set_compact_mode(compact: bool) -> void:
	_is_compact = compact
	if is_instance_valid(dock_buttons_container):
		dock_buttons_container.add_theme_constant_override("separation", 6 if compact else 10)
	for cat_id in _category_buttons.keys():
		var btn: Button = _category_buttons[cat_id]
		if is_instance_valid(btn):
			btn.custom_minimum_size = Vector2(92, 36) if compact else Vector2(142, 40)
			btn.add_theme_font_size_override("font_size", 10 if compact else 13)
	if is_instance_valid(_demolish_button):
		_demolish_button.custom_minimum_size = Vector2(74, 36) if compact else Vector2(110, 40)
		_demolish_button.add_theme_font_size_override("font_size", 10 if compact else 13)
	if is_instance_valid(shelf_scroll):
		shelf_scroll.custom_minimum_size = Vector2(560, 128) if compact else Vector2(948, 128)
	if is_instance_valid(shelf_tabs_container):
		shelf_tabs_container.add_theme_constant_override("separation", 4 if compact else 6)
	for tab_id in _sub_tab_buttons.keys():
		var tbtn: Button = _sub_tab_buttons[tab_id]
		if is_instance_valid(tbtn):
			tbtn.custom_minimum_size = Vector2(0, 24) if compact else Vector2(80, 26)
			tbtn.add_theme_font_size_override("font_size", 10 if compact else 12)
	_sync_panel_bounds()

func _sync_panel_bounds() -> void:
	_apply_min_size_centered()
	call_deferred("_apply_min_size_centered")

func _apply_min_size_centered() -> void:
	if not is_inside_tree():
		return
	var min_sz = get_combined_minimum_size()
	var half_w = maxf(240.0, min_sz.x * 0.5)
	var h = maxf(44.0, min_sz.y)
	offset_left = -half_w
	offset_right = half_w
	offset_top = -16.0 - h
	offset_bottom = -16.0

func _on_building_button_pressed(data: BuildingData) -> void:
	_selected_building = data
	if data.is_connector and data.network_type in ["power_cable", "supply_cable"]:
		EventBus.cable_mode_entered.emit(data)
	else:
		EventBus.build_mode_entered.emit(data)
	_highlight_active_building_card(_building_buttons.get(data))

func _on_demolish_pressed() -> void:
	_close_shelf()
	_selected_building = null
	EventBus.demolish_mode_entered.emit()
	_highlight_active_building_card(null)
	if _demolish_button:
		_demolish_button.add_theme_stylebox_override("normal", BrutalistTheme.create_active_button_style())

func _highlight_active_building_card(active_btn: Button) -> void:
	for b in _building_buttons.values():
		if b == active_btn:
			b.add_theme_stylebox_override("normal", BrutalistTheme.create_active_button_style())
		else:
			b.remove_theme_stylebox_override("normal")

func _update_category_highlights() -> void:
	for cat_id in _category_buttons.keys():
		var btn: Button = _category_buttons[cat_id]
		if cat_id == _active_category and shelf_panel.visible:
			btn.add_theme_stylebox_override("normal", BrutalistTheme.create_active_button_style())
		else:
			btn.remove_theme_stylebox_override("normal")

func _update_sub_tab_highlights() -> void:
	for tab_id in _sub_tab_buttons.keys():
		var btn: Button = _sub_tab_buttons[tab_id]
		if tab_id == _active_sub_tab:
			btn.add_theme_stylebox_override("normal", BrutalistTheme.create_active_button_style())
		else:
			btn.remove_theme_stylebox_override("normal")

func _update_button_highlights() -> void:
	_selected_building = null
	_highlight_active_building_card(null)
	if _demolish_button:
		_demolish_button.remove_theme_stylebox_override("normal")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and shelf_panel.visible:
			_close_shelf()
			get_viewport().set_input_as_handled()

func _on_resources_updated(_res_name: String, _amount: int) -> void:
	_update_affordability()

func _on_buildings_updated(_b: Node2D) -> void:
	_update_affordability()

func _on_game_mode_changed(_mode_name: String) -> void:
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
			btn.modulate = Color(0.85, 0.72, 0.72, 0.75)

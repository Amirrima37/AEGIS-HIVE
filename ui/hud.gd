class_name GameHUD
extends CanvasLayer

const BrutalistTheme = preload("res://ui/brutalist_theme.gd")

@onready var topbar_hbox: HBoxContainer = $TopBar/MarginContainer/HBoxContainer
@onready var label_energy: Label = $TopBar/MarginContainer/HBoxContainer/ResEnergy
@onready var label_ore: Label = $TopBar/MarginContainer/HBoxContainer/ResOre
@onready var label_materials: Label = $TopBar/MarginContainer/HBoxContainer/ResMaterials
@onready var label_ammo: Label = $TopBar/MarginContainer/HBoxContainer/ResAmmo
@onready var label_population: Label = $TopBar/MarginContainer/HBoxContainer/ResPopulation
@onready var label_wave: Label = $TopBar/MarginContainer/HBoxContainer/WaveCountdown
@onready var directive_status_badge: Label = $TopBar/MarginContainer/HBoxContainer/DirectiveStatusBadge
@onready var btn_game_mode: Button = $TopBar/MarginContainer/HBoxContainer/BtnGameMode

@onready var overlay_toggle: OverlayToggle = $OverlayToggle
@onready var layer_indicator: LayerIndicator = $LayerIndicator
@onready var command_panel: CommandPanel = $CommandPanel
@onready var build_toolbar: BuildToolbar = $BuildToolbar
@onready var minimap_panel: MinimapPanel = $MinimapPanel
@onready var speed_control: SpeedControl = $SpeedControl

var _is_compact_viewport: bool = false

func _ready() -> void:
	if EventBus:
		EventBus.resource_changed.connect(_on_resource_changed)
		if EventBus.has_signal("game_mode_changed"):
			EventBus.game_mode_changed.connect(_on_game_mode_changed)
		if EventBus.has_signal("combat_power_shift_toggled"):
			EventBus.combat_power_shift_toggled.connect(func(_a): _update_directive_badge())
		if EventBus.has_signal("aegis_protocol_toggled"):
			EventBus.aegis_protocol_toggled.connect(func(_a): _update_directive_badge())
			
	if btn_game_mode:
		btn_game_mode.pressed.connect(_on_btn_game_mode_pressed)
		BrutalistTheme.apply_button_styles(btn_game_mode)
		
	# Apply styling to TopBar
	var topbar_panel = $TopBar as PanelContainer
	if topbar_panel:
		topbar_panel.add_theme_stylebox_override("panel", BrutalistTheme.create_panel_style(
			BrutalistTheme.BG_PANEL,
			BrutalistTheme.BORDER_DARK,
			3,
			6
		))
		
	if command_panel:
		command_panel.tab_expanded_changed.connect(_on_command_panel_expanded)
	if build_toolbar:
		build_toolbar.shelf_visibility_changed.connect(_on_build_shelf_visibility_changed)
	if get_viewport():
		get_viewport().size_changed.connect(_apply_responsive_layout)
		
	_update_mode_button()
	_update_directive_badge()
	_update_all_resources()
	_apply_responsive_layout()

func _apply_responsive_layout() -> void:
	if not is_inside_tree() or not get_viewport():
		return
	var sz = get_viewport().get_visible_rect().size
	var compact = (sz.x < 1900.0 or sz.y < 960.0)
	var constrain_y = (sz.y < 960.0)
	_is_compact_viewport = compact
	
	if is_instance_valid(topbar_hbox):
		topbar_hbox.add_theme_constant_override("separation", 8 if compact else 16)
	for lbl in [label_energy, label_ore, label_materials, label_ammo, label_population, label_wave, directive_status_badge]:
		if is_instance_valid(lbl):
			lbl.add_theme_font_size_override("font_size", 11 if compact else 13)
	if is_instance_valid(btn_game_mode):
		btn_game_mode.add_theme_font_size_override("font_size", 11 if compact else 13)
	
	if is_instance_valid(overlay_toggle):
		overlay_toggle.offset_top = 54.0
		overlay_toggle.offset_bottom = 200.0 if compact else 250.0
		overlay_toggle.offset_left = -182.0 if compact else -204.0
		overlay_toggle.offset_right = -16.0
		if overlay_toggle.has_method("set_compact_mode"):
			overlay_toggle.set_compact_mode(compact)

	if is_instance_valid(layer_indicator):
		if compact or constrain_y:
			layer_indicator.offset_left = -202.0
			layer_indicator.offset_right = -16.0
			layer_indicator.offset_top = -115.0
			layer_indicator.offset_bottom = 115.0
		else:
			layer_indicator.offset_left = -224.0
			layer_indicator.offset_right = -16.0
			layer_indicator.offset_top = -145.0
			layer_indicator.offset_bottom = 145.0
		if layer_indicator.has_method("set_compact_mode"):
			layer_indicator.set_compact_mode(compact or constrain_y)
		var li_min = layer_indicator.get_combined_minimum_size()
		var li_h = maxf(230.0 if (compact or constrain_y) else 290.0, li_min.y)
		if constrain_y:
			li_h = minf(li_h, 230.0)
		layer_indicator.offset_top = -li_h * 0.5
		layer_indicator.offset_bottom = li_h * 0.5
		layer_indicator.offset_left = -maxf(196.0 if compact else 212.0, li_min.x) - 16.0
		layer_indicator.offset_right = -16.0
		layer_indicator.size = Vector2(maxf(196.0 if compact else 212.0, li_min.x), li_h)
			
	if is_instance_valid(minimap_panel):
		if compact or constrain_y:
			minimap_panel.offset_left = -256.0
			minimap_panel.offset_top = -196.0
			minimap_panel.offset_right = -16.0
			minimap_panel.offset_bottom = -16.0
		else:
			minimap_panel.offset_left = -460.0
			minimap_panel.offset_top = -320.0
			minimap_panel.offset_right = -16.0
			minimap_panel.offset_bottom = -16.0
		if minimap_panel.has_method("set_compact_mode"):
			minimap_panel.set_compact_mode(compact or constrain_y)
			
	if is_instance_valid(speed_control):
		speed_control.offset_left = 16.0
		speed_control.offset_right = 276.0 if compact else 356.0
		if speed_control.has_method("set_compact_mode"):
			speed_control.set_compact_mode(compact)
			
	if is_instance_valid(command_panel):
		command_panel.offset_left = 16.0
		command_panel.offset_right = 328.0 if compact else 372.0
		if command_panel.has_method("set_compact_mode"):
			command_panel.set_compact_mode(compact)
		if compact and command_panel.is_expanded() and build_toolbar and build_toolbar.shelf_panel and build_toolbar.shelf_panel.visible:
			command_panel.set_expanded(false)
			
	if is_instance_valid(build_toolbar) and build_toolbar.has_method("set_compact_mode"):
		build_toolbar.set_compact_mode(compact)
	_update_directive_badge()

func _on_command_panel_expanded(expanded: bool) -> void:
	if expanded and _is_compact_viewport and is_instance_valid(build_toolbar):
		build_toolbar._close_shelf()

func _on_build_shelf_visibility_changed(is_open: bool) -> void:
	if is_open and _is_compact_viewport and is_instance_valid(command_panel):
		command_panel.set_expanded(false)

func _update_directive_badge() -> void:
	if not is_instance_valid(directive_status_badge):
		return
	if GameState and GameState.aegis_protocol_active:
		directive_status_badge.visible = true
		directive_status_badge.text = "🛡 ЭГИДА" if _is_compact_viewport else "🛡 ЭГИДА АКТИВНА"
		directive_status_badge.add_theme_color_override("font_color", Color(0.35, 0.90, 1.0))
	elif GameState and GameState.combat_power_shift_active:
		directive_status_badge.visible = true
		directive_status_badge.text = "⚡ ПЕРЕБРОС" if _is_compact_viewport else "⚡ ЭНЕРГОПЕРЕБРОС"
		directive_status_badge.add_theme_color_override("font_color", BrutalistTheme.TEXT_AMBER)
	else:
		directive_status_badge.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code == KEY_F3:
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
		btn_game_mode.add_theme_color_override("font_color", BrutalistTheme.TEXT_AMBER)
	else:
		btn_game_mode.text = "🛠 Режим: Стандарт [F3]"
		btn_game_mode.add_theme_color_override("font_color", BrutalistTheme.TEXT_MUTED)

func _update_all_resources() -> void:
	var is_unl = GameState and GameState.has_method("is_unlimited_mode") and GameState.is_unlimited_mode()
	if label_energy:
		label_energy.text = "⚡ %s" % ("∞" if is_unl else ("%d МВт" % ResourceManager.get_resource("energy")))
	if label_ore:
		label_ore.text = "⛏ %s" % ("∞" if is_unl else ("%d т" % ResourceManager.get_resource("ore")))
	if label_materials:
		label_materials.text = "🏗 %s" % ("∞" if is_unl else ("%d т" % ResourceManager.get_resource("materials")))
	if label_ammo:
		var ammo_val = ResourceManager.get_resource("ammo")
		label_ammo.text = "🪖 Боеприпасы: %s" % ("∞" if is_unl else str(ammo_val))
	if label_population:
		var cur_pop = ResourceManager.get_resource("population")
		var cap_pop = ResourceManager.get_resource("population_capacity")
		if is_unl:
			label_population.text = "👥 %d / %d [∞]" % [cur_pop, cap_pop]
		else:
			label_population.text = "👥 %d / %d" % [cur_pop, cap_pop]
	if label_wave:
		# User requirement: wave counter placeholder always displays 00:00
		label_wave.text = "⚠️ ВОЛНА 00: 00:00 [УГРОЗА: НЕТ]"

func _on_resource_changed(_res_name: String, _new_amount: int) -> void:
	_update_all_resources()

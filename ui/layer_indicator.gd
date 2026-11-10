class_name LayerIndicator
extends PanelContainer

const BrutalistTheme = preload("res://ui/brutalist_theme.gd")

@onready var root_vbox: VBoxContainer = $MarginContainer/VBoxContainer
@onready var label_header: Label = $MarginContainer/VBoxContainer/LabelHeader
@onready var btn_add_above: Button = $MarginContainer/VBoxContainer/BtnAddAbove
@onready var btn_up: Button = $MarginContainer/VBoxContainer/BtnUp
@onready var label_layer_name: Label = $MarginContainer/VBoxContainer/LabelLayerName
@onready var layers_scroll: ScrollContainer = $MarginContainer/VBoxContainer/LayersScroll
@onready var layers_list: VBoxContainer = $MarginContainer/VBoxContainer/LayersScroll/LayersList
@onready var btn_down: Button = $MarginContainer/VBoxContainer/BtnDown
@onready var btn_add_below: Button = $MarginContainer/VBoxContainer/BtnAddBelow
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel

var _layer_buttons: Dictionary = {} # z -> Button
var _status_timer: float = 0.0
var _is_compact: bool = false
var _last_compromised_set: Array[int] = []

func _ready() -> void:
	add_theme_stylebox_override("panel", BrutalistTheme.create_panel_style(
		BrutalistTheme.BG_PANEL,
		BrutalistTheme.BORDER_DARK,
		4,
		6
	))
	
	if btn_add_above:
		BrutalistTheme.apply_button_styles(btn_add_above)
		btn_add_above.tooltip_text = "Создать строительный ярус выше [Shift+Q]\nТребует Опорную колонну на верхнем ярусе (в режиме Стандарт)"
		btn_add_above.pressed.connect(_on_add_above_pressed)
	if btn_up:
		BrutalistTheme.apply_button_styles(btn_up)
		btn_up.tooltip_text = "Переключиться на ярус выше [Q]"
		btn_up.pressed.connect(func(): EventBus.layer_change_requested.emit(1))
	if btn_down:
		BrutalistTheme.apply_button_styles(btn_down)
		btn_down.tooltip_text = "Переключиться на ярус ниже [E]"
		btn_down.pressed.connect(func(): EventBus.layer_change_requested.emit(-1))
	if btn_add_below:
		BrutalistTheme.apply_button_styles(btn_add_below)
		btn_add_below.tooltip_text = "Пробурить уровень Геофронта ниже [Shift+E]\nТребует запитанную Буровую установку на нижнем ярусе (в режиме Стандарт)"
		btn_add_below.pressed.connect(_on_add_below_pressed)
		
	if status_label:
		status_label.visible = false
		
	if EventBus:
		EventBus.active_layer_changed.connect(_on_active_layer_changed)
		EventBus.layer_created.connect(_on_layer_created_ui)
		EventBus.layer_removed.connect(_on_layer_removed_ui)
		if EventBus.has_signal("layer_creation_failed"):
			EventBus.layer_creation_failed.connect(_on_layer_creation_failed)
		if EventBus.has_signal("layer_integrity_compromised"):
			EventBus.layer_integrity_compromised.connect(_on_layer_integrity_compromised)
		if EventBus.has_signal("layer_cascade_damage"):
			EventBus.layer_cascade_damage.connect(_on_layer_cascade_damage)
		if EventBus.has_signal("building_placed"):
			EventBus.building_placed.connect(func(_b): _refresh_compromised_markers())
		if EventBus.has_signal("building_removed"):
			EventBus.building_removed.connect(func(_b): _refresh_compromised_markers())
		if EventBus.has_signal("game_mode_changed"):
			EventBus.game_mode_changed.connect(func(_m): _refresh_compromised_markers())
		
	_update_text(GameState.current_layer)
	_rebuild_layer_list()

func _process(delta: float) -> void:
	if _status_timer > 0.0:
		_status_timer -= delta
		if _status_timer <= 0.0 and status_label:
			status_label.visible = false

func _on_add_above_pressed() -> void:
	var lm = _get_layer_manager()
	var prev_count = lm.get_existing_z_levels().size() if (lm and lm.has_method("get_existing_z_levels")) else _layer_buttons.size()
	EventBus.request_create_layer_above.emit()
	# If created from UI button, jump to newly created top layer for immediate player feedback
	if lm and lm.has_method("get_existing_z_levels"):
		var keys: Array = lm.get_existing_z_levels()
		if keys.size() > prev_count and not keys.is_empty():
			var top_z = keys.max()
			EventBus.layer_jump_requested.emit(top_z)

func _on_add_below_pressed() -> void:
	var lm = _get_layer_manager()
	var prev_count = lm.get_existing_z_levels().size() if (lm and lm.has_method("get_existing_z_levels")) else _layer_buttons.size()
	EventBus.request_create_layer_below.emit()
	if lm and lm.has_method("get_existing_z_levels"):
		var keys: Array = lm.get_existing_z_levels()
		if keys.size() > prev_count and not keys.is_empty():
			var bot_z = keys.min()
			EventBus.layer_jump_requested.emit(bot_z)

func _on_active_layer_changed(z: int) -> void:
	_update_text(z)
	_highlight_active_in_list()

func _on_layer_created_ui(z: int) -> void:
	_rebuild_layer_list()
	if z != 0:
		var lbl = "ярус +%d" % z if z > 0 else "Геофронт %d" % z
		_show_status("Открыт %s" % lbl, Color(0.3, 0.9, 0.5, 1.0))

func _on_layer_removed_ui(_z: int) -> void:
	_rebuild_layer_list()
	if is_instance_valid(status_label):
		status_label.visible = false
	_status_timer = 0.0

func _on_layer_creation_failed(_target_z: int, reason: String) -> void:
	_show_status(reason, BrutalistTheme.TEXT_RED)

func _on_layer_integrity_compromised(z_level: int, _reason: String) -> void:
	_refresh_compromised_markers()
	_show_status("⚠ Ярус %s: нет опоры!" % (("+" + str(z_level)) if z_level > 0 else str(z_level)), BrutalistTheme.TEXT_RED)

func _on_layer_cascade_damage(z_level: int, total_dmg: int, affected: int) -> void:
	_refresh_compromised_markers()
	_show_status("💥 Деформация +%d: -%d HP (%d зд.)" % [z_level, total_dmg, affected], BrutalistTheme.TEXT_RED)

func set_compact_mode(compact: bool) -> void:
	_is_compact = compact
	if is_instance_valid(root_vbox):
		root_vbox.add_theme_constant_override("separation", 2 if compact else 4)
	var btn_h := 20 if compact else 26
	var btn_w := 172 if compact else 188
	for b in [btn_add_above, btn_up, btn_down, btn_add_below]:
		if is_instance_valid(b):
			b.custom_minimum_size = Vector2(btn_w, btn_h)
			b.add_theme_font_size_override("font_size", 10 if compact else 12)
	if is_instance_valid(label_layer_name):
		label_layer_name.custom_minimum_size = Vector2(btn_w, 26 if compact else 32)
		label_layer_name.add_theme_font_size_override("font_size", 11 if compact else 13)
	if is_instance_valid(layers_scroll):
		layers_scroll.custom_minimum_size = Vector2(btn_w, 46 if compact else 88)
	for btn in _layer_buttons.values():
		if is_instance_valid(btn):
			btn.custom_minimum_size = Vector2(160 if compact else 174, btn_h)
			btn.add_theme_font_size_override("font_size", 10 if compact else 12)

func _get_compromised_z_list() -> Array[int]:
	var lm = _get_layer_manager()
	if lm and lm.has_method("get_compromised_layers"):
		return lm.get_compromised_layers()
	return _last_compromised_set

func _refresh_compromised_markers() -> void:
	var lm = _get_layer_manager()
	if lm and lm.has_method("get_compromised_layers"):
		_last_compromised_set = lm.get_compromised_layers()
	_highlight_active_in_list()

func _show_status(msg: String, col: Color) -> void:
	if not is_instance_valid(status_label):
		return
	status_label.text = msg
	status_label.add_theme_color_override("font_color", col)
	status_label.visible = true
	_status_timer = 4.5

func _get_layer_manager() -> Node:
	if is_inside_tree():
		return get_tree().root.find_child("LayerManager", true, false)
	return null

func _rebuild_layer_list() -> void:
	if not is_instance_valid(layers_list):
		return
	for c in layers_list.get_children():
		layers_list.remove_child(c)
		c.queue_free()
	_layer_buttons.clear()
	
	var lm = _get_layer_manager()
	var z_list: Array = [0]
	if lm and lm.has_method("get_existing_z_levels"):
		z_list = lm.get_existing_z_levels()
	if z_list.is_empty():
		z_list = [0]
	
	z_list.sort_custom(func(a, b): return a > b)
	
	for z in z_list:
		var btn = Button.new()
		btn.name = "BtnLayer_%d" % z
		btn.custom_minimum_size = Vector2(160 if _is_compact else 174, 20 if _is_compact else 26)
		btn.add_theme_font_size_override("font_size", 10 if _is_compact else 12)
		btn.text = _format_layer_button_text(z, false)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		BrutalistTheme.apply_button_styles(btn)
		
		var target_z = z
		btn.pressed.connect(func(): EventBus.layer_jump_requested.emit(target_z))
		layers_list.add_child(btn)
		_layer_buttons[z] = btn
		
	_highlight_active_in_list()

func _format_layer_button_text(z: int, is_compromised: bool) -> String:
	var prefix := "⚠ " if is_compromised else ""
	if z == 0:
		return "%s🏗 ПОВЕРХН. [0]" % prefix
	elif z > 0:
		return "%s🔭 ПЛАТФ. [+%d]" % [prefix, z]
	else:
		return "%s⛏ ГЕОФР. [%d]" % [prefix, z]

func _highlight_active_in_list() -> void:
	var cur = GameState.current_layer
	var compromised_list = _get_compromised_z_list()
	for z in _layer_buttons.keys():
		var btn: Button = _layer_buttons[z]
		if not is_instance_valid(btn):
			continue
		var is_comp = compromised_list.has(z)
		btn.text = _format_layer_button_text(z, is_comp)
		if is_comp:
			var warn_sb = BrutalistTheme.create_panel_style(Color(0.24, 0.08, 0.10, 0.95), BrutalistTheme.TEXT_RED if z != cur else BrutalistTheme.BORDER_AMBER, 3, 4)
			btn.add_theme_stylebox_override("normal", warn_sb)
			btn.add_theme_color_override("font_color", BrutalistTheme.TEXT_RED if z != cur else BrutalistTheme.TEXT_AMBER)
		elif z == cur:
			BrutalistTheme.set_button_active(btn, true)
			btn.add_theme_color_override("font_color", BrutalistTheme.TEXT_AMBER)
		else:
			BrutalistTheme.set_button_active(btn, false)
			btn.add_theme_color_override("font_color", BrutalistTheme.TEXT_MUTED)

func _update_text(z: int) -> void:
	var title = ""
	if z == 0:
		title = "ПОВЕРХНОСТЬ\n[z=0]"
	elif z > 0:
		title = "ПЛАТФОРМА\n[z=+%d]" % z
	else:
		title = "ГЕОФРОНТ\n[z=%d]" % z
	
	if label_layer_name:
		label_layer_name.text = title

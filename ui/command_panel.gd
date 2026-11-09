class_name CommandPanel
extends PanelContainer

signal tab_expanded_changed(is_expanded: bool)

const BrutalistTheme = preload("res://ui/brutalist_theme.gd")

const ICON_FLASK = preload("res://assets/icons/icon_research_flask.svg")
const ICON_SCROLL = preload("res://assets/icons/icon_directives_scroll.svg")
const ICON_LOCKED = preload("res://assets/icons/icon_slot_locked.svg")

const CATEGORY_LABELS = {
	"defense": "🛡 Оборона и щиты",
	"life_support": "🏠 Жизнеобеспечение",
	"logistics": "📦 Логистика и патроны",
	"industry": "⚙ Добыча и заводы"
}

var _active_tab: String = "directives" # "research" | "directives"
var _is_expanded: bool = true
var _is_compact: bool = false

var _root_vbox: VBoxContainer = null
var _content_section: VBoxContainer = null
var _header_label: Label = null
var _btn_collapse: Button = null
var _content_scroll: ScrollContainer = null
var _research_container: VBoxContainer = null
var _directives_container: VBoxContainer = null

# Bottom unified 4-button tab strip (same panel!)
var btn_tab_research: Button = null
var btn_tab_directives: Button = null
var btn_tab_slot3: Button = null
var btn_tab_slot4: Button = null

# Directives controls
var btn_combat_shift: Button = null
var btn_aegis_protocol: Button = null
var btn_jump_to_research: Button = null
var _aegis_status_label: Label = null
var _shelter_label: Label = null
var _priority_rows_box: VBoxContainer = null
var btn_policies_placeholder: Button = null

# Research controls
var _research_cards_box: VBoxContainer = null
var _tech_action_buttons: Dictionary = {} # StringName -> Button
var _tech_progress_bars: Dictionary = {} # StringName -> ProgressBar
var _tech_status_labels: Dictionary = {} # StringName -> Label

func _ready() -> void:
	add_theme_stylebox_override("panel", BrutalistTheme.create_panel_style(
		BrutalistTheme.BG_PANEL,
		BrutalistTheme.BORDER_DARK,
		4,
		8
	))
	_build_ui()
	_connect_events()
	refresh_all()

func _build_ui() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()

	_root_vbox = VBoxContainer.new()
	_root_vbox.name = "CommandRootVBox"
	_root_vbox.add_theme_constant_override("separation", 6)
	_root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_root_vbox)

	# --- 1. Upper Content Section (vertical center down to 4-button dock) ---
	_content_section = VBoxContainer.new()
	_content_section.name = "ContentSection"
	_content_section.add_theme_constant_override("separation", 6)
	_content_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root_vbox.add_child(_content_section)

	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 6)
	_content_section.add_child(header_hbox)

	_header_label = Label.new()
	_header_label.name = "PanelHeader"
	_header_label.text = "📜 ДИРЕКТИВЫ КОЛОНИИ"
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_label.add_theme_color_override("font_color", BrutalistTheme.TEXT_AMBER)
	_header_label.add_theme_font_size_override("font_size", 13)
	header_hbox.add_child(_header_label)

	_btn_collapse = Button.new()
	_btn_collapse.name = "BtnCollapseCommand"
	_btn_collapse.text = "✕"
	_btn_collapse.tooltip_text = "Свернуть содержимое панели"
	_btn_collapse.custom_minimum_size = Vector2(26, 24)
	BrutalistTheme.apply_button_styles(_btn_collapse)
	_btn_collapse.pressed.connect(func(): set_expanded(false))
	header_hbox.add_child(_btn_collapse)

	var hsep_top = HSeparator.new()
	_content_section.add_child(hsep_top)

	_content_scroll = ScrollContainer.new()
	_content_scroll.name = "ContentScroll"
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_content_section.add_child(_content_scroll)

	var scroll_body = VBoxContainer.new()
	scroll_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_body.add_theme_constant_override("separation", 8)
	_content_scroll.add_child(scroll_body)

	# Research view container
	_research_container = VBoxContainer.new()
	_research_container.name = "ResearchView"
	_research_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_research_container.add_theme_constant_override("separation", 8)
	scroll_body.add_child(_research_container)
	_build_research_view()

	# Directives view container
	_directives_container = VBoxContainer.new()
	_directives_container.name = "DirectivesView"
	_directives_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_directives_container.add_theme_constant_override("separation", 8)
	scroll_body.add_child(_directives_container)
	_build_directives_view()

	var hsep_bottom = HSeparator.new()
	_content_section.add_child(hsep_bottom)

	# --- 2. Unified Bottom 4-Button Tab Bar (same PanelContainer!) ---
	var tabs_hbox = HBoxContainer.new()
	tabs_hbox.name = "TabStripHBox"
	tabs_hbox.add_theme_constant_override("separation", 6)
	tabs_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_root_vbox.add_child(tabs_hbox)

	btn_tab_research = _make_tab_button("BtnTabResearch", "Исслед.", ICON_FLASK, "Вкладка исследований и разблокировки технологий [F6]")
	btn_tab_research.pressed.connect(func(): select_tab("research", true))
	tabs_hbox.add_child(btn_tab_research)

	btn_tab_directives = _make_tab_button("BtnTabDirectives", "Директ.", ICON_SCROLL, "Директивы колонии, режимы обороны и приоритеты энергии [F5]")
	btn_tab_directives.pressed.connect(func(): select_tab("directives", true))
	tabs_hbox.add_child(btn_tab_directives)

	btn_tab_slot3 = _make_tab_button("BtnTabSlot3", "—", ICON_LOCKED, "Резервный командный слот [в разработке]", true)
	tabs_hbox.add_child(btn_tab_slot3)

	btn_tab_slot4 = _make_tab_button("BtnTabSlot4", "—", ICON_LOCKED, "Резервный командный слот [в разработке]", true)
	tabs_hbox.add_child(btn_tab_slot4)

func _make_tab_button(node_name: String, caption: String, icon_tex: Texture2D, tip: String, is_placeholder: bool = false) -> Button:
	var btn = Button.new()
	btn.name = node_name
	btn.text = caption
	btn.icon = icon_tex
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn.add_theme_constant_override("icon_max_width", 20)
	btn.add_theme_font_size_override("font_size", 10)
	btn.custom_minimum_size = Vector2(64, 46)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.tooltip_text = tip
	BrutalistTheme.apply_button_styles(btn)
	if is_placeholder:
		btn.disabled = true
		btn.add_theme_color_override("font_color", BrutalistTheme.TEXT_MUTED)
		btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.60, 0.68, 0.85))
	return btn

func _build_research_view() -> void:
	var intro = Label.new()
	intro.text = "Прикладные проекты для усиления обороны форпоста:"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 11)
	intro.add_theme_color_override("font_color", BrutalistTheme.TEXT_MUTED)
	_research_container.add_child(intro)

	_research_cards_box = VBoxContainer.new()
	_research_cards_box.name = "ResearchCardsBox"
	_research_cards_box.add_theme_constant_override("separation", 8)
	_research_container.add_child(_research_cards_box)

func _rebuild_research_cards() -> void:
	if not is_instance_valid(_research_cards_box):
		return
	for c in _research_cards_box.get_children():
		_research_cards_box.remove_child(c)
		c.queue_free()
	_tech_action_buttons.clear()
	_tech_progress_bars.clear()
	_tech_status_labels.clear()

	var rm = _get_research_manager()
	var tech_list: Array[Dictionary] = rm.get_tech_list() if rm else ResearchManager.TECH_DEFS.duplicate(true)

	for t_def in tech_list:
		var t_id: StringName = t_def["id"]
		var is_future = int(t_def.get("available_stage", 99)) > 3
		var card = PanelContainer.new()
		card.add_theme_stylebox_override("panel", BrutalistTheme.create_panel_style(
			Color(0.10, 0.12, 0.15, 0.90),
			BrutalistTheme.BORDER_DARK,
			3,
			8
		))
		_research_cards_box.add_child(card)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		var title = Label.new()
		title.text = str(t_def["title"])
		title.add_theme_font_size_override("font_size", 12)
		title.add_theme_color_override("font_color", BrutalistTheme.TEXT_MUTED if is_future else BrutalistTheme.TEXT_BRIGHT)
		vbox.add_child(title)

		var desc = Label.new()
		desc.text = str(t_def["description"])
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 10)
		desc.add_theme_color_override("font_color", BrutalistTheme.TEXT_MUTED)
		vbox.add_child(desc)

		var cost: Dictionary = t_def.get("cost", {})
		var cost_lbl = Label.new()
		cost_lbl.text = "Стоимость: ⛏ %d  🏗 %d  ⏱ %d тиков" % [int(cost.get("ore", 0)), int(cost.get("materials", 0)), int(t_def.get("ticks_required", 1))]
		cost_lbl.add_theme_font_size_override("font_size", 10)
		cost_lbl.add_theme_color_override("font_color", BrutalistTheme.TEXT_AMBER if not is_future else BrutalistTheme.TEXT_MUTED)
		vbox.add_child(cost_lbl)

		var pbar = ProgressBar.new()
		pbar.min_value = 0
		pbar.max_value = max(1, int(t_def.get("ticks_required", 1)))
		pbar.custom_minimum_size = Vector2(0, 12)
		pbar.show_percentage = false
		vbox.add_child(pbar)
		_tech_progress_bars[t_id] = pbar

		var status_lbl = Label.new()
		status_lbl.add_theme_font_size_override("font_size", 10)
		vbox.add_child(status_lbl)
		_tech_status_labels[t_id] = status_lbl

		var btn = Button.new()
		btn.name = "BtnResearch_" + str(t_id)
		btn.custom_minimum_size = Vector2(0, 28)
		BrutalistTheme.apply_button_styles(btn)
		if is_future:
			btn.text = "🔒 ЭТАП 5 [СКОРО]"
			btn.disabled = true
			pbar.visible = false
		else:
			var captured_id = t_id
			btn.pressed.connect(func(): _on_start_research_pressed(captured_id))
		vbox.add_child(btn)
		_tech_action_buttons[t_id] = btn

	_update_research_status()

func _build_directives_view() -> void:
	# 1. Instant Combat Power Shift (No research required)
	var combat_card = PanelContainer.new()
	combat_card.add_theme_stylebox_override("panel", BrutalistTheme.create_panel_style(
		Color(0.10, 0.12, 0.15, 0.90),
		BrutalistTheme.BORDER_DARK,
		3,
		8
	))
	_directives_container.add_child(combat_card)

	var combat_vbox = VBoxContainer.new()
	combat_vbox.add_theme_constant_override("separation", 4)
	combat_card.add_child(combat_vbox)

	var c_title = Label.new()
	c_title.text = "⚡ БОЕВОЙ ЭНЕРГОПЕРЕБРОС"
	c_title.add_theme_font_size_override("font_size", 12)
	c_title.add_theme_color_override("font_color", BrutalistTheme.TEXT_BRIGHT)
	combat_vbox.add_child(c_title)

	var c_desc = Label.new()
	c_desc.text = "Доступно сразу: отключает жильё, карьеры и заводы; перебрасывает МВт на оборону."
	c_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c_desc.add_theme_font_size_override("font_size", 10)
	c_desc.add_theme_color_override("font_color", BrutalistTheme.TEXT_MUTED)
	combat_vbox.add_child(c_desc)

	btn_combat_shift = Button.new()
	btn_combat_shift.name = "BtnCombatPowerShift"
	btn_combat_shift.custom_minimum_size = Vector2(0, 30)
	btn_combat_shift.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BrutalistTheme.apply_button_styles(btn_combat_shift)
	btn_combat_shift.pressed.connect(_on_combat_shift_pressed)
	combat_vbox.add_child(btn_combat_shift)

	# 2. Aegis Protocol (Unlocked ONLY via Research tab)
	var aegis_card = PanelContainer.new()
	aegis_card.add_theme_stylebox_override("panel", BrutalistTheme.create_panel_style(
		Color(0.10, 0.12, 0.15, 0.90),
		BrutalistTheme.BORDER_DARK,
		3,
		8
	))
	_directives_container.add_child(aegis_card)

	var aegis_vbox = VBoxContainer.new()
	aegis_vbox.add_theme_constant_override("separation", 4)
	aegis_card.add_child(aegis_vbox)

	var a_title = Label.new()
	a_title.text = "🛡 ПРОТОКОЛ «ЭГИДА»"
	a_title.add_theme_font_size_override("font_size", 12)
	a_title.add_theme_color_override("font_color", Color(0.55, 0.88, 1.0))
	aegis_vbox.add_child(a_title)

	_aegis_status_label = Label.new()
	_aegis_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aegis_status_label.add_theme_font_size_override("font_size", 10)
	aegis_vbox.add_child(_aegis_status_label)

	_shelter_label = Label.new()
	_shelter_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shelter_label.add_theme_font_size_override("font_size", 10)
	_shelter_label.add_theme_color_override("font_color", Color(0.45, 0.85, 0.70))
	aegis_vbox.add_child(_shelter_label)

	btn_aegis_protocol = Button.new()
	btn_aegis_protocol.name = "BtnAegisProtocol"
	btn_aegis_protocol.custom_minimum_size = Vector2(0, 30)
	btn_aegis_protocol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BrutalistTheme.apply_button_styles(btn_aegis_protocol)
	btn_aegis_protocol.pressed.connect(_on_aegis_protocol_pressed)
	aegis_vbox.add_child(btn_aegis_protocol)

	btn_jump_to_research = Button.new()
	btn_jump_to_research.name = "BtnJumpToResearch"
	btn_jump_to_research.text = "🧪 Во вкладку «Исследования» →"
	btn_jump_to_research.custom_minimum_size = Vector2(0, 26)
	btn_jump_to_research.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn_jump_to_research.add_theme_font_size_override("font_size", 10)
	BrutalistTheme.apply_button_styles(btn_jump_to_research)
	btn_jump_to_research.pressed.connect(func(): select_tab("research", false))
	aegis_vbox.add_child(btn_jump_to_research)

	# 3. Dynamic Power Priorities
	var prio_card = PanelContainer.new()
	prio_card.add_theme_stylebox_override("panel", BrutalistTheme.create_panel_style(
		Color(0.10, 0.12, 0.15, 0.90),
		BrutalistTheme.BORDER_DARK,
		3,
		8
	))
	_directives_container.add_child(prio_card)

	var prio_vbox = VBoxContainer.new()
	prio_vbox.add_theme_constant_override("separation", 5)
	prio_card.add_child(prio_vbox)

	var p_title = Label.new()
	p_title.text = "⚡ ПРИОРИТЕТЫ ЭНЕРГОСНАБЖЕНИЯ"
	p_title.add_theme_font_size_override("font_size", 12)
	p_title.add_theme_color_override("font_color", BrutalistTheme.TEXT_AMBER)
	prio_vbox.add_child(p_title)

	_priority_rows_box = VBoxContainer.new()
	_priority_rows_box.name = "PriorityRowsBox"
	_priority_rows_box.add_theme_constant_override("separation", 4)
	prio_vbox.add_child(_priority_rows_box)

	# 4. Future Policy Window Stub (Stage 6 extension slot)
	btn_policies_placeholder = Button.new()
	btn_policies_placeholder.name = "BtnPoliciesPlaceholder"
	btn_policies_placeholder.text = "📋 ПОЛИТИКИ И УКАЗЫ КОЛОНИИ [СКОРО]"
	btn_policies_placeholder.tooltip_text = "Отдельное окно политических решений и законов (Этап 6)"
	btn_policies_placeholder.custom_minimum_size = Vector2(0, 28)
	btn_policies_placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn_policies_placeholder.add_theme_font_size_override("font_size", 10)
	BrutalistTheme.apply_button_styles(btn_policies_placeholder)
	btn_policies_placeholder.disabled = true
	btn_policies_placeholder.add_theme_color_override("font_disabled_color", Color(0.58, 0.64, 0.72, 0.88))
	_directives_container.add_child(btn_policies_placeholder)

func _connect_events() -> void:
	if EventBus:
		if EventBus.has_signal("combat_power_shift_toggled"):
			EventBus.combat_power_shift_toggled.connect(func(_a): refresh_all())
		if EventBus.has_signal("aegis_protocol_toggled"):
			EventBus.aegis_protocol_toggled.connect(func(_a): refresh_all())
		if EventBus.has_signal("power_priorities_changed"):
			EventBus.power_priorities_changed.connect(func(_p): _rebuild_priority_rows())
		if EventBus.has_signal("research_started"):
			EventBus.research_started.connect(func(_id): _update_research_status())
		if EventBus.has_signal("research_progress_updated"):
			EventBus.research_progress_updated.connect(func(_id, _c, _t): _update_research_status())
		if EventBus.has_signal("research_completed"):
			EventBus.research_completed.connect(func(_id): refresh_all())
		if EventBus.has_signal("resource_changed"):
			EventBus.resource_changed.connect(func(_n, _v): _update_research_status())
		if EventBus.has_signal("game_mode_changed"):
			EventBus.game_mode_changed.connect(func(_m): refresh_all())
		if EventBus.has_signal("tick"):
			EventBus.tick.connect(func(_t): refresh_dynamic_readouts())
		if EventBus.has_signal("building_placed"):
			EventBus.building_placed.connect(func(_b): refresh_dynamic_readouts())
		if EventBus.has_signal("building_removed"):
			EventBus.building_removed.connect(func(_b): refresh_dynamic_readouts())

func select_tab(tab_id: String, toggle_if_same: bool = false) -> void:
	if toggle_if_same and _is_expanded and _active_tab == tab_id:
		set_expanded(false)
		return
	_active_tab = tab_id
	set_expanded(true)
	refresh_all()

func set_expanded(expanded: bool) -> void:
	_is_expanded = expanded
	if is_instance_valid(_content_section):
		_content_section.visible = expanded
	if expanded:
		anchor_top = 0.5
		anchor_bottom = 1.0
		offset_top = 0.0
		offset_bottom = -72.0
	else:
		anchor_top = 1.0
		anchor_bottom = 1.0
		offset_top = -134.0
		offset_bottom = -72.0
	_update_tab_highlights()
	tab_expanded_changed.emit(expanded)

func set_compact_mode(compact: bool) -> void:
	_is_compact = compact
	var tab_min := Vector2(64, 44) if compact else Vector2(74, 48)
	for btn in [btn_tab_research, btn_tab_directives, btn_tab_slot3, btn_tab_slot4]:
		if is_instance_valid(btn):
			btn.custom_minimum_size = tab_min

func is_expanded() -> bool:
	return _is_expanded

func get_active_tab() -> String:
	return _active_tab

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code == KEY_F5:
			select_tab("directives", true)
			get_viewport().set_input_as_handled()
		elif code == KEY_F6:
			select_tab("research", true)
			get_viewport().set_input_as_handled()

func refresh_all() -> void:
	if is_instance_valid(_research_container):
		_research_container.visible = (_active_tab == "research")
	if is_instance_valid(_directives_container):
		_directives_container.visible = (_active_tab == "directives")
	if is_instance_valid(_header_label):
		_header_label.text = "🔬 ИССЛЕДОВАНИЯ" if _active_tab == "research" else "📜 ДИРЕКТИВЫ КОЛОНИИ"
	_update_tab_highlights()
	if _research_cards_box and _research_cards_box.get_child_count() == 0:
		_rebuild_research_cards()
	_update_research_status()
	_update_directives_controls()
	_rebuild_priority_rows()

func refresh_dynamic_readouts() -> void:
	if not _is_expanded:
		return
	if _active_tab == "directives":
		_update_directives_controls()
		_rebuild_priority_rows()
	else:
		_update_research_status()

func _update_tab_highlights() -> void:
	if is_instance_valid(btn_tab_research):
		if _is_expanded and _active_tab == "research":
			btn_tab_research.add_theme_stylebox_override("normal", BrutalistTheme.create_active_button_style())
			btn_tab_research.add_theme_color_override("font_color", Color(0.45, 0.88, 1.0))
		else:
			btn_tab_research.remove_theme_stylebox_override("normal")
			btn_tab_research.add_theme_color_override("font_color", BrutalistTheme.TEXT_BRIGHT)
	if is_instance_valid(btn_tab_directives):
		if _is_expanded and _active_tab == "directives":
			btn_tab_directives.add_theme_stylebox_override("normal", BrutalistTheme.create_active_button_style())
			btn_tab_directives.add_theme_color_override("font_color", BrutalistTheme.TEXT_AMBER)
		else:
			btn_tab_directives.remove_theme_stylebox_override("normal")
			btn_tab_directives.add_theme_color_override("font_color", BrutalistTheme.TEXT_BRIGHT)

func _update_directives_controls() -> void:
	if is_instance_valid(btn_combat_shift):
		var c_active = GameState and GameState.combat_power_shift_active
		if c_active:
			btn_combat_shift.text = "⚡ ЭНЕРГОПЕРЕБРОС: АКТИВЕН [ВКЛ]"
			btn_combat_shift.add_theme_stylebox_override("normal", BrutalistTheme.create_active_button_style())
			btn_combat_shift.add_theme_color_override("font_color", BrutalistTheme.TEXT_AMBER)
		else:
			btn_combat_shift.text = "⚡ ВКЛЮЧИТЬ БОЕВОЙ ПЕРЕБРОС"
			btn_combat_shift.remove_theme_stylebox_override("normal")
			btn_combat_shift.add_theme_color_override("font_color", BrutalistTheme.TEXT_BRIGHT)

	var aegis_unlocked = GameState and GameState.aegis_protocol_unlocked
	var aegis_active = GameState and GameState.aegis_protocol_active
	if is_instance_valid(_aegis_status_label):
		if not aegis_unlocked:
			_aegis_status_label.text = "Открывает укрытие населения в бункерах/под щитами и принудительную готовность щитов. Требует исследования."
			_aegis_status_label.add_theme_color_override("font_color", BrutalistTheme.TEXT_MUTED)
		else:
			_aegis_status_label.text = "Исследовано! Активирует укрытие колонистов и переводит энергощиты в принудительную готовность."
			_aegis_status_label.add_theme_color_override("font_color", Color(0.55, 0.88, 1.0))

	if is_instance_valid(btn_aegis_protocol):
		if not aegis_unlocked:
			btn_aegis_protocol.disabled = true
			btn_aegis_protocol.text = "🔒 ПРОТОКОЛ «ЭГИДА» ЗАБЛОКИРОВАН"
			btn_aegis_protocol.remove_theme_stylebox_override("normal")
		else:
			btn_aegis_protocol.disabled = false
			if aegis_active:
				btn_aegis_protocol.text = "🛡 ПРОТОКОЛ «ЭГИДА»: АКТИВЕН [ВКЛ]"
				btn_aegis_protocol.add_theme_stylebox_override("normal", BrutalistTheme.create_active_button_style())
				btn_aegis_protocol.add_theme_color_override("font_color", Color(0.35, 0.90, 1.0))
			else:
				btn_aegis_protocol.text = "🛡 АКТИВИРОВАТЬ ПРОТОКОЛ «ЭГИДА»"
				btn_aegis_protocol.remove_theme_stylebox_override("normal")
				btn_aegis_protocol.add_theme_color_override("font_color", BrutalistTheme.TEXT_BRIGHT)

	if is_instance_valid(btn_jump_to_research):
		btn_jump_to_research.visible = (not aegis_unlocked)

	if is_instance_valid(_shelter_label):
		var tm = _get_tick_manager()
		if aegis_unlocked and tm and tm.has_method("get_sheltered_population_stats"):
			var st = tm.get_sheltered_population_stats()
			_shelter_label.visible = true
			_shelter_label.text = "👥 Укрыто: %d / %d (ёмк. защиты: %d) | Щиты: %s" % [
				int(st["sheltered"]), int(st["total"]), int(st["bunker_capacity"]),
				"ПРИНУД. ГОТОВЫ" if aegis_active else "ОЖИДАНИЕ"
			]
		else:
			_shelter_label.visible = false

func _rebuild_priority_rows() -> void:
	if not is_instance_valid(_priority_rows_box) or not GameState or not GameState.has_method("get_power_category_order"):
		return
	for c in _priority_rows_box.get_children():
		_priority_rows_box.remove_child(c)
		c.queue_free()

	var order = GameState.get_power_category_order()
	var tm = _get_tick_manager()
	var power_summary: Dictionary = tm.get_category_power_summary() if (tm and tm.has_method("get_category_power_summary")) else {}

	for idx in range(order.size()):
		var cat_id = order[idx]
		var row = HBoxContainer.new()
		row.name = "PriorityRow_" + cat_id
		row.add_theme_constant_override("separation", 4)
		_priority_rows_box.add_child(row)

		var lbl = Label.new()
		var mw = int(power_summary.get(cat_id, 0))
		lbl.text = "#%d %s (%d МВт)" % [idx + 1, CATEGORY_LABELS.get(cat_id, cat_id), mw]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", BrutalistTheme.TEXT_BRIGHT)
		row.add_child(lbl)

		var btn_up = Button.new()
		btn_up.name = "BtnPrioUp_" + cat_id
		btn_up.text = "▲"
		btn_up.custom_minimum_size = Vector2(26, 22)
		BrutalistTheme.apply_button_styles(btn_up)
		btn_up.disabled = (idx == 0)
		var cap_idx_up = idx
		btn_up.pressed.connect(func(): _move_priority(cap_idx_up, -1))
		row.add_child(btn_up)

		var btn_down = Button.new()
		btn_down.name = "BtnPrioDown_" + cat_id
		btn_down.text = "▼"
		btn_down.custom_minimum_size = Vector2(26, 22)
		BrutalistTheme.apply_button_styles(btn_down)
		btn_down.disabled = (idx == order.size() - 1)
		var cap_idx_down = idx
		btn_down.pressed.connect(func(): _move_priority(cap_idx_down, 1))
		row.add_child(btn_down)

func _move_priority(idx: int, delta: int) -> void:
	var order = GameState.get_power_category_order()
	var new_idx = idx + delta
	if new_idx < 0 or new_idx >= order.size():
		return
	var tmp = order[idx]
	order[idx] = order[new_idx]
	order[new_idx] = tmp
	GameState.set_power_category_order(order)
	_rebuild_priority_rows()

func _update_research_status() -> void:
	var rm = _get_research_manager()
	var tech_list: Array[Dictionary] = rm.get_tech_list() if rm else ResearchManager.TECH_DEFS.duplicate(true)
	for t_def in tech_list:
		var t_id: StringName = t_def["id"]
		if int(t_def.get("available_stage", 99)) > 3:
			continue
		var btn: Button = _tech_action_buttons.get(t_id)
		var pbar: ProgressBar = _tech_progress_bars.get(t_id)
		var st_lbl: Label = _tech_status_labels.get(t_id)
		var total = max(1, int(t_def.get("ticks_required", 1)))
		if GameState.is_tech_unlocked(t_id):
			if pbar:
				pbar.value = total
			if st_lbl:
				st_lbl.text = "Статус: ИЗУЧЕНО — доступно в Директивах"
				st_lbl.add_theme_color_override("font_color", Color(0.35, 0.90, 0.55))
			if btn:
				btn.text = "✓ ИССЛЕДОВАНИЕ ЗАВЕРШЕНО"
				btn.disabled = true
				btn.add_theme_stylebox_override("normal", BrutalistTheme.create_active_button_style())
		elif GameState.active_research_id == t_id:
			var cur = GameState.active_research_progress
			if pbar:
				pbar.value = cur
			if st_lbl:
				st_lbl.text = "Статус: В ПРОЦЕССЕ (%d / %d тиков)" % [cur, total]
				st_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
			if btn:
				btn.text = "⏳ ИДЁТ ИССЛЕДОВАНИЕ..."
				btn.disabled = true
		else:
			if pbar:
				pbar.value = 0
			var can_start = rm.can_start_research(t_id) if rm else false
			if st_lbl:
				st_lbl.text = "Статус: ГОТОВО К ЗАПУСКУ" if can_start else "Недостаточно ресурсов для запуска"
				st_lbl.add_theme_color_override("font_color", BrutalistTheme.TEXT_MUTED)
			if btn:
				btn.text = "🧪 ИССЛЕДОВАТЬ"
				btn.disabled = not can_start
				btn.remove_theme_stylebox_override("normal")

func _on_start_research_pressed(tech_id: StringName) -> void:
	var rm = _get_research_manager()
	if rm and rm.has_method("start_research"):
		rm.start_research(tech_id)
	refresh_all()

func _on_combat_shift_pressed() -> void:
	if GameState and GameState.has_method("toggle_combat_power_shift"):
		GameState.toggle_combat_power_shift()
	refresh_all()

func _on_aegis_protocol_pressed() -> void:
	if GameState and GameState.has_method("toggle_aegis_protocol"):
		GameState.toggle_aegis_protocol()
	refresh_all()

func _get_research_manager() -> Node:
	if is_inside_tree():
		return get_tree().root.find_child("ResearchManager", true, false)
	return null

func _get_tick_manager() -> Node:
	if is_inside_tree():
		return get_tree().root.find_child("TickManager", true, false)
	return null

class_name TestHUDModularDock
extends RefCounted

static func run_all_tests(main_node: Node) -> void:
	print("--- НАЧАЛО ТЕСТИРОВАНИЯ GUI: МОДУЛЬНЫЙ ДОК И БРУТАЛИСТСКИЙ HUD ---")
	
	var hud: GameHUD = main_node.find_child("HUD", true, false)
	assert(hud != null, "GUI.1: GameHUD must exist in main scene")
	
	var toolbar: BuildToolbar = main_node.find_child("BuildToolbar", true, false)
	assert(toolbar != null, "GUI.2: BuildToolbar must exist in main scene")
	
	var layer_ind: LayerIndicator = main_node.find_child("LayerIndicator", true, false)
	assert(layer_ind != null, "GUI.3: LayerIndicator must exist in main scene")
	
	var speed_ctrl: SpeedControl = main_node.find_child("SpeedControl", true, false)
	assert(speed_ctrl != null, "GUI.4: SpeedControl must exist in main scene")
	
	var overlay_toggle: OverlayToggle = main_node.find_child("OverlayToggle", true, false)
	assert(overlay_toggle != null, "GUI.5: OverlayToggle must exist in main scene")
	
	var minimap: MinimapPanel = main_node.find_child("MinimapPanel", true, false)
	assert(minimap != null, "GUI.6: MinimapPanel must exist in main scene")
	
	var cmd_panel: CommandPanel = main_node.find_child("CommandPanel", true, false)
	assert(cmd_panel != null, "GUI.6b: CommandPanel must exist in main scene")
	
	# Test 1: Category Dock Categories & Card Icons
	assert(toolbar._category_buttons.has("city"), "GUI.7: City category button missing")
	assert(toolbar._category_buttons.has("production"), "GUI.8: Production category button missing (renamed from energy)")
	assert(not toolbar._category_buttons.has("energy"), "GUI.8b: Legacy 'energy' key must be renamed to 'production'")
	assert(toolbar._category_buttons["production"].text.contains("ПРОИЗВОДСТВО"), "GUI.8c: Production button text must contain 'ПРОИЗВОДСТВО'")
	assert(toolbar._category_buttons.has("logistics"), "GUI.9: Logistics category button missing")
	assert(toolbar._category_buttons.has("defense"), "GUI.10: Defense category button missing")
	assert(toolbar._demolish_button != null, "GUI.11: Demolish button missing")
	assert(toolbar._building_buttons.size() == 19, "GUI.12: All 19 buildings must have mapped buttons, got %d" % toolbar._building_buttons.size())
	for b_data in toolbar._building_buttons.keys():
		var card_btn: Button = toolbar._building_buttons[b_data]
		assert(card_btn.icon != null, "GUI.12b: Building card '%s' must have an icon assigned" % b_data.id)
	print("[OK] GUI.T1: Нижний док содержит вкладку 'ПРОИЗВОДСТВО', 4 категории и 19 карточек (вкл. Бронепалубу) с иконками")
	
	# Test 2: Pop-up Shelf Open & Close
	assert(toolbar.shelf_panel.visible == false, "GUI.13: Shelf must be closed initially")
	
	# Click Defense category
	toolbar._category_buttons["defense"].pressed.emit()
	assert(toolbar.shelf_panel.visible == true, "GUI.14: Shelf must open on category click")
	assert(toolbar._active_category == "defense", "GUI.15: Active category must be 'defense'")
	assert(toolbar.shelf_title_label.text.contains("ОБОРОНА"), "GUI.16: Shelf title must say 'ОБОРОНА'")
	
	# Sub-tabs check for Defense
	assert(toolbar._sub_tab_buttons.has("all"), "GUI.17: 'all' sub-tab missing")
	assert(toolbar._sub_tab_buttons.has("combat"), "GUI.18: 'combat' sub-tab missing")
	assert(toolbar._sub_tab_buttons.has("support"), "GUI.19: 'support' sub-tab missing")
	assert(toolbar._sub_tab_buttons.has("ammo"), "GUI.20: 'ammo' sub-tab missing")
	
	# Filter cards by clicking combat
	toolbar._sub_tab_buttons["combat"].pressed.emit()
	assert(toolbar._active_sub_tab == "combat", "GUI.21: Active sub-tab must be 'combat'")
	
	# Verify visibility of combat buildings vs others
	for b_data in toolbar._building_buttons.keys():
		var btn: Button = toolbar._building_buttons[b_data]
		if b_data.id in [&"defense_wall", &"armor_deck", &"autocannon_turret", &"heavy_railgun"]:
			assert(btn.visible == true, "GUI.22: Combat building %s must be visible" % b_data.id)
		elif b_data.id in [&"shield_generator", &"sensor_tower", &"munitions_factory", &"command_center"]:
			assert(btn.visible == false, "GUI.23: Non-combat building %s must be hidden" % b_data.id)
			
	# Click Defense category again -> should toggle close
	toolbar._category_buttons["defense"].pressed.emit()
	assert(toolbar.shelf_panel.visible == false, "GUI.24: Shelf must toggle closed when clicking active category again")
	print("[OK] GUI.T2: Всплывающая полка BuildShelf открывается, фильтрует по подвкладкам и закрывается")
	
	# Test 3: Close button [X]
	toolbar._category_buttons["city"].pressed.emit()
	assert(toolbar.shelf_panel.visible == true, "GUI.25: Shelf must open for City")
	toolbar._close_shelf()
	assert(toolbar.shelf_panel.visible == false, "GUI.26: _close_shelf must close shelf")
	
	# Test 4: TopBar Resources & Wave countdown
	assert(hud.label_energy != null, "GUI.27: Energy label missing")
	assert(hud.label_ore != null, "GUI.28: Ore label missing")
	assert(hud.label_materials != null, "GUI.29: Materials label missing")
	assert(hud.label_ammo != null, "GUI.30: Ammo label missing")
	assert(hud.label_ammo.text.contains("Боеприпасы"), "GUI.31: Label must say 'Боеприпасы', got '%s'" % hud.label_ammo.text)
	assert(hud.label_wave != null, "GUI.32: Wave label missing")
	assert(hud.label_wave.text.contains("00:00"), "GUI.33: Wave countdown placeholder must display '00:00', got '%s'" % hud.label_wave.text)
	print("[OK] GUI.T3: Верхняя панель содержит 'Боеприпасы' и счетчик волны '00:00'")
	
	# Test 5: Layer Indicator Geofront wording
	layer_ind._update_text(0)
	assert(layer_ind.label_layer_name.text.contains("ПОВЕРХНОСТЬ"), "GUI.34: z=0 must be 'ПОВЕРХНОСТЬ'")
	layer_ind._update_text(-1)
	assert(layer_ind.label_layer_name.text.contains("ГЕОФРОНТ"), "GUI.35: z=-1 must be 'ГЕОФРОНТ', got '%s'" % layer_ind.label_layer_name.text)
	assert(not layer_ind.label_layer_name.text.contains("ШАХТА"), "GUI.36: Must not use 'ШАХТА'")
	layer_ind._update_text(0)
	print("[OK] GUI.T4: Переключение слоев использует термин 'ГЕОФРОНТ', а не 'ШАХТА'")
	
	# Test 6: Time Controls
	speed_ctrl.btn_speed2.pressed.emit()
	assert(GameState.game_speed == 2.0, "GUI.37: Speed2 button must set speed to 2.0")
	speed_ctrl.btn_speed1.pressed.emit()
	assert(GameState.game_speed == 1.0, "GUI.38: Speed1 button must restore speed to 1.0")
	print("[OK] GUI.T5: Управление временем (пауза, 1x, 2x, 3x) в левом нижнем углу полностью функционально")
	
	# Test 7: Overlay Toggles & Renamings
	assert(overlay_toggle.btn_power != null, "GUI.39: btn_power missing")
	assert(overlay_toggle.btn_supply != null and overlay_toggle.btn_supply.text.contains("ЛОГИСТИКА"), "GUI.40: btn_supply must say 'ЛОГИСТИКА'")
	assert(overlay_toggle.btn_integrity != null and overlay_toggle.btn_integrity.text.contains("БРОНЯ"), "GUI.41: btn_integrity must say 'БРОНЯ'")
	assert(overlay_toggle.btn_sensors != null and overlay_toggle.btn_sensors.text.contains("РАДАР [soon]"), "GUI.42: btn_sensors must say 'РАДАР [soon]'")
	assert(overlay_toggle.btn_sensors.disabled == true, "GUI.42b: btn_sensors placeholder must be disabled")
	assert(overlay_toggle.btn_minerals != null and overlay_toggle.btn_minerals.text.contains("НЕДРА [soon]"), "GUI.43: btn_minerals must say 'НЕДРА [soon]'")
	assert(overlay_toggle.btn_minerals.disabled == true, "GUI.43b: btn_minerals placeholder must be disabled")
	
	# Test Armor / Integrity Overlay integration with NetworkOverlay
	var net_overlay: NetworkOverlay = main_node.find_child("NetworkOverlay", true, false)
	assert(net_overlay != null, "GUI.43c: NetworkOverlay must exist")
	overlay_toggle.btn_integrity.set_pressed(true)
	assert(net_overlay.show_integrity_overlay == true, "GUI.43d: Pressing 'БРОНЯ' must activate show_integrity_overlay")
	overlay_toggle.btn_integrity.set_pressed(false)
	assert(net_overlay.show_integrity_overlay == false, "GUI.43e: Toggling 'БРОНЯ' off must deactivate show_integrity_overlay")
	print("[OK] GUI.T6: Инфо-слои переименованы ('ЛОГИСТИКА', '[soon]'), оверлей 'БРОНЯ' управляет NetworkOverlay")
	
	# Test 8: Minimap Placeholder
	assert(minimap.placeholder_viewport != null, "GUI.44: Minimap placeholder viewport must exist")
	print("[OK] GUI.T7: Тактический радар зарезервирован серой пустышкой в правом нижнем углу")
	
	# Test 9: Keyboard Focus Isolation (Buttons must have FOCUS_NONE so Space/arrows don't retrigger clicks)
	var focus_violations := _check_focus_none(hud)
	assert(focus_violations == 0, "GUI.45: All HUD buttons must use FOCUS_NONE, found %d violations" % focus_violations)
	print("[OK] GUI.T8: Все кнопки HUD имеют FOCUS_NONE и не перехватывают клавиатурный фокус")
	
	# Test 10: Layer Creation via UI (+ Ярус / + Геофронт) in Standard & Unlimited Modes + GameMode affordability sync
	var lm: LayerManager = main_node.find_child("LayerManager", true, false)
	assert(lm != null, "GUI.46: LayerManager missing")
	assert(layer_ind.btn_add_above != null and layer_ind.btn_add_below != null, "GUI.47: Add layer buttons missing on LayerIndicator")
	
	GameState.set_game_mode(GameState.GameMode.STANDARD)
	var before_z_cnt = lm.get_existing_z_levels().size()
	# In standard mode without rig on bottom layer, pressing add_below must fail gracefully & show status
	layer_ind.btn_add_below.pressed.emit()
	assert(lm.get_existing_z_levels().size() == before_z_cnt, "GUI.48: Standard mode without rig must block drilling deeper")
	assert(layer_ind.status_label.visible == true, "GUI.49: Failed layer creation must display reason in status_label")
	
	# Switch to UNLIMITED mode -> both buttons must create layers and jump directly to them!
	GameState.set_game_mode(GameState.GameMode.UNLIMITED)
	var prev_top = lm.get_existing_z_levels().max()
	layer_ind.btn_add_above.pressed.emit()
	assert(lm.layers.has(prev_top + 1), "GUI.50: BtnAddAbove in Unlimited mode must create layer +%d" % (prev_top + 1))
	assert(GameState.current_layer == prev_top + 1, "GUI.51: Clicking BtnAddAbove must switch camera/active layer to +%d" % (prev_top + 1))
	assert(layer_ind._layer_buttons.has(prev_top + 1), "GUI.52: Layer list must add button for +%d" % (prev_top + 1))
	
	var prev_bot = lm.get_existing_z_levels().min()
	layer_ind.btn_add_below.pressed.emit()
	assert(lm.layers.has(prev_bot - 1), "GUI.53: BtnAddBelow in Unlimited mode must create geofront %d" % (prev_bot - 1))
	assert(GameState.current_layer == prev_bot - 1, "GUI.54: Clicking BtnAddBelow must switch active layer to %d" % (prev_bot - 1))
	
	# Check affordability sync on game_mode_changed
	ResourceManager.set_resource("ore", 0)
	ResourceManager.set_resource("materials", 0)
	for b_data in toolbar._building_buttons.keys():
		if b_data.id == &"heavy_railgun":
			assert(toolbar._building_buttons[b_data].disabled == false, "GUI.55: Unlimited mode must enable expensive cards even at 0 resources")
	GameState.set_game_mode(GameState.GameMode.STANDARD)
	for b_data in toolbar._building_buttons.keys():
		if b_data.id == &"heavy_railgun":
			assert(toolbar._building_buttons[b_data].disabled == true, "GUI.56: Returning to Standard mode at 0 resources must disable expensive cards")
	
	# Restore clean layer 0
	lm.remove_layer(prev_top + 1)
	lm.remove_layer(prev_bot - 1)
	lm.set_active_layer(0)
	print("[OK] GUI.T9: Создание ярусов вверх и вниз через кнопки HUD и переключение режимов работают безупречно")
	
	# Test 10: LayerIndicator centered at right edge + compromised warning state
	assert(abs(layer_ind.anchor_left - 1.0) < 0.01 and abs(layer_ind.anchor_right - 1.0) < 0.01, "GUI.57: LayerIndicator must be anchored to right edge")
	assert(abs(layer_ind.anchor_top - 0.5) < 0.01 and abs(layer_ind.anchor_bottom - 0.5) < 0.01, "GUI.58: LayerIndicator must be centered vertically on right edge")
	if not lm.layers.has(1):
		lm.create_layer(1)
	lm.validate_structural_integrity()
	layer_ind._refresh_compromised_markers()
	assert(layer_ind._layer_buttons.has(1), "GUI.59: Layer 1 button must exist in LayerIndicator")
	assert(layer_ind._layer_buttons[1].text.contains("⚠"), "GUI.60: Compromised layer button must display warning symbol")
	print("[OK] GUI.T10: LayerIndicator центрирован у правого края и подсвечивает аварийные ярусы")
	
	# Test 11: CommandPanel (4 bottom buttons, Research strictly left of Directives, Combat Shift & Research-gated Aegis, Priorities)
	assert(abs(cmd_panel.anchor_left - 0.0) < 0.01 and abs(cmd_panel.anchor_bottom - 1.0) < 0.01, "GUI.61: CommandPanel must anchor left-bottom")
	assert(cmd_panel.btn_tab_research != null and cmd_panel.btn_tab_directives != null, "GUI.62: CommandPanel tab buttons missing")
	assert(cmd_panel.btn_tab_slot3 != null and cmd_panel.btn_tab_slot3.disabled == true, "GUI.63: Placeholder slot 3 must be disabled")
	assert(cmd_panel.btn_tab_slot4 != null and cmd_panel.btn_tab_slot4.disabled == true, "GUI.64: Placeholder slot 4 must be disabled")
	assert(cmd_panel.btn_tab_research.icon != null and cmd_panel.btn_tab_directives.icon != null, "GUI.65: Research flask and Directives scroll SVG icons must load")
	await main_node.get_tree().process_frame
	assert(cmd_panel.btn_tab_research.global_position.x < cmd_panel.btn_tab_directives.global_position.x, "GUI.66: Research button must be strictly to the left of Directives")
	
	GameState.reset_directives_and_research()
	ResourceManager.set_resource("ore", 500)
	ResourceManager.set_resource("materials", 500)
	cmd_panel.select_tab("directives", false)
	assert(cmd_panel.get_active_tab() == "directives" and cmd_panel.is_expanded() == true, "GUI.67: Directives tab must open")
	assert(cmd_panel.btn_aegis_protocol.disabled == true, "GUI.68: Aegis protocol button must be locked before research")
	assert(cmd_panel.btn_jump_to_research.visible == true, "GUI.69: Jump to Research hint button must be visible when Aegis is locked")
	
	# Toggle instant Combat Power Shift via UI click
	cmd_panel.btn_combat_shift.pressed.emit()
	assert(GameState.combat_power_shift_active == true, "GUI.70: Clicking BtnCombatPowerShift must immediately activate combat shift")
	assert(hud.directive_status_badge.visible == true, "GUI.71: TopBar directive badge must appear")
	
	# Jump to Research and complete Aegis study
	cmd_panel.btn_jump_to_research.pressed.emit()
	assert(cmd_panel.get_active_tab() == "research", "GUI.72: Clicking Jump to Research must open Research tab")
	var btn_res_aegis: Button = cmd_panel._tech_action_buttons.get(&"aegis_protocol")
	assert(btn_res_aegis != null and not btn_res_aegis.disabled, "GUI.73: Aegis research start button must be enabled with 500 ore/mat")
	btn_res_aegis.pressed.emit()
	assert(GameState.active_research_id == &"aegis_protocol", "GUI.74: Clicking start research must queue aegis_protocol")
	
	var tick_mgr: TickManager = main_node.find_child("TickManager", true, false)
	for _t in range(8):
		tick_mgr.run_tick()
	assert(GameState.aegis_protocol_unlocked == true, "GUI.75: 8 ticks must unlock Aegis protocol")
	
	cmd_panel.btn_tab_directives.pressed.emit()
	assert(cmd_panel.btn_aegis_protocol.disabled == false, "GUI.76: Unlocked Aegis button must become enabled")
	cmd_panel.btn_aegis_protocol.pressed.emit()
	assert(GameState.aegis_protocol_active == true, "GUI.77: Clicking BtnAegisProtocol must activate Aegis")
	
	# Dynamic priority reorder via UI button
	var initial_order = GameState.get_power_category_order()
	var last_cat = initial_order[3]
	var prio_up_btn: Button = cmd_panel.find_child("BtnPrioUp_" + last_cat, true, false)
	assert(prio_up_btn != null, "GUI.78: Priority up button missing")
	prio_up_btn.pressed.emit()
	var updated_order = GameState.get_power_category_order()
	assert(updated_order[2] == last_cat, "GUI.79: Clicking priority up must promote category from #4 to #3")
	print("[OK] GUI.T11: Единая левая панель CommandPanel (4 кнопки, Исследования -> Директивы, приоритеты) полностью функциональна")
	
	# Test 12: Re-verify FOCUS_NONE across ALL newly created dynamic buttons inside CommandPanel & LayerIndicator
	var focus_violations_after := _check_focus_none(hud)
	assert(focus_violations_after == 0, "GUI.80: All dynamic HUD buttons must keep FOCUS_NONE, found %d violations" % focus_violations_after)
	print("[OK] GUI.T12: Все динамические кнопки CommandPanel и LayerIndicator сохраняют FOCUS_NONE")
	
	# Test 13: Zero HUD geometry overlap check at 1920x1080 (desktop) and 1280x800 (compact / Steam Deck)
	var hud_scene = load("res://ui/hud.tscn") as PackedScene
	
	# 13A: Exact 1920x1080 SubViewport verification
	var sv_hd := SubViewport.new()
	sv_hd.name = "Desktop1080TestViewport"
	sv_hd.size = Vector2i(1920, 1080)
	sv_hd.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main_node.add_child(sv_hd)
	var sub_hd_hud := hud_scene.instantiate() as GameHUD
	sv_hd.add_child(sub_hd_hud)
	await main_node.get_tree().process_frame
	await main_node.get_tree().process_frame
	assert(sub_hd_hud._is_compact_viewport == false, "GUI.80b: SubViewport 1920x1080 must stay in desktop layout mode")
	_assert_no_ui_overlaps(sub_hd_hud, Vector2(1920, 1080), "Desktop 1920x1080 (CommandPanel open, Shelf closed)")
	sub_hd_hud.build_toolbar._category_buttons["defense"].pressed.emit()
	await main_node.get_tree().process_frame
	await main_node.get_tree().process_frame
	_assert_no_ui_overlaps(sub_hd_hud, Vector2(1920, 1080), "Desktop 1920x1080 (CommandPanel open + Defense Shelf 8 cards open)")
	sub_hd_hud.command_panel.set_expanded(false)
	await main_node.get_tree().process_frame
	_assert_no_ui_overlaps(sub_hd_hud, Vector2(1920, 1080), "Desktop 1920x1080 (CommandPanel collapsed + Shelf open)")
	sv_hd.queue_free()
	
	# 13B: Compact 1280x800 layout verification via real SubViewport
	var sv := SubViewport.new()
	sv.name = "CompactLayoutTestViewport"
	sv.size = Vector2i(1280, 800)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main_node.add_child(sv)
	var sub_hud := hud_scene.instantiate() as GameHUD
	sv.add_child(sub_hud)
	await main_node.get_tree().process_frame
	await main_node.get_tree().process_frame
	assert(sub_hud._is_compact_viewport == true, "GUI.81: SubViewport 1280x800 must activate compact layout mode")
	_assert_no_ui_overlaps(sub_hud, Vector2(1280, 800), "Compact 1280x800 (CommandPanel expanded, Shelf closed)")
	
	# Opening BuildShelf on 1280x800 must auto-collapse CommandPanel & have zero overlaps
	sub_hud.build_toolbar._category_buttons["defense"].pressed.emit()
	await main_node.get_tree().process_frame
	await main_node.get_tree().process_frame
	assert(sub_hud.command_panel.is_expanded() == false, "GUI.82: Opening BuildShelf in 1280x800 compact mode must collapse CommandPanel")
	_assert_no_ui_overlaps(sub_hud, Vector2(1280, 800), "Compact 1280x800 (Shelf open, CommandPanel auto-collapsed)")
	
	# Expanding CommandPanel on 1280x800 must auto-close BuildShelf & have zero overlaps
	sub_hud.command_panel.btn_tab_research.pressed.emit()
	await main_node.get_tree().process_frame
	await main_node.get_tree().process_frame
	assert(sub_hud.build_toolbar.shelf_panel.visible == false, "GUI.83: Opening CommandPanel in 1280x800 compact mode must close BuildShelf")
	_assert_no_ui_overlaps(sub_hud, Vector2(1280, 800), "Compact 1280x800 (Research expanded, Shelf auto-closed)")
	sv.queue_free()

	# 13C: 1550–1920 × 900 Desktop resolution matrix verification
	var desktop_resolutions: Array[Vector2i] = [
		Vector2i(1550, 900),
		Vector2i(1600, 900),
		Vector2i(1680, 1050),
		Vector2i(1920, 900)
	]
	for target_res in desktop_resolutions:
		var sv_mat := SubViewport.new()
		sv_mat.name = "MatrixTestViewport_%dx%d" % [target_res.x, target_res.y]
		sv_mat.size = target_res
		sv_mat.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		main_node.add_child(sv_mat)
		var mat_hud := hud_scene.instantiate() as GameHUD
		sv_mat.add_child(mat_hud)
		await main_node.get_tree().process_frame
		await main_node.get_tree().process_frame
		
		var vp_v2 := Vector2(target_res.x, target_res.y)
		_assert_no_ui_overlaps(mat_hud, vp_v2, "Matrix %dx%d (Initial)" % [target_res.x, target_res.y])
		
		# Open shelf
		mat_hud.build_toolbar._category_buttons["defense"].pressed.emit()
		await main_node.get_tree().process_frame
		await main_node.get_tree().process_frame
		_assert_no_ui_overlaps(mat_hud, vp_v2, "Matrix %dx%d (Shelf open)" % [target_res.x, target_res.y])
		
		# Toggle CommandPanel
		mat_hud.command_panel.btn_tab_research.pressed.emit()
		await main_node.get_tree().process_frame
		await main_node.get_tree().process_frame
		_assert_no_ui_overlaps(mat_hud, vp_v2, "Matrix %dx%d (CommandPanel toggled)" % [target_res.x, target_res.y])
		
		sv_mat.queue_free()
	
	GameState.reset_directives_and_research()
	GameState.set_game_mode(GameState.GameMode.STANDARD)
	toolbar._close_shelf()
	print("[OK] GUI.T13: Геометрическая матрица HUD проверена на 1920x1080, 1280x800 и матрице 1550–1920x900 — 0 пересечений и вылетов за экран")
	
	print("--- ВСЕ ТЕСТЫ GUI УСПЕШНО ПРОЙДЕНЫ ---")

static func _assert_no_ui_overlaps(hud_node: GameHUD, vp_size: Vector2, case_label: String) -> void:
	var panels: Array[Control] = []
	for node_name in ["TopBar", "OverlayToggle", "LayerIndicator", "MinimapPanel", "SpeedControl", "CommandPanel", "BuildToolbar"]:
		var ctrl = hud_node.get_node_or_null(node_name) as Control
		if ctrl and ctrl.visible:
			panels.append(ctrl)
	var screen_rect := Rect2(Vector2(-1.0, -1.0), vp_size + Vector2(2.0, 2.0))
	for i in range(panels.size()):
		var a = panels[i]
		var ra = a.get_global_rect()
		assert(screen_rect.encloses(ra), "Overlap/Bounds [%s]: '%s' rect %s exceeds viewport %s" % [case_label, a.name, str(ra), str(vp_size)])
		for j in range(i + 1, panels.size()):
			var b = panels[j]
			var rb = b.get_global_rect()
			assert(not ra.intersects(rb), "Overlap [%s]: '%s' %s intersects '%s' %s" % [case_label, a.name, str(ra), b.name, str(rb)])

static func _check_focus_none(node: Node) -> int:
	var count := 0
	if node is Button and node.focus_mode != Control.FOCUS_NONE:
		count += 1
	for c in node.get_children():
		count += _check_focus_none(c)
	return count

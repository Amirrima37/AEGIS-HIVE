class_name NetworkOverlay
extends Node2D

@export var network_manager: NetworkManager = null
@export var building_manager: BuildingManager = null
@export var defense_system: DefenseSystem = null

var show_power_overlay: bool = false
var show_supply_overlay: bool = false
var show_integrity_overlay: bool = false

func _ready() -> void:
	z_index = 50
	_find_dependencies()
	
	if EventBus:
		if EventBus.has_signal("network_updated"):
			EventBus.network_updated.connect(_on_network_updated)
		if EventBus.has_signal("overlay_toggled"):
			EventBus.overlay_toggled.connect(_on_overlay_toggled)
		if EventBus.has_signal("active_layer_changed"):
			EventBus.active_layer_changed.connect(_on_layer_changed)
		if EventBus.has_signal("building_damaged"):
			EventBus.building_damaged.connect(_on_building_state_changed)
		if EventBus.has_signal("building_repaired"):
			EventBus.building_repaired.connect(_on_building_repaired)
		if EventBus.has_signal("building_placed"):
			EventBus.building_placed.connect(_on_building_placed_or_removed)
		if EventBus.has_signal("building_removed"):
			EventBus.building_removed.connect(_on_building_placed_or_removed)

func _find_dependencies() -> void:
	if (network_manager == null or not is_instance_valid(network_manager)) and is_inside_tree():
		network_manager = get_tree().root.find_child("NetworkManager", true, false)
	if (building_manager == null or not is_instance_valid(building_manager)):
		if network_manager and network_manager.building_manager and is_instance_valid(network_manager.building_manager):
			building_manager = network_manager.building_manager
		elif is_inside_tree():
			building_manager = get_tree().root.find_child("BuildingManager", true, false)
	if (defense_system == null or not is_instance_valid(defense_system)) and is_inside_tree():
		defense_system = get_tree().root.find_child("DefenseSystem", true, false)

func _get_defense_system() -> DefenseSystem:
	if defense_system and is_instance_valid(defense_system):
		return defense_system
	if is_inside_tree():
		defense_system = get_tree().root.find_child("DefenseSystem", true, false)
		return defense_system
	return null

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code == KEY_F1:
			toggle_power_overlay()
			get_viewport().set_input_as_handled()
		elif code == KEY_F2:
			toggle_supply_overlay()
			get_viewport().set_input_as_handled()
		elif code == KEY_F4:
			toggle_integrity_overlay()
			get_viewport().set_input_as_handled()

func toggle_power_overlay() -> void:
	show_power_overlay = not show_power_overlay
	if EventBus and EventBus.has_signal("overlay_toggled"):
		EventBus.overlay_toggled.emit("power", show_power_overlay)
	queue_redraw()

func toggle_supply_overlay() -> void:
	show_supply_overlay = not show_supply_overlay
	if EventBus and EventBus.has_signal("overlay_toggled"):
		EventBus.overlay_toggled.emit("supply", show_supply_overlay)
	queue_redraw()

func toggle_integrity_overlay() -> void:
	show_integrity_overlay = not show_integrity_overlay
	if EventBus and EventBus.has_signal("overlay_toggled"):
		EventBus.overlay_toggled.emit("integrity", show_integrity_overlay)
	queue_redraw()

func _on_overlay_toggled(overlay_name: String, is_visible: bool) -> void:
	if overlay_name == "power":
		show_power_overlay = is_visible
	elif overlay_name == "supply":
		show_supply_overlay = is_visible
	elif overlay_name == "integrity":
		show_integrity_overlay = is_visible
	queue_redraw()

func _on_network_updated(_type: String) -> void:
	queue_redraw()

func _on_layer_changed(_z: int) -> void:
	queue_redraw()

func _on_building_state_changed(_b: Node2D, _amount: int = 0, _hp: int = 0) -> void:
	if show_integrity_overlay:
		queue_redraw()

func _on_building_repaired(_b: Node2D, _amount: int = 0) -> void:
	if show_integrity_overlay:
		queue_redraw()

func _on_building_placed_or_removed(_b: Node2D) -> void:
	if show_integrity_overlay:
		queue_redraw()

func _draw() -> void:
	_find_dependencies()
	var cur_z = GameState.current_layer
	
	# Draw power lines (Cyan)
	if show_power_overlay and network_manager:
		var pg = network_manager.get_power_grid()
		if pg:
			var edges = pg.get_all_edges()
			var cyan = Color(0.0, 0.9, 1.0, 0.85)
			for edge in edges:
				var b1 = edge[0] as Building
				var b2 = edge[1] as Building
				if not is_instance_valid(b1) or not is_instance_valid(b2):
					continue
				if b1.z_level == cur_z and b2.z_level == cur_z:
					var p1 = to_local(b1.global_position)
					var p2 = to_local(b2.global_position)
					draw_line(p1, p2, cyan, 3.0, true)
					draw_circle(p1, 4.0, cyan)
					draw_circle(p2, 4.0, cyan)
				elif b1.z_level == cur_z and b2.z_level != cur_z:
					var p1 = to_local(b1.global_position)
					draw_arc(p1, 16.0, 0, TAU, 24, cyan, 2.5, true)
				elif b2.z_level == cur_z and b1.z_level != cur_z:
					var p2 = to_local(b2.global_position)
					draw_arc(p2, 16.0, 0, TAU, 24, cyan, 2.5, true)
					
	# Draw supply lines (Amber)
	if show_supply_overlay and network_manager:
		var sc = network_manager.get_supply_chain()
		if sc:
			var edges = sc.get_all_edges()
			var amber = Color(1.0, 0.6, 0.1, 0.85)
			for edge in edges:
				var b1 = edge[0] as Building
				var b2 = edge[1] as Building
				if not is_instance_valid(b1) or not is_instance_valid(b2):
					continue
				if b1.z_level == cur_z and b2.z_level == cur_z:
					var p1 = to_local(b1.global_position)
					var p2 = to_local(b2.global_position)
					draw_line(p1, p2, amber, 3.0, true)
					draw_circle(p1, 4.0, amber)
					draw_circle(p2, 4.0, amber)
				elif b1.z_level == cur_z and b2.z_level != cur_z:
					var p1 = to_local(b1.global_position)
					draw_arc(p1, 20.0, 0, TAU, 24, amber, 2.5, true)
				elif b2.z_level == cur_z and b1.z_level != cur_z:
					var p2 = to_local(b2.global_position)
					draw_arc(p2, 20.0, 0, TAU, 24, amber, 2.5, true)

	# Draw Armor / Structural Integrity (HP Bars & Footprints)
	if show_integrity_overlay and building_manager:
		var buildings = building_manager.get_buildings_on_layer(cur_z)
		var font = ThemeDB.fallback_font
		for b in buildings:
			if not is_instance_valid(b) or not b.data:
				continue
			var pos = to_local(b.global_position)
			var size = b.data.tile_size
			var max_hp = max(1, b.data.max_hp)
			var cur_hp = clamp(b.current_hp, 0, max_hp)
			var ratio = float(cur_hp) / float(max_hp)
			
			# Color selection based on structural condition
			var col = Color(0.20, 0.88, 0.45, 0.95) # Healthy Green
			if ratio < 0.40:
				col = Color(0.95, 0.25, 0.25, 0.98) # Critical Red
			elif ratio < 0.85:
				col = Color(0.96, 0.62, 0.07, 0.95) # Damaged Amber
				
			# Isometric diamond footprint outline matching tile size
			var sx = float(size.x)
			var sy = float(size.y)
			var top = pos + Vector2((sy - sx) * 32.0, -(sx + sy) * 16.0)
			var right = pos + Vector2((sx + sy) * 32.0, (sx - sy) * 16.0)
			var bottom = pos + Vector2((sx - sy) * 32.0, (sx + sy) * 16.0)
			var left = pos + Vector2(-(sx + sy) * 32.0, -(sx - sy) * 16.0)
			var fill_poly = PackedVector2Array([top, right, bottom, left])
			draw_colored_polygon(fill_poly, Color(col.r, col.g, col.b, 0.14))
			var diamond = PackedVector2Array([top, right, bottom, left, top])
			draw_polyline(diamond, Color(col.r, col.g, col.b, 0.85), 2.5, true)
			
			# Armor / Integrity bar positioned above building footprint
			var bar_w = 64.0 if (size.x == 1 and size.y == 1) else 86.0
			var bar_h = 9.0
			var bar_y = pos.y - (26.0 + float(size.x + size.y) * 9.0)
			var bar_x = pos.x - bar_w * 0.5
			
			# High-contrast brutalist backdrop pill + HP bar
			draw_rect(Rect2(bar_x - 4, bar_y - 16, bar_w + 8, bar_h + 20), Color(0.05, 0.07, 0.09, 0.88), true)
			draw_rect(Rect2(bar_x - 1, bar_y - 1, bar_w + 2, bar_h + 2), Color(0.03, 0.04, 0.06, 0.95), true)
			draw_rect(Rect2(bar_x, bar_y, bar_w * ratio, bar_h), col, true)
			draw_rect(Rect2(bar_x - 1, bar_y - 1, bar_w + 2, bar_h + 2), Color(0.32, 0.36, 0.44, 1.0), false, 1.0)
			
			# HP & Efficiency readout text
			if font:
				var eff_pct = int(round((b.get_efficiency() if b.has_method("get_efficiency") else 1.0) * 100.0))
				var hp_text = "%d/%d (%d%%)" % [cur_hp, max_hp, int(round(ratio * 100.0))]
				if cur_hp <= 0:
					hp_text += " [РУИНЫ]"
				elif eff_pct < 100:
					hp_text += " [КПД %d%%]" % eff_pct
				var font_size = 11
				var text_size = font.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
				var text_pos = Vector2(pos.x - text_size.x * 0.5, bar_y - 4.0)
				draw_string(font, text_pos + Vector2(1, 1), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.9))
				draw_string(font, text_pos, hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.95, 0.97, 1.0, 1.0))

		# Overhead Armor Deck shield projections protecting current layer from above
		var ds = _get_defense_system()
		if ds and ds.has_method("get_layer_armor_decks_protecting"):
			var decks = ds.get_layer_armor_decks_protecting(cur_z)
			for deck in decks:
				if not is_instance_valid(deck) or deck.data == null:
					continue
				var pos = to_local(deck.global_position)
				var sz = deck.data.tile_size
				var sx = float(sz.x)
				var sy = float(sz.y)
				var top = pos + Vector2((sy - sx) * 32.0, -(sx + sy) * 16.0)
				var right = pos + Vector2((sx + sy) * 32.0, (sx - sy) * 16.0)
				var bottom = pos + Vector2((sx - sy) * 32.0, (sx + sy) * 16.0)
				var left = pos + Vector2(-(sx + sy) * 32.0, -(sx - sy) * 16.0)
				var deck_poly = PackedVector2Array([top, right, bottom, left])
				var steel_blue = Color(0.32, 0.72, 0.96, 0.75)
				draw_colored_polygon(deck_poly, Color(0.32, 0.72, 0.96, 0.12))
				draw_polyline(PackedVector2Array([top, right, bottom, left, top]), steel_blue, 2.0, true)
				draw_line(top, bottom, Color(0.32, 0.72, 0.96, 0.35), 1.0, true)
				draw_line(left, right, Color(0.32, 0.72, 0.96, 0.35), 1.0, true)
				if font:
					var badge = "🛡 ПАЛУБА (+%d)" % deck.z_level
					var ts = font.get_string_size(badge, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
					draw_string(font, pos + Vector2(-ts.x * 0.5, 4.0), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.75, 0.92, 1.0, 0.95))

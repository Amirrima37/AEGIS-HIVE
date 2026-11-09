class_name Building
extends Node2D

var data: BuildingData
var grid_position: Vector2i = Vector2i.ZERO
var z_level: int = 0
var current_hp: int = 100

var connected_to_power: bool = true:
	set(value):
		connected_to_power = value
		update_operational_state()

var connected_to_supply: bool = true:
	set(value):
		connected_to_supply = value
		update_operational_state()

var is_operational: bool = true:
	set(value):
		is_operational = value
		_update_operational_visuals()

var sprite_node: Sprite2D = null
var status_rim_node: Node2D = null
var damage_overlay_node: Node2D = null

func _ready() -> void:
	if sprite_node == null:
		_setup_sprite()
	if damage_overlay_node == null:
		_setup_damage_overlay()
	if status_rim_node == null:
		_setup_status_rim()
	_update_position_from_parent()

func init(p_data: BuildingData, pos: Vector2i, z: int, tml: TileMapLayer = null) -> void:
	data = p_data
	grid_position = pos
	z_level = z
	if data:
		current_hp = data.max_hp
		if data.network_type == "power_source":
			connected_to_power = true
		elif data.network_type == "supply_source":
			connected_to_supply = true
	_setup_sprite()
	_setup_damage_overlay()
	_setup_status_rim()
	if tml:
		update_world_position(tml)
	if data and data.is_connector:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
	update_operational_state()

func _setup_sprite() -> void:
	if sprite_node == null:
		sprite_node = Sprite2D.new()
		sprite_node.name = "Sprite2D"
		add_child(sprite_node)
	
	if data and data.sprite:
		sprite_node.texture = data.sprite
		sprite_node.centered = true

func _setup_damage_overlay() -> void:
	if damage_overlay_node == null:
		damage_overlay_node = Node2D.new()
		damage_overlay_node.name = "DamageOverlay"
		damage_overlay_node.z_index = 3
		damage_overlay_node.visible = false
		damage_overlay_node.draw.connect(_on_draw_damage_overlay)
		add_child(damage_overlay_node)

func _on_draw_damage_overlay() -> void:
	if not is_instance_valid(damage_overlay_node) or not data:
		return
	var max_hp = max(1, data.max_hp)
	var ratio = float(current_hp) / float(max_hp)
	var size = data.tile_size
	var sx = float(size.x)
	var sy = float(size.y)
	var top = Vector2((sy - sx) * 32.0, -(sx + sy) * 16.0)
	var right = Vector2((sx + sy) * 32.0, (sx - sy) * 16.0)
	var bottom = Vector2((sx - sy) * 32.0, (sx + sy) * 16.0)
	var left = Vector2(-(sx + sy) * 32.0, -(sx - sy) * 16.0)

	if current_hp <= 0:
		# Ruined state (0 HP): dark debris bed + crossed twisted beams
		var rubble = PackedVector2Array([top * 0.85, right * 0.85, bottom * 0.85, left * 0.85])
		damage_overlay_node.draw_colored_polygon(rubble, Color(0.12, 0.11, 0.10, 0.72))
		damage_overlay_node.draw_line(left * 0.72, right * 0.72, Color(0.85, 0.30, 0.20, 0.90), 3.0, true)
		damage_overlay_node.draw_line(top * 0.72, bottom * 0.72, Color(0.85, 0.30, 0.20, 0.90), 3.0, true)
		damage_overlay_node.draw_line(left * 0.45 + Vector2(0, -14), right * 0.40 + Vector2(0, -4), Color(0.35, 0.38, 0.42, 0.95), 4.0, true)
	elif ratio < 0.5:
		# Heavily damaged (< 50% HP): soot cracks and hazard sparks
		damage_overlay_node.draw_line(Vector2(-14, -18), Vector2(4, -6), Color(0.10, 0.08, 0.08, 0.85), 2.5, true)
		damage_overlay_node.draw_line(Vector2(4, -6), Vector2(-6, 6), Color(0.10, 0.08, 0.08, 0.85), 2.0, true)
		damage_overlay_node.draw_line(Vector2(4, -6), Vector2(18, 2), Color(0.96, 0.62, 0.07, 0.85), 2.0, true)
		damage_overlay_node.draw_circle(Vector2(0, -14), 3.5, Color(0.96, 0.48, 0.08, 0.85))

func _setup_status_rim() -> void:
	if status_rim_node == null:
		status_rim_node = Node2D.new()
		status_rim_node.name = "StatusRim"
		status_rim_node.z_index = 2
		status_rim_node.draw.connect(_on_draw_status_rim)
		add_child(status_rim_node)
	_update_operational_visuals()

func _process(_delta: float) -> void:
	if status_rim_node and status_rim_node.visible:
		status_rim_node.queue_redraw()

func _on_draw_status_rim() -> void:
	if not status_rim_node or not is_instance_valid(status_rim_node):
		return
	var size = data.tile_size if data else Vector2i(1, 1)
	var sx = float(size.x)
	var sy = float(size.y)
	
	# Isometric diamond vertices matching grid footprint centered at (0, 0)
	var top = Vector2((sy - sx) * 32.0, -(sx + sy) * 16.0)
	var right = Vector2((sx + sy) * 32.0, (sx - sy) * 16.0)
	var bottom = Vector2((sx - sy) * 32.0, (sx + sy) * 16.0)
	var left = Vector2(-(sx + sy) * 32.0, -(sx - sy) * 16.0)
	var points = PackedVector2Array([top, right, bottom, left, top])
	
	var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	var outer_alpha = 0.20 + 0.45 * pulse
	var core_alpha = 0.45 + 0.55 * pulse
	
	# Outer soft neon glow
	status_rim_node.draw_polyline(points, Color(1.0, 0.1, 0.1, outer_alpha), 4.0, true)
	# Inner bright neon core
	status_rim_node.draw_polyline(points, Color(1.0, 0.25, 0.25, core_alpha), 2.0, true)

func update_world_position(tml: TileMapLayer) -> void:
	if not tml:
		return
	var size = data.tile_size if data else Vector2i(1, 1)
	var origin_local = tml.map_to_local(grid_position)
	var end_local = tml.map_to_local(grid_position + size - Vector2i(1, 1))
	position = (origin_local + end_local) * 0.5
	
	if sprite_node and sprite_node.texture:
		var tex_h = sprite_node.texture.get_height()
		# Стандартизированная формула идеального попадания основания здания на ромб сетки:
		# Нижняя вершина ромба основания находится на tex_h - 3 (с сохранением 2px антиалиасинга)
		var base_y_offset = (size.x * 32.0 + 3.0) - tex_h * 0.5
		if data and "base_offset_y" in data:
			base_y_offset += data.base_offset_y
		sprite_node.offset = Vector2(0, base_y_offset)

func _update_position_from_parent() -> void:
	var p = get_parent()
	if p is TileMapLayer:
		update_world_position(p)
	elif p and p.get_parent() is TileMapLayer:
		update_world_position(p.get_parent())

func get_efficiency() -> float:
	if current_hp <= 0:
		return 0.0
	var max_hp = max(1, data.max_hp if data else 100)
	var ratio = float(current_hp) / float(max_hp)
	if ratio >= 0.5:
		return 1.0
	return clamp(0.4 + 0.6 * (ratio / 0.5), 0.4, 1.0)

func update_operational_state() -> void:
	var op = (current_hp > 0)
	if data:
		if data.network_type == "power_source":
			# Power sources are always powered
			pass
		elif data.is_connector:
			# Connectors only depend on HP
			pass
		else:
			if data.energy_consumption > 0 or data.network_type in ["power_consumer", "supply_consumer", "supply_source"]:
				if not connected_to_power:
					op = false
			if data.network_type == "supply_consumer":
				if not connected_to_supply:
					op = false
			if GameState and GameState.has_method("is_blocked_by_combat_mode") and GameState.is_blocked_by_combat_mode(data):
				op = false
	is_operational = op
	_update_damage_visuals()

func _update_damage_visuals() -> void:
	var max_hp = max(1, data.max_hp if data else 100)
	var ratio = float(current_hp) / float(max_hp)
	if is_instance_valid(sprite_node) and data:
		if current_hp <= 0:
			if data.ruined_sprite:
				sprite_node.texture = data.ruined_sprite
				sprite_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			else:
				if data.sprite:
					sprite_node.texture = data.sprite
				sprite_node.modulate = Color(0.32, 0.30, 0.28, 0.85)
		elif ratio < 0.5:
			if data.damaged_sprite:
				sprite_node.texture = data.damaged_sprite
				sprite_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			else:
				if data.sprite:
					sprite_node.texture = data.sprite
				sprite_node.modulate = Color(0.65, 0.60, 0.58, 1.0)
		else:
			if data.sprite:
				sprite_node.texture = data.sprite
			sprite_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if is_instance_valid(damage_overlay_node):
		damage_overlay_node.visible = (current_hp <= 0 or ratio < 0.5)
		if damage_overlay_node.visible:
			damage_overlay_node.queue_redraw()

func _update_operational_visuals() -> void:
	_update_damage_visuals()
	
	if status_rim_node and is_instance_valid(status_rim_node):
		var is_conn = (data != null and data.is_connector)
		var should_show = (not is_operational) and (not is_conn)
		status_rim_node.visible = should_show
		if should_show:
			status_rim_node.queue_redraw()

func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)
	update_operational_state()
	if EventBus and EventBus.has_signal("building_damaged"):
		EventBus.building_damaged.emit(self, amount, current_hp)

func get_refund() -> Dictionary:
	if not data:
		return {"ore": 0, "materials": 0}
	var rate = 0.25 if current_hp <= 0 else 0.5
	return {
		"ore": int(data.cost_ore * rate),
		"materials": int(data.cost_materials * rate)
	}

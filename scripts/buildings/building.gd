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

func _ready() -> void:
	if sprite_node == null:
		_setup_sprite()
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
	if tml:
		update_world_position(tml)
	update_operational_state()

func _setup_sprite() -> void:
	if sprite_node == null:
		sprite_node = Sprite2D.new()
		sprite_node.name = "Sprite2D"
		add_child(sprite_node)
	
	if data and data.sprite:
		sprite_node.texture = data.sprite
		sprite_node.centered = true

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
	is_operational = op

func _update_operational_visuals() -> void:
	if not is_instance_valid(sprite_node):
		return
	if is_operational:
		sprite_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		sprite_node.modulate = Color(0.6, 0.6, 0.6, 0.7)

func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)
	update_operational_state()
	if EventBus and EventBus.has_signal("building_damaged"):
		EventBus.building_damaged.emit(self, amount, current_hp)

func get_refund() -> Dictionary:
	if not data:
		return {"ore": 0, "materials": 0}
	return {
		"ore": int(data.cost_ore * 0.5),
		"materials": int(data.cost_materials * 0.5)
	}

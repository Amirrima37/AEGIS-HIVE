class_name BuildingPlacer
extends Node2D

enum Mode { IDLE, BUILDING, DEMOLISHING, CABLING }

@export var building_manager: BuildingManager = null
@export var layer_manager: Node = null

var current_mode: Mode = Mode.IDLE
var current_building_data: BuildingData = null
var current_grid_pos: Vector2i = Vector2i.ZERO
var can_place_current: bool = false

var _ghost_node: Node2D = null
var _ghost_sprite: Sprite2D = null
var _highlighted_building: Building = null
var _is_cabling_mouse_down: bool = false
var _last_cabled_pos: Vector2i = Vector2i(999999, 999999)

func _ready() -> void:
	_setup_ghost()
	_find_dependencies()
	
	if EventBus:
		EventBus.build_mode_entered.connect(_on_build_mode_entered)
		EventBus.build_mode_exited.connect(_on_build_mode_exited)
		EventBus.demolish_mode_entered.connect(_on_demolish_mode_entered)
		EventBus.demolish_mode_exited.connect(_on_demolish_mode_exited)
		if EventBus.has_signal("cable_mode_entered"):
			EventBus.cable_mode_entered.connect(_on_cable_mode_entered)
		if EventBus.has_signal("cable_mode_exited"):
			EventBus.cable_mode_exited.connect(_on_cable_mode_exited)
		if EventBus.has_signal("game_mode_changed"):
			EventBus.game_mode_changed.connect(_on_game_mode_changed)

func _setup_ghost() -> void:
	_ghost_node = Node2D.new()
	_ghost_node.name = "GhostPreview"
	_ghost_node.visible = false
	_ghost_node.z_index = 100
	add_child(_ghost_node)
	
	_ghost_sprite = Sprite2D.new()
	_ghost_sprite.name = "GhostSprite"
	_ghost_sprite.centered = true
	_ghost_node.add_child(_ghost_sprite)

func _find_dependencies() -> void:
	if building_manager == null or not is_instance_valid(building_manager):
		if is_inside_tree():
			building_manager = get_tree().root.find_child("BuildingManager", true, false)
			
	if layer_manager == null or not is_instance_valid(layer_manager):
		if is_inside_tree():
			layer_manager = get_tree().root.find_child("LayerManager", true, false)

func _get_active_tile_map_layer() -> TileMapLayer:
	_find_dependencies()
	if layer_manager and "layers" in layer_manager:
		var z = GameState.current_layer
		if layer_manager.layers.has(z):
			return layer_manager.layers[z].tile_map_layer
	return null

func _unhandled_input(event: InputEvent) -> void:
	if current_mode == Mode.IDLE:
		return
		
	# Exit mode on ESC or Right Mouse Button
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_current_mode()
		get_viewport().set_input_as_handled()
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_current_mode()
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if current_mode == Mode.BUILDING:
					_handle_build_click()
					get_viewport().set_input_as_handled()
				elif current_mode == Mode.CABLING:
					_is_cabling_mouse_down = true
					_last_cabled_pos = current_grid_pos
					_handle_cable_click()
					get_viewport().set_input_as_handled()
				elif current_mode == Mode.DEMOLISHING:
					_handle_demolish_click()
					get_viewport().set_input_as_handled()
			else: # Released
				if current_mode == Mode.CABLING:
					_is_cabling_mouse_down = false
					_last_cabled_pos = Vector2i(999999, 999999)

func _process(_delta: float) -> void:
	if current_mode == Mode.BUILDING or current_mode == Mode.CABLING:
		_update_ghost_cursor()
		if current_mode == Mode.CABLING and _is_cabling_mouse_down:
			if current_grid_pos != _last_cabled_pos and can_place_current:
				_last_cabled_pos = current_grid_pos
				_handle_cable_click()
	elif current_mode == Mode.DEMOLISHING:
		_update_demolish_cursor()

func _update_ghost_cursor() -> void:
	if current_building_data == null:
		return
		
	var tml = _get_active_tile_map_layer()
	if tml == null:
		_ghost_node.visible = false
		return
		
	var mouse_world = get_global_mouse_position()
	var local_pos = tml.to_local(mouse_world)
	current_grid_pos = tml.local_to_map(local_pos)
	
	var size = current_building_data.tile_size
	var origin_local = tml.map_to_local(current_grid_pos)
	var end_local = tml.map_to_local(current_grid_pos + size - Vector2i(1, 1))
	var center_local = (origin_local + end_local) * 0.5
	
	_ghost_node.global_position = tml.to_global(center_local)
	_ghost_node.visible = true
	
	if _ghost_sprite and _ghost_sprite.texture:
		var tex_h = _ghost_sprite.texture.get_height()
		var base_y_offset = (size.x * 32.0 + 3.0) - tex_h * 0.5
		if current_building_data and "base_offset_y" in current_building_data:
			base_y_offset += current_building_data.base_offset_y
		_ghost_sprite.offset = Vector2(0, base_y_offset)
	
	# Check placement validity
	var z = GameState.current_layer
	var is_area_free = false
	if building_manager and building_manager.occupancy:
		is_area_free = building_manager.occupancy.is_area_free(z, current_grid_pos, size)
		
	var costs = {
		"ore": current_building_data.cost_ore,
		"materials": current_building_data.cost_materials
	}
	var can_afford = ResourceManager.can_afford(costs)
	
	var layer_allowed = true
	if current_building_data.allowed_layers == "surface_only" and z != 0:
		layer_allowed = false
	elif current_building_data.allowed_layers == "underground_only" and z >= 0:
		layer_allowed = false
		
	var unique_ok = true
	if current_building_data.id == &"command_center" and building_manager.get_building_count(&"command_center") > 0:
		unique_ok = false
		
	can_place_current = is_area_free and can_afford and layer_allowed and unique_ok
	
	if can_place_current:
		if current_building_data and current_building_data.connects_layers:
			var is_aligned = false
			if building_manager and building_manager.occupancy:
				for adj_z in [z - 1, z + 1]:
					var adj_b = building_manager.occupancy.get_building_at(adj_z, current_grid_pos)
					if adj_b and is_instance_valid(adj_b) and adj_b.data and adj_b.data.connects_layers:
						is_aligned = true
						break
			if is_aligned:
				_ghost_sprite.modulate = Color(0.1, 1.5, 0.4, 0.85) # Изумрудный: точное попадание в шахту лифта
			else:
				_ghost_sprite.modulate = Color(1.0, 0.85, 0.2, 0.75) # Янтарный: лифт без вертикальной связки
		else:
			_ghost_sprite.modulate = Color(0.3, 1.0, 0.3, 0.6) # Green
	else:
		_ghost_sprite.modulate = Color(1.0, 0.3, 0.3, 0.6) # Red

func _draw() -> void:
	if current_mode != Mode.BUILDING or current_building_data == null:
		return
	if not current_building_data.connects_layers:
		return
		
	var tml = _get_active_tile_map_layer()
	if tml == null or building_manager == null:
		return
		
	var cur_z = GameState.current_layer
	var shaft_color = Color(0.0, 0.9, 1.0, 0.55) # Голографический контур шахты лифта
	
	# Проекция контуров лифтов со смежных ярусов (cur_z - 1 и cur_z + 1)
	for adj_z in [cur_z - 1, cur_z + 1]:
		var adj_buildings = building_manager.get_buildings_on_layer(adj_z)
		for b in adj_buildings:
			if is_instance_valid(b) and b.data and b.data.connects_layers:
				var pos = b.grid_position
				var size = b.data.tile_size
				var origin_l = tml.map_to_local(pos)
				var end_l = tml.map_to_local(pos + size - Vector2i(1, 1))
				var center_local = to_local(tml.to_global((origin_l + end_l) * 0.5))
				
				var hw = size.x * 64.0
				var hh = size.y * 32.0
				var pts = PackedVector2Array([
					center_local + Vector2(0, -hh),
					center_local + Vector2(hw, 0),
					center_local + Vector2(0, hh),
					center_local + Vector2(-hw, 0),
					center_local + Vector2(0, -hh)
				])
				draw_polyline(pts, shaft_color, 2.5, true)
				draw_circle(center_local, 4.0, shaft_color)

func _update_demolish_cursor() -> void:
	var tml = _get_active_tile_map_layer()
	if tml == null or building_manager == null:
		_clear_demolish_highlight()
		return
		
	var mouse_world = get_global_mouse_position()
	var local_pos = tml.to_local(mouse_world)
	var grid_pos = tml.local_to_map(local_pos)
	
	var target_b = null
	if building_manager.occupancy:
		target_b = building_manager.occupancy.get_building_at(GameState.current_layer, grid_pos)
		
	if target_b != _highlighted_building:
		_clear_demolish_highlight()
		if target_b and is_instance_valid(target_b):
			_highlighted_building = target_b
			_highlighted_building.modulate = Color(1.5, 0.3, 0.3, 0.8)

func _clear_demolish_highlight() -> void:
	if _highlighted_building and is_instance_valid(_highlighted_building):
		_highlighted_building.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if _highlighted_building.has_method("_update_operational_visuals"):
			_highlighted_building._update_operational_visuals()
	_highlighted_building = null

func _handle_build_click() -> void:
	if not can_place_current or current_building_data == null:
		return
	if building_manager == null:
		return
		
	var placed = building_manager.place_building(current_building_data, current_grid_pos, GameState.current_layer)
	if placed:
		# If Shift is held, player can continue building; otherwise exit build mode
		if not Input.is_key_pressed(KEY_SHIFT):
			_cancel_current_mode()

func _handle_cable_click() -> void:
	if not can_place_current or current_building_data == null:
		return
	if building_manager == null:
		return
		
	# Place the cable/conveyor and stay in CABLING mode for continuous laying
	building_manager.place_building(current_building_data, current_grid_pos, GameState.current_layer)

func _handle_demolish_click() -> void:
	if _highlighted_building and is_instance_valid(_highlighted_building):
		var b = _highlighted_building
		if b.data and b.data.is_structural:
			print("[WARN] Внимание: снос опорной конструкции может нарушить целостность верхних ярусов!")
		_clear_demolish_highlight()
		building_manager.remove_building(b)

func _cancel_current_mode() -> void:
	queue_redraw()
	if current_mode == Mode.BUILDING:
		current_mode = Mode.IDLE
		current_building_data = null
		_ghost_node.visible = false
		EventBus.build_mode_exited.emit()
	elif current_mode == Mode.CABLING:
		current_mode = Mode.IDLE
		current_building_data = null
		_is_cabling_mouse_down = false
		_last_cabled_pos = Vector2i(999999, 999999)
		_ghost_node.visible = false
		EventBus.cable_mode_exited.emit()
	elif current_mode == Mode.DEMOLISHING:
		current_mode = Mode.IDLE
		_clear_demolish_highlight()
		EventBus.demolish_mode_exited.emit()

func _on_build_mode_entered(building_data: Resource) -> void:
	_clear_demolish_highlight()
	if building_data is BuildingData:
		current_building_data = building_data
		current_mode = Mode.BUILDING
		if _ghost_sprite and current_building_data.sprite:
			_ghost_sprite.texture = current_building_data.sprite
		_update_ghost_cursor()
	queue_redraw()

func _on_build_mode_exited() -> void:
	queue_redraw()
	if current_mode == Mode.BUILDING:
		current_mode = Mode.IDLE
		current_building_data = null
		_ghost_node.visible = false

func _on_cable_mode_entered(cable_data: Resource) -> void:
	_clear_demolish_highlight()
	if cable_data is BuildingData:
		current_building_data = cable_data
		current_mode = Mode.CABLING
		if _ghost_sprite and current_building_data.sprite:
			_ghost_sprite.texture = current_building_data.sprite
		_update_ghost_cursor()

func _on_cable_mode_exited() -> void:
	if current_mode == Mode.CABLING:
		current_mode = Mode.IDLE
		current_building_data = null
		_is_cabling_mouse_down = false
		_last_cabled_pos = Vector2i(999999, 999999)
		_ghost_node.visible = false

func _on_demolish_mode_entered() -> void:
	current_mode = Mode.DEMOLISHING
	current_building_data = null
	_ghost_node.visible = false

func _on_demolish_mode_exited() -> void:
	if current_mode == Mode.DEMOLISHING:
		current_mode = Mode.IDLE
		_clear_demolish_highlight()

func _on_game_mode_changed(_mode: String) -> void:
	if current_mode == Mode.BUILDING or current_mode == Mode.CABLING:
		_update_ghost_cursor()

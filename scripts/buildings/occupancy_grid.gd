class_name OccupancyGrid
extends Node

var layer_manager: Node = null
var _grid: Dictionary = {} # z: int -> Dictionary (Vector2i -> Building)
var _blocked_cells: Dictionary = {} # z: int -> Dictionary (Vector2i -> bool)

func _ready() -> void:
	if EventBus:
		EventBus.layer_created.connect(_on_layer_created)
		EventBus.layer_removed.connect(_on_layer_removed)
		if EventBus.has_signal("wall_destroyed"):
			EventBus.wall_destroyed.connect(_on_wall_destroyed)

func init_grid(p_layer_manager: Node) -> void:
	layer_manager = p_layer_manager

func _get_layer_manager() -> Node:
	if layer_manager and is_instance_valid(layer_manager):
		return layer_manager
	if is_inside_tree():
		var found = get_tree().root.find_child("LayerManager", true, false)
		if found:
			layer_manager = found
			return layer_manager
	return null

func _on_layer_created(z: int) -> void:
	if not _grid.has(z):
		_grid[z] = {}
	if not _blocked_cells.has(z):
		_blocked_cells[z] = {}

func _on_layer_removed(z: int) -> void:
	_grid.erase(z)
	_blocked_cells.erase(z)

func _on_wall_destroyed(w: Node2D) -> void:
	if is_instance_valid(w) and "grid_position" in w and "z_level" in w:
		set_blocked(w.z_level, w.grid_position, false)

func has_tile(z: int, pos: Vector2i) -> bool:
	var lm = _get_layer_manager()
	if lm and "layers" in lm and lm.layers.has(z):
		var layer_data = lm.layers[z]
		var tml = layer_data.tile_map_layer
		if tml and tml is TileMapLayer:
			return tml.get_cell_source_id(pos) != -1
	# If no LayerManager is attached (e.g. unit tests without full scene), allow tile by default
	return true

func is_area_free(z: int, origin: Vector2i, size: Vector2i) -> bool:
	for dx in range(size.x):
		for dy in range(size.y):
			var pos = origin + Vector2i(dx, dy)
			if not has_tile(z, pos):
				return false
			if get_building_at(z, pos) != null:
				return false
	return true

func occupy(z: int, origin: Vector2i, size: Vector2i, building: Node2D) -> void:
	if not _grid.has(z):
		_grid[z] = {}
	var is_solid_building = false
	if building is WallNode:
		is_solid_building = true
	elif building and "data" in building and building.data and "is_solid" in building.data and building.data.is_solid:
		is_solid_building = true
	elif building and "is_solid" in building and building.is_solid:
		is_solid_building = true

	for dx in range(size.x):
		for dy in range(size.y):
			var pos = origin + Vector2i(dx, dy)
			_grid[z][pos] = building
			if is_solid_building:
				set_blocked(z, pos, true)

func vacate(z: int, origin: Vector2i, size: Vector2i) -> void:
	if not _grid.has(z):
		return
	for dx in range(size.x):
		for dy in range(size.y):
			var pos = origin + Vector2i(dx, dy)
			_grid[z].erase(pos)
			set_blocked(z, pos, false)

func get_building_at(z: int, pos: Vector2i) -> Node2D:
	if _grid.has(z) and _grid[z].has(pos):
		var b = _grid[z][pos]
		if is_instance_valid(b):
			return b
		else:
			_grid[z].erase(pos)
	return null

func is_blocked(z: int, pos: Vector2i) -> bool:
	var b = get_building_at(z, pos)
	if b != null:
		if b is WallNode:
			return b.is_solid and b.current_hp > 0
		elif "is_solid" in b and b.is_solid and "current_hp" in b:
			return b.current_hp > 0
	if _blocked_cells.has(z):
		return _blocked_cells[z].get(pos, false)
	return false

func set_blocked(z: int, pos: Vector2i, blocked: bool) -> void:
	if not _blocked_cells.has(z):
		_blocked_cells[z] = {}
	if blocked:
		_blocked_cells[z][pos] = true
	else:
		_blocked_cells[z].erase(pos)

func find_path(z: int, start_pos: Vector2i, end_pos: Vector2i) -> Array[Vector2i]:
	if start_pos == end_pos:
		return [start_pos]
		
	var queue: Array[Vector2i] = [start_pos]
	var visited: Dictionary = {start_pos: true}
	var parent: Dictionary = {}
	
	var directions = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]
	
	var found = false
	var max_iterations = 2000
	var iters = 0
	
	while queue.size() > 0 and iters < max_iterations:
		iters += 1
		var current = queue.pop_front()
		if current == end_pos:
			found = true
			break
			
		for d in directions:
			var neighbor = current + d
			if visited.has(neighbor):
				continue
			if is_blocked(z, neighbor):
				continue
			if not has_tile(z, neighbor):
				continue
				
			visited[neighbor] = true
			parent[neighbor] = current
			queue.push_back(neighbor)
			
	if not found:
		return []
		
	var path: Array[Vector2i] = []
	var curr = end_pos
	while curr != start_pos:
		path.push_front(curr)
		curr = parent[curr]
	path.push_front(start_pos)
	return path

func clear() -> void:
	_grid.clear()
	_blocked_cells.clear()

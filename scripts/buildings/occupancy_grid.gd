class_name OccupancyGrid
extends Node

var layer_manager: Node = null
var _grid: Dictionary = {} # z: int -> Dictionary (Vector2i -> Building)
var _blocked_cells: Dictionary = {} # z: int -> Dictionary (Vector2i -> bool)
var _astar_grids: Dictionary = {} # z: int -> AStarGrid2D

const DEFAULT_BOUNDS: Rect2i = Rect2i(-128, -128, 256, 256)

func _ready() -> void:
	if EventBus:
		EventBus.layer_created.connect(_on_layer_created)
		EventBus.layer_removed.connect(_on_layer_removed)
		if EventBus.has_signal("wall_destroyed"):
			EventBus.wall_destroyed.connect(_on_wall_destroyed)

func init_grid(p_layer_manager: Node) -> void:
	layer_manager = p_layer_manager
	if layer_manager and "layers" in layer_manager:
		for z in layer_manager.layers:
			_get_or_create_astar(z)

func _get_layer_manager() -> Node:
	if layer_manager and is_instance_valid(layer_manager):
		return layer_manager
	if is_inside_tree():
		var found = get_tree().root.find_child("LayerManager", true, false)
		if found:
			layer_manager = found
			return layer_manager
	return null

func _get_or_create_astar(z: int) -> AStarGrid2D:
	if _astar_grids.has(z):
		return _astar_grids[z]
	var astar = AStarGrid2D.new()
	astar.region = DEFAULT_BOUNDS
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	_sync_astar_grid(z, astar)
	_astar_grids[z] = astar
	return astar

func _sync_astar_grid(z: int, astar: AStarGrid2D) -> void:
	var lm = _get_layer_manager()
	if lm and "layers" in lm and lm.layers.has(z):
		var layer_data = lm.layers[z]
		var tml = layer_data.tile_map_layer
		if tml and tml is TileMapLayer:
			astar.fill_solid_region(astar.region, true)
			for pos in tml.get_used_cells():
				if astar.is_in_boundsv(pos):
					astar.set_point_solid(pos, false)
	else:
		astar.fill_solid_region(astar.region, false)

	if _blocked_cells.has(z):
		for pos in _blocked_cells[z]:
			if _blocked_cells[z][pos] and astar.is_in_boundsv(pos):
				astar.set_point_solid(pos, true)

func _ensure_bounds(astar: AStarGrid2D, z: int, pos: Vector2i) -> void:
	if not astar.is_in_boundsv(pos):
		var new_region = astar.region.expand(pos).grow(32)
		astar.region = new_region
		astar.update()
		_sync_astar_grid(z, astar)

func _on_layer_created(z: int) -> void:
	if not _grid.has(z):
		_grid[z] = {}
	if not _blocked_cells.has(z):
		_blocked_cells[z] = {}
	_astar_grids.erase(z)
	_get_or_create_astar(z)

func _on_layer_removed(z: int) -> void:
	_grid.erase(z)
	_blocked_cells.erase(z)
	_astar_grids.erase(z)

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

	if _astar_grids.has(z):
		var astar: AStarGrid2D = _astar_grids[z]
		_ensure_bounds(astar, z, pos)
		if astar.is_in_boundsv(pos):
			if blocked:
				astar.set_point_solid(pos, true)
			else:
				if has_tile(z, pos):
					astar.set_point_solid(pos, false)
				else:
					astar.set_point_solid(pos, true)

func find_path(z: int, start_pos: Vector2i, end_pos: Vector2i) -> Array[Vector2i]:
	if start_pos == end_pos:
		return [start_pos]
		
	var astar = _get_or_create_astar(z)
	_ensure_bounds(astar, z, start_pos)
	_ensure_bounds(astar, z, end_pos)

	if not astar.is_in_boundsv(start_pos) or not astar.is_in_boundsv(end_pos):
		return []

	if astar.is_point_solid(start_pos) or astar.is_point_solid(end_pos):
		return []

	return astar.get_id_path(start_pos, end_pos)

func clear() -> void:
	_grid.clear()
	_blocked_cells.clear()
	_astar_grids.clear()

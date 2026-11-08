class_name OccupancyGrid
extends Node

var layer_manager: Node = null
var _grid: Dictionary = {} # z: int -> Dictionary (Vector2i -> Building)

func _ready() -> void:
	if EventBus:
		EventBus.layer_created.connect(_on_layer_created)
		EventBus.layer_removed.connect(_on_layer_removed)

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

func _on_layer_removed(z: int) -> void:
	_grid.erase(z)

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
	for dx in range(size.x):
		for dy in range(size.y):
			var pos = origin + Vector2i(dx, dy)
			_grid[z][pos] = building

func vacate(z: int, origin: Vector2i, size: Vector2i) -> void:
	if not _grid.has(z):
		return
	for dx in range(size.x):
		for dy in range(size.y):
			var pos = origin + Vector2i(dx, dy)
			_grid[z].erase(pos)

func get_building_at(z: int, pos: Vector2i) -> Node2D:
	if _grid.has(z) and _grid[z].has(pos):
		var b = _grid[z][pos]
		if is_instance_valid(b):
			return b
		else:
			_grid[z].erase(pos)
	return null

func clear() -> void:
	_grid.clear()

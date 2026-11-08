class_name LayerManager
extends Node2D

const LayerData = preload("res://scripts/world/layer_data.gd")

@export var initial_grid_size: int = 64
@export var default_layer: int = 0

var layers: Dictionary = {} # int -> LayerData
var active_layer_z: int = 0
var shared_tileset: TileSet

# Source IDs in TileSet
const SOURCE_SURFACE: int = 0
const SOURCE_STRUCTURE: int = 1
const SOURCE_UNDERGROUND: int = 2

func _ready() -> void:
	_init_shared_tileset()
	
	# Connect to EventBus signals
	EventBus.layer_change_requested.connect(_on_layer_change_requested)
	EventBus.layer_jump_requested.connect(_on_layer_jump_requested)
	EventBus.layer_created.connect(_on_layer_created_requested)
	if EventBus.has_signal("request_create_layer_above"):
		EventBus.request_create_layer_above.connect(_on_request_create_layer_above)
	if EventBus.has_signal("request_create_layer_below"):
		EventBus.request_create_layer_below.connect(_on_request_create_layer_below)
	if EventBus.has_signal("building_removed"):
		EventBus.building_removed.connect(_on_building_changed_structural)
	if EventBus.has_signal("building_damaged"):
		EventBus.building_damaged.connect(_on_building_damaged_structural)
	if EventBus.has_signal("layer_removed"):
		EventBus.layer_removed.connect(_on_layer_removed_structural)
	
	# Create initial surface layer (z=0)
	create_layer(0)
	set_active_layer(0)

func _init_shared_tileset() -> void:
	shared_tileset = TileSet.new()
	shared_tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	shared_tileset.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	shared_tileset.tile_size = Vector2i(128, 64)
	
	_add_texture_source(SOURCE_SURFACE, "res://assets/tiles/surface_tile.png")
	_add_texture_source(SOURCE_STRUCTURE, "res://assets/tiles/structure_tile.png")
	_add_texture_source(SOURCE_UNDERGROUND, "res://assets/tiles/underground_tile.png")

func _add_texture_source(source_id: int, path: String) -> void:
	if not ResourceLoader.exists(path):
		push_warning("Tile texture not found: " + path)
		return
	var tex = load(path) as Texture2D
	if not tex:
		return
	var atlas = TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(128, 64)
	atlas.create_tile(Vector2i(0, 0))
	shared_tileset.add_source(atlas, source_id)

func create_layer(z: int) -> LayerData:
	if layers.has(z):
		return layers[z]
	
	var tml = TileMapLayer.new()
	tml.name = "Layer_%d" % z
	tml.tile_set = shared_tileset
	tml.y_sort_enabled = true
	# z_index ensures proper isometric layering order
	tml.z_index = z * 10
	add_child(tml)
	
	# Dedicated container for buildings so they are drawn above floor tiles and y-sorted among each other
	var b_container = Node2D.new()
	b_container.name = "Buildings"
	b_container.y_sort_enabled = true
	b_container.z_index = 1
	tml.add_child(b_container)
	
	var data = LayerData.new(z, tml)
	layers[z] = data
	
	_generate_initial_tiles(data)
	
	EventBus.layer_created.emit(z)
	_update_layers_visibility()
	return data

func _generate_initial_tiles(layer_data: LayerData) -> void:
	var tml = layer_data.tile_map_layer
	var half = initial_grid_size / 2
	var source_id = SOURCE_SURFACE
	
	if layer_data.z_level > 0:
		source_id = SOURCE_STRUCTURE
		# Platform starts as a central hub (smaller pad)
		half = max(4, initial_grid_size / 3)
	elif layer_data.z_level < 0:
		source_id = SOURCE_UNDERGROUND
		# Underground starts as an excavated chamber
		half = max(5, initial_grid_size / 3)
	
	for x in range(-half, half):
		for y in range(-half, half):
			# Diamond shaped island bounds
			if abs(x) + abs(y) <= half * 1.4:
				tml.set_cell(Vector2i(x, y), source_id, Vector2i(0, 0))

func set_active_layer(z: int) -> void:
	if not layers.has(z):
		return
	
	active_layer_z = z
	GameState.current_layer = z
	EventBus.active_layer_changed.emit(z)
	_update_layers_visibility()

func _update_layers_visibility() -> void:
	for z_key in layers.keys():
		var data: LayerData = layers[z_key]
		var tml: TileMapLayer = data.tile_map_layer
		
		if z_key > active_layer_z:
			# Любые ярусы ВЫШЕ активного скрываются, чтобы их тайлы, здания и сетка
			# не перекрывали активный слой и не делали его полупрозрачным!
			tml.visible = false
		elif z_key == active_layer_z:
			# Текущий рабочий ярус: строго видим и на 100% непрозрачен
			tml.visible = true
			tml.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			# Ярусы НИЖЕ активного: просвечивают сквозь открытые участки (почти прозрачные)
			var diff = active_layer_z - z_key
			if diff == 1:
				tml.visible = true
				tml.modulate = Color(0.65, 0.7, 0.75, 0.12)
			elif diff == 2:
				tml.visible = true
				tml.modulate = Color(0.5, 0.5, 0.6, 0.04)
			else:
				tml.visible = false

func _on_layer_change_requested(delta: int) -> void:
	var target_z = active_layer_z + delta
	if layers.has(target_z):
		set_active_layer(target_z)

func _on_layer_jump_requested(target_z: int) -> void:
	if layers.has(target_z):
		set_active_layer(target_z)

func _on_layer_created_requested(z: int) -> void:
	if not layers.has(z):
		create_layer(z)

func _get_building_manager() -> Node:
	if is_inside_tree():
		return get_tree().root.find_child("BuildingManager", true, false)
	return null

func _on_request_create_layer_above() -> void:
	var keys = get_existing_z_levels()
	var z_target = (keys.max() if not keys.is_empty() else 0) + 1
	var is_unl = GameState and GameState.has_method("is_unlimited_mode") and GameState.is_unlimited_mode()
	if not is_unl:
		var bm = _get_building_manager()
		if bm and bm.has_method("has_structural_support"):
			if not bm.has_structural_support(z_target):
				push_warning("Cannot create layer +%d: Requires a support pillar on layer %d" % [z_target, z_target - 1])
				return
	create_layer(z_target)

func _on_request_create_layer_below() -> void:
	var keys = get_existing_z_levels()
	var z_target = (keys.min() if not keys.is_empty() else 0) - 1
	var is_unl = GameState and GameState.has_method("is_unlimited_mode") and GameState.is_unlimited_mode()
	if not is_unl:
		var bm = _get_building_manager()
		if bm and bm.has_method("has_excavation_rig"):
			if not bm.has_excavation_rig(z_target):
				push_warning("Cannot create layer %d: Requires an excavation rig on layer %d" % [z_target, z_target + 1])
				return
	create_layer(z_target)

func get_existing_z_levels() -> Array:
	var keys = layers.keys()
	keys.sort()
	return keys

func remove_layer(z: int) -> void:
	if z == 0 or not layers.has(z):
		return
	var data = layers[z]
	layers.erase(z)
	if is_instance_valid(data.tile_map_layer):
		data.tile_map_layer.queue_free()
	EventBus.layer_removed.emit(z)
	if active_layer_z == z:
		set_active_layer(0)
	validate_structural_integrity()

func is_layer_structurally_sound(z: int) -> bool:
	if z == 0:
		return true
	var is_unl = GameState and GameState.has_method("is_unlimited_mode") and GameState.is_unlimited_mode()
	if is_unl:
		return true
	var bm = _get_building_manager()
	if bm == null:
		return true
	if z > 0:
		return bm.has_structural_support(z)
	elif z < 0:
		return bm.has_excavation_rig(z)
	return true

func validate_structural_integrity() -> Array[int]:
	var compromised: Array[int] = []
	var is_unl = GameState and GameState.has_method("is_unlimited_mode") and GameState.is_unlimited_mode()
	if is_unl:
		return compromised
		
	var bm = _get_building_manager()
	if bm == null:
		return compromised
		
	for z in get_existing_z_levels():
		if z > 0 and not bm.has_structural_support(z):
			compromised.append(z)
			if EventBus and EventBus.has_signal("layer_integrity_compromised"):
				EventBus.layer_integrity_compromised.emit(z, "missing_support_pillar")
		elif z < 0 and not bm.has_excavation_rig(z):
			compromised.append(z)
			if EventBus and EventBus.has_signal("layer_integrity_compromised"):
				EventBus.layer_integrity_compromised.emit(z, "missing_excavation_rig")
				
	return compromised

func _on_building_changed_structural(b: Node2D) -> void:
	if b and "data" in b and b.data and b.data.is_structural:
		validate_structural_integrity()

func _on_building_damaged_structural(b: Node2D, _amount: int, current_hp: int) -> void:
	if current_hp <= 0 and b and "data" in b and b.data and b.data.is_structural:
		validate_structural_integrity()

func _on_layer_removed_structural(_z: int) -> void:
	validate_structural_integrity()

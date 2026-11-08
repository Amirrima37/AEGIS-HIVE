class_name BuildingManager
extends Node2D

@export var layer_manager: Node = null
@onready var occupancy: OccupancyGrid = $OccupancyGrid

var _buildings: Dictionary = {} # int (z) -> Array[Building]

func _ready() -> void:
	if occupancy == null:
		var child = get_node_or_null("OccupancyGrid")
		if child is OccupancyGrid:
			occupancy = child
		else:
			occupancy = OccupancyGrid.new()
			occupancy.name = "OccupancyGrid"
			add_child(occupancy)
	
	_find_layer_manager()
	if occupancy:
		occupancy.init_grid(layer_manager)
		
	if EventBus:
		EventBus.layer_removed.connect(_on_layer_removed)

func _find_layer_manager() -> void:
	if layer_manager and is_instance_valid(layer_manager):
		return
	if is_inside_tree():
		layer_manager = get_tree().root.find_child("LayerManager", true, false)

func _on_layer_removed(z: int) -> void:
	if _buildings.has(z):
		for b in _buildings[z]:
			if is_instance_valid(b):
				b.queue_free()
		_buildings.erase(z)

func place_building(data: BuildingData, pos: Vector2i, z: int) -> Building:
	if data == null:
		push_warning("place_building called with null data")
		return null
	
	_find_layer_manager()
	if occupancy:
		occupancy.init_grid(layer_manager)
	
	# Check layer constraints
	if data.allowed_layers == "surface_only" and z != 0:
		push_warning("Building %s is only allowed on surface layer (z=0)" % data.id)
		return null
	if data.allowed_layers == "underground_only" and z >= 0:
		push_warning("Building %s is only allowed on underground layers (z<0)" % data.id)
		return null
		
	# Unique building check (command center can only exist once in the world)
	if data.id == &"command_center" and get_building_count(&"command_center") > 0:
		push_warning("Command Center already exists!")
		return null
		
	# Check tile occupancy
	if occupancy and not occupancy.is_area_free(z, pos, data.tile_size):
		return null
		
	# Check resources
	var costs = {
		"ore": data.cost_ore,
		"materials": data.cost_materials
	}
	if not ResourceManager.can_afford(costs):
		return null
		
	# Deduct resources
	if not ResourceManager.spend(costs):
		return null
		
	# Instantiate building
	var building: Building
	if data.custom_script != null:
		building = data.custom_script.new()
	elif data.id == &"defense_wall" or data.defense_role == "wall":
		building = WallNode.new()
	else:
		building = Building.new()
		
	building.name = "%s_%d_%d_%d" % [data.id, z, pos.x, pos.y]
	
	var tml: TileMapLayer = null
	if layer_manager and "layers" in layer_manager and layer_manager.layers.has(z):
		tml = layer_manager.layers[z].tile_map_layer
		
	if tml:
		var buildings_container = tml.get_node_or_null("Buildings")
		if buildings_container == null:
			buildings_container = Node2D.new()
			buildings_container.name = "Buildings"
			buildings_container.y_sort_enabled = true
			buildings_container.z_index = 1
			tml.add_child(buildings_container)
		buildings_container.add_child(building)
		building.init(data, pos, z, tml)
	else:
		add_child(building)
		building.init(data, pos, z)
		
	# Register in buildings list
	if not _buildings.has(z):
		_buildings[z] = []
	_buildings[z].append(building)
	
	# Register in OccupancyGrid
	if occupancy:
		occupancy.occupy(z, pos, data.tile_size, building)
		
	EventBus.building_placed.emit(building)
	return building

func remove_building(building: Building) -> void:
	if not is_instance_valid(building):
		return
		
	var z = building.z_level
	var pos = building.grid_position
	var size = building.data.tile_size if building.data else Vector2i(1, 1)
	
	# Refund resources
	var refund = building.get_refund()
	ResourceManager.produce(refund)
	
	# Vacate grid
	if occupancy:
		occupancy.vacate(z, pos, size)
		
	# Remove from registry
	if _buildings.has(z):
		_buildings[z].erase(building)
		
	EventBus.building_removed.emit(building)
	building.queue_free()

func get_buildings_on_layer(z: int) -> Array[Building]:
	var result: Array[Building] = []
	if not _buildings.has(z):
		return result
	for b in _buildings[z]:
		if is_instance_valid(b):
			result.append(b)
	return result

func get_all_buildings() -> Array[Building]:
	var result: Array[Building] = []
	for z in _buildings.keys():
		for b in _buildings[z]:
			if is_instance_valid(b):
				result.append(b)
	return result

func get_building_count(id: StringName) -> int:
	var count = 0
	for b in get_all_buildings():
		if b.data and b.data.id == id:
			count += 1
	return count

func has_structural_support(target_z: int) -> bool:
	# Check layer directly below target_z (z - 1) for support pillar
	var support_layer = target_z - 1
	var list = get_buildings_on_layer(support_layer)
	for b in list:
		if b.data and b.data.unlocks_layer_above and b.is_operational:
			return true
	return false

func has_excavation_rig(target_z: int) -> bool:
	# Check layer directly above target_z (z + 1) for excavation rig
	var drill_layer = target_z + 1
	var list = get_buildings_on_layer(drill_layer)
	for b in list:
		if b.data and b.data.unlocks_layer_below and b.is_operational:
			return true
	return false

func spawn_starting_command_center() -> Building:
	if get_building_count(&"command_center") > 0:
		return null
	var cc_res_path = "res://data/buildings/command_center.tres"
	if not ResourceLoader.exists(cc_res_path):
		return null
	var cc_data = load(cc_res_path) as BuildingData
	if not cc_data:
		return null
	# Place at center of z=0
	return place_building(cc_data, Vector2i(-1, -1), 0)

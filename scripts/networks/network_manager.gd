class_name NetworkManager
extends Node2D

@export var power_grid: PowerGrid = null
@export var supply_chain: SupplyChain = null
@export var shaft_elevator: ShaftElevator = null

@export var building_manager: BuildingManager = null
@export var layer_manager: Node = null

var _is_dirty: bool = true

func _ready() -> void:
	if shaft_elevator == null:
		shaft_elevator = get_node_or_null("ShaftElevator")
		if shaft_elevator == null:
			shaft_elevator = ShaftElevator.new()
			shaft_elevator.name = "ShaftElevator"
			add_child(shaft_elevator)
			
	if power_grid == null:
		power_grid = get_node_or_null("PowerGrid")
		if power_grid == null:
			power_grid = PowerGrid.new()
			power_grid.name = "PowerGrid"
			add_child(power_grid)
	power_grid.shaft_elevator = shaft_elevator
	
	if supply_chain == null:
		supply_chain = get_node_or_null("SupplyChain")
		if supply_chain == null:
			supply_chain = SupplyChain.new()
			supply_chain.name = "SupplyChain"
			add_child(supply_chain)
	supply_chain.shaft_elevator = shaft_elevator
	
	_find_dependencies()
	
	if EventBus:
		EventBus.building_placed.connect(_on_building_changed)
		EventBus.building_removed.connect(_on_building_changed)
		if EventBus.has_signal("building_damaged"):
			EventBus.building_damaged.connect(_on_building_damaged)
		if EventBus.has_signal("layer_created"):
			EventBus.layer_created.connect(_on_layer_changed)
		if EventBus.has_signal("layer_removed"):
			EventBus.layer_removed.connect(_on_layer_changed)

func _find_dependencies() -> void:
	if (building_manager == null or not is_instance_valid(building_manager)) and is_inside_tree():
		building_manager = get_tree().root.find_child("BuildingManager", true, false)
	if (layer_manager == null or not is_instance_valid(layer_manager)) and is_inside_tree():
		layer_manager = get_tree().root.find_child("LayerManager", true, false)
		
	if building_manager and is_instance_valid(building_manager):
		if power_grid and power_grid.occupancy == null:
			power_grid.occupancy = building_manager.occupancy
		if supply_chain and supply_chain.occupancy == null:
			supply_chain.occupancy = building_manager.occupancy

func mark_dirty() -> void:
	_is_dirty = true

func _on_building_changed(_b: Node) -> void:
	_is_dirty = true
	recalculate_all()

func _on_layer_changed(_z: int) -> void:
	_is_dirty = true
	recalculate_all()

func _on_building_damaged(_b: Node2D, _amount: int, current_hp: int) -> void:
	_is_dirty = true
	if current_hp <= 0:
		recalculate_all()

func recalculate_all(force: bool = false) -> void:
	if not _is_dirty and not force:
		return
		
	_find_dependencies()
	var all_buildings: Array[Building] = []
	if building_manager:
		all_buildings = building_manager.get_all_buildings()
		
	if power_grid:
		power_grid.recalculate_grid(all_buildings)
	if supply_chain:
		supply_chain.recalculate_chain(all_buildings)
		
	if layer_manager and "layers" in layer_manager:
		var connected_layers: Dictionary = {0: true}
		if shaft_elevator:
			connected_layers = shaft_elevator.get_connected_layers_from_zero(all_buildings)
		for z in layer_manager.layers.keys():
			if not connected_layers.has(z):
				if EventBus and EventBus.has_signal("layer_isolated_warning"):
					EventBus.layer_isolated_warning.emit(z)
					
	_is_dirty = false

func get_power_grid() -> PowerGrid:
	return power_grid

func get_supply_chain() -> SupplyChain:
	return supply_chain

func get_shaft_elevator() -> ShaftElevator:
	return shaft_elevator

func is_layer_connected(z: int) -> bool:
	if z == 0:
		return true
	_find_dependencies()
	var all_buildings: Array[Building] = []
	if building_manager:
		all_buildings = building_manager.get_all_buildings()
	if shaft_elevator:
		return shaft_elevator.is_layer_connected(z, all_buildings)
	return false

func get_interlayer_throughput(z1: int, z2: int) -> int:
	_find_dependencies()
	var all_buildings: Array[Building] = []
	if building_manager:
		all_buildings = building_manager.get_all_buildings()
	if shaft_elevator:
		return shaft_elevator.get_throughput_between(z1, z2, all_buildings)
	return 0

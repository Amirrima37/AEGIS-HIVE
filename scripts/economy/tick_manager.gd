class_name TickManager
extends Node

@export var tick_interval: float = 1.0 # Base seconds per tick
@export var building_manager: BuildingManager = null
@export var network_manager: NetworkManager = null

var _accumulated_time: float = 0.0

func _ready() -> void:
	_find_dependencies()

func _find_dependencies() -> void:
	if (building_manager == null or not is_instance_valid(building_manager)) and is_inside_tree():
		building_manager = get_tree().root.find_child("BuildingManager", true, false)
	if (network_manager == null or not is_instance_valid(network_manager)) and is_inside_tree():
		network_manager = get_tree().root.find_child("NetworkManager", true, false)

func _process(delta: float) -> void:
	if GameState.is_paused or GameState.game_speed <= 0.0:
		return
	
	_accumulated_time += delta * GameState.game_speed
	while _accumulated_time >= tick_interval:
		_accumulated_time -= tick_interval
		run_tick()

func run_tick() -> void:
	_find_dependencies()
	if building_manager == null:
		return
		
	# Phase 0: Recalculate network connectivity if NetworkManager is present
	if network_manager:
		network_manager.recalculate_all()
		
	var all_buildings = building_manager.get_all_buildings()
	
	# Phase 1: ENERGY PRODUCTION (Reactors, Command Center, etc.)
	var total_energy_produced = 0
	for b in all_buildings:
		if not is_instance_valid(b) or b.data == null:
			continue
		if b.data.is_connector:
			continue
		if b.data.energy_production > 0 and b.connected_to_power and b.current_hp > 0:
			total_energy_produced += b.data.energy_production
			if b.data.energy_consumption == 0:
				b.is_operational = true
	
	if total_energy_produced > 0:
		ResourceManager.produce({"energy": total_energy_produced})
	
	# Phase 2: ENERGY CONSUMPTION (Consumers)
	for b in all_buildings:
		if not is_instance_valid(b) or b.data == null:
			continue
		if b.data.is_connector:
			continue
		if b.data.energy_consumption > 0:
			if b.connected_to_power and b.current_hp > 0:
				var need = b.data.energy_consumption
				if ResourceManager.get_resource("energy") >= need:
					ResourceManager.spend({"energy": need})
					b.is_operational = true
				else:
					# Brownout
					b.is_operational = false
			else:
				b.is_operational = false
				
	# Phase 3: ORE PRODUCTION (Quarries, etc.)
	var total_ore_produced = 0
	for b in all_buildings:
		if not is_instance_valid(b) or b.data == null:
			continue
		if b.data.is_connector:
			continue
		if b.data.ore_production > 0:
			if b.connected_to_power and b.connected_to_supply and b.is_operational:
				total_ore_produced += b.data.ore_production
			
	if total_ore_produced > 0:
		ResourceManager.produce({"ore": total_ore_produced})
		
	# Phase 4 & 5: ORE CONSUMPTION & MATERIALS PRODUCTION (Factories)
	for b in all_buildings:
		if not is_instance_valid(b) or b.data == null:
			continue
		if b.data.is_connector:
			continue
		if b.is_operational and b.connected_to_power and b.connected_to_supply:
			var ore_need = b.data.ore_consumption
			var mat_yield = b.data.materials_production
			
			if ore_need > 0:
				if ResourceManager.get_resource("ore") >= ore_need:
					ResourceManager.spend({"ore": ore_need})
					if mat_yield > 0:
						ResourceManager.produce({"materials": mat_yield})
			elif mat_yield > 0:
				ResourceManager.produce({"materials": mat_yield})
				
	# Population capacity recalculation
	var total_pop_cap = 0
	for b in all_buildings:
		if is_instance_valid(b) and b.is_operational and b.connected_to_power and b.data:
			total_pop_cap += b.data.population_capacity
	if total_pop_cap > 0 and ResourceManager.get_resource("population") < total_pop_cap:
		pass
		
	# Tick increment & EventBus broadcast
	GameState.tick_count += 1
	EventBus.tick.emit(GameState.tick_count)

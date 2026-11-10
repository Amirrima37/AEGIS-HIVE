class_name TickManager
extends Node

@export var tick_interval: float = 1.0 # Base seconds per tick
@export var building_manager: BuildingManager = null
@export var network_manager: NetworkManager = null
@export var research_manager: ResearchManager = null
@export var layer_manager: LayerManager = null

var _accumulated_time: float = 0.0

func _ready() -> void:
	_find_dependencies()
	if EventBus.has_signal("building_placed"):
		EventBus.building_placed.connect(_on_building_network_changed)
	if EventBus.has_signal("building_removed"):
		EventBus.building_removed.connect(_on_building_network_changed)
	if EventBus.has_signal("network_updated"):
		EventBus.network_updated.connect(_on_building_network_changed)
	if EventBus.has_signal("combat_power_shift_toggled"):
		EventBus.combat_power_shift_toggled.connect(_on_directive_mode_changed)
	if EventBus.has_signal("aegis_protocol_toggled"):
		EventBus.aegis_protocol_toggled.connect(_on_directive_mode_changed)
	update_population_capacity()

func _on_building_network_changed(_arg1 = null, _arg2 = null) -> void:
	update_population_capacity()

func get_total_population_capacity() -> int:
	_find_dependencies()
	if building_manager == null:
		return ResourceManager.get_resource("population_capacity")
	var all_buildings = building_manager.get_all_buildings()
	var cap = 0
	var is_aegis = GameState and GameState.aegis_protocol_active
	var ds = get_tree().root.find_child("DefenseSystem", true, false) if (is_inside_tree() and is_aegis) else null
	for b in all_buildings:
		if is_instance_valid(b) and b.data and b.data.population_capacity > 0:
			if b.current_hp > 0:
				if b.is_operational and b.connected_to_power:
					cap += b.data.population_capacity
				elif is_aegis and b.data.id == &"habitation_block":
					var protected := false
					if ds:
						if ds.shield_controller and ds.shield_controller.is_position_shielded(b.z_level, b.grid_position):
							protected = true
						elif ds.has_method("is_position_armor_covered") and ds.is_position_armor_covered(b.z_level, b.grid_position):
							protected = true
					if protected:
						cap += b.data.population_capacity
	if cap == 0 and all_buildings.is_empty():
		cap = max(10, ResourceManager.get_resource("population"))
	return cap

func update_population_capacity() -> int:
	var cap = get_total_population_capacity()
	ResourceManager.set_resource("population_capacity", cap)
	return cap

func _find_dependencies() -> void:
	if (building_manager == null or not is_instance_valid(building_manager)) and is_inside_tree():
		building_manager = get_tree().root.find_child("BuildingManager", true, false)
	if (network_manager == null or not is_instance_valid(network_manager)) and is_inside_tree():
		network_manager = get_tree().root.find_child("NetworkManager", true, false)
	if (research_manager == null or not is_instance_valid(research_manager)) and is_inside_tree():
		research_manager = get_tree().root.find_child("ResearchManager", true, false)
	if (layer_manager == null or not is_instance_valid(layer_manager)) and is_inside_tree():
		layer_manager = get_tree().root.find_child("LayerManager", true, false)

func _on_directive_mode_changed(_active: bool) -> void:
	_find_dependencies()
	if building_manager:
		for b in building_manager.get_all_buildings():
			if is_instance_valid(b):
				b.update_operational_state()
	update_population_capacity()

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
			var eff = b.get_efficiency() if b.has_method("get_efficiency") else 1.0
			var prod = int(round(float(b.data.energy_production) * eff))
			if eff > 0.0 and prod == 0:
				prod = 1
			total_energy_produced += prod
			if b.data.energy_consumption == 0:
				b.is_operational = true
	
	if total_energy_produced > 0:
		ResourceManager.produce({"energy": total_energy_produced})
	
	# Phase 2: ENERGY CONSUMPTION (Sorted by dynamic category priority & Combat/Aegis lockdown)
	var consumers: Array[Building] = []
	for b in all_buildings:
		if not is_instance_valid(b) or b.data == null or b.data.is_connector:
			continue
		if GameState and GameState.has_method("is_blocked_by_combat_mode") and GameState.is_blocked_by_combat_mode(b.data):
			b.is_operational = false
			continue
		if b.data.energy_consumption > 0:
			consumers.append(b)
	consumers.sort_custom(func(a, b):
		var pa = GameState.get_effective_power_priority(a.data) if (GameState and GameState.has_method("get_effective_power_priority")) else a.data.power_priority
		var pb = GameState.get_effective_power_priority(b.data) if (GameState and GameState.has_method("get_effective_power_priority")) else b.data.power_priority
		if pa == pb:
			return a.data.energy_consumption < b.data.energy_consumption
		return pa < pb
	)
	
	var total_energy_spent = 0
	var available_energy = ResourceManager.get_resource("energy")
	for b in consumers:
		if b.connected_to_power and b.current_hp > 0:
			var need = b.data.energy_consumption
			if available_energy >= need:
				available_energy -= need
				total_energy_spent += need
				b.is_operational = true
			else:
				# Brownout: низкоприоритетные здания отключаются первыми
				b.is_operational = false
		else:
			b.is_operational = false
				
	if total_energy_spent > 0:
		ResourceManager.spend({"energy": total_energy_spent})
				
	# Phase 3: ORE PRODUCTION (Quarries, etc.)
	var total_ore_produced = 0
	for b in all_buildings:
		if not is_instance_valid(b) or b.data == null:
			continue
		if b.data.is_connector:
			continue
		if GameState and GameState.has_method("is_blocked_by_combat_mode") and GameState.is_blocked_by_combat_mode(b.data):
			continue
		if b.data.ore_production > 0:
			if b.connected_to_power and b.connected_to_supply and b.is_operational and b.current_hp > 0:
				var eff = b.get_efficiency() if b.has_method("get_efficiency") else 1.0
				var yield_ore = int(floor(float(b.data.ore_production) * eff))
				if eff > 0.0 and yield_ore == 0:
					yield_ore = 1
				total_ore_produced += yield_ore
			
	if total_ore_produced > 0:
		ResourceManager.produce({"ore": total_ore_produced})
		
	# Phase 4 & 5: ORE CONSUMPTION & MATERIALS PRODUCTION (Factories)
	var total_ore_spent = 0
	var total_materials_produced = 0
	var available_ore = ResourceManager.get_resource("ore")

	for b in all_buildings:
		if not is_instance_valid(b) or b.data == null:
			continue
		if b.data.is_connector:
			continue
		if GameState and GameState.has_method("is_blocked_by_combat_mode") and GameState.is_blocked_by_combat_mode(b.data):
			continue
		if b.data.materials_production <= 0 and (b.data.defense_role == "munitions" or b.data.id == &"munitions_factory"):
			continue
		if b.is_operational and b.connected_to_power and b.connected_to_supply and b.current_hp > 0:
			var ore_need = b.data.ore_consumption
			var eff = b.get_efficiency() if b.has_method("get_efficiency") else 1.0
			var mat_yield = int(floor(float(b.data.materials_production) * eff))
			if eff > 0.0 and b.data.materials_production > 0 and mat_yield == 0:
				mat_yield = 1
			
			if ore_need > 0:
				if available_ore >= ore_need:
					available_ore -= ore_need
					total_ore_spent += ore_need
					if mat_yield > 0:
						total_materials_produced += mat_yield
			elif mat_yield > 0:
				total_materials_produced += mat_yield

	if total_ore_spent > 0:
		ResourceManager.spend({"ore": total_ore_spent})
	if total_materials_produced > 0:
		ResourceManager.produce({"materials": total_materials_produced})
				
	# Phase 6: Population capacity recalculation and gradual growth (frozen during combat lockdown)
	var total_pop_cap = update_population_capacity()
	var current_pop = ResourceManager.get_resource("population")
	var lockdown = GameState and GameState.has_method("is_combat_mode_active") and GameState.is_combat_mode_active()
	if not lockdown:
		if current_pop < total_pop_cap:
			var diff = total_pop_cap - current_pop
			var growth = 2 if diff >= 10 else 1
			ResourceManager.modify_resource("population", growth)
		elif current_pop > total_pop_cap:
			ResourceManager.modify_resource("population", -1)
	
	# Phase 7: Research progress & structural integrity tick decay
	if research_manager:
		research_manager.advance_tick()
	if layer_manager and layer_manager.has_method("apply_tick_structural_decay"):
		layer_manager.apply_tick_structural_decay()
		
	# Tick increment & EventBus broadcast
	GameState.tick_count += 1
	EventBus.tick.emit(GameState.tick_count)

func get_category_power_summary() -> Dictionary:
	_find_dependencies()
	var summary := {
		"defense": 0,
		"life_support": 0,
		"logistics": 0,
		"industry": 0
	}
	if building_manager == null or not GameState or not GameState.has_method("get_building_power_category"):
		return summary
	for b in building_manager.get_all_buildings():
		if not is_instance_valid(b) or b.data == null or b.data.energy_consumption <= 0 or b.current_hp <= 0:
			continue
		var cat = GameState.get_building_power_category(b.data)
		summary[cat] = int(summary.get(cat, 0)) + b.data.energy_consumption
	return summary

func get_sheltered_population_stats() -> Dictionary:
	_find_dependencies()
	var total_pop = ResourceManager.get_resource("population")
	var cc_bunker_cap = 0
	var protected_hab_cap = 0
	var ds = get_tree().root.find_child("DefenseSystem", true, false) if is_inside_tree() else null
	if building_manager:
		for b in building_manager.get_all_buildings():
			if not is_instance_valid(b) or b.data == null or b.current_hp <= 0:
				continue
			if b.data.id == &"command_center":
				cc_bunker_cap += b.data.population_capacity
			elif b.data.id == &"habitation_block":
				var protected := false
				if ds:
					if ds.shield_controller and ds.shield_controller.is_position_shielded(b.z_level, b.grid_position):
						protected = true
					elif ds.has_method("is_position_armor_covered") and ds.is_position_armor_covered(b.z_level, b.grid_position):
						protected = true
				if protected:
					protected_hab_cap += b.data.population_capacity
	var sheltered := 0
	if GameState and GameState.aegis_protocol_active:
		sheltered = min(total_pop, cc_bunker_cap + protected_hab_cap)
	return {
		"total": total_pop,
		"sheltered": sheltered,
		"bunker_capacity": cc_bunker_cap + protected_hab_cap
	}

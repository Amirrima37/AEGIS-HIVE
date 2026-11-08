class_name RepairDepot
extends Node

signal building_repaired(building: Building, amount: int)

var building_manager: BuildingManager = null
var default_repair_rate: float = 50.0 # HP в секунду

var _scan_timer: float = 0.0
const SCAN_INTERVAL: float = 0.5

func _init(p_building_manager: BuildingManager = null) -> void:
	building_manager = p_building_manager

func _get_building_manager() -> BuildingManager:
	if building_manager and is_instance_valid(building_manager):
		return building_manager
	if is_inside_tree():
		building_manager = get_tree().root.find_child("BuildingManager", true, false)
		return building_manager
	return null

func _process(delta: float) -> void:
	_scan_timer += delta
	if _scan_timer >= SCAN_INTERVAL:
		run(_scan_timer)
		_scan_timer = 0.0

## Выполнить цикл сканирования и ремонта поврежденных объектов
func run(delta: float = SCAN_INTERVAL) -> int:
	var bm = _get_building_manager()
	if bm == null:
		return 0
		
	var depots = get_all_depots()
	var total_healed = 0
	
	for depot in depots:
		if not is_instance_valid(depot) or depot.data == null or depot.current_hp <= 0:
			continue
		if not depot.connected_to_power:
			continue
			
		var range_tiles = depot.data.repair_range if depot.data.repair_range > 0.0 else 8.0
		var rate = depot.data.repair_rate if depot.data.repair_rate > 0.0 else default_repair_rate
		var max_heal_tick = int(ceil(rate * delta))
		
		# Найти наиболее поврежденное здание на этом же ярусе в радиусе действия
		var target = _find_most_damaged_in_range(depot, range_tiles)
		if target != null:
			var missing_hp = target.data.max_hp - target.current_hp
			var heal_amount = min(missing_hp, max_heal_tick)
			
			# Требуются материалы для ремонта (1 единица материалов на каждые 25 HP)
			var mat_needed = max(1, int(ceil(heal_amount / 25.0)))
			if ResourceManager.can_afford({"materials": mat_needed}):
				ResourceManager.spend({"materials": mat_needed})
				target.current_hp += heal_amount
				target.update_operational_state()
				total_healed += heal_amount
				
				building_repaired.emit(target, heal_amount)
				if EventBus and EventBus.has_signal("building_repaired"):
					EventBus.building_repaired.emit(target, heal_amount)
					
	return total_healed

func get_all_depots() -> Array[Building]:
	var result: Array[Building] = []
	var bm = _get_building_manager()
	if bm == null:
		return result
	for b in bm.get_all_buildings():
		if not is_instance_valid(b) or b.data == null:
			continue
		if b.data.defense_role == "repair" or b.data.id == &"repair_depot":
			result.append(b)
	return result

func _find_most_damaged_in_range(depot: Building, range_tiles: float) -> Building:
	var depot_pos = Vector2(depot.grid_position)
	var best_building: Building = null
	var lowest_hp_ratio = 1.0
	
	var bm = _get_building_manager()
	if bm == null:
		return null
		
	for b in bm.get_buildings_on_layer(depot.z_level):
		if not is_instance_valid(b) or b.data == null:
			continue
		if b.current_hp >= b.data.max_hp:
			continue # Не повреждено
			
		var b_pos = Vector2(b.grid_position)
		if depot_pos.distance_to(b_pos) <= range_tiles:
			var ratio = float(b.current_hp) / float(b.data.max_hp)
			if ratio < lowest_hp_ratio:
				lowest_hp_ratio = ratio
				best_building = b
				
	return best_building

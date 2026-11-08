class_name TestDefenseSystem
extends RefCounted

static func run_all_tests(main_node: Node) -> void:
	print("--- НАЧАЛО ТЕСТИРОВАНИЯ ЭТАПА 3: ОБОРОНИТЕЛЬНЫЕ СИСТЕМЫ ---")
	
	var building_mgr: BuildingManager = main_node.find_child("BuildingManager", true, false)
	assert(building_mgr != null, "BuildingManager not found!")
	var network_mgr: NetworkManager = main_node.find_child("NetworkManager", true, false)
	assert(network_mgr != null, "NetworkManager not found!")
	var defense_sys: DefenseSystem = main_node.find_child("DefenseSystem", true, false)
	assert(defense_sys != null, "DefenseSystem not found!")
	var occupancy: OccupancyGrid = building_mgr.occupancy
	assert(occupancy != null, "OccupancyGrid not found!")
	
	# Load building data resources
	var wall_data = load("res://data/buildings/defense_wall.tres") as BuildingData
	assert(wall_data != null, "Failed to load defense_wall.tres")
	var turret_data = load("res://data/buildings/autocannon_turret.tres") as BuildingData
	assert(turret_data != null, "Failed to load autocannon_turret.tres")
	var railgun_data = load("res://data/buildings/heavy_railgun.tres") as BuildingData
	assert(railgun_data != null, "Failed to load heavy_railgun.tres")
	var shield_data = load("res://data/buildings/shield_generator.tres") as BuildingData
	assert(shield_data != null, "Failed to load shield_generator.tres")
	var munitions_data = load("res://data/buildings/munitions_factory.tres") as BuildingData
	assert(munitions_data != null, "Failed to load munitions_factory.tres")
	var sensor_data = load("res://data/buildings/sensor_tower.tres") as BuildingData
	assert(sensor_data != null, "Failed to load sensor_tower.tres")
	var repair_data = load("res://data/buildings/repair_depot.tres") as BuildingData
	assert(repair_data != null, "Failed to load repair_depot.tres")
	
	# Replenish resources for testing
	ResourceManager.set_resource("ore", 5000)
	ResourceManager.set_resource("materials", 5000)
	
	# -------------------------------------------------------------
	# T3.1: test_wall_blocks_pathfinding
	# -------------------------------------------------------------
	var wall_pos = Vector2i(5, 5)
	var wall_b = building_mgr.place_building(wall_data, wall_pos, 0)
	assert(wall_b != null, "T3.1: Wall placement failed")
	assert(wall_b is WallNode, "T3.1: Wall building must be instance of WallNode")
	assert(occupancy.is_blocked(0, wall_pos) == true, "T3.1: Wall position must be blocked in OccupancyGrid")
	
	# Path straight through wall from (4, 5) to (6, 5)
	var path_around = occupancy.find_path(0, Vector2i(4, 5), Vector2i(6, 5))
	assert(path_around.size() > 0, "T3.1: Path around single wall should exist")
	assert(not path_around.has(wall_pos), "T3.1: Path must not traverse the blocked wall tile (5, 5)")
	
	# Wall destruction test
	var wall_destroyed_emitted = [false]
	var on_wall_destroyed = func(w):
		if w == wall_b:
			wall_destroyed_emitted[0] = true
	EventBus.wall_destroyed.connect(on_wall_destroyed)
	
	wall_b.take_damage(5000)
	assert(wall_b.current_hp == 0, "T3.1: Wall HP must be 0 after lethal damage")
	assert(wall_destroyed_emitted[0] == true, "T3.1: EventBus.wall_destroyed signal was not emitted")
	assert(occupancy.is_blocked(0, wall_pos) == false, "T3.1: Destroyed wall must no longer block pathfinding")
	EventBus.wall_destroyed.disconnect(on_wall_destroyed)
	building_mgr.remove_building(wall_b)
	print("[OK] T3.1: test_wall_blocks_pathfinding пройден (стены блокируют путь юнитов и освобождают при разрушении)")
	
	# -------------------------------------------------------------
	# T3.2: test_turret_fires_at_nearest_enemy
	# -------------------------------------------------------------
	var turret_b = building_mgr.place_building(turret_data, Vector2i(8, 8), 0)
	assert(turret_b != null, "T3.2: Turret placement failed")
	turret_b.connected_to_power = true
	
	var ammo_sys = defense_sys.ammo_supply
	var turret_mgr = defense_sys.turret_manager
	ammo_sys.reset()
	ammo_sys.produce(10)
	
	# Mock enemy targets
	var enemy1 = {"grid_position": Vector2i(10, 8), "z_level": 0, "hp": 200, "current_hp": 200}
	var enemy2 = {"grid_position": Vector2i(14, 8), "z_level": 0, "hp": 200, "current_hp": 200}
	var targets = [enemy2, enemy1] # enemy1 is nearer (dist 2) vs enemy2 (dist 6)
	
	var nearest = turret_mgr.find_nearest_target(turret_b, targets)
	assert(nearest == enemy1, "T3.2: Turret must prioritize nearest target in range")
	
	var fired_signal_emitted = [false]
	var on_turret_fired = func(t, target):
		if t == turret_b and target == enemy1:
			fired_signal_emitted[0] = true
	EventBus.turret_fired.connect(on_turret_fired)
	
	var fired = turret_mgr.fire(turret_b, enemy1)
	assert(fired == true, "T3.2: Turret fire failed")
	assert(fired_signal_emitted[0] == true, "T3.2: EventBus.turret_fired signal not emitted")
	assert(ammo_sys.ammo_stock == 9, "T3.2: Firing autocannon must consume 1 ammo, got %d" % ammo_sys.ammo_stock)
	assert(enemy1.hp == 200 - 120, "T3.2: Enemy must take 120 damage, got %d" % enemy1.hp)
	EventBus.turret_fired.disconnect(on_turret_fired)
	
	# Test turret without ammo cannot fire
	ammo_sys.reset()
	turret_mgr._cooldowns.erase(turret_b) # clear cooldown
	assert(turret_mgr.can_fire(turret_b) == false, "T3.2: Turret without ammo must not be able to fire")
	assert(turret_mgr.fire(turret_b, enemy1) == false, "T3.2: Turret fire without ammo must fail")
	building_mgr.remove_building(turret_b)
	print("[OK] T3.2: test_turret_fires_at_nearest_enemy пройден (захват ближайшей цели, расход патронов, урон)")
	
	# -------------------------------------------------------------
	# T3.3: test_shield_energy_drain
	# -------------------------------------------------------------
	var shield_b = building_mgr.place_building(shield_data, Vector2i(10, 10), 0)
	assert(shield_b != null, "T3.3: Shield generator placement failed")
	shield_b.connected_to_power = true
	
	var shield_ctrl = defense_sys.shield_controller
	shield_ctrl.activate()
	assert(shield_ctrl.is_active == true, "T3.3: Shield controller must be active")
	assert(shield_ctrl.is_position_shielded(0, Vector2i(11, 11)) == true, "T3.3: (11,11) must be shielded within radius 6")
	assert(shield_ctrl.is_position_shielded(0, Vector2i(25, 25)) == false, "T3.3: (25,25) must be outside shield radius")
	
	# Incoming damage inside shield dome is absorbed
	var remaining_dmg = shield_ctrl.absorb_damage(0, Vector2i(11, 11), 100)
	assert(remaining_dmg == 0, "T3.3: Shield must absorb all damage within dome radius, got %d" % remaining_dmg)
	
	# When shield generator loses power or is removed
	shield_b.connected_to_power = false
	var depleted_emitted = [false]
	var on_depleted = func(): depleted_emitted[0] = true
	EventBus.shield_depleted.connect(on_depleted)
	
	var unabsorbed_dmg = shield_ctrl.absorb_damage(0, Vector2i(11, 11), 100)
	assert(unabsorbed_dmg == 100, "T3.3: Unpowered shield must not absorb damage")
	assert(depleted_emitted[0] == true, "T3.3: EventBus.shield_depleted must be emitted when shields fail")
	EventBus.shield_depleted.disconnect(on_depleted)
	building_mgr.remove_building(shield_b)
	shield_ctrl.deactivate()
	print("[OK] T3.3: test_shield_energy_drain пройден (купол щита поглощает урон и сигнализирует при обесточивании)")
	
	# -------------------------------------------------------------
	# T3.4: test_ammo_production_and_consumption
	# -------------------------------------------------------------
	var mun_b = building_mgr.place_building(munitions_data, Vector2i(14, 14), 0)
	assert(mun_b != null, "T3.4: Munitions factory placement failed")
	mun_b.connected_to_power = true
	
	ResourceManager.set_resource("ore", 100)
	ResourceManager.set_resource("materials", 100)
	ammo_sys.reset()
	assert(ammo_sys.ammo_stock == 0, "T3.4: Ammo stock must start at 0")
	
	var produced = ammo_sys.process_factories()
	assert(produced == 30, "T3.4: Munitions factory must produce 30 ammo, got %d" % produced)
	assert(ammo_sys.ammo_stock == 30, "T3.4: Ammo stock must be 30, got %d" % ammo_sys.ammo_stock)
	assert(ResourceManager.get_resource("ore") == 100 - 2, "T3.4: Ore must decrease by 2")
	assert(ResourceManager.get_resource("materials") == 100 - 1, "T3.4: Materials must decrease by 1")
	
	var consumed = ammo_sys.consume(15)
	assert(consumed == true, "T3.4: Consuming 15 ammo must succeed")
	assert(ammo_sys.ammo_stock == 15, "T3.4: Remaining ammo must be 15, got %d" % ammo_sys.ammo_stock)
	building_mgr.remove_building(mun_b)
	print("[OK] T3.4: test_ammo_production_and_consumption пройден (производство патронов на фабриках и расход)")
	
	# -------------------------------------------------------------
	# T3.5: test_repair_depot_heals_buildings
	# -------------------------------------------------------------
	var repair_b = building_mgr.place_building(repair_data, Vector2i(18, 18), 0)
	assert(repair_b != null, "T3.5: Repair depot placement failed")
	
	# Place damaged building within repair range (dist 2)
	var hab_data = load("res://data/buildings/habitation_block.tres") as BuildingData
	var damaged_hab = building_mgr.place_building(hab_data, Vector2i(20, 18), 0)
	assert(damaged_hab != null, "T3.5: Habitation block placement failed")
	repair_b.connected_to_power = true
	damaged_hab.take_damage(50)
	assert(damaged_hab.current_hp == damaged_hab.data.max_hp - 50, "T3.5: Hab HP must be 50 below max")
	
	ResourceManager.set_resource("materials", 50)
	var repaired_signal_emitted = [false]
	var on_repaired = func(b, amt):
		if b == damaged_hab:
			repaired_signal_emitted[0] = true
	EventBus.building_repaired.connect(on_repaired)
	
	var repair_sys = defense_sys.repair_depot
	var healed = repair_sys.run(1.0) # 1 sec tick = 50 HP repaired
	assert(healed == 50, "T3.5: Repair depot must restore 50 HP in 1 second, got %d" % healed)
	assert(damaged_hab.current_hp == damaged_hab.data.max_hp, "T3.5: Hab must be fully repaired to max HP")
	assert(repaired_signal_emitted[0] == true, "T3.5: EventBus.building_repaired must be emitted")
	assert(ResourceManager.get_resource("materials") < 50, "T3.5: Materials must be consumed for repairs")
	EventBus.building_repaired.disconnect(on_repaired)
	
	building_mgr.remove_building(damaged_hab)
	building_mgr.remove_building(repair_b)
	print("[OK] T3.5: test_repair_depot_heals_buildings пройден (ремонтные дроны восстанавливают повреждения за материалы)")
	
	# -------------------------------------------------------------
	# T3.6: test_defense_toolbar_buttons
	# -------------------------------------------------------------
	var toolbar: BuildToolbar = main_node.find_child("BuildToolbar", true, false)
	if toolbar:
		for path in [
			"res://data/buildings/defense_wall.tres",
			"res://data/buildings/autocannon_turret.tres",
			"res://data/buildings/heavy_railgun.tres",
			"res://data/buildings/shield_generator.tres",
			"res://data/buildings/munitions_factory.tres",
			"res://data/buildings/sensor_tower.tres",
			"res://data/buildings/repair_depot.tres"
		]:
			var res = load(path) as BuildingData
			assert(toolbar._building_buttons.has(res), "T3.6: BuildToolbar must have button for %s" % res.id)
		print("[OK] T3.6: test_defense_toolbar_buttons пройден (все 7 оборонительных зданий интегрированы в панель строительства)")
	
	print("--- ВСЕ ТЕСТЫ ЭТАПА 3 УСПЕШНО ПРОЙДЕНЫ ---")

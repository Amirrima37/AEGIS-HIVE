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
	var armor_deck_data = load("res://data/buildings/armor_deck.tres") as BuildingData
	assert(armor_deck_data != null, "Failed to load armor_deck.tres")
	var hab_data = load("res://data/buildings/habitation_block.tres") as BuildingData
	assert(hab_data != null, "Failed to load habitation_block.tres")
	var quarry_data = load("res://data/buildings/quarry.tres") as BuildingData
	assert(quarry_data != null, "Failed to load quarry.tres")
	var factory_data = load("res://data/buildings/factory.tres") as BuildingData
	assert(factory_data != null, "Failed to load factory.tres")
	var pillar_data = load("res://data/buildings/support_pillar.tres") as BuildingData
	assert(pillar_data != null, "Failed to load support_pillar.tres")
	
	var layer_mgr: LayerManager = main_node.find_child("LayerManager", true, false)
	var tick_mgr: TickManager = main_node.find_child("TickManager", true, false)
	var research_mgr: ResearchManager = main_node.find_child("ResearchManager", true, false)
	assert(layer_mgr != null and tick_mgr != null and research_mgr != null, "Core Stage 3 test managers missing!")
	
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
	mun_b.connected_to_supply = false
	
	ResourceManager.set_resource("ore", 100)
	ResourceManager.set_resource("materials", 100)
	ammo_sys.reset()
	assert(ammo_sys.ammo_stock == 0, "T3.4: Ammo stock must start at 0")
	
	# Unsupplied factory must produce 0
	var produced_unsupplied = ammo_sys.process_factories()
	assert(produced_unsupplied == 0, "T3.4: Unsupplied munitions factory must produce 0 ammo")
	
	# Now supply logistics
	mun_b.connected_to_supply = true
	var produced = ammo_sys.process_factories()
	assert(produced == 30, "T3.4: Munitions factory must produce 30 ammo, got %d" % produced)
	assert(ammo_sys.ammo_stock == 30, "T3.4: Ammo stock must be 30, got %d" % ammo_sys.ammo_stock)
	assert(ResourceManager.get_resource("ore") == 100 - 2, "T3.4: Ore must decrease by 2")
	assert(ResourceManager.get_resource("materials") == 100 - 1, "T3.4: Materials must decrease by 1")
	
	var consumed = ammo_sys.consume(15)
	assert(consumed == true, "T3.4: Consuming 15 ammo must succeed")
	assert(ammo_sys.ammo_stock == 15, "T3.4: Remaining ammo must be 15, got %d" % ammo_sys.ammo_stock)
	building_mgr.remove_building(mun_b)
	print("[OK] T3.4: test_ammo_production_and_consumption пройден (логистика + производство патронов и расход)")
	
	# -------------------------------------------------------------
	# T3.5: test_repair_depot_heals_buildings
	# -------------------------------------------------------------
	var repair_b = building_mgr.place_building(repair_data, Vector2i(18, 18), 0)
	assert(repair_b != null, "T3.5: Repair depot placement failed")
	
	# Place damaged building within repair range (dist 2)
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
			"res://data/buildings/armor_deck.tres",
			"res://data/buildings/autocannon_turret.tres",
			"res://data/buildings/heavy_railgun.tres",
			"res://data/buildings/shield_generator.tres",
			"res://data/buildings/munitions_factory.tres",
			"res://data/buildings/sensor_tower.tres",
			"res://data/buildings/repair_depot.tres"
		]:
			var res = load(path) as BuildingData
			assert(toolbar._building_buttons.has(res), "T3.6: BuildToolbar must have button for %s" % res.id)
		print("[OK] T3.6: test_defense_toolbar_buttons пройден (все 8 оборонительных зданий интегрированы в панель строительства)")
	
	# -------------------------------------------------------------
	# T3.7: test_ammo_sync_with_resource_manager_and_unlimited_mode
	# -------------------------------------------------------------
	ammo_sys.reset()
	assert(ResourceManager.get_resource("ammo") == 0, "T3.7: ResourceManager['ammo'] must sync on reset")
	ammo_sys.produce(42)
	assert(ResourceManager.get_resource("ammo") == 42, "T3.7: ResourceManager['ammo'] must reflect produce(42)")
	ammo_sys.reset()
	GameState.set_game_mode(GameState.GameMode.UNLIMITED)
	assert(ammo_sys.has_ammo(999) == true, "T3.7: Unlimited mode must bypass ammo check")
	assert(ammo_sys.consume(10) == true, "T3.7: Unlimited mode consume must succeed at 0 stock")
	GameState.set_game_mode(GameState.GameMode.STANDARD)
	print("[OK] T3.7: test_ammo_sync_with_resource_manager_and_unlimited_mode пройден")
	
	# -------------------------------------------------------------
	# T3.8: test_pause_speed_and_ruins_in_defense_subsystems
	# -------------------------------------------------------------
	var t38_turret = building_mgr.place_building(turret_data, Vector2i(8, 8), 0)
	var t38_repair = building_mgr.place_building(repair_data, Vector2i(10, 8), 0)
	var t38_ruin_wall = building_mgr.place_building(wall_data, Vector2i(12, 8), 0)
	assert(t38_turret != null and t38_repair != null and t38_ruin_wall != null, "T3.8: Test buildings placement failed")
	t38_turret.connected_to_power = true
	t38_repair.connected_to_power = true
	# Ruin the wall completely (0 HP -> ruins cannot be auto-healed!)
	t38_ruin_wall.take_damage(t38_ruin_wall.data.max_hp)
	assert(t38_ruin_wall.current_hp == 0, "T3.8: Ruined wall HP must be 0")
	ResourceManager.set_resource("materials", 200)
	assert(repair_sys.run(1.0) == 0, "T3.8: RepairDepot must ignore 0 HP ruins")
	
	# Unoperational turret must NOT fire; unoperational repair depot must NOT heal
	t38_turret.connected_to_power = false
	ammo_sys.produce(5)
	var dummy_enemy = {"grid_position": Vector2i(9, 8), "z_level": 0, "hp": 500, "current_hp": 500}
	assert(turret_mgr.can_fire(t38_turret) == false, "T3.8: Unpowered turret must not fire")
	t38_turret.connected_to_power = true
	assert(turret_mgr.fire(t38_turret, dummy_enemy) == true, "T3.8: Powered turret must fire")
	
	# Pause must freeze cooldown countdown
	var cd_before = turret_mgr._cooldowns.get(t38_turret, 0.0)
	assert(cd_before > 0.0, "T3.8: Turret must have active cooldown after firing")
	GameState.is_paused = true
	turret_mgr._process(0.5)
	assert(abs(turret_mgr._cooldowns.get(t38_turret, 0.0) - cd_before) < 0.001, "T3.8: Paused TurretManager must freeze cooldown")
	GameState.is_paused = false
	GameState.game_speed = 2.0
	turret_mgr._process(0.1)
	assert(turret_mgr._cooldowns.get(t38_turret, 0.0) < cd_before - 0.15, "T3.8: Speed 2x must tick cooldown twice as fast")
	GameState.game_speed = 1.0
	
	t38_repair.connected_to_power = false
	var t38_damaged_hab = building_mgr.place_building(hab_data, Vector2i(10, 10), 0)
	assert(t38_damaged_hab != null, "T3.8: Damaged hab placement failed")
	t38_damaged_hab.take_damage(40)
	assert(repair_sys.run(1.0) == 0, "T3.8: Unoperational RepairDepot must not heal")
	
	ammo_sys.reset()
	turret_mgr._cooldowns.clear()
	building_mgr.remove_building(t38_damaged_hab)
	building_mgr.remove_building(t38_ruin_wall)
	building_mgr.remove_building(t38_repair)
	building_mgr.remove_building(t38_turret)
	print("[OK] T3.8: test_pause_speed_and_ruins_in_defense_subsystems пройден")
	
	# -------------------------------------------------------------
	# T3.9: test_inductive_structural_integrity_and_cascade_damage
	# -------------------------------------------------------------
	GameState.set_game_mode(GameState.GameMode.STANDARD)
	for b in building_mgr.get_all_buildings():
		if b.data and b.data.id != &"command_center":
			building_mgr.remove_building(b)
	ResourceManager.set_resource("ore", 5000)
	ResourceManager.set_resource("materials", 5000)
	ResourceManager.set_resource("energy", 5000)
	
	var t39_pillar0 = building_mgr.place_building(pillar_data, Vector2i(0, 2), 0)
	assert(t39_pillar0 != null, "T3.9: Pillar on z=0 failed")
	layer_mgr.create_layer(1)
	var t39_pillar1 = building_mgr.place_building(pillar_data, Vector2i(0, 2), 1)
	assert(t39_pillar1 != null, "T3.9: Pillar on z=1 failed")
	layer_mgr.create_layer(2)
	var t39_hab_z1 = building_mgr.place_building(hab_data, Vector2i(1, 2), 1)
	var t39_hab_z2 = building_mgr.place_building(hab_data, Vector2i(1, 2), 2)
	assert(t39_hab_z1 != null and t39_hab_z2 != null, "T3.9: Upper habs failed")
	assert(layer_mgr.is_layer_structurally_sound(1) == true and layer_mgr.is_layer_structurally_sound(2) == true, "T3.9: Supported layers +1 & +2 must be sound")
	
	var comp_list := []
	var cascade_layers := []
	var on_comp = func(z_lvl, _r): comp_list.append(z_lvl)
	var on_casc = func(z_lvl, _d, _c): cascade_layers.append(z_lvl)
	EventBus.layer_integrity_compromised.connect(on_comp)
	EventBus.layer_cascade_damage.connect(on_casc)
	
	var hp1_before = t39_hab_z1.current_hp
	var hp2_before = t39_hab_z2.current_hp
	# Destroy base pillar on z=0 -> BOTH z=1 and z=2 must be compromised inductively and take cascade damage!
	t39_pillar0.take_damage(t39_pillar0.data.max_hp)
	assert(comp_list.has(1) and comp_list.has(2), "T3.9: Both z=1 and z=2 must be compromised inductively when z=0 pillar fails")
	assert(cascade_layers.has(1) and cascade_layers.has(2), "T3.9: Cascade damage must hit both z=1 and z=2")
	assert(t39_hab_z1.current_hp < hp1_before and t39_hab_z2.current_hp < hp2_before, "T3.9: Upper buildings must lose ~35% HP on pillar collapse")
	
	EventBus.layer_integrity_compromised.disconnect(on_comp)
	EventBus.layer_cascade_damage.disconnect(on_casc)
	building_mgr.remove_building(t39_hab_z2)
	building_mgr.remove_building(t39_hab_z1)
	building_mgr.remove_building(t39_pillar1)
	building_mgr.remove_building(t39_pillar0)
	layer_mgr.remove_layer(2)
	print("[OK] T3.9: test_inductive_structural_integrity_and_cascade_damage пройден")
	
	# -------------------------------------------------------------
	# T3.10: test_combat_power_shift_and_research_gated_aegis_protocol
	# -------------------------------------------------------------
	GameState.reset_directives_and_research()
	var t310_quarry = building_mgr.place_building(quarry_data, Vector2i(-3, 0), 0)
	var t310_hab = building_mgr.place_building(hab_data, Vector2i(2, 0), 0)
	var t310_shield = building_mgr.place_building(shield_data, Vector2i(0, 2), 0)
	assert(t310_quarry != null and t310_hab != null and t310_shield != null, "T3.10: Placement failed")
	network_mgr.recalculate_all()
	assert(t310_quarry.is_operational == true and t310_hab.is_operational == true, "T3.10: Civilian/mining must operate initially")
	
	# 1) Immediate Combat Power Shift (NO research required)
	GameState.set_combat_power_shift(true)
	assert(t310_quarry.is_operational == false and t310_hab.is_operational == false, "T3.10: Combat power shift must immediately shut down industry & habitation")
	assert(shield_ctrl.is_active == false, "T3.10: Combat power shift alone does NOT activate Aegis shields")
	
	# 2) Aegis Protocol MUST remain blocked before Research completion
	assert(GameState.set_aegis_protocol(true) == false, "T3.10: Aegis Protocol must fail before research")
	assert(GameState.aegis_protocol_active == false, "T3.10: Aegis cannot become active while locked")
	
	# 3) Research &"aegis_protocol" via ResearchManager + TickManager ticks
	ResourceManager.set_resource("ore", 500)
	ResourceManager.set_resource("materials", 500)
	assert(research_mgr.start_research(&"aegis_protocol") == true, "T3.10: Starting Aegis research must succeed")
	for _i in range(8):
		tick_mgr.run_tick()
	assert(GameState.is_tech_unlocked(&"aegis_protocol") == true, "T3.10: Aegis tech must unlock after 8 ticks")
	assert(GameState.aegis_protocol_unlocked == true, "T3.10: aegis_protocol_unlocked flag must flip true")
	
	# 4) Activate Aegis -> shield dome forces active and remains active even after enemy_wave_ended!
	assert(GameState.set_aegis_protocol(true) == true, "T3.10: Aegis must activate once unlocked")
	assert(shield_ctrl.is_active == true, "T3.10: Active Aegis must force ShieldController active")
	EventBus.enemy_wave_ended.emit(1)
	assert(shield_ctrl.is_active == true, "T3.10: Shield must remain forced ready after wave ends under Aegis")
	var shelter_stats = tick_mgr.get_sheltered_population_stats()
	assert(int(shelter_stats["bunker_capacity"]) >= 70, "T3.10: Covered hab + CC bunker must sum capacity >= 70, got %d" % int(shelter_stats["bunker_capacity"]))
	
	GameState.reset_directives_and_research()
	shield_ctrl.deactivate()
	building_mgr.remove_building(t310_shield)
	building_mgr.remove_building(t310_hab)
	building_mgr.remove_building(t310_quarry)
	print("[OK] T3.10: test_combat_power_shift_and_research_gated_aegis_protocol пройден")
	
	# -------------------------------------------------------------
	# T3.11: test_dynamic_power_priorities
	# -------------------------------------------------------------
	GameState.reset_directives_and_research()
	# Set user custom ranking: industry (#1) BEFORE life_support (#2) BEFORE defense (#3)!
	GameState.set_power_category_order(["industry", "life_support", "defense", "logistics"])
	var t311_quarry = building_mgr.place_building(quarry_data, Vector2i(-3, 0), 0) # industry, -3 MW (touches CC)
	var t311_hab = building_mgr.place_building(hab_data, Vector2i(2, 0), 0) # life_support, -2 MW (touches CC)
	var t311_shield = building_mgr.place_building(shield_data, Vector2i(0, 2), 0) # defense, -6 MW (touches CC)
	assert(t311_quarry != null and t311_hab != null and t311_shield != null, "T3.11: Placement failed")
	# Total demand = 3 + 2 + 6 = 11 MW, CC produces +10 MW
	ResourceManager.set_resource("energy", 0)
	network_mgr.recalculate_all()
	tick_mgr.run_tick()
	# Because industry is #1 (3 MW) and life_support is #2 (2 MW) = 5 MW, remaining = 5 MW (< 6 MW for defense!), defense browns out!
	assert(t311_quarry.is_operational == true, "T3.11: Rank #1 industry must retain power in brownout")
	assert(t311_hab.is_operational == true, "T3.11: Rank #2 life_support must retain power in brownout")
	assert(t311_shield.is_operational == false, "T3.11: Lower ranked defense must brown out during deficit")
	
	building_mgr.remove_building(t311_shield)
	building_mgr.remove_building(t311_hab)
	building_mgr.remove_building(t311_quarry)
	GameState.reset_directives_and_research()
	print("[OK] T3.11: test_dynamic_power_priorities пройден (пользовательские приоритеты определяют порядок отключения)")
	
	# -------------------------------------------------------------
	# T3.12: test_armor_deck_above_only_and_overhead_protection
	# -------------------------------------------------------------
	GameState.set_game_mode(GameState.GameMode.STANDARD)
	ResourceManager.set_resource("ore", 1000)
	ResourceManager.set_resource("materials", 1000)
	var t312_fail_z0 = building_mgr.place_building(armor_deck_data, Vector2i(6, 6), 0)
	assert(t312_fail_z0 == null, "T3.12: ArmorDeck must be rejected on z=0 (above_only)")
	var t312_fail_zm1 = building_mgr.place_building(armor_deck_data, Vector2i(6, 6), -1)
	assert(t312_fail_zm1 == null, "T3.12: ArmorDeck must be rejected on z=-1 (above_only)")
	
	layer_mgr.create_layer(1)
	var t312_pillar = building_mgr.place_building(pillar_data, Vector2i(0, 2), 0)
	var t312_deck = building_mgr.place_building(armor_deck_data, Vector2i(2, 2), 1)
	assert(t312_deck != null, "T3.12: ArmorDeck placement on z=+1 must succeed")
	assert(defense_sys.is_position_armor_covered(0, Vector2i(2, 2)) == true, "T3.12: z=0 cell (2,2) must be armor-covered by deck on z=+1")
	assert(defense_sys.is_position_armor_covered(0, Vector2i(9, 9)) == false, "T3.12: Uncovered cell must return false")
	
	var deck_hp_before = t312_deck.current_hp
	var passthrough = defense_sys.absorb_overhead_damage(0, Vector2i(2, 2), 500)
	assert(passthrough == 0, "T3.12: ArmorDeck must absorb full 500 overhead damage")
	assert(t312_deck.current_hp == deck_hp_before - 500, "T3.12: ArmorDeck HP must decrease by absorbed damage")
	building_mgr.remove_building(t312_deck)
	building_mgr.remove_building(t312_pillar)
	print("[OK] T3.12: test_armor_deck_above_only_and_overhead_protection пройден")
	
	# -------------------------------------------------------------
	# T3.13: test_damage_efficiency_degradation_ruins_and_refund
	# -------------------------------------------------------------
	ResourceManager.set_resource("ore", 1000)
	ResourceManager.set_resource("materials", 1000)
	ResourceManager.set_resource("energy", 500)
	var t313_quarry = building_mgr.place_building(quarry_data, Vector2i(-3, 0), 0)
	assert(t313_quarry != null, "T3.13: Quarry placement failed")
	network_mgr.recalculate_all()
	assert(abs(t313_quarry.get_efficiency() - 1.0) < 0.001, "T3.13: Intact quarry efficiency must be 1.0")
	assert(t313_quarry.damage_overlay_node.visible == false, "T3.13: Intact quarry DamageOverlay must be hidden")
	assert(t313_quarry.sprite_node.modulate == Color(1.0, 1.0, 1.0, 1.0), "T3.13: Intact quarry modulate must be white")
	assert(int(t313_quarry.get_refund()["ore"]) == int(quarry_data.cost_ore * 0.5), "T3.13: Intact refund must be 50%")
	
	# Drop quarry to 25% HP -> efficiency < 1.0, output reduced on tick!
	t313_quarry.take_damage(int(quarry_data.max_hp * 0.75))
	assert(t313_quarry.get_efficiency() < 0.75 and t313_quarry.get_efficiency() >= 0.4, "T3.13: Heavily damaged efficiency must scale down cleanly")
	assert(t313_quarry.damage_overlay_node.visible == true, "T3.13: Damaged DamageOverlay must become visible <50% HP")
	ResourceManager.set_resource("ore", 100)
	tick_mgr.run_tick()
	var gained_damaged = ResourceManager.get_resource("ore") - 100
	assert(gained_damaged < quarry_data.ore_production and gained_damaged > 0, "T3.13: Damaged quarry must yield reduced ore (%d < %d)" % [gained_damaged, quarry_data.ore_production])
	
	# Drop to 0 HP -> ruins state (25% salvage refund!)
	t313_quarry.take_damage(t313_quarry.current_hp)
	assert(t313_quarry.current_hp == 0 and t313_quarry.get_efficiency() == 0.0, "T3.13: 0 HP efficiency must be 0.0")
	assert(int(t313_quarry.get_refund()["ore"]) == int(quarry_data.cost_ore * 0.25), "T3.13: Ruined building refund must be 25%")
	building_mgr.remove_building(t313_quarry)
	print("[OK] T3.13: test_damage_efficiency_degradation_ruins_and_refund пройден")
	
	# -------------------------------------------------------------
	# T3.14: test_munitions_factory_single_spend_through_tick
	# -------------------------------------------------------------
	GameState.set_game_mode(GameState.GameMode.STANDARD)
	ResourceManager.set_resource("energy", 1000)
	ResourceManager.set_resource("ore", 1000)
	ResourceManager.set_resource("materials", 1000)
	defense_sys.ammo_supply.reset()
	
	var t314_mun = building_mgr.place_building(munitions_data, Vector2i(6, 6), 0)
	assert(t314_mun != null, "T3.14: Munitions factory placement failed")
	t314_mun.connected_to_power = true
	t314_mun.connected_to_supply = true
	t314_mun.is_operational = true
	
	# Set exact resources right before tick execution to measure tick spend in isolation
	ResourceManager.set_resource("energy", 500)
	ResourceManager.set_resource("ore", 100)
	ResourceManager.set_resource("materials", 100)
	ResourceManager.set_resource("ammo", 0)
	
	# Execute a full game tick through TickManager
	tick_mgr.run_tick()
	
	# Munitions factory consumes 2 ore and 1 materials to produce 30 ammo (single-spend)
	# If double-spend bug existed (TickManager Phase 4/5 + AmmoSupply), ore would be 96 instead of 98.
	assert(ResourceManager.get_resource("ore") == 98, "T3.14: Ore must decrease by exactly 2 (single-spend), got %d" % ResourceManager.get_resource("ore"))
	assert(ResourceManager.get_resource("materials") == 99, "T3.14: Materials must decrease by exactly 1, got %d" % ResourceManager.get_resource("materials"))
	assert(ResourceManager.get_resource("ammo") == 30, "T3.14: Ammo produced must be 30 in ResourceManager, got %d" % ResourceManager.get_resource("ammo"))
	assert(defense_sys.ammo_supply.ammo_stock == 30, "T3.14: AmmoSupply stock must match ResourceManager ammo (30)")
	
	building_mgr.remove_building(t314_mun)
	print("[OK] T3.14: test_munitions_factory_single_spend_through_tick пройден (руда списана строго 1 раз за тик, боеприпасы произведены)")

	# -------------------------------------------------------------
	# T3.15: test_multi_layer_stacked_armor_decks
	# -------------------------------------------------------------
	ResourceManager.set_resource("energy", 1000)
	ResourceManager.set_resource("ore", 2000)
	ResourceManager.set_resource("materials", 2000)
	if not layer_mgr.layers.has(1):
		layer_mgr.create_layer(1)
	if not layer_mgr.layers.has(2):
		layer_mgr.create_layer(2)
		
	var t315_pillar0 = building_mgr.place_building(pillar_data, Vector2i(0, 4), 0)
	var t315_pillar1 = building_mgr.place_building(pillar_data, Vector2i(0, 4), 1)
	
	# Stack two armor decks at same position across z=1 and z=2
	var deck_pos := Vector2i(4, 4)
	var t315_deck_z1 = building_mgr.place_building(armor_deck_data, deck_pos, 1)
	var t315_deck_z2 = building_mgr.place_building(armor_deck_data, deck_pos, 2)
	assert(t315_deck_z1 != null and t315_deck_z2 != null, "T3.15: Stacked armor decks placement failed")
	assert(defense_sys.is_position_armor_covered(0, deck_pos) == true, "T3.15: z=0 cell must be armor covered by stacked decks")
	
	# Each deck has 8000 HP. Apply 10000 overhead damage to z=0 cell.
	# Upper deck (z=2) absorbs first (8000 HP), and excess 2000 damage penetrates to lower deck (z=1).
	var passthrough_stacked = defense_sys.absorb_overhead_damage(0, deck_pos, 10000)
	assert(passthrough_stacked == 0, "T3.15: Stacked armor decks must absorb all 10000 damage without leaking to z=0")
	assert(t315_deck_z2.current_hp == 0, "T3.15: Upper deck on z=2 must absorb first and reach 0 HP (destroyed)")
	assert(t315_deck_z1.current_hp == 6000, "T3.15: Lower deck on z=1 must absorb remaining 2000 damage (8000 - 2000 = 6000), got %d" % t315_deck_z1.current_hp)
	
	building_mgr.remove_building(t315_deck_z2)
	building_mgr.remove_building(t315_deck_z1)
	if t315_pillar1:
		building_mgr.remove_building(t315_pillar1)
	if t315_pillar0:
		building_mgr.remove_building(t315_pillar0)
	print("[OK] T3.15: test_multi_layer_stacked_armor_decks пройден (поглощение сверху вниз, пробитие остаточного урона)")

	# -------------------------------------------------------------
	# T3.16: test_reverse_ammo_synchronization
	# -------------------------------------------------------------
	defense_sys.ammo_supply.reset()
	ResourceManager.set_resource("ammo", 120)
	assert(defense_sys.ammo_supply.ammo_stock == 120, "T3.16: AmmoSupply.ammo_stock must reflect ResourceManager set_resource(120)")
	assert(defense_sys.ammo_supply.has_ammo(120) == true, "T3.16: has_ammo(120) must be true")
	assert(defense_sys.ammo_supply.has_ammo(121) == false, "T3.16: has_ammo(121) must be false")
	
	# Reverse modification via ResourceManager.modify_resource
	ResourceManager.modify_resource("ammo", -50)
	assert(defense_sys.ammo_supply.ammo_stock == 70, "T3.16: AmmoSupply.ammo_stock must reflect ResourceManager modify_resource(-50)")
	assert(defense_sys.ammo_supply.has_ammo(70) == true, "T3.16: has_ammo(70) must be true")
	assert(defense_sys.ammo_supply.has_ammo(71) == false, "T3.16: has_ammo(71) must be false")
	
	defense_sys.ammo_supply.consume(20)
	assert(ResourceManager.get_resource("ammo") == 50, "T3.16: Consuming through AmmoSupply must update ResourceManager ammo to 50")
	defense_sys.ammo_supply.reset()
	assert(ResourceManager.get_resource("ammo") == 0, "T3.16: Reset must set ResourceManager ammo to 0")
	print("[OK] T3.16: test_reverse_ammo_synchronization пройден (двусторонняя синхронизация боеприпасов с ResourceManager)")

	# -------------------------------------------------------------
	# T3.17: test_excavation_rig_structural_demolition
	# -------------------------------------------------------------
	ResourceManager.set_resource("energy", 1000)
	ResourceManager.set_resource("ore", 1000)
	ResourceManager.set_resource("materials", 1000)
	var exc_data = load("res://data/buildings/excavation_rig.tres") as BuildingData
	assert(exc_data != null, "T3.17: excavation_rig.tres missing")
	assert(exc_data.is_structural == true, "T3.17: excavation_rig must be flagged as is_structural = true")
	
	if not layer_mgr.layers.has(-1):
		layer_mgr.create_layer(-1)
	
	# Without operational excavation rig on z=0 drilling to z=-1, layer -1 is compromised
	var compromised_before = layer_mgr.validate_structural_integrity()
	assert(compromised_before.has(-1), "T3.17: Layer -1 without excavation rig on z=0 must be flagged compromised")
	
	# Place excavation rig on z=0 (which unlocks and supports layer z=-1 below)
	var t317_rig = building_mgr.place_building(exc_data, Vector2i(8, 8), 0)
	assert(t317_rig != null, "T3.17: Excavation rig placement on z=0 failed")
	assert(t317_rig.data.is_structural == true, "T3.17: Placed excavation rig instance data must have is_structural == true")
	t317_rig.connected_to_power = true
	t317_rig.is_operational = true
	
	var compromised_with_rig = layer_mgr.validate_structural_integrity()
	assert(not compromised_with_rig.has(-1), "T3.17: Layer -1 with operational excavation rig must no longer be compromised")
	
	# Demolish excavation rig on z=0: because is_structural is true, layer_mgr._on_building_changed_structural triggers integrity recheck
	building_mgr.remove_building(t317_rig)
	var compromised_after_demo = layer_mgr.get_compromised_layers()
	assert(compromised_after_demo.has(-1), "T3.17: Demolishing excavation rig must flag layer -1 as compromised again")
	print("[OK] T3.17: test_excavation_rig_structural_demolition пройден (буровая установка имеет флаг is_structural и триггерит проверку целостности)")

	print("--- ВСЕ ТЕСТЫ ЭТАПА 3 УСПЕШНО ПРОЙДЕНЫ ---")

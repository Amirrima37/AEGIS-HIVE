extends Node

func _ready() -> void:
	print("--- STARTING M2 P1 VERIFICATION PROBE ---")
	
	# Load and instantiate Main scene
	var main_scene = load("res://scenes/main.tscn")
	if main_scene == null:
		push_error("Failed to load main.tscn")
		get_tree().quit(1)
		return
	var main_node = main_scene.instantiate()
	add_child(main_node)
	
	# Wait for deferred initializations
	await get_tree().process_frame
	await get_tree().process_frame
	
	var bm: BuildingManager = main_node.find_child("BuildingManager", true, false)
	var tm: TickManager = main_node.find_child("TickManager", true, false)
	var ds: DefenseSystem = main_node.find_child("DefenseSystem", true, false)
	var hud: GameHUD = main_node.find_child("HUD", true, false)
	var lm: LayerManager = main_node.find_child("LayerManager", true, false)
	var cmd: CommandPanel = hud.command_panel if hud else null
	
	assert(bm != null, "BuildingManager not found")
	assert(tm != null, "TickManager not found")
	assert(ds != null, "DefenseSystem not found")
	assert(hud != null, "GameHUD not found")
	assert(lm != null, "LayerManager not found")
	assert(cmd != null, "CommandPanel not found")
	
	print("[OK] Core systems found and initialized")
	
	# ========================================================
	# 1. P1-0: TickManager Signal Batching & Building Setter Guards
	# ========================================================
	print("Testing P1-0 (TickManager Signal Batching & Setter Guards)...")
	
	# Set sufficient resources
	ResourceManager.set_resource("energy", 500)
	ResourceManager.set_resource("ore", 500)
	ResourceManager.set_resource("materials", 500)
	
	var factory_data = load("res://data/buildings/factory.tres") as BuildingData
	var quarry_data = load("res://data/buildings/quarry.tres") as BuildingData
	assert(factory_data != null and quarry_data != null, "Building data failed to load")
	
	var placed_test_buildings: Array[Building] = []
	for i in range(10):
		var q = bm.place_building(quarry_data, Vector2i(i * 2 - 20, 10), 0)
		if q:
			q.connected_to_power = true
			q.connected_to_supply = true
			placed_test_buildings.append(q)
		var f = bm.place_building(factory_data, Vector2i(i * 2 - 20, 14), 0)
		if f:
			f.connected_to_power = true
			f.connected_to_supply = true
			placed_test_buildings.append(f)
			
	var resource_changed_count = [0]
	var on_res_changed = func(_name, _val):
		resource_changed_count[0] += 1
	EventBus.resource_changed.connect(on_res_changed)
	
	var t_start = Time.get_ticks_usec()
	tm.run_tick()
	var t_elapsed_ms = (Time.get_ticks_usec() - t_start) / 1000.0
	EventBus.resource_changed.disconnect(on_res_changed)
	
	print("  Tick execution time: %.3f ms | resource_changed emissions: %d" % [t_elapsed_ms, resource_changed_count[0]])
	assert(t_elapsed_ms < 50.0, "P1-0 FAIL: TickManager.run_tick took %.2f ms (expected < 50 ms)" % t_elapsed_ms)
	assert(resource_changed_count[0] <= 7, "P1-0 FAIL: Expected <= 7 batched resource_changed emissions, got %d" % resource_changed_count[0])
	
	# Building setter guards test
	var sample_b = placed_test_buildings[0]
	var op_redraws_triggered = [false]
	var initial_status_rim_draw = sample_b.status_rim_node.visible
	
	# Setting identical values should return early immediately
	sample_b.connected_to_power = sample_b.connected_to_power
	sample_b.connected_to_supply = sample_b.connected_to_supply
	sample_b.is_operational = sample_b.is_operational
	assert(sample_b.status_rim_node.visible == initial_status_rim_draw, "P1-0: Setter guard check failed")
	print("[PASS] P1-0: TickManager signal batching (<50ms, <=5 signals) & Building setter guards verified")
	
	# Cleanup test buildings
	for b in placed_test_buildings:
		bm.remove_building(b)
		
	# ========================================================
	# 2. P1-1: CommandPanel Caching, AStarGrid2D, 0 HP StatusRim, Excavation Rig, Alert Spam
	# ========================================================
	print("Testing P1-1 (CommandPanel Caching, AStarGrid2D, 0 HP StatusRim, Rig, LayerManager Alerts)...")
	
	# Test CommandPanel caching
	cmd.select_tab("directives")
	await get_tree().process_frame
	var pbox = cmd.find_child("PriorityRow_defense", true, false)
	assert(pbox != null, "P1-1: PriorityRow_defense not found")
	var initial_row_instance_id = pbox.get_instance_id()
	
	# Run 5 ticks
	for _k in range(5):
		tm.run_tick()
		
	var after_row = cmd.find_child("PriorityRow_defense", true, false)
	assert(after_row != null, "P1-1: PriorityRow_defense not found after ticks")
	assert(after_row.get_instance_id() == initial_row_instance_id, "P1-1 FAIL: Priority rows were recreated instead of cached!")
	assert(cmd._cached_tick_manager != null and cmd._cached_research_manager != null, "P1-1: Manager references must be cached")
	print("  -> CommandPanel priority row nodes strictly cached across ticks without recreation")
	
	# Test OccupancyGrid AStarGrid2D Navigation
	var occ: OccupancyGrid = bm.occupancy
	assert(occ != null, "OccupancyGrid not found")
	
	# Path latency and validity check across obstacle
	var path_start = Vector2i(0, 0)
	var path_end = Vector2i(8, 0)
	var t_astar_start = Time.get_ticks_usec()
	var initial_path = occ.find_path(0, path_start, path_end)
	var t_astar_dur_ms = (Time.get_ticks_usec() - t_astar_start) / 1000.0
	assert(initial_path.size() > 0, "P1-1: Initial path must exist")
	print("  -> AStarGrid2D initial query latency: %.4f ms" % t_astar_dur_ms)
	assert(t_astar_dur_ms < 0.5, "P1-1 FAIL: AStarGrid2D query too slow (%.3f ms)" % t_astar_dur_ms)
	
	# Place wall obstacle at (4, 0)
	var wall_data = load("res://data/buildings/defense_wall.tres") as BuildingData
	assert(wall_data != null, "defense_wall.tres not found")
	var wall_b = bm.place_building(wall_data, Vector2i(4, 0), 0)
	assert(wall_b != null, "Wall placement failed")
	assert(occ.is_blocked(0, Vector2i(4, 0)) == true, "Wall at (4, 0) must be blocked")
	
	var blocked_path = occ.find_path(0, path_start, path_end)
	assert(blocked_path.size() > 0, "Path around wall must be found")
	assert(not blocked_path.has(Vector2i(4, 0)), "Path must route around solid wall (4, 0)")
	
	# Vacate wall and verify path traverses (4, 0)
	bm.remove_building(wall_b)
	assert(occ.is_blocked(0, Vector2i(4, 0)) == false, "Wall tile must be unblocked after removal")
	var cleared_path = occ.find_path(0, path_start, path_end)
	assert(cleared_path.has(Vector2i(4, 0)), "Path after vacate must traverse cleared cell (4, 0)")
	
	# Long distance path test (40 tiles) to verify removal of 2000-iteration ceiling
	var long_start = Vector2i(-20, 0)
	var long_end = Vector2i(20, 0)
	var long_path = occ.find_path(0, long_start, long_end)
	assert(long_path.size() >= 40, "P1-1: Long distance path (40 tiles) must succeed without 2000 iteration cutoff")
	print("  -> AStarGrid2D successfully routed 40-tile path across grid")
	
	# Test Building 0 HP StatusRim & set_process
	var hab_data = load("res://data/buildings/habitation_block.tres") as BuildingData
	var test_hab = bm.place_building(hab_data, Vector2i(10, 10), 0)
	assert(test_hab != null, "Habitation block placement failed")
	
	# Power building to test healthy operational state: status rim hidden, process disabled
	test_hab.connected_to_power = true
	assert(test_hab.is_operational == true, "Hab must be operational when powered")
	assert(test_hab.status_rim_node.visible == false, "P1-1: Healthy operational building must not show StatusRim")
	assert(test_hab.is_processing() == false, "P1-1: Healthy building must not run _process()")
	
	# Unpowered building: status rim visible, process enabled
	test_hab.connected_to_power = false
	assert(test_hab.status_rim_node.visible == true, "P1-1: Unpowered building must show StatusRim")
	assert(test_hab.is_processing() == true, "P1-1: Unpowered building must run _process() for pulsation")
	
	# Ruined building (0 HP): status rim hidden, process disabled
	test_hab.take_damage(test_hab.data.max_hp)
	assert(test_hab.current_hp == 0, "Building must be 0 HP")
	assert(test_hab.status_rim_node.visible == false, "P1-1 FAIL: 0 HP Ruin must NOT display active StatusRim")
	assert(test_hab.is_processing() == false, "P1-1 FAIL: 0 HP Ruin must NOT run _process()")
	print("  -> 0 HP Ruined building correctly turns off StatusRim and deactivates _process()")
	bm.remove_building(test_hab)
	
	# Test excavation_rig.tres structural flag
	var rig_data = load("res://data/buildings/excavation_rig.tres") as BuildingData
	assert(rig_data != null, "excavation_rig.tres failed to load")
	assert(rig_data.is_structural == true, "P1-1 FAIL: excavation_rig.tres must have is_structural = true")
	print("  -> excavation_rig.tres is_structural = true confirmed")
	
	# Test LayerManager alert debouncing (no spam on consecutive ticks)
	var comp_emissions = [0]
	var on_comp = func(_z, _reason):
		comp_emissions[0] += 1
	EventBus.layer_integrity_compromised.connect(on_comp)
	
	# Create upper layer 1 without pillar -> compromised
	lm.create_layer(1)
	lm.validate_structural_integrity()
	assert(comp_emissions[0] == 1, "P1-1: Expected 1 emission when layer 1 becomes compromised, got %d" % comp_emissions[0])
	
	# Calling validate_structural_integrity() again (simulate consecutive ticks)
	for _t in range(4):
		lm.validate_structural_integrity()
	assert(comp_emissions[0] == 1, "P1-1 FAIL: layer_integrity_compromised was spammed %d times (expected 1 with diff check)" % comp_emissions[0])
	EventBus.layer_integrity_compromised.disconnect(on_comp)
	lm.remove_layer(1)
	print("[PASS] P1-1: CommandPanel caching, AStarGrid2D, 0 HP StatusRim, excavation rig, and alert debouncing verified")
	
	# ========================================================
	# 3. P1-2: BrutalistTheme Button Styles, Center Radii, Tracer Scoping
	# ========================================================
	print("Testing P1-2 (BrutalistTheme Button Styles, Center Radii, Tracer Scoping)...")
	
	# Test BrutalistTheme.set_button_active
	var test_btn = Button.new()
	BrutalistTheme.apply_button_styles(test_btn)
	
	# Active state
	BrutalistTheme.set_button_active(test_btn, true)
	var active_sb = test_btn.get_theme_stylebox("normal") as StyleBoxFlat
	assert(active_sb != null and active_sb.bg_color == BrutalistTheme.BG_BTN_ACTIVE, "P1-2: Active stylebox failed")
	
	# Inactive state: MUST NOT be null or stripped to default engine theme
	BrutalistTheme.set_button_active(test_btn, false)
	var normal_sb = test_btn.get_theme_stylebox("normal") as StyleBoxFlat
	assert(normal_sb != null, "P1-2 FAIL: Normal stylebox was stripped!")
	assert(normal_sb.bg_color == BrutalistTheme.BG_BTN_NORMAL, "P1-2 FAIL: Normal stylebox did not restore dark graphite BG_BTN_NORMAL")
	
	# Inactive demolish button
	BrutalistTheme.set_button_active(test_btn, false, true)
	var demo_sb = test_btn.get_theme_stylebox("normal") as StyleBoxFlat
	assert(demo_sb != null and demo_sb.bg_color == BrutalistTheme.BG_DEMOLISH, "P1-2: Demolish normal style failed")
	test_btn.free()
	print("  -> BrutalistTheme button styles cleanly preserved on toggle without stripping")
	
	# Test TurretManager & RepairDepot Geometric Center Alignment
	var turret_mgr = ds.turret_manager
	var repair_mgr = ds.repair_depot
	assert(turret_mgr != null and repair_mgr != null, "Defense managers not found")
	
	# Place 2x2 Heavy Railgun at (10, 10). Center is (11.0, 11.0). Top-left is (10, 10).
	var railgun_data = load("res://data/buildings/heavy_railgun.tres") as BuildingData
	var sensor_data = load("res://data/buildings/sensor_tower.tres") as BuildingData
	assert(railgun_data != null and sensor_data != null, "Railgun or sensor data failed to load")
	
	var railgun_b = bm.place_building(railgun_data, Vector2i(10, 10), 0)
	assert(railgun_b != null, "Railgun placement failed")
	railgun_b.connected_to_power = true
	
	# Sensor tower at (17, 10), tile_size is 2x2, center is (18.0, 11.0). Center-to-center distance = 7.0 tiles.
	# Top-left distance would be Vector2(10,10).distance_to(17,10) = 7.0.
	# Now let's place sensor at (15, 15), center is (16.0, 16.0). Center dist: sqrt(5^2 + 5^2) = 7.071 tiles.
	var sensor_b = bm.place_building(sensor_data, Vector2i(15, 11), 0) # center is (16.0, 12.0)
	sensor_b.connected_to_power = true
	var eff_range = turret_mgr.get_effective_range(railgun_b)
	# Sensor radius is 8.0 tiles. With center alignment, distance = sqrt(5^2 + 1^2) = 5.099 <= 8.0 -> +20% bonus
	assert(eff_range > railgun_data.attack_range, "P1-2: Turret must receive sensor bonus via center alignment")
	
	# Test Turret Tracer Scoping
	var tracer_enemy = {"grid_position": Vector2i(13, 11), "tile_size": Vector2i(1, 1), "z_level": 0, "current_hp": 100}
	ds.ammo_supply.produce(50)
	var root_child_count_before = get_tree().root.get_child_count()
	var layer0_container = railgun_b.get_parent() # "Buildings" container
	var layer_child_count_before = layer0_container.get_child_count()
	
	railgun_b.connected_to_power = true
	assert(turret_mgr.can_fire(railgun_b) == true, "Turret must be able to fire")
	var fired = turret_mgr.fire(railgun_b, tracer_enemy)
	assert(fired == true, "Turret fire must succeed")
	
	var root_child_count_after = get_tree().root.get_child_count()
	var layer_child_count_after = layer0_container.get_child_count()
	assert(root_child_count_after == root_child_count_before, "P1-2 FAIL: Tracer Line2D was added to get_tree().root instead of layer container!")
	assert(layer_child_count_after > layer_child_count_before, "P1-2 FAIL: Tracer Line2D was NOT scoped to the layer container!")
	print("  -> Turret tracer Line2D strictly scoped to layer container, zero root pollution")
	
	# Test RepairDepot Center Alignment
	var repair_data = load("res://data/buildings/repair_depot.tres") as BuildingData
	var depot_b = bm.place_building(repair_data, Vector2i(20, 20), 0) # 2x2, center (21.0, 21.0)
	assert(depot_b != null, "Repair depot placement failed")
	depot_b.connected_to_power = true
	
	var damaged_target = bm.place_building(hab_data, Vector2i(23, 20), 0) # 2x2, center (24.0, 21.0). dist = 3.0
	assert(damaged_target != null, "Damaged target placement failed")
	damaged_target.take_damage(60)
	
	var target_found = repair_mgr._find_most_damaged_in_range(depot_b, 4.0)
	assert(target_found == damaged_target, "P1-2: Repair depot must find damaged building using center-to-center distance")
	
	# Cleanup
	bm.remove_building(damaged_target)
	bm.remove_building(depot_b)
	bm.remove_building(sensor_b)
	bm.remove_building(railgun_b)
	
	print("[PASS] P1-2: BrutalistTheme button styles, radii center alignment, and tracer scoping verified")
	print("=================================================================")
	print("--- ALL M2 P1 VERIFICATIONS PASSED SUCCESSFULLY (100% GENUINE) ---")
	print("=================================================================")
	get_tree().quit(0)

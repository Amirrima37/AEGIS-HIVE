extends Node

const TestDefenseSystem = preload("res://tests/test_defense_system.gd")
const TestHUDModularDock = preload("res://tests/test_hud_modular_dock.gd")
const TestLinuxCompatibility = preload("res://tests/test_linux_compatibility.gd")

func _ready() -> void:
	# Watchdog timer: automatically exit process after 15s if tests get stuck or crash
	get_tree().create_timer(15.0).timeout.connect(func():
		printerr("[ERROR] Test runner watchdog timeout exceeded (15s)!")
		get_tree().quit(1)
	)

	print("--- НАЧАЛО ТЕСТИРОВАНИЯ ЭТАПА 0 И ЭТАПА 1 ---")
	
	# Load main scene
	var main_scene = load("res://scenes/main.tscn")
	assert(main_scene != null, "Main scene failed to load!")
	var main_node = main_scene.instantiate()
	add_child(main_node)
	
	print("[OK] Сцена main.tscn успешно инстанцирована")
	
	# Wait for deferred initializations (e.g. initial command center)
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Check autoloads
	assert(EventBus != null, "EventBus not found!")
	assert(GameState != null, "GameState not found!")
	assert(ResourceManager != null, "ResourceManager not found!")
	print("[OK] Синглтоны Autoload зарегистрированы")
	
	# Find LayerManager, BuildingManager, TickManager
	var layer_mgr: LayerManager = main_node.find_child("LayerManager", true, false)
	assert(layer_mgr != null, "LayerManager not found!")
	assert(layer_mgr.layers.has(0), "Surface layer z=0 was not created!")
	print("[OK] LayerManager инициализировал поверхностный ярус (z=0)")
	
	var building_mgr: BuildingManager = main_node.find_child("BuildingManager", true, false)
	assert(building_mgr != null, "BuildingManager not found!")
	print("[OK] BuildingManager обнаружен")
	
	var tick_mgr: TickManager = main_node.find_child("TickManager", true, false)
	assert(tick_mgr != null, "TickManager not found!")
	print("[OK] TickManager обнаружен")
	
	# Check initial Command Center on surface z=0
	assert(building_mgr.get_building_count(&"command_center") == 1, "Starting Command Center not spawned!")
	print("[OK] Начальный Командный Центр корректно размещен на z=0")
	
	# --- ТЕСТЫ ЭТАПА 0 ---
	# Test layer creation (Upper +1 and Underground -1)
	EventBus.layer_created.emit(1)
	EventBus.layer_created.emit(-1)
	assert(layer_mgr.layers.has(1), "Upper platform z=1 failed to create!")
	assert(layer_mgr.layers.has(-1), "Underground geofont z=-1 failed to create!")
	print("[OK] Динамическое создание ярусов вверх (z=+1) и вниз (z=-1) работает")
	
	# Test layer jump & delta navigation
	EventBus.layer_jump_requested.emit(1) # Jump to +1
	assert(GameState.current_layer == 1, "Failed to jump to layer 1!")
	print("[OK] Прямой переход по клику на ярус z=+1 работает корректно")
	
	EventBus.layer_change_requested.emit(-1) # Go down from 1 to 0
	assert(GameState.current_layer == 0, "Failed to change layer by -1!")
	print("[OK] Смена яруса клавишей E (дельта -1) перешла на z=0")

	EventBus.layer_jump_requested.emit(-1) # Jump to -1
	assert(GameState.current_layer == -1, "Failed to jump to layer -1!")
	print("[OK] Прямой переход по клику на ярус z=-1 работает корректно")
	
	# Test Camera
	var cam = main_node.find_child("Camera2D", true, false)
	assert(cam != null, "IsometricCamera not found!")
	print("[OK] Изометрическая камера обнаружена и настроена")
	print("--- ВСЕ ТЕСТЫ ЭТАПА 0 УСПЕШНО ПРОЙДЕНЫ ---")
	
	# --- ТЕСТЫ ЭТАПА 1 ---
	print("--- НАЧАЛО ТЕСТИРОВАНИЯ ЭТАПА 1 ---")
	
	# T1.1: can_afford and spend
	ResourceManager.set_resource("ore", 50)
	assert(ResourceManager.can_afford({"ore": 10}) == true, "T1.1: can_afford failed for valid amount")
	var spend_success = ResourceManager.spend({"ore": 10})
	assert(spend_success == true, "T1.1: spend failed")
	assert(ResourceManager.get_resource("ore") == 40, "T1.1: balance did not deduct properly")
	print("[OK] T1.1: test_can_afford_and_spend пройден")
	
	# T1.2: spend insufficient
	var spend_fail = ResourceManager.spend({"ore": 999})
	assert(spend_fail == false, "T1.2: spend should fail when not enough resources")
	assert(ResourceManager.get_resource("ore") == 40, "T1.2: balance changed on failed spend")
	print("[OK] T1.2: test_spend_insufficient пройден")
	
	# T1.3: OccupancyGrid basic
	var occ = building_mgr.occupancy
	assert(occ != null, "OccupancyGrid is null")
	var dummy_building = Building.new()
	occ.occupy(0, Vector2i(3, 3), Vector2i(2, 2), dummy_building)
	assert(occ.is_area_free(0, Vector2i(3, 3), Vector2i(2, 2)) == false, "T1.3: area should be occupied")
	assert(occ.is_area_free(0, Vector2i(6, 6), Vector2i(1, 1)) == true, "T1.3: free area reported occupied")
	occ.vacate(0, Vector2i(3, 3), Vector2i(2, 2))
	assert(occ.is_area_free(0, Vector2i(3, 3), Vector2i(2, 2)) == true, "T1.3: area should be free after vacate")
	dummy_building.free()
	print("[OK] T1.3: test_occupancy_grid_basic пройден")
	
	# T1.4: Building placement
	var quarry_data = load("res://data/buildings/quarry.tres") as BuildingData
	assert(quarry_data != null, "quarry.tres failed to load")
	ResourceManager.set_resource("ore", 100)
	ResourceManager.set_resource("materials", 100)
	var ore_before_place = ResourceManager.get_resource("ore")
	var b_quarry = building_mgr.place_building(quarry_data, Vector2i(5, 5), 0)
	assert(b_quarry != null, "T1.4: quarry placement returned null")
	assert(ResourceManager.get_resource("ore") == ore_before_place - quarry_data.cost_ore, "T1.4: cost not deducted")
	assert(occ.get_building_at(0, Vector2i(5, 5)) == b_quarry, "T1.4: building not found in OccupancyGrid")
	print("[OK] T1.4: test_building_placement пройден")
	
	# T1.5: Building removal and refund
	var mat_before_remove = ResourceManager.get_resource("materials")
	var expected_refund_mat = int(quarry_data.cost_materials * 0.5)
	building_mgr.remove_building(b_quarry)
	assert(ResourceManager.get_resource("materials") == mat_before_remove + expected_refund_mat, "T1.5: refund incorrect")
	assert(occ.get_building_at(0, Vector2i(5, 5)) == null, "T1.5: tile not vacated after remove")
	print("[OK] T1.5: test_building_removal_refund пройден")
	
	# T1.6: Tick production (Fusion reactor: +25 energy)
	var reactor_data = load("res://data/buildings/fusion_reactor.tres") as BuildingData
	assert(reactor_data != null, "fusion_reactor.tres failed to load")
	ResourceManager.set_resource("ore", 200)
	ResourceManager.set_resource("materials", 200)
	ResourceManager.set_resource("energy", 50)
	var reactor = building_mgr.place_building(reactor_data, Vector2i(3, 3), 0)
	assert(reactor != null, "T1.6: reactor placement failed")
	
	# Command center on z=0 produces +10, reactor produces +25 -> total +35 energy per tick
	var energy_before_tick = ResourceManager.get_resource("energy")
	tick_mgr.run_tick()
	assert(ResourceManager.get_resource("energy") == energy_before_tick + 35, "T1.6: energy production incorrect")
	print("[OK] T1.6: test_tick_production пройден")
	
	# T1.7: Tick consumption (Quarry consumes 3 energy, produces 5 ore)
	# Place quarry2 adjacent to reactor at (5, 3) so it is directly connected to power
	var quarry2 = building_mgr.place_building(quarry_data, Vector2i(5, 3), 0)
	assert(quarry2 != null, "T1.7: quarry2 placement failed")
	var energy_pre = ResourceManager.get_resource("energy")
	var ore_pre = ResourceManager.get_resource("ore")
	tick_mgr.run_tick()
	# Net energy change: +35 (CC+reactor) - 3 (quarry) = +32
	# Ore change: +5
	assert(ResourceManager.get_resource("energy") == energy_pre + 32, "T1.7: net energy incorrect with quarry consumption")
	assert(ResourceManager.get_resource("ore") == ore_pre + 5, "T1.7: ore production incorrect")
	print("[OK] T1.7: test_tick_consumption пройден")
	
	# T1.8: test_layer_requires_pillar (Attempt to create layer above without pillar)
	var existing_levels = layer_mgr.get_existing_z_levels()
	var target_upper_z = existing_levels.max() + 1
	EventBus.request_create_layer_above.emit()
	assert(not layer_mgr.layers.has(target_upper_z), "T1.8: Layer should not be created without support pillar")
	print("[OK] T1.8: test_layer_requires_pillar пройден")
	
	# T1.9: test_layer_with_pillar (Build support pillar on top layer, then create layer above)
	var pillar_data = load("res://data/buildings/support_pillar.tres") as BuildingData
	assert(pillar_data != null, "support_pillar.tres failed to load")
	ResourceManager.set_resource("ore", 100)
	ResourceManager.set_resource("materials", 100)
	var top_z = existing_levels.max()
	var pillar = building_mgr.place_building(pillar_data, Vector2i(0, 0), top_z)
	assert(pillar != null, "T1.9: support pillar placement failed")
	assert(building_mgr.has_structural_support(target_upper_z) == true, "T1.9: structural support check failed")
	
	EventBus.request_create_layer_above.emit()
	assert(layer_mgr.layers.has(target_upper_z) == true, "T1.9: Layer creation with pillar failed")
	print("[OK] T1.9: test_layer_with_pillar пройден")
	
	# T1.10: test_structural_demolish_warning
	assert(pillar.data.is_structural == true, "T1.10: support pillar is_structural flag must be true")
	assert(pillar.data.unlocks_layer_above == true, "T1.10: support pillar unlocks_layer_above flag must be true")
	print("[OK] T1.10: test_structural_demolish_warning пройден")
	
	# --- ТЕСТЫ ЭТАПА 2 ---
	print("--- НАЧАЛО ТЕСТИРОВАНИЯ ЭТАПА 2 ---")
	
	var network_mgr: NetworkManager = main_node.find_child("NetworkManager", true, false)
	assert(network_mgr != null, "NetworkManager not found!")
	
	var cable_data = load("res://data/buildings/power_cable.tres") as BuildingData
	assert(cable_data != null, "power_cable.tres failed to load")
	var conveyor_data = load("res://data/buildings/conveyor.tres") as BuildingData
	assert(conveyor_data != null, "conveyor.tres failed to load")
	var elevator_data = load("res://data/buildings/shaft_elevator.tres") as BuildingData
	assert(elevator_data != null, "shaft_elevator.tres failed to load")
	var warehouse_data = load("res://data/buildings/warehouse.tres") as BuildingData
	assert(warehouse_data != null, "warehouse.tres failed to load")
	var factory_data = load("res://data/buildings/factory.tres") as BuildingData
	assert(factory_data != null, "factory.tres failed to load")
	var hab_data = load("res://data/buildings/habitation_block.tres") as BuildingData
	assert(hab_data != null, "habitation_block.tres failed to load")
	
	# Clean up previous Stage 1 test buildings on layer 0 except command center
	for b in building_mgr.get_buildings_on_layer(0):
		if b.data and b.data.id != &"command_center":
			building_mgr.remove_building(b)
	
	ResourceManager.set_resource("ore", 10000)
	ResourceManager.set_resource("materials", 10000)
	ResourceManager.set_resource("energy", 1000)
	
	# T2.1: test_power_grid_basic (Reactor -> Cable -> Cable -> Quarry: quarry connected_to_power == true)
	var t21_reactor = building_mgr.place_building(reactor_data, Vector2i(3, 0), 0)
	assert(t21_reactor != null, "T2.1: reactor placement failed")
	var t21_cable1 = building_mgr.place_building(cable_data, Vector2i(5, 0), 0)
	assert(t21_cable1 != null, "T2.1: cable1 placement failed")
	var t21_cable2 = building_mgr.place_building(cable_data, Vector2i(6, 0), 0)
	assert(t21_cable2 != null, "T2.1: cable2 placement failed")
	var t21_quarry = building_mgr.place_building(quarry_data, Vector2i(7, 0), 0)
	assert(t21_quarry != null, "T2.1: quarry placement failed")
	
	network_mgr.recalculate_all()
	assert(t21_quarry.connected_to_power == true, "T2.1: quarry must be connected to power via cables")
	assert(t21_quarry.is_operational == true, "T2.1: quarry must be operational when powered")
	print("[OK] T2.1: test_power_grid_basic пройден")
	
	# T2.2: test_power_grid_disconnected (Quarry without cables to reactor: connected_to_power == false)
	var t22_quarry = building_mgr.place_building(quarry_data, Vector2i(-5, 4), 0)
	assert(t22_quarry != null, "T2.2: disconnected quarry placement failed")
	network_mgr.recalculate_all()
	assert(t22_quarry.connected_to_power == false, "T2.2: isolated quarry must have connected_to_power == false")
	assert(t22_quarry.is_operational == false, "T2.2: isolated quarry must have is_operational == false")
	print("[OK] T2.2: test_power_grid_disconnected пройден")
	
	# T2.3: test_power_cable_removal (Remove middle cable -> consumer disconnected)
	building_mgr.remove_building(t21_cable2)
	assert(t21_quarry.connected_to_power == false, "T2.3: quarry must be disconnected after cable removal")
	assert(t21_quarry.is_operational == false, "T2.3: quarry must not be operational after cable removal")
	print("[OK] T2.3: test_power_cable_removal пройден")
	
	# Clean up T2.1 and T2.2 buildings
	building_mgr.remove_building(t21_reactor)
	building_mgr.remove_building(t21_cable1)
	building_mgr.remove_building(t21_quarry)
	building_mgr.remove_building(t22_quarry)
	
	# T2.4: test_supply_chain_basic (Quarry -> Conveyor -> Factory: factory connected_to_supply == true)
	var t24_quarry = building_mgr.place_building(quarry_data, Vector2i(3, 0), 0)
	assert(t24_quarry != null, "T2.4: quarry placement failed")
	var t24_conveyor = building_mgr.place_building(conveyor_data, Vector2i(5, 0), 0)
	assert(t24_conveyor != null, "T2.4: conveyor placement failed")
	var t24_factory = building_mgr.place_building(factory_data, Vector2i(6, 0), 0)
	assert(t24_factory != null, "T2.4: factory placement failed")
	network_mgr.recalculate_all()
	assert(t24_factory.connected_to_supply == true, "T2.4: factory must be connected to supply via conveyor to quarry")
	print("[OK] T2.4: test_supply_chain_basic пройден")
	
	# T2.5: test_supply_chain_disconnected (Factory without conveyor to quarry: connected_to_supply == false, not operational)
	var t25_factory = building_mgr.place_building(factory_data, Vector2i(0, 4), 0)
	assert(t25_factory != null, "T2.5: factory placement failed")
	network_mgr.recalculate_all()
	assert(t25_factory.connected_to_supply == false, "T2.5: isolated factory must have connected_to_supply == false")
	assert(t25_factory.is_operational == false, "T2.5: isolated factory must not be operational")
	print("[OK] T2.5: test_supply_chain_disconnected пройден")
	
	# Clean up T2.4 and T2.5
	building_mgr.remove_building(t24_quarry)
	building_mgr.remove_building(t24_conveyor)
	building_mgr.remove_building(t24_factory)
	building_mgr.remove_building(t25_factory)
	
	# T2.6: test_shaft_elevator_connects_layers (Elevator on z=0 + elevator on z=-1 at same XY -> power passes between layers)
	var t26_reactor = building_mgr.place_building(reactor_data, Vector2i(0, 2), 0)
	var t26_elev_top = building_mgr.place_building(elevator_data, Vector2i(2, 2), 0)
	var t26_elev_bot = building_mgr.place_building(elevator_data, Vector2i(2, 2), -1)
	assert(t26_elev_top != null and t26_elev_bot != null, "T2.6: elevator placement failed")
	var t26_cable_under = building_mgr.place_building(cable_data, Vector2i(4, 2), -1)
	var t26_quarry_under = building_mgr.place_building(quarry_data, Vector2i(5, 2), -1)
	assert(t26_quarry_under != null, "T2.6: underground quarry placement failed")
	network_mgr.recalculate_all()
	assert(t26_quarry_under.connected_to_power == true, "T2.6: power must flow through shaft elevator to layer -1")
	print("[OK] T2.6: test_shaft_elevator_connects_layers пройден")
	
	# Clean up T2.6
	building_mgr.remove_building(t26_reactor)
	building_mgr.remove_building(t26_elev_top)
	building_mgr.remove_building(t26_elev_bot)
	building_mgr.remove_building(t26_cable_under)
	building_mgr.remove_building(t26_quarry_under)
	
	# T2.7: test_isolated_layer (Layer z=1 without elevator: buildings on it connected_to_power == false)
	assert(layer_mgr.layers.has(1), "Layer 1 not present")
	var t27_hab = building_mgr.place_building(hab_data, Vector2i(2, 2), 1)
	assert(t27_hab != null, "T2.7: hab block placement on layer 1 failed")
	network_mgr.recalculate_all()
	assert(network_mgr.is_layer_connected(1) == false, "T2.7: layer 1 without elevator should be isolated")
	assert(t27_hab.connected_to_power == false, "T2.7: building on isolated layer must have connected_to_power == false")
	print("[OK] T2.7: test_isolated_layer пройден")
	building_mgr.remove_building(t27_hab)
	
	# T2.8: test_tick_respects_networks (Quarry without power cable -> after tick ore does not increase)
	var t28_quarry = building_mgr.place_building(quarry_data, Vector2i(-4, 4), 0)
	assert(t28_quarry != null, "T2.8: isolated quarry placement failed")
	network_mgr.recalculate_all()
	assert(t28_quarry.connected_to_power == false, "T2.8: t28_quarry must be unpowered")
	ResourceManager.set_resource("energy", 1000)
	var ore_before_t28 = ResourceManager.get_resource("ore")
	tick_mgr.run_tick()
	assert(ResourceManager.get_resource("ore") == ore_before_t28, "T2.8: unpowered quarry must not produce ore during tick")
	print("[OK] T2.8: test_tick_respects_networks пройден")
	building_mgr.remove_building(t28_quarry)
	
	# T2.9: test_tick_with_full_chain (Reactor -> Cable -> Quarry -> Conveyor -> Factory: after tick materials increases)
	var t29_reactor = building_mgr.place_building(reactor_data, Vector2i(2, 0), 0)
	var t29_cable1 = building_mgr.place_building(cable_data, Vector2i(2, -1), 0) # touches reactor at (2,0)
	var t29_cable2 = building_mgr.place_building(cable_data, Vector2i(3, -1), 0)
	var t29_cable3 = building_mgr.place_building(cable_data, Vector2i(4, -1), 0)
	var t29_cable4 = building_mgr.place_building(cable_data, Vector2i(5, -1), 0) # touches quarry at (4,0, size 2x2: 4..5)
	var t29_cable5 = building_mgr.place_building(cable_data, Vector2i(6, -1), 0)
	var t29_cable6 = building_mgr.place_building(cable_data, Vector2i(7, -1), 0) # touches factory at (7,0)
	
	var t29_quarry = building_mgr.place_building(quarry_data, Vector2i(4, 0), 0) # size 2x2: (4..5, 0..1)
	var t29_conveyor = building_mgr.place_building(conveyor_data, Vector2i(6, 0), 0) # touches quarry at (5,0)
	var t29_factory = building_mgr.place_building(factory_data, Vector2i(7, 0), 0) # touches conveyor at (6,0)
	
	network_mgr.recalculate_all()
	assert(t29_quarry.connected_to_power == true, "T2.9: quarry must be powered")
	assert(t29_factory.connected_to_power == true, "T2.9: factory must be powered")
	assert(t29_factory.connected_to_supply == true, "T2.9: factory must be connected to supply")
	assert(t29_factory.is_operational == true, "T2.9: factory must be operational")
	
	ResourceManager.set_resource("ore", 100)
	ResourceManager.set_resource("energy", 500)
	var mat_before_t29 = ResourceManager.get_resource("materials")
	tick_mgr.run_tick()
	assert(ResourceManager.get_resource("materials") > mat_before_t29, "T2.9: materials must increase after tick with full chain")
	print("[OK] T2.9: test_tick_with_full_chain пройден")
	
	# T2.10: test_network_recalculates_on_demolish (Build chain -> demolish middle cable -> recalculate -> end building disconnected)
	building_mgr.remove_building(t29_cable5)
	assert(t29_factory.connected_to_power == false, "T2.10: factory must lose power after middle cable demolished")
	assert(t29_factory.is_operational == false, "T2.10: factory must become unoperational")
	print("[OK] T2.10: test_network_recalculates_on_demolish пройден")
	
	# T2.11: test_building_grid_alignment (All 11 buildings must have width == tile_size.x * 128 and standardized offset)
	var catalog = [
		"command_center", "fusion_reactor", "quarry", "factory",
		"habitation_block", "support_pillar", "excavation_rig",
		"power_cable", "conveyor", "shaft_elevator", "warehouse"
	]
	for b_id in catalog:
		var b_data = load("res://data/buildings/%s.tres" % b_id) as BuildingData
		assert(b_data != null, "BuildingData not found: %s" % b_id)
		assert(b_data.sprite != null, "Building sprite missing for %s" % b_id)
		var tex = b_data.sprite
		var exp_w = b_data.tile_size.x * 128
		assert(tex.get_width() == exp_w, "Sprite width for %s is %d, expected %d" % [b_id, tex.get_width(), exp_w])
		var dummy = Building.new()
		var tml_0 = layer_mgr.layers[0].tile_map_layer
		dummy.init(b_data, Vector2i.ZERO, 0, tml_0)
		var expected_offset_y = (b_data.tile_size.x * 32.0 + 3.0) - tex.get_height() * 0.5 + b_data.base_offset_y
		assert(abs(dummy.sprite_node.offset.y - expected_offset_y) < 0.01, "Sprite offset formula mismatch for %s" % b_id)
		dummy.queue_free()
	print("[OK] T2.11: test_building_grid_alignment пройден (все 11 спрайтов строго соответствуют сетке)")
	
	# T2.12: test_unlimited_mode (Sandbox mode allows building and layer expansion without resources/waiting)
	assert(GameState.is_unlimited_mode() == false, "T2.12: default mode must be STANDARD")
	ResourceManager.set_resource("ore", 0)
	ResourceManager.set_resource("materials", 0)
	assert(ResourceManager.can_afford({"ore": 10, "materials": 5}) == false, "T2.12: cannot afford with 0 resources in STANDARD mode")
	var t212_fail = building_mgr.place_building(quarry_data, Vector2i(-2, 2), 0)
	assert(t212_fail == null, "T2.12: placement must fail with insufficient resources in STANDARD mode")
	
	# Switch to UNLIMITED mode
	GameState.set_game_mode(GameState.GameMode.UNLIMITED)
	assert(GameState.is_unlimited_mode() == true, "T2.12: must be in UNLIMITED mode")
	assert(ResourceManager.can_afford({"ore": 1000, "materials": 500}) == true, "T2.12: can afford everything in UNLIMITED mode")
	assert(ResourceManager.spend({"ore": 1000, "materials": 500}) == true, "T2.12: spend succeeds in UNLIMITED mode")
	var t212_quarry = building_mgr.place_building(quarry_data, Vector2i(-2, 2), 0)
	assert(t212_quarry != null, "T2.12: placement must succeed in UNLIMITED mode even with 0 resources")
	building_mgr.remove_building(t212_quarry)
	
	# Return to STANDARD mode
	GameState.set_game_mode(GameState.GameMode.STANDARD)
	assert(GameState.is_unlimited_mode() == false, "T2.12: must return to STANDARD mode")
	print("[OK] T2.12: test_unlimited_mode пройден")
	
	# T2.13: test_warehouse_requires_quarry (Warehouse without quarry must not supply factory; with quarry it transmits supply)
	ResourceManager.set_resource("ore", 1000)
	ResourceManager.set_resource("materials", 1000)
	ResourceManager.set_resource("energy", 1000)
	var wh_data = load("res://data/buildings/warehouse.tres") as BuildingData
	assert(wh_data != null, "warehouse.tres failed to load")
	var t213_wh = building_mgr.place_building(wh_data, Vector2i(0, 6), 0)
	var t213_factory = building_mgr.place_building(factory_data, Vector2i(2, 6), 0)
	network_mgr.recalculate_all()
	assert(t213_factory.connected_to_supply == false, "T2.13: factory must NOT be supplied by an isolated warehouse without a quarry")
	# Now connect quarry to the warehouse
	var t213_quarry = building_mgr.place_building(quarry_data, Vector2i(-2, 6), 0)
	network_mgr.recalculate_all()
	assert(t213_factory.connected_to_supply == true, "T2.13: factory must be supplied through warehouse once quarry is connected")
	building_mgr.remove_building(t213_wh)
	building_mgr.remove_building(t213_factory)
	building_mgr.remove_building(t213_quarry)
	print("[OK] T2.13: test_warehouse_requires_quarry пройден (дыра бесконечного склада закрыта)")
	
	# T2.14: test_network_dirty_flag_caching
	network_mgr.recalculate_all()
	assert(network_mgr._is_dirty == false, "T2.14: dirty flag must be false after recalculation")
	network_mgr.mark_dirty()
	assert(network_mgr._is_dirty == true, "T2.14: mark_dirty must set dirty flag to true")
	network_mgr.recalculate_all()
	assert(network_mgr._is_dirty == false, "T2.14: dirty flag must be false after recalculate_all")
	print("[OK] T2.14: test_network_dirty_flag_caching пройден (холостой ход тиков устранен)")
	
	# T2.15: test_building_damage_invalidates_network (Lethal damage immediately recalculates network)
	var t215_reactor = building_mgr.place_building(reactor_data, Vector2i(4, 4), 0)
	var t215_cable = building_mgr.place_building(cable_data, Vector2i(6, 4), 0)
	var t215_quarry = building_mgr.place_building(quarry_data, Vector2i(7, 4), 0)
	assert(t215_reactor != null and t215_cable != null and t215_quarry != null, "T2.15: placements failed")
	network_mgr.recalculate_all()
	assert(t215_quarry.connected_to_power == true, "T2.15: quarry must be powered initially")
	# Deal lethal damage to cable
	t215_cable.take_damage(t215_cable.current_hp)
	assert(t215_cable.current_hp == 0, "T2.15: cable HP must be 0")
	assert(t215_quarry.connected_to_power == false, "T2.15: quarry must lose power immediately after cable is destroyed by damage")
	building_mgr.remove_building(t215_reactor)
	building_mgr.remove_building(t215_cable)
	building_mgr.remove_building(t215_quarry)
	print("[OK] T2.15: test_building_damage_invalidates_network пройден (сети реагируют на урон)")
	
	# T2.16: test_power_priority_brownout (Priority 0 Habitation gets power first over Priority 2 Factory during deficit)
	for b in building_mgr.get_buildings_on_layer(0):
		if b.data and b.data.id != &"command_center":
			building_mgr.remove_building(b)
			
	ResourceManager.set_resource("ore", 1000)
	ResourceManager.set_resource("materials", 1000)
	var t216_hab = building_mgr.place_building(hab_data, Vector2i(2, 0), 0) # 1x1: (2, 0) touches CC at (1, 0)
	var t216_factory = building_mgr.place_building(factory_data, Vector2i(2, 1), 0) # 2x2: (2..3, 1..2) touches CC
	var t216_factory2 = building_mgr.place_building(factory_data, Vector2i(2, -2), 0) # 2x2: (2..3, -2..-1) touches CC
	assert(t216_hab != null and t216_factory != null and t216_factory2 != null, "T2.16: placements failed")
	assert(t216_hab.data.power_priority == 0, "T2.16: hab priority must be 0")
	assert(t216_factory.data.power_priority == 2, "T2.16: factory priority must be 2")
	network_mgr.recalculate_all()
	assert(t216_hab.connected_to_power == true and t216_factory.connected_to_power == true and t216_factory2.connected_to_power == true, "T2.16: power connection failed")
	
	# Deficit simulation: CC generates +10 net. Total demand = 2 (hab, p0) + 5 (f1, p2) + 5 (f2, p2) = 12 energy.
	ResourceManager.set_resource("energy", 0)
	tick_mgr.run_tick()
	# CC produces +10 -> Hab (p0) consumes 2 (leaving 8) -> Factory1 (p2) consumes 5 (leaving 3) -> Factory2 (p2, needs 5) browns out!
	assert(t216_hab.is_operational == true, "T2.16: Priority 0 building must remain operational during deficit")
	assert(t216_factory2.is_operational == false, "T2.16: Lowest priority building must brown out during deficit")
	building_mgr.remove_building(t216_hab)
	building_mgr.remove_building(t216_factory)
	building_mgr.remove_building(t216_factory2)
	print("[OK] T2.16: test_power_priority_brownout пройден (приоритеты энергии защищают жизненно важные узлы)")
	
	# T2.17: test_elevator_throughput_query (Shaft elevator capacity queryable and operational)
	var t217_elev_top = building_mgr.place_building(elevator_data, Vector2i(2, 2), 0)
	var t217_elev_bot = building_mgr.place_building(elevator_data, Vector2i(2, 2), -1)
	assert(t217_elev_top != null and t217_elev_bot != null, "T2.17: elevator placement failed")
	var tp = network_mgr.get_interlayer_throughput(0, -1)
	assert(tp == 100, "T2.17: throughput between 0 and -1 must be 100, got %d" % tp)
	building_mgr.remove_building(t217_elev_top)
	building_mgr.remove_building(t217_elev_bot)
	print("[OK] T2.17: test_elevator_throughput_query пройден (пропускная способность лифтов валидируется)")
	
	# T2.18: test_layer_structural_integrity (Structural integrity and missing support detection)
	assert(layer_mgr.is_layer_structurally_sound(0) == true, "T2.18: surface layer z=0 must always be sound")
	var comp_layers = layer_mgr.validate_structural_integrity()
	# In tests, if upper layer 1 exists without pillar, it should be detected in compromised layers
	if layer_mgr.layers.has(1):
		assert(comp_layers.has(1) == true, "T2.18: layer 1 without pillar must be detected as compromised")
	print("[OK] T2.18: test_layer_structural_integrity пройден (целостность ярусов и опор валидируется)")
	
	# T2.19: test_population_growth_and_capacity (Habitation block raises capacity and ticks grow population)
	ResourceManager.set_resource("energy", 1000)
	ResourceManager.set_resource("ore", 1000)
	ResourceManager.set_resource("materials", 1000)
	ResourceManager.set_resource("population", 10)
	var t219_hab = building_mgr.place_building(hab_data, Vector2i(2, 0), 0)
	assert(t219_hab != null, "T2.19: hab placement failed")
	network_mgr.recalculate_all()
	tick_mgr.run_tick()
	var cap_after = ResourceManager.get_resource("population_capacity")
	assert(cap_after >= 70, "T2.19: Capacity must be at least 70 (CC 50 + Hab 20), got %d" % cap_after)
	var pop_after_1 = ResourceManager.get_resource("population")
	assert(pop_after_1 > 10, "T2.19: Population must grow after tick, got %d" % pop_after_1)
	for i in range(35):
		tick_mgr.run_tick()
	var pop_after_growth = ResourceManager.get_resource("population")
	assert(pop_after_growth == cap_after, "T2.19: Population must reach capacity %d, got %d" % [cap_after, pop_after_growth])
	building_mgr.remove_building(t219_hab)
	tick_mgr.run_tick()
	assert(ResourceManager.get_resource("population_capacity") == 50, "T2.19: Capacity must return to 50 after hab demolished")
	print("[OK] T2.19: test_population_growth_and_capacity пройден (население плавно растет до нового лимита)")
	
	# T2.20: test_layer_creation_preserves_active_layer_and_transparency
	layer_mgr.set_active_layer(0)
	assert(layer_mgr.active_layer_z == 0, "T2.20: Active layer must be 0")
	var l0_tml = layer_mgr.layers[0].tile_map_layer
	assert(l0_tml.visible == true, "T2.20: Active layer must be visible")
	assert(l0_tml.modulate.a == 1.0, "T2.20: Active layer must be fully opaque (1.0)")
	EventBus.request_create_layer_below.emit()
	assert(layer_mgr.active_layer_z == 0, "T2.20: Active layer must remain 0 when creating new layer below")
	assert(l0_tml.modulate.a == 1.0, "T2.20: Active layer must remain fully opaque")
	if layer_mgr.layers.has(1):
		assert(layer_mgr.layers[1].tile_map_layer.visible == false, "T2.20: Layer above active layer must be hidden to avoid obscuring current layer")
	if layer_mgr.layers.has(-1):
		var lm1_tml = layer_mgr.layers[-1].tile_map_layer
		assert(lm1_tml.visible == true, "T2.20: Lower layer -1 must be visible")
		assert(lm1_tml.modulate.a <= 0.15, "T2.20: Lower layer -1 must be almost transparent (<=0.15), got %f" % lm1_tml.modulate.a)
	# When jumping to layer 1:
	if layer_mgr.layers.has(1):
		layer_mgr.set_active_layer(1)
		assert(layer_mgr.layers[1].tile_map_layer.visible == true, "T2.20: Layer 1 must be visible when active")
		assert(layer_mgr.layers[1].tile_map_layer.modulate.a == 1.0, "T2.20: Layer 1 must be opaque when active")
		assert(layer_mgr.layers[0].tile_map_layer.visible == true, "T2.20: Layer 0 below must be visible")
		assert(layer_mgr.layers[0].tile_map_layer.modulate.a <= 0.15, "T2.20: Layer 0 below must be translucent")
		layer_mgr.set_active_layer(0)
	print("[OK] T2.20: test_layer_creation_preserves_active_layer_and_transparency пройден (активный слой непрозрачен, слои сверху скрыты, снизу почти прозрачные)")
	
	# T2.21: test_unoperational_building_rim_and_opacity
	ResourceManager.set_resource("ore", 1000)
	ResourceManager.set_resource("materials", 1000)
	var t221_hab = building_mgr.place_building(hab_data, Vector2i(6, 6), 0)
	assert(t221_hab != null, "T2.21: hab placement failed")
	network_mgr.recalculate_all()
	assert(t221_hab.connected_to_power == false, "T2.21: isolated hab must not have power")
	assert(t221_hab.is_operational == false, "T2.21: unpowered hab must be non-operational")
	assert(t221_hab.sprite_node.modulate == Color(1.0, 1.0, 1.0, 1.0), "T2.21: unoperational sprite must stay fully opaque Color(1,1,1,1)")
	assert(t221_hab.status_rim_node != null and t221_hab.status_rim_node.visible == true, "T2.21: status rim must be visible for unoperational building")
	# Now power the building manually to test recovery
	t221_hab.connected_to_power = true
	assert(t221_hab.is_operational == true, "T2.21: hab must be operational when power is restored")
	assert(t221_hab.status_rim_node.visible == false, "T2.21: status rim must hide when building becomes operational")
	building_mgr.remove_building(t221_hab)
	print("[OK] T2.21: test_unoperational_building_rim_and_opacity пройден (здание непрозрачно, неоновая окантовка мигает красным при отключении)")
	print("--- ВСЕ ТЕСТЫ ЭТАПА 0, 1 И 2 УСПЕШНО ПРОЙДЕНЫ (EXIT 0) ---")
	
	# --- ТЕСТЫ ЭТАПА 3: ОБОРОНИТЕЛЬНЫЕ СИСТЕМЫ ---
	TestDefenseSystem.run_all_tests(main_node)
	
	# --- ТЕСТЫ GUI: МОДУЛЬНЫЙ ДОК И БРУТАЛИСТСКИЙ HUD ---
	await TestHUDModularDock.run_all_tests(main_node)
	
	# --- ТЕСТЫ LINUX & STEAM DECK COMPATIBILITY ---
	TestLinuxCompatibility.run_all_tests(main_node)
	
	print("--- ВСЕ ТЕСТЫ ЭТАПОВ 0, 1, 2, 3, GUI И LINUX/STEAM DECK УСПЕШНО ПРОЙДЕНЫ (EXIT 0) ---")
	get_tree().quit(0)

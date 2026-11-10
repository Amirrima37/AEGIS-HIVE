extends Node

func _ready() -> void:
	print("--- STARTING M3 P2 VERIFICATION PROBE ---")
	
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
	
	assert(bm != null, "BuildingManager not found")
	assert(tm != null, "TickManager not found")
	assert(ds != null, "DefenseSystem not found")
	assert(hud != null, "GameHUD not found")
	assert(lm != null, "LayerManager not found")
	print("[OK] Core systems found and initialized")
	
	# ========================================================
	# 1. Packaging & Ballast Reduction (export_presets.cfg)
	# ========================================================
	print("Checking 1: export_presets.cfg exclude_filter configuration...")
	var export_cfg_file = FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	assert(export_cfg_file != null, "export_presets.cfg not found")
	var export_cfg_content = export_cfg_file.get_as_text()
	export_cfg_file.close()
	
	assert(export_cfg_content.contains("assets/sprites/buildings_backup/*"), "export_presets.cfg missing buildings_backup exclusion")
	assert(export_cfg_content.contains("assets/sprites/buildings_test/*"), "export_presets.cfg missing buildings_test exclusion")
	assert(export_cfg_content.contains("tests/*"), "export_presets.cfg missing tests exclusion")
	assert(export_cfg_content.contains("graphify-out/*"), "export_presets.cfg missing graphify-out exclusion")
	assert(export_cfg_content.contains("scratch/*"), "export_presets.cfg missing scratch exclusion")
	assert(export_cfg_content.contains("assets/ui_build_toolbar_mockup.svg"), "export_presets.cfg missing mockup exclusion")
	assert(export_cfg_content.contains("name=\"Windows Desktop\""), "export_presets.cfg missing Windows Desktop preset")
	assert(export_cfg_content.contains("name=\"Linux/X11\""), "export_presets.cfg missing Linux/X11 preset")
	print("[OK] Packaging configuration verified (exclude_filter excludes non-production ballast on all active presets)")
	
	# ========================================================
	# 2. Repository Hygiene & Tool Relocation
	# ========================================================
	print("Checking 2: Repository hygiene & relocated scratch tools...")
	var gitignore_file = FileAccess.open("res://.gitignore", FileAccess.READ)
	assert(gitignore_file != null, ".gitignore not found")
	var gitignore_text = gitignore_file.get_as_text()
	gitignore_file.close()
	assert(gitignore_text.contains("graphify-out/"), ".gitignore missing graphify-out/")
	assert(gitignore_text.contains("scratch/"), ".gitignore missing scratch/")
	
	assert(FileAccess.file_exists("res://scripts/tools/generate_armor_deck.py"), "Relocated generate_armor_deck.py missing in scripts/tools/")
	assert(FileAccess.file_exists("res://scripts/tools/generate_rotated_and_corners.py"), "Relocated generate_rotated_and_corners.py missing in scripts/tools/")
	assert(not FileAccess.file_exists("res://scratch/generate_armor_deck.py"), "Original scratch/generate_armor_deck.py was not removed")
	assert(not FileAccess.file_exists("res://scratch/generate_rotated_and_corners.py"), "Original scratch/generate_rotated_and_corners.py was not removed")
	
	var norm_file = FileAccess.open("res://scripts/tools/normalize_building_sprites.py", FileAccess.READ)
	assert(norm_file != null, "normalize_building_sprites.py not found")
	var norm_text = norm_file.get_as_text()
	norm_file.close()
	var count_deck = norm_text.count("'armor_deck.png': 2,")
	assert(count_deck == 1, "normalize_building_sprites.py still has duplicate armor_deck.png in SPECS (count=%d)" % count_deck)
	print("[OK] Repository hygiene verified (.gitignore, tools relocated to scripts/tools/, duplicate keys removed)")
	
	# ========================================================
	# 3. All 19 Buildings Geometry & Sprite Validation (T2.11)
	# ========================================================
	print("Checking 3: Validating all 19 buildings from data/buildings/...")
	var catalog = [
		"armor_deck", "autocannon_turret", "command_center", "conveyor",
		"defense_wall", "excavation_rig", "factory", "fusion_reactor",
		"habitation_block", "heavy_railgun", "munitions_factory", "power_cable",
		"quarry", "repair_depot", "sensor_tower", "shaft_elevator",
		"shield_generator", "support_pillar", "warehouse"
	]
	assert(catalog.size() == 19, "Catalog size must be exactly 19")
	var tml_0 = lm.layers[0].tile_map_layer
	for b_id in catalog:
		var b_data = load("res://data/buildings/%s.tres" % b_id) as BuildingData
		assert(b_data != null, "BuildingData missing: %s" % b_id)
		assert(b_data.sprite != null, "Building sprite missing: %s" % b_id)
		var tex = b_data.sprite
		var exp_w = b_data.tile_size.x * 128
		assert(tex.get_width() == exp_w, "Sprite width mismatch for %s: got %d, expected %d" % [b_id, tex.get_width(), exp_w])
		var dummy = Building.new()
		dummy.init(b_data, Vector2i.ZERO, 0, tml_0)
		var expected_offset_y = (b_data.tile_size.x * 32.0 + 3.0) - tex.get_height() * 0.5 + b_data.base_offset_y
		assert(abs(dummy.sprite_node.offset.y - expected_offset_y) < 0.01, "Sprite offset mismatch for %s" % b_id)
		dummy.queue_free()
	print("[OK] All 19 buildings validated for sprite size, texture existence, and isometric grid alignment")
	
	# ========================================================
	# 4. Defense System Test Scenarios (T3.14 - T3.17)
	# ========================================================
	print("Checking 4: Running defense scenarios...")
	var munitions_data = load("res://data/buildings/munitions_factory.tres") as BuildingData
	var armor_deck_data = load("res://data/buildings/armor_deck.tres") as BuildingData
	var exc_data = load("res://data/buildings/excavation_rig.tres") as BuildingData
	var pillar_data = load("res://data/buildings/support_pillar.tres") as BuildingData
	
	# a) Munitions single spend
	GameState.set_game_mode(GameState.GameMode.STANDARD)
	ResourceManager.set_resource("energy", 1000)
	ResourceManager.set_resource("ore", 1000)
	ResourceManager.set_resource("materials", 1000)
	ds.ammo_supply.reset()
	var test_mun = bm.place_building(munitions_data, Vector2i(6, 6), 0)
	assert(test_mun != null, "Probe: Munitions factory placement failed")
	test_mun.connected_to_power = true
	test_mun.connected_to_supply = true
	test_mun.is_operational = true
	ResourceManager.set_resource("energy", 500)
	ResourceManager.set_resource("ore", 100)
	ResourceManager.set_resource("materials", 100)
	ResourceManager.set_resource("ammo", 0)
	tm.run_tick()
	assert(ResourceManager.get_resource("ore") == 98, "Probe: Ore must decrease by exactly 2 (got %d)" % ResourceManager.get_resource("ore"))
	assert(ResourceManager.get_resource("materials") == 99, "Probe: Materials must decrease by 1")
	assert(ResourceManager.get_resource("ammo") == 30, "Probe: Ammo produced must be 30")
	bm.remove_building(test_mun)
	print("[OK] Munitions factory single-spend per tick verified")
	
	# b) Multi-layer stacked armor decks
	ResourceManager.set_resource("energy", 1000)
	ResourceManager.set_resource("ore", 2000)
	ResourceManager.set_resource("materials", 2000)
	if not lm.layers.has(1): lm.create_layer(1)
	if not lm.layers.has(2): lm.create_layer(2)
	var pil0 = bm.place_building(pillar_data, Vector2i(0, 4), 0)
	var pil1 = bm.place_building(pillar_data, Vector2i(0, 4), 1)
	var dpos := Vector2i(4, 4)
	var deck_z1 = bm.place_building(armor_deck_data, dpos, 1)
	var deck_z2 = bm.place_building(armor_deck_data, dpos, 2)
	assert(deck_z1 != null and deck_z2 != null, "Probe: Stacked decks placement failed")
	var rem_dmg = ds.absorb_overhead_damage(0, dpos, 10000)
	assert(rem_dmg == 0, "Probe: Overhead damage not completely absorbed")
	assert(deck_z2.current_hp == 0, "Probe: Upper deck z=2 must absorb first and be destroyed")
	assert(deck_z1.current_hp == 6000, "Probe: Lower deck z=1 must absorb remaining 2000 damage")
	bm.remove_building(deck_z2)
	bm.remove_building(deck_z1)
	if pil1: bm.remove_building(pil1)
	if pil0: bm.remove_building(pil0)
	print("[OK] Multi-layer stacked armor decks sequential absorption verified")
	
	# c) Reverse ammo synchronization
	ds.ammo_supply.reset()
	ResourceManager.set_resource("ammo", 200)
	assert(ds.ammo_supply.ammo_stock == 200, "Probe: AmmoSupply failed to sync with ResourceManager.set_resource")
	ResourceManager.modify_resource("ammo", -75)
	assert(ds.ammo_supply.ammo_stock == 125, "Probe: AmmoSupply failed to sync with ResourceManager.modify_resource")
	assert(ds.ammo_supply.has_ammo(125) == true, "Probe: has_ammo(125) must be true")
	assert(ds.ammo_supply.has_ammo(126) == false, "Probe: has_ammo(126) must be false")
	ds.ammo_supply.reset()
	print("[OK] Reverse ammo synchronization verified")
	
	# d) Excavation rig structural demolition
	ResourceManager.set_resource("energy", 1000)
	ResourceManager.set_resource("ore", 1000)
	ResourceManager.set_resource("materials", 1000)
	assert(exc_data.is_structural == true, "Probe: excavation_rig must have is_structural == true")
	if not lm.layers.has(-1): lm.create_layer(-1)
	var comp1 = lm.validate_structural_integrity()
	assert(comp1.has(-1), "Probe: Layer -1 without rig on z=0 must be compromised")
	var rig = bm.place_building(exc_data, Vector2i(8, 8), 0)
	assert(rig != null, "Probe: Excavation rig placement failed")
	rig.connected_to_power = true
	rig.is_operational = true
	var comp2 = lm.validate_structural_integrity()
	assert(not comp2.has(-1), "Probe: Layer -1 with operational rig on z=0 must not be compromised")
	bm.remove_building(rig)
	var comp3 = lm.get_compromised_layers()
	assert(comp3.has(-1), "Probe: Demolishing excavation rig must flag layer -1 compromised again")
	print("[OK] Excavation rig structural demolition integrity verified")
	
	# ========================================================
	# 5. HUD Verification (Combat ArmorDeck & Resolution Matrix)
	# ========================================================
	print("Checking 5: HUD Combat tab & Resolution Matrix...")
	hud.build_toolbar._category_buttons["defense"].pressed.emit()
	hud.build_toolbar._sub_tab_buttons["combat"].pressed.emit()
	assert(hud.build_toolbar._building_buttons.has(armor_deck_data), "BuildToolbar missing armor_deck button")
	var armor_deck_btn: Button = hud.build_toolbar._building_buttons[armor_deck_data]
	assert(armor_deck_btn.visible == true, "armor_deck button must be visible in combat sub-tab")
	hud.build_toolbar._close_shelf()
	print("[OK] Combat sub-tab contains and shows armor_deck")
	
	var hud_scene = load("res://ui/hud.tscn") as PackedScene
	var res_matrix = [Vector2i(1550, 900), Vector2i(1600, 900), Vector2i(1680, 1050), Vector2i(1920, 900)]
	for res in res_matrix:
		var sv := SubViewport.new()
		sv.size = res
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(sv)
		var test_hud := hud_scene.instantiate() as GameHUD
		sv.add_child(test_hud)
		await get_tree().process_frame
		await get_tree().process_frame
		TestHUDModularDock._assert_no_ui_overlaps(test_hud, Vector2(res.x, res.y), "Probe %dx%d Initial" % [res.x, res.y])
		test_hud.build_toolbar._category_buttons["defense"].pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		TestHUDModularDock._assert_no_ui_overlaps(test_hud, Vector2(res.x, res.y), "Probe %dx%d Shelf Open" % [res.x, res.y])
		sv.queue_free()
	print("[OK] 1550–1920x900 resolution matrix verified with 0 panel overlaps")
	
	print("--- ALL M3 P2 VERIFICATIONS PASSED SUCCESSFULLY (EXIT 0) ---")
	get_tree().quit(0)

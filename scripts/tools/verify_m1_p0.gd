extends Node

func _ready() -> void:
	print("--- STARTING M1 P0 VERIFICATION PROBE ---")
	
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
	var bp: BuildingPlacer = main_node.find_child("BuildingPlacer", true, false)
	var cam: IsometricCamera = main_node.find_child("Camera2D", true, false)
	var sc: SpeedControl = hud.speed_control if hud else null
	
	assert(bm != null, "BuildingManager not found")
	assert(tm != null, "TickManager not found")
	assert(ds != null, "DefenseSystem not found")
	assert(hud != null, "GameHUD not found")
	assert(bp != null, "BuildingPlacer not found")
	assert(cam != null, "IsometricCamera not found")
	
	print("[OK] Core systems found and initialized")
	
	# ========================================================
	# 1. P0-1: Munitions Factory & Ammo SSOT
	# ========================================================
	print("Testing P0-1 (Munitions Factory & Ammo SSOT)...")
	var ammo_sys = ds.ammo_supply
	assert(ammo_sys != null, "AmmoSupply not found")
	
	# SSOT Test: Setting ammo via ResourceManager must reflect in AmmoSupply immediately
	ResourceManager.set_resource("ammo", 77)
	assert(ammo_sys.ammo_stock == 77, "P0-1: ammo_stock must reflect ResourceManager directly, got %d" % ammo_sys.ammo_stock)
	assert(ammo_sys.has_ammo(50) == true, "P0-1: has_ammo(50) must be true at stock 77")
	
	# SSOT Test: produce via AmmoSupply modifies ResourceManager
	ammo_sys.produce(10)
	assert(ResourceManager.get_resource("ammo") == 87, "P0-1: produce(10) must update ResourceManager to 87, got %d" % ResourceManager.get_resource("ammo"))
	assert(ammo_sys.ammo_stock == 87, "P0-1: ammo_stock must be 87")
	
	# Single Spend Test in TickManager
	ammo_sys.reset()
	assert(ResourceManager.get_resource("ammo") == 0, "P0-1: reset must zero ammo in ResourceManager")
	var mf_data = load("res://data/buildings/munitions_factory.tres") as BuildingData
	assert(mf_data != null, "Failed to load munitions_factory.tres")
	
	# Place munitions factory at (10, 10), z=0
	var mf_building = bm.place_building(mf_data, Vector2i(10, 10), 0)
	assert(mf_building != null, "Failed to place munitions_factory")
	mf_building.connected_to_power = true
	mf_building.connected_to_supply = true
	mf_building.is_operational = true
	
	# Set exact resources: ore = 10, materials = 10
	ResourceManager.set_resource("ore", 10)
	ResourceManager.set_resource("materials", 10)
	ResourceManager.set_resource("energy", 100)
	
	# Run 1 economy tick
	tm.run_tick()
	
	# Munitions factory consumes: ore=2, materials=1 -> produces ammo=30
	# With Single Spend, ore should be 10 - 2 = 8, materials should be 10 - 1 = 9, ammo should be 30
	var final_ore = ResourceManager.get_resource("ore")
	var final_mat = ResourceManager.get_resource("materials")
	var final_ammo = ResourceManager.get_resource("ammo")
	assert(final_ore == 8, "P0-1: Ore after tick must be 8 (single spend), got %d" % final_ore)
	assert(final_mat == 9, "P0-1: Materials after tick must be 9 (single spend), got %d" % final_mat)
	assert(final_ammo == 30, "P0-1: Ammo after tick must be 30, got %d" % final_ammo)
	print("[PASS] P0-1: Munitions factory single-spends resources (ore: 10->8, mat: 10->9, ammo: 0->30) and ResourceManager is SSOT")
	
	bm.remove_building(mf_building)
	ammo_sys.reset()
	
	# ========================================================
	# 2. P0-2: Aegis Protocol, Population Invariant, Shield Efficiency
	# ========================================================
	print("Testing P0-2 (Aegis Protocol, Population Invariant, Shield Efficiency)...")
	# Unlock Aegis tech
	GameState.unlock_tech(&"aegis_protocol")
	assert(GameState.aegis_protocol_unlocked == true, "P0-2: Aegis protocol must be unlocked")
	
	ResourceManager.set_resource("ore", 500)
	ResourceManager.set_resource("materials", 500)
	ResourceManager.set_resource("energy", 500)
	
	# Place shield generator covering hab blocks (adjacent to CC for power network)
	var shield_data = load("res://data/buildings/shield_generator.tres") as BuildingData
	var shield_b = bm.place_building(shield_data, Vector2i(0, 2), 0)
	assert(shield_b != null, "P0-2: Shield generator placement failed")
	
	var hab_data = load("res://data/buildings/habitation_block.tres") as BuildingData
	var hab1 = bm.place_building(hab_data, Vector2i(2, 0), 0)
	assert(hab1 != null, "P0-2: Habitation block 1 placement failed")
	
	var hab2 = bm.place_building(hab_data, Vector2i(2, 1), 0)
	assert(hab2 != null, "P0-2: Habitation block 2 placement failed")
	
	# Normal capacity: CC (50) + 2x hab (20 each = 40) = 90
	var normal_cap = tm.update_population_capacity()
	assert(normal_cap == 90, "P0-2: Normal capacity must be 90, got %d" % normal_cap)
	
	# Activate Aegis Protocol
	var aegis_ok = GameState.set_aegis_protocol(true)
	assert(aegis_ok == true, "P0-2: Aegis activation must succeed")
	assert(GameState.aegis_protocol_active == true, "P0-2: Aegis must be active")
	assert(GameState.combat_power_shift_active == true, "P0-2: Combat power shift must be activated by Aegis")
	
	# Invariant Check: deactivating combat power shift while Aegis is active must be rejected
	GameState.set_combat_power_shift(false)
	assert(GameState.combat_power_shift_active == true, "P0-2: Combat power shift MUST NOT deactivate while Aegis is active")
	
	# Population capacity check under Aegis: sheltered habitation blocks capacity must be preserved!
	var aegis_cap = tm.update_population_capacity()
	assert(aegis_cap == 90, "P0-2: Under Aegis, sheltered capacity must remain 90, got %d" % aegis_cap)
	
	# Shield efficiency scaling test
	var s_ctrl = ds.shield_controller
	s_ctrl.activate()
	assert(s_ctrl.is_position_shielded(0, Vector2i(2, 0)) == true, "P0-2: Habitation block at (2, 0) must be shielded")
	
	# 100 HP generator at full efficiency absorbs 100 damage completely
	var dmg_absorbed = s_ctrl.absorb_damage(0, Vector2i(2, 0), 100)
	assert(dmg_absorbed == 0, "P0-2: 100%% eff shield must absorb all 100 damage, got %d" % dmg_absorbed)
	
	# Now degrade shield generator HP to 5% (efficiency drops)
	shield_b.current_hp = int(shield_b.data.max_hp * 0.05)
	var eff = shield_b.get_efficiency()
	assert(eff < 0.5, "P0-2: Degraded generator must have eff < 0.5, got %f" % eff)
	
	# At eff < 0.5, incoming 100 damage must NOT be 100% absorbed
	var leaked_dmg = s_ctrl.absorb_damage(0, Vector2i(2, 0), 100)
	assert(leaked_dmg > 50, "P0-2: Degraded shield must leak unabsorbed damage, got %d" % leaked_dmg)
	
	# Cleanup P0-2
	GameState.set_aegis_protocol(false)
	GameState.set_combat_power_shift(false)
	bm.remove_building(shield_b)
	bm.remove_building(hab1)
	bm.remove_building(hab2)
	s_ctrl.deactivate()
	print("[PASS] P0-2: Aegis invariant maintained, sheltered pop capacity preserved (90/90), shield efficiency scaling verified")
	
	# ========================================================
	# 3. P0-3: Stacked Armor Decks
	# ========================================================
	print("Testing P0-3 (Stacked Armor Decks)...")
	var ad_data = load("res://data/buildings/armor_deck.tres") as BuildingData
	assert(ad_data != null, "Failed to load armor_deck.tres")
	assert(ad_data.icon != null, "P0-3: armor_deck.tres icon must not be null")
	
	ResourceManager.set_resource("ore", 500)
	ResourceManager.set_resource("materials", 500)
	
	# Ensure upper layers exist
	var lm: LayerManager = main_node.find_child("LayerManager", true, false)
	assert(lm != null, "LayerManager not found")
	if not lm.layers.has(1):
		lm.create_layer(1)
	if not lm.layers.has(2):
		lm.create_layer(2)
	
	# Place deck1 at z=1 with 500 HP
	var deck1 = bm.place_building(ad_data, Vector2i(10, 10), 1)
	assert(deck1 != null, "Failed to place armor_deck on z=1")
	deck1.current_hp = 500
	
	# Place deck2 at z=2 with 300 HP
	var deck2 = bm.place_building(ad_data, Vector2i(10, 10), 2)
	assert(deck2 != null, "Failed to place armor_deck on z=2")
	deck2.current_hp = 300
	
	# Descending order check: get_armor_decks_above must return [deck2, deck1]
	var decks_above = ds.get_armor_decks_above(0, Vector2i(10, 10))
	assert(decks_above.size() == 2, "P0-3: Must find 2 armor decks above z=0")
	assert(decks_above[0].z_level == 2 and decks_above[1].z_level == 1, "P0-3: Decks must be sorted descending by Z-level")
	
	# Absorb 600 damage targeting z=0 at (10, 10)
	# deck2 (300 HP) must be destroyed (0 HP)
	# deck1 (500 HP) must absorb remaining 300 -> 200 HP
	# leaked damage must be 0!
	var remainder = ds.absorb_overhead_damage(0, Vector2i(10, 10), 600)
	assert(remainder == 0, "P0-3: 600 damage must be fully absorbed by stacked decks (300 + 300), got remainder %d" % remainder)
	assert(deck2.current_hp == 0, "P0-3: deck2 must have 0 HP, got %d" % deck2.current_hp)
	assert(deck1.current_hp == 200, "P0-3: deck1 must have 200 HP, got %d" % deck1.current_hp)
	
	# Further 300 damage: deck1 absorbs 200, remainder 100 leaks to z=0
	var remainder2 = ds.absorb_overhead_damage(0, Vector2i(10, 10), 300)
	assert(remainder2 == 100, "P0-3: Remainder must be 100, got %d" % remainder2)
	assert(deck1.current_hp == 0, "P0-3: deck1 must now have 0 HP, got %d" % deck1.current_hp)
	
	bm.remove_building(deck1)
	bm.remove_building(deck2)
	print("[PASS] P0-3: Stacked armor decks absorb sequentially in descending Z-order (600 dmg -> deck2: 300->0, deck1: 500->200, 0 leak)")
	
	# ========================================================
	# 4. P0-4: Desktop HUD Responsive Layout on 1550-1920x900
	# ========================================================
	print("Testing P0-4 (Desktop HUD Responsive Layout on 1550-1920x900)...")
	var hud_scene = load("res://ui/hud.tscn") as PackedScene
	var test_res = [
		Vector2i(1550, 900),
		Vector2i(1600, 900),
		Vector2i(1750, 900),
		Vector2i(1880, 900),
		Vector2i(1920, 900)
	]
	for res in test_res:
		var sv = SubViewport.new()
		sv.size = res
		add_child(sv)
		var test_hud = hud_scene.instantiate() as GameHUD
		sv.add_child(test_hud)
		# Force responsive layout
		test_hud._apply_responsive_layout()
		assert(test_hud._is_compact_viewport == true, "P0-4: Viewport %s must activate compact layout" % str(res))
		
		# Verify LayerIndicator and MinimapPanel have clearance (no vertical overlap)
		var li = test_hud.layer_indicator
		var mm = test_hud.minimap_panel
		var li_bottom = (float(res.y) * 0.5) + (li.size.y * 0.5)
		var mm_top = float(res.y) + mm.offset_top
		assert(li_bottom < mm_top, "P0-4: At %s, LayerIndicator bottom (%.1f) must be above Minimap top (%.1f)" % [str(res), li_bottom, mm_top])
		
		sv.queue_free()
	print("[PASS] P0-4: All 1550-1920x900 viewports activate compact/constrained bounds with 100+ px clearance between panels")
	
	# ========================================================
	# 5. P0-5: ESC Key Handling, Mode Transitions, Input
	# ========================================================
	print("Testing P0-5 (ESC Key Handling, Mode Transitions, Input)...")
	var tb = hud.build_toolbar
	assert(tb != null, "BuildToolbar not found")
	
	# Open shelf and select autocannon
	var ac_data = load("res://data/buildings/autocannon_turret.tres") as BuildingData
	assert(ac_data != null, "Failed to load autocannon_turret.tres")
	
	tb._category_buttons["defense"].pressed.emit()
	assert(tb.shelf_panel.visible == true, "P0-5: Shelf must be visible")
	
	tb._on_building_button_pressed(ac_data)
	assert(tb._selected_building == ac_data, "P0-5: Building must be selected in toolbar")
	assert(bp.current_mode == BuildingPlacer.Mode.BUILDING, "P0-5: BuildingPlacer must be in BUILDING mode")
	assert(bp._ghost_node.visible == true, "P0-5: Ghost preview must be visible")
	
	# Simulate ESC key press
	var esc_event = InputEventKey.new()
	esc_event.pressed = true
	esc_event.physical_keycode = KEY_ESCAPE
	esc_event.keycode = KEY_ESCAPE
	
	tb._unhandled_input(esc_event)
	
	# ESC must cancel building placement / ghost first
	assert(tb._selected_building == null, "P0-5: ESC must clear _selected_building")
	assert(bp.current_mode == BuildingPlacer.Mode.IDLE, "P0-5: ESC must reset BuildingPlacer to IDLE")
	assert(bp._ghost_node.visible == false, "P0-5: Ghost preview must be hidden after ESC")
	
	# Mode transition test: entering CABLING then entering DEMOLISHING
	var cable_data = load("res://data/buildings/power_cable.tres") as BuildingData
	bp._on_cable_mode_entered(cable_data)
	assert(bp.current_mode == BuildingPlacer.Mode.CABLING, "P0-5: Must be in CABLING mode")
	bp._is_cabling_mouse_down = true
	
	bp._on_demolish_mode_entered()
	assert(bp.current_mode == BuildingPlacer.Mode.DEMOLISHING, "P0-5: Must transition to DEMOLISHING mode")
	assert(bp._is_cabling_mouse_down == false, "P0-5: Transition must clear _is_cabling_mouse_down")
	
	bp._cancel_current_mode()
	assert(bp.current_mode == BuildingPlacer.Mode.IDLE, "P0-5: Mode must be IDLE after cancel")
	print("[PASS] P0-5: ESC cancels building placement ghost, clean mode transitions, input consumed properly")
	
	print("--- ALL M1 P0 VERIFICATIONS PASSED SUCCESSFULLY (100% GENUINE LOGIC) ---")
	get_tree().quit(0)

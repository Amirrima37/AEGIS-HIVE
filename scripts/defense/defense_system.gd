class_name DefenseSystem
extends Node2D

signal turret_fired(turret_id: Variant, target_id: Variant)
signal shield_depleted()
signal wall_destroyed(building_id: Variant)

@export var building_manager: BuildingManager = null
@export var network_manager: NetworkManager = null

var turret_manager: TurretManager = null
var shield_controller: ShieldController = null
var ammo_supply: AmmoSupply = null
var repair_depot: RepairDepot = null

func _ready() -> void:
	_find_managers()
	_setup_subsystems()
	_connect_events()

func _find_managers() -> void:
	if building_manager == null and is_inside_tree():
		building_manager = get_tree().root.find_child("BuildingManager", true, false)
	if network_manager == null and is_inside_tree():
		network_manager = get_tree().root.find_child("NetworkManager", true, false)

func init(p_building_manager: BuildingManager, p_network_manager: NetworkManager = null) -> void:
	building_manager = p_building_manager
	network_manager = p_network_manager
	_setup_subsystems()

func _setup_subsystems() -> void:
	if ammo_supply == null:
		ammo_supply = AmmoSupply.new(building_manager)
		ammo_supply.name = "AmmoSupply"
		add_child(ammo_supply)
	else:
		ammo_supply.building_manager = building_manager
		
	if turret_manager == null:
		turret_manager = TurretManager.new(building_manager, ammo_supply)
		turret_manager.name = "TurretManager"
		add_child(turret_manager)
	else:
		turret_manager.building_manager = building_manager
		turret_manager.ammo_supply = ammo_supply
		
	if shield_controller == null:
		shield_controller = ShieldController.new(building_manager, network_manager)
		shield_controller.name = "ShieldController"
		add_child(shield_controller)
	else:
		shield_controller.building_manager = building_manager
		shield_controller.network_manager = network_manager
		
	if repair_depot == null:
		repair_depot = RepairDepot.new(building_manager)
		repair_depot.name = "RepairDepot"
		add_child(repair_depot)
	else:
		repair_depot.building_manager = building_manager

func _connect_events() -> void:
	if EventBus:
		if EventBus.has_signal("enemy_wave_start"):
			EventBus.enemy_wave_start.connect(_on_enemy_wave_start)
		if EventBus.has_signal("base_under_attack"):
			EventBus.base_under_attack.connect(_on_base_under_attack)
		if EventBus.has_signal("wall_destroyed"):
			EventBus.wall_destroyed.connect(func(w): wall_destroyed.emit(w))
		if EventBus.has_signal("shield_depleted"):
			EventBus.shield_depleted.connect(func(): shield_depleted.emit())
		if EventBus.has_signal("turret_fired"):
			EventBus.turret_fired.connect(func(t, target): turret_fired.emit(t, target))
		if EventBus.has_signal("tick"):
			EventBus.tick.connect(_on_tick)

func _on_enemy_wave_start(_wave_index: int) -> void:
	if shield_controller:
		shield_controller.activate()

func _on_base_under_attack(pos: Vector2, z: int) -> void:
	# Оповещение тактической системы обороны о секторе атаки
	pass

func _on_tick(_tick_count: int) -> void:
	# RepairDepot._process handles frame-rate-scaled repair ticks; avoid double-healing on discrete ticks
	if ammo_supply:
		ammo_supply.process_factories()

## Периодический цикл логистики обороны (для детерминированных тестов и пакетных тиков)
func tick(delta: float) -> void:
	if ammo_supply:
		ammo_supply.process_factories()
	if repair_depot:
		repair_depot.run(delta)

## Возвращает живую Бронепалубу с любого яруса выше target_z, перекрывающую клетку grid_pos
func get_armor_deck_at(target_z: int, grid_pos: Vector2i) -> Building:
	_find_managers()
	if building_manager == null:
		return null
	var best_deck: Building = null
	var highest_z := -999999
	for b in building_manager.get_all_buildings():
		if not is_instance_valid(b) or b.data == null or b.current_hp <= 0:
			continue
		if b.z_level <= target_z:
			continue
		if b.data.defense_role != "armor_deck" and b.data.id != &"armor_deck":
			continue
		var origin = b.grid_position
		var sz = b.data.tile_size
		if grid_pos.x >= origin.x and grid_pos.x < origin.x + sz.x and grid_pos.y >= origin.y and grid_pos.y < origin.y + sz.y:
			if b.z_level > highest_z:
				highest_z = b.z_level
				best_deck = b
	return best_deck

func is_position_armor_covered(target_z: int, grid_pos: Vector2i) -> bool:
	return get_armor_deck_at(target_z, grid_pos) != null

## Перехватывает урон от атак сверху (кислотный дождь / воздушный обстрел) бронепалубой
func absorb_overhead_damage(target_z: int, grid_pos: Vector2i, damage: int) -> int:
	if damage <= 0:
		return 0
	var deck = get_armor_deck_at(target_z, grid_pos)
	if deck == null or not is_instance_valid(deck) or deck.current_hp <= 0:
		return damage
	var absorbed = min(deck.current_hp, damage)
	deck.take_damage(absorbed)
	return max(0, damage - absorbed)

func get_layer_armor_decks_protecting(target_z: int) -> Array[Building]:
	var result: Array[Building] = []
	_find_managers()
	if building_manager == null:
		return result
	for b in building_manager.get_all_buildings():
		if not is_instance_valid(b) or b.data == null or b.current_hp <= 0:
			continue
		if b.z_level > target_z and (b.data.defense_role == "armor_deck" or b.data.id == &"armor_deck"):
			result.append(b)
	return result

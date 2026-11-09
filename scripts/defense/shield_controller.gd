class_name ShieldController
extends Node2D

signal shield_depleted()

var building_manager: BuildingManager = null
var network_manager: NetworkManager = null

var is_active: bool = false
var energy_per_sec: float = 2.0
var shield_radius: float = 6.0 # В тайлах

# Хранилище визуальных эффектов куполов
var _dome_nodes: Dictionary = {} # Building -> Node2D

func _init(p_building_manager: BuildingManager = null, p_network_manager: NetworkManager = null) -> void:
	building_manager = p_building_manager
	network_manager = p_network_manager

func _get_building_manager() -> BuildingManager:
	if building_manager and is_instance_valid(building_manager):
		return building_manager
	if is_inside_tree():
		building_manager = get_tree().root.find_child("BuildingManager", true, false)
		return building_manager
	return null

func _ready() -> void:
	if EventBus:
		if EventBus.has_signal("enemy_wave_start"):
			EventBus.enemy_wave_start.connect(func(_idx): activate())
		if EventBus.has_signal("enemy_wave_ended"):
			EventBus.enemy_wave_ended.connect(_on_wave_ended)
		if EventBus.has_signal("aegis_protocol_toggled"):
			EventBus.aegis_protocol_toggled.connect(_on_aegis_toggled)
		if EventBus.has_signal("network_updated"):
			EventBus.network_updated.connect(func(_t): _refresh_domes_if_active())
		if EventBus.has_signal("building_placed"):
			EventBus.building_placed.connect(func(_b): _refresh_domes_if_active())
		EventBus.building_removed.connect(_on_building_removed)

func _on_wave_ended(_idx: int) -> void:
	# Under active Aegis Protocol, shields remain forced in readiness even between waves
	if GameState and GameState.aegis_protocol_active:
		activate()
		return
	deactivate()

func _on_aegis_toggled(active: bool) -> void:
	if active:
		activate()
	else:
		deactivate()

func _refresh_domes_if_active() -> void:
	if is_active:
		_update_domes()

func activate() -> void:
	is_active = true
	_update_domes()

func deactivate() -> void:
	is_active = false
	_clear_domes()

func _on_building_removed(b: Node2D) -> void:
	if _dome_nodes.has(b):
		if is_instance_valid(_dome_nodes[b]):
			_dome_nodes[b].queue_free()
		_dome_nodes.erase(b)

func get_active_generators(z: int = -999) -> Array[Building]:
	var result: Array[Building] = []
	var bm = _get_building_manager()
	if bm == null:
		return result
	var list = bm.get_all_buildings() if z == -999 else bm.get_buildings_on_layer(z)
	for b in list:
		if not is_instance_valid(b) or b.data == null or b.current_hp <= 0:
			continue
		if b.data.defense_role == "shield" or b.data.id == &"shield_generator":
			if b.is_operational and b.connected_to_power:
				result.append(b)
	return result

## Проверка, находится ли позиция под защитой силового купола
func is_position_shielded(z: int, grid_pos: Vector2i) -> bool:
	if not is_active:
		return false
	var generators = get_active_generators(z)
	for gen in generators:
		var rad = gen.data.shield_radius if gen.data.shield_radius > 0.0 else shield_radius
		var center = Vector2(gen.grid_position) + Vector2(gen.data.tile_size) * 0.5
		if center.distance_to(Vector2(grid_pos)) <= rad:
			return true
	return false

## Поглощение входящего урона щитом. Возвращает остаточный непоглощенный урон.
func absorb_damage(z: int, grid_pos: Vector2i, damage: int) -> int:
	if not is_active:
		return damage
		
	var generators = get_active_generators(z)
	if generators.is_empty():
		shield_depleted.emit()
		if EventBus and EventBus.has_signal("shield_depleted"):
			EventBus.shield_depleted.emit()
		return damage
		
	for gen in generators:
		var rad = gen.data.shield_radius if gen.data.shield_radius > 0.0 else shield_radius
		var center = Vector2(gen.grid_position) + Vector2(gen.data.tile_size) * 0.5
		if center.distance_to(Vector2(grid_pos)) <= rad:
			# Урон полностью рассеян силовым полем
			_flash_shield_visual(gen)
			return 0
			
	return damage

func _flash_shield_visual(gen: Building) -> void:
	if _dome_nodes.has(gen) and is_instance_valid(_dome_nodes[gen]):
		var dome = _dome_nodes[gen]
		var tween = create_tween()
		tween.tween_property(dome, "modulate:a", 1.0, 0.05)
		tween.tween_property(dome, "modulate:a", 0.4, 0.3)

func _update_domes() -> void:
	if not is_inside_tree() or not is_active:
		return
	var active_gens = get_active_generators()
	for old_gen in _dome_nodes.keys():
		if not active_gens.has(old_gen) or not is_instance_valid(old_gen):
			if is_instance_valid(_dome_nodes[old_gen]):
				_dome_nodes[old_gen].queue_free()
			_dome_nodes.erase(old_gen)
	for gen in active_gens:
		if not _dome_nodes.has(gen):
			var dome = Node2D.new()
			dome.name = "ShieldDome"
			dome.z_index = 5
			dome.modulate.a = 0.45
			dome.draw.connect(func():
				if not is_instance_valid(gen) or gen.data == null:
					return
				var rad_px = (gen.data.shield_radius if gen.data.shield_radius > 0.0 else shield_radius) * 64.0
				# Dimetric 2:1 isometric projection ellipse matching world grid
				dome.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
				dome.draw_arc(Vector2.ZERO, rad_px, 0, TAU, 48, Color(0.2, 0.78, 1.0, 0.85), 2.5, true)
				dome.draw_circle(Vector2.ZERO, rad_px, Color(0.1, 0.55, 0.95, 0.16))
				dome.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			)
			gen.add_child(dome)
			_dome_nodes[gen] = dome

func _clear_domes() -> void:
	for gen in _dome_nodes.keys():
		if is_instance_valid(_dome_nodes[gen]):
			_dome_nodes[gen].queue_free()
	_dome_nodes.clear()

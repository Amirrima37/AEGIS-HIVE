class_name TurretManager
extends Node2D

signal turret_fired(turret: Node2D, target: Variant)

var building_manager: BuildingManager = null
var ammo_supply: AmmoSupply = null

# Cooldown tracking: Building -> float (seconds remaining until next shot)
var _cooldowns: Dictionary = {}

func _init(p_building_manager: BuildingManager = null, p_ammo_supply: AmmoSupply = null) -> void:
	building_manager = p_building_manager
	ammo_supply = p_ammo_supply

func _get_building_manager() -> BuildingManager:
	if building_manager and is_instance_valid(building_manager):
		return building_manager
	if is_inside_tree():
		building_manager = get_tree().root.find_child("BuildingManager", true, false)
		return building_manager
	return null

func _get_ammo_supply() -> AmmoSupply:
	if ammo_supply and is_instance_valid(ammo_supply):
		return ammo_supply
	var p = get_parent()
	if p and "ammo_supply" in p and p.ammo_supply != null:
		ammo_supply = p.ammo_supply
		return ammo_supply
	if is_inside_tree():
		var found = get_tree().root.find_child("AmmoSupply", true, false)
		if found is AmmoSupply:
			ammo_supply = found
			return ammo_supply
	return null

func _process(delta: float) -> void:
	# Tick down weapon cooldowns
	var to_erase: Array = []
	for turret in _cooldowns.keys():
		if not is_instance_valid(turret):
			to_erase.append(turret)
			continue
		_cooldowns[turret] -= delta
		if _cooldowns[turret] <= 0.0:
			to_erase.append(turret)
			
	for t in to_erase:
		_cooldowns.erase(t)

func get_all_turrets() -> Array[Building]:
	var result: Array[Building] = []
	var bm = _get_building_manager()
	if bm == null:
		return result
	for b in bm.get_all_buildings():
		if not is_instance_valid(b) or b.data == null:
			continue
		if b.data.defense_role in ["turret", "railgun"] or b.data.id in [&"autocannon_turret", &"heavy_railgun"]:
			result.append(b)
	return result

func can_fire(turret: Building) -> bool:
	if not is_instance_valid(turret) or turret.data == null or turret.current_hp <= 0:
		return false
	if not turret.connected_to_power:
		return false
	if _cooldowns.has(turret) and _cooldowns[turret] > 0.0:
		return false
	var ammo_needed = turret.data.ammo_consumption_per_shot
	var asup = _get_ammo_supply()
	if asup and not asup.has_ammo(ammo_needed):
		return false
	return true

## Вычисляет эффективную дальность турели с учетом сенсорных вышек
func get_effective_range(turret: Building) -> float:
	if turret.data == null:
		return 0.0
	var base_range = turret.data.attack_range
	# Бонус сенсорной вышки (+20% к дальности при наличии активной вышки на ярусе)
	var bm = _get_building_manager()
	if bm:
		for b in bm.get_buildings_on_layer(turret.z_level):
			if is_instance_valid(b) and b.connected_to_power and b.current_hp > 0 and b.data and b.data.defense_role == "sensor":
				var dist = Vector2(turret.grid_position).distance_to(Vector2(b.grid_position))
				if dist <= b.data.sensor_radius:
					return base_range * 1.2
	return base_range

## Поиск ближайшей цели в радиусе поражения
func find_nearest_target(turret: Building, targets: Array) -> Variant:
	if not is_instance_valid(turret):
		return null
	var max_range = get_effective_range(turret)
	var turret_pos = Vector2(turret.grid_position)
	var best_target = null
	var best_dist = INF
	
	for target in targets:
		if target == null:
			continue
		# Validate HP
		if typeof(target) == TYPE_DICTIONARY:
			if target.has("current_hp") and target["current_hp"] <= 0:
				continue
			if target.has("hp") and target["hp"] <= 0:
				continue
		elif target is Object:
			if "current_hp" in target and target.current_hp <= 0:
				continue
			if "hp" in target and target.hp <= 0:
				continue
			
		var target_pos: Vector2
		var target_z: int = turret.z_level
		if typeof(target) == TYPE_DICTIONARY:
			if target.has("grid_position"):
				target_pos = Vector2(target["grid_position"])
			elif target.has("position"):
				target_pos = target["position"]
			else:
				continue
			if target.has("z_level"):
				target_z = target["z_level"]
		elif target is Object:
			if "grid_position" in target:
				target_pos = Vector2(target.grid_position)
			elif "position" in target:
				target_pos = target.position
			else:
				continue
			if "z_level" in target:
				target_z = target.z_level
		else:
			continue
			
		if target_z != turret.z_level:
			continue # Разные слои
			
		var d = turret_pos.distance_to(target_pos)
		if d <= max_range and d < best_dist:
			best_dist = d
			best_target = target
			
	return best_target

## Совершить выстрел по указанной цели
func fire(turret: Building, target: Variant) -> bool:
	if not can_fire(turret):
		return false
	if target == null:
		return false
		
	var ammo_needed = turret.data.ammo_consumption_per_shot
	var asup = _get_ammo_supply()
	if asup and not asup.consume(ammo_needed):
		return false
		
	# Apply damage
	var dmg = int(turret.data.attack_damage)
	if target is Object and target.has_method("take_damage"):
		target.take_damage(dmg)
	elif target is Object and "hp" in target:
		target.hp = max(0, target.hp - dmg)
		if "current_hp" in target:
			target.current_hp = max(0, target.current_hp - dmg)
	elif typeof(target) == TYPE_DICTIONARY:
		if target.has("hp"):
			target["hp"] = max(0, target["hp"] - dmg)
		if target.has("current_hp"):
			target["current_hp"] = max(0, target["current_hp"] - dmg)
			
	# Set cooldown
	var rate = turret.data.attack_rate
	var cooldown = 1.0 / rate if rate > 0.0 else 1.0
	_cooldowns[turret] = cooldown
	
	# Visual tracer line if both in tree
	_draw_tracer(turret, target)
	
	turret_fired.emit(turret, target)
	if EventBus and EventBus.has_signal("turret_fired"):
		EventBus.turret_fired.emit(turret, target)
		
	return true

func _draw_tracer(turret: Building, target: Variant) -> void:
	if not is_inside_tree():
		return
	var from_pos = turret.global_position
	var to_pos = from_pos
	if target is Node2D:
		to_pos = target.global_position
	elif target is Object and "global_position" in target:
		to_pos = target.global_position
	
	var line = Line2D.new()
	line.width = 2.5 if turret.data.defense_role == "railgun" else 1.5
	line.default_color = Color(0.2, 0.9, 1.0, 0.9) if turret.data.defense_role == "railgun" else Color(1.0, 0.8, 0.2, 0.8)
	line.add_point(from_pos)
	line.add_point(to_pos)
	get_tree().root.add_child(line)
	
	var tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)

## Сканирование и залп всех готовых турелей по целям
func scan_and_fire_all(targets: Array) -> int:
	var shots_fired = 0
	for turret in get_all_turrets():
		if can_fire(turret):
			var target = find_nearest_target(turret, targets)
			if target != null:
				if fire(turret, target):
					shots_fired += 1
	return shots_fired

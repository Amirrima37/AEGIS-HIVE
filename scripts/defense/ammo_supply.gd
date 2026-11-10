class_name AmmoSupply
extends Node

signal ammo_changed(new_amount: int)

var ammo_stock: int:
	get:
		if ResourceManager:
			return ResourceManager.get_resource("ammo")
		return _fallback_ammo_stock
	set(val):
		var clamped = max(0, val)
		if ResourceManager:
			ResourceManager.set_resource("ammo", clamped)
		else:
			_fallback_ammo_stock = clamped
			ammo_changed.emit(_fallback_ammo_stock)

var _fallback_ammo_stock: int = 0
var building_manager: BuildingManager = null

func _init(p_building_manager: BuildingManager = null) -> void:
	building_manager = p_building_manager
	if EventBus and EventBus.has_signal("resource_changed"):
		if not EventBus.resource_changed.is_connected(_on_resource_changed):
			EventBus.resource_changed.connect(_on_resource_changed)

func _on_resource_changed(res_name: String, amount: int) -> void:
	if res_name == "ammo":
		ammo_changed.emit(amount)

func _get_building_manager() -> BuildingManager:
	if building_manager and is_instance_valid(building_manager):
		return building_manager
	if is_inside_tree():
		building_manager = get_tree().root.find_child("BuildingManager", true, false)
		return building_manager
	return null

func produce(amount: int) -> void:
	if amount <= 0:
		return
	if ResourceManager:
		ResourceManager.modify_resource("ammo", amount)
	else:
		_fallback_ammo_stock += amount
		ammo_changed.emit(_fallback_ammo_stock)

func consume(amount: int) -> bool:
	if GameState and GameState.has_method("is_unlimited_mode") and GameState.is_unlimited_mode():
		return true
	if has_ammo(amount):
		if ResourceManager:
			ResourceManager.modify_resource("ammo", -amount)
		else:
			_fallback_ammo_stock -= amount
			ammo_changed.emit(_fallback_ammo_stock)
		return true
	return false

func has_ammo(amount: int = 1) -> bool:
	if GameState and GameState.has_method("is_unlimited_mode") and GameState.is_unlimited_mode():
		return true
	return ammo_stock >= amount

func reset() -> void:
	if ResourceManager:
		ResourceManager.set_resource("ammo", 0)
	else:
		_fallback_ammo_stock = 0
		ammo_changed.emit(0)

## Цикл производства патронов на фабриках боеприпасов
func process_factories() -> int:
	var bm = _get_building_manager()
	if bm == null:
		return 0
	var produced_total = 0
	var all_buildings = bm.get_all_buildings()
	for b in all_buildings:
		if not is_instance_valid(b) or b.data == null or b.current_hp <= 0:
			continue
		if not b.is_operational or not b.connected_to_power or not b.connected_to_supply:
			continue
		if b.data.id == &"munitions_factory" or b.data.defense_role == "munitions":
			var eff = b.get_efficiency() if b.has_method("get_efficiency") else 1.0
			if eff <= 0.0:
				continue
			var ore_cost = b.data.ore_consumption
			var mat_cost = b.data.materials_consumption
			if ResourceManager.can_afford({"ore": ore_cost, "materials": mat_cost}):
				ResourceManager.spend({"ore": ore_cost, "materials": mat_cost})
				var base_prod = b.data.ammo_production if b.data.ammo_production > 0 else 30
				var prod = int(floor(float(base_prod) * eff))
				if prod > 0:
					produce(prod)
					produced_total += prod
	return produced_total

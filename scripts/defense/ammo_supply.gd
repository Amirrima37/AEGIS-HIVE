class_name AmmoSupply
extends Node

signal ammo_changed(new_amount: int)

var ammo_stock: int = 0:
	set(val):
		ammo_stock = max(0, val)
		ammo_changed.emit(ammo_stock)
		if EventBus and EventBus.has_signal("resource_changed"):
			EventBus.resource_changed.emit("ammo", ammo_stock)

var building_manager: BuildingManager = null

func _init(p_building_manager: BuildingManager = null) -> void:
	building_manager = p_building_manager

func _get_building_manager() -> BuildingManager:
	if building_manager and is_instance_valid(building_manager):
		return building_manager
	if is_inside_tree():
		building_manager = get_tree().root.find_child("BuildingManager", true, false)
		return building_manager
	return null

func produce(amount: int) -> void:
	ammo_stock += amount

func consume(amount: int) -> bool:
	if ammo_stock >= amount:
		ammo_stock -= amount
		return true
	return false

func has_ammo(amount: int = 1) -> bool:
	return ammo_stock >= amount

func reset() -> void:
	ammo_stock = 0

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
		if not b.connected_to_power:
			continue
		if b.data.id == &"munitions_factory" or b.data.defense_role == "munitions":
			var ore_cost = b.data.ore_consumption
			var mat_cost = b.data.materials_consumption
			if ResourceManager.can_afford({"ore": ore_cost, "materials": mat_cost}):
				ResourceManager.spend({"ore": ore_cost, "materials": mat_cost})
				var prod = b.data.ammo_production if b.data.ammo_production > 0 else 30
				produce(prod)
				produced_total += prod
	return produced_total

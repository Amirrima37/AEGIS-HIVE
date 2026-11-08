extends Node

var resources: Dictionary = {
	"energy": 100,
	"ore": 50,
	"materials": 30,
	"population": 10,
	"population_capacity": 50
}

func get_resource(res_name: String) -> int:
	return resources.get(res_name, 0)

func modify_resource(res_name: String, delta: int) -> void:
	if not resources.has(res_name):
		resources[res_name] = 0
	resources[res_name] = max(0, int(resources[res_name] + delta))
	EventBus.resource_changed.emit(res_name, resources[res_name])

func set_resource(res_name: String, amount: int) -> void:
	resources[res_name] = max(0, int(amount))
	EventBus.resource_changed.emit(res_name, resources[res_name])

func can_afford(costs: Dictionary) -> bool:
	if GameState and GameState.is_unlimited_mode():
		return true
	for res in costs.keys():
		var amount = int(costs[res])
		if amount > 0 and resources.get(str(res), 0) < amount:
			return false
	return true

func spend(costs: Dictionary) -> bool:
	if GameState and GameState.is_unlimited_mode():
		return true
	for res in costs.keys():
		var amount = int(costs[res])
		if amount > 0 and resources.get(str(res), 0) < amount:
			EventBus.insufficient_resources.emit(str(res))
			return false
	
	for res in costs.keys():
		var amount = int(costs[res])
		if amount > 0:
			modify_resource(str(res), -amount)
	return true

func produce(yields: Dictionary) -> void:
	for res in yields.keys():
		var amount = int(yields[res])
		if amount > 0:
			modify_resource(str(res), amount)

func get_all() -> Dictionary:
	return resources.duplicate()

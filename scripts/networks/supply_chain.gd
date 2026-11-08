class_name SupplyChain
extends NetworkGraph

@export var shaft_elevator: ShaftElevator = null
@export var occupancy: OccupancyGrid = null

func is_supply_conductor(b: Building) -> bool:
	if not is_instance_valid(b) or b.data == null:
		return false
	var nt = b.data.network_type
	return nt in ["supply_source", "supply_cable", "warehouse", "elevator"]

func is_valid_supply_node(b: Building) -> bool:
	if not is_instance_valid(b) or b.data == null:
		return false
	return b.data.network_type in ["supply_source", "supply_cable", "supply_consumer", "warehouse", "elevator"]

func recalculate_chain(all_buildings: Array[Building]) -> void:
	clear()
	
	# 1. Filter and add valid supply nodes
	var supply_buildings: Array[Building] = []
	for b in all_buildings:
		if is_valid_supply_node(b):
			supply_buildings.append(b)
			add_node(b)
			
	# 2. Add edges between adjacent buildings on the same layer
	# At least one building must be a supply conductor (source, cable, warehouse, elevator)
	if occupancy:
		# Оптимальный поиск O(N) через пространственный периметр OccupancyGrid
		for b1 in supply_buildings:
			var z = b1.z_level
			var origin = b1.grid_position
			var size = b1.data.tile_size if b1.data else Vector2i(1, 1)
			
			# Верх и низ периметра
			for x in range(origin.x, origin.x + size.x):
				var top_b = occupancy.get_building_at(z, Vector2i(x, origin.y - 1)) as Building
				if top_b and top_b != b1 and is_valid_supply_node(top_b):
					if is_supply_conductor(b1) or is_supply_conductor(top_b):
						add_edge(b1, top_b)
				var bot_b = occupancy.get_building_at(z, Vector2i(x, origin.y + size.y)) as Building
				if bot_b and bot_b != b1 and is_valid_supply_node(bot_b):
					if is_supply_conductor(b1) or is_supply_conductor(bot_b):
						add_edge(b1, bot_b)
						
			# Лево и право периметра
			for y in range(origin.y, origin.y + size.y):
				var left_b = occupancy.get_building_at(z, Vector2i(origin.x - 1, y)) as Building
				if left_b and left_b != b1 and is_valid_supply_node(left_b):
					if is_supply_conductor(b1) or is_supply_conductor(left_b):
						add_edge(b1, left_b)
				var right_b = occupancy.get_building_at(z, Vector2i(origin.x + size.x, y)) as Building
				if right_b and right_b != b1 and is_valid_supply_node(right_b):
					if is_supply_conductor(b1) or is_supply_conductor(right_b):
						add_edge(b1, right_b)
	else:
		# Fallback: попарная проверка, если OccupancyGrid не подключен
		var by_layer: Dictionary = {}
		for b in supply_buildings:
			var z = b.z_level
			if not by_layer.has(z):
				by_layer[z] = []
			by_layer[z].append(b)
			
		for z in by_layer.keys():
			var layer_list: Array = by_layer[z]
			var count = layer_list.size()
			for i in range(count):
				var b1 = layer_list[i]
				for j in range(i + 1, count):
					var b2 = layer_list[j]
					if is_supply_conductor(b1) or is_supply_conductor(b2):
						if are_buildings_adjacent(b1, b2):
							add_edge(b1, b2)
					
	# 3. Add vertical elevator bridges
	if shaft_elevator:
		var vert_pairs = shaft_elevator.get_vertical_connections(all_buildings)
		for pair in vert_pairs:
			var e1 = pair[0]
			var e2 = pair[1]
			if is_valid_supply_node(e1) and is_valid_supply_node(e2):
				add_edge(e1, e2)
				
	# 4. Multi-source BFS from all supply_source nodes (quarries).
	# Склад (warehouse) проводит грузы, но сам по себе без подключения к карьеру не генерирует руду!
	var supplied_set: Dictionary = {}
	var queue: Array[Building] = []
	
	for b in supply_buildings:
		if b.data and b.data.network_type == "supply_source" and b.current_hp > 0:
			supplied_set[b] = true
			queue.append(b)
			
	while queue.size() > 0:
		var curr = queue.pop_front()
		if not is_instance_valid(curr):
			continue
		if not is_supply_conductor(curr):
			continue
		if _adjacency.has(curr):
			for neighbor in _adjacency[curr]:
				if is_instance_valid(neighbor) and neighbor.current_hp > 0:
					if not supplied_set.has(neighbor):
						supplied_set[neighbor] = true
						if is_supply_conductor(neighbor):
							queue.append(neighbor)
						
	# 5. Apply supply state to all buildings
	for b in all_buildings:
		if not is_instance_valid(b):
			continue
		if b.data and b.data.network_type == "supply_source":
			b.connected_to_supply = true
		elif b.data and b.data.network_type == "supply_consumer":
			b.connected_to_supply = supplied_set.has(b)
		elif is_valid_supply_node(b):
			b.connected_to_supply = supplied_set.has(b)
		else:
			b.connected_to_supply = true
			
	if EventBus and EventBus.has_signal("network_updated"):
		EventBus.network_updated.emit("supply")

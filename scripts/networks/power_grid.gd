class_name PowerGrid
extends NetworkGraph

@export var shaft_elevator: ShaftElevator = null
@export var occupancy: OccupancyGrid = null

func is_power_conductor(b: Building) -> bool:
	if not is_instance_valid(b) or b.data == null:
		return false
	var nt = b.data.network_type
	return nt in ["power_source", "power_cable", "elevator"]

func is_valid_power_node(b: Building) -> bool:
	if not is_instance_valid(b) or b.data == null:
		return false
	var nt = b.data.network_type
	if nt in ["power_source", "power_cable", "power_consumer", "elevator"]:
		return true
	if b.data.energy_production > 0 or b.data.energy_consumption > 0:
		return true
	return false

func recalculate_grid(all_buildings: Array[Building]) -> void:
	clear()
	
	# 1. Filter and add valid power nodes
	var power_buildings: Array[Building] = []
	for b in all_buildings:
		if is_valid_power_node(b):
			power_buildings.append(b)
			add_node(b)
			
	# 2. Add edges between adjacent buildings on the same layer
	# At least one building must be a power conductor (source, cable, elevator)
	if occupancy:
		# Оптимальный поиск O(N) через пространственный периметр OccupancyGrid
		for b1 in power_buildings:
			var z = b1.z_level
			var origin = b1.grid_position
			var size = b1.data.tile_size if b1.data else Vector2i(1, 1)
			
			# Верх и низ периметра
			for x in range(origin.x, origin.x + size.x):
				var top_b = occupancy.get_building_at(z, Vector2i(x, origin.y - 1)) as Building
				if top_b and top_b != b1 and is_valid_power_node(top_b):
					if is_power_conductor(b1) or is_power_conductor(top_b):
						add_edge(b1, top_b)
				var bot_b = occupancy.get_building_at(z, Vector2i(x, origin.y + size.y)) as Building
				if bot_b and bot_b != b1 and is_valid_power_node(bot_b):
					if is_power_conductor(b1) or is_power_conductor(bot_b):
						add_edge(b1, bot_b)
						
			# Лево и право периметра
			for y in range(origin.y, origin.y + size.y):
				var left_b = occupancy.get_building_at(z, Vector2i(origin.x - 1, y)) as Building
				if left_b and left_b != b1 and is_valid_power_node(left_b):
					if is_power_conductor(b1) or is_power_conductor(left_b):
						add_edge(b1, left_b)
				var right_b = occupancy.get_building_at(z, Vector2i(origin.x + size.x, y)) as Building
				if right_b and right_b != b1 and is_valid_power_node(right_b):
					if is_power_conductor(b1) or is_power_conductor(right_b):
						add_edge(b1, right_b)
	else:
		# Fallback: попарная проверка, если OccupancyGrid не подключен
		var by_layer: Dictionary = {}
		for b in power_buildings:
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
					if is_power_conductor(b1) or is_power_conductor(b2):
						if are_buildings_adjacent(b1, b2):
							add_edge(b1, b2)
					
	# 3. Add vertical elevator bridges
	if shaft_elevator:
		var vert_pairs = shaft_elevator.get_vertical_connections(all_buildings)
		for pair in vert_pairs:
			var e1 = pair[0]
			var e2 = pair[1]
			if is_valid_power_node(e1) and is_valid_power_node(e2):
				add_edge(e1, e2)
				
	# 4. Multi-source BFS from all power_source nodes
	var powered_set: Dictionary = {}
	var queue: Array[Building] = []
	
	for b in power_buildings:
		if b.data and b.data.network_type == "power_source" and b.current_hp > 0:
			powered_set[b] = true
			queue.append(b)
			
	while queue.size() > 0:
		var curr = queue.pop_front()
		if not is_instance_valid(curr):
			continue
		if not is_power_conductor(curr):
			continue
		if _adjacency.has(curr):
			for neighbor in _adjacency[curr]:
				if is_instance_valid(neighbor) and neighbor.current_hp > 0:
					if not powered_set.has(neighbor):
						powered_set[neighbor] = true
						if is_power_conductor(neighbor):
							queue.append(neighbor)
						
	# 5. Apply power state to all buildings
	for b in all_buildings:
		if not is_instance_valid(b):
			continue
		if b.data and b.data.network_type == "power_source":
			b.connected_to_power = true
		elif is_valid_power_node(b):
			b.connected_to_power = powered_set.has(b)
		else:
			b.connected_to_power = true
			
	if EventBus and EventBus.has_signal("network_updated"):
		EventBus.network_updated.emit("power")

class_name NetworkGraph
extends Node

var _nodes: Array[Building] = []
var _adjacency: Dictionary = {} # Building -> Array[Building]

func add_node(building: Building) -> void:
	if not is_instance_valid(building):
		return
	if not _nodes.has(building):
		_nodes.append(building)
	if not _adjacency.has(building):
		_adjacency[building] = []

func remove_node(building: Building) -> void:
	if _nodes.has(building):
		_nodes.erase(building)
	if _adjacency.has(building):
		var neighbors: Array[Building] = []
		neighbors.assign(_adjacency[building])
		for n in neighbors:
			if _adjacency.has(n):
				_adjacency[n].erase(building)
		_adjacency.erase(building)

func add_edge(a: Building, b: Building) -> void:
	if not is_instance_valid(a) or not is_instance_valid(b) or a == b:
		return
	add_node(a)
	add_node(b)
	if not _adjacency[a].has(b):
		_adjacency[a].append(b)
	if not _adjacency[b].has(a):
		_adjacency[b].append(a)

func remove_edge(a: Building, b: Building) -> void:
	if _adjacency.has(a):
		_adjacency[a].erase(b)
	if _adjacency.has(b):
		_adjacency[b].erase(a)

func get_connected_component(source: Building) -> Array[Building]:
	var result: Array[Building] = []
	if not is_instance_valid(source) or not _nodes.has(source):
		return result
		
	var queue: Array[Building] = [source]
	var visited: Dictionary = {source: true}
	
	while queue.size() > 0:
		var curr = queue.pop_front()
		if not is_instance_valid(curr):
			continue
		result.append(curr)
		if _adjacency.has(curr):
			for neighbor in _adjacency[curr]:
				if is_instance_valid(neighbor) and not visited.has(neighbor):
					visited[neighbor] = true
					queue.append(neighbor)
	return result

func is_connected_to_source(building: Building, source_type: String) -> bool:
	if not is_instance_valid(building):
		return false
	if building.data and building.data.network_type == source_type:
		return true
	var comp = get_connected_component(building)
	for b in comp:
		if is_instance_valid(b) and b.data and b.data.network_type == source_type:
			return true
	return false

func recalculate() -> void:
	pass

func get_all_edges() -> Array:
	var edges: Array = []
	for u in _adjacency.keys():
		if not is_instance_valid(u):
			continue
		var u_id = u.get_instance_id()
		for v in _adjacency[u]:
			if not is_instance_valid(v):
				continue
			var v_id = v.get_instance_id()
			# Неориентированное ребро: добавляем пару только один раз без аллокаций строк
			if u_id < v_id:
				edges.append([u, v])
	return edges

func clear() -> void:
	_nodes.clear()
	_adjacency.clear()

static func are_buildings_adjacent(a: Building, b: Building) -> bool:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return false
	if a.z_level != b.z_level:
		return false
	var a_size = a.data.tile_size if a.data else Vector2i(1, 1)
	var b_size = b.data.tile_size if b.data else Vector2i(1, 1)
	var a_min = a.grid_position
	var a_max = a.grid_position + a_size - Vector2i(1, 1)
	var b_min = b.grid_position
	var b_max = b.grid_position + b_size - Vector2i(1, 1)
	
	var dx = 0
	if a_max.x < b_min.x:
		dx = b_min.x - a_max.x
	elif b_max.x < a_min.x:
		dx = a_min.x - b_max.x
		
	var dy = 0
	if a_max.y < b_min.y:
		dy = b_min.y - a_max.y
	elif b_max.y < a_min.y:
		dy = a_min.y - b_max.y
		
	return (dx + dy) <= 1

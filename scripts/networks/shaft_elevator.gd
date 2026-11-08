class_name ShaftElevator
extends Node

# Finds pairs of elevators on adjacent layers (z, z+1) with the same grid_position
func get_vertical_connections(all_buildings: Array[Building]) -> Array:
	var pairs: Array = []
	var elevators: Array[Building] = []
	for b in all_buildings:
		if is_instance_valid(b) and b.data and b.data.connects_layers:
			elevators.append(b)
			
	for i in range(elevators.size()):
		var e1 = elevators[i]
		for j in range(i + 1, elevators.size()):
			var e2 = elevators[j]
			if e1.grid_position == e2.grid_position and abs(e1.z_level - e2.z_level) == 1:
				pairs.append([e1, e2])
	return pairs

func is_layer_connected(target_z: int, all_buildings: Array[Building]) -> bool:
	if target_z == 0:
		return true
	return get_connected_layers_from_zero(all_buildings).has(target_z)

func get_connected_layers_from_zero(all_buildings: Array[Building]) -> Dictionary:
	var connected: Dictionary = {0: true}
	var connections = get_vertical_connections(all_buildings)
	if connections.is_empty():
		return connected
		
	# Graph of layer connectivity
	var layer_adj: Dictionary = {}
	for pair in connections:
		var z1 = pair[0].z_level
		var z2 = pair[1].z_level
		if not layer_adj.has(z1):
			layer_adj[z1] = []
		if not layer_adj.has(z2):
			layer_adj[z2] = []
		if not layer_adj[z1].has(z2):
			layer_adj[z1].append(z2)
		if not layer_adj[z2].has(z1):
			layer_adj[z2].append(z1)
			
	# BFS from layer 0
	if not layer_adj.has(0):
		return connected
		
	var queue: Array[int] = [0]
	while queue.size() > 0:
		var curr_z = queue.pop_front()
		if layer_adj.has(curr_z):
			for next_z in layer_adj[curr_z]:
				if not connected.has(next_z):
					connected[next_z] = true
					queue.append(next_z)
					
	return connected

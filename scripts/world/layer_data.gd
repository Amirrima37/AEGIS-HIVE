class_name LayerData
extends RefCounted

var z_level: int = 0
var display_name: String = ""
var layer_type: String = "surface" # "surface", "above", "underground"
var tile_map_layer: TileMapLayer = null
var created_at_tick: int = 0

func _init(p_z: int, p_tile_map: TileMapLayer) -> void:
	z_level = p_z
	tile_map_layer = p_tile_map
	
	if z_level == 0:
		layer_type = "surface"
		display_name = "Поверхность (z=0)"
	elif z_level > 0:
		layer_type = "above"
		display_name = "Платформа +%d" % z_level
	else:
		layer_type = "underground"
		display_name = "Геофронт %d" % z_level

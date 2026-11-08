class_name WallNode
extends Building

signal wall_destroyed(wall: WallNode)

var is_solid: bool = true

func _ready() -> void:
	super._ready()
	is_solid = true

func init(p_data: BuildingData, pos: Vector2i, z: int, tml: TileMapLayer = null) -> void:
	super.init(p_data, pos, z, tml)
	is_solid = true
	if data:
		data.is_solid = true

func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)
	update_operational_state()
	
	if EventBus and EventBus.has_signal("building_damaged"):
		EventBus.building_damaged.emit(self, amount, current_hp)
		
	if current_hp <= 0:
		_on_destroyed()

func _on_destroyed() -> void:
	is_solid = false
	if is_inside_tree():
		var bm = get_tree().root.find_child("BuildingManager", true, false)
		if bm and bm.occupancy:
			bm.occupancy.set_blocked(z_level, grid_position, false)
	wall_destroyed.emit(self)
	if EventBus and EventBus.has_signal("wall_destroyed"):
		EventBus.wall_destroyed.emit(self)

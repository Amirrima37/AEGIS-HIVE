class_name World
extends Node2D

@onready var layer_manager: LayerManager = $LayerManager
@onready var building_manager: BuildingManager = $BuildingManager
@onready var network_manager: NetworkManager = $NetworkManager
@onready var network_overlay: NetworkOverlay = $NetworkOverlay
@onready var building_placer: BuildingPlacer = $BuildingPlacer
@onready var tick_manager: TickManager = $TickManager

func _ready() -> void:
	if building_manager:
		building_manager.layer_manager = layer_manager
		if building_manager.occupancy:
			building_manager.occupancy.init_grid(layer_manager)
			
	if network_manager:
		network_manager.building_manager = building_manager
		network_manager.layer_manager = layer_manager
		
	if network_overlay:
		network_overlay.network_manager = network_manager
		
	if building_placer:
		building_placer.building_manager = building_manager
		building_placer.layer_manager = layer_manager
		
	if tick_manager:
		tick_manager.building_manager = building_manager
		tick_manager.network_manager = network_manager

	_spawn_initial_command_center.call_deferred()

func _spawn_initial_command_center() -> void:
	if building_manager:
		building_manager.spawn_starting_command_center()
	if network_manager:
		network_manager.recalculate_all()

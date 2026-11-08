extends Node

# Layer management signals
signal layer_change_requested(delta: int)
signal layer_jump_requested(z: int)
signal active_layer_changed(z: int)
signal layer_created(z: int)
signal layer_removed(z: int)
signal request_create_layer_above
signal request_create_layer_below

# Camera signals
signal camera_zoom_changed(zoom: float)

# Game state signals
signal game_speed_changed(speed: float)
signal game_paused(paused: bool)
signal game_mode_changed(mode_name: String)
signal tick(tick_count: int)

# Resource signals
signal resource_changed(resource_name: String, new_amount: int)
signal insufficient_resources(resource_name: String)

# Building signals
signal build_mode_entered(building_data: Resource)
signal build_mode_exited
signal building_placed(building: Node2D)
signal building_removed(building: Node2D)
signal building_damaged(building: Node2D, amount: int, current_hp: int)
signal demolish_mode_entered
signal demolish_mode_exited

# Network signals (Stage 2)
signal network_updated(network_type: String)
signal building_connected(building: Node, network_type: String)
signal building_disconnected(building: Node, network_type: String)
signal cable_mode_entered(cable_data: Resource)
signal cable_mode_exited
signal overlay_toggled(overlay_name: String, visible: bool)
signal layer_isolated_warning(z: int)

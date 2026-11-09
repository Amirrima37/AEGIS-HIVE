extends Node

# Layer management signals
signal layer_change_requested(delta: int)
signal layer_jump_requested(z: int)
signal active_layer_changed(z: int)
signal layer_created(z: int)
signal layer_removed(z: int)
signal request_create_layer_above
signal request_create_layer_below
signal layer_creation_failed(target_z: int, reason: String)

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

# Defense signals (Stage 3)
signal turret_fired(turret: Node2D, target: Variant)
signal shield_depleted
signal wall_destroyed(building: Node2D)
signal building_repaired(building: Node2D, amount: int)
signal enemy_wave_start(wave_index: int)
signal enemy_wave_ended(wave_index: int)
signal base_under_attack(pos: Vector2, z: int)

# Structural Integrity & Cascades (Stage 3 completion)
signal layer_integrity_compromised(z: int, reason: String)
signal layer_cascade_damage(z: int, total_damage: int, affected_count: int)

# Colonial Directives, Combat Shift, Aegis & Research
signal combat_power_shift_toggled(active: bool)
signal aegis_protocol_toggled(active: bool)
signal power_priorities_changed(priorities: Dictionary)
signal research_started(tech_id: StringName)
signal research_progress_updated(tech_id: StringName, current_ticks: int, total_ticks: int)
signal research_completed(tech_id: StringName)

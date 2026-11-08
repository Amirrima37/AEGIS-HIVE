class_name NetworkOverlay
extends Node2D

@export var network_manager: NetworkManager = null

var show_power_overlay: bool = false
var show_supply_overlay: bool = false

func _ready() -> void:
	z_index = 50
	_find_network_manager()
	
	if EventBus:
		if EventBus.has_signal("network_updated"):
			EventBus.network_updated.connect(_on_network_updated)
		if EventBus.has_signal("overlay_toggled"):
			EventBus.overlay_toggled.connect(_on_overlay_toggled)
		if EventBus.has_signal("active_layer_changed"):
			EventBus.active_layer_changed.connect(_on_layer_changed)

func _find_network_manager() -> void:
	if network_manager == null or not is_instance_valid(network_manager):
		if is_inside_tree():
			network_manager = get_tree().root.find_child("NetworkManager", true, false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			toggle_power_overlay()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F2:
			toggle_supply_overlay()
			get_viewport().set_input_as_handled()

func toggle_power_overlay() -> void:
	show_power_overlay = not show_power_overlay
	if EventBus and EventBus.has_signal("overlay_toggled"):
		EventBus.overlay_toggled.emit("power", show_power_overlay)
	queue_redraw()

func toggle_supply_overlay() -> void:
	show_supply_overlay = not show_supply_overlay
	if EventBus and EventBus.has_signal("overlay_toggled"):
		EventBus.overlay_toggled.emit("supply", show_supply_overlay)
	queue_redraw()

func _on_overlay_toggled(overlay_name: String, is_visible: bool) -> void:
	if overlay_name == "power":
		show_power_overlay = is_visible
	elif overlay_name == "supply":
		show_supply_overlay = is_visible
	queue_redraw()

func _on_network_updated(_type: String) -> void:
	queue_redraw()

func _on_layer_changed(_z: int) -> void:
	queue_redraw()

func _draw() -> void:
	_find_network_manager()
	if network_manager == null:
		return
		
	var cur_z = GameState.current_layer
	
	# Draw power lines (Cyan)
	if show_power_overlay:
		var pg = network_manager.get_power_grid()
		if pg:
			var edges = pg.get_all_edges()
			var cyan = Color(0.0, 0.9, 1.0, 0.85)
			for edge in edges:
				var b1 = edge[0] as Building
				var b2 = edge[1] as Building
				if not is_instance_valid(b1) or not is_instance_valid(b2):
					continue
				if b1.z_level == cur_z and b2.z_level == cur_z:
					var p1 = to_local(b1.global_position)
					var p2 = to_local(b2.global_position)
					draw_line(p1, p2, cyan, 3.0, true)
					draw_circle(p1, 4.0, cyan)
					draw_circle(p2, 4.0, cyan)
				elif b1.z_level == cur_z and b2.z_level != cur_z:
					var p1 = to_local(b1.global_position)
					draw_arc(p1, 16.0, 0, TAU, 24, cyan, 2.5, true)
				elif b2.z_level == cur_z and b1.z_level != cur_z:
					var p2 = to_local(b2.global_position)
					draw_arc(p2, 16.0, 0, TAU, 24, cyan, 2.5, true)
					
	# Draw supply lines (Amber)
	if show_supply_overlay:
		var sc = network_manager.get_supply_chain()
		if sc:
			var edges = sc.get_all_edges()
			var amber = Color(1.0, 0.6, 0.1, 0.85)
			for edge in edges:
				var b1 = edge[0] as Building
				var b2 = edge[1] as Building
				if not is_instance_valid(b1) or not is_instance_valid(b2):
					continue
				if b1.z_level == cur_z and b2.z_level == cur_z:
					var p1 = to_local(b1.global_position)
					var p2 = to_local(b2.global_position)
					draw_line(p1, p2, amber, 3.0, true)
					draw_circle(p1, 4.0, amber)
					draw_circle(p2, 4.0, amber)
				elif b1.z_level == cur_z and b2.z_level != cur_z:
					var p1 = to_local(b1.global_position)
					draw_arc(p1, 20.0, 0, TAU, 24, amber, 2.5, true)
				elif b2.z_level == cur_z and b1.z_level != cur_z:
					var p2 = to_local(b2.global_position)
					draw_arc(p2, 20.0, 0, TAU, 24, amber, 2.5, true)

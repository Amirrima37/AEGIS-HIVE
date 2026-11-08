class_name MinimapPanel
extends PanelContainer

@onready var layers_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/LayersContainer
@onready var btn_add_above: Button = $MarginContainer/VBoxContainer/BtnAddAbove
@onready var btn_add_below: Button = $MarginContainer/VBoxContainer/BtnAddBelow

var _layer_buttons: Dictionary = {} # z -> Button

func _ready() -> void:
	EventBus.layer_created.connect(_on_layer_list_changed)
	EventBus.layer_removed.connect(_on_layer_list_changed)
	EventBus.active_layer_changed.connect(_on_active_layer_changed)
	
	btn_add_above.pressed.connect(_on_add_above_pressed)
	btn_add_below.pressed.connect(_on_add_below_pressed)
	
	_rebuild_layer_list()

func _on_add_above_pressed() -> void:
	EventBus.request_create_layer_above.emit()

func _on_add_below_pressed() -> void:
	EventBus.request_create_layer_below.emit()

func _on_layer_list_changed(_z: int) -> void:
	_rebuild_layer_list()

func _on_active_layer_changed(_z: int) -> void:
	_highlight_active()

func _get_sorted_keys() -> Array:
	# Check through LayerManager or collect known buttons
	var keys = _layer_buttons.keys()
	if keys.is_empty():
		keys = [0]
	keys.sort()
	return keys

func _rebuild_layer_list() -> void:
	# Clear old buttons
	for child in layers_container.get_children():
		child.queue_free()
	_layer_buttons.clear()
	
	# We query all existing layer nodes from scene tree
	var layer_mgr = get_tree().root.find_child("LayerManager", true, false)
	var z_list: Array = []
	if layer_mgr and layer_mgr.has_method("get_existing_z_levels"):
		z_list = layer_mgr.get_existing_z_levels()
	else:
		z_list = [0]
	
	# Sort descending (top floors at top of UI, underground at bottom)
	z_list.sort_custom(func(a, b): return a > b)
	
	for z in z_list:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(160, 32)
		var icon_str = "🏗"
		var desc = "Поверхность"
		if z > 0:
			icon_str = "🔭"
			desc = "Ярус +%d" % z
		elif z < 0:
			icon_str = "⛏"
			desc = "Геофронт %d" % z
		
		btn.text = "%s  %s [z=%d]" % [icon_str, desc, z]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var target_z = z
		btn.pressed.connect(func(): EventBus.layer_jump_requested.emit(target_z))
		
		layers_container.add_child(btn)
		_layer_buttons[z] = btn
	
	_highlight_active()

func _highlight_active() -> void:
	var current_z = GameState.current_layer
	for z in _layer_buttons.keys():
		var btn: Button = _layer_buttons[z]
		if not is_instance_valid(btn):
			continue
		if z == current_z:
			btn.modulate = Color(0.4, 1.2, 1.5, 1.0) # Radiant cyan glow
		else:
			btn.modulate = Color(0.8, 0.8, 0.85, 0.85)

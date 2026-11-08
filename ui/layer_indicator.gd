class_name LayerIndicator
extends PanelContainer

@onready var label_layer_name: Label = $MarginContainer/HBoxContainer/LabelLayerName
@onready var btn_up: Button = $MarginContainer/HBoxContainer/BtnUp
@onready var btn_down: Button = $MarginContainer/HBoxContainer/BtnDown

func _ready() -> void:
	EventBus.active_layer_changed.connect(_on_active_layer_changed)
	btn_up.pressed.connect(func(): EventBus.layer_change_requested.emit(1))
	btn_down.pressed.connect(func(): EventBus.layer_change_requested.emit(-1))
	_update_text(GameState.current_layer)

func _on_active_layer_changed(z: int) -> void:
	_update_text(z)

func _update_text(z: int) -> void:
	var title = ""
	if z == 0:
		title = "ПОВЕРХНОСТЬ [z=0]"
	elif z > 0:
		title = "ПЛАТФОРМА [z=+%d]" % z
	else:
		title = "ГЕОФРОНТ [z=%d]" % z
	
	if label_layer_name:
		label_layer_name.text = title

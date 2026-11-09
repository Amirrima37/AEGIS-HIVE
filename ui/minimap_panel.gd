class_name MinimapPanel
extends PanelContainer

const BrutalistTheme = preload("res://ui/brutalist_theme.gd")

# Placeholder for tactical radar / minimap as requested by user.
# Reserves the bottom-right space for future radar rendering implementation.

@onready var header_label: Label = $MarginContainer/VBoxContainer/Header
@onready var placeholder_viewport: PanelContainer = $MarginContainer/VBoxContainer/PlaceholderViewport
@onready var placeholder_text: Label = $MarginContainer/VBoxContainer/PlaceholderViewport/CenterContainer/PlaceholderText
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel

func _ready() -> void:
	add_theme_stylebox_override("panel", BrutalistTheme.create_panel_style(
		BrutalistTheme.BG_PANEL,
		BrutalistTheme.BORDER_DARK,
		4,
		8
	))
	
	if header_label:
		header_label.text = "ТАКТИЧЕСКИЙ РАДАР [OFFLINE]"
		header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		header_label.add_theme_color_override("font_color", BrutalistTheme.TEXT_MUTED)
		
	if placeholder_viewport:
		var grid_sb = BrutalistTheme.create_panel_style(
			Color(0.06, 0.07, 0.09, 0.95),
			Color(0.18, 0.22, 0.28, 0.8),
			3,
			12
		)
		placeholder_viewport.add_theme_stylebox_override("panel", grid_sb)
	if placeholder_text:
		placeholder_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
	if status_label:
		status_label.text = "СТАТУС: В РЕЗЕРВЕ // СИСТЕМА СКАНИРОВАНИЯ НЕ АКТИВИРОВАНА"
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status_label.add_theme_color_override("font_color", Color(0.45, 0.50, 0.58, 0.9))

func set_compact_mode(compact: bool) -> void:
	if header_label:
		header_label.add_theme_font_size_override("font_size", 11 if compact else 13)
	if placeholder_text:
		placeholder_text.custom_minimum_size = Vector2(200, 0) if compact else Vector2(360, 0)
		placeholder_text.add_theme_font_size_override("font_size", 10 if compact else 12)
	if status_label:
		status_label.text = "В РЕЗЕРВЕ [OFFLINE]" if compact else "СТАТУС: В РЕЗЕРВЕ // СИСТЕМА СКАНИРОВАНИЯ НЕ АКТИВИРОВАНА"
		status_label.add_theme_font_size_override("font_size", 9 if compact else 10)

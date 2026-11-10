class_name BrutalistTheme
extends RefCounted

# Colors
const BG_PANEL = Color(0.08, 0.10, 0.14, 0.88)
const BG_PANEL_ALT = Color(0.06, 0.08, 0.11, 0.94)
const BORDER_DARK = Color(0.22, 0.26, 0.32, 1.0)
const BORDER_HIGHLIGHT = Color(0.38, 0.44, 0.54, 1.0)
const BORDER_AMBER = Color(0.96, 0.62, 0.07, 1.0)

const BG_BTN_NORMAL = Color(0.12, 0.15, 0.19, 0.92)
const BG_BTN_HOVER = Color(0.16, 0.20, 0.26, 0.98)
const BG_BTN_PRESSED = Color(0.20, 0.24, 0.32, 1.0)
const BG_BTN_ACTIVE = Color(0.18, 0.22, 0.28, 1.0)
const BG_BTN_DISABLED = Color(0.08, 0.10, 0.12, 0.6)

const BG_DEMOLISH = Color(0.20, 0.10, 0.12, 0.92)
const BORDER_DEMOLISH = Color(0.50, 0.22, 0.26, 1.0)

const TEXT_BRIGHT = Color(0.95, 0.97, 1.0, 1.0)
const TEXT_MUTED = Color(0.58, 0.64, 0.72, 1.0)
const TEXT_AMBER = Color(0.96, 0.62, 0.07, 1.0)
const TEXT_RED = Color(0.94, 0.38, 0.38, 1.0)

static func create_panel_style(bg: Color = BG_PANEL, border: Color = BORDER_DARK, corner: int = 3, padding: int = 6) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(corner)
	sb.content_margin_left = padding
	sb.content_margin_right = padding
	sb.content_margin_top = padding
	sb.content_margin_bottom = padding
	return sb

static func apply_button_styles(btn: Button, is_demolish: bool = false) -> void:
	if not is_instance_valid(btn):
		return
	btn.focus_mode = Control.FOCUS_NONE
		
	var sb_normal = StyleBoxFlat.new()
	sb_normal.set_border_width_all(1)
	sb_normal.set_corner_radius_all(3)
	sb_normal.content_margin_left = 8
	sb_normal.content_margin_right = 8
	sb_normal.content_margin_top = 4
	sb_normal.content_margin_bottom = 4
	
	var sb_hover = sb_normal.duplicate() as StyleBoxFlat
	var sb_pressed = sb_normal.duplicate() as StyleBoxFlat
	var sb_disabled = sb_normal.duplicate() as StyleBoxFlat
	
	if is_demolish:
		sb_normal.bg_color = BG_DEMOLISH
		sb_normal.border_color = BORDER_DEMOLISH
		sb_hover.bg_color = Color(0.26, 0.13, 0.15, 0.98)
		sb_hover.border_color = Color(0.70, 0.30, 0.34, 1.0)
		sb_pressed.bg_color = Color(0.32, 0.15, 0.18, 1.0)
		sb_pressed.border_color = Color(0.85, 0.35, 0.40, 1.0)
		sb_disabled.bg_color = Color(0.12, 0.08, 0.09, 0.5)
		sb_disabled.border_color = Color(0.25, 0.15, 0.17, 0.5)
		btn.add_theme_color_override("font_color", TEXT_RED)
	else:
		sb_normal.bg_color = BG_BTN_NORMAL
		sb_normal.border_color = BORDER_DARK
		sb_hover.bg_color = BG_BTN_HOVER
		sb_hover.border_color = BORDER_HIGHLIGHT
		sb_pressed.bg_color = BG_BTN_PRESSED
		sb_pressed.border_color = BORDER_AMBER
		sb_disabled.bg_color = BG_BTN_DISABLED
		sb_disabled.border_color = Color(0.14, 0.16, 0.20, 0.5)
		btn.add_theme_color_override("font_color", TEXT_BRIGHT)
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
		btn.add_theme_color_override("font_pressed_color", TEXT_AMBER)
		btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.45, 0.5, 0.5))
	
	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("disabled", sb_disabled)
	btn.add_theme_stylebox_override("focus", sb_hover)

static func create_active_button_style() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = BG_BTN_ACTIVE
	sb.border_color = BORDER_AMBER
	sb.set_border_width_all(1)
	sb.border_width_top = 2 # Amber accent bar at top
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

static func create_normal_button_style(is_demolish: bool = false) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	if is_demolish:
		sb.bg_color = BG_DEMOLISH
		sb.border_color = BORDER_DEMOLISH
	else:
		sb.bg_color = BG_BTN_NORMAL
		sb.border_color = BORDER_DARK
	return sb

static func set_button_active(btn: Button, active: bool, is_demolish: bool = false) -> void:
	if not is_instance_valid(btn):
		return
	if active:
		btn.add_theme_stylebox_override("normal", create_active_button_style())
	else:
		btn.add_theme_stylebox_override("normal", create_normal_button_style(is_demolish))


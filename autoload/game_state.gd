extends Node

enum GameMode { STANDARD, UNLIMITED }

var current_layer: int = 0
var game_speed: float = 1.0
var is_paused: bool = false
var tick_count: int = 0
var current_game_mode: GameMode = GameMode.STANDARD

# Colonial Directives & Defense Modes (Stage 3 completion)
var combat_power_shift_active: bool = false
var aegis_protocol_unlocked: bool = false
var aegis_protocol_active: bool = false

# Dynamic power priority ranking per category (1 = highest, 4 = lowest)
var power_category_priorities: Dictionary = {
	"defense": 1,
	"life_support": 2,
	"logistics": 3,
	"industry": 4
}

# Research progression state
var unlocked_techs: Dictionary = {} # StringName -> bool
var active_research_id: StringName = &""
var active_research_progress: int = 0

func _ready() -> void:
	if EventBus:
		EventBus.active_layer_changed.connect(_on_active_layer_changed)
		EventBus.game_speed_changed.connect(_on_game_speed_changed)
		EventBus.game_paused.connect(_on_game_paused)

func _on_active_layer_changed(z: int) -> void:
	current_layer = z

func _on_game_speed_changed(speed: float) -> void:
	game_speed = speed

func _on_game_paused(paused: bool) -> void:
	is_paused = paused

func is_unlimited_mode() -> bool:
	return current_game_mode == GameMode.UNLIMITED

func set_game_mode(mode: GameMode) -> void:
	current_game_mode = mode
	var mode_name = "unlimited" if mode == GameMode.UNLIMITED else "standard"
	if EventBus and EventBus.has_signal("game_mode_changed"):
		EventBus.game_mode_changed.emit(mode_name)

func toggle_unlimited_mode() -> void:
	if current_game_mode == GameMode.STANDARD:
		set_game_mode(GameMode.UNLIMITED)
	else:
		set_game_mode(GameMode.STANDARD)

func is_combat_mode_active() -> bool:
	return combat_power_shift_active or aegis_protocol_active

func set_combat_power_shift(active: bool) -> void:
	if not active and aegis_protocol_active:
		return
	if combat_power_shift_active == active:
		return
	combat_power_shift_active = active
	if EventBus and EventBus.has_signal("combat_power_shift_toggled"):
		EventBus.combat_power_shift_toggled.emit(combat_power_shift_active)

func toggle_combat_power_shift() -> void:
	set_combat_power_shift(not combat_power_shift_active)

func is_tech_unlocked(tech_id: StringName) -> bool:
	return unlocked_techs.get(tech_id, false)

func unlock_tech(tech_id: StringName) -> void:
	unlocked_techs[tech_id] = true
	if tech_id == &"aegis_protocol":
		aegis_protocol_unlocked = true
	if active_research_id == tech_id:
		active_research_id = &""
		active_research_progress = 0
	if EventBus and EventBus.has_signal("research_completed"):
		EventBus.research_completed.emit(tech_id)

func set_aegis_protocol(active: bool) -> bool:
	if active and not aegis_protocol_unlocked:
		return false
	if aegis_protocol_active == active:
		return true
	aegis_protocol_active = active
	if active and not combat_power_shift_active:
		# Aegis includes emergency power rerouting to defense systems
		set_combat_power_shift(true)
	if EventBus and EventBus.has_signal("aegis_protocol_toggled"):
		EventBus.aegis_protocol_toggled.emit(aegis_protocol_active)
	return true

func toggle_aegis_protocol() -> bool:
	if not aegis_protocol_unlocked:
		return false
	return set_aegis_protocol(not aegis_protocol_active)

func get_building_power_category(data: Resource) -> String:
	if data == null:
		return "industry"
	if "is_defense" in data and data.is_defense:
		var role = data.defense_role if "defense_role" in data else ""
		if role == "munitions":
			return "logistics"
		if role == "repair":
			return "life_support"
		return "defense"
	var b_id: StringName = data.id if "id" in data else &""
	if b_id in [&"habitation_block", &"repair_depot", &"command_center"]:
		return "life_support"
	if b_id in [&"munitions_factory", &"warehouse", &"shaft_elevator"]:
		return "logistics"
	return "industry"

func is_blocked_by_combat_mode(data: Resource) -> bool:
	if not is_combat_mode_active() or data == null:
		return false
	var cat = get_building_power_category(data)
	if cat == "industry":
		return true
	var b_id: StringName = data.id if "id" in data else &""
	if b_id == &"habitation_block":
		return true
	return false

func get_effective_power_priority(data: Resource) -> int:
	if data == null:
		return 4
	var cat = get_building_power_category(data)
	if is_combat_mode_active() and cat == "defense":
		return 0
	return int(power_category_priorities.get(cat, 4))

func get_power_category_order() -> Array[String]:
	var cats: Array[String] = ["defense", "life_support", "logistics", "industry"]
	cats.sort_custom(func(a, b):
		return int(power_category_priorities.get(a, 4)) < int(power_category_priorities.get(b, 4))
	)
	return cats

func set_power_category_order(ordered_categories: Array) -> void:
	var rank := 1
	for c in ordered_categories:
		var key = str(c)
		if power_category_priorities.has(key):
			power_category_priorities[key] = rank
			rank += 1
	if EventBus and EventBus.has_signal("power_priorities_changed"):
		EventBus.power_priorities_changed.emit(power_category_priorities.duplicate())

func reset_directives_and_research() -> void:
	combat_power_shift_active = false
	aegis_protocol_unlocked = false
	aegis_protocol_active = false
	unlocked_techs.clear()
	active_research_id = &""
	active_research_progress = 0
	power_category_priorities = {
		"defense": 1,
		"life_support": 2,
		"logistics": 3,
		"industry": 4
	}

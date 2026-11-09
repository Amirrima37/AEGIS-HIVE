class_name ResearchManager
extends Node

const TECH_DEFS: Array[Dictionary] = [
	{
		"id": &"aegis_protocol",
		"title": "Протокол «Эгида»",
		"description": "Герметичное укрытие населения под защитой ярусов и принудительная боевая готовность куполов силовых щитов.",
		"cost": {"ore": 40, "materials": 40},
		"ticks_required": 8,
		"available_stage": 3
	},
	{
		"id": &"xenology_tier1",
		"title": "Ксеноанализ ядра [Этап 5]",
		"description": "Изучение аномальных эманаций фауны и кристаллов ядра планеты.",
		"cost": {"ore": 120, "materials": 100},
		"ticks_required": 20,
		"available_stage": 5
	},
	{
		"id": &"megastructures_tier1",
		"title": "Мегапроекты: каркас [Этап 5]",
		"description": "Проектирование планетарных защитных сооружений и глубокого бурения.",
		"cost": {"ore": 250, "materials": 200},
		"ticks_required": 35,
		"available_stage": 5
	}
]

func get_tech_list() -> Array[Dictionary]:
	return TECH_DEFS.duplicate(true)

func get_tech_def(tech_id: StringName) -> Dictionary:
	for t in TECH_DEFS:
		if t["id"] == tech_id:
			return t
	return {}

func can_start_research(tech_id: StringName) -> bool:
	var def = get_tech_def(tech_id)
	if def.is_empty():
		return false
	if int(def.get("available_stage", 99)) > 3:
		return false
	if GameState.is_tech_unlocked(tech_id):
		return false
	if GameState.active_research_id != &"":
		return false
	if GameState.is_unlimited_mode():
		return true
	return ResourceManager.can_afford(def["cost"])

func start_research(tech_id: StringName) -> bool:
	if not can_start_research(tech_id):
		return false
	var def = get_tech_def(tech_id)
	if not ResourceManager.spend(def["cost"]):
		return false
	if GameState.is_unlimited_mode():
		GameState.unlock_tech(tech_id)
		return true
	GameState.active_research_id = tech_id
	GameState.active_research_progress = 0
	if EventBus and EventBus.has_signal("research_started"):
		EventBus.research_started.emit(tech_id)
	if EventBus and EventBus.has_signal("research_progress_updated"):
		EventBus.research_progress_updated.emit(tech_id, 0, int(def["ticks_required"]))
	return true

func advance_tick() -> void:
	var tech_id = GameState.active_research_id
	if tech_id == &"":
		return
	var def = get_tech_def(tech_id)
	if def.is_empty():
		GameState.active_research_id = &""
		GameState.active_research_progress = 0
		return
	var total = max(1, int(def.get("ticks_required", 1)))
	GameState.active_research_progress += 1
	if EventBus and EventBus.has_signal("research_progress_updated"):
		EventBus.research_progress_updated.emit(tech_id, GameState.active_research_progress, total)
	if GameState.active_research_progress >= total:
		GameState.unlock_tech(tech_id)

class_name BuildingData
extends Resource

@export var id: StringName
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var sprite: Texture2D

@export_group("Размеры")
@export var tile_size: Vector2i = Vector2i(1, 1)

@export_group("Стоимость строительства")
@export var cost_ore: int = 0
@export var cost_materials: int = 0
@export var cost_energy_initial: int = 0

@export_group("Экономика (за тик)")
@export var energy_production: int = 0
@export var energy_consumption: int = 0
@export var ore_production: int = 0
@export var ore_consumption: int = 0
@export var materials_production: int = 0
@export var materials_consumption: int = 0
@export var population_capacity: int = 0

@export_group("Прочность")
@export var max_hp: int = 100

@export_group("Правила размещения")
@export var allowed_layers: String = "any" # "any", "surface_only", "underground_only"
@export var is_structural: bool = false
@export var unlocks_layer_above: bool = false
@export var unlocks_layer_below: bool = false

@export_group("Сетевые свойства")
@export var network_type: String = "none" # "power_source", "power_consumer", "power_cable",
                                          # "supply_source", "supply_consumer", "supply_cable",
                                          # "elevator", "warehouse", "none"
@export var is_connector: bool = false # true для кабелей, конвейеров, лифтов
@export var connection_range: int = 1 # Радиус автоподключения (в тайлах)
@export var throughput: int = 0 # Пропускная способность (для лифтов)
@export var connects_layers: bool = false # true только для shaft_elevator

@export_group("Визуальное выравнивание")
@export var base_offset_y: float = 0.0 # Ручная юстировка смещения по Y (0 = идеальная посадка на сетку)

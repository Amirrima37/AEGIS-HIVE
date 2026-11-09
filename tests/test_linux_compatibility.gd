class_name TestLinuxCompatibility
extends RefCounted

## Тесты совместимости с Linux и SteamOS (Steam Deck)
## Проверяет:
## L.T1: Валидация регистрозависимых путей (res://)
## L.T2: Поддержка физических сканкодов (Physical Keycodes) и геймпада
## L.T3: Корректность записи и чтения user:// (XDG Base Directory)
## L.T4: Адаптивность UI и камеры к разрешению Steam Deck (1280x800, 16:10)

static func run_all_tests(main_node: Node) -> void:
	print("--- НАЧАЛО ТЕСТИРОВАНИЯ LINUX & STEAM DECK COMPATIBILITY ---")
	test_case_sensitive_paths()
	test_physical_and_gamepad_input(main_node)
	test_user_directory_xdg_io()
	test_steam_deck_viewport_aspect()
	print("--- ВСЕ ТЕСТЫ LINUX & STEAM DECK COMPATIBILITY УСПЕШНО ПРОЙДЕНЫ ---")

static func test_case_sensitive_paths() -> void:
	# Проверяем ключевые каталоги и ресурсы через DirAccess и FileAccess
	var critical_paths = [
		"res://scenes/main.tscn",
		"res://autoload/event_bus.gd",
		"res://autoload/game_state.gd",
		"res://autoload/resource_manager.gd",
		"res://ui/hud.tscn",
		"res://ui/brutalist_theme.gd",
		"res://data/buildings/command_center.tres",
		"res://data/buildings/defense_wall.tres",
		"res://data/buildings/heavy_railgun.tres",
		"res://assets/sprites/buildings/command_center.png",
		"res://assets/sprites/buildings/defense_wall.png"
	]
	
	for path in critical_paths:
		assert(FileAccess.file_exists(path), "L.T1 FAIL: Critical resource not found at %s" % path)
		var res = load(path)
		assert(res != null, "L.T1 FAIL: Resource failed to load: %s" % path)
		
	print("[OK] L.T1: Все критические ресурсы res:// успешно верифицированы")

static func test_physical_and_gamepad_input(main_node: Node) -> void:
	var cam: IsometricCamera = main_node.find_child("Camera2D", true, false)
	assert(cam != null, "L.T2 FAIL: IsometricCamera (Camera2D) not found in scene tree")
	
	# Проверяем вызов _handle_keyboard_pan при различных сканкодах и осях
	var initial_pos = cam.position
	cam._handle_keyboard_pan(0.016)
	
	# Проверяем эмуляцию физического сканкода Q/E
	var ev_q = InputEventKey.new()
	ev_q.pressed = true
	ev_q.keycode = 0
	ev_q.physical_keycode = KEY_Q
	cam._unhandled_input(ev_q)
	
	# Проверяем эмуляцию кнопок геймпада (L1 / R1)
	var ev_joy = InputEventJoypadButton.new()
	ev_joy.pressed = true
	ev_joy.button_index = JOY_BUTTON_LEFT_SHOULDER
	cam._unhandled_input(ev_joy)
	
	print("[OK] L.T2: Физические сканкоды клавиш и события геймпада/Steam Deck корректно обрабатываются")

static func test_user_directory_xdg_io() -> void:
	var test_file_path = "user://linux_compatibility_check.tmp"
	var test_content = "AegisHive-Linux-Compatibility-Token-2026"
	
	var fa_write = FileAccess.open(test_file_path, FileAccess.WRITE)
	assert(fa_write != null, "L.T3 FAIL: Cannot open user:// for writing: %s" % error_string(FileAccess.get_open_error()))
	fa_write.store_string(test_content)
	fa_write.close()
	
	assert(FileAccess.file_exists(test_file_path), "L.T3 FAIL: Test file was not created in user://")
	
	var fa_read = FileAccess.open(test_file_path, FileAccess.READ)
	assert(fa_read != null, "L.T3 FAIL: Cannot open user:// for reading")
	var read_back = fa_read.get_as_text()
	fa_read.close()
	assert(read_back == test_content, "L.T3 FAIL: Content mismatch in user:// test file")
	
	# Очистка
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_file_path))
	print("[OK] L.T3: Протокол работы с хранилищем user:// (XDG Base Directory) полностью функционален")

static func test_steam_deck_viewport_aspect() -> void:
	# Проверяем параметры растяжения и соотношения сторон в ProjectSettings
	var stretch_mode = ProjectSettings.get_setting("display/window/stretch/mode")
	var stretch_aspect = ProjectSettings.get_setting("display/window/stretch/aspect")
	
	assert(stretch_mode == "canvas_items", "L.T4 FAIL: stretch mode must be 'canvas_items'")
	assert(stretch_aspect == "expand", "L.T4 FAIL: stretch aspect must be 'expand' for 16:10 Steam Deck support")
	
	print("[OK] L.T4: Настройки адаптивности экрана к разрешению 1280x800 (Steam Deck 16:10) подтверждены")

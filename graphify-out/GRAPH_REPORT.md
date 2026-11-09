# Graph Report - MegaProject  (2026-11-09)

## Corpus Check
- 21 files · ~22,723 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 111 file(s) not represented in the graph (top: .gd 38, .uid 38, .tres 19)
- WARNING: 111 of 232 files seen (48%) have no supported extractor and are missing from this graph entirely. It may look complete while representing only part of the codebase.

## Summary
- 159 nodes · 165 edges · 20 communities (13 shown, 7 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `e629f3bd`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Project: Aegis-Hive — Дорожная карта разработки v2
- СПЕЦИФИКАЦИЯ ФАЙЛОВ
- 2. Инструменты и источники ассетов
- normalize_building_sprites.py
- RULES — Правила совместной разработки
- STYLE GUIDE & LORE — Мир, эстетика и арт-дирекшн Aegis-Hive
- STATE — Текущий статус проекта
- STAGES — Глобальный роадмап проекта Aegis-Hive
- AEGIS-HIVE
- context-mode.md
- Руководство для участников (Contributing Guide)
- СТИЛИСТИЧЕСКИЙ МАНИФЕСТ И ГЛУБОКИЙ РЕСЕРЧ АРХИТЕКТУРЫ «AEGIS-HIVE»
- run
- file-naming.md
- export-linux
- steps
- aegis-hive.sh
- run

## God Nodes (most connected - your core abstractions)
1. `Project: Aegis-Hive — Дорожная карта разработки v2` - 14 edges
2. `run()` - 10 edges
3. `AEGIS-HIVE` - 8 edges
4. `steps` - 7 edges
5. `СПЕЦИФИКАЦИЯ ФАЙЛОВ` - 6 edges
6. `run()` - 6 edges
7. `СТИЛИСТИЧЕСКИЙ МАНИФЕСТ И ГЛУБОКИЙ РЕСЕРЧ АРХИТЕКТУРЫ «AEGIS-HIVE»` - 6 edges
8. `with` - 6 edges
9. `build_or_update_shader_materials()` - 5 edges
10. `link_to_coll()` - 5 edges

## Surprising Connections (you probably didn't know these)
- `run()` --calls--> `build_or_update_shader_materials()`  [EXTRACTED]
  scratch/generate_armor_deck.py → scratch/generate_armor_deck.py  _Bridges community 14 → community 19_

## Import Cycles
- None detected.

## Communities (20 total, 7 thin omitted)

### Community 0 - "Project: Aegis-Hive — Дорожная карта разработки v2"
Cohesion: 0.12
Nodes (16): 6.1 Сюжетная кампания (3 Акта), 6.2 Живой город — система постоянных диалогов, Project: Aegis-Hive — Дорожная карта разработки v2, 🎨 Арт-пайплайн (параллельный трек), Готовые решения и аддоны (Accelerators), Общая философия разработки, Структура этапов, Технические решения (обновлено) (+8 more)

### Community 1 - "СПЕЦИФИКАЦИЯ ФАЙЛОВ"
Cohesion: 0.15
Nodes (10): 1. ТЕКУЩЕЕ ДЕРЕВО ПРОЕКТА (FILE TREE), 2. ТЕХНИЧЕСКИЙ РЕЕСТР ФАЙЛОВ И ПРАВИЛА АРХИТЕКТУРЫ, `docs/` (Регламенты, лор и статусы), PROJECT: AEGIS-HIVE — АРХИТЕКТУРНАЯ СТРУКТУРА, `scripts/defense/` (Оборонительная подсистема), `scripts/economy/` (Экономика и исследования), `scripts/networks/` (Подсистема логистики и сетей), `ui/` (Модульный бруталистский HUD) (+2 more)

### Community 2 - "2. Инструменты и источники ассетов"
Cohesion: 0.25
Nodes (7): 1. Спецификация изометрических ассетов, 2. Инструменты и источники ассетов, TOOLS — Инструменты и пайплайны генерации ассетов, А. Изометрические тайлы и здания (3D/2D), Б. 2D-портреты персонажей, изометрические спрайты и иллюстрации, В. Нормализация спрайтов зданий под сетку (Auto-Alignment Pipeline), Г. Обновление и импорт в Godot

### Community 3 - "normalize_building_sprites.py"
Cohesion: 0.20
Nodes (6): get_all_disk_files(), lint_case_sensitivity(), main(), find_bottom_vertex(), main(), normalize_sprite()

### Community 4 - "RULES — Правила совместной разработки"
Cohesion: 0.33
Nodes (5): 1. Схема взаимодействия по этапам, 2. [РЕЖИМ ПЛАНИРОВАНИЯ — Claude Opus], 3. [ДЕЙСТВИЯ ПОЛЬЗОВАТЕЛЯ ПО АРТ-ПАЙПЛАЙНУ], 4. [РЕЖИМ ИСПОЛНЕНИЯ — Gemini Flash], RULES — Правила совместной разработки

### Community 5 - "STYLE GUIDE & LORE — Мир, эстетика и арт-дирекшн Aegis-Hive"
Cohesion: 0.33
Nodes (5): 1. Концепция мира и Лор, 2. Ключевые референсы и «Вайб», 3. Спецификация спрайтов зданий (Изометрия), 4. Системный промпт для Gemini Argon (для генерации), STYLE GUIDE & LORE — Мир, эстетика и арт-дирекшн Aegis-Hive

### Community 6 - "STATE — Текущий статус проекта"
Cohesion: 0.40
Nodes (4): 1. Активный этап, 2. Статус всех этапов, 3. Окружение и технические заметки, STATE — Текущий статус проекта

### Community 7 - "STAGES — Глобальный роадмап проекта Aegis-Hive"
Cohesion: 0.50
Nodes (3): 1. Обзор этапов, 2. Параллельный арт-пайплайн, STAGES — Глобальный роадмап проекта Aegis-Hive

### Community 8 - "AEGIS-HIVE"
Cohesion: 0.17
Nodes (12): AEGIS-HIVE, Архитектура проекта, Быстрый старт, Запуск из исходного кода (Windows / Linux), Запуск на Linux / Steam Deck (без установки Godot), Источники вдохновения, Лицензия, О проекте (+4 more)

### Community 13 - "СТИЛИСТИЧЕСКИЙ МАНИФЕСТ И ГЛУБОКИЙ РЕСЕРЧ АРХИТЕКТУРЫ «AEGIS-HIVE»"
Cohesion: 0.20
Nodes (9): 1. Диагностика проблемы: почему модели начали терять эстетику?, 2. Глубокий анатомический разбор ключевых референсов, 3. Матрица визуального языка «Aegis-Hive» (Свод правил для 3D), 4. Архитектурный рецепт следующего поколения моделей, А. Tsutomu Nihei («BLAME!» / «Biomega») — Архитектура как подавляющая сила, Анализ источников: Tsutomu Nihei ("BLAME!"), Tsukumizu ("Girls' Last Tour"), Hideaki Anno / Ikuto Yamashita ("Neon Genesis Evangelion"), Б. Tsukumizu («Girls' Last Tour») — Меланхоличный монолит и «Вещь в себе», В. Hideaki Anno / Ikuto Yamashita («Neon Genesis Evangelion») — Милитаризм Токио-3 и Геофронта (+1 more)

### Community 16 - "export-linux"
Cohesion: 0.12
Nodes (15): env, name, runs-on, GODOT_CHANNEL, GODOT_VERSION, jobs, build-and-test-linux, name (+7 more)

### Community 17 - "steps"
Cohesion: 0.17
Nodes (12): steps, id, if, name, run, uses, with, files (+4 more)

### Community 19 - "run"
Cohesion: 0.44
Nodes (8): run(), add_bevel(), build_hydraulic_lock(), link_to_coll(), make_cable(), make_cube(), make_cylinder(), make_frustum_skirt()

## Knowledge Gaps
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Project: Aegis-Hive — Дорожная карта разработки v2` connect `Project: Aegis-Hive — Дорожная карта разработки v2` to `СПЕЦИФИКАЦИЯ ФАЙЛОВ`?**
  _High betweenness centrality (0.038) - this node is a cross-community bridge._
- **Should `Project: Aegis-Hive — Дорожная карта разработки v2` be split into smaller, more focused modules?**
  _Cohesion score 0.125 - nodes in this community are weakly interconnected._
- **Why does `AEGIS-HIVE` connect `AEGIS-HIVE` to `СПЕЦИФИКАЦИЯ ФАЙЛОВ`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **Should `export-linux` be split into smaller, more focused modules?**
  _Cohesion score 0.125 - nodes in this community are weakly interconnected._
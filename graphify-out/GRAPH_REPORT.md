# Graph Report - MegaProject  (2026-11-09)

## Corpus Check
- 13 files · ~7,181 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 98 file(s) not represented in the graph (top: .gd 33, .uid 33, .tres 18)
- WARNING: 98 of 161 files seen (61%) have no supported extractor and are missing from this graph entirely. It may look complete while representing only part of the codebase.

## Summary
- 83 nodes · 74 edges · 13 communities (9 shown, 4 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `a6e969a0`
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

## God Nodes (most connected - your core abstractions)
1. `Project: Aegis-Hive — Дорожная карта разработки v2` - 14 edges
2. `AEGIS-HIVE` - 8 edges
3. `2. Инструменты и источники ассетов` - 5 edges
4. `RULES — Правила совместной разработки` - 5 edges
5. `STYLE GUIDE & LORE — Мир, эстетика и арт-дирекшн Aegis-Hive` - 5 edges
6. `Быстрый старт` - 4 edges
7. `СПЕЦИФИКАЦИЯ ФАЙЛОВ` - 4 edges
8. `STATE — Текущий статус проекта` - 4 edges
9. `normalize_sprite()` - 3 edges
10. `2. ТЕХНИЧЕСКИЙ РЕЕСТР ФАЙЛОВ И ПРАВИЛА АРХИТЕКТУРЫ` - 3 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (13 total, 4 thin omitted)

### Community 0 - "Project: Aegis-Hive — Дорожная карта разработки v2"
Cohesion: 0.12
Nodes (16): 6.1 Сюжетная кампания (3 Акта), 6.2 Живой город — система постоянных диалогов, Project: Aegis-Hive — Дорожная карта разработки v2, 🎨 Арт-пайплайн (параллельный трек), Готовые решения и аддоны (Accelerators), Общая философия разработки, Структура этапов, Технические решения (обновлено) (+8 more)

### Community 1 - "СПЕЦИФИКАЦИЯ ФАЙЛОВ"
Cohesion: 0.18
Nodes (8): 1. ТЕКУЩЕЕ ДЕРЕВО ПРОЕКТА (FILE TREE), 2. ТЕХНИЧЕСКИЙ РЕЕСТР ФАЙЛОВ И ПРАВИЛА АРХИТЕКТУРЫ, `docs/` (Регламенты, лор и статусы), PROJECT: AEGIS-HIVE — АРХИТЕКТУРНАЯ СТРУКТУРА, `scripts/networks/` (Подсистема логистики и сетей), `ui/`, ГЛОБАЛЬНЫЕ СИСТЕМНЫЕ ИНВАРИАНТЫ, СПЕЦИФИКАЦИЯ ФАЙЛОВ

### Community 2 - "2. Инструменты и источники ассетов"
Cohesion: 0.25
Nodes (7): 1. Спецификация изометрических ассетов, 2. Инструменты и источники ассетов, TOOLS — Инструменты и пайплайны генерации ассетов, А. Изометрические тайлы и здания (3D/2D), Б. 2D-портреты персонажей, изометрические спрайты и иллюстрации, В. Нормализация спрайтов зданий под сетку (Auto-Alignment Pipeline), Г. Обновление и импорт в Godot

### Community 3 - "normalize_building_sprites.py"
Cohesion: 0.32
Nodes (3): find_bottom_vertex(), main(), normalize_sprite()

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
Nodes (12): AEGIS-HIVE, Архитектура проекта, Быстрый старт, Запуск из командной строки, Запуск через редактор, Источники вдохновения, Лицензия, О проекте (+4 more)

## Knowledge Gaps
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Project: Aegis-Hive — Дорожная карта разработки v2` connect `Project: Aegis-Hive — Дорожная карта разработки v2` to `СПЕЦИФИКАЦИЯ ФАЙЛОВ`?**
  _High betweenness centrality (0.135) - this node is a cross-community bridge._
- **Should `Project: Aegis-Hive — Дорожная карта разработки v2` be split into smaller, more focused modules?**
  _Cohesion score 0.125 - nodes in this community are weakly interconnected._
- **Why does `AEGIS-HIVE` connect `AEGIS-HIVE` to `СПЕЦИФИКАЦИЯ ФАЙЛОВ`?**
  _High betweenness centrality (0.104) - this node is a cross-community bridge._
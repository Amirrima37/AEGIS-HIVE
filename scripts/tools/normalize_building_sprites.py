#!/usr/bin/env python3
"""
scripts/tools/normalize_building_sprites.py

Пайплайн нормализации и выравнивания изометрических спрайтов зданий под сетку Godot 4 (2:1).
Автоматически:
1. Измеряет ширину и положение основания здания (Diegetic Status Rim).
2. Масштабирует изображение (LANCZOS) так, чтобы ширина ромба основания строго равнялась size.x * 128 px.
3. Центрирует основание по горизонтали (X = target_w / 2).
4. Размещает нижнюю вершину ромба на y = canvas_h - 3 (с сохранением 2px антиалиасинга).
5. Приводит спрайты всех зданий к единому математическому инварианту:
   Sprite2D.offset = Vector2(0, size.x * 32.0 + 3.0 - texture_height * 0.5)
"""

import os
import sys
from PIL import Image

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SPRITES_DIR = os.path.join(PROJECT_ROOT, 'assets', 'sprites', 'buildings')
BACKUP_DIR = os.path.join(PROJECT_ROOT, 'assets', 'sprites', 'buildings_backup')

SPECS = {
    'command_center.png': 3,
    'fusion_reactor.png': 2,
    'quarry.png': 2,
    'factory.png': 2,
    'habitation_block.png': 1,
    'support_pillar.png': 1,
    'excavation_rig.png': 2,
    'power_cable.png': 1,
    'conveyor.png': 1,
    'shaft_elevator.png': 2,
    'warehouse.png': 2
}

def find_bottom_vertex(im):
    w, h = im.size
    pixels = im.load()
    bbox = im.getbbox()
    if not bbox:
        return w / 2.0, h / 2.0
    bot_y = 0
    bot_x = 0
    for y in range(h - 1, -1, -1):
        for x in range(w):
            if pixels[x, y][3] > 80:
                bot_y = y
                bot_x = x
                break
        if bot_y > 0:
            break
    row_x = [x for x in range(w) if pixels[x, bot_y][3] > 80]
    if row_x:
        bot_x = sum(row_x) / float(len(row_x))
    return bot_x, bot_y

def normalize_sprite(src_path, dst_path, size_tiles):
    target_w = size_tiles * 128
    target_diamond_h = size_tiles * 64
    
    im = Image.open(src_path).convert('RGBA')
    w, h = im.size
    pixels = im.load()
    bbox = im.getbbox()
    if not bbox:
        print(f"Skipping empty image: {src_path}")
        return
        
    bot_x, bot_y = find_bottom_vertex(im)
    mid_x = w / 2.0
    
    # Ищем левый край ромба основания (угол ромба)
    min_x = w
    for y in range(int(bot_y), max(0, int(bot_y - w * 0.4)), -1):
        for x in range(int(mid_x)):
            if pixels[x, y][3] > 80:
                if x < min_x:
                    min_x = x
                break
                
    curr_rim_w = (mid_x - min_x) * 2.0
    if curr_rim_w <= 0:
        curr_rim_w = target_w
    scale = target_w / float(curr_rim_w)
    
    new_w = int(round(w * scale))
    new_h = int(round(h * scale))
    scaled = im.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    s_bot_x, s_bot_y = find_bottom_vertex(scaled)
    s_bbox = scaled.getbbox()
    
    margin_bottom = 2
    content_top = s_bbox[1]
    canvas_h = int(s_bot_y - content_top + margin_bottom + 4)
    if canvas_h % 2 != 0:
        canvas_h += 1
        
    out_im = Image.new('RGBA', (target_w, canvas_h), (0, 0, 0, 0))
    target_bot_x = target_w / 2.0
    target_bot_y = canvas_h - 1 - margin_bottom
    
    paste_x = int(round(target_bot_x - s_bot_x))
    paste_y = int(round(target_bot_y - s_bot_y))
    out_im.paste(scaled, (paste_x, paste_y), scaled)
    
    out_im.save(dst_path)
    
    # Проверка
    v_bot_x, v_bot_y = find_bottom_vertex(out_im)
    v_base_cy = v_bot_y - (target_diamond_h / 2.0)
    offset_y = (target_diamond_h * 0.5 + margin_bottom + 1.0) - canvas_h * 0.5
    
    print(f"[{size_tiles}x{size_tiles}] {os.path.basename(src_path):20s} -> {target_w}x{canvas_h} px | base_center_y={v_base_cy:.1f} | offset_y={offset_y:.1f}")

def main():
    if not os.path.exists(BACKUP_DIR):
        print(f"Error: Backup directory not found: {BACKUP_DIR}")
        return
        
    print(f"=== Нормализация спрайтов зданий в {SPRITES_DIR} ===")
    for filename, size_tiles in SPECS.items():
        src = os.path.join(BACKUP_DIR, filename)
        dst = os.path.join(SPRITES_DIR, filename)
        if os.path.exists(src):
            normalize_sprite(src, dst, size_tiles)
        else:
            print(f"Warning: {filename} not found in backup")
    print("=== Нормализация успешно завершена ===")

if __name__ == '__main__':
    main()

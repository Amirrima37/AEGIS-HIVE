#!/usr/bin/env python3
"""
scripts/tools/lint_file_casing.py

Automated Case-Sensitivity Linter for Godot 4.
Validates that all res:// path references in .gd, .tscn, .tres, and .godot files
match the exact disk case on Linux/Unix file systems (ext4/btrfs/xfs).

Returns exit code 0 on success, 1 on case-mismatch or missing files.
"""

import os
import re
import sys

IGNORED_DIRS = {'.git', '.godot', 'graphify-out', 'builds', 'scratch', 'assets/sprites/buildings_backup'}
VALID_EXTENSIONS = ('.gd', '.tscn', '.tres', '.png', '.svg', '.wav', '.ogg', '.mp3', '.cfg', '.godot')

def get_all_disk_files(root_dir):
    files_map = {}
    for root, dirs, files in os.walk(root_dir):
        # Filter out ignored directories
        dirs[:] = [d for d in dirs if d not in IGNORED_DIRS and not any(ign in os.path.join(root, d).replace('\\', '/') for ign in IGNORED_DIRS)]
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), root_dir).replace('\\', '/')
            files_map[rel.lower()] = rel
    return files_map

def lint_case_sensitivity(root_dir):
    disk_files = get_all_disk_files(root_dir)
    res_pattern = re.compile(r'res://([a-zA-Z0-9_\-/\.]+)')
    errors = []

    for root, dirs, files in os.walk(root_dir):
        dirs[:] = [d for d in dirs if d not in IGNORED_DIRS and not any(ign in os.path.join(root, d).replace('\\', '/') for ign in IGNORED_DIRS)]
        for f in files:
            if f.endswith(('.gd', '.tscn', '.tres', '.godot')):
                full_path = os.path.join(root, f)
                rel_source = os.path.relpath(full_path, root_dir).replace('\\', '/')
                with open(full_path, 'r', encoding='utf-8', errors='ignore') as fh:
                    content = fh.read()
                    matches = res_pattern.findall(content)
                    for m in matches:
                        clean_ref = m.strip()
                        # Ignore dynamic format string stems like res://data/buildings/
                        if not any(clean_ref.endswith(ext) for ext in VALID_EXTENSIONS):
                            continue
                        
                        lower_ref = clean_ref.lower()
                        if lower_ref in disk_files:
                            actual = disk_files[lower_ref]
                            if actual != clean_ref:
                                errors.append({
                                    'file': rel_source,
                                    'reference': clean_ref,
                                    'actual_on_disk': actual,
                                    'type': 'CASE_MISMATCH'
                                })
                        else:
                            errors.append({
                                'file': rel_source,
                                'reference': clean_ref,
                                'actual_on_disk': 'MISSING',
                                'type': 'NOT_FOUND'
                            })

    return errors

def main():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
    print(f"[INFO] Running case-sensitivity linter on: {root_dir}")
    errors = lint_case_sensitivity(root_dir)

    if errors:
        print(f"\n[ERROR] Found {len(errors)} path issue(s) that will break Linux builds:\n")
        for err in errors:
            print(f"  Source: {err['file']}")
            print(f"    Referenced : res://{err['reference']}")
            print(f"    On Disk    : {err['actual_on_disk']}")
            print(f"    Error Type : {err['type']}\n")
        sys.exit(1)
    else:
        print("[SUCCESS] All res:// references match disk case perfectly! Ready for Linux.")
        sys.exit(0)

if __name__ == '__main__':
    main()

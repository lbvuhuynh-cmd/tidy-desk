"""Checks every TidyDesk/Resources/Levels/level_<n>.json (schema: schema/level_schema.json).

For every level:
  * required keys / types, file number == levelId, levelIds unique, item ids unique,
  * known category (optional), every item fits the desk,
  * total item area == gridRows * gridCols (the desk ends up exactly full),
  * initialPosition: in bounds, no overlaps, at least one item starts in the drawer,
  * correctPosition (optional, "fixed target" levels): in bounds, no overlaps, and if every item has one
    they must tile the whole desk,
  * an exact tiling exists (items may also be rotated, like tap-to-rotate in the game),
  * "forced": with the messy items left where they are (and other items free to rotate) the desk can NOT be
    finished -> the player really has to tidy up. Free-fit levels with messy items must be forced.

Usage:  python tools/check_levels.py
"""
import json
import re
import sys
from pathlib import Path

LEVEL_DIR = Path(__file__).resolve().parent.parent / "TidyDesk" / "Resources" / "Levels"
CATEGORIES = {"peripheral", "display", "audio", "mobile", "power", "cozy"}
LEVEL_KEYS = {"levelId": int, "levelName": str, "gridRows": int, "gridCols": int, "items": list}
ITEM_KEYS = {"id": str, "name": str, "gridWidth": int, "gridHeight": int, "imageName": str}


def count_tilings(rows, cols, sizes, fixed=None, limit=10_000, rotate=False):
    """Exact cover count. `fixed` = {index: (row, col)} pinned first (authored orientation).
    With `rotate`, free items may also be placed turned 90 degrees."""
    grid = [[False] * cols for _ in range(rows)]
    used = [False] * len(sizes)

    def fits(r, c, w, h):
        if r < 0 or c < 0 or r + h > rows or c + w > cols:
            return False
        return all(not grid[rr][cc] for rr in range(r, r + h) for cc in range(c, c + w))

    def mark(r, c, w, h, value):
        for rr in range(r, r + h):
            for cc in range(c, c + w):
                grid[rr][cc] = value

    for i, (r, c) in (fixed or {}).items():
        w, h = sizes[i]
        if not fits(r, c, w, h):
            return -1
        mark(r, c, w, h, True)
        used[i] = True

    count = 0

    def first_empty():
        for r in range(rows):
            for c in range(cols):
                if not grid[r][c]:
                    return r, c
        return None

    def search():
        nonlocal count
        if count >= limit:
            return
        cell = first_empty()
        if cell is None:
            if all(used):
                count += 1
            return
        r, c = cell
        tried = set()
        for i, (bw, bh) in enumerate(sizes):
            if used[i]:
                continue
            shape = (min(bw, bh), max(bw, bh)) if rotate else (bw, bh)
            options = {(bw, bh), (bh, bw)} if rotate else {(bw, bh)}
            for (w, h) in options:
                if (shape, w, h) in tried:
                    continue
                tried.add((shape, w, h))
                if fits(r, c, w, h):
                    used[i] = True
                    mark(r, c, w, h, True)
                    search()
                    mark(r, c, w, h, False)
                    used[i] = False

    search()
    return count


def pos(p):
    return (p["row"], p["col"]) if p else None


def check_level(path, data, errors):
    tag = path.name
    for key, kind in LEVEL_KEYS.items():
        if not isinstance(data.get(key), kind):
            errors.append(f"{tag}: '{key}' missing or not {kind.__name__}")
            return None
    m = re.fullmatch(r"level_(\d+)\.json", path.name)
    if m and int(m.group(1)) != data["levelId"]:
        errors.append(f"{tag}: file number {m.group(1)} != levelId {data['levelId']}")

    rows, cols = data["gridRows"], data["gridCols"]
    sizes, starts, targets, ids = [], {}, {}, []
    for i, it in enumerate(data["items"]):
        for key, kind in ITEM_KEYS.items():
            if not isinstance(it.get(key), kind):
                errors.append(f"{tag}: item {i} '{key}' missing or not {kind.__name__}")
        if "category" in it and it["category"] not in CATEGORIES:
            errors.append(f"{tag}: {it.get('id')} has unknown category {it['category']}")
        w, h = it.get("gridWidth", 0), it.get("gridHeight", 0)
        if not ((w <= cols and h <= rows) or (h <= cols and w <= rows)) or w < 1 or h < 1:
            errors.append(f"{tag}: {it.get('id')} ({w}x{h}) does not fit a {cols}x{rows} desk")
        sizes.append((w, h))
        ids.append(it.get("id"))
        if it.get("initialPosition"):
            starts[i] = pos(it["initialPosition"])
        if it.get("correctPosition"):
            targets[i] = pos(it["correctPosition"])
    if len(set(ids)) != len(ids):
        errors.append(f"{tag}: item ids are not unique")

    area = sum(w * h for w, h in sizes)
    if area != rows * cols:
        errors.append(f"{tag}: item area {area} != desk area {rows * cols}")
        return None
    if len(starts) == len(sizes):
        errors.append(f"{tag}: every item starts on the desk; nothing left in the drawer")

    n = count_tilings(rows, cols, sizes)
    n_rot = count_tilings(rows, cols, sizes, rotate=True)
    if n_rot == 0:
        errors.append(f"{tag}: no tiling exists")

    if count_tilings(rows, cols, sizes, starts, limit=1, rotate=True) == -1:
        errors.append(f"{tag}: initialPosition values overlap or stick out")

    mode = "free"
    forced = "-"
    if targets:
        mode = "fixed"
        tgt_only = [sizes[i] for i in targets]
        if count_tilings(rows, cols, sizes, targets, limit=1) == -1:
            errors.append(f"{tag}: correctPosition values overlap or stick out")
        elif len(targets) == len(sizes) and sum(w * h for w, h in tgt_only) != rows * cols:
            errors.append(f"{tag}: correctPositions do not cover the desk")
        elif count_tilings(rows, cols, sizes, targets, limit=1) == 0:
            errors.append(f"{tag}: the other items cannot fill the desk around the fixed targets")
        wrong = [i for i in starts if i in targets and starts[i] == targets[i]]
        if starts and len(wrong) == len(starts):
            errors.append(f"{tag}: every messy item already starts on its correct spot")
    elif starts:
        with_mess = count_tilings(rows, cols, sizes, starts, rotate=True)
        if with_mess > 0:
            errors.append(f"{tag}: desk can be finished without moving the messy items")
            forced = "NO"
        elif with_mess == 0:
            forced = "yes"

    print(f"{tag:<14} #{data['levelId']:<3} {cols}x{rows}  items={len(sizes):<2} messy={len(starts)} "
          f"mode={mode:<5} forced={forced:<3} solutions={n:<5} with-rotation={n_rot}")
    return data["levelId"]


def main():
    errors = []
    files = sorted(LEVEL_DIR.glob("level_*.json"), key=lambda p: int(re.sub(r"\D", "", p.stem) or 0))
    if not files:
        print(f"No level files in {LEVEL_DIR}")
        sys.exit(1)
    seen = set()
    for path in files:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            errors.append(f"{path.name}: invalid JSON ({e})")
            continue
        level_id = check_level(path, data, errors)
        if level_id is not None:
            if level_id in seen:
                errors.append(f"{path.name}: duplicate levelId {level_id}")
            seen.add(level_id)

    if errors:
        print("\nERRORS:")
        for e in errors:
            print("  -", e)
        sys.exit(1)
    print(f"\nAll {len(files)} level files OK.")


if __name__ == "__main__":
    main()

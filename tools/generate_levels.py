"""Generates the chapter levels (level_9.json ... ) from item pools, deterministically (fixed seed).

Each generated level:
  * is built from a random exact tiling of the desk, so it is always solvable;
  * has its item count tuned to the chapter's difficulty curve;
  * has 1-3 "messy" items placed on the desk in a wrong spot such that the desk can NOT be finished
    with them left there (even with rotation) -> the player really has to tidy up ("forced");
  * keeps every item in its pool footprint (one asset name = one footprint, see ASSETS.md).

Levels 1-8 are hand-made; this script only writes the ids listed in CHAPTERS and leaves other files alone.
Re-running with the same SEED reproduces the same files. Validate afterwards: python tools/check_levels.py

Usage:  python tools/generate_levels.py          (dry run: prints a summary)
        python tools/generate_levels.py --write  (writes the JSON files)
"""
import json
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_levels import count_tilings  # noqa: E402

LEVEL_DIR = Path(__file__).resolve().parent.parent / "TidyDesk" / "Resources" / "Levels"
SEED = 20261112

# imageName: (w, h, display name, SF Symbol fallback, category). Footprints must match existing levels.
ITEMS = {
    # Tech (already used by levels 1-8)
    "cable_bundle": (2, 1, "Cable Bundle", "cable.connector", "power"),
    "coffee_mug": (1, 1, "Coffee Mug", "cup.and.saucer.fill", "cozy"),
    "desk_lamp": (1, 2, "Desk Lamp", "lamp.desk.fill", "cozy"),
    "desk_lamp_tall": (1, 3, "Tall Desk Lamp", "lamp.desk.fill", "cozy"),
    "desk_mat": (2, 2, "Mouse Pad", "rectangle.fill", "peripheral"),
    "game_controller": (2, 1, "Controller", "gamecontroller.fill", "peripheral"),
    "headphones": (2, 2, "Headphones", "headphones", "audio"),
    "keyboard_compact": (3, 1, "Compact Keyboard", "keyboard.fill", "peripheral"),
    "keyboard_fullsize": (5, 1, "Full Keyboard", "keyboard.fill", "peripheral"),
    "keyboard_mechanical": (4, 1, "Mechanical Keyboard", "keyboard.fill", "peripheral"),
    "laptop": (3, 2, "Laptop", "laptopcomputer", "display"),
    "laptop_gaming": (2, 2, "Gaming Laptop", "laptopcomputer", "display"),
    "mic_boom": (1, 3, "Boom Mic", "mic.fill", "audio"),
    "microphone": (1, 2, "Microphone", "mic.fill", "audio"),
    "monitor": (3, 2, "Monitor", "display", "display"),
    "monitor_ultrawide": (4, 2, "Ultrawide Monitor", "display", "display"),
    "mouse_on_mat": (2, 1, "Mouse on Mat", "computermouse.fill", "peripheral"),
    "mouse_wireless": (1, 1, "Mouse", "computermouse.fill", "peripheral"),
    "notebook": (1, 2, "Notebook", "book.closed.fill", "cozy"),
    "phone": (1, 2, "Phone", "iphone", "mobile"),
    "plant": (1, 1, "Plant", "leaf.fill", "cozy"),
    "power_strip": (3, 1, "Power Strip", "powerplug.fill", "power"),
    "speaker": (1, 2, "Speaker", "hifispeaker.fill", "audio"),
    "speaker_tower": (1, 3, "Tower Speaker", "hifispeaker.fill", "audio"),
    "tablet": (2, 2, "Tablet", "ipad.landscape", "display"),
    "webcam": (1, 1, "Webcam", "web.camera.fill", "mobile"),
    "wifi_router": (2, 2, "Wi-Fi Router", "wifi.router.fill", "power"),
    # Garden (new in chapter 4; SF Symbols until the pictures exist)
    "seed_packet": (1, 1, "Seed Packet", "leaf.circle.fill", "garden"),
    "succulent_pot": (1, 1, "Succulent", "leaf.fill", "garden"),
    "birdhouse": (1, 1, "Birdhouse", "bird.fill", "garden"),
    "flower_pot": (1, 2, "Flower Pot", "camera.macro", "garden"),
    "pruning_shears": (1, 2, "Pruning Shears", "scissors", "garden"),
    "garden_gloves": (1, 2, "Garden Gloves", "hand.raised.fill", "garden"),
    "grow_light": (1, 3, "Grow Light", "sun.max.fill", "garden"),
    "seedling_tray": (2, 1, "Seedling Tray", "leaf.arrow.triangle.circlepath", "garden"),
    "watering_can": (2, 2, "Watering Can", "drop.fill", "garden"),
    "monstera_pot": (2, 2, "Monstera", "tree.fill", "garden"),
    "herb_planter": (3, 1, "Herb Planter", "leaf.fill", "garden"),
    "flower_box": (4, 1, "Flower Box", "camera.macro", "garden"),
    "garden_basket": (3, 2, "Harvest Basket", "basket.fill", "garden"),
    "soil_bag": (2, 3, "Soil Bag", "bag.fill", "garden"),
}

OFFICE = ["monitor", "laptop", "keyboard_compact", "keyboard_mechanical", "mouse_wireless", "mouse_on_mat",
          "coffee_mug", "plant", "webcam", "notebook", "phone", "desk_lamp", "desk_lamp_tall", "tablet",
          "desk_mat", "wifi_router", "power_strip", "cable_bundle", "speaker"]
GAMING = ["monitor_ultrawide", "monitor", "laptop_gaming", "headphones", "game_controller", "keyboard_mechanical",
          "keyboard_fullsize", "keyboard_compact", "mouse_on_mat", "mouse_wireless", "mic_boom", "microphone",
          "speaker_tower", "speaker", "webcam", "cable_bundle", "power_strip", "coffee_mug", "desk_lamp", "desk_mat"]
GARDEN = ["seed_packet", "succulent_pot", "birdhouse", "plant", "flower_pot", "pruning_shears", "garden_gloves",
          "grow_light", "seedling_tray", "watering_can", "monstera_pot", "herb_planter", "flower_box",
          "garden_basket", "soil_bag", "coffee_mug", "notebook"]

# Difficulty curve inside a chapter: (cols, rows, target item count, messy items).
CURVE = [(4, 3, 4, 1), (5, 3, 5, 1), (4, 4, 6, 1), (5, 4, 7, 2), (6, 4, 8, 2),
         (5, 5, 8, 2), (6, 5, 9, 2), (7, 5, 10, 3), (7, 6, 12, 3), (8, 6, 13, 3)]

CHAPTERS = [
    ("Office Hours", 9, OFFICE, [
        "Inbox Zero", "Morning Standup", "Quiet Corner", "Spreadsheet Day", "Video Call Ready",
        "Second Screen", "Lunch at the Desk", "Deadline Mode", "Corner Office", "Friday Wrap-Up"]),
    ("Gaming Den", 19, GAMING, [
        "Couch Co-op", "Retro Night", "First Stream", "Headset On", "Ranked Match",
        "LAN Party", "Speedrun", "Late Night Raid", "Tournament Prep", "Ultimate Rig"]),
    ("Garden Corner", 29, GARDEN, [
        "Seed Starting", "Windowsill Herbs", "Sunny Ledge", "Potting Bench", "Spring Planting",
        "Watering Day", "Little Greenhouse", "Harvest Time", "Balcony Garden", "Blooming Bench"]),
]
FIRST_CHAPTER = "First Desks"  # levels 1-8 (hand-made)


def random_tiling(rng, cols, rows, pool, target, prefer=frozenset()):
    """Random exact cover of the desk with pool items (each at most twice). Returns [(name, r, c, rotated)].
    Items in `prefer` (not used yet in this chapter) are tried first, so every chapter item shows up somewhere."""
    grid = [[False] * cols for _ in range(rows)]
    placed, uses = [], {}

    def first_empty():
        for r in range(rows):
            for c in range(cols):
                if not grid[r][c]:
                    return r, c
        return None

    def fits(r, c, w, h):
        return r + h <= rows and c + w <= cols and all(not grid[rr][cc] for rr in range(r, r + h)
                                                       for cc in range(c, c + w))

    def mark(r, c, w, h, v):
        for rr in range(r, r + h):
            for cc in range(c, c + w):
                grid[rr][cc] = v

    # Bias towards the item size that hits the target count.
    avg = cols * rows / target
    budget = [4000]

    def search():
        budget[0] -= 1
        if budget[0] < 0:
            return False
        cell = first_empty()
        if cell is None:
            return True
        r, c = cell
        names = pool[:]
        rng.shuffle(names)
        names.sort(key=lambda n: abs(ITEMS[n][0] * ITEMS[n][1] - avg) + rng.random() * 2.5 - (2.5 if n in prefer and rng.random() < 0.6 else 0))
        for name in names:
            if uses.get(name, 0) >= 2:
                continue
            w, h = ITEMS[name][:2]
            options = [(w, h, False)] + ([(h, w, True)] if w != h else [])
            rng.shuffle(options)
            for (ww, hh, rot) in options:
                if fits(r, c, ww, hh):
                    mark(r, c, ww, hh, True)
                    uses[name] = uses.get(name, 0) + 1
                    placed.append((name, r, c, rot))
                    if search():
                        return True
                    placed.pop()
                    uses[name] -= 1
                    mark(r, c, ww, hh, False)
        return False

    return placed if search() else None


def choose_mess(rng, cols, rows, sizes, solution, k):
    """Pick k items + wrong starting spots (authored orientation) that force the player to move them."""
    candidates = [i for i, (w, h) in enumerate(sizes) if w * h >= 2] or list(range(len(sizes)))
    for _ in range(400):
        chosen = rng.sample(candidates, min(k, len(candidates)))
        if len(chosen) >= len(sizes):
            continue
        starts, occupied, ok = {}, set(), True
        for i in chosen:
            w, h = sizes[i]
            spots = [(r, c) for r in range(rows - h + 1) for c in range(cols - w + 1)]
            rng.shuffle(spots)
            for (r, c) in spots:
                cells = {(rr, cc) for rr in range(r, r + h) for cc in range(c, c + w)}
                if cells & occupied:
                    continue
                if solution.get(i) == (r, c, False):
                    continue  # not "messy" if it already sits where the tiling put it
                starts[i] = (r, c)
                occupied |= cells
                break
            else:
                ok = False
                break
        if ok and count_tilings(rows, cols, sizes, starts, limit=1, rotate=True) == 0:
            return starts
    return None


def build_level(rng, level_id, name, chapter, pool, cols, rows, target, messy, prefer=frozenset()):
    for attempt in range(300):
        # Preferring unused items can skew the item count; after 150 tries fall back to a plain random tiling.
        tiling = random_tiling(rng, cols, rows, pool, target, prefer if attempt < 150 else frozenset())
        if not tiling or abs(len(tiling) - target) > 1:
            continue
        rng.shuffle(tiling)  # drawer order != board order
        sizes = [ITEMS[n][:2] for (n, _, _, _) in tiling]
        solution = {i: (r, c, rot) for i, (_, r, c, rot) in enumerate(tiling)}
        starts = choose_mess(rng, cols, rows, sizes, solution, messy)
        if starts is None:
            continue
        items, counts = [], {}
        # Messy items first in the file (they start on the desk), then the drawer in shuffled order.
        order = sorted(range(len(tiling)), key=lambda i: (i not in starts, i))
        for i in order:
            img = tiling[i][0]
            w, h, label, symbol, category = ITEMS[img]
            counts[img] = counts.get(img, 0) + 1
            item_id = img.replace("_", "-") + (f"-{counts[img]}" if counts[img] > 1 else "")
            item = {"id": item_id, "name": label, "gridWidth": w, "gridHeight": h}
            if i in starts:
                item["initialPosition"] = {"row": starts[i][0], "col": starts[i][1]}
            item.update({"imageName": img, "symbol": symbol, "category": category})
            items.append(item)
        return {"levelId": level_id, "levelName": name, "chapter": chapter,
                "gridRows": rows, "gridCols": cols, "items": items}
    raise RuntimeError(f"could not build level {level_id}")


def main():
    write = "--write" in sys.argv
    rng = random.Random(SEED)
    for chapter, first_id, pool, names in CHAPTERS:
        used = set()
        for step, ((cols, rows, target, messy), name) in enumerate(zip(CURVE, names)):
            level_id = first_id + step
            # Every chapter item should show up at least once (e.g. monitors in the office chapter).
            prefer = frozenset(n for n in pool if n not in used)
            level = build_level(rng, level_id, name, chapter, pool, cols, rows, target, messy, prefer)
            used.update(it["imageName"] for it in level["items"])
            print(f"#{level_id:<3} {chapter:<14} {name:<20} {cols}x{rows} items={len(level['items']):<2} "
                  f"messy={sum(1 for it in level['items'] if 'initialPosition' in it)}")
            if write:
                path = LEVEL_DIR / f"level_{level_id}.json"
                path.write_text(json.dumps(level, indent=2) + "\n", encoding="utf-8")
        missing = [n for n in pool if n not in used]
        if missing:
            print(f"   note: {chapter} never uses {', '.join(missing)}")
    if write:
        # Hand-made levels 1-8 belong to the first chapter.
        for level_id in range(1, 9):
            path = LEVEL_DIR / f"level_{level_id}.json"
            data = json.loads(path.read_text(encoding="utf-8"))
            if data.get("chapter") != FIRST_CHAPTER:
                data = {"levelId": data["levelId"], "levelName": data["levelName"], "chapter": FIRST_CHAPTER,
                        **{k: v for k, v in data.items() if k not in ("levelId", "levelName", "chapter")}}
                path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        print("written; now run: python tools/check_levels.py")


if __name__ == "__main__":
    main()

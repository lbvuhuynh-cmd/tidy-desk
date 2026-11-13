"""Cuts a sheet of several objects (one AI image with 4-9 items on a plain background) into one PNG per item.

How it works:
  1. removes the flat background (same flood fill as check_assets.py --import),
  2. finds each separate object (pieces close together, e.g. a sparkle next to a pot, count as one),
  3. orders them like reading text: top row left -> right, then the next row,
  4. saves <name>.png for each, in that order, cropped tight with a small margin.

Usage:
  python tools/split_sheet.py <sheet.png|jpg> <out folder> name1 name2 name3 ...
  python tools/split_sheet.py sheet.jpg out/                   (no names: preview, saves item_01.png ...)
  python tools/split_sheet.py --gap=0.004 sheet.jpg out/ a b c  (items drawn close together: merge less)

Then import as usual:  python tools/check_assets.py --import <out folder>

Needs Pillow (pip install pillow). Prints the size of every piece found; if the count doesn't match the names,
nothing is named wrongly: the pieces are saved as item_01.png ... so you can look and rename.
"""
import sys
from collections import deque
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_assets import clean_png  # noqa: E402


def find_boxes(alpha_mask, w, h, step):
    """Connected components on a downsampled mask -> (label grid, boxes). Each box is
    [x0, y0, x1, y1, cells, {labels}] in full-size pixels; the grid holds the component label of every cell."""
    gw, gh = (w + step - 1) // step, (h + step - 1) // step
    grid = bytearray(gw * gh)
    for gy in range(gh):
        for gx in range(gw):
            x0, y0 = gx * step, gy * step
            if any(alpha_mask[y * w + x] for y in range(y0, min(h, y0 + step), 2)
                   for x in range(x0, min(w, x0 + step), 2)):
                grid[gy * gw + gx] = 1
    seen = bytearray(gw * gh)
    labels = [0] * (gw * gh)
    boxes = []
    for start in range(gw * gh):
        if not grid[start] or seen[start]:
            continue
        queue = deque([start])
        seen[start] = 1
        label = len(boxes) + 1
        minx = miny = 10 ** 9
        maxx = maxy = -1
        cells = 0
        while queue:
            i = queue.popleft()
            labels[i] = label
            gx, gy = i % gw, i // gw
            cells += 1
            minx, maxx, miny, maxy = min(minx, gx), max(maxx, gx), min(miny, gy), max(maxy, gy)
            for nx, ny in ((gx + 1, gy), (gx - 1, gy), (gx, gy + 1), (gx, gy - 1)):
                if 0 <= nx < gw and 0 <= ny < gh:
                    j = ny * gw + nx
                    if grid[j] and not seen[j]:
                        seen[j] = 1
                        queue.append(j)
        boxes.append([minx * step, miny * step, min(w, (maxx + 1) * step), min(h, (maxy + 1) * step), cells, {label}])
    return (labels, gw), boxes


def merge_close(boxes, gap):
    """Merges a small piece into the object box it overlaps or nearly touches (stray bits belong to the nearest object)."""
    changed = True
    while changed:
        changed = False
        for i in range(len(boxes)):
            for j in range(i + 1, len(boxes)):
                a, b = boxes[i], boxes[j]
                near = a[0] - gap <= b[2] and b[0] - gap <= a[2] and a[1] - gap <= b[3] and b[1] - gap <= a[3]
                # Only a small piece (sparkle, cable end, loose part) joins its neighbour; two real objects whose
                # boxes overlap (e.g. a boom arm reaching over a speaker) stay separate.
                small = min(a[4], b[4]) < 0.12 * max(a[4], b[4])
                if near and small:
                    boxes[i] = [min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3]), a[4] + b[4], a[5] | b[5]]
                    del boxes[j]
                    changed = True
                    break
            if changed:
                break
    return boxes


def reading_order(boxes):
    """Rows by vertical centre (an item joins a row if it overlaps the row's band), then left to right."""
    boxes = sorted(boxes, key=lambda b: (b[1] + b[3]) / 2)
    rows = []
    for b in boxes:
        cy = (b[1] + b[3]) / 2
        for row in rows:
            top = min(r[1] for r in row)
            bottom = max(r[3] for r in row)
            if top <= cy <= bottom:
                row.append(b)
                break
        else:
            rows.append([b])
    return [b for row in rows for b in sorted(row, key=lambda r: r[0])]


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    args = [a for a in sys.argv[1:] if not a.startswith("--gap=")]
    gap_ratio = next((float(a[6:]) for a in sys.argv[1:] if a.startswith("--gap=")), 0.015)
    if len(args) < 2:
        sys.exit(__doc__)
    sheet, out = Path(args[0]), Path(args[1])
    names = args[2:]
    out.mkdir(parents=True, exist_ok=True)

    from PIL import Image
    cleaned = out / "_sheet_clean.png"
    notes = clean_png(sheet, cleaned)
    if "removed opaque background" not in notes:
        print("WARNING: no flat background found (corners differ). Ask for a plain single-colour background.")
    im = Image.open(cleaned).convert("RGBA")
    w, h = im.size
    alpha = im.getchannel("A").tobytes()
    mask = bytes(1 if a > 40 else 0 for a in alpha)

    step = max(2, min(w, h) // 300)
    (label_grid, gw), boxes = find_boxes(mask, w, h, step)
    if not boxes:
        sys.exit("No objects found.")
    biggest = max(b[4] for b in boxes)
    boxes = [b for b in boxes if b[4] >= biggest * 0.01]           # drop specks / noise
    boxes = merge_close(boxes, gap=int(gap_ratio * max(w, h)))
    boxes = reading_order(boxes)

    print(f"{sheet.name}: {len(boxes)} item(s) found")
    use_names = len(names) == len(boxes)
    if names and not use_names:
        print(f"WARNING: {len(names)} names given but {len(boxes)} items found -> saving as item_NN.png; "
              "look at them, then rename (or regenerate with more space between items).")
    pad = max(2, int(0.01 * max(w, h)))
    for index, (x0, y0, x1, y1, _, own) in enumerate(boxes, start=1):
        cx0, cy0, cx1, cy1 = max(0, x0 - pad), max(0, y0 - pad), min(w, x1 + pad), min(h, y1 + pad)
        crop = im.crop((cx0, cy0, cx1, cy1))
        # Keep only this object's pixels: a neighbour reaching into the box (e.g. a boom arm over a speaker)
        # is erased. Cells with no label (background / soft fringe) stay as they are.
        # Unlabelled cells next to a neighbour's cells (its soft anti-aliased fringe) are erased too.
        gh = len(label_grid) // gw

        def foreign(gx, gy):
            lab = label_grid[gy * gw + gx]
            if lab:
                return lab not in own
            near = [label_grid[ny * gw + nx] for ny in range(max(0, gy - 1), min(gh, gy + 2))
                    for nx in range(max(0, gx - 1), min(gw, gx + 2))]
            return any(n and n not in own for n in near) and not any(n in own for n in near)

        verdict = {}
        cp = crop.load()
        for y in range(crop.size[1]):
            gy = (cy0 + y) // step
            for x in range(crop.size[0]):
                gx = (cx0 + x) // step
                key = (gx, gy)
                if key not in verdict:
                    verdict[key] = foreign(gx, gy)
                if verdict[key]:
                    cp[x, y] = (0, 0, 0, 0)
        crop = crop.crop(crop.getbbox() or (0, 0, crop.size[0], crop.size[1]))
        name = names[index - 1] if use_names else f"item_{index:02d}"
        crop.save(out / f"{name}.png")
        print(f"  {index:>2}. {name:<22} {crop.size[0]}x{crop.size[1]} px  (aspect {crop.size[0] / crop.size[1]:.2f}:1)")
    cleaned.unlink()


if __name__ == "__main__":
    main()

"""Asset checklist for the top-down vector art.

Reads every level_<n>.json, lists each distinct imageName with its footprint and the canvas size the artist
should use, and checks TidyDesk/Resources/Assets.xcassets for a matching <name>.imageset:

  OK       imageset present, has an image file, vector data preserved (for PDF/SVG)
  MISSING  not in the catalog yet -> the game shows the SF Symbol fallback (fine for development)
  WARN     present but something is off (no file, PDF/SVG without "preserves-vector-representation", ...)

Also lists image sets in the catalog that no level uses (typos are the usual cause).

Usage:
  python tools/check_assets.py                      # report
  python tools/check_assets.py --strict             # exit 1 if anything is MISSING or WARN (use before release)
  python tools/check_assets.py --import <folder>    # copy <name>.svg/.pdf/.png from a folder into the catalog
                                                    # as correctly configured image sets, then report

On import, SVGs from AI/icon generators (square 1024x1024 canvas, opaque background) are cleaned up:
the full-canvas background shape is removed and the viewBox is cropped to the drawing, so the art fills
its tile. The script then warns if the drawing's aspect ratio doesn't match the item's footprint.
"""
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEVEL_DIR = ROOT / "TidyDesk" / "Resources" / "Levels"
CATALOG = ROOT / "TidyDesk" / "Resources" / "Assets.xcassets"
POINTS_PER_CELL = 128  # suggested artboard size per grid cell (see ASSETS.md)
SYSTEM_SETS = {"AppIcon", "AccentColor"}


def level_assets():
    assets = {}
    for path in sorted(LEVEL_DIR.glob("level_*.json"), key=lambda p: int(re.sub(r"\D", "", p.stem) or 0)):
        data = json.loads(path.read_text(encoding="utf-8"))
        for it in data["items"]:
            entry = assets.setdefault(it["imageName"], {
                "size": (it["gridWidth"], it["gridHeight"]),
                "names": set(), "levels": set(), "symbol": it.get("symbol"),
            })
            entry["names"].add(it["name"])
            entry["levels"].add(data["levelId"])
    return assets


def catalog_sets():
    return {p.name[:-len(".imageset")]: p for p in CATALOG.rglob("*.imageset")}


def inspect(imageset: Path):
    contents = imageset / "Contents.json"
    if not contents.exists():
        return "WARN", "no Contents.json"
    data = json.loads(contents.read_text(encoding="utf-8"))
    files = [img.get("filename") for img in data.get("images", []) if img.get("filename")]
    if not files:
        return "WARN", "image set has no image file"
    missing = [f for f in files if not (imageset / f).exists()]
    if missing:
        return "WARN", f"listed file(s) not found: {', '.join(missing)}"
    vector = [f for f in files if f.lower().endswith((".pdf", ".svg"))]
    preserves = data.get("properties", {}).get("preserves-vector-representation", False)
    if vector and not preserves:
        return "WARN", "vector file without 'Preserve Vector Data' (will blur when lifted 1.08x)"
    kind = "vector" if vector else "raster"
    return "OK", f"{kind}: {', '.join(files)}"


NUM = r"-?\d*\.?\d+(?:[eE][-+]?\d+)?"


def svg_viewbox(text):
    m = re.search(r'<svg[^>]*\bviewBox="([^"]+)"', text)
    if not m:
        return None
    vals = [float(v) for v in re.split(r"[\s,]+", m.group(1).strip())]
    return vals if len(vals) == 4 else None


def clean_svg(text):
    """Remove a full-canvas background and crop the viewBox to the drawing. Returns (text, notes)."""
    notes = []
    box = svg_viewbox(text)
    if not box:
        return text, ["no viewBox, left as is"]
    x, y, w, h = box

    # 1. A first shape covering the whole canvas is a background, not part of the device.
    first = re.search(r"<(path|rect)\b[^>]*/>", text)
    if first:
        tag, full = first.group(0), False
        if first.group(1) == "path":
            d = re.search(r'\bd="([^"]*)"', tag)
            nums = [float(n) for n in re.findall(NUM, d.group(1))] if d else []
            full = (0 < len(nums) <= 12 and min(nums[0::2]) <= x and max(nums[0::2]) >= x + w
                    and min(nums[1::2]) <= y and max(nums[1::2]) >= y + h)
        else:
            rw = re.search(r'\bwidth="([\d.]+)"', tag)
            rh = re.search(r'\bheight="([\d.]+)"', tag)
            full = bool(rw and rh and float(rw.group(1)) >= w and float(rh.group(1)) >= h)
        if full:
            text = text.replace(tag, "", 1)
            notes.append("removed opaque background")

    # 2. Crop to the drawing, only when every shape is a path with absolute M/L/C/Q/Z and nothing is transformed.
    if "transform=" in text or re.search(r"<(rect|circle|ellipse|polygon|polyline|line|image|use|text)\b", text):
        notes.append("not cropped (transforms or non-path shapes): crop the artboard in the editor")
        return text, notes
    paths = re.findall(r'<path\b[^>]*\bd="([^"]*)"', text)
    if not paths or any(re.search(r"[A-DF-Za-df-z]", re.sub(r"[MLCQZ]", "", p)) for p in paths):
        notes.append("not cropped (relative/arc path commands): crop the artboard in the editor")
        return text, notes
    xs, ys = [], []
    for p in paths:
        nums = [float(n) for n in re.findall(NUM, p)]
        xs += nums[0::2]
        ys += nums[1::2]
    pad = 0.005 * max(w, h)
    x0, y0, x1, y1 = min(xs) - pad, min(ys) - pad, max(xs) + pad, max(ys) + pad
    nw, nh = x1 - x0, y1 - y0
    if nw < 0.97 * w or nh < 0.97 * h:
        head = re.search(r"<svg\b[^>]*>", text).group(0)
        new_head = re.sub(r'\s(width|height|viewBox)="[^"]*"', "", head)
        new_head = new_head[:-1].rstrip("/").rstrip() + \
            f' width="{nw:.0f}" height="{nh:.0f}" viewBox="{x0:.1f} {y0:.1f} {nw:.1f} {nh:.1f}">'
        text = text.replace(head, new_head, 1)
        notes.append(f"cropped canvas {w:.0f}x{h:.0f} -> {nw:.0f}x{nh:.0f}")
    return text, notes


def aspect_note(text, size):
    """Warning text if the SVG's aspect ratio is far from the footprint's, else None."""
    box = svg_viewbox(text)
    if not box:
        return None
    art, cells = box[2] / box[3], size[0] / size[1]
    ratio = art / cells
    if 0.85 <= ratio <= 1.18:
        return None
    return (f"aspect {art:.2f}:1 vs footprint {size[0]}x{size[1]} ({cells:.2f}:1): art fills only "
            f"~{min(ratio, 1 / ratio):.0%} of the tile; redraw at {size[0] * POINTS_PER_CELL}x{size[1] * POINTS_PER_CELL}")


def aspect_issue(imageset: Path, size):
    for svg in imageset.glob("*.svg"):
        return aspect_note(svg.read_text(encoding="utf-8"), size)
    return None


def import_folder(folder: Path, assets):
    """<name>.svg / .pdf / .png -> Assets.xcassets/<name>.imageset (single scale, vector data preserved)."""
    if not folder.is_dir():
        sys.exit(f"--import: '{folder}' is not a folder")
    preference = {".svg": 0, ".pdf": 1, ".png": 2}
    chosen = {}
    for f in folder.iterdir():
        ext = f.suffix.lower()
        stem = f.stem
        while Path(stem).suffix.lower() in preference:  # "mouse.svg.svg" (Windows hides the real extension)
            stem = Path(stem).stem
        if ext in preference and (stem not in chosen or preference[ext] < preference[chosen[stem].suffix.lower()]):
            chosen[stem] = f
    for name, src in sorted(chosen.items()):
        if name not in assets:
            print(f"skip  {src.name}: no level uses an asset called '{name}' (check the spelling in ASSETS.md)")
            continue
        target = CATALOG / f"{name}.imageset"
        if target.exists():
            shutil.rmtree(target)
        target.mkdir(parents=True)
        out = name + src.suffix.lower()
        notes = []
        if src.suffix.lower() == ".svg":
            text, notes = clean_svg(src.read_text(encoding="utf-8"))
            (target / out).write_text(text, encoding="utf-8", newline="\n")
            aspect = aspect_note(text, assets[name]["size"])
            if aspect:
                notes.append("WARNING " + aspect)
        else:
            shutil.copy2(src, target / out)
        contents = {"images": [{"filename": out, "idiom": "universal"}],
                    "info": {"author": "xcode", "version": 1}}
        if src.suffix.lower() in (".svg", ".pdf"):
            contents["properties"] = {"preserves-vector-representation": True}
        (target / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8", newline="\n")
        print(f"added {name}.imageset  <- {src.name}" + "".join(f"\n      {n}" for n in notes))
    print()


def main():
    strict = "--strict" in sys.argv
    assets = level_assets()
    if "--import" in sys.argv:
        i = sys.argv.index("--import")
        if i + 1 >= len(sys.argv):
            sys.exit("--import needs a folder")
        import_folder(Path(sys.argv[i + 1]), assets)
    sets = catalog_sets()
    problems = 0

    print(f"{'asset name':<22} {'cells':<6} {'artboard (pt)':<14} {'status':<8} detail")
    print("-" * 96)
    for name in sorted(assets):
        info = assets[name]
        w, h = info["size"]
        board = f"{w * POINTS_PER_CELL}x{h * POINTS_PER_CELL}"
        if name in sets:
            status, detail = inspect(sets[name])
            issue = aspect_issue(sets[name], (w, h)) if status == "OK" else None
            if issue:
                status, detail = "WARN", issue
        else:
            status, detail = "MISSING", f"fallback SF Symbol: {info['symbol'] or '(category default)'}"
        if status != "OK":
            problems += 1
        used = ", ".join(sorted(info["names"]))
        print(f"{name:<22} {w}x{h:<4} {board:<14} {status:<8} {detail}   [{used}]")

    unused = sorted(set(sets) - set(assets) - SYSTEM_SETS)
    if unused:
        print("\nImage sets no level uses (typo?):", ", ".join(unused))

    have = sum(1 for n in assets if n in sets)
    print(f"\n{have}/{len(assets)} device assets in the catalog.")
    if strict and (problems or unused):
        sys.exit(1)


if __name__ == "__main__":
    main()

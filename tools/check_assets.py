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


def import_folder(folder: Path, assets):
    """<name>.svg / .pdf / .png -> Assets.xcassets/<name>.imageset (single scale, vector data preserved)."""
    if not folder.is_dir():
        sys.exit(f"--import: '{folder}' is not a folder")
    preference = {".svg": 0, ".pdf": 1, ".png": 2}
    chosen = {}
    for f in folder.iterdir():
        ext = f.suffix.lower()
        if ext in preference and (f.stem not in chosen or preference[ext] < preference[chosen[f.stem].suffix.lower()]):
            chosen[f.stem] = f
    for name, src in sorted(chosen.items()):
        if name not in assets:
            print(f"skip  {src.name}: no level uses an asset called '{name}' (check the spelling in ASSETS.md)")
            continue
        target = CATALOG / f"{name}.imageset"
        if target.exists():
            shutil.rmtree(target)
        target.mkdir(parents=True)
        shutil.copy2(src, target / src.name)
        contents = {"images": [{"filename": src.name, "idiom": "universal"}],
                    "info": {"author": "xcode", "version": 1}}
        if src.suffix.lower() in (".svg", ".pdf"):
            contents["properties"] = {"preserves-vector-representation": True}
        (target / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8", newline="\n")
        print(f"added {name}.imageset  <- {src.name}")
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

"""Prepare the OBJ files that still have to be imported into Roblox Studio.

Every OBJ in assets/models/parkpark whose name has no mesh ID yet in MeshAssets.json is copied to
assets/models/parkpark/import_queue/ with a number in front (01_ParkParkX.obj, 02_...), in the order they should be
imported, together with the shared material file and palette image. Select all the numbered files in the 3D
Importer at once; Studio names each imported model after its file, so the numbers show up in the model names
(the ID recording step strips them).

    python tools/queue_import.py          # copy what is pending
    python tools/queue_import.py --list   # only list it
    python tools/queue_import.py --all    # copy every OBJ (re-import everything)
"""
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "assets" / "models" / "parkpark"
QUEUE = SOURCES / "import_queue"
GENERATOR = ROOT / "tools" / "generate_parkpark_meshes.py"
SHARED = ("ParkParkFairground.mtl", "ParkParkPalette.png", "ParkParkPaletteNeglected.png")


def generator_order() -> dict[str, int]:
    text = GENERATOR.read_text(encoding="utf-8")
    order: dict[str, int] = {}
    for match in re.finditer(r'Mesh\("(ParkPark\w+)"\)', text):
        order.setdefault(match.group(1), match.start())
    return order


def main() -> None:
    assets = json.loads((SOURCES / "MeshAssets.json").read_text(encoding="utf-8"))
    recorded = set(assets.get("meshes", {}))
    names = sorted(path.stem for path in SOURCES.glob("*.obj"))
    pending = names if "--all" in sys.argv else [name for name in names if name not in recorded]
    order = generator_order()
    pending.sort(key=lambda name: (order.get(name, 10**9), name))

    if not pending:
        print("nothing pending: every OBJ already has a mesh ID")
        return
    width = max(2, len(str(len(pending))))
    print(f"{len(pending)} OBJ file(s) to import, in this order:")
    for index, name in enumerate(pending, 1):
        print(f"  {index:0{width}d}_{name}.obj")
    if "--list" in sys.argv:
        return

    if QUEUE.exists():
        shutil.rmtree(QUEUE)
    QUEUE.mkdir(parents=True)
    for index, name in enumerate(pending, 1):
        shutil.copyfile(SOURCES / f"{name}.obj", QUEUE / f"{index:0{width}d}_{name}.obj")
    for shared in SHARED:
        if (SOURCES / shared).exists():
            shutil.copyfile(SOURCES / shared, QUEUE / shared)
    (QUEUE / "READ_ME.txt").write_text(
        "Import every numbered .obj in this folder with the Studio 3D Importer (select them all at once).\n"
        "Keep the .mtl and .png files next to them. Then tell Claude 'imported'.\n",
        encoding="utf-8",
    )
    print(f"copied to {QUEUE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

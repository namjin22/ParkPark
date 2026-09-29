"""Write ParkPark's Rojo model templates (.rbxmx) from uploaded mesh IDs and OBJ bounds.

Studio's 3D Importer uploads each OBJ as a mesh asset. Record the IDs in
assets/models/parkpark/MeshAssets.json and run this script from the repository root:

    python tools/build_parkpark_templates.py

Part placement follows assets/models/parkpark/README.md. Uploaded meshes render centered
on their bounding box, so each part sits at its OBJ bounding-box center. The script uses
only Python's standard library.
"""

from __future__ import annotations

import json
import math
from itertools import count
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "assets" / "models" / "parkpark"
OUTPUT = ROOT / "assets" / "models" / "roblox"
ASSETS = json.loads((SOURCES / "MeshAssets.json").read_text(encoding="utf-8"))

# Untextured meshes fall back to one palette color per part.
CREAM, CORAL, MINT, GOLD = (245, 217, 171), (232, 92, 82), (84, 166, 135), (235, 171, 69)
FADED_CORAL = (135, 79, 74)
WHITE = (255, 255, 255)
# The carousel reads too small beside guests at 1:1, so its meshes render at this scale.
# Keep in sync with GameConfig.CarouselScale, which places riders on the scaled horses.
S = 1.6
# Keep in sync with GameConfig.TeacupsScale, which places guests inside the cups.
TEACUPS_SCALE = 1.0

_referents = count(1)

Vector = tuple[float, float, float]
Matrix = list[list[float]]


def rotation(yaw_degrees: float = 0.0, roll_degrees: float = 0.0) -> Matrix:
    """Return Ry(yaw) * Rz(roll)."""
    cy, sy = math.cos(math.radians(yaw_degrees)), math.sin(math.radians(yaw_degrees))
    cz, sz = math.cos(math.radians(roll_degrees)), math.sin(math.radians(roll_degrees))
    ry = [[cy, 0.0, sy], [0.0, 1.0, 0.0], [-sy, 0.0, cy]]
    rz = [[cz, -sz, 0.0], [sz, cz, 0.0], [0.0, 0.0, 1.0]]
    return [[sum(ry[i][k] * rz[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def cframe_body(position: Vector, matrix: Matrix) -> str:
    values = {"X": position[0], "Y": position[1], "Z": position[2]}
    for i in range(3):
        for j in range(3):
            values[f"R{i}{j}"] = matrix[i][j]
    return "".join(f"<{key}>{round(value, 6) + 0.0}</{key}>" for key, value in values.items())


def vector3(name: str, value: Vector) -> str:
    return f'<Vector3 name="{name}"><X>{value[0]}</X><Y>{value[1]}</Y><Z>{value[2]}</Z></Vector3>'


def color3(rgb: tuple[int, int, int]) -> str:
    red, green, blue = rgb
    return f'<Color3uint8 name="Color3uint8">{(255 << 24) | (red << 16) | (green << 8) | blue}</Color3uint8>'


def obj_bounds(obj: str) -> tuple[Vector, Vector]:
    points = [
        [float(value) for value in line.split()[1:4]]
        for line in (SOURCES / f"{obj}.obj").read_text(encoding="utf-8").splitlines()
        if line.startswith("v ")
    ]
    low = [min(point[axis] for point in points) for axis in range(3)]
    high = [max(point[axis] for point in points) for axis in range(3)]
    center = tuple(round((low[axis] + high[axis]) / 2, 4) for axis in range(3))
    size = tuple(round(high[axis] - low[axis], 4) for axis in range(3))
    return center, size


def mesh_part(
    name: str,
    obj: str,
    origin: Vector,
    yaw: float,
    can_collide: bool,
    fallback: tuple[int, int, int],
    scale: float = 1.0,
) -> str:
    center, size = obj_bounds(obj)
    size = tuple(round(axis * scale, 4) for axis in size)
    cosine, sine = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    # scale * (origin * Ry(yaw) * center), about the template root
    position = tuple(
        round(axis * scale, 4)
        for axis in (
            origin[0] + cosine * center[0] + sine * center[2],
            origin[1] + center[1],
            origin[2] - sine * center[0] + cosine * center[2],
        )
    )
    textured = obj in ASSETS.get("textured", []) and ASSETS.get("palette")
    texture = f"<url>{ASSETS['palette']}</url>" if textured else "<null></null>"
    collide = str(can_collide).lower()
    return f"""<Item class="MeshPart" referent="RBX{next(_referents)}"><Properties>
<string name="Name">{name}</string>
<Content name="MeshId"><url>{ASSETS["meshes"][obj]}</url></Content>
<Content name="TextureID">{texture}</Content>
{vector3("InitialSize", size)}
{vector3("size", size)}
<CoordinateFrame name="CFrame">{cframe_body(position, rotation(yaw))}</CoordinateFrame>
<bool name="Anchored">true</bool>
<bool name="CanCollide">{collide}</bool>
<bool name="CanTouch">false</bool>
<bool name="CanQuery">{collide}</bool>
<token name="CollisionFidelity">2</token>
<token name="RenderFidelity">0</token>
<token name="Material">272</token>
{color3(WHITE if textured else fallback)}
</Properties></Item>"""


def cylinder_collider(name: str, center: Vector, height: float, diameter: float, scale: float = 1.0) -> str:
    # Cylinder parts run along X, so roll them 90 degrees to stand upright.
    center = tuple(round(axis * scale, 4) for axis in center)
    height, diameter = round(height * scale, 4), round(diameter * scale, 4)
    return f"""<Item class="Part" referent="RBX{next(_referents)}"><Properties>
<string name="Name">{name}</string>
<token name="shape">2</token>
{vector3("size", (height, diameter, diameter))}
<CoordinateFrame name="CFrame">{cframe_body(center, rotation(0, 90))}</CoordinateFrame>
<bool name="Anchored">true</bool>
<bool name="CanCollide">true</bool>
<bool name="CanTouch">false</bool>
<bool name="CanQuery">false</bool>
<bool name="CastShadow">false</bool>
<float name="Transparency">1</float>
</Properties></Item>"""


def model(name: str, children: list[str]) -> str:
    pivot = cframe_body((0.0, 0.0, 0.0), rotation())
    return f"""<Item class="Model" referent="RBX{next(_referents)}"><Properties>
<string name="Name">{escape(name)}</string>
<OptionalCoordinateFrame name="WorldPivotData"><CFrame>{pivot}</CFrame></OptionalCoordinateFrame>
</Properties>
{"".join(children)}
</Item>"""


def write(name: str, item: str) -> None:
    xml = f'<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">\n{item}\n</roblox>\n'
    (OUTPUT / f"{name}.rbxmx").write_text(xml, encoding="utf-8", newline="\n")
    print(f"wrote {OUTPUT.relative_to(ROOT) / (name + '.rbxmx')}")


def main() -> None:
    write(
        "RuinedEntrance",
        model(
            "RuinedEntrance",
            [
                mesh_part("EntranceArch", "ParkParkStorybookEntrance", (0, 0, 0), 0, False, CREAM),
                mesh_part("SignPanel", "ParkParkEntranceSign", (0, 14.2, -1.35), 0, False, CORAL),
                cylinder_collider("LeftPillarCollider", (-7.05, 4.1, 0), 8.2, 2.6),
                cylinder_collider("RightPillarCollider", (7.05, 4.1, 0), 8.2, 2.6),
            ],
        ),
    )
    write(
        "BrokenCarousel",
        model(
            "BrokenCarousel",
            [
                mesh_part("RidePlatform", "ParkParkCarouselPlatform", (0, 0, 0), 0, False, MINT, S),
                cylinder_collider("PlatformCollider", (0, 0.42, 0), 0.7, 24, S),
                # The console keeps its authored size and sits just outside the scaled platform.
                mesh_part("RepairConsole", "ParkParkRepairConsole", (12 * S + 1.2, 0, 0), 180, True, CREAM),
                model(
                    "CarouselRotor",
                    [
                        mesh_part("CenterPost", "ParkParkCarouselRotor", (0, 0, 0), 0, False, GOLD, S),
                        mesh_part("CanopyNeglected", "ParkParkCanopyNeglected", (0, 0, 0), 0, False, FADED_CORAL, S),
                        mesh_part("CanopyRestored", "ParkParkCanopyRestored", (0, 0, 0), 0, False, CORAL, S),
                    ],
                ),
            ],
        ),
    )


    # The debris pile sits at its own pivot (ParkBuilder places it beside the path) and
    # carries the cleanup prompt, so its single mesh is the CleanupTarget.
    if "ParkParkEntranceDebris" in ASSETS["meshes"]:
        write(
            "EntranceDebris",
            model(
                "EntranceDebris",
                [mesh_part("CleanupTarget", "ParkParkEntranceDebris", (0, 0, 0), 0, False, (97, 56, 36))],
            ),
        )
    else:
        print("skipped EntranceDebris: import ParkParkEntranceDebris.obj and record its mesh ID first")

    teacups_meshes = ("ParkParkTeacupsPlatform", "ParkParkTeacupsRotor")
    if all(name in ASSETS["meshes"] for name in teacups_meshes):
        write(
            "TeacupsRide",
            model(
                "TeacupsRide",
                [
                    mesh_part("RidePlatform", "ParkParkTeacupsPlatform", (0, 0, 0), 0, False, MINT, TEACUPS_SCALE),
                    cylinder_collider("PlatformCollider", (0, 0.42, 0), 0.7, 18.4, TEACUPS_SCALE),
                    mesh_part("TeacupsConsole", "ParkParkRepairConsole", (0, 0, 10.5), 180, True, CREAM),
                    model(
                        "TeacupsRotor",
                        [
                            mesh_part(
                                "RotorCore",
                                "ParkParkTeacupsRotor",
                                (0, 0, 0),
                                0,
                                False,
                                GOLD,
                                TEACUPS_SCALE,
                            ),
                        ],
                    ),
                ],
            ),
        )
    else:
        missing = ", ".join(name for name in teacups_meshes if name not in ASSETS["meshes"])
        print(f"skipped TeacupsRide: import {missing} and record their mesh IDs first")


if __name__ == "__main__":
    main()

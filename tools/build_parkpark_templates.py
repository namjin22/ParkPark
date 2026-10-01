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
import re
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
CONFIG_TEXT = (ROOT / "src" / "shared" / "Config" / "GameConfig.luau").read_text(encoding="utf-8")


def config_number(key: str) -> float:
    """Read a numeric top-level value from GameConfig.luau (the game and the templates share it)."""
    match = re.search(rf"^\s*{key} = (-?[0-9.]+),", CONFIG_TEXT, re.M)
    if match is None:
        raise KeyError(f"GameConfig.luau has no numeric {key}")
    return float(match.group(1))


# Every ride and the entrance are sized around the carousel; the game code reads the same values.
ENTRANCE_SCALE = config_number("EntranceScale")
ENTRANCE_HEIGHT_SCALE = config_number("EntranceHeightScale")
DEBRIS_SCALE = config_number("DebrisScale")
S = config_number("CarouselScale")
TEACUPS_SCALE = config_number("TeacupsScale")
BUMPER_SCALE = config_number("BumperScale")
BUMPER_CAR_SCALE = config_number("BumperCarScale")
BUMPER_CAR_COUNT = int(config_number("BumperSeatCount"))
CONSOLE_SCALE = config_number("ConsoleScale")
LITTER_SCALE = config_number("LitterScale")
SNACK_SCALE = config_number("SnackScale")
FERRIS_SCALE = config_number("FerrisScale")
FERRIS_RADIUS = config_number("FerrisRadius")
FERRIS_HUB = config_number("FerrisHubHeight")
FERRIS_CABINS = int(config_number("FerrisCabinCount"))
SWING_SCALE = config_number("SwingScale")
SWING_TOWER = config_number("SwingTowerHeight")
SWING_ANCHOR_RADIUS = config_number("SwingAnchorRadius")
SWING_ANCHOR_Y = config_number("SwingAnchorY")
SWING_SEATS = int(config_number("SwingSeatCount"))
SWING_PLATFORM = config_number("SwingPlatformRadius")
PIRATE_SCALE = config_number("PirateScale")
PIRATE_HUB = config_number("PirateHubHeight")
PIRATE_PLATFORM = config_number("PiratePlatformRadius")
HAUNTED_SCALE = config_number("HauntedScale")
COASTER_SCALE = config_number("CoasterScale")
COASTER_CARS = int(config_number("CoasterCarCount"))
FLUME_SCALE = config_number("FlumeScale")
FLUME_CARS = int(config_number("FlumeCarCount"))
DROP_SCALE = config_number("DropScale")
DROP_REST_Y = config_number("DropRestY")
GIFT_SCALE = config_number("GiftScale")
TRAIN_SCALE = config_number("TrainScale")
TRAIN_CARS = int(config_number("TrainCarCount"))
FLUME_SCALE = config_number("FlumeScale")
FLUME_CARS = int(config_number("FlumeCarCount"))
TREE_SCALE = config_number("TreeScale")
BUSH_SCALE = config_number("BushScale")
LAMP_SCALE = config_number("LampScale")
BENCH_SCALE = config_number("BenchScale")
FOUNTAIN_SCALE = config_number("FountainScale")
BALLOON_SCALE = config_number("BalloonScale")
PALM_SCALE = config_number("PalmScale")
UMBRELLA_SCALE = config_number("UmbrellaScale")
POND_SCALE = config_number("PondScale")
SANDCASTLE_SCALE = config_number("SandcastleScale")
TEACUP_COUNT = int(config_number("TeacupCupCount"))
TEACUP_RING_RADIUS = config_number("TeacupRingRadius")
TEACUP_BASE_HEIGHT = config_number("TeacupCupBaseHeight")

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
    scale: float | tuple[float, float, float] = 1.0,
) -> str:
    center, natural_size = obj_bounds(obj)
    sx, sy, sz = (scale, scale, scale) if isinstance(scale, (int, float)) else scale
    # Roblox scales the mesh by Size / InitialSize, so InitialSize must stay the mesh's natural size.
    size = tuple(round(natural_size[axis] * (sx, sy, sz)[axis], 4) for axis in range(3))
    cosine, sine = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    # scale * (origin * Ry(yaw) * center), about the template root
    position = (
        round(sx * (origin[0] + cosine * center[0] + sine * center[2]), 4),
        round(sy * (origin[1] + center[1]), 4),
        round(sz * (origin[2] - sine * center[0] + cosine * center[2]), 4),
    )
    textured = obj in ASSETS.get("textured", []) and ASSETS.get("palette")
    texture = f"<url>{ASSETS['palette']}</url>" if textured else "<null></null>"
    collide = str(can_collide).lower()
    return f"""<Item class="MeshPart" referent="RBX{next(_referents)}"><Properties>
<string name="Name">{name}</string>
<Content name="MeshId"><url>{ASSETS["meshes"][obj]}</url></Content>
<Content name="TextureID">{texture}</Content>
{vector3("InitialSize", natural_size)}
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


def box_collider(name: str, center: Vector, size: Vector, yaw: float = 0.0, scale: float = 1.0) -> str:
    center = tuple(round(axis * scale, 4) for axis in center)
    size = tuple(round(axis * scale, 4) for axis in size)
    return f"""<Item class="Part" referent="RBX{next(_referents)}"><Properties>
<string name="Name">{name}</string>
{vector3("size", size)}
<CoordinateFrame name="CFrame">{cframe_body(center, rotation(yaw))}</CoordinateFrame>
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


def console(name: str, x: float, z: float, yaw: float = 180) -> str:
    """A ride console; (x, z) is the world-scale position, so the origin is divided by the mesh scale."""
    return mesh_part(name, "ParkParkRepairConsole", (x / CONSOLE_SCALE, 0, z / CONSOLE_SCALE), yaw, True, CREAM, CONSOLE_SCALE)


def missing_meshes(names: tuple[str, ...]) -> list[str]:
    return [name for name in names if name not in ASSETS["meshes"]]


def main() -> None:
    entrance_scale = (ENTRANCE_SCALE, ENTRANCE_HEIGHT_SCALE, ENTRANCE_SCALE)
    write(
        "RuinedEntrance",
        model(
            "RuinedEntrance",
            [
                mesh_part("EntranceArch", "ParkParkStorybookEntrance", (0, 0, 0), 0, False, CREAM, entrance_scale),
                mesh_part("SignPanel", "ParkParkEntranceSign", (0, 14.2, -1.35), 0, False, CORAL, entrance_scale),
                cylinder_collider(
                    "LeftPillarCollider",
                    (-7.05 * ENTRANCE_SCALE, 4.1 * ENTRANCE_HEIGHT_SCALE, 0),
                    8.2 * ENTRANCE_HEIGHT_SCALE,
                    2.9 * ENTRANCE_SCALE,
                ),
                cylinder_collider(
                    "RightPillarCollider",
                    (7.05 * ENTRANCE_SCALE, 4.1 * ENTRANCE_HEIGHT_SCALE, 0),
                    8.2 * ENTRANCE_HEIGHT_SCALE,
                    2.9 * ENTRANCE_SCALE,
                ),
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
                # The central column blocks players; the horses and arms move, so they stay non-solid.
                cylinder_collider("ColumnCollider", (0, 4.0, 0), 7.0, 1.4, S),
                console("RepairConsole", 12 * S + 5, 0),
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

    # The debris pile sits at its own pivot (ParkBuilder places it beside the path) and carries the
    # cleanup prompt, so its single mesh is the CleanupTarget. It is solid like any structure.
    if not missing_meshes(("ParkParkEntranceDebris",)):
        write(
            "EntranceDebris",
            model(
                "EntranceDebris",
                [mesh_part("CleanupTarget", "ParkParkEntranceDebris", (0, 0, 0), 0, True, (97, 56, 36), DEBRIS_SCALE)],
            ),
        )
    else:
        print("skipped EntranceDebris: import ParkParkEntranceDebris.obj and record its mesh ID first")

    # Litter is cloned by LitterService; its single mesh is the pickup target.
    if not missing_meshes(("ParkParkLitter",)):
        write(
            "Litter",
            model("Litter", [mesh_part("LitterPiece", "ParkParkLitter", (0, 0, 0), 0, False, (150, 130, 100), LITTER_SCALE)]),
        )
    else:
        print("skipped Litter: import ParkParkLitter.obj and record its mesh ID first")

    build_teacups()
    build_bumper_cars()
    build_snack_stand()
    build_ferris_wheel()
    build_swing_ride()
    build_pirate_ship()
    build_haunted_house()
    build_coaster()
    build_flume()
    build_drop_tower()
    build_gift_shop()
    build_train()
    build_flume()
    build_decor()


def build_teacups() -> None:
    platform_radius = 9.2
    common = [
        mesh_part("RidePlatform", "ParkParkTeacupsPlatform", (0, 0, 0), 0, False, MINT, TEACUPS_SCALE),
        cylinder_collider("PlatformCollider", (0, 0.42, 0), 0.7, 18.4, TEACUPS_SCALE),
        # Beside the platform, away from the side where the guests line up (the line extends toward +X).
        console("TeacupsConsole", -24, 36),
    ]
    separate_cups = ("ParkParkTeacupsHub", "ParkParkTeacup")
    if not missing_meshes(separate_cups):
        # Rotating hub plus six cups that each spin on their own turntable (TeacupService drives them).
        cups = []
        for index in range(TEACUP_COUNT):
            angle = 2 * math.pi * index / TEACUP_COUNT
            origin = (TEACUP_RING_RADIUS * math.cos(angle), TEACUP_BASE_HEIGHT, TEACUP_RING_RADIUS * math.sin(angle))
            cups.append(mesh_part(f"TeacupCup{index + 1}", "ParkParkTeacup", origin, 0, False, CORAL, TEACUPS_SCALE))
        write(
            "TeacupsRide",
            model(
                "TeacupsRide",
                common
                + [
                    cylinder_collider("ColumnCollider", (0, 3.8, 0), 6.4, 1.3, TEACUPS_SCALE),
                    model("TeacupsRotor", [mesh_part("RotorCore", "ParkParkTeacupsHub", (0, 0, 0), 0, False, GOLD, TEACUPS_SCALE)]),
                    model("TeacupCups", cups),
                ],
            ),
        )
        return

    # Until the separate hub and cup are imported, keep the single-mesh rotor (guests sit on the rotor).
    if not missing_meshes(("ParkParkTeacupsPlatform", "ParkParkTeacupsRotor")):
        write(
            "TeacupsRide",
            model(
                "TeacupsRide",
                common
                + [model("TeacupsRotor", [mesh_part("RotorCore", "ParkParkTeacupsRotor", (0, 0, 0), 0, False, GOLD, TEACUPS_SCALE)])],
            ),
        )
        print("wrote TeacupsRide with the legacy rotor: import ParkParkTeacupsHub and ParkParkTeacup for spinning cups")
    else:
        print("skipped TeacupsRide: import the teacup meshes and record their mesh IDs first")


def build_bumper_cars() -> None:
    needed = ("ParkParkBumperPlatform", "ParkParkBumperCar")
    missing = missing_meshes(needed)
    if missing:
        print(f"skipped BumperCarsRide: import {', '.join(missing)} and record their mesh IDs first")
        return

    car_center, _ = obj_bounds("ParkParkBumperCar")
    ring_radius = 5.5 * BUMPER_SCALE
    cars = []
    for index in range(BUMPER_CAR_COUNT):
        angle = 2 * math.pi * index / BUMPER_CAR_COUNT
        # Start on a ring, facing along it (car front is local -Z): yaw = atan2(-vx, -vz).
        velocity = (-math.sin(angle), math.cos(angle))
        yaw = math.degrees(math.atan2(-velocity[0], -velocity[1]))
        wanted = (ring_radius * math.cos(angle), 0.0, ring_radius * math.sin(angle))
        # mesh_part places the part at scale * (origin + Ry(yaw) * center), so solve for the
        # origin that puts the car's bounding-box center exactly at `wanted`.
        cosine, sine = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
        offset = (cosine * car_center[0] + sine * car_center[2], 0.0, -sine * car_center[0] + cosine * car_center[2])
        origin = (wanted[0] / BUMPER_CAR_SCALE - offset[0], 0.0, wanted[2] / BUMPER_CAR_SCALE - offset[2])
        cars.append(mesh_part(f"BumperCar{index + 1}", "ParkParkBumperCar", origin, yaw, False, CORAL, BUMPER_CAR_SCALE))

    colliders = [
        cylinder_collider("PlatformCollider", (0, 0.42, 0), 0.7, 20.84, BUMPER_SCALE),
    ]
    # Solid bumper rail with an opening at the front (+Z) where the console and queue are.
    segments = 24
    for k in range(segments):
        angle = 2 * math.pi * k / segments
        if abs(math.degrees(angle) - 90) < 20:
            continue
        yaw = math.degrees(math.atan2(-math.cos(angle), -math.sin(angle)))
        colliders.append(
            box_collider(
                f"RailCollider{k + 1}",
                (9.95 * math.cos(angle), 1.3, 9.95 * math.sin(angle)),
                (2.9, 1.1, 0.8),
                yaw,
                BUMPER_SCALE,
            )
        )
    for k in range(4):
        angle = math.pi / 4 + k * math.pi / 2
        colliders.append(
            cylinder_collider(f"LampCollider{k + 1}", (10.6 * math.cos(angle), 3.3, 10.6 * math.sin(angle)), 6.4, 1.0, BUMPER_SCALE)
        )
    write(
        "BumperCarsRide",
        model(
            "BumperCarsRide",
            [
                mesh_part("RidePlatform", "ParkParkBumperPlatform", (0, 0, 0), 0, False, MINT, BUMPER_SCALE),
                *colliders,
                # The bumper line extends toward -X, so the console stands on the opposite (+X) side.
                console("BumperConsole", 24, 36),
                model("BumperCars", cars),
            ],
        ),
    )


def build_snack_stand() -> None:
    if missing_meshes(("ParkParkSnackStand",)):
        print("skipped SnackStand: import ParkParkSnackStand.obj and record its mesh ID first")
        return

    # The mesh faces -Z; ParkBuilder turns the template so the counter faces the queue (+X in the world).
    colliders = [
        # SnackCounter is where served guests stand in front of, and it blocks the way like the counter does.
        # Imported meshes arrive turned half a turn, so the body is yawed 180 and the result matches the OBJ
        # layout: colliders are written in OBJ coordinates (the counter on the -Z front).
        box_collider("SnackCounter", (0, 0.65, -1.1), (5.7, 1.3, 1.3), 0, SNACK_SCALE),
        box_collider("BackWall", (0, 1.7, 1.5), (5.6, 3.4, 0.3), 0, SNACK_SCALE),
        box_collider("LeftWall", (-2.75, 1.7, 0.2), (0.3, 3.4, 2.8), 0, SNACK_SCALE),
        box_collider("RightWall", (2.75, 1.7, 0.2), (0.3, 3.4, 2.8), 0, SNACK_SCALE),
    ]
    for x in (-2.85, 2.85):
        colliders.append(cylinder_collider(f"PostColliderFront{x:+.0f}", (x, 1.85, -1.7), 3.3, 0.3, SNACK_SCALE))
    write(
        "SnackStand",
        model(
            "SnackStand",
            [
                mesh_part("StandBody", "ParkParkSnackStand", (0, 0, 0), 180, False, CORAL, SNACK_SCALE),
                *colliders,
                # Behind the stand, away from the queue in front of the counter, so its prompts stay clear of the guests.
                console("SnackConsole", -9.5, 7, 0),
            ],
        ),
    )


def build_ferris_wheel() -> None:
    needed = ("ParkParkFerrisBase", "ParkParkFerrisWheel", "ParkParkFerrisCabin")
    missing = missing_meshes(needed)
    if missing:
        print(f"skipped FerrisWheelRide: import {', '.join(missing)} and record their mesh IDs first")
        return

    # The wheel turns in the local XY plane on an axle along Z; ParkBuilder turns the model a quarter.
    # Cabins are placed with their hanger point (the OBJ origin) on the rim, and FerrisService then moves them.
    cabins = []
    for index in range(FERRIS_CABINS):
        angle = 2 * math.pi * index / FERRIS_CABINS
        hanger = (FERRIS_RADIUS * math.cos(angle), FERRIS_HUB + FERRIS_RADIUS * math.sin(angle), 0.0)
        cabins.append(mesh_part(f"FerrisCabin{index + 1}", "ParkParkFerrisCabin", hanger, 0, False, CORAL, FERRIS_SCALE))

    colliders = [box_collider("BasePad", (0, 0.15, 0), (11.0, 0.3, 8.4), 0, FERRIS_SCALE)]
    # The tower legs lean, so approximate each with a few upright posts along its length.
    for z in (-1.4, 1.4):
        for side in (-1, 1):
            for t in (0.0, 0.35, 0.7):
                x = side * 4.4 * (1 - t)
                y = 0.3 + (FERRIS_HUB - 0.3) * t
                colliders.append(
                    cylinder_collider(f"LegCollider_{z:+.1f}_{side:+d}_{int(t * 100)}", (x, y + 1.6, z), 3.2, 1.3, FERRIS_SCALE)
                )
    write(
        "FerrisWheelRide",
        model(
            "FerrisWheelRide",
            [
                mesh_part("FerrisBase", "ParkParkFerrisBase", (0, 0, 0), 0, False, CREAM, FERRIS_SCALE),
                mesh_part("Wheel", "ParkParkFerrisWheel", (0, FERRIS_HUB, 0), 0, False, GOLD, FERRIS_SCALE),
                model("FerrisCabins", cabins),
                *colliders,
                # Behind the wheel (local +Z is east in the world), away from the queue on the west side.
                console("FerrisConsole", 8, 10, 0),
            ],
        ),
    )


def build_swing_ride() -> None:
    needed = ("ParkParkSwingBase", "ParkParkSwingCrown", "ParkParkSwingSeat")
    missing = missing_meshes(needed)
    if missing:
        print(f"skipped SwingRide: import {', '.join(missing)} and record their mesh IDs first")
        return

    # The seats hang at rest straight below their anchors on the crown's rim; SwingService then moves the
    # crown and the seats. Each seat's OBJ origin is its anchor, so the anchor is the part's origin here.
    seats = []
    for index in range(SWING_SEATS):
        angle = 2 * math.pi * index / SWING_SEATS
        anchor = (
            SWING_ANCHOR_RADIUS * math.cos(angle),
            SWING_TOWER + SWING_ANCHOR_Y,
            SWING_ANCHOR_RADIUS * math.sin(angle),
        )
        seats.append(mesh_part(f"SwingSeat{index + 1}", "ParkParkSwingSeat", anchor, 0, False, CORAL, SWING_SCALE))
    write(
        "SwingRide",
        model(
            "SwingRide",
            [
                mesh_part("Tower", "ParkParkSwingBase", (0, 0, 0), 0, False, CREAM, SWING_SCALE),
                mesh_part("Crown", "ParkParkSwingCrown", (0, SWING_TOWER, 0), 0, False, CORAL, SWING_SCALE),
                model("SwingSeats", seats),
                cylinder_collider("PlatformCollider", (0, 0.3, 0), 0.6, SWING_PLATFORM * 2, SWING_SCALE),
                cylinder_collider("ColumnCollider", (0, SWING_TOWER / 2, 0), SWING_TOWER, 2.0, SWING_SCALE),
                # South of the platform (local +Z), away from the queue that forms along the path to the east.
                console("SwingConsole", 0, SWING_PLATFORM * SWING_SCALE + 8),
            ],
        ),
    )


def build_pirate_ship() -> None:
    needed = ("ParkParkPirateBase", "ParkParkPirateShip")
    missing = missing_meshes(needed)
    if missing:
        print(f"skipped PirateRide: import {', '.join(missing)} and record their mesh IDs first")
        return

    # The ship mesh's origin is the axle, so the part's origin here is the axle height; PirateService swings it.
    colliders = [cylinder_collider("PlatformCollider", (0, 0.3, 0), 0.6, PIRATE_PLATFORM * 2, PIRATE_SCALE)]
    # The tower legs lean along Z toward the apex, so approximate each with a few upright posts.
    for x in (-4.4, 4.4):
        for side in (-1, 1):
            for t in (0.0, 0.4, 0.75):
                z = side * 4.6 * (1 - t)
                y = 0.6 + (PIRATE_HUB - 0.6) * t
                colliders.append(
                    cylinder_collider(f"LegCollider_{x:+.1f}_{side:+d}_{int(t * 100)}", (x, y + 1.6, z), 3.2, 1.3, PIRATE_SCALE)
                )
    write(
        "PirateRide",
        model(
            "PirateRide",
            [
                mesh_part("PirateBase", "ParkParkPirateBase", (0, 0, 0), 0, False, CREAM, PIRATE_SCALE),
                mesh_part("Ship", "ParkParkPirateShip", (0, PIRATE_HUB, 0), 0, False, CORAL, PIRATE_SCALE),
                *colliders,
                # South of the platform (local +Z), away from the queue that forms along the path to the west.
                console("PirateConsole", 0, PIRATE_PLATFORM * PIRATE_SCALE + 8),
            ],
        ),
    )


def build_flume() -> None:
    needed = ("ParkParkFlumeTrack", "ParkParkFlumeBoat")
    missing = missing_meshes(needed)
    if missing:
        print(f"skipped FlumeRide: import {', '.join(missing)} and record their mesh IDs first")
        return

    # TrackService places the boats along the generated path when the game starts; the template only needs them
    # to exist with the right names and size.
    boats = [
        mesh_part(f"FlumeCar{index + 1}", "ParkParkFlumeBoat", (0, 1.0, index * 5.0), 0, False, CORAL, FLUME_SCALE)
        for index in range(FLUME_CARS)
    ]
    write(
        "FlumeRide",
        model(
            "FlumeRide",
            [
                mesh_part("FlumeTrack", "ParkParkFlumeTrack", (0, 0, 0), 0, False, MINT, FLUME_SCALE),
                # The station dock is solid, so guests and players cannot walk through it.
                box_collider("Station", (0, 0.35, -8.0), (20.0, 0.7, 4.4), 0, FLUME_SCALE),
                model("FlumeCars", boats),
                # The ride is turned half a turn in the world, so this lands beside the station near its line.
                console("FlumeConsole", 18, -33, 0),
            ],
        ),
    )


def build_drop_tower() -> None:
    needed = ("ParkParkDropTower", "ParkParkDropGondola")
    missing = missing_meshes(needed)
    if missing:
        print(f"skipped DropRide: import {', '.join(missing)} and record their mesh IDs first")
        return

    # DropService raises the gondola from this rest height (the top of the base) at run time.
    write(
        "DropRide",
        model(
            "DropRide",
            [
                mesh_part("DropTower", "ParkParkDropTower", (0, 0, 0), 0, False, CREAM, DROP_SCALE),
                mesh_part("DropGondola", "ParkParkDropGondola", (0, DROP_REST_Y, 0), 0, False, CORAL, DROP_SCALE),
                cylinder_collider("BaseCollider", (0, 0.3, 0), 0.6, 12.0, DROP_SCALE),
                # The tower is slim and solid; its four posts make a 2.6-stud square in world scale.
                box_collider("TowerCollider", (0, 10.0, 0), (2.6, 20.0, 2.6), 0, DROP_SCALE),
                # Beside the base, near the line that forms in front of it (+Z).
                console("DropConsole", -24, 22),
            ],
        ),
    )


def build_gift_shop() -> None:
    if missing_meshes(("ParkParkGiftShop",)):
        print("skipped GiftShop: import ParkParkGiftShop.obj and record its mesh ID first")
        return

    # Imported meshes arrive turned half a turn, so the body is yawed 180 and the result matches the OBJ layout:
    # colliders are written in OBJ coordinates (the counter on the -Z front), like the snack stand's.
    colliders = [
        box_collider("GiftCounter", (0, 0.65, -1.1), (5.7, 1.3, 1.3), 0, GIFT_SCALE),
        box_collider("BackWall", (0, 1.7, 1.5), (5.6, 3.4, 0.3), 0, GIFT_SCALE),
        box_collider("LeftWall", (-2.75, 1.7, 0.2), (0.3, 3.4, 2.8), 0, GIFT_SCALE),
        box_collider("RightWall", (2.75, 1.7, 0.2), (0.3, 3.4, 2.8), 0, GIFT_SCALE),
    ]
    for x in (-2.85, 2.85):
        colliders.append(cylinder_collider(f"PostColliderFront{x:+.0f}", (x, 1.85, -1.7), 3.3, 0.3, GIFT_SCALE))
    write(
        "GiftShop",
        model(
            "GiftShop",
            [
                mesh_part("ShopBody", "ParkParkGiftShop", (0, 0, 0), 180, False, CORAL, GIFT_SCALE),
                *colliders,
                # Behind the shop, away from the line in front of the counter (the counter is on local -Z).
                console("GiftConsole", -6, 10, 0),
            ],
        ),
    )


def build_train() -> None:
    needed = ("ParkParkTrainTrack", "ParkParkTrainCar")
    missing = missing_meshes(needed)
    if missing:
        print(f"skipped TrainRide: import {', '.join(missing)} and record their mesh IDs first")
        return

    # TrackService places the wagons along the generated path when the game starts.
    wagons = [
        mesh_part(f"TrainCar{index + 1}", "ParkParkTrainCar", (0, 1.0, index * 4.9), 0, False, CORAL, TRAIN_SCALE)
        for index in range(TRAIN_CARS)
    ]
    write(
        "TrainRide",
        model(
            "TrainRide",
            [
                mesh_part("TrainTrack", "ParkParkTrainTrack", (0, 0, 0), 0, False, CREAM, TRAIN_SCALE),
                # The station platform is solid, so guests and players cannot walk through it.
                box_collider("Station", (0, 0.2, -8.2), (16.0, 0.4, 2.6), 0, TRAIN_SCALE),
                model("TrainCars", wagons),
                # The ride is turned half a turn in the world, so this lands beside the station near its line.
                console("TrainConsole", 18, -33, 0),
            ],
        ),
    )


def marker(name: str, center: Vector, size: Vector, scale: float = 1.0) -> str:
    """An invisible, non-solid part that game code uses as a position (for example a window light)."""
    center = tuple(round(axis * scale, 4) for axis in center)
    size = tuple(round(axis * scale, 4) for axis in size)
    return f"""<Item class="Part" referent="RBX{next(_referents)}"><Properties>
<string name="Name">{name}</string>
{vector3("size", size)}
<CoordinateFrame name="CFrame">{cframe_body(center, rotation())}</CoordinateFrame>
<bool name="Anchored">true</bool>
<bool name="CanCollide">false</bool>
<bool name="CanTouch">false</bool>
<bool name="CanQuery">false</bool>
<bool name="CastShadow">false</bool>
<float name="Transparency">1</float>
</Properties></Item>"""


def build_haunted_house() -> None:
    if missing_meshes(("ParkParkHauntedHouse",)):
        print("skipped HauntedHouse: import ParkParkHauntedHouse.obj and record its mesh ID first")
        return

    # Yaw applied to the imported mesh only. The imported house showed its blank back to the queue (world -Z),
    # like the snack stand, so it is turned 180 degrees; colliders and markers use OBJ coordinates and stay put.
    body_yaw = 180
    windows = [
        marker(f"WindowLight{index + 1}", (x, y, -5.1), (1.5, 1.5, 0.3), HAUNTED_SCALE)
        for index, (x, y) in enumerate(((-3.9, 2.9), (3.9, 2.9), (-3.9, 5.0), (3.9, 5.0)))
    ]
    write(
        "HauntedHouse",
        model(
            "HauntedHouse",
            [
                mesh_part("HouseBody", "ParkParkHauntedHouse", (0, 0, 0), body_yaw, False, CREAM, HAUNTED_SCALE),
                box_collider("BodyCollider", (0, 3.6, 0), (12.0, 7.0, 9.0), 0, HAUNTED_SCALE),
                # In OBJ coordinates: the yawed import matches the OBJ layout (the tower is at +5.4, -1.5).
                cylinder_collider("TowerCollider", (5.4, 6.0, -1.5), 12.0, 3.6, HAUNTED_SCALE),
                *windows,
                # West of the house, away from the line that forms south of it.
                console("HauntedConsole", -9 * HAUNTED_SCALE - 8, -4 * HAUNTED_SCALE),
            ],
        ),
    )


def build_coaster() -> None:
    needed = ("ParkParkCoasterTrack", "ParkParkCoasterCar")
    missing = missing_meshes(needed)
    if missing:
        print(f"skipped CoasterRide: import {', '.join(missing)} and record their mesh IDs first")
        return

    # CoasterService places the cars along the generated path when the game starts, so their template
    # positions do not matter; they only need to exist with the right names and size.
    cars = [
        mesh_part(f"CoasterCar{index + 1}", "ParkParkCoasterCar", (0, 1.0, index * 4.6), 0, False, MINT, COASTER_SCALE)
        for index in range(COASTER_CARS)
    ]
    write(
        "CoasterRide",
        model(
            "CoasterRide",
            [
                mesh_part("CoasterTrack", "ParkParkCoasterTrack", (0, 0, 0), 0, False, CORAL, COASTER_SCALE),
                # The station platform is solid, so guests and players cannot walk through it.
                box_collider("Station", (0, 0.35, -8.0), (20.0, 0.7, 4.4), 0, COASTER_SCALE),
                model("CoasterCars", cars),
                # West of the station, away from the line that forms south of it.
                console("CoasterConsole", -15 * COASTER_SCALE, -10 * COASTER_SCALE),
            ],
        ),
    )


def build_decor() -> None:
    """Scenery templates: one mesh (`Piece`, origin at the ground point) plus an optional solid collider."""
    pieces = (
        ("DecorTree", "ParkParkDecorTree", TREE_SCALE, cylinder_collider("Collider", (0, 1.8, 0), 3.6, 1.3, TREE_SCALE)),
        ("DecorBush", "ParkParkDecorBush", BUSH_SCALE, None),
        ("DecorLamp", "ParkParkDecorLamp", LAMP_SCALE, cylinder_collider("Collider", (0, 3.0, 0), 6.0, 0.6, LAMP_SCALE)),
        ("DecorBench", "ParkParkDecorBench", BENCH_SCALE, box_collider("Collider", (0, 0.9, 0.2), (2.8, 1.8, 1.1), 0, BENCH_SCALE)),
        ("DecorFountain", "ParkParkDecorFountain", FOUNTAIN_SCALE, cylinder_collider("Collider", (0, 0.6, 0), 1.2, 9.0, FOUNTAIN_SCALE)),
        ("DecorBalloons", "ParkParkDecorBalloons", BALLOON_SCALE, None),
        ("DecorPalm", "ParkParkDecorPalm", PALM_SCALE, cylinder_collider("Collider", (0, 1.8, 0), 3.6, 1.2, PALM_SCALE)),
        ("DecorUmbrella", "ParkParkDecorUmbrella", UMBRELLA_SCALE, cylinder_collider("Collider", (0, 2.3, 0), 4.6, 0.4, UMBRELLA_SCALE)),
        ("DecorPond", "ParkParkDecorPond", POND_SCALE, cylinder_collider("Collider", (0, 0.4, 0), 0.8, 12.6, POND_SCALE)),
        ("DecorSandcastle", "ParkParkDecorSandcastle", SANDCASTLE_SCALE, cylinder_collider("Collider", (0, 1.6, 0), 3.2, 6.0, SANDCASTLE_SCALE)),
    )
    for name, obj, scale, collider in pieces:
        if missing_meshes((obj,)):
            print(f"skipped {name}: import {obj}.obj and record its mesh ID first")
            continue
        children = [mesh_part("Piece", obj, (0, 0, 0), 0, False, MINT, scale)]
        if collider:
            children.append(collider)
        write(name, model(name, children))


if __name__ == "__main__":
    main()

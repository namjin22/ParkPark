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
DUCK_SCALE = config_number("DuckScale")
BOUNCE_SCALE = config_number("BounceScale")
BUNNY_SCALE = config_number("BunnyScale")
MINE_SCALE = config_number("MineScale")
SKY_SCALE = config_number("SkyScale")
MAZE_SCALE = config_number("MazeScale")
PINE_SCALE = config_number("PineScale")
ROCK_SCALE = config_number("RockScale")
SHOP_SCALE = config_number("ShopScale")
STAGE_SCALE = config_number("StageScale")
PENGUIN_SCALE = config_number("PenguinScale")
SLED_SCALE = config_number("SledScale")
CAVE_SCALE = config_number("CaveScale")
REINDEER_SCALE = config_number("ReindeerScale")
SNOWFLAKE_SCALE = config_number("SnowflakeScale")
ORBIT_SCALE = config_number("OrbitScale")
MOON_SCALE = config_number("MoonScale")
UFO_SCALE = config_number("UfoScale")
CORSAIR_SCALE = config_number("CorsairScale")
TREASURE_SCALE = config_number("TreasureScale")
GHOSTSHIP_SCALE = config_number("GhostShipScale")
CANNON_SCALE = config_number("CannonScale")
BARRELS_SCALE = config_number("BarrelsScale")
LOLLI_SCALE = config_number("LolliScale")
GUMMY_SCALE = config_number("GummyScale")
FACTORY_SCALE = config_number("FactoryScale")
LOLLIPOP_SCALE = config_number("LollipopScale")
CANDYCANE_SCALE = config_number("CandyCaneScale")
COCONUT_SCALE = config_number("CoconutScale")
MUSHROOM_SCALE = config_number("MushroomScale")
TEMPLE_SCALE = config_number("TempleScale")
FERN_SCALE = config_number("FernScale")
TOTEM_SCALE = config_number("TotemScale")
CAMELSCALE = config_number("CamelScale")
DUNESCALE = config_number("DuneScale")
PYRAMIDSCALE = config_number("PyramidScale")
CACTUSSCALE = config_number("CactusScale")
OBELISKSCALE = config_number("ObeliskScale")
NIMBUSSCALE = config_number("NimbusScale")
RAINBOWSCALE = config_number("RainbowScale")
CASTLESCALE = config_number("CastleScale")
CLOUDSCALE = config_number("CloudScale")
RAINBOWARCHSCALE = config_number("RainbowArchScale")
CRYSTAL_SCALE = config_number("CrystalScale")
PLANET_SCALE = config_number("PlanetScale")
SWAN_SCALE = config_number("SwanScale")
BALLPIT_SCALE = config_number("BallPitScale")
ROCKET_SCALE = config_number("RocketScale")
TRAIN_CARS = int(config_number("TrainCarCount"))
FLUME_SCALE = config_number("FlumeScale")
FLUME_CARS = int(config_number("FlumeCarCount"))
TREE_SCALE = config_number("TreeScale")
BUSH_SCALE = config_number("BushScale")
LAMP_SCALE = config_number("LampScale")
BENCH_SCALE = config_number("BenchScale")
FLOWERS_SCALE = config_number("FlowersScale")
GAZEBO_SCALE = config_number("GazeboScale")
STATUE_SCALE = config_number("StatueScale")
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
    # A V2 mesh (ParkPark<Name>V2) replaces its original as soon as its mesh ID is recorded in MeshAssets.json.
    if f"{obj}V2" in ASSETS["meshes"]:
        obj = f"{obj}V2"
    center, natural_size = obj_bounds(obj)
    sx, sy, sz = (scale, scale, scale) if isinstance(scale, (int, float)) else scale
    # Roblox scales the mesh by Size / InitialSize, so InitialSize must stay the mesh's natural size.
    size = tuple(round(natural_size[axis] * (sx, sy, sz)[axis], 4) for axis in range(3))
    # Studio's importer turns every mesh half a turn about its own centre, and the template yaw turns it back about
    # that centre too, so the part's centre belongs where the OBJ puts it, rotated about the template origin by
    # the intended layout yaw (template yaw + 180). Rotating the centre by the template yaw alone put an
    # off-centre mesh (the sky ride's track) on the wrong side of its pivot.
    layout_yaw = yaw + 180.0
    cosine, sine = math.cos(math.radians(layout_yaw)), math.sin(math.radians(layout_yaw))
    # scale * (origin + Ry(layout yaw) * center), about the template root
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
                console("RepairConsole", 12 * S + 3, 0),
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
    build_duck()
    build_bounce()
    build_bunny()
    build_track_ride("Mine", "MineRide", "MineTrack", "MineCar", "MineCars", MINE_SCALE, 20, -36)
    build_track_ride("Sky", "SkyRide", "SkyTrack", "SkyCar", "SkyCars", SKY_SCALE, 18, -30)
    build_maze()
    build_swan()
    build_stage()
    build_penguin()
    build_sled()
    build_cave()
    build_reindeer()
    build_snowflake()
    build_orbit()
    build_moon()
    build_ufo()
    build_corsair()
    build_treasure()
    build_ghost_ship()
    build_lolli()
    build_gummy()
    build_factory()
    build_coconut()
    build_mushroom()
    build_temple()
    build_spinner_zone_ride("CamelRide", "ParkParkCamelHub", "ParkParkDunePod", CAMELSCALE, 7.4, 2.0)
    build_bounce_zone_ride("DuneRide", "ParkParkDuneMound", DUNESCALE)
    build_hidden_zone_ride("PyramidRide", "ParkParkPyramid", PYRAMIDSCALE, (14.4, 9.6, 14.4))
    build_spinner_zone_ride("NimbusRide", "ParkParkNimbusHub", "ParkParkCloudPod", NIMBUSSCALE, 3.0, 5.0)
    build_bounce_zone_ride("RainbowRide", "ParkParkRainbowMound", RAINBOWSCALE)
    build_hidden_zone_ride("CastleRide", "ParkParkSkyCastle", CASTLESCALE, (9.4, 9.8, 7.4))
    build_ball_pit()
    build_rocket()
    for shop_template, shop_obj in (("IceCreamShop", "ParkParkShopIceCream"), ("PizzaShop", "ParkParkShopPizza"), ("NoodleShop", "ParkParkShopNoodle"), ("CocoaShop", "ParkParkShopCocoa"), ("CookieShop", "ParkParkShopCookie"), ("StarShop", "ParkParkShopStar"), ("TavernShop", "ParkParkShopTavern"), ("SweetsShop", "ParkParkShopSweets"), ("JuiceShop", "ParkParkShopJuice"), ("OasisShop", "ParkParkShopOasis"), ("CottonShop", "ParkParkShopCotton")):
        build_shop(shop_template, shop_obj)
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
                mesh_part("FlumeTrack", "ParkParkFlumeTrack", (0, 0, 0), 180, False, MINT, FLUME_SCALE),
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
                mesh_part("TrainTrack", "ParkParkTrainTrack", (0, 0, 0), 180, False, CREAM, TRAIN_SCALE),
                # The station platform is solid, so guests and players cannot walk through it.
                box_collider("Station", (0, 0.2, -8.2), (16.0, 0.4, 2.6), 0, TRAIN_SCALE),
                model("TrainCars", wagons),
                # The ride is turned half a turn in the world, so this lands beside the station near its line.
                console("TrainConsole", 18, -33, 0),
            ],
        ),
    )


def build_duck() -> None:
    needed = ("ParkParkDuckHub", "ParkParkDuck")
    missing = missing_meshes(needed)
    if missing:
        print(f"skipped DuckRide: import {', '.join(missing)} and record their mesh IDs first")
        return

    # ExtraRideService turns `Hub` and spins each `Seat<N>` duck on its own turntable; the console sits beside the line.
    ducks = []
    for index in range(6):
        angle = 2 * math.pi * index / 6
        origin = (5.6 * math.cos(angle), 1.04, 5.6 * math.sin(angle))
        ducks.append(mesh_part(f"Seat{index + 1}", "ParkParkDuck", origin, 0, False, GOLD, DUCK_SCALE))
    write(
        "DuckRide",
        model(
            "DuckRide",
            [
                mesh_part("Hub", "ParkParkDuckHub", (0, 0, 0), 0, False, MINT, DUCK_SCALE),
                cylinder_collider("HubCollider", (0, 0.5, 0), 1.0, 17.4, DUCK_SCALE),
                cylinder_collider("ColumnCollider", (0, 3.0, 0), 5.0, 1.8, DUCK_SCALE),
                *ducks,
                console("Console", -24, 30, 0),
            ],
        ),
    )


def build_bounce() -> None:
    if missing_meshes(("ParkParkBounceHouse",)):
        print("skipped BounceRide: import ParkParkBounceHouse and record its mesh ID first")
        return

    # The castle is turned 180 so the imported mesh matches the OBJ layout (its gate faces +Z, toward the line).
    seats = []
    for index in range(6):
        angle = 2 * math.pi * index / 6
        seats.append(box_collider(f"Seat{index + 1}", (3.2 * math.cos(angle), 1.05, 3.2 * math.sin(angle)), (1, 0.2, 1), 0, BOUNCE_SCALE))
    write(
        "BounceRide",
        model(
            "BounceRide",
            [
                mesh_part("Pad", "ParkParkBounceHouse", (0, 0, 0), 180, False, GOLD, BOUNCE_SCALE),
                box_collider("Collider", (0, 3.0, 0), (14.0, 6.0, 14.0), 0, BOUNCE_SCALE),
                *seats,
                console("Console", -24, 32, 0),
            ],
        ),
    )


def build_bunny() -> None:
    needed = ("ParkParkBunnyHub", "ParkParkBunny")
    missing = missing_meshes(needed)
    if missing:
        print(f"skipped BunnyRide: import {', '.join(missing)} and record their mesh IDs first")
        return

    # ExtraRideService turns `Hub` and bobs each `Seat<N>` bunny; each bunny is turned to face its direction of travel
    # (the imported mesh already comes in half a turn round, hence the minus sign).
    bunnies = []
    for index in range(6):
        angle = 2 * math.pi * index / 6
        origin = (4.4 * math.cos(angle), 0.72, 4.4 * math.sin(angle))
        bunnies.append(mesh_part(f"Seat{index + 1}", "ParkParkBunny", origin, -math.degrees(angle), False, CREAM, BUNNY_SCALE))
    write(
        "BunnyRide",
        model(
            "BunnyRide",
            [
                mesh_part("Hub", "ParkParkBunnyHub", (0, 0, 0), 0, False, MINT, BUNNY_SCALE),
                cylinder_collider("HubCollider", (0, 0.5, 0), 1.0, 14.4, BUNNY_SCALE),
                cylinder_collider("ColumnCollider", (0, 3.0, 0), 5.0, 1.8, BUNNY_SCALE),
                *bunnies,
                console("Console", -24, 20, 0),
            ],
        ),
    )


def build_track_ride(
    key: str, template: str, track_obj: str, car_prefix: str, cars_name: str, scale: float, console_x: float, console_z: float
) -> None:
    needed = (f"ParkPark{track_obj}", f"ParkPark{car_prefix}")
    missing = missing_meshes(needed)
    if missing:
        print(f"skipped {template}: import {', '.join(missing)} and record their mesh IDs first")
        return

    # TrackService places the cars along the generated path when the game starts. Like the train, the ride is
    # turned half a turn in the world, and the imported track mesh needs the matching yaw 180 here.
    cars = [
        mesh_part(f"{car_prefix}{index + 1}", f"ParkPark{car_prefix}", (0, 1.0, index * 4.9), 0, False, CORAL, scale)
        for index in range(2)
    ]
    write(
        template,
        model(
            template,
            [
                mesh_part(track_obj, f"ParkPark{track_obj}", (0, 0, 0), 180, False, CREAM, scale),
                box_collider("Station", (0, 0.2, -8.2), (16.0, 0.4, 2.6), 0, scale),
                model(cars_name, cars),
                console("Console", console_x, console_z, 0),
            ],
        ),
    )


def build_maze() -> None:
    if missing_meshes(("ParkParkHedgeMaze",)):
        print("skipped MazeRide: import ParkParkHedgeMaze and record its mesh ID first")
        return

    # The hedge ring is turned 180 so the imported mesh matches the OBJ layout (its entrance gap faces +Z).
    seats = [box_collider(f"Seat{index + 1}", (index, 1.0, 0), (1, 0.2, 1), 0, MAZE_SCALE) for index in range(6)]
    write(
        "MazeRide",
        model(
            "MazeRide",
            [
                mesh_part("Pad", "ParkParkHedgeMaze", (0, 0, 0), 180, False, MINT, MAZE_SCALE),
                box_collider("Collider", (0, 1.6, 0), (30.4, 3.2, 30.4), 0, MAZE_SCALE),
                *seats,
                console("Console", -24, 35, 0),
            ],
        ),
    )


def build_shop(template: str, obj: str) -> None:
    if missing_meshes((obj,)):
        print(f"skipped {template}: import {obj} and record its mesh ID first")
        return

    # The stall body is turned 180 so the imported mesh matches the OBJ layout (counter on +Z, toward the line).
    # The invisible `Counter` marks where the head guest is served.
    write(
        template,
        model(
            template,
            [
                mesh_part("Body", obj, (0, 0, 0), 180, False, MINT, SHOP_SCALE),
                box_collider("BodyCollider", (0, 2.0, -0.2), (8.2, 4.0, 5.0), 0, SHOP_SCALE),
                box_collider("Counter", (0, 1.2, 3.0), (1.0, 0.2, 1.0), 0, SHOP_SCALE),
                console("Console", -16, 6, 0),
            ],
        ),
    )


def build_swan() -> None:
    needed = ("ParkParkSwanHub", "ParkParkSwan")
    missing = missing_meshes(needed)
    if missing:
        print(f"skipped SwanRide: import {', '.join(missing)} and record their mesh IDs first")
        return

    # Like the bunny carousel: each swan faces its direction of travel (the imported mesh already comes in half a turn
    # round, hence the minus sign); ExtraRideService bobs the `Seat<N>` swans while `Hub` turns.
    swans = []
    for index in range(6):
        angle = 2 * math.pi * index / 6
        origin = (4.4 * math.cos(angle), 0.9, 4.4 * math.sin(angle))
        swans.append(mesh_part(f"Seat{index + 1}", "ParkParkSwan", origin, -math.degrees(angle), False, CREAM, SWAN_SCALE))
    write(
        "SwanRide",
        model(
            "SwanRide",
            [
                mesh_part("Hub", "ParkParkSwanHub", (0, 0, 0), 0, False, MINT, SWAN_SCALE),
                cylinder_collider("HubCollider", (0, 0.5, 0), 1.0, 14.4, SWAN_SCALE),
                cylinder_collider("ColumnCollider", (0, 2.0, 0), 4.0, 1.8, SWAN_SCALE),
                *swans,
                console("Console", -24, 22, 0),
            ],
        ),
    )


def build_ball_pit() -> None:
    if missing_meshes(("ParkParkBallPit",)):
        print("skipped BallPitRide: import ParkParkBallPit and record its mesh ID first")
        return

    # The pit is turned 180 so the imported mesh matches the OBJ layout (its low entrance side faces +Z).
    seats = []
    for index in range(6):
        angle = 2 * math.pi * index / 6
        seats.append(box_collider(f"Seat{index + 1}", (3.2 * math.cos(angle), 1.1, 3.2 * math.sin(angle)), (1, 0.2, 1), 0, BALLPIT_SCALE))
    write(
        "BallPitRide",
        model(
            "BallPitRide",
            [
                mesh_part("Pad", "ParkParkBallPit", (0, 0, 0), 180, False, GOLD, BALLPIT_SCALE),
                box_collider("Collider", (0, 1.2, 0), (14.0, 2.4, 14.0), 0, BALLPIT_SCALE),
                *seats,
                console("Console", -24, 24, 0),
            ],
        ),
    )


def build_rocket() -> None:
    needed = ("ParkParkRocketHub", "ParkParkRocket")
    missing = missing_meshes(needed)
    if missing:
        print(f"skipped RocketRide: import {', '.join(missing)} and record their mesh IDs first")
        return

    rockets = []
    for index in range(6):
        angle = 2 * math.pi * index / 6
        origin = (5.4 * math.cos(angle), 0.98, 5.4 * math.sin(angle))
        rockets.append(mesh_part(f"Seat{index + 1}", "ParkParkRocket", origin, 0, False, CREAM, ROCKET_SCALE))
    write(
        "RocketRide",
        model(
            "RocketRide",
            [
                mesh_part("Hub", "ParkParkRocketHub", (0, 0, 0), 0, False, MINT, ROCKET_SCALE),
                cylinder_collider("HubCollider", (0, 0.5, 0), 1.0, 16.8, ROCKET_SCALE),
                cylinder_collider("ColumnCollider", (0, 3.0, 0), 5.0, 2.2, ROCKET_SCALE),
                *rockets,
                console("Console", -26, 24, 0),
            ],
        ),
    )


def build_reindeer() -> None:
    needed = ("ParkParkReindeerHub", "ParkParkReindeer")
    missing = missing_meshes(needed)
    if missing:
        print(f"skipped ReindeerRide: import {', '.join(missing)} and record their mesh IDs first")
        return

    # Like the swan boats: each reindeer faces its direction of travel (the imported mesh comes in half a turn round).
    deer = []
    for index in range(6):
        angle = 2 * math.pi * index / 6
        origin = (4.4 * math.cos(angle), 0.9, 4.4 * math.sin(angle))
        deer.append(mesh_part(f"Seat{index + 1}", "ParkParkReindeer", origin, -math.degrees(angle), False, CREAM, REINDEER_SCALE))
    write(
        "ReindeerRide",
        model(
            "ReindeerRide",
            [
                mesh_part("Hub", "ParkParkReindeerHub", (0, 0, 0), 0, False, MINT, REINDEER_SCALE),
                cylinder_collider("HubCollider", (0, 0.5, 0), 1.0, 14.4, REINDEER_SCALE),
                cylinder_collider("ColumnCollider", (0, 2.0, 0), 4.0, 1.8, REINDEER_SCALE),
                *deer,
                console("Console", -24, 22, 0),
            ],
        ),
    )


def build_snowflake() -> None:
    needed = ("ParkParkSnowflakeHub", "ParkParkSnowPod")
    missing = missing_meshes(needed)
    if missing:
        print(f"skipped SnowflakeRide: import {', '.join(missing)} and record their mesh IDs first")
        return

    pods = []
    for index in range(6):
        angle = 2 * math.pi * index / 6
        origin = (5.4 * math.cos(angle), 0.98, 5.4 * math.sin(angle))
        pods.append(mesh_part(f"Seat{index + 1}", "ParkParkSnowPod", origin, 0, False, CREAM, SNOWFLAKE_SCALE))
    write(
        "SnowflakeRide",
        model(
            "SnowflakeRide",
            [
                mesh_part("Hub", "ParkParkSnowflakeHub", (0, 0, 0), 0, False, MINT, SNOWFLAKE_SCALE),
                cylinder_collider("HubCollider", (0, 0.5, 0), 1.0, 16.8, SNOWFLAKE_SCALE),
                cylinder_collider("ColumnCollider", (0, 3.0, 0), 5.0, 2.2, SNOWFLAKE_SCALE),
                *pods,
                console("Console", -26, 24, 0),
            ],
        ),
    )


def build_orbit() -> None:
    needed = ("ParkParkOrbitHub", "ParkParkSpacePod")
    missing = missing_meshes(needed)
    if missing:
        print(f"skipped OrbitRide: import {', '.join(missing)} and record their mesh IDs first")
        return

    pods = []
    for index in range(6):
        angle = 2 * math.pi * index / 6
        origin = (5.4 * math.cos(angle), 0.98, 5.4 * math.sin(angle))
        pods.append(mesh_part(f"Seat{index + 1}", "ParkParkSpacePod", origin, 0, False, CREAM, ORBIT_SCALE))
    write(
        "OrbitRide",
        model(
            "OrbitRide",
            [
                mesh_part("Hub", "ParkParkOrbitHub", (0, 0, 0), 0, False, MINT, ORBIT_SCALE),
                cylinder_collider("HubCollider", (0, 0.5, 0), 1.0, 16.8, ORBIT_SCALE),
                cylinder_collider("ColumnCollider", (0, 3.0, 0), 6.0, 2.6, ORBIT_SCALE),
                *pods,
                console("Console", -26, 24, 0),
            ],
        ),
    )


def build_moon() -> None:
    if missing_meshes(("ParkParkMoonMound",)):
        print("skipped MoonRide: import ParkParkMoonMound and record its mesh ID first")
        return

    seats = []
    for index in range(6):
        angle = 2 * math.pi * index / 6
        seats.append(box_collider(f"Seat{index + 1}", (3.2 * math.cos(angle), 1.6, 3.2 * math.sin(angle)), (1, 0.2, 1), 0, MOON_SCALE))
    write(
        "MoonRide",
        model(
            "MoonRide",
            [
                mesh_part("Pad", "ParkParkMoonMound", (0, 0, 0), 180, False, CREAM, MOON_SCALE),
                cylinder_collider("Collider", (0, 0.9, 0), 1.8, 14.0, MOON_SCALE),
                *seats,
                console("Console", -24, 24, 0),
            ],
        ),
    )


def build_ufo() -> None:
    if missing_meshes(("ParkParkUfo",)):
        print("skipped UfoRide: import ParkParkUfo and record its mesh ID first")
        return

    seats = [box_collider(f"Seat{index + 1}", (index, 1.0, 0), (1, 0.2, 1), 0, UFO_SCALE) for index in range(6)]
    write(
        "UfoRide",
        model(
            "UfoRide",
            [
                mesh_part("Pad", "ParkParkUfo", (0, 0, 0), 180, False, MINT, UFO_SCALE),
                cylinder_collider("Collider", (0, 2.4, 0), 4.8, 14.6, UFO_SCALE),
                *seats,
                console("Console", -24, 30, 0),
            ],
        ),
    )


def build_corsair() -> None:
    needed = ("ParkParkCorsairHub", "ParkParkBarrelPod")
    missing = missing_meshes(needed)
    if missing:
        print(f"skipped CorsairRide: import {', '.join(missing)} and record their mesh IDs first")
        return

    pods = []
    for index in range(6):
        angle = 2 * math.pi * index / 6
        origin = (5.4 * math.cos(angle), 0.98, 5.4 * math.sin(angle))
        pods.append(mesh_part(f"Seat{index + 1}", "ParkParkBarrelPod", origin, 0, False, CREAM, CORSAIR_SCALE))
    write(
        "CorsairRide",
        model(
            "CorsairRide",
            [
                mesh_part("Hub", "ParkParkCorsairHub", (0, 0, 0), 0, False, MINT, CORSAIR_SCALE),
                cylinder_collider("HubCollider", (0, 0.5, 0), 1.0, 16.8, CORSAIR_SCALE),
                cylinder_collider("ColumnCollider", (0, 3.0, 0), 6.0, 1.6, CORSAIR_SCALE),
                *pods,
                console("Console", -26, 24, 0),
            ],
        ),
    )


def build_treasure() -> None:
    if missing_meshes(("ParkParkTreasureMound",)):
        print("skipped TreasureRide: import ParkParkTreasureMound and record its mesh ID first")
        return

    seats = []
    for index in range(6):
        angle = 2 * math.pi * index / 6
        seats.append(box_collider(f"Seat{index + 1}", (3.2 * math.cos(angle), 1.6, 3.2 * math.sin(angle)), (1, 0.2, 1), 0, TREASURE_SCALE))
    write(
        "TreasureRide",
        model(
            "TreasureRide",
            [
                mesh_part("Pad", "ParkParkTreasureMound", (0, 0, 0), 180, False, CREAM, TREASURE_SCALE),
                cylinder_collider("Collider", (0, 0.9, 0), 1.8, 14.0, TREASURE_SCALE),
                *seats,
                console("Console", -24, 24, 0),
            ],
        ),
    )


def build_ghost_ship() -> None:
    if missing_meshes(("ParkParkGhostShip",)):
        print("skipped GhostShipRide: import ParkParkGhostShip and record its mesh ID first")
        return

    seats = [box_collider(f"Seat{index + 1}", (index, 1.0, 0), (1, 0.2, 1), 0, GHOSTSHIP_SCALE) for index in range(6)]
    write(
        "GhostShipRide",
        model(
            "GhostShipRide",
            [
                mesh_part("Pad", "ParkParkGhostShip", (0, 0, 0), 180, False, MINT, GHOSTSHIP_SCALE),
                box_collider("Collider", (0, 3.0, 0), (7.4, 6.0, 14.6), 0, GHOSTSHIP_SCALE),
                *seats,
                console("Console", -24, 30, 0),
            ],
        ),
    )


def build_lolli() -> None:
    needed = ("ParkParkLolliHub", "ParkParkCandyPod")
    missing = missing_meshes(needed)
    if missing:
        print(f"skipped LolliRide: import {', '.join(missing)} and record their mesh IDs first")
        return

    pods = []
    for index in range(6):
        angle = 2 * math.pi * index / 6
        origin = (5.4 * math.cos(angle), 0.98, 5.4 * math.sin(angle))
        pods.append(mesh_part(f"Seat{index + 1}", "ParkParkCandyPod", origin, 0, False, CREAM, LOLLI_SCALE))
    write(
        "LolliRide",
        model(
            "LolliRide",
            [
                mesh_part("Hub", "ParkParkLolliHub", (0, 0, 0), 0, False, MINT, LOLLI_SCALE),
                cylinder_collider("HubCollider", (0, 0.5, 0), 1.0, 16.8, LOLLI_SCALE),
                cylinder_collider("ColumnCollider", (0, 3.0, 0), 6.0, 1.2, LOLLI_SCALE),
                *pods,
                console("Console", -26, 24, 0),
            ],
        ),
    )


def build_gummy() -> None:
    if missing_meshes(("ParkParkGummyMound",)):
        print("skipped GummyRide: import ParkParkGummyMound and record its mesh ID first")
        return

    seats = []
    for index in range(6):
        angle = 2 * math.pi * index / 6
        seats.append(box_collider(f"Seat{index + 1}", (3.2 * math.cos(angle), 1.6, 3.2 * math.sin(angle)), (1, 0.2, 1), 0, GUMMY_SCALE))
    write(
        "GummyRide",
        model(
            "GummyRide",
            [
                mesh_part("Pad", "ParkParkGummyMound", (0, 0, 0), 180, False, CREAM, GUMMY_SCALE),
                cylinder_collider("Collider", (0, 0.9, 0), 1.8, 14.0, GUMMY_SCALE),
                *seats,
                console("Console", -24, 24, 0),
            ],
        ),
    )


def build_factory() -> None:
    if missing_meshes(("ParkParkCandyFactory",)):
        print("skipped FactoryRide: import ParkParkCandyFactory and record its mesh ID first")
        return

    seats = [box_collider(f"Seat{index + 1}", (index, 1.0, 0), (1, 0.2, 1), 0, FACTORY_SCALE) for index in range(6)]
    write(
        "FactoryRide",
        model(
            "FactoryRide",
            [
                mesh_part("Pad", "ParkParkCandyFactory", (0, 0, 0), 180, False, MINT, FACTORY_SCALE),
                box_collider("Collider", (0, 3.0, 0), (12.6, 6.0, 9.6), 0, FACTORY_SCALE),
                *seats,
                console("Console", -24, 30, 0),
            ],
        ),
    )


def build_coconut() -> None:
    needed = ("ParkParkCoconutHub", "ParkParkCoconutPod")
    missing = missing_meshes(needed)
    if missing:
        print(f"skipped CoconutRide: import {', '.join(missing)} and record their mesh IDs first")
        return

    pods = []
    for index in range(6):
        angle = 2 * math.pi * index / 6
        origin = (5.4 * math.cos(angle), 0.98, 5.4 * math.sin(angle))
        pods.append(mesh_part(f"Seat{index + 1}", "ParkParkCoconutPod", origin, 0, False, CREAM, COCONUT_SCALE))
    write(
        "CoconutRide",
        model(
            "CoconutRide",
            [
                mesh_part("Hub", "ParkParkCoconutHub", (0, 0, 0), 0, False, MINT, COCONUT_SCALE),
                cylinder_collider("HubCollider", (0, 0.5, 0), 1.0, 16.8, COCONUT_SCALE),
                cylinder_collider("ColumnCollider", (0, 3.5, 0), 7.0, 2.0, COCONUT_SCALE),
                *pods,
                console("Console", -26, 24, 0),
            ],
        ),
    )


def build_mushroom() -> None:
    if missing_meshes(("ParkParkMushroomMound",)):
        print("skipped MushroomRide: import ParkParkMushroomMound and record its mesh ID first")
        return

    seats = []
    for index in range(6):
        angle = 2 * math.pi * index / 6
        seats.append(box_collider(f"Seat{index + 1}", (3.2 * math.cos(angle), 1.6, 3.2 * math.sin(angle)), (1, 0.2, 1), 0, MUSHROOM_SCALE))
    write(
        "MushroomRide",
        model(
            "MushroomRide",
            [
                mesh_part("Pad", "ParkParkMushroomMound", (0, 0, 0), 180, False, CREAM, MUSHROOM_SCALE),
                cylinder_collider("Collider", (0, 0.9, 0), 1.8, 14.0, MUSHROOM_SCALE),
                *seats,
                console("Console", -24, 24, 0),
            ],
        ),
    )


def build_temple() -> None:
    if missing_meshes(("ParkParkTemple",)):
        print("skipped TempleRide: import ParkParkTemple and record its mesh ID first")
        return

    seats = [box_collider(f"Seat{index + 1}", (index, 1.0, 0), (1, 0.2, 1), 0, TEMPLE_SCALE) for index in range(6)]
    write(
        "TempleRide",
        model(
            "TempleRide",
            [
                mesh_part("Pad", "ParkParkTemple", (0, 0, 0), 180, False, CREAM, TEMPLE_SCALE),
                box_collider("Collider", (0, 5.0, 0), (13.2, 10.0, 11.2), 0, TEMPLE_SCALE),
                *seats,
                console("Console", -24, 30, 0),
            ],
        ),
    )


def build_spinner_zone_ride(template: str, hub_obj: str, pod_obj: str, scale: float, column_h: float = 6.0, column_d: float = 2.0) -> None:
    missing = missing_meshes((hub_obj, pod_obj))
    if missing:
        print(f"skipped {template}: import {', '.join(missing)} and record their mesh IDs first")
        return

    pods = []
    for index in range(6):
        angle = 2 * math.pi * index / 6
        origin = (5.4 * math.cos(angle), 0.98, 5.4 * math.sin(angle))
        pods.append(mesh_part(f"Seat{index + 1}", pod_obj, origin, 0, False, CREAM, scale))
    write(
        template,
        model(
            template,
            [
                mesh_part("Hub", hub_obj, (0, 0, 0), 0, False, MINT, scale),
                cylinder_collider("HubCollider", (0, 0.5, 0), 1.0, 16.8, scale),
                cylinder_collider("ColumnCollider", (0, column_h / 2, 0), column_h, column_d, scale),
                *pods,
                console("Console", -26, 24, 0),
            ],
        ),
    )


def build_bounce_zone_ride(template: str, obj: str, scale: float) -> None:
    if missing_meshes((obj,)):
        print(f"skipped {template}: import {obj} and record its mesh ID first")
        return

    seats = []
    for index in range(6):
        angle = 2 * math.pi * index / 6
        seats.append(box_collider(f"Seat{index + 1}", (3.2 * math.cos(angle), 1.6, 3.2 * math.sin(angle)), (1, 0.2, 1), 0, scale))
    write(
        template,
        model(
            template,
            [
                mesh_part("Pad", obj, (0, 0, 0), 180, False, CREAM, scale),
                cylinder_collider("Collider", (0, 0.9, 0), 1.8, 14.0, scale),
                *seats,
                console("Console", -24, 24, 0),
            ],
        ),
    )


def build_hidden_zone_ride(template: str, obj: str, scale: float, box: tuple[float, float, float]) -> None:
    if missing_meshes((obj,)):
        print(f"skipped {template}: import {obj} and record its mesh ID first")
        return

    seats = [box_collider(f"Seat{index + 1}", (index, 1.0, 0), (1, 0.2, 1), 0, scale) for index in range(6)]
    write(
        template,
        model(
            template,
            [
                mesh_part("Pad", obj, (0, 0, 0), 180, False, MINT, scale),
                box_collider("Collider", (0, box[1] / 2, 0), box, 0, scale),
                *seats,
                console("Console", -24, 30, 0),
            ],
        ),
    )


def build_stage() -> None:
    if missing_meshes(("ParkParkShowStage",)):
        print("skipped ShowStage: import ParkParkShowStage and record its mesh ID first")
        return

    # The stage is turned 180 so the imported mesh matches the OBJ layout (audience on +Z). The `Seat<N>` markers are
    # ground spots in front of it where watching guests stand.
    seats = []
    for index in range(8):
        column, row = index % 4, index // 4
        seats.append(box_collider(f"Seat{index + 1}", ((column - 1.5) * 3, 0.1, 7 + row * 2.5), (1, 0.2, 1), 0, STAGE_SCALE))
    write(
        "ShowStage",
        model(
            "ShowStage",
            [
                mesh_part("Pad", "ParkParkShowStage", (0, 0, 0), 180, False, CORAL, STAGE_SCALE),
                box_collider("Collider", (0, 1.4, 0), (12.4, 2.8, 9.4), 0, STAGE_SCALE),
                *seats,
                console("Console", -24, 22, 0),
            ],
        ),
    )


def build_penguin() -> None:
    needed = ("ParkParkIceHub", "ParkParkPenguin")
    missing = missing_meshes(needed)
    if missing:
        print(f"skipped PenguinRide: import {', '.join(missing)} and record their mesh IDs first")
        return

    sleds = []
    for index in range(6):
        angle = 2 * math.pi * index / 6
        origin = (5.4 * math.cos(angle), 0.98, 5.4 * math.sin(angle))
        sleds.append(mesh_part(f"Seat{index + 1}", "ParkParkPenguin", origin, 0, False, CREAM, PENGUIN_SCALE))
    write(
        "PenguinRide",
        model(
            "PenguinRide",
            [
                mesh_part("Hub", "ParkParkIceHub", (0, 0, 0), 0, False, MINT, PENGUIN_SCALE),
                cylinder_collider("HubCollider", (0, 0.5, 0), 1.0, 16.8, PENGUIN_SCALE),
                cylinder_collider("ColumnCollider", (0, 3.0, 0), 5.0, 2.2, PENGUIN_SCALE),
                *sleds,
                console("Console", -26, 24, 0),
            ],
        ),
    )


def build_sled() -> None:
    if missing_meshes(("ParkParkSnowMound",)):
        print("skipped SledRide: import ParkParkSnowMound and record its mesh ID first")
        return

    seats = []
    for index in range(6):
        angle = 2 * math.pi * index / 6
        seats.append(box_collider(f"Seat{index + 1}", (3.2 * math.cos(angle), 1.6, 3.2 * math.sin(angle)), (1, 0.2, 1), 0, SLED_SCALE))
    write(
        "SledRide",
        model(
            "SledRide",
            [
                mesh_part("Pad", "ParkParkSnowMound", (0, 0, 0), 180, False, CREAM, SLED_SCALE),
                cylinder_collider("Collider", (0, 0.9, 0), 1.8, 14.0, SLED_SCALE),
                *seats,
                console("Console", -24, 24, 0),
            ],
        ),
    )


def build_cave() -> None:
    if missing_meshes(("ParkParkIceCave",)):
        print("skipped CaveRide: import ParkParkIceCave and record its mesh ID first")
        return

    seats = [box_collider(f"Seat{index + 1}", (index, 1.0, 0), (1, 0.2, 1), 0, CAVE_SCALE) for index in range(6)]
    write(
        "CaveRide",
        model(
            "CaveRide",
            [
                mesh_part("Pad", "ParkParkIceCave", (0, 0, 0), 180, False, MINT, CAVE_SCALE),
                cylinder_collider("Collider", (0, 3.5, 0), 7.0, 15.4, CAVE_SCALE),
                box_collider("TunnelCollider", (0, 1.6, 8.2), (4.6, 3.2, 4.2), 0, CAVE_SCALE),
                *seats,
                console("Console", -24, 30, 0),
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
                mesh_part("CoasterTrack", "ParkParkCoasterTrack", (0, 0, 0), 180, False, CORAL, COASTER_SCALE),
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
        ("DecorFlowers", "ParkParkDecorFlowers", FLOWERS_SCALE, None),
        ("DecorGazebo", "ParkParkDecorGazebo", GAZEBO_SCALE, cylinder_collider("Collider", (0, 0.5, 0), 1.0, 6.4, GAZEBO_SCALE)),
        ("DecorStatue", "ParkParkDecorStatue", STATUE_SCALE, box_collider("Collider", (0, 1.0, 0), (3.0, 2.0, 3.0), 0, STATUE_SCALE)),
        ("DecorCrystal", "ParkParkDecorCrystal", CRYSTAL_SCALE, cylinder_collider("Collider", (0, 1.4, 0), 2.8, 2.2, CRYSTAL_SCALE)),
        ("DecorPlanet", "ParkParkDecorPlanet", PLANET_SCALE, cylinder_collider("Collider", (0, 1.4, 0), 2.8, 2.4, PLANET_SCALE)),
        ("DecorCannon", "ParkParkDecorCannon", CANNON_SCALE, box_collider("Collider", (0, 1.0, 0), (1.8, 2.0, 2.6), 0, CANNON_SCALE)),
        ("DecorBarrels", "ParkParkDecorBarrels", BARRELS_SCALE, cylinder_collider("Collider", (0, 0.9, 0.6), 1.8, 4.2, BARRELS_SCALE)),
        ("DecorLollipop", "ParkParkDecorLollipop", LOLLIPOP_SCALE, cylinder_collider("Collider", (0, 1.7, 0), 3.4, 0.6, LOLLIPOP_SCALE)),
        ("DecorCandyCane", "ParkParkDecorCandyCane", CANDYCANE_SCALE, cylinder_collider("Collider", (0, 2.0, 0), 4.0, 0.7, CANDYCANE_SCALE)),
        ("DecorFern", "ParkParkDecorFern", FERN_SCALE, None),
        ("DecorTotem", "ParkParkDecorTotem", TOTEM_SCALE, box_collider("Collider", (0, 2.4, 0), (1.4, 4.8, 1.4), 0, TOTEM_SCALE)),
        ("DecorCactus", "ParkParkDecorCactus", CACTUSSCALE, cylinder_collider("Collider", (0, 1.8, 0), 3.6, 1.2, CACTUSSCALE)),
        ("DecorObelisk", "ParkParkDecorObelisk", OBELISKSCALE, box_collider("Collider", (0, 2.5, 0), (1.8, 5.0, 1.8), 0, OBELISKSCALE)),
        ("DecorCloud", "ParkParkDecorCloud", CLOUDSCALE, cylinder_collider("Collider", (0, 1.3, 0), 2.6, 0.5, CLOUDSCALE)),
        ("DecorRainbow", "ParkParkDecorRainbow", RAINBOWARCHSCALE, None),
        ("DecorPine", "ParkParkDecorPine", PINE_SCALE, cylinder_collider("Collider", (0, 1.2, 0), 2.4, 0.8, PINE_SCALE)),
        ("DecorRock", "ParkParkDecorRock", ROCK_SCALE, cylinder_collider("Collider", (0, 1.0, 0), 2.0, 4.4, ROCK_SCALE)),
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

import math

# ----------------------------------------------------------------------------------------------------------------
# Zone specs: the desert (사막 구역) and the cloud zone (구름 구역).
# ----------------------------------------------------------------------------------------------------------------
ZONES = [
    {
        "key": "Desert", "name": "사막 구역", "gate": 810000, "ground": ("Color3.fromRGB(226, 196, 140)", "Sand"),
        "requires": "Juice", "boundary": -2242, "minz": -2505, "gather": ("선인장 열매", "Color3.fromRGB(255, 150, 90)"),
        "rides": [
            dict(key="Camel", disp="낙타 회전", model="CamelRide", kind="Spinner", fare=3800, total=540000, thrill=True, scale="CamelScale", scale_v="2.4"),
            dict(key="Dune", disp="모래 언덕 점프", model="DuneRide", kind="Bounce", fare=4000, total=550000, thrill=False, scale="DuneScale", scale_v="2.4"),
            dict(key="Pyramid", disp="피라미드 탐험", model="PyramidRide", kind="Hidden", fare=4200, total=560000, thrill=True, scale="PyramidScale", scale_v="2.2"),
            dict(key="Oasis", disp="오아시스 카페", model="OasisShop", kind="Shop", fare=3900, total=570000, thrill=False, scale="", scale_v=""),
        ],
        "decor": [("DecorCactus", "CactusScale", "2", 30, 4, 2), ("DecorObelisk", "ObeliskScale", "2", 8, 6, 2), ("DecorRock", None, None, 20, 6, 4), ("DecorPalm", None, None, 8, 7, 5)],
    },
    {
        "key": "Cloud", "name": "구름 구역", "gate": 880000, "ground": ("Color3.fromRGB(238, 243, 250)", "Snow"),
        "requires": "Oasis", "boundary": -2505, "minz": -2768, "gather": ("구름 조각", "Color3.fromRGB(190, 215, 255)"),
        "rides": [
            dict(key="Nimbus", disp="구름 회전", model="NimbusRide", kind="Spinner", fare=4400, total=580000, thrill=True, scale="NimbusScale", scale_v="2.4"),
            dict(key="Rainbow", disp="무지개 점프", model="RainbowRide", kind="Bounce", fare=4600, total=590000, thrill=False, scale="RainbowScale", scale_v="2.4"),
            dict(key="Castle", disp="하늘 성 탐험", model="CastleRide", kind="Hidden", fare=4800, total=600000, thrill=True, scale="CastleScale", scale_v="2.2"),
            dict(key="Cotton", disp="솜사탕 가게", model="CottonShop", kind="Shop", fare=4500, total=610000, thrill=False, scale="", scale_v=""),
        ],
        "decor": [("DecorCloud", "CloudScale", "2", 26, 5, 3), ("DecorRainbow", "RainbowArchScale", "2", 8, 6, 4), ("DecorFlowers", None, None, 14, 4, 2.5)],
    },
]
POS = [(-60, "A"), (150, "A"), (-60, "B"), (110, "B")]  # x, row


def fnum(v):
    return str(int(round(v / 1000.0) * 1000))


def ride_text(zone, prev_key, index, r):
    total = r["total"]
    unlock = round(total * 0.68, -3)
    repair = total - unlock
    income = [round(total * f, -3) for f in (0.302, 0.558, 0.899, 1.354)]
    staff = [round(total * f, -3) for f in (0.39, 0.663, 1.06)]
    lines = [
        f"\t\t{r['key']} = {{",
        f'\t\t\tDisplayName = "{r["disp"]}",',
        f'\t\t\tModelName = "{r["model"]}",',
        f'\t\t\tConsoleName = "{r["model"]}Console",',
        f"\t\t\tUnlockCost = {int(unlock)},",
        f"\t\t\tRepairCost = {int(repair)},",
        f"\t\t\tBaseFare = {r['fare']},",
        f'\t\t\tRequires = "{prev_key}",',
        f'\t\t\tZone = "{zone["key"]}",',
    ]
    if r["kind"] == "Shop":
        lines.append("\t\t\tIsShop = true,")
    else:
        lines.append(f"\t\t\tRideSeconds = {26 if r['kind'] == 'Spinner' else 22 if r['kind'] == 'Bounce' else 25},")
    lines += [
        f"\t\t\tIncomePerLevel = {int(round(r['fare'] / 3))},",
        "\t\t\tIncomeCosts = { " + ", ".join(str(int(x)) for x in income) + " },",
        "\t\t\tStaffCosts = { " + ", ".join(str(int(x)) for x in staff) + " },",
        "\t\t},",
    ]
    return "\n".join(lines) + "\n"


def extra_text(r):
    k = r["key"]
    base = [f"\t{k} = {{", f"\t\tKind = \"{r['kind'] if r['kind'] != 'Spinner' else 'Spinner'}\",", f"\t\tTemplate = GameConfig.Rides.{k}.ModelName,"]
    if r["kind"] == "Shop":
        base.append("\t\tScale = GameConfig.ShopScale,")
    else:
        base.append(f"\t\tScale = GameConfig.{r['scale']},")
    if r["kind"] == "Spinner":
        base += ["\t\tSeatCount = 6,", "\t\tSeatLift = 0.6,", "\t\tRiderHip = 1.4,", "\t\tHubSeconds = 12,", "\t\tSpinSeconds = 5,", "\t\tHubRadius = 8.2,", "\t\tSeatOrbit = 5.4,"]
    elif r["kind"] == "Bounce":
        base += ["\t\tSeatCount = 6,", "\t\tSeatLift = 0,", "\t\tRiderHip = 3.0,", "\t\tBounceHeight = 6,", "\t\tBouncePeriod = 1.8,"]
    elif r["kind"] == "Hidden":
        base += ["\t\tSeatCount = 6,", "\t\tSeatLift = 0,", "\t\tRiderHip = 0,"]
    else:
        base += ["\t\tSeatCount = 1,", "\t\tSeatLift = 0,", "\t\tRiderHip = 0,"]
    base.append("\t},")
    return "\n".join(base) + "\n"


def layout_text(zone):
    b = zone["boundary"]
    row = {"A": b - 73, "B": b - 188}
    out = []
    for r, (x, rw) in zip(zone["rides"], POS):
        pivot = row[rw] if r["kind"] != "Shop" else b - 158
        radius = 26 if r["kind"] in ("Spinner", "Bounce") else 34 if r["kind"] == "Hidden" else 16
        head = pivot + (30 if r["kind"] != "Shop" else 10)
        out.append(
            f"\t{r['key']} = {{\n\t\tPivot = Vector3.new({x}, 0, {pivot}),\n\t\tPlatformRadius = {radius},\n\t\tQueueHead = Vector3.new({x}, 0, {head}),\n\t\tQueueDirection = Vector3.new(0, 0, 1),\n\t}},\n"
        )
    return "".join(out)


def branch_text(zone):
    b = zone["boundary"]
    rows = {"A": b - 18, "B": b - 133}
    return "".join(f"\t{r['key']} = {rows[rw]},\n" for r, (x, rw) in zip(zone["rides"], POS))


# ----------------------------------------------------------------------------------------------------------------
# Mesh generator functions (14 OBJs)
# ----------------------------------------------------------------------------------------------------------------
GEN = '''def make_camel_hub() -> Mesh:
    """Rotating sandstone deck: a pale disc ringed with gold, a carved obelisk in the middle, and a pedestal per basket."""
    mesh = Mesh("ParkParkCamelHub")
    add_vertical_cylinder(mesh, 8.2, 0.0, 0.6, "faded_cream", 44)
    add_vertical_cylinder(mesh, 8.25, 0.0, 0.45, "gold", 44)
    add_torus(mesh, 8.0, 0.14, 0.62, "coral", segments=44, sides=6)
    for index in range(10):
        angle = TAU * index / 10 + 0.2
        add_ellipsoid(mesh, (7.0 * math.cos(angle), 0.68, 7.0 * math.sin(angle)), (0.3, 0.1, 0.3), "gold", slices=6, stacks=3)
    lathe(mesh, [(1.5, 0.6, "cream"), (1.1, 1.0, "cream"), (0.9, 6.0, "faded_cream"), (0.0, 7.4, "gold")], 4)
    add_box(mesh, (0, 3.4, 0), (1.9, 0.3, 1.9), "coral")
    for index in range(6):
        angle = TAU * index / 6
        x, z = 5.4 * math.cos(angle), 5.4 * math.sin(angle)
        add_cylinder_between(mesh, (0, 0.9, 0), (x, 0.9, z), 0.16, 0.16, "cream", 8)
        add_vertical_cylinder(mesh, 1.4, 0.6, 0.9, "gold", 24, x, z)
    return mesh


def make_dune_pod() -> Mesh:
    """A woven basket seat (base at y=0): sand-coloured wicker with gold bands and a seat on top at about y=1.72."""
    mesh = Mesh("ParkParkDunePod")
    lathe(mesh, [(0.0, 0.0, "faded_cream"), (0.8, 0.0, "faded_cream"), (1.0, 0.7, "cream"), (0.95, 1.3, "cream"), (0.0, 1.6, "faded_cream")], 14)
    for y, radius in ((0.3, 0.9), (0.9, 1.0), (1.4, 0.93)):
        add_torus(mesh, radius, 0.06, y, "gold", segments=18, sides=5)
    add_box(mesh, (0, 1.72, -0.2), (0.9, 0.14, 1.0), "coral")
    for side in (-1, 1):
        add_cylinder_between(mesh, (side * 0.5, 1.75, 0.35), (side * 0.5, 2.3, 0.7), 0.05, 0.05, "gold", 5)
    add_cylinder_between(mesh, (0, 0.0, 0.0), (0, 0.5, 0.0), 0.09, 0.09, "gold", 6)
    return mesh


def make_dune_mound() -> Mesh:
    """A sand dune (origin at the ground centre): a rounded golden dune with ripples, a little palm and a flag."""
    mesh = Mesh("ParkParkDuneMound")
    add_vertical_cylinder(mesh, 6.8, 0.0, 0.9, "faded_cream", 36)
    lathe(mesh, [(6.6, 0.9, "cream"), (5.2, 1.3, "faded_cream"), (3.0, 1.55, "cream"), (0.0, 1.6, "faded_cream")], 28)
    for radius in (2.4, 3.8, 5.2):
        add_torus(mesh, radius, 0.07, 1.5, "faded_cream", segments=30, sides=4)
    add_cylinder_between(mesh, (4.6, 1.5, 3.4), (4.9, 5.2, 3.4), 0.2, 0.14, "wood", 6)
    for index in range(6):
        angle = TAU * index / 6
        add_cylinder_between(mesh, (4.9, 5.2, 3.4), (4.9 + 1.4 * math.cos(angle), 4.5, 3.4 + 1.4 * math.sin(angle)), 0.1, 0.03, "mint", 5)
    for index in range(6):
        angle = TAU * index / 6 + 0.4
        add_ellipsoid(mesh, (6.3 * math.cos(angle), 1.1, 6.3 * math.sin(angle)), (0.8, 0.6, 0.8), "faded_cream" if index % 2 else "gold", slices=7, stacks=4)
    return mesh


def make_pyramid() -> Mesh:
    """A desert pyramid (origin at the ground centre, door and ramp on the +Z side): sandstone sides, a gold cap and torches."""
    mesh = Mesh("ParkParkPyramid")
    lathe(mesh, [(7.2, 0.0, "cream"), (5.2, 3.2, "faded_cream"), (3.2, 6.2, "cream"), (1.0, 8.6, "faded_cream"), (0.0, 9.6, "gold")], 4)
    add_box(mesh, (0, 1.6, 4.9), (3.0, 3.2, 0.5), "ink")
    for index in range(4):
        add_box(mesh, (0, 0.2 + index * 0.4, 6.4 - index * 0.35), (3.4, 0.4, 1.0), "faded_cream")
    for side in (-1, 1):
        add_cylinder_between(mesh, (side * 2.4, 0.0, 6.2), (side * 2.4, 3.0, 6.2), 0.12, 0.12, "wood", 6)
        add_ellipsoid(mesh, (side * 2.4, 3.3, 6.2), (0.3, 0.45, 0.3), "coral", slices=6, stacks=4)
    return mesh


def make_shop_oasis() -> Mesh:
    """Oasis cafe stall: cream walls, a coral-and-gold awning, a palm and a water jar on the roof."""
    mesh = Mesh("ParkParkShopOasis")
    shop_base(mesh, "cream", "coral", "gold")
    add_cylinder_between(mesh, (-1.8, 5.0, 0), (-1.5, 7.6, 0), 0.2, 0.14, "wood", 6)
    for index in range(6):
        angle = TAU * index / 6
        add_cylinder_between(mesh, (-1.5, 7.6, 0), (-1.5 + 1.5 * math.cos(angle), 6.9, 1.5 * math.sin(angle)), 0.1, 0.03, "mint", 5)
    lathe(mesh, [(0.0, 5.0, "coral"), (0.8, 5.0, "coral"), (1.0, 5.9, "gold"), (0.6, 6.6, "gold"), (0.4, 6.9, "coral"), (0.0, 6.9, "coral")], 14)
    return mesh


def make_decor_cactus() -> Mesh:
    """A saguaro-style cactus (origin at the ground point): a ribbed trunk with two arms and a small flower."""
    mesh = Mesh("ParkParkDecorCactus")
    add_vertical_cylinder(mesh, 0.55, 0.0, 3.6, "mint", 10)
    add_ellipsoid(mesh, (0, 3.6, 0), (0.55, 0.45, 0.55), "mint", slices=8, stacks=4)
    for side, height in ((-1, 1.6), (1, 2.2)):
        add_cylinder_between(mesh, (0, height, 0), (side * 1.0, height, 0), 0.28, 0.28, "mint", 8)
        add_cylinder_between(mesh, (side * 1.0, height, 0), (side * 1.0, height + 1.1, 0), 0.28, 0.25, "mint", 8)
        add_ellipsoid(mesh, (side * 1.0, height + 1.15, 0), (0.28, 0.22, 0.28), "mint", slices=6, stacks=3)
    add_ellipsoid(mesh, (0, 4.05, 0), (0.22, 0.16, 0.22), "coral", slices=6, stacks=3)
    return mesh


def make_decor_obelisk() -> Mesh:
    """A small sandstone obelisk (origin at the ground point) with a gold tip."""
    mesh = Mesh("ParkParkDecorObelisk")
    add_box(mesh, (0, 0.3, 0), (1.8, 0.6, 1.8), "faded_cream")
    lathe(mesh, [(0.75, 0.6, "cream"), (0.55, 4.2, "cream"), (0.0, 5.0, "gold")], 4)
    return mesh


def make_nimbus_hub() -> Mesh:
    """Rotating cloud deck: a pale disc edged with puffs, a little rainbow arch in the middle, and a pedestal per cloud seat."""
    mesh = Mesh("ParkParkNimbusHub")
    add_vertical_cylinder(mesh, 8.2, 0.0, 0.6, "cream", 44)
    add_vertical_cylinder(mesh, 8.25, 0.0, 0.45, "faded_mint", 44)
    for index in range(14):
        angle = TAU * index / 14
        add_ellipsoid(mesh, (8.0 * math.cos(angle), 0.7, 8.0 * math.sin(angle)), (0.9, 0.55, 0.9), "cream", slices=8, stacks=5)
    for band, material in enumerate(("coral", "gold", "mint")):
        radius = 2.6 - band * 0.35
        for index in range(12):
            a0, a1 = math.pi * index / 12, math.pi * (index + 1) / 12
            add_cylinder_between(mesh, (radius * math.cos(a0), 0.6 + radius * math.sin(a0), 0), (radius * math.cos(a1), 0.6 + radius * math.sin(a1), 0), 0.17, 0.17, material, 6)
    for index in range(6):
        angle = TAU * index / 6 + TAU / 12
        x, z = 5.4 * math.cos(angle), 5.4 * math.sin(angle)
        add_cylinder_between(mesh, (0, 0.9, 0), (x, 0.9, z), 0.14, 0.14, "faded_mint", 8)
        add_vertical_cylinder(mesh, 1.4, 0.6, 0.9, "cream", 24, x, z)
    return mesh


def make_cloud_pod() -> Mesh:
    """A cloud seat (base at y=0): three white puffs under a seat on top at about y=1.72."""
    mesh = Mesh("ParkParkCloudPod")
    add_ellipsoid(mesh, (0, 0.8, 0), (0.9, 0.7, 0.9), "cream", slices=12, stacks=6)
    add_ellipsoid(mesh, (0.6, 0.7, 0.2), (0.55, 0.5, 0.55), "cream", slices=10, stacks=5)
    add_ellipsoid(mesh, (-0.6, 0.7, -0.2), (0.55, 0.5, 0.55), "cream", slices=10, stacks=5)
    add_box(mesh, (0, 1.72, -0.2), (0.9, 0.14, 1.0), "coral")
    for side in (-1, 1):
        add_cylinder_between(mesh, (side * 0.5, 1.75, 0.35), (side * 0.5, 2.3, 0.7), 0.05, 0.05, "gold", 5)
    add_cylinder_between(mesh, (0, 0.0, 0.0), (0, 0.5, 0.0), 0.09, 0.09, "gold", 6)
    return mesh


def make_rainbow_mound() -> Mesh:
    """A bouncy rainbow pad (origin at the ground centre): concentric colour bands over a soft cloud base."""
    mesh = Mesh("ParkParkRainbowMound")
    add_vertical_cylinder(mesh, 6.8, 0.0, 0.9, "cream", 36)
    lathe(mesh, [(6.6, 0.9, "coral"), (5.7, 1.2, "gold"), (4.6, 1.45, "mint"), (3.4, 1.55, "faded_mint"), (2.2, 1.6, "cream"), (0.0, 1.6, "cream")], 32)
    for index in range(8):
        angle = TAU * index / 8 + 0.2
        add_ellipsoid(mesh, (6.4 * math.cos(angle), 1.1, 6.4 * math.sin(angle)), (0.9, 0.6, 0.9), "cream", slices=8, stacks=4)
    return mesh


def make_sky_castle() -> Mesh:
    """A castle on a cloud (origin at the ground centre, gate on the +Z side): cream walls, four coral towers and a gold flag."""
    mesh = Mesh("ParkParkSkyCastle")
    add_ellipsoid(mesh, (0, 0.8, 0), (7.2, 1.0, 6.4), "cream", slices=16, stacks=5)
    add_box(mesh, (0, 3.2, 0), (9.0, 4.4, 7.0), "cream")
    add_box(mesh, (0, 5.7, 0), (9.4, 0.6, 7.4), "faded_mint")
    for sx in (-1, 1):
        for sz in (-1, 1):
            add_vertical_cylinder(mesh, 1.1, 1.0, 6.4, "faded_cream", 14, sx * 4.5, sz * 3.5)
            lathe(mesh, [(1.5, 6.4, "coral"), (0.0, 9.0, "coral")], 14) if False else None
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * 4.5, sz * 3.5
            add_cylinder_between(mesh, (x, 6.4, z), (x, 9.0, z), 1.5, 0.05, "coral", 14)
    add_box(mesh, (0, 2.2, 3.55), (2.4, 3.2, 0.3), "ink")
    add_cylinder_between(mesh, (0, 6.0, 0), (0, 9.8, 0), 0.08, 0.08, "wood", 6)
    add_box(mesh, (0.8, 9.4, 0), (1.6, 0.9, 0.06), "gold")
    return mesh


def make_shop_cotton() -> Mesh:
    """Cotton-candy stall: mint walls, a coral-and-cream awning, and a giant cotton-candy cloud on a cone on the roof."""
    mesh = Mesh("ParkParkShopCotton")
    shop_base(mesh, "mint", "coral", "cream")
    lathe(mesh, [(0.0, 5.0, "cream"), (0.9, 6.4, "cream"), (0.0, 6.5, "cream")], 10)
    add_ellipsoid(mesh, (0, 7.5, 0), (1.5, 1.2, 1.5), "coral", slices=10, stacks=6)
    add_ellipsoid(mesh, (0.9, 7.2, 0.3), (0.9, 0.8, 0.9), "faded_cream", slices=8, stacks=5)
    add_ellipsoid(mesh, (-0.9, 7.1, -0.2), (0.9, 0.8, 0.9), "faded_cream", slices=8, stacks=5)
    return mesh


def make_decor_cloud() -> Mesh:
    """A little cloud on a stand (origin at the ground point): four puffs on a thin post."""
    mesh = Mesh("ParkParkDecorCloud")
    add_vertical_cylinder(mesh, 0.15, 0.0, 2.6, "faded_mint", 8)
    for x, y, z, r in ((0, 3.4, 0, 1.2), (1.0, 3.2, 0.2, 0.85), (-1.0, 3.2, -0.2, 0.85), (0.2, 3.9, 0.3, 0.75)):
        add_ellipsoid(mesh, (x, y, z), (r, r * 0.75, r), "cream", slices=10, stacks=6)
    return mesh


def make_decor_rainbow() -> Mesh:
    """A small rainbow arch on two posts (origin at the ground point, facing +Z)."""
    mesh = Mesh("ParkParkDecorRainbow")
    for band, material in enumerate(("coral", "gold", "mint", "faded_mint")):
        radius = 2.8 - band * 0.4
        for index in range(14):
            a0, a1 = math.pi * index / 14, math.pi * (index + 1) / 14
            add_cylinder_between(mesh, (radius * math.cos(a0), 0.2 + radius * math.sin(a0), 0), (radius * math.cos(a1), 0.2 + radius * math.sin(a1), 0), 0.22, 0.22, material, 6)
    for side in (-1, 1):
        add_ellipsoid(mesh, (side * 2.6, 0.5, 0.0), (0.7, 0.5, 0.7), "cream", slices=8, stacks=4)
    return mesh


'''
import re
GEN = re.sub(r"\n[^\n]*if False else None", "", GEN)

# ----------------------------------------------------------------------------------------------------------------
# Template builders (generic ones, written once)
# ----------------------------------------------------------------------------------------------------------------
TPL_GENERIC = '''def build_spinner_zone_ride(template: str, hub_obj: str, pod_obj: str, scale: float, column_h: float = 6.0, column_d: float = 2.0) -> None:
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


'''


def edit(path, fn):
    raw = open(path, encoding="utf-8", newline="").read()
    crlf = "\r\n" in raw
    s = fn(raw.replace("\r\n", "\n"))
    open(path, "w", encoding="utf-8", newline="").write(s.replace("\n", "\r\n") if crlf else s)


def rep(s, a, b):
    assert a in s, a[:80]
    return s.replace(a, b, 1)


MESH_ORDER = ["make_camel_hub", "make_dune_pod", "make_dune_mound", "make_pyramid", "make_shop_oasis", "make_decor_cactus", "make_decor_obelisk",
              "make_nimbus_hub", "make_cloud_pod", "make_rainbow_mound", "make_sky_castle", "make_shop_cotton", "make_decor_cloud", "make_decor_rainbow"]
edit("tools/generate_parkpark_meshes.py", lambda s: rep(rep(s, "def make_litter() -> Mesh:", GEN + "def make_litter() -> Mesh:"), "        make_decor_totem(),\n", "        make_decor_totem(),\n" + "".join(f"        {n}(),\n" for n in MESH_ORDER)))


def tpl(s):
    s = rep(s, 'TOTEM_SCALE = config_number("TotemScale")\n', 'TOTEM_SCALE = config_number("TotemScale")\n' + "".join(f'{n.upper()} = config_number("{n}")\n' for n in ["CamelScale", "DuneScale", "PyramidScale", "CactusScale", "ObeliskScale", "NimbusScale", "RainbowScale", "CastleScale", "CloudScale", "RainbowArchScale"]))
    s = rep(s, "    build_temple()\n", "    build_temple()\n"
            "    build_spinner_zone_ride(\"CamelRide\", \"ParkParkCamelHub\", \"ParkParkDunePod\", CAMELSCALE, 7.4, 2.0)\n"
            "    build_bounce_zone_ride(\"DuneRide\", \"ParkParkDuneMound\", DUNESCALE)\n"
            "    build_hidden_zone_ride(\"PyramidRide\", \"ParkParkPyramid\", PYRAMIDSCALE, (14.4, 9.6, 14.4))\n"
            "    build_spinner_zone_ride(\"NimbusRide\", \"ParkParkNimbusHub\", \"ParkParkCloudPod\", NIMBUSSCALE, 3.0, 5.0)\n"
            "    build_bounce_zone_ride(\"RainbowRide\", \"ParkParkRainbowMound\", RAINBOWSCALE)\n"
            "    build_hidden_zone_ride(\"CastleRide\", \"ParkParkSkyCastle\", CASTLESCALE, (9.4, 9.8, 7.4))\n")
    s = s.replace("CAMELSCALE", "CAMELSCALE_").replace("CAMELSCALE_", "CAMELSCALE")
    s = rep(s, '("JuiceShop", "ParkParkShopJuice")', '("JuiceShop", "ParkParkShopJuice"), ("OasisShop", "ParkParkShopOasis"), ("CottonShop", "ParkParkShopCotton")')
    s = rep(s, "def build_stage() -> None:", TPL_GENERIC + "def build_stage() -> None:")
    s = rep(s, '        ("DecorPine", "ParkParkDecorPine"', '        ("DecorCactus", "ParkParkDecorCactus", CACTUSSCALE, cylinder_collider("Collider", (0, 1.8, 0), 3.6, 1.2, CACTUSSCALE)),\n        ("DecorObelisk", "ParkParkDecorObelisk", OBELISKSCALE, box_collider("Collider", (0, 2.5, 0), (1.8, 5.0, 1.8), 0, OBELISKSCALE)),\n        ("DecorCloud", "ParkParkDecorCloud", CLOUDSCALE, cylinder_collider("Collider", (0, 1.3, 0), 2.6, 0.5, CLOUDSCALE)),\n        ("DecorRainbow", "ParkParkDecorRainbow", RAINBOWARCHSCALE, None),\n        ("DecorPine", "ParkParkDecorPine"')
    # constants are written as <NAME>SCALE below
    return s


edit("tools/build_parkpark_templates.py", tpl)
# fix constant names: the loop above created e.g. CAMELSCALE_ONLY names from "CamelScale".upper() = "CAMELSCALE"
print("templates ok")

# ----------------------------------------------------------------------------------------------------------------
# Config, layout, extras, decor, gather, services, bootstrap
# ----------------------------------------------------------------------------------------------------------------
RIDES = ""
prev = "Juice"
for zone in ZONES:
    prev = zone["requires"]
    for index, r in enumerate(zone["rides"]):
        RIDES += ride_text(zone, prev, index, r)
        prev = r["key"]

EXTRAS = "".join(extra_text(r) for z in ZONES for r in z["rides"])
LAYOUTS = "".join(layout_text(z) for z in ZONES)
BRANCH = "".join(branch_text(z) for z in ZONES)
CHAIN = "".join(f'\t\t"{r["key"]}",\n' for z in ZONES for r in z["rides"])
THRILL = "".join(f'\t\t"{r["key"]}",\n' for z in ZONES for r in z["rides"] if r["thrill"])
SCALES = "\tCamelScale = 2.4,\n\tDuneScale = 2.4,\n\tPyramidScale = 2.2,\n\tCactusScale = 2,\n\tObeliskScale = 2,\n\tNimbusScale = 2.4,\n\tRainbowScale = 2.4,\n\tCastleScale = 2.2,\n\tCloudScale = 2,\n\tRainbowArchScale = 2,\n"


def cfg(s):
    s = rep(s, "\t\tNoodle = {\n", RIDES + "\t\tNoodle = {\n")
    s = rep(s, '\t\t"Juice",\n\t},', '\t\t"Juice",\n' + CHAIN + "\t},")
    s = rep(s, "\tTotemScale = 2,\n", "\tTotemScale = 2,\n" + SCALES)
    s = rep(s, '"Candy", "Jungle" } :: { string }', '"Candy", "Jungle", "Desert", "Cloud" } :: { string }')
    s = rep(s, "\t\tJungle = 760000,\n", "\t\tJungle = 760000,\n" + "".join(f"\t\t{z['key']} = {z['gate']},\n" for z in ZONES))
    s = rep(s, '\t\tJungle = "정글 구역",\n', '\t\tJungle = "정글 구역",\n' + "".join(f'\t\t{z["key"]} = "{z["name"]}",\n' for z in ZONES))
    s = rep(s, '\t\tJungle = "Sweets",\n', '\t\tJungle = "Sweets",\n' + "".join(f'\t\t{z["key"]} = "{z["requires"]}",\n' for z in ZONES))
    s = rep(s, '\t\tJungle = { Color = Color3.fromRGB(88, 140, 84), Material = "Grass" },\n', '\t\tJungle = { Color = Color3.fromRGB(88, 140, 84), Material = "Grass" },\n' + "".join(f'\t\t{z["key"]} = {{ Color = {z["ground"][0]}, Material = "{z["ground"][1]}" }},\n' for z in ZONES))
    s = rep(s, '\t\t"Coconut",\n\t\t"Temple",\n\t} :: { string },', '\t\t"Coconut",\n\t\t"Temple",\n' + THRILL + "\t} :: { string },")
    return s


edit("src/shared/Config/GameConfig.luau", cfg)
edit("src/shared/Config/ExtraRides.luau", lambda s: rep(s, "\tCocoa = {\n", EXTRAS + "\tCocoa = {\n"))


def lay(s):
    s = rep(s, "\tJuice = -2112,\n", "\tJuice = -2112,\n" + BRANCH)
    s = rep(s, "\tJungle = { BoundaryZ = -1979, MinZ = -2242 },\n", "\tJungle = { BoundaryZ = -1979, MinZ = -2242 },\n" + "".join(f"\t{z['key']} = {{ BoundaryZ = {z['boundary']}, MinZ = {z['minz']} }},\n" for z in ZONES))
    s = rep(s, "\tFerris = {\n\t\tPivot = FERRIS_PIVOT,", LAYOUTS + "\tFerris = {\n\t\tPivot = FERRIS_PIVOT,")
    return s


edit("src/shared/Config/ParkLayout.luau", lay)


def decor(s):
    s = rep(s, "\tlocal jungle = ParkLayout.ZoneBounds.Jungle\n", "".join(f"\tlocal {z['key'].lower()} = ParkLayout.ZoneBounds.{z['key']}\n\ttable.insert(zoneRects, {{ roadX - roadHalf, roadX + roadHalf, {z['key'].lower()}.MinZ, {z['key'].lower()}.BoundaryZ }})\n" for z in ZONES) + "\tlocal jungle = ParkLayout.ZoneBounds.Jungle\n")
    block = ""
    for z in ZONES:
        v = z["key"].lower()
        props = "".join(f'\t\t{{ kind = "{k}", count = {c}, margin = {m}, radius = {r} }},\n' for k, _, _, c, m, r in z["decor"])
        block += (f"\t-- The {z['name']}: scenery with lamps along its road.\n"
                  f"\tlocal {v}Props: {{ {{ kind: string, count: number, margin: number, radius: number }} }} = {{\n{props}\t}}\n"
                  f"\tfor _, prop in {v}Props do\n\t\tlocal made = 0\n\t\tlocal tries = 0\n\t\twhile made < prop.count and tries < 3000 do\n\t\t\ttries += 1\n"
                  f"\t\t\tlocal x = random:NextNumber(-WORLD_X, WORLD_X)\n\t\t\tlocal z = random:NextNumber({v}.MinZ + 6, {v}.BoundaryZ - 8)\n"
                  f"\t\t\tif not zoneBlocked(x, z, prop.margin) and clear(x, z, prop.radius) then\n\t\t\t\tplace(prop.kind, Vector3.new(x, 0, z), random:NextNumber(0, math.pi * 2), prop.radius)\n\t\t\t\tmade += 1\n\t\t\tend\n\t\tend\n\tend\n"
                  f"\tfor z = {v}.BoundaryZ - 16, {v}.MinZ + 12, -24 do\n\t\tfor _, side in {{ -1, 1 }} do\n\t\t\tlocal spot = Vector3.new(roadX + side * (roadHalf + 5.5), 0, z)\n"
                  f"\t\t\tif not zoneBlocked(spot.X, spot.Z, 0) and clear(spot.X, spot.Z, 1.5) then\n\t\t\t\tplace(\"DecorLamp\", spot, 0, 1.5)\n\t\t\tend\n\t\tend\n\tend\n\n")
    s = rep(s, "\t-- The jungle: ferns,", block + "\t-- The jungle: ferns,")
    s = rep(s, '\telseif kind == "DecorFern" then', '\telseif kind == "DecorCactus" then\n\t\tpart("Cactus", Vector3.new(2.2, 7.2, 2.2), Vector3.new(0, 3.6, 0), Color3.fromRGB(96, 170, 120), nil).CanCollide = true\n\telseif kind == "DecorObelisk" then\n\t\tpart("Obelisk", Vector3.new(1.8, 9, 1.8), Vector3.new(0, 4.5, 0), Color3.fromRGB(226, 205, 160), nil).CanCollide = true\n\telseif kind == "DecorCloud" then\n\t\tpart("Cloud", Vector3.new(5, 3.4, 4), Vector3.new(0, 7, 0), Color3.fromRGB(246, 248, 252), Enum.PartType.Ball)\n\telseif kind == "DecorRainbow" then\n\t\tpart("Arch", Vector3.new(6, 3, 0.8), Vector3.new(0, 4, 0), Color3.fromRGB(244, 150, 130), nil)\n\telseif kind == "DecorFern" then')
    s = rep(s, "\t\tDecorFern = true,\n", "\t\tDecorFern = true,\n\t\tDecorCactus = true,\n\t\tDecorCloud = true,\n")
    return s


edit("src/server/Services/DecorService.luau", decor)
edit("src/server/Services/GatherService.luau", lambda s: rep(s, '\t\tJungle = { "바나나", Color3.fromRGB(255, 224, 90) },\n', '\t\tJungle = { "바나나", Color3.fromRGB(255, 224, 90) },\n' + "".join(f'\t\t{z["key"]} = {{ "{z["gather"][0]}", {z["gather"][1]} }},\n' for z in ZONES)))


def ambience(name, zone_key, slab, y, color_a, color_b, rate, speed, light, tex, size, direction):
    return f'''--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- Ambient particles over the {zone_key} zone: an invisible slab with a soft emitter.
local {name} = {{}}

function {name}.Start(park: {{ ParkFolder: Folder }})
	local zone = ParkLayout.ZoneBounds.{zone_key}
	local depth = zone.BoundaryZ - zone.MinZ
	local slab = Instance.new("Part")
	slab.Name = "{slab}"
	slab.Size = Vector3.new(ParkLayout.GroundHalfWidth * 2, 1, depth)
	slab.Position = Vector3.new(0, {y}, (zone.BoundaryZ + zone.MinZ) / 2)
	slab.Anchored = true
	slab.CanCollide = false
	slab.CanQuery = false
	slab.CanTouch = false
	slab.Transparency = 1
	slab.Parent = park.ParkFolder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "{tex}"
	emitter.Color = ColorSequence.new({color_a}, {color_b})
	emitter.Size = NumberSequence.new({size})
	emitter.Lifetime = NumberRange.new(8, 12)
	emitter.Rate = {rate}
	emitter.Speed = NumberRange.new({speed})
	emitter.EmissionDirection = Enum.NormalId.{direction}
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.LightEmission = {light}
	emitter.Parent = slab
end

return {name}
'''


open("src/server/Services/DesertService.luau", "w", encoding="utf-8", newline="").write(
    ambience("DesertService", "Desert", "SandDust", 4, "Color3.fromRGB(235, 205, 150)", "Color3.fromRGB(250, 230, 190)", 40, "3, 5", 0.1, "rbxasset://textures/particles/smoke_main.dds", 9, "Right"))
open("src/server/Services/CloudService.luau", "w", encoding="utf-8", newline="").write(
    ambience("CloudService", "Cloud", "CloudWisps", 5, "Color3.fromRGB(255, 255, 255)", "Color3.fromRGB(215, 232, 255)", 14, "1, 2", 0.3, "rbxasset://textures/particles/smoke_main.dds", 14, "Top"))


def boot(s):
    s = rep(s, "local jungleService = require(script.Parent.Services.JungleService)\n", "local jungleService = require(script.Parent.Services.JungleService)\nlocal desertService = require(script.Parent.Services.DesertService)\nlocal cloudService = require(script.Parent.Services.CloudService)\n")
    return rep(s, "jungleService.Start(park)\n", "jungleService.Start(park)\ndesertService.Start(park)\ncloudService.Start(park)\n")


edit("src/server/Bootstrap.server.luau", boot)
print("ok")

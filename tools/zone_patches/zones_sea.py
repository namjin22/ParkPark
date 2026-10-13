import os

os.chdir(r"C:\Users\User\Desktop\Project\parkpark")

# ----------------------------------------------------------------------------------------------------------------
# The undersea zone (해저 구역, key Sea), built like zones2.py: config, layout, extras, decor, ambience, meshes.
# Every file is transformed in memory first and written only when all anchors were found.
# ----------------------------------------------------------------------------------------------------------------
ZONE = {
    "key": "Sea", "name": "해저 구역", "gate": 950000, "ground": ("Color3.fromRGB(176, 214, 222)", "Sand"),
    "requires": "Cotton", "boundary": -2768, "minz": -3031, "gather": ("진주", "Color3.fromRGB(240, 236, 244)"),
    "rides": [
        dict(key="Seahorse", disp="해마 회전", model="SeahorseRide", kind="Spinner", fare=4700, total=630000, thrill=True, scale="SeahorseScale", scale_v="2.4"),
        dict(key="Jelly", disp="해파리 점프", model="JellyRide", kind="Bounce", fare=4900, total=640000, thrill=False, scale="JellyScale", scale_v="2.4"),
        dict(key="Aquarium", disp="수족관 터널 투어", model="AquariumRide", kind="Hidden", fare=5100, total=650000, thrill=True, scale="AquariumScale", scale_v="2.2"),
        dict(key="BubbleTea", disp="버블티 가게", model="BubbleTeaShop", kind="Shop", fare=4800, total=660000, thrill=False, scale="", scale_v=""),
    ],
    "decor": [("DecorCoral", "CoralScale", "2", 26, 5, 3), ("DecorSeaweed", "SeaweedScale", "2", 30, 4, 2), ("DecorRock", None, None, 16, 6, 4), ("DecorBush", None, None, 20, 4, 2.5)],
}
POS = [(-60, "A"), (150, "A"), (-60, "B"), (110, "B")]


def ride_text(zone, prev_key, r):
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
    base = [f"\t{k} = {{", f"\t\tKind = \"{r['kind']}\",", f"\t\tTemplate = GameConfig.Rides.{k}.ModelName,"]
    base.append("\t\tScale = GameConfig.ShopScale," if r["kind"] == "Shop" else f"\t\tScale = GameConfig.{r['scale']},")
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


GEN = '''def make_seahorse_hub() -> Mesh:
    """Rotating reef deck: a pale disc edged with coral lumps, a tall coral column in the middle, a pedestal per seat."""
    mesh = Mesh("ParkParkSeahorseHub")
    add_vertical_cylinder(mesh, 8.2, 0.0, 0.6, "cream", 44)
    add_vertical_cylinder(mesh, 8.25, 0.0, 0.45, "faded_mint", 44)
    for index in range(14):
        angle = TAU * index / 14
        add_ellipsoid(mesh, (8.0 * math.cos(angle), 0.7, 8.0 * math.sin(angle)), (0.7, 0.6, 0.7), "coral" if index % 2 == 0 else "gold", slices=8, stacks=5)
    lathe(mesh, [(1.6, 0.6, "coral"), (1.1, 1.4, "coral"), (0.8, 6.0, "faded_mint"), (0.0, 7.4, "gold")], 12)
    for index in range(5):
        angle = TAU * index / 5
        add_cylinder_between(mesh, (0.5 * math.cos(angle), 2.2, 0.5 * math.sin(angle)), (1.6 * math.cos(angle), 4.4, 1.6 * math.sin(angle)), 0.3, 0.12, "coral", 8)
    for index in range(6):
        angle = TAU * index / 6
        x, z = 5.4 * math.cos(angle), 5.4 * math.sin(angle)
        add_cylinder_between(mesh, (0, 0.9, 0), (x, 0.9, z), 0.16, 0.16, "cream", 8)
        add_vertical_cylinder(mesh, 1.4, 0.6, 0.9, "gold", 24, x, z)
    return mesh


def make_bubble_pod() -> Mesh:
    """A bubble seat (base at y=0): a ring of small bubbles under a seat on top at about y=1.72."""
    mesh = Mesh("ParkParkBubblePod")
    lathe(mesh, [(0.0, 0.0, "faded_mint"), (0.8, 0.0, "faded_mint"), (1.0, 0.7, "mint"), (0.95, 1.3, "mint"), (0.0, 1.6, "faded_mint")], 14)
    for index in range(6):
        angle = TAU * index / 6
        add_ellipsoid(mesh, (0.95 * math.cos(angle), 0.8, 0.95 * math.sin(angle)), (0.32, 0.32, 0.32), "cream", slices=8, stacks=5)
    add_box(mesh, (0, 1.72, -0.2), (0.9, 0.14, 1.0), "coral")
    for side in (-1, 1):
        add_cylinder_between(mesh, (side * 0.5, 1.75, 0.35), (side * 0.5, 2.3, 0.7), 0.05, 0.05, "gold", 5)
    add_cylinder_between(mesh, (0, 0.0, 0.0), (0, 0.5, 0.0), 0.09, 0.09, "gold", 6)
    return mesh


def make_jelly_mound() -> Mesh:
    """A bouncy jellyfish pad (origin at the ground centre): a wobbly coral dome on a pale base with trailing strands."""
    mesh = Mesh("ParkParkJellyMound")
    add_vertical_cylinder(mesh, 6.8, 0.0, 0.9, "cream", 36)
    lathe(mesh, [(6.6, 0.9, "coral"), (5.7, 1.2, "faded_coral"), (4.6, 1.45, "coral"), (3.4, 1.55, "faded_coral"), (2.2, 1.6, "coral"), (0.0, 1.6, "coral")], 32)
    for index in range(10):
        angle = TAU * index / 10 + 0.2
        x, z = 6.5 * math.cos(angle), 6.5 * math.sin(angle)
        add_cylinder_between(mesh, (x, 0.9, z), (x * 1.05, 0.1, z * 1.05), 0.2, 0.08, "mint", 6)
        add_ellipsoid(mesh, (x, 1.0, z), (0.5, 0.35, 0.5), "gold", slices=8, stacks=4)
    return mesh


def make_aquarium_tunnel() -> Mesh:
    """An aquarium: a glass dome over a pale base with a back wall and a sign arch (origin at the ground centre, entrance on +Z)."""
    mesh = Mesh("ParkParkAquariumTunnel")
    add_box(mesh, (0, 0.25, 0), (14.4, 0.5, 12.4), "cream")
    add_box(mesh, (0, 3.0, -5.7), (14.0, 5.0, 0.6), "mint")
    for side in (-1, 1):
        add_box(mesh, (side * 6.9, 2.8, 0.0), (0.5, 4.6, 11.0), "dark_glass")
    add_ellipsoid(mesh, (0, 5.0, -0.2), (7.2, 2.6, 6.0), "dark_glass", slices=18, stacks=8)
    for x, y, z, material in ((-3.0, 3.2, 1.0, "coral"), (2.5, 3.8, -1.5, "gold"), (-1.0, 4.6, -2.5, "coral"), (4.0, 2.8, 2.0, "gold")):
        add_ellipsoid(mesh, (x, y, z), (0.9, 0.4, 0.3), material, slices=8, stacks=4)
        add_box(mesh, (x - 1.0, y, z), (0.3, 0.5, 0.1), material)
    for side in (-1, 1):
        add_vertical_cylinder(mesh, 0.35, 0.5, 6.2, "gold", 10, side * 3.2, 5.7)
    add_box(mesh, (0, 6.6, 5.7), (7.4, 1.2, 0.4), "coral")
    add_box(mesh, (0, 2.0, 5.9), (0.1, 0.1, 0.1), "ink")
    return mesh


def make_shop_bubble_tea() -> Mesh:
    """Bubble-tea stall: mint walls, a coral-and-cream awning, and a big cup with a straw on the roof."""
    mesh = Mesh("ParkParkShopBubbleTea")
    shop_base(mesh, "mint", "coral", "cream")
    add_cylinder_between(mesh, (0, 5.0, 0), (0, 7.4, 0), 0.9, 1.4, "cream", 16)
    add_vertical_cylinder(mesh, 1.5, 7.4, 7.7, "coral", 16)
    add_cylinder_between(mesh, (0.4, 7.7, 0), (0.9, 9.4, 0), 0.12, 0.12, "gold", 6)
    for index in range(5):
        angle = TAU * index / 5
        add_ellipsoid(mesh, (0.45 * math.cos(angle), 5.45, 0.45 * math.sin(angle)), (0.3, 0.3, 0.3), "ink", slices=6, stacks=4)
    return mesh


def make_decor_coral() -> Mesh:
    """A coral cluster (origin at the ground point): five branching arms on a low mound."""
    mesh = Mesh("ParkParkDecorCoral")
    add_ellipsoid(mesh, (0, 0.2, 0), (1.3, 0.45, 1.3), "faded_cream", slices=10, stacks=4)
    for index in range(5):
        angle = TAU * index / 5
        tip = (0.9 * math.cos(angle), 2.8 + 0.4 * (index % 2), 0.9 * math.sin(angle))
        add_cylinder_between(mesh, (0.2 * math.cos(angle), 0.3, 0.2 * math.sin(angle)), tip, 0.34, 0.14, "coral" if index % 2 == 0 else "gold", 8)
        add_ellipsoid(mesh, tip, (0.22, 0.22, 0.22), "coral", slices=6, stacks=4)
    return mesh


def make_decor_seaweed() -> Mesh:
    """Swaying seaweed (origin at the ground point): five thin strands bent in three pieces."""
    mesh = Mesh("ParkParkDecorSeaweed")
    for index in range(5):
        angle = TAU * index / 5
        bx, bz = 0.5 * math.cos(angle), 0.5 * math.sin(angle)
        points = [(bx, 0.0, bz), (bx + 0.2, 1.0, bz), (bx - 0.15, 2.0, bz + 0.1), (bx + 0.1, 3.0, bz)]
        for start, end in zip(points, points[1:]):
            add_cylinder_between(mesh, start, end, 0.1, 0.08, "mint" if index % 2 == 0 else "faded_mint", 5)
    return mesh


'''

AMBIENCE = '''--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- Ambient particles over the Sea zone: slow bubbles rising from an invisible slab.
local SeaService = {}

function SeaService.Start(park: { ParkFolder: Folder })
	local zone = ParkLayout.ZoneBounds.Sea
	local depth = zone.BoundaryZ - zone.MinZ
	local slab = Instance.new("Part")
	slab.Name = "SeaBubbles"
	slab.Size = Vector3.new(ParkLayout.GroundHalfWidth * 2, 1, depth)
	slab.Position = Vector3.new(0, 2, (zone.BoundaryZ + zone.MinZ) / 2)
	slab.Anchored = true
	slab.CanCollide = false
	slab.CanQuery = false
	slab.CanTouch = false
	slab.Transparency = 1
	slab.Parent = park.ParkFolder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(215, 240, 250), Color3.fromRGB(180, 225, 240))
	emitter.Size = NumberSequence.new(3)
	emitter.Lifetime = NumberRange.new(8, 12)
	emitter.Rate = 30
	emitter.Speed = NumberRange.new(2, 4)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.LightEmission = 0.2
	emitter.Transparency = NumberSequence.new(0.5)
	emitter.Parent = slab
end

return SeaService
'''


def rep(s, a, b, tag=""):
    assert a in s, f"anchor missing {tag}: {a[:80]!r}"
    return s.replace(a, b, 1)


files = {}


def load(path):
    if path not in files:
        raw = open(path, encoding="utf-8", newline="").read()
        files[path] = ("\r\n" in raw, raw.replace("\r\n", "\n"))
    return files[path][1]


def put(path, text):
    crlf = files[path][0]
    files[path] = (crlf, text)


# generator
s = load("tools/generate_parkpark_meshes.py")
s = rep(s, "def make_litter() -> Mesh:", GEN + "def make_litter() -> Mesh:")
MESHES = ["make_seahorse_hub", "make_bubble_pod", "make_jelly_mound", "make_aquarium_tunnel", "make_shop_bubble_tea", "make_decor_coral", "make_decor_seaweed"]
s = rep(s, "        make_decor_rainbow(),\n", "        make_decor_rainbow(),\n" + "".join(f"        {n}(),\n" for n in MESHES))
put("tools/generate_parkpark_meshes.py", s)

# templates
s = load("tools/build_parkpark_templates.py")
s = rep(s, 'RAINBOWARCHSCALE = config_number("RainbowArchScale")\n',
        'RAINBOWARCHSCALE = config_number("RainbowArchScale")\n' + "".join(f'{n.upper()} = config_number("{n}")\n' for n in ["SeahorseScale", "JellyScale", "AquariumScale", "CoralScale", "SeaweedScale"]))
s = rep(s, '    build_hidden_zone_ride("CastleRide", "ParkParkSkyCastle", CASTLESCALE, (9.4, 9.8, 7.4))\n',
        '    build_hidden_zone_ride("CastleRide", "ParkParkSkyCastle", CASTLESCALE, (9.4, 9.8, 7.4))\n'
        '    build_spinner_zone_ride("SeahorseRide", "ParkParkSeahorseHub", "ParkParkBubblePod", SEAHORSESCALE, 7.4, 2.0)\n'
        '    build_bounce_zone_ride("JellyRide", "ParkParkJellyMound", JELLYSCALE)\n'
        '    build_hidden_zone_ride("AquariumRide", "ParkParkAquariumTunnel", AQUARIUMSCALE, (14.4, 7.4, 12.4))\n')
s = rep(s, '("CottonShop", "ParkParkShopCotton")', '("CottonShop", "ParkParkShopCotton"), ("BubbleTeaShop", "ParkParkShopBubbleTea")')
s = rep(s, '        ("DecorPine", "ParkParkDecorPine"',
        '        ("DecorCoral", "ParkParkDecorCoral", CORALSCALE, cylinder_collider("Collider", (0, 1.8, 0), 3.6, 1.6, CORALSCALE)),\n'
        '        ("DecorSeaweed", "ParkParkDecorSeaweed", SEAWEEDSCALE, None),\n'
        '        ("DecorPine", "ParkParkDecorPine"')
put("tools/build_parkpark_templates.py", s)

# game config
rides = ""
prev = ZONE["requires"]
for r in ZONE["rides"]:
    rides += ride_text(ZONE, prev, r)
    prev = r["key"]
chain = "".join(f'\t\t"{r["key"]}",\n' for r in ZONE["rides"])
thrill = "".join(f'\t\t"{r["key"]}",\n' for r in ZONE["rides"] if r["thrill"])
scales = "\tSeahorseScale = 2.4,\n\tJellyScale = 2.4,\n\tAquariumScale = 2.2,\n\tCoralScale = 2,\n\tSeaweedScale = 2,\n"
s = load("src/shared/Config/GameConfig.luau")
s = rep(s, "\t\tNoodle = {\n", rides + "\t\tNoodle = {\n", "rides")
s = rep(s, '\t\t"Castle",\n\t\t"Cotton",\n\t},\n', '\t\t"Castle",\n\t\t"Cotton",\n' + chain + "\t},\n", "chain")
s = rep(s, '"Desert", "Cloud" } :: { string },', '"Desert", "Cloud", "Sea" } :: { string },', "zoneorder")
s = rep(s, "\t\tCloud = 880000,\n", "\t\tCloud = 880000,\n" + f"\t\tSea = {ZONE['gate']},\n", "costs")
s = rep(s, '\t\tCloud = "구름 구역",\n', '\t\tCloud = "구름 구역",\n' + f'\t\tSea = "{ZONE["name"]}",\n', "names")
s = rep(s, '\t\tCloud = "Oasis",\n', '\t\tCloud = "Oasis",\n' + f'\t\tSea = "{ZONE["requires"]}",\n', "requires")
s = rep(s, '\t\tCloud = { Color = Color3.fromRGB(238, 243, 250), Material = "Snow" },\n',
        '\t\tCloud = { Color = Color3.fromRGB(238, 243, 250), Material = "Snow" },\n'
        + f'\t\tSea = {{ Color = {ZONE["ground"][0]}, Material = "{ZONE["ground"][1]}" }},\n', "ground")
s = rep(s, '\t\t"Nimbus",\n\t\t"Castle",\n\t} :: { string },', '\t\t"Nimbus",\n\t\t"Castle",\n' + thrill + "\t} :: { string },", "thrill")
s = rep(s, "\tRainbowArchScale = 2,\n", "\tRainbowArchScale = 2,\n" + scales, "scales")
s = rep(s, '\t\t"Desert",\n\t\t"Cloud",\n\t} :: { string },\n\tGatherKinds = {', '\t\t"Desert",\n\t\t"Cloud",\n\t\t"Sea",\n\t} :: { string },\n\tGatherKinds = {', "gatherorder")
s = rep(s, '\t\tCloud = { Label = "구름 조각", Color = Color3.fromRGB(190, 215, 255) },\n',
        '\t\tCloud = { Label = "구름 조각", Color = Color3.fromRGB(190, 215, 255) },\n'
        + f'\t\tSea = {{ Label = "{ZONE["gather"][0]}", Color = {ZONE["gather"][1]} }},\n', "gather")
put("src/shared/Config/GameConfig.luau", s)

s = load("src/shared/Config/ExtraRides.luau")
s = rep(s, "\tMaze = {\n", "".join(extra_text(r) for r in ZONE["rides"]) + "\tMaze = {\n", "extras")
put("src/shared/Config/ExtraRides.luau", s)

s = load("src/shared/Config/ParkLayout.luau")
s = rep(s, "\tJuice = -2112,\n", "\tJuice = -2112,\n" + branch_text(ZONE), "branch")
s = rep(s, "\tCloud = { BoundaryZ = -2505, MinZ = -2768 },\n",
        "\tCloud = { BoundaryZ = -2505, MinZ = -2768 },\n" + f"\tSea = {{ BoundaryZ = {ZONE['boundary']}, MinZ = {ZONE['minz']} }},\n", "bounds")
s = rep(s, "\tFerris = {\n\t\tPivot = FERRIS_PIVOT,", layout_text(ZONE) + "\tFerris = {\n\t\tPivot = FERRIS_PIVOT,", "layout")
put("src/shared/Config/ParkLayout.luau", s)

# decor
v = ZONE["key"].lower()
props = "".join(f'\t\t{{ kind = "{k}", count = {c}, margin = {m}, radius = {r} }},\n' for k, _, _, c, m, r in ZONE["decor"])
block = (
    f"\t-- The {ZONE['name']}: scenery with lamps along its road.\n"
    f"\tlocal {v}Props: {{ {{ kind: string, count: number, margin: number, radius: number }} }} = {{\n{props}\t}}\n"
    f"\tfor _, prop in {v}Props do\n\t\tlocal made = 0\n\t\tlocal tries = 0\n\t\twhile made < prop.count and tries < 3000 do\n\t\t\ttries += 1\n"
    f"\t\t\tlocal x = random:NextNumber(-WORLD_X, WORLD_X)\n\t\t\tlocal z = random:NextNumber({v}.MinZ + 6, {v}.BoundaryZ - 8)\n"
    f"\t\t\tif not zoneBlocked(x, z, prop.margin) and clear(x, z, prop.radius) then\n\t\t\t\tplace(prop.kind, Vector3.new(x, 0, z), random:NextNumber(0, math.pi * 2), prop.radius)\n\t\t\t\tmade += 1\n\t\t\tend\n\t\tend\n\tend\n"
    f"\tfor z = {v}.BoundaryZ - 16, {v}.MinZ + 12, -24 do\n\t\tfor _, side in {{ -1, 1 }} do\n\t\t\tlocal spot = Vector3.new(roadX + side * (roadHalf + 5.5), 0, z)\n"
    f"\t\t\tif not zoneBlocked(spot.X, spot.Z, 0) and clear(spot.X, spot.Z, 1.5) then\n\t\t\t\tplace(\"DecorLamp\", spot, 0, 1.5)\n\t\t\tend\n\t\tend\n\tend\n\n"
)
s = load("src/server/Services/DecorService.luau")
s = rep(s, "\tlocal jungle = ParkLayout.ZoneBounds.Jungle\n",
        f"\tlocal {v} = ParkLayout.ZoneBounds.{ZONE['key']}\n\ttable.insert(zoneRects, {{ roadX - roadHalf, roadX + roadHalf, {v}.MinZ, {v}.BoundaryZ }})\n"
        "\tlocal jungle = ParkLayout.ZoneBounds.Jungle\n", "decor-rects")
s = rep(s, "\t-- The jungle: ferns,", block + "\t-- The jungle: ferns,", "decor-block")
s = rep(s, '\telseif kind == "DecorFern" then',
        '\telseif kind == "DecorCoral" then\n\t\tpart("Coral", Vector3.new(3, 3.6, 3), Vector3.new(0, 1.8, 0), Color3.fromRGB(240, 130, 120), nil).CanCollide = true\n'
        '\telseif kind == "DecorSeaweed" then\n\t\tpart("Seaweed", Vector3.new(0.8, 3, 0.8), Vector3.new(0, 1.5, 0), Color3.fromRGB(90, 170, 120), nil)\n'
        '\telseif kind == "DecorFern" then', "decor-kinds")
s = rep(s, "\t\tDecorFern = true,\n", "\t\tDecorFern = true,\n\t\tDecorCoral = true,\n\t\tDecorSeaweed = true,\n", "decor-natural")
put("src/server/Services/DecorService.luau", s)

# bootstrap
s = load("src/server/Bootstrap.server.luau")
s = rep(s, "local cloudService = require(script.Parent.Services.CloudService)\n", "local cloudService = require(script.Parent.Services.CloudService)\nlocal seaService = require(script.Parent.Services.SeaService)\n", "req")
s = rep(s, "cloudService.Start(park)\n", "cloudService.Start(park)\nseaService.Start(park)\n", "start")
put("src/server/Bootstrap.server.luau", s)

# everything matched: write
for path, (crlf, text) in files.items():
    open(path, "w", encoding="utf-8", newline="").write(text.replace("\n", "\r\n") if crlf else text)
open("src/server/Services/SeaService.luau", "w", encoding="utf-8", newline="").write(AMBIENCE)
print("ok", len(files), "files")

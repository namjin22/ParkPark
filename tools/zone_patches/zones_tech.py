import os

os.chdir(r"C:\Users\User\Desktop\Project\parkpark")

# ----------------------------------------------------------------------------------------------------------------
# The undersea zone (해저 구역, key Sea), built like zones2.py: config, layout, extras, decor, ambience, meshes.
# Every file is transformed in memory first and written only when all anchors were found.
# ----------------------------------------------------------------------------------------------------------------
ZONE = {
    "key": "Tech", "name": "로봇 도시", "gate": 1030000, "ground": ("Color3.fromRGB(96, 104, 122)", "Concrete"),
    "requires": "BubbleTea", "boundary": -3031, "minz": -3294, "gather": ("나사", "Color3.fromRGB(196, 206, 218)"),
    "rides": [
        dict(key="Robot", disp="로봇 회전", model="RobotRide", kind="Spinner", fare=5000, total=670000, thrill=True, scale="RobotScale", scale_v="2.4"),
        dict(key="Neon", disp="네온 점프", model="NeonRide", kind="Bounce", fare=5200, total=680000, thrill=False, scale="NeonScale", scale_v="2.4"),
        dict(key="TechFactory", disp="로봇 공장 투어", model="TechFactoryRide", kind="Hidden", fare=5400, total=690000, thrill=True, scale="TechFactoryScale", scale_v="2.2"),
        dict(key="Ramen", disp="라멘 가게", model="RamenShop", kind="Shop", fare=5100, total=700000, thrill=False, scale="", scale_v=""),
    ],
    "decor": [("DecorNeonSign", "NeonSignScale", "2", 22, 5, 2.5), ("DecorAntenna", "AntennaScale", "2", 18, 6, 2), ("DecorRock", None, None, 14, 6, 4), ("DecorBush", None, None, 16, 4, 2.5)],
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


GEN = '''def make_robot_hub() -> Mesh:
    """Rotating robot deck: a dark disc with neon bands, an antenna column in the middle, a pedestal per seat."""
    mesh = Mesh("ParkParkRobotHub")
    add_vertical_cylinder(mesh, 8.2, 0.0, 0.6, "dark_glass", 44)
    add_vertical_cylinder(mesh, 8.25, 0.0, 0.45, "ink", 44)
    add_torus(mesh, 7.8, 0.14, 0.64, "mint", segments=44, sides=6)
    add_torus(mesh, 4.0, 0.1, 0.62, "coral", segments=36, sides=6)
    lathe(mesh, [(1.4, 0.6, "ink"), (1.0, 1.4, "dark_glass"), (0.5, 6.0, "faded_mint"), (0.0, 7.6, "coral")], 10)
    for y, material in ((2.4, "mint"), (3.6, "gold"), (4.8, "mint")):
        add_torus(mesh, 0.85, 0.09, y, material, segments=16, sides=5)
    for index in range(6):
        angle = TAU * index / 6
        x, z = 5.4 * math.cos(angle), 5.4 * math.sin(angle)
        add_cylinder_between(mesh, (0, 0.9, 0), (x, 0.9, z), 0.16, 0.16, "faded_mint", 8)
        add_vertical_cylinder(mesh, 1.4, 0.6, 0.9, "mint", 24, x, z)
    return mesh


def make_gear_pod() -> Mesh:
    """A gear seat (base at y=0): a toothed disc under a seat on top at about y=1.72."""
    mesh = Mesh("ParkParkGearPod")
    add_vertical_cylinder(mesh, 0.85, 0.0, 0.5, "gold", 16)
    for index in range(8):
        angle = TAU * index / 8
        add_box(mesh, (0.95 * math.cos(angle), 0.25, 0.95 * math.sin(angle)), (0.32, 0.5, 0.32), "gold")
    lathe(mesh, [(0.5, 0.5, "faded_mint"), (0.7, 1.0, "mint"), (0.6, 1.5, "mint"), (0.0, 1.62, "faded_mint")], 12)
    add_box(mesh, (0, 1.72, -0.2), (0.9, 0.14, 1.0), "coral")
    for side in (-1, 1):
        add_cylinder_between(mesh, (side * 0.5, 1.75, 0.35), (side * 0.5, 2.3, 0.7), 0.05, 0.05, "gold", 5)
    return mesh


def make_neon_mound() -> Mesh:
    """A neon bounce pad (origin at the ground centre): a dark grid dome ringed with glowing bands."""
    mesh = Mesh("ParkParkNeonMound")
    add_vertical_cylinder(mesh, 6.8, 0.0, 0.9, "ink", 36)
    lathe(mesh, [(6.6, 0.9, "dark_glass"), (5.7, 1.2, "ink"), (4.6, 1.45, "dark_glass"), (3.4, 1.55, "ink"), (2.2, 1.6, "dark_glass"), (0.0, 1.6, "dark_glass")], 32)
    for radius, y, material in ((6.4, 1.0, "mint"), (4.8, 1.38, "coral"), (3.0, 1.58, "mint")):
        add_torus(mesh, radius, 0.1, y, material, segments=40, sides=6)
    for index in range(8):
        angle = TAU * index / 8 + 0.2
        add_cylinder_between(mesh, (1.2 * math.cos(angle), 1.62, 1.2 * math.sin(angle)), (6.2 * math.cos(angle), 1.12, 6.2 * math.sin(angle)), 0.07, 0.07, "gold", 5)
    return mesh


def make_robot_factory() -> Mesh:
    """A small robot factory (origin at the ground centre, entrance on +Z): a mint hall with chimneys and a conveyor."""
    mesh = Mesh("ParkParkRobotFactory")
    add_box(mesh, (0, 0.25, 0), (13.4, 0.5, 11.4), "faded_cream")
    add_box(mesh, (0, 3.3, -0.6), (12.6, 5.6, 9.4), "mint")
    add_box(mesh, (0, 6.3, -0.6), (13.0, 0.6, 9.8), "dark_glass")
    for x in (-4.0, 4.0):
        add_vertical_cylinder(mesh, 0.7, 6.6, 9.8, "ink", 12, x, -3.0)
        add_ellipsoid(mesh, (x, 10.2, -3.0), (0.9, 0.5, 0.9), "faded_cream", slices=8, stacks=4)
    add_box(mesh, (0, 2.0, 4.1), (3.0, 3.6, 0.3), "ink")
    add_box(mesh, (0, 0.8, 5.0), (9.0, 0.4, 1.2), "ink")
    for index in range(5):
        add_box(mesh, (-3.2 + index * 1.6, 1.15, 5.0), (0.7, 0.7, 0.7), "gold")
    add_box(mesh, (0, 5.2, 4.9), (7.0, 1.0, 0.3), "coral")
    return mesh


def make_shop_ramen() -> Mesh:
    """Ramen stall: coral walls, a mint-and-cream awning, and a big bowl with noodles and chopsticks on the roof."""
    mesh = Mesh("ParkParkShopRamen")
    shop_base(mesh, "coral", "mint", "cream")
    add_cylinder_between(mesh, (0, 5.0, 0), (0, 6.4, 0), 0.7, 1.7, "cream", 16)
    add_ellipsoid(mesh, (0, 6.5, 0), (1.5, 0.45, 1.5), "gold", slices=12, stacks=4)
    for side in (-1, 1):
        add_cylinder_between(mesh, (side * 0.35, 6.7, 0), (side * 0.8 + 0.9, 8.4, 0.2), 0.07, 0.07, "wood", 5)
    return mesh


def make_decor_neon_sign() -> Mesh:
    """A neon sign (origin at the ground point): a post carrying a dark panel with two glowing bars."""
    mesh = Mesh("ParkParkDecorNeonSign")
    add_vertical_cylinder(mesh, 0.15, 0.0, 3.6, "faded_mint", 8)
    add_box(mesh, (0, 4.2, 0), (2.6, 1.4, 0.2), "ink")
    add_box(mesh, (0, 4.45, 0.14), (2.0, 0.22, 0.12), "mint")
    add_box(mesh, (0, 3.95, 0.14), (1.4, 0.22, 0.12), "coral")
    return mesh


def make_decor_antenna() -> Mesh:
    """An antenna tower (origin at the ground point): a thin tapering mast with rungs, a dish and a red tip."""
    mesh = Mesh("ParkParkDecorAntenna")
    add_cylinder_between(mesh, (0, 0, 0), (0, 7.4, 0), 0.5, 0.1, "faded_mint", 8)
    for index in range(5):
        y = 1.0 + index * 1.3
        add_box(mesh, (0, y, 0), (1.0 - index * 0.14, 0.1, 0.1), "cream")
    add_ellipsoid(mesh, (0.5, 6.6, 0), (0.6, 0.18, 0.6), "cream", slices=10, stacks=4)
    add_ellipsoid(mesh, (0, 7.7, 0), (0.18, 0.18, 0.18), "coral", slices=6, stacks=4)
    return mesh


'''

AMBIENCE = '''--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local ParkLayout = require(Config:WaitForChild("ParkLayout"))

-- Ambient particles over the Tech zone: slow neon motes rising from an invisible slab.
local TechService = {}

function TechService.Start(park: { ParkFolder: Folder })
	local zone = ParkLayout.ZoneBounds.Tech
	local depth = zone.BoundaryZ - zone.MinZ
	local slab = Instance.new("Part")
	slab.Name = "TechMotes"
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
	emitter.Color = ColorSequence.new(Color3.fromRGB(120, 230, 255), Color3.fromRGB(255, 130, 200))
	emitter.Size = NumberSequence.new(1.6)
	emitter.Lifetime = NumberRange.new(8, 12)
	emitter.Rate = 18
	emitter.Speed = NumberRange.new(2, 4)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.LightEmission = 0.8
	emitter.Transparency = NumberSequence.new(0.5)
	emitter.Parent = slab
end

return TechService
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
MESHES = ["make_robot_hub", "make_gear_pod", "make_neon_mound", "make_robot_factory", "make_shop_ramen", "make_decor_neon_sign", "make_decor_antenna"]
s = rep(s, "        make_decor_seaweed(),\n", "        make_decor_seaweed(),\n" + "".join(f"        {n}(),\n" for n in MESHES))
put("tools/generate_parkpark_meshes.py", s)

# templates
s = load("tools/build_parkpark_templates.py")
s = rep(s, 'SEAWEEDSCALE = config_number("SeaweedScale")\n',
        'SEAWEEDSCALE = config_number("SeaweedScale")\n' + "".join(f'{n.upper()} = config_number("{n}")\n' for n in ["RobotScale", "NeonScale", "TechFactoryScale", "NeonSignScale", "AntennaScale"]))
s = rep(s, '    build_hidden_zone_ride("AquariumRide", "ParkParkAquariumTunnel", AQUARIUMSCALE, (14.4, 7.4, 12.4))\n',
        '    build_hidden_zone_ride("AquariumRide", "ParkParkAquariumTunnel", AQUARIUMSCALE, (14.4, 7.4, 12.4))\n'
        '    build_spinner_zone_ride("RobotRide", "ParkParkRobotHub", "ParkParkGearPod", ROBOTSCALE, 7.4, 2.0)\n'
        '    build_bounce_zone_ride("NeonRide", "ParkParkNeonMound", NEONSCALE)\n'
        '    build_hidden_zone_ride("TechFactoryRide", "ParkParkRobotFactory", TECHFACTORYSCALE, (13.4, 7.4, 11.4))\n')
s = rep(s, '("BubbleTeaShop", "ParkParkShopBubbleTea")', '("BubbleTeaShop", "ParkParkShopBubbleTea"), ("RamenShop", "ParkParkShopRamen")')
s = rep(s, '        ("DecorPine", "ParkParkDecorPine"',
        '        ("DecorNeonSign", "ParkParkDecorNeonSign", NEONSIGNSCALE, box_collider("Collider", (0, 2.5, 0), (2.6, 5.0, 0.5), 0, NEONSIGNSCALE)),\n'
        '        ("DecorAntenna", "ParkParkDecorAntenna", ANTENNASCALE, cylinder_collider("Collider", (0, 4.0, 0), 8.0, 0.9, ANTENNASCALE)),\n'
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
scales = "\tRobotScale = 2.4,\n\tNeonScale = 2.4,\n\tTechFactoryScale = 2.2,\n\tNeonSignScale = 2,\n\tAntennaScale = 2,\n"
s = load("src/shared/Config/GameConfig.luau")
s = rep(s, "\t\tNoodle = {\n", rides + "\t\tNoodle = {\n", "rides")
s = rep(s, '\t\t"Aquarium",\n\t\t"BubbleTea",\n\t},\n', '\t\t"Aquarium",\n\t\t"BubbleTea",\n' + chain + "\t},\n", "chain")
s = rep(s, '"Cloud", "Sea" } :: { string },', '"Cloud", "Sea", "Tech" } :: { string },', "zoneorder")
s = rep(s, "\t\tSea = 950000,\n", "\t\tSea = 950000,\n" + f"\t\tTech = {ZONE['gate']},\n", "costs")
s = rep(s, '\t\tSea = "해저 구역",\n', '\t\tSea = "해저 구역",\n' + f'\t\tTech = "{ZONE["name"]}",\n', "names")
s = rep(s, '\t\tSea = "Cotton",\n', '\t\tSea = "Cotton",\n' + f'\t\tTech = "{ZONE["requires"]}",\n', "requires")
s = rep(s, '\t\tSea = { Color = Color3.fromRGB(176, 214, 222), Material = "Sand" },\n',
        '\t\tSea = { Color = Color3.fromRGB(176, 214, 222), Material = "Sand" },\n'
        + f'\t\tTech = {{ Color = {ZONE["ground"][0]}, Material = "{ZONE["ground"][1]}" }},\n', "ground")
s = rep(s, '\t\t"Seahorse",\n\t\t"Aquarium",\n\t} :: { string },', '\t\t"Seahorse",\n\t\t"Aquarium",\n' + thrill + "\t} :: { string },", "thrill")
s = rep(s, "\tSeaweedScale = 2,\n", "\tSeaweedScale = 2,\n" + scales, "scales")
s = rep(s, '\t\t"Cloud",\n\t\t"Sea",\n\t} :: { string },\n\tGatherKinds = {', '\t\t"Cloud",\n\t\t"Sea",\n\t\t"Tech",\n\t} :: { string },\n\tGatherKinds = {', "gatherorder")
s = rep(s, '\t\tSea = { Label = "진주", Color = Color3.fromRGB(240, 236, 244) },\n',
        '\t\tSea = { Label = "진주", Color = Color3.fromRGB(240, 236, 244) },\n'
        + f'\t\tTech = {{ Label = "{ZONE["gather"][0]}", Color = {ZONE["gather"][1]} }},\n', "gather")
put("src/shared/Config/GameConfig.luau", s)

s = load("src/shared/Config/ExtraRides.luau")
s = rep(s, "\tMaze = {\n", "".join(extra_text(r) for r in ZONE["rides"]) + "\tMaze = {\n", "extras")
put("src/shared/Config/ExtraRides.luau", s)

s = load("src/shared/Config/ParkLayout.luau")
s = rep(s, "\tJuice = -2112,\n", "\tJuice = -2112,\n" + branch_text(ZONE), "branch")
s = rep(s, "\tSea = { BoundaryZ = -2768, MinZ = -3031 },\n",
        "\tSea = { BoundaryZ = -2768, MinZ = -3031 },\n" + f"\tTech = {{ BoundaryZ = {ZONE['boundary']}, MinZ = {ZONE['minz']} }},\n", "bounds")
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
        '\telseif kind == "DecorNeonSign" then\n\t\tpart("Sign", Vector3.new(2.6, 1.4, 0.3), Vector3.new(0, 4.2, 0), Color3.fromRGB(40, 46, 60), nil).CanCollide = true\n'
        '\telseif kind == "DecorAntenna" then\n\t\tpart("Mast", Vector3.new(0.8, 8, 0.8), Vector3.new(0, 4, 0), Color3.fromRGB(150, 180, 170), nil).CanCollide = true\n'
        '\telseif kind == "DecorFern" then', "decor-kinds")
put("src/server/Services/DecorService.luau", s)

# bootstrap
s = load("src/server/Bootstrap.server.luau")
s = rep(s, "local seaService = require(script.Parent.Services.SeaService)\n", "local seaService = require(script.Parent.Services.SeaService)\nlocal techService = require(script.Parent.Services.TechService)\n", "req")
s = rep(s, "seaService.Start(park)\n", "seaService.Start(park)\ntechService.Start(park)\n", "start")
put("src/server/Bootstrap.server.luau", s)

# everything matched: write
for path, (crlf, text) in files.items():
    open(path, "w", encoding="utf-8", newline="").write(text.replace("\n", "\r\n") if crlf else text)
open("src/server/Services/TechService.luau", "w", encoding="utf-8", newline="").write(AMBIENCE)
print("ok", len(files), "files")

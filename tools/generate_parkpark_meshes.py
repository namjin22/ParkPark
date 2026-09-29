"""Generate editable OBJ sources for ParkPark's first custom fairground models.

The output is geometry source, not a Rojo instance. Import the OBJ/MTL files in
Roblox Studio, review the meshes, and save approved models before wiring them
into the place. The script uses only Python's standard library.
"""

from __future__ import annotations

import math
import struct
import zlib
from collections import defaultdict
from pathlib import Path
from typing import Callable


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "models" / "parkpark"
TAU = math.pi * 2

MATERIALS = {
    "cream": (0.96, 0.85, 0.67),
    "coral": (0.91, 0.36, 0.32),
    "mint": (0.33, 0.65, 0.53),
    "gold": (0.92, 0.67, 0.27),
    "wood": (0.38, 0.22, 0.14),
    "ink": (0.12, 0.16, 0.17),
    "faded_cream": (0.65, 0.59, 0.48),
    "faded_coral": (0.53, 0.31, 0.29),
    "faded_mint": (0.33, 0.43, 0.38),
    "dark_glass": (0.20, 0.29, 0.29),
}

# One flat color cell per material in ParkParkPalette.png; faces sample the cell center.
PALETTE_CELL = 32
PALETTE_INDEX = {name: index for index, name in enumerate(MATERIALS)}
PALETTE_UVS = {name: ((index + 0.5) / len(MATERIALS), 0.5) for name, index in PALETTE_INDEX.items()}


class Mesh:
    def __init__(self, name: str) -> None:
        self.name = name
        self.vertices: list[tuple[float, float, float]] = []
        self.faces: dict[str, list[tuple[int, ...]]] = defaultdict(list)

    def vertex(self, point: tuple[float, float, float]) -> int:
        self.vertices.append(point)
        return len(self.vertices)

    def face(self, material: str, *indices: int) -> None:
        self.faces[material].append(tuple(indices))

    def triangle(self, material: str, a: int, b: int, c: int) -> None:
        self.face(material, a, b, c)

    def validate(self) -> None:
        if not self.vertices or not self.faces:
            raise ValueError(f"{self.name} has no geometry")
        for material, faces in self.faces.items():
            if material not in MATERIALS:
                raise ValueError(f"{self.name} uses undefined material {material!r}")
            for face in faces:
                if len(face) < 3 or any(index < 1 or index > len(self.vertices) for index in face):
                    raise ValueError(f"{self.name} contains an invalid face: {face}")

    def orient_outward(self) -> int:
        """Wind every connected part counter-clockwise from outside, as Roblox renders front faces.

        The primitive helpers emit mixed windings, which Studio showed as inside-out parts.
        Parts are joined through shared positions, and a part with a negative signed volume
        about its own centroid has all of its faces reversed. Returns the number of flipped parts.
        """
        weld: dict[tuple[int, int, int], int] = {}
        position_id = [
            weld.setdefault(tuple(round(c * 1000) for c in vertex), len(weld)) for vertex in self.vertices
        ]
        parent = list(range(len(weld)))

        def find(item: int) -> int:
            while parent[item] != item:
                parent[item] = parent[parent[item]]
                item = parent[item]
            return item

        all_faces = [(material, index) for material, faces in self.faces.items() for index in range(len(faces))]
        for material, index in all_faces:
            face = self.faces[material][index]
            for a, b in zip(face, face[1:]):
                root_a, root_b = find(position_id[a - 1]), find(position_id[b - 1])
                if root_a != root_b:
                    parent[root_a] = root_b

        parts: dict[int, list[tuple[str, int]]] = defaultdict(list)
        for material, index in all_faces:
            parts[find(position_id[self.faces[material][index][0] - 1])].append((material, index))

        flipped = 0
        for members in parts.values():
            used = {vertex for material, index in members for vertex in self.faces[material][index]}
            centroid = tuple(sum(self.vertices[v - 1][axis] for v in used) / len(used) for axis in range(3))
            volume = 0.0
            for material, index in members:
                points = [
                    tuple(self.vertices[v - 1][axis] - centroid[axis] for axis in range(3))
                    for v in self.faces[material][index]
                ]
                for k in range(1, len(points) - 1):
                    a, b, c = points[0], points[k], points[k + 1]
                    volume += (
                        a[0] * (b[1] * c[2] - b[2] * c[1])
                        + a[1] * (b[2] * c[0] - b[0] * c[2])
                        + a[2] * (b[0] * c[1] - b[1] * c[0])
                    )
            if volume < 0:
                flipped += 1
                for material, index in members:
                    self.faces[material][index] = tuple(reversed(self.faces[material][index]))
        return flipped

    def write(self, path: Path) -> tuple[int, int, tuple[float, float, float], tuple[float, float, float]]:
        self.validate()
        self.orient_outward()
        with path.open("w", encoding="utf-8", newline="\n") as output:
            output.write(f"# {self.name} — ParkPark original fairground mesh\n")
            output.write("mtllib ParkParkFairground.mtl\n")
            output.write(f"o {self.name}\n")
            for x, y, z in self.vertices:
                output.write(f"v {x:.5f} {y:.5f} {z:.5f}\n")
            # Studio's OBJ import ignores MTL colors, so every face also samples its palette cell.
            for u, v in PALETTE_UVS.values():
                output.write(f"vt {u:.5f} {v:.5f}\n")
            for material, faces in self.faces.items():
                texture_index = PALETTE_INDEX[material] + 1
                output.write(f"usemtl {material}\n")
                for face in faces:
                    output.write("f " + " ".join(f"{index}/{texture_index}" for index in face) + "\n")
        triangles = sum(max(1, len(face) - 2) for faces in self.faces.values() for face in faces)
        minimum = tuple(min(vertex[axis] for vertex in self.vertices) for axis in range(3))
        maximum = tuple(max(vertex[axis] for vertex in self.vertices) for axis in range(3))
        if triangles > 20_000:
            raise ValueError(f"{self.name} exceeds Roblox's 20,000-triangle mesh budget")
        return len(self.vertices), triangles, minimum, maximum


PointTransform = Callable[[float, float, float], tuple[float, float, float]]


def identity(x: float, y: float, z: float) -> tuple[float, float, float]:
    return x, y, z


def radial_transform(angle: float, origin: tuple[float, float, float]) -> PointTransform:
    cosine = math.cos(angle)
    sine = math.sin(angle)

    def transform(x: float, y: float, z: float) -> tuple[float, float, float]:
        return origin[0] + x * cosine - z * sine, origin[1] + y, origin[2] + x * sine + z * cosine

    return transform


def add_box(
    mesh: Mesh,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    material: str,
    transform: PointTransform = identity,
) -> None:
    cx, cy, cz = center
    sx, sy, sz = (dimension * 0.5 for dimension in size)
    points = [
        (cx - sx, cy - sy, cz - sz),
        (cx + sx, cy - sy, cz - sz),
        (cx + sx, cy + sy, cz - sz),
        (cx - sx, cy + sy, cz - sz),
        (cx - sx, cy - sy, cz + sz),
        (cx + sx, cy - sy, cz + sz),
        (cx + sx, cy + sy, cz + sz),
        (cx - sx, cy + sy, cz + sz),
    ]
    ids = [mesh.vertex(transform(*point)) for point in points]
    for face in (
        (0, 3, 2, 1),
        (4, 5, 6, 7),
        (0, 4, 7, 3),
        (1, 2, 6, 5),
        (0, 1, 5, 4),
        (3, 7, 6, 2),
    ):
        mesh.face(material, *(ids[index] for index in face))


def add_cylinder_between(
    mesh: Mesh,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    radius_start: float,
    radius_end: float,
    material: str,
    segments: int = 10,
    transform: PointTransform = identity,
) -> None:
    direction = tuple(end[index] - start[index] for index in range(3))
    length = math.sqrt(sum(component * component for component in direction))
    axis = tuple(component / length for component in direction)
    guide = (0.0, 1.0, 0.0) if abs(axis[1]) < 0.92 else (1.0, 0.0, 0.0)
    u = (
        axis[1] * guide[2] - axis[2] * guide[1],
        axis[2] * guide[0] - axis[0] * guide[2],
        axis[0] * guide[1] - axis[1] * guide[0],
    )
    u_length = math.sqrt(sum(component * component for component in u))
    u = tuple(component / u_length for component in u)
    v = (
        axis[1] * u[2] - axis[2] * u[1],
        axis[2] * u[0] - axis[0] * u[2],
        axis[0] * u[1] - axis[1] * u[0],
    )

    rings: list[list[int]] = []
    for point, radius in ((start, radius_start), (end, radius_end)):
        ring = []
        for segment in range(segments):
            angle = TAU * segment / segments
            position = tuple(
                point[index] + radius * (u[index] * math.cos(angle) + v[index] * math.sin(angle))
                for index in range(3)
            )
            ring.append(mesh.vertex(transform(*position)))
        rings.append(ring)

    bottom_center = mesh.vertex(transform(*start))
    top_center = mesh.vertex(transform(*end))
    for segment in range(segments):
        following = (segment + 1) % segments
        mesh.face(material, rings[0][segment], rings[0][following], rings[1][following], rings[1][segment])
        mesh.triangle(material, bottom_center, rings[0][following], rings[0][segment])
        mesh.triangle(material, top_center, rings[1][segment], rings[1][following])


def add_vertical_cylinder(
    mesh: Mesh,
    radius: float,
    bottom: float,
    top: float,
    material: str,
    segments: int = 32,
    center_x: float = 0.0,
    center_z: float = 0.0,
) -> None:
    bottom_ring = []
    top_ring = []
    for segment in range(segments):
        angle = TAU * segment / segments
        x = center_x + radius * math.cos(angle)
        z = center_z + radius * math.sin(angle)
        bottom_ring.append(mesh.vertex((x, bottom, z)))
        top_ring.append(mesh.vertex((x, top, z)))
    bottom_center = mesh.vertex((center_x, bottom, center_z))
    top_center = mesh.vertex((center_x, top, center_z))
    for segment in range(segments):
        following = (segment + 1) % segments
        mesh.face(material, bottom_ring[segment], bottom_ring[following], top_ring[following], top_ring[segment])
        mesh.triangle(material, bottom_center, bottom_ring[following], bottom_ring[segment])
        mesh.triangle(material, top_center, top_ring[segment], top_ring[following])


def add_ellipsoid(
    mesh: Mesh,
    center: tuple[float, float, float],
    radii: tuple[float, float, float],
    material: str,
    transform: PointTransform = identity,
    slices: int = 10,
    stacks: int = 6,
) -> None:
    cx, cy, cz = center
    rx, ry, rz = radii
    rings: list[list[int]] = []
    for stack in range(1, stacks):
        latitude = -math.pi / 2 + math.pi * stack / stacks
        ring = []
        for slice_index in range(slices):
            longitude = TAU * slice_index / slices
            point = (
                cx + rx * math.cos(latitude) * math.cos(longitude),
                cy + ry * math.sin(latitude),
                cz + rz * math.cos(latitude) * math.sin(longitude),
            )
            ring.append(mesh.vertex(transform(*point)))
        rings.append(ring)

    bottom = mesh.vertex(transform(cx, cy - ry, cz))
    top = mesh.vertex(transform(cx, cy + ry, cz))
    first_ring, last_ring = rings[0], rings[-1]
    for slice_index in range(slices):
        following = (slice_index + 1) % slices
        mesh.triangle(material, bottom, first_ring[following], first_ring[slice_index])
        mesh.triangle(material, top, last_ring[slice_index], last_ring[following])
    for ring_index in range(len(rings) - 1):
        lower, upper = rings[ring_index], rings[ring_index + 1]
        for slice_index in range(slices):
            following = (slice_index + 1) % slices
            mesh.face(material, lower[slice_index], lower[following], upper[following], upper[slice_index])


def add_torus(
    mesh: Mesh,
    major_radius: float,
    minor_radius: float,
    y: float,
    material: str,
    segments: int = 48,
    sides: int = 8,
    start_angle: float = 0.0,
    end_angle: float = TAU,
    center_x: float = 0.0,
    center_z: float = 0.0,
) -> None:
    rings: list[list[int]] = []
    for segment in range(segments + (1 if end_angle != TAU else 0)):
        angle = start_angle + (end_angle - start_angle) * segment / segments
        ring = []
        for side in range(sides):
            tube_angle = TAU * side / sides
            ring_radius = major_radius + minor_radius * math.cos(tube_angle)
            ring_y = y + minor_radius * math.sin(tube_angle)
            ring.append(
                mesh.vertex(
                    (center_x + ring_radius * math.cos(angle), ring_y, center_z + ring_radius * math.sin(angle))
                )
            )
        rings.append(ring)
    for ring_index in range(len(rings) - 1 if end_angle != TAU else len(rings)):
        next_ring = (ring_index + 1) % len(rings)
        for side in range(sides):
            next_side = (side + 1) % sides
            mesh.face(
                material,
                rings[ring_index][side],
                rings[ring_index][next_side],
                rings[next_ring][next_side],
                rings[next_ring][side],
            )


def add_star(mesh: Mesh, center_y: float, radius: float, material: str) -> None:
    front_z, back_z = -0.12, 0.12
    points = []
    for index in range(10):
        angle = math.pi / 2 + index * math.pi / 5
        point_radius = radius if index % 2 == 0 else radius * 0.43
        points.append((point_radius * math.cos(angle), center_y + point_radius * math.sin(angle)))
    front = [mesh.vertex((x, y, front_z)) for x, y in points]
    back = [mesh.vertex((x, y, back_z)) for x, y in points]
    front_center = mesh.vertex((0, center_y, front_z))
    back_center = mesh.vertex((0, center_y, back_z))
    for index in range(10):
        following = (index + 1) % 10
        mesh.triangle(material, front_center, front[index], front[following])
        mesh.triangle(material, back_center, back[following], back[index])
        mesh.face(material, front[index], back[index], back[following], front[following])


def add_horse(mesh: Mesh, angle: float, orbit_radius: float, palette: str) -> None:
    origin = (orbit_radius * math.cos(angle), 0, orbit_radius * math.sin(angle))
    transform = radial_transform(angle, origin)
    add_ellipsoid(mesh, (0, 2.15, 0), (1.15, 0.63, 0.53), palette, transform)
    add_ellipsoid(mesh, (0.82, 2.46, 0), (0.42, 0.45, 0.38), "cream", transform, 8, 5)
    add_cylinder_between(mesh, (0.49, 2.28, 0), (0.83, 3.1, 0), 0.26, 0.16, palette, 8, transform)
    add_ellipsoid(mesh, (1.12, 2.67, 0), (0.46, 0.34, 0.31), palette, transform, 8, 5)
    add_ellipsoid(mesh, (1.48, 2.58, 0), (0.26, 0.2, 0.25), "cream", transform, 8, 4)
    add_ellipsoid(mesh, (0.78, 2.89, 0), (0.46, 0.13, 0.4), "coral", transform, 8, 4)
    add_cylinder_between(mesh, (0.5, 2.65, -0.24), (0.82, 2.91, -0.19), 0.08, 0.04, "wood", 6, transform)
    add_cylinder_between(mesh, (0.5, 2.65, 0.24), (0.82, 2.91, 0.19), 0.08, 0.04, "wood", 6, transform)
    for x in (-0.72, 0.65):
        for z in (-0.34, 0.34):
            add_cylinder_between(mesh, (x, 1.95, z), (x + 0.04, 0.93, z), 0.12, 0.07, palette, 7, transform)
    add_cylinder_between(mesh, (-1.03, 2.27, 0), (-1.42, 1.98, 0), 0.13, 0.06, "gold", 7, transform)
    add_ellipsoid(mesh, (0.18, 2.69, 0), (0.48, 0.2, 0.54), "wood", transform, 8, 4)


def make_platform() -> Mesh:
    mesh = Mesh("ParkParkCarouselPlatform")
    profile = [
        (0.0, 0.08, "wood"),
        (11.7, 0.08, "wood"),
        (12.0, 0.25, "cream"),
        (11.7, 0.48, "coral"),
        (10.9, 0.62, "cream"),
        (0.0, 0.62, "mint"),
    ]
    lathe(mesh, profile, 64)
    add_torus(mesh, 11.25, 0.13, 0.63, "gold")
    add_torus(mesh, 9.85, 0.07, 0.645, "coral")
    for segment in range(16):
        angle = TAU * segment / 16
        x, z = 10.7 * math.cos(angle), 10.7 * math.sin(angle)
        add_ellipsoid(mesh, (x, 0.66, z), (0.34, 0.11, 0.34), "cream" if segment % 2 else "coral", slices=8, stacks=4)
    return mesh


def lathe(mesh: Mesh, profile: list[tuple[float, float, str]], segments: int = 32) -> None:
    rings: list[list[int]] = []
    for radius, y, _ in profile:
        ring = []
        for segment in range(segments):
            angle = TAU * segment / segments
            ring.append(mesh.vertex((radius * math.cos(angle), y, radius * math.sin(angle))))
        rings.append(ring)
    for profile_index in range(len(profile) - 1):
        material = profile[profile_index + 1][2]
        for segment in range(segments):
            following = (segment + 1) % segments
            mesh.face(
                material,
                rings[profile_index][segment],
                rings[profile_index][following],
                rings[profile_index + 1][following],
                rings[profile_index + 1][segment],
            )


def make_rotor() -> Mesh:
    mesh = Mesh("ParkParkCarouselRotor")
    lathe(
        mesh,
        [
            (0.0, 0.5, "gold"),
            (0.88, 0.5, "coral"),
            (0.78, 0.9, "cream"),
            (0.62, 1.2, "gold"),
            (0.48, 3.0, "cream"),
            (0.6, 3.2, "coral"),
            (0.48, 3.45, "cream"),
            (0.48, 11.6, "cream"),
            (0.75, 11.9, "gold"),
            (0.48, 12.2, "cream"),
            (0.0, 12.2, "gold"),
        ],
        32,
    )
    for band_y, radius, material in ((1.0, 0.66, "gold"), (3.35, 0.56, "coral"), (11.75, 0.67, "gold")):
        add_torus(mesh, radius, 0.1, band_y, material, segments=32, sides=6)

    for horse_index in range(8):
        angle = TAU * horse_index / 8
        outer = (8.75 * math.cos(angle), 12.0, 8.75 * math.sin(angle))
        add_cylinder_between(mesh, (0, 11.65, 0), outer, 0.13, 0.1, "gold", 8)
        origin = (6.6 * math.cos(angle), 0, 6.6 * math.sin(angle))
        transform = radial_transform(angle, origin)
        add_cylinder_between(mesh, (0, 3.4, 0), (0, 11.9, 0), 0.105, 0.075, "cream", 8, transform)
        add_ellipsoid(mesh, (0, 3.43, 0), (0.22, 0.16, 0.22), "gold", transform, 8, 4)
        add_horse(mesh, angle, 6.6, "mint" if horse_index % 2 else "coral")
    return mesh


def add_canopy_panel(mesh: Mesh, segment: int, material: str, thickness: float = 0.12) -> None:
    start = TAU * segment / 8 + 0.018
    end = TAU * (segment + 1) / 8 - 0.018
    angular_steps = 4
    profile = ((1.05, 14.1), (3.1, 14.65), (6.1, 14.0), (9.35, 12.35))
    top: list[list[int]] = []
    bottom: list[list[int]] = []
    for radius, y in profile:
        top_ring, bottom_ring = [], []
        for angular_step in range(angular_steps + 1):
            angle = start + (end - start) * angular_step / angular_steps
            x, z = radius * math.cos(angle), radius * math.sin(angle)
            top_ring.append(mesh.vertex((x, y, z)))
            bottom_ring.append(mesh.vertex((x, y - thickness, z)))
        top.append(top_ring)
        bottom.append(bottom_ring)

    for radial_step in range(len(profile) - 1):
        for angular_step in range(angular_steps):
            mesh.face(
                material,
                top[radial_step][angular_step],
                top[radial_step][angular_step + 1],
                top[radial_step + 1][angular_step + 1],
                top[radial_step + 1][angular_step],
            )
            mesh.face(
                "wood",
                bottom[radial_step][angular_step + 1],
                bottom[radial_step][angular_step],
                bottom[radial_step + 1][angular_step],
                bottom[radial_step + 1][angular_step + 1],
            )
    for angular_step in (0, angular_steps):
        for radial_step in range(len(profile) - 1):
            mesh.face(
                "gold",
                top[radial_step][angular_step],
                bottom[radial_step][angular_step],
                bottom[radial_step + 1][angular_step],
                top[radial_step + 1][angular_step],
            )
    for radial_step in (0, len(profile) - 1):
        for angular_step in range(angular_steps):
            mesh.face(
                "gold",
                top[radial_step][angular_step],
                top[radial_step][angular_step + 1],
                bottom[radial_step][angular_step + 1],
                bottom[radial_step][angular_step],
            )


def make_canopy(restored: bool) -> Mesh:
    name = "ParkParkCanopyRestored" if restored else "ParkParkCanopyNeglected"
    mesh = Mesh(name)
    missing_panels = set() if restored else {2, 6}
    for segment in range(8):
        if segment in missing_panels:
            continue
        if restored:
            material = "coral" if segment % 2 == 0 else "cream"
        else:
            material = "faded_coral" if segment % 2 == 0 else "faded_cream"
        add_canopy_panel(mesh, segment, material)

    for segment in range(8):
        if not restored and segment in {2, 3, 6}:
            continue
        angle = TAU * segment / 8
        add_cylinder_between(
            mesh,
            (0, 14.0, 0),
            (9.25 * math.cos(angle), 12.3, 9.25 * math.sin(angle)),
            0.1,
            0.075,
            "gold" if restored else "faded_mint",
            7,
        )
    if restored:
        add_torus(mesh, 9.23, 0.14, 12.28, "gold", segments=64, sides=8)
        for segment in range(24):
            angle = TAU * segment / 24
            add_ellipsoid(
                mesh,
                (9.18 * math.cos(angle), 12.05, 9.18 * math.sin(angle)),
                (0.15, 0.2, 0.15),
                "gold" if segment % 2 == 0 else "coral",
                slices=7,
                stacks=4,
            )
    else:
        add_torus(mesh, 9.23, 0.11, 12.28, "faded_coral", segments=48, sides=6, end_angle=TAU * 0.72)

    lathe(
        mesh,
        [
            (0.0, 14.1, "gold"),
            (0.7, 14.1, "coral" if restored else "faded_coral"),
            (0.64, 14.45, "cream" if restored else "faded_cream"),
            (0.5, 14.9, "coral" if restored else "faded_coral"),
            (0.37, 15.35, "gold"),
            (0.18, 15.8, "gold"),
            (0.0, 16.15, "gold"),
        ],
        24,
    )
    add_star(mesh, 16.65, 0.72, "gold" if restored else "faded_mint")
    return mesh


def add_arch_band(mesh: Mesh) -> None:
    segments = 32
    outer_radius, inner_radius, spring_y = 8.0, 6.15, 7.7
    front_z, back_z = -1.2, 1.2
    outer_front, inner_front, outer_back, inner_back = [], [], [], []
    for segment in range(segments + 1):
        angle = math.pi * segment / segments
        outer_x = outer_radius * math.cos(angle)
        outer_y = spring_y + outer_radius * math.sin(angle)
        inner_x = inner_radius * math.cos(angle)
        inner_y = spring_y + inner_radius * math.sin(angle)
        outer_front.append(mesh.vertex((outer_x, outer_y, front_z)))
        inner_front.append(mesh.vertex((inner_x, inner_y, front_z)))
        outer_back.append(mesh.vertex((outer_x, outer_y, back_z)))
        inner_back.append(mesh.vertex((inner_x, inner_y, back_z)))
    for segment in range(segments):
        material = "cream" if segment % 4 else "coral"
        mesh.face(material, outer_front[segment], outer_front[segment + 1], inner_front[segment + 1], inner_front[segment])
        mesh.face(material, outer_back[segment + 1], outer_back[segment], inner_back[segment], inner_back[segment + 1])
        mesh.face("gold", outer_front[segment], outer_back[segment], outer_back[segment + 1], outer_front[segment + 1])
        mesh.face("gold", inner_front[segment + 1], inner_back[segment + 1], inner_back[segment], inner_front[segment])


def make_entrance() -> Mesh:
    mesh = Mesh("ParkParkStorybookEntrance")
    for side, accent in ((-1, "coral"), (1, "mint")):
        center_x = side * 7.05
        add_vertical_cylinder(mesh, 1.12, 0.72, 7.82, "cream", 12, center_x)
        add_vertical_cylinder(mesh, 1.48, 0.08, 0.78, accent, 12, center_x)
        add_vertical_cylinder(mesh, 1.34, 7.28, 8.12, "gold", 12, center_x)
        for band_y in (0.9, 1.25, 7.0, 7.32, 8.06):
            add_torus(
                mesh,
                1.16 if band_y < 7 else 1.32,
                0.085,
                band_y,
                "gold",
                segments=16,
                sides=6,
                center_x=center_x,
            )
    add_arch_band(mesh)
    add_star(mesh, 16.25, 0.82, "gold")
    for side in (-1, 1):
        for tier in range(3):
            y = 9.4 + tier * 1.1
            add_ellipsoid(mesh, (side * (8.2 + tier * 0.16), y, -0.1), (0.2, 0.28, 0.2), "gold", slices=8, stacks=4)
    return mesh


def make_entrance_sign() -> Mesh:
    mesh = Mesh("ParkParkEntranceSign")
    add_box(mesh, (0, 0, 0), (7.4, 1.25, 0.3), "gold")
    add_box(mesh, (0, 0, -0.17), (7.1, 1.02, 0.12), "cream")
    add_box(mesh, (0, 0, -0.24), (6.72, 0.72, 0.06), "coral")
    add_torus(mesh, 0.09, 0.055, 0.0, "gold", segments=16, sides=5, center_x=-3.4)
    add_torus(mesh, 0.09, 0.055, 0.0, "gold", segments=16, sides=5, center_x=3.4)
    return mesh


def make_repair_console() -> Mesh:
    mesh = Mesh("ParkParkRepairConsole")
    lathe(
        mesh,
        [
            (0.0, 0.08, "wood"),
            (0.82, 0.08, "wood"),
            (0.94, 0.22, "gold"),
            (0.68, 0.42, "cream"),
            (0.62, 1.45, "cream"),
            (0.86, 1.58, "coral"),
            (0.66, 1.78, "cream"),
            (0.58, 2.42, "cream"),
            (0.7, 2.55, "gold"),
            (0.0, 2.55, "coral"),
        ],
        20,
    )
    add_torus(mesh, 0.78, 0.09, 0.36, "gold", segments=24, sides=6)
    add_box(mesh, (0, 1.82, -0.67), (0.92, 0.72, 0.12), "wood")
    add_box(mesh, (0, 1.82, -0.75), (0.72, 0.52, 0.08), "cream")
    for index, material in enumerate(("coral", "gold", "mint")):
        x = (index - 1) * 0.22
        add_ellipsoid(mesh, (x, 1.82, -0.83), (0.095, 0.12, 0.08), material, slices=8, stacks=4)
    add_star(mesh, 2.76, 0.26, "gold")
    return mesh


def write_materials() -> None:
    with (OUTPUT / "ParkParkFairground.mtl").open("w", encoding="utf-8", newline="\n") as output:
        output.write("# Shared low-poly palette for ParkPark's original fairground meshes\n")
        items = list(MATERIALS.items())
        for index, (name, diffuse) in enumerate(items):
            red, green, blue = diffuse
            output.write(f"newmtl {name}\n")
            output.write(f"Ka {red * 0.3:.4f} {green * 0.3:.4f} {blue * 0.3:.4f}\n")
            output.write(f"Kd {red:.4f} {green:.4f} {blue:.4f}\n")
            output.write("Ks 0.08 0.08 0.08\nNs 18\nd 1.0\nillum 2\n")
            output.write("map_Kd ParkParkPalette.png\n")
            if index < len(items) - 1:
                output.write("\n")


def neglected(diffuse: tuple[float, float, float]) -> tuple[float, float, float]:
    """Fade a palette color toward a dusty, sun-bleached gray-brown for the unrepaired park."""
    luminance = 0.3 * diffuse[0] + 0.59 * diffuse[1] + 0.11 * diffuse[2]
    dust = (0.05, 0.035, 0.0)
    return tuple(
        min(1.0, (channel * 0.35 + luminance * 0.65) * 0.72 + dust[index]) for index, channel in enumerate(diffuse)
    )


def write_palette(file_name: str, transform: Callable[[tuple[float, float, float]], tuple[float, ...]]) -> None:
    """Write a palette texture as an sRGB PNG using only the standard library."""
    width, height = PALETTE_CELL * len(MATERIALS), PALETTE_CELL
    row = b"".join(
        bytes(round(channel * 255) for channel in transform(diffuse)) * PALETTE_CELL
        for diffuse in MATERIALS.values()
    )
    raw = b"".join(b"\x00" + row for _ in range(height))

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    (OUTPUT / file_name).write_bytes(png)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    write_materials()
    write_palette("ParkParkPalette.png", lambda diffuse: diffuse)
    # Same UV layout, so the game swaps between the two textures for neglected/restored states.
    write_palette("ParkParkPaletteNeglected.png", neglected)
    meshes = (
        make_platform(),
        make_rotor(),
        make_canopy(restored=False),
        make_canopy(restored=True),
        make_entrance(),
        make_entrance_sign(),
        make_repair_console(),
    )
    for mesh in meshes:
        path = OUTPUT / f"{mesh.name}.obj"
        vertices, triangles, minimum, maximum = mesh.write(path)
        bounds = tuple(round(maximum[axis] - minimum[axis], 2) for axis in range(3))
        print(f"{path.relative_to(ROOT)}: {vertices:,} vertices, {triangles:,} triangles, bounds {bounds} studs")


if __name__ == "__main__":
    main()

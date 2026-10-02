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


def tilted_transform(
    origin: tuple[float, float, float], yaw: float, pitch: float = 0.0, roll: float = 0.0
) -> PointTransform:
    """Rotate about X (roll), then Z (pitch), then Y (yaw), and move to origin. Angles in degrees."""
    cr, sr = math.cos(math.radians(roll)), math.sin(math.radians(roll))
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))

    def transform(x: float, y: float, z: float) -> tuple[float, float, float]:
        y, z = y * cr - z * sr, y * sr + z * cr
        x, y = x * cp - y * sp, x * sp + y * cp
        x, z = x * cy + z * sy, -x * sy + z * cy
        return origin[0] + x, origin[1] + y, origin[2] + z

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
    transform: PointTransform = identity,
) -> None:
    bottom_ring = []
    top_ring = []
    for segment in range(segments):
        angle = TAU * segment / segments
        x = center_x + radius * math.cos(angle)
        z = center_z + radius * math.sin(angle)
        bottom_ring.append(mesh.vertex(transform(x, bottom, z)))
        top_ring.append(mesh.vertex(transform(x, top, z)))
    bottom_center = mesh.vertex(transform(center_x, bottom, center_z))
    top_center = mesh.vertex(transform(center_x, top, center_z))
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
    transform: PointTransform = identity,
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
                    transform(
                        center_x + ring_radius * math.cos(angle),
                        ring_y,
                        center_z + ring_radius * math.sin(angle),
                    )
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


def add_star(mesh: Mesh, center_y: float, radius: float, material: str, cx: float = 0.0, cz: float = 0.0) -> None:
    front_z, back_z = cz - 0.12, cz + 0.12
    points = []
    for index in range(10):
        angle = math.pi / 2 + index * math.pi / 5
        point_radius = radius if index % 2 == 0 else radius * 0.43
        points.append((cx + point_radius * math.cos(angle), center_y + point_radius * math.sin(angle)))
    front = [mesh.vertex((x, y, front_z)) for x, y in points]
    back = [mesh.vertex((x, y, back_z)) for x, y in points]
    front_center = mesh.vertex((cx, center_y, front_z))
    back_center = mesh.vertex((cx, center_y, back_z))
    for index in range(10):
        following = (index + 1) % 10
        mesh.triangle(material, front_center, front[index], front[following])
        mesh.triangle(material, back_center, back[following], back[index])
        mesh.face(material, front[index], back[index], back[following], front[following])


def add_horse(mesh: Mesh, angle: float, orbit_radius: float, palette: str) -> None:
    origin = (orbit_radius * math.cos(angle), 0, orbit_radius * math.sin(angle))
    # The rotor turns with positive Roblox yaw, so a horse at `angle` travels toward
    # (sin a, 0, -cos a). Point its head (+X) along that tangent instead of outward.
    transform = radial_transform(angle - math.pi / 2, origin)
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
    add_ellipsoid(mesh, (-0.45, 2.69, 0), (0.48, 0.2, 0.54), "wood", transform, 8, 4)


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


def lathe(
    mesh: Mesh,
    profile: list[tuple[float, float, str]],
    segments: int = 32,
    transform: PointTransform = identity,
) -> None:
    rings: list[list[int]] = []
    for radius, y, _ in profile:
        ring = []
        for segment in range(segments):
            angle = TAU * segment / segments
            ring.append(mesh.vertex(transform(radius * math.cos(angle), y, radius * math.sin(angle))))
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
        # The pole runs down into the horse's back so nothing hangs loose above the saddle.
        add_cylinder_between(mesh, (0, 2.72, 0), (0, 11.9, 0), 0.105, 0.075, "cream", 8, transform)
        add_ellipsoid(mesh, (0, 2.86, 0), (0.24, 0.16, 0.24), "gold", transform, 8, 4)
        add_horse(mesh, angle, 6.6, "mint" if horse_index % 2 else "coral")
    return mesh


def make_teacups_platform() -> Mesh:
    mesh = Mesh("ParkParkTeacupsPlatform")
    lathe(
        mesh,
        [
            (0.0, 0.08, "wood"),
            (8.85, 0.08, "wood"),
            (9.2, 0.25, "gold"),
            (9.0, 0.48, "coral"),
            (8.45, 0.7, "cream"),
            (7.4, 0.76, "mint"),
            (0.0, 0.76, "mint"),
        ],
        64,
    )
    add_torus(mesh, 8.62, 0.14, 0.7, "gold", segments=64, sides=8)
    add_torus(mesh, 7.5, 0.08, 0.78, "coral", segments=56, sides=6)
    for index in range(16):
        angle = TAU * index / 16
        x, z = 8.08 * math.cos(angle), 8.08 * math.sin(angle)
        add_ellipsoid(mesh, (x, 0.83, z), (0.27, 0.1, 0.27), "cream" if index % 2 else "coral", slices=7, stacks=4)
    return mesh


def add_teacup(mesh: Mesh, angle: float, orbit_radius: float, palette: str) -> None:
    origin = (orbit_radius * math.cos(angle), 0, orbit_radius * math.sin(angle))
    transform = radial_transform(angle, origin)
    lathe(
        mesh,
        [
            (0.43, 1.06, "wood"),
            (0.76, 1.08, "gold"),
            (1.02, 1.3, palette),
            (1.24, 1.78, palette),
            (1.34, 2.32, palette),
            (1.28, 2.43, "gold"),
            (1.08, 2.38, "cream"),
            (0.96, 1.66, "dark_glass"),
            (0.64, 1.39, "dark_glass"),
            (0.36, 1.34, "dark_glass"),
        ],
        28,
        transform,
    )
    add_vertical_cylinder(mesh, 0.7, 1.05, 1.22, "dark_glass", segments=24, transform=transform)
    add_torus(mesh, 0.94, 0.13, 1.13, "cream", segments=24, sides=6, transform=transform)

    # Paired handles make each cup read clearly even at the entrance camera distance.
    for side in (-1, 1):
        points = (
            (side * 1.18, 2.18, 0.0),
            (side * 1.48, 2.17, 0.0),
            (side * 1.67, 1.98, 0.0),
            (side * 1.53, 1.78, 0.0),
            (side * 1.21, 1.78, 0.0),
        )
        for start, end in zip(points, points[1:]):
            add_cylinder_between(mesh, start, end, 0.075, 0.075, "gold", 6, transform)

    for dot in range(8):
        dot_angle = TAU * dot / 8
        add_ellipsoid(
            mesh,
            (1.12 * math.cos(dot_angle), 2.18, 1.12 * math.sin(dot_angle)),
            (0.11, 0.1, 0.11),
            "cream",
            transform,
            6,
            4,
        )


def make_teacups_rotor() -> Mesh:
    mesh = Mesh("ParkParkTeacupsRotor")
    lathe(
        mesh,
        [
            (0.0, 0.62, "wood"),
            (0.76, 0.62, "wood"),
            (0.94, 0.9, "gold"),
            (0.66, 1.2, "coral"),
            (0.55, 4.0, "cream"),
            (0.78, 4.2, "gold"),
            (0.55, 4.48, "mint"),
            (0.48, 7.18, "cream"),
            (0.8, 7.42, "gold"),
            (0.5, 7.68, "coral"),
            (0.0, 7.82, "gold"),
        ],
        32,
    )
    for y, radius, material in ((1.02, 0.78, "cream"), (4.34, 0.7, "coral"), (7.52, 0.68, "gold")):
        add_torus(mesh, radius, 0.11, y, material, segments=32, sides=7)

    orbit_radius = 6.0
    for cup_index in range(6):
        angle = TAU * cup_index / 6
        x, z = orbit_radius * math.cos(angle), orbit_radius * math.sin(angle)
        material = ("coral", "mint", "cream")[cup_index % 3]
        # Rotating saucer pedestals and spokes tie the six cups into one controllable rotor.
        add_cylinder_between(mesh, (x, 0.77, z), (x, 1.12, z), 0.52, 0.39, "gold", 10)
        add_cylinder_between(mesh, (0, 1.18, 0), (x, 1.18, z), 0.16, 0.11, "coral", 8)
        add_cylinder_between(mesh, (0, 5.35, 0), (x * 0.72, 3.0, z * 0.72), 0.15, 0.09, "gold", 8)
        add_cylinder_between(mesh, (0, 7.18, 0), (x * 0.78, 4.65, z * 0.78), 0.12, 0.075, "cream", 8)
        add_teacup(mesh, angle, orbit_radius, material)

    add_torus(mesh, 6.85, 0.11, 3.02, "gold", segments=48, sides=7)
    add_star(mesh, 8.28, 0.54, "gold")
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


def make_entrance_debris() -> Mesh:
    """A cleanup pile: snapped planks, a split crate, a fallen ticket sign, and weeds with a few blooms."""
    mesh = Mesh("ParkParkEntranceDebris")
    # Split crate with a loose lid.
    add_box(mesh, (0.9, 0.5, -0.5), (1.4, 1.0, 1.2), "wood", tilted_transform((0, 0, 0), 12))
    add_box(mesh, (0, 0, 0), (1.5, 0.12, 1.3), "faded_cream", tilted_transform((1.2, 1.12, -0.35), 25, 14))
    # Snapped planks leaning on and around the crate.
    for origin, yaw, pitch, material in (
        ((-0.6, 0.55, 0.2), -20, 24, "wood"),
        ((-1.4, 0.18, -0.9), 58, 5, "faded_cream"),
        ((0.2, 0.3, 1.1), 102, -9, "wood"),
        ((-0.3, 0.95, -0.6), 150, 32, "faded_coral"),
        ((1.9, 0.2, 0.9), 35, -4, "faded_cream"),
    ):
        add_box(mesh, (0, 0, 0), (2.8, 0.13, 0.42), material, tilted_transform(origin, yaw, pitch))
    # Fallen ticket-booth sign, face down in the weeds.
    add_box(mesh, (0, 0, 0), (1.9, 0.6, 0.1), "faded_coral", tilted_transform((-1.5, 0.28, 1.2), -30, 0, 72))
    add_box(mesh, (0, 0, 0), (2.05, 0.72, 0.06), "faded_cream", tilted_transform((-1.5, 0.22, 1.22), -30, 0, 72))
    # Weeds and bushes that have grown through the pile.
    for center, radii, material in (
        ((-2.2, 0.35, -0.4), (0.8, 0.55, 0.7), "faded_mint"),
        ((2.3, 0.3, -0.7), (0.7, 0.45, 0.6), "faded_mint"),
        ((-0.9, 0.25, -1.5), (0.6, 0.35, 0.5), "mint"),
        ((1.1, 0.25, 1.7), (0.55, 0.32, 0.45), "faded_mint"),
        ((0.1, 0.2, -1.4), (0.45, 0.28, 0.4), "mint"),
    ):
        add_ellipsoid(mesh, center, radii, material, slices=9, stacks=5)
    # A few blooms and pebbles so the pile reads as overgrown rather than as plain rubble.
    for center in ((-2.0, 0.85, -0.2), (2.4, 0.72, -0.5), (-0.8, 0.58, -1.4)):
        add_ellipsoid(mesh, center, (0.13, 0.1, 0.13), "coral", slices=6, stacks=4)
    for center in ((1.6, 0.1, -1.6), (-2.6, 0.08, 0.8), (0.6, 0.09, 2.1), (2.8, 0.08, 0.4)):
        add_ellipsoid(mesh, center, (0.24, 0.12, 0.2), "faded_cream", slices=7, stacks=4)
    return mesh


def make_bumper_platform() -> Mesh:
    """Round bumper-car rink: rimmed floor, low bumper rail, floor inlays, and four lamp posts."""
    mesh = Mesh("ParkParkBumperPlatform")
    add_vertical_cylinder(mesh, 10.4, 0.08, 0.7, "cream", 48)
    add_vertical_cylinder(mesh, 10.42, 0.08, 0.3, "coral", 48)
    add_vertical_cylinder(mesh, 9.7, 0.7, 0.8, "mint", 48)
    # Floor inlays make the rink read as a track rather than a plain disc.
    add_torus(mesh, 6.6, 0.1, 0.82, "coral", segments=48, sides=5)
    add_torus(mesh, 3.4, 0.1, 0.82, "gold", segments=40, sides=5)
    add_vertical_cylinder(mesh, 1.0, 0.8, 0.9, "gold", 24)
    add_vertical_cylinder(mesh, 0.55, 0.9, 0.98, "coral", 20)
    # Bumper rail: posts around the rim joined by a padded coral rail with a gold cap.
    for post in range(24):
        angle = TAU * post / 24
        add_vertical_cylinder(
            mesh, 0.16, 0.8, 1.55, "cream", 8, 9.95 * math.cos(angle), 9.95 * math.sin(angle)
        )
    add_torus(mesh, 9.95, 0.34, 1.32, "coral", segments=48, sides=8)
    add_torus(mesh, 9.95, 0.1, 1.72, "gold", segments=48, sides=6)
    # Lamp posts at the diagonals, with a bulb, so the restored rink glows at dusk.
    for index in range(4):
        angle = math.pi / 4 + index * math.pi / 2
        x, z = 10.6 * math.cos(angle), 10.6 * math.sin(angle)
        add_vertical_cylinder(mesh, 0.22, 0.08, 6.0, "cream", 12, x, z)
        add_vertical_cylinder(mesh, 0.42, 0.08, 1.1, "gold", 12, x, z)
        add_torus(mesh, 0.3, 0.07, 5.7, "gold", segments=14, sides=5, center_x=x, center_z=z)
        add_ellipsoid(mesh, (x, 6.35, z), (0.5, 0.5, 0.5), "gold", slices=10, stacks=6)
        add_ellipsoid(mesh, (x, 6.95, z), (0.13, 0.2, 0.13), "coral", slices=6, stacks=4)
    return mesh


def make_bumper_car() -> Mesh:
    """One bumper car facing local -Z: cushioned bumper ring, rounded body, seat, and a spark pole."""
    mesh = Mesh("ParkParkBumperCar")
    # Chassis and padded bumper ring.
    add_box(mesh, (0, 0.34, 0), (1.7, 0.26, 2.5), "wood")
    for x, z, size in (
        (0, -1.38, (2.0, 0.34, 0.3)),
        (0, 1.38, (2.0, 0.34, 0.3)),
        (-1.0, 0, (0.3, 0.34, 2.5)),
        (1.0, 0, (0.3, 0.34, 2.5)),
    ):
        add_box(mesh, (x, 0.48, z), size, "gold")
    for x, z in ((-1.0, -1.38), (1.0, -1.38), (-1.0, 1.38), (1.0, 1.38)):
        add_ellipsoid(mesh, (x, 0.48, z), (0.24, 0.2, 0.24), "gold", slices=8, stacks=4)
    # Body shell: cowl, hood, and side fenders.
    add_ellipsoid(mesh, (0, 0.88, 0.25), (0.86, 0.46, 1.05), "coral", slices=14, stacks=6)
    add_ellipsoid(mesh, (0, 0.82, -0.85), (0.74, 0.34, 0.68), "coral", slices=12, stacks=6)
    for side in (-1, 1):
        add_ellipsoid(mesh, (side * 0.72, 0.72, -0.1), (0.24, 0.3, 1.3), "cream", slices=8, stacks=5)
    add_box(mesh, (0, 1.2, -0.85), (0.5, 0.05, 0.86), "mint")
    # Seat, backrest, and steering wheel.
    add_box(mesh, (0, 1.12, 0.5), (1.1, 0.34, 0.9), "cream")
    add_box(mesh, (0, 1.62, 0.92), (1.1, 0.9, 0.2), "cream")
    add_cylinder_between(mesh, (0, 1.2, -0.2), (0, 1.55, 0.05), 0.05, 0.05, "wood", 6)
    add_torus(mesh, 0.28, 0.05, 1.56, "gold", segments=14, sides=5, center_z=0.05)
    # Headlights.
    for side in (-1, 1):
        add_ellipsoid(mesh, (side * 0.52, 0.92, -1.4), (0.17, 0.17, 0.12), "gold", slices=8, stacks=4)
    # Spark pole with a contact plate on top.
    add_cylinder_between(mesh, (0, 1.4, 1.0), (0, 5.0, 1.0), 0.08, 0.06, "wood", 8)
    add_ellipsoid(mesh, (0, 5.05, 1.0), (0.5, 0.09, 0.5), "gold", slices=12, stacks=4)
    add_ellipsoid(mesh, (0, 5.2, 1.0), (0.12, 0.14, 0.12), "coral", slices=6, stacks=4)
    return mesh


def make_teacups_hub() -> Mesh:
    """Rotating teacup deck: turntable ring, six cup pedestals joined to a central column and small roof.

    The cups are a separate mesh (make_teacup) so each one can spin on its own pedestal.
    """
    mesh = Mesh("ParkParkTeacupsHub")
    # Deck sits on the platform top (y = 0.85) and rotates as one piece.
    add_vertical_cylinder(mesh, 8.6, 0.74, 1.12, "cream", 48)
    add_vertical_cylinder(mesh, 8.62, 0.74, 0.98, "coral", 48)
    add_torus(mesh, 8.4, 0.12, 1.14, "gold", segments=48, sides=6)
    lathe(
        mesh,
        [
            (0.0, 1.1, "wood"),
            (1.5, 1.1, "wood"),
            (1.15, 1.6, "gold"),
            (0.66, 2.0, "coral"),
            (0.55, 4.6, "cream"),
            (0.78, 4.8, "gold"),
            (0.55, 5.1, "mint"),
            (0.46, 7.4, "cream"),
            (0.5, 7.6, "gold"),
            (0.0, 7.7, "gold"),
        ],
        32,
    )
    # Small striped roof joined to the top of the column.
    lathe(
        mesh,
        [(0.0, 8.7, "gold"), (1.6, 7.9, "coral"), (3.2, 7.35, "cream"), (4.1, 7.0, "coral"), (4.1, 6.85, "gold")],
        32,
    )
    add_cylinder_between(mesh, (0, 7.4, 0), (0, 8.7, 0), 0.34, 0.16, "gold", 10)
    add_star(mesh, 9.15, 0.5, "gold")
    orbit_radius = 6.0
    for index in range(6):
        angle = TAU * index / 6
        x, z = orbit_radius * math.cos(angle), orbit_radius * math.sin(angle)
        # Flat spoke from the hub to each turntable, then the turntable the cup spins on.
        add_cylinder_between(mesh, (0, 1.3, 0), (x, 1.3, z), 0.24, 0.24, "coral", 8)
        add_vertical_cylinder(mesh, 2.0, 1.12, 1.34, "gold", 28, x, z)
        add_vertical_cylinder(mesh, 1.7, 1.34, 1.42, "cream", 28, x, z)
    return mesh


def make_teacup() -> Mesh:
    """One wide, shallow teacup with its base at y=0, so a guest can stand waist-deep in it."""
    mesh = Mesh("ParkParkTeacup")
    lathe(
        mesh,
        [
            (0.0, 0.0, "gold"),
            (0.8, 0.0, "gold"),
            (1.05, 0.16, "coral"),
            (1.45, 0.6, "coral"),
            (1.65, 1.2, "coral"),
            (1.58, 1.32, "gold"),
            (1.38, 1.26, "cream"),
            (1.28, 0.62, "dark_glass"),
            (1.0, 0.5, "dark_glass"),
            (0.0, 0.46, "dark_glass"),
        ],
        32,
    )
    for side in (-1, 1):
        points = (
            (side * 1.55, 1.05, 0.0),
            (side * 1.95, 1.05, 0.0),
            (side * 2.1, 0.78, 0.0),
            (side * 1.9, 0.52, 0.0),
            (side * 1.5, 0.52, 0.0),
        )
        for start, end in zip(points, points[1:]):
            add_cylinder_between(mesh, start, end, 0.1, 0.1, "gold", 6)
    for dot in range(10):
        dot_angle = TAU * dot / 10 + 0.2
        add_ellipsoid(
            mesh,
            (1.5 * math.cos(dot_angle), 0.9, 1.5 * math.sin(dot_angle)),
            (0.12, 0.11, 0.12),
            "cream",
            slices=6,
            stacks=4,
        )
    return mesh


def add_slab(mesh: Mesh, corners: list[tuple[float, float, float]], material: str) -> None:
    """A hexahedron from eight corners (four on the -Z face, then the same four on the +Z face)."""
    ids = [mesh.vertex(point) for point in corners]
    for face in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 4, 7, 3), (1, 2, 6, 5), (0, 1, 5, 4), (3, 7, 6, 2)):
        mesh.face(material, *(ids[index] for index in face))


def make_snack_stand() -> Mesh:
    """A striped-awning snack stall (front is -Z): counter, popcorn machine, posts, and a popcorn-tub crest."""
    mesh = Mesh("ParkParkSnackStand")
    add_box(mesh, (0, 0.1, 0), (6.6, 0.2, 4.2), "wood")
    # Back wall and side panels.
    add_box(mesh, (0, 1.7, 1.5), (5.6, 3.0, 0.15), "cream")
    add_box(mesh, (-2.75, 1.7, 0.2), (0.15, 3.0, 2.8), "cream")
    add_box(mesh, (2.75, 1.7, 0.2), (0.15, 3.0, 2.8), "cream")
    # Counter with a wooden top and coral front panels.
    add_box(mesh, (0, 0.65, -1.1), (5.4, 0.9, 1.0), "coral")
    add_box(mesh, (0, 1.16, -1.1), (5.7, 0.12, 1.3), "wood")
    for x in (-1.8, 0.0, 1.8):
        add_box(mesh, (x, 0.65, -1.62), (1.4, 0.6, 0.06), "cream")
    # Corner posts.
    for x in (-2.85, 2.85):
        for z in (-1.7, 1.6):
            add_vertical_cylinder(mesh, 0.1, 0.2, 3.5, "gold", 10, center_x=x, center_z=z)
    # Striped, sloping awning with a scalloped valance along its low front edge.
    stripes = 6
    width = 6.4 / stripes
    for index in range(stripes):
        x0 = -3.2 + index * width
        x1 = x0 + width
        material = "coral" if index % 2 == 0 else "cream"
        add_slab(
            mesh,
            [
                (x0, 3.15, -2.1),
                (x1, 3.15, -2.1),
                (x1, 3.27, -2.1),
                (x0, 3.27, -2.1),
                (x0, 3.7, 1.8),
                (x1, 3.7, 1.8),
                (x1, 3.82, 1.8),
                (x0, 3.82, 1.8),
            ],
            material,
        )
        add_box(mesh, ((x0 + x1) / 2, 3.0, -2.12), (width, 0.32, 0.06), material)
    # Popcorn-tub crest on the roof, with puffs of popcorn.
    add_cylinder_between(mesh, (0, 3.85, 0.3), (0, 4.65, 0.3), 0.42, 0.62, "coral", 12)
    add_cylinder_between(mesh, (0, 4.0, 0.3), (0, 4.3, 0.3), 0.5, 0.56, "cream", 12)
    for x, y, z, radius in ((-0.3, 4.85, 0.15, 0.3), (0.3, 4.9, 0.45, 0.28), (0.0, 5.1, 0.3, 0.32), (0.35, 4.75, 0.05, 0.22)):
        add_ellipsoid(mesh, (x, y, z), (radius, radius * 0.9, radius), "cream", slices=8, stacks=5)
    add_star(mesh, 5.55, 0.25, "gold")
    # Popcorn machine on the counter (left) and candy jars (right).
    add_box(mesh, (-1.6, 1.52, -1.0), (1.0, 0.6, 0.8), "coral")
    add_box(mesh, (-1.6, 2.05, -1.0), (0.9, 0.5, 0.7), "dark_glass")
    add_box(mesh, (-1.6, 2.36, -1.0), (1.05, 0.12, 0.85), "gold")
    add_ellipsoid(mesh, (-1.6, 2.05, -1.0), (0.3, 0.2, 0.25), "cream", slices=8, stacks=4)
    for x, material in ((1.2, "mint"), (1.65, "coral"), (2.1, "gold")):
        add_vertical_cylinder(mesh, 0.2, 1.22, 1.75, material, 10, center_x=x, center_z=-1.0)
        add_vertical_cylinder(mesh, 0.22, 1.75, 1.82, "cream", 10, center_x=x, center_z=-1.0)
    # A barrel and a crate beside the stand.
    add_vertical_cylinder(mesh, 0.42, 0.2, 1.1, "wood", 12, center_x=3.95, center_z=-0.4)
    add_vertical_cylinder(mesh, 0.44, 0.55, 0.65, "gold", 12, center_x=3.95, center_z=-0.4)
    add_box(mesh, (3.95, 0.5, 0.75), (0.9, 0.6, 0.8), "wood", tilted_transform((0, 0, 0), 12))
    return mesh


FERRIS_RADIUS = 6.0
FERRIS_HUB_HEIGHT = 9.2
FERRIS_CABIN_COUNT = 8


def in_wheel_plane(z_offset: float) -> PointTransform:
    """Map a horizontal (XZ) primitive onto the wheel's vertical XY plane at z = z_offset."""

    def transform(x: float, y: float, z: float) -> tuple[float, float, float]:
        return x, z, y + z_offset

    return transform


def make_ferris_wheel() -> Mesh:
    """The turning wheel, centered on its hub (axle along Z): twin rims, spokes, cross-braces, bulbs, hub caps."""
    mesh = Mesh("ParkParkFerrisWheel")
    for z in (-0.5, 0.5):
        add_torus(mesh, FERRIS_RADIUS, 0.17, 0.0, "coral", 48, 6, transform=in_wheel_plane(z))
        add_torus(mesh, FERRIS_RADIUS - 0.9, 0.1, 0.0, "cream", 40, 5, transform=in_wheel_plane(z))
    for index in range(16):
        angle = TAU * index / 16
        cosine, sine = math.cos(angle), math.sin(angle)
        for z in (-0.5, 0.5):
            add_cylinder_between(
                mesh,
                (0.6 * cosine, 0.6 * sine, z),
                (FERRIS_RADIUS * cosine, FERRIS_RADIUS * sine, z),
                0.07,
                0.07,
                "cream" if index % 2 else "gold",
                6,
            )
        add_cylinder_between(
            mesh,
            (FERRIS_RADIUS * cosine, FERRIS_RADIUS * sine, -0.5),
            (FERRIS_RADIUS * cosine, FERRIS_RADIUS * sine, 0.5),
            0.09,
            0.09,
            "gold",
            6,
        )
    # Bulbs round the rim on both faces.
    for index in range(32):
        angle = TAU * index / 32
        material = "gold" if index % 2 else "cream"
        for z in (-0.72, 0.72):
            add_ellipsoid(
                mesh,
                ((FERRIS_RADIUS + 0.12) * math.cos(angle), (FERRIS_RADIUS + 0.12) * math.sin(angle), z),
                (0.13, 0.13, 0.13),
                material,
                slices=6,
                stacks=3,
            )
    # Hanger knobs where the cabins hang.
    for index in range(FERRIS_CABIN_COUNT):
        angle = TAU * index / FERRIS_CABIN_COUNT
        add_ellipsoid(
            mesh,
            (FERRIS_RADIUS * math.cos(angle), FERRIS_RADIUS * math.sin(angle), 0.0),
            (0.22, 0.22, 0.7),
            "gold",
            slices=8,
            stacks=4,
        )
    # Hub: axle cylinder, coral drum, and gold caps on both sides.
    add_cylinder_between(mesh, (0, 0, -1.0), (0, 0, 1.0), 0.95, 0.95, "coral", 20)
    add_cylinder_between(mesh, (0, 0, -1.02), (0, 0, -1.15), 0.55, 0.55, "gold", 16)
    add_cylinder_between(mesh, (0, 0, 1.02), (0, 0, 1.15), 0.55, 0.55, "gold", 16)
    return mesh


def make_ferris_base() -> Mesh:
    """Boarding pad and two A-frame towers that carry the axle at (0, hub, 0); origin is the ground center."""
    mesh = Mesh("ParkParkFerrisBase")
    add_box(mesh, (0, 0.15, 0), (11.0, 0.3, 8.4), "wood")
    add_box(mesh, (0, 0.32, 0), (10.0, 0.06, 7.4), "cream")
    for z in (-1.4, 1.4):
        apex = (0.0, FERRIS_HUB_HEIGHT, z)
        for foot_x in (-4.4, 4.4):
            add_cylinder_between(mesh, (foot_x, 0.3, z), apex, 0.3, 0.24, "coral", 8)
            add_box(mesh, (foot_x, 0.5, z), (0.9, 0.4, 0.9), "gold")
        # Cross-brace and a gold collar under the axle.
        add_cylinder_between(mesh, (-2.6, 3.7, z), (2.6, 3.7, z), 0.16, 0.16, "cream", 6)
        add_cylinder_between(mesh, (-1.5, 6.4, z), (1.5, 6.4, z), 0.13, 0.13, "cream", 6)
        add_ellipsoid(mesh, apex, (0.5, 0.5, 0.45), "gold", slices=10, stacks=5)
    add_cylinder_between(mesh, (0, FERRIS_HUB_HEIGHT, -1.7), (0, FERRIS_HUB_HEIGHT, 1.7), 0.32, 0.32, "gold", 10)
    add_star(mesh, FERRIS_HUB_HEIGHT + 0.9, 0.35, "gold")
    return mesh


def make_ferris_cabin() -> Mesh:
    """A gondola hanging from its hanger point (the origin): striped dome roof, low walls, and a bench.

    It is symmetric front to back, so it looks right whichever way the imported mesh ends up facing.
    """
    mesh = Mesh("ParkParkFerrisCabin")
    add_cylinder_between(mesh, (0, 0.25, 0), (0, -0.55, 0), 0.09, 0.09, "gold", 8)
    add_ellipsoid(mesh, (0, 0.28, 0), (0.2, 0.12, 0.2), "gold", slices=8, stacks=4)
    lathe(
        mesh,
        [(0.0, -0.32, "gold"), (0.5, -0.48, "coral"), (1.2, -0.62, "cream"), (1.55, -0.78, "coral"), (1.55, -0.86, "gold")],
        24,
    )
    for x in (-1.15, 1.15):
        for z in (-0.85, 0.85):
            add_cylinder_between(mesh, (x, -0.86, z), (x, -2.5, z), 0.07, 0.07, "gold", 6)
    add_box(mesh, (0, -2.6, 0), (2.5, 0.14, 2.0), "wood")
    # Half walls on the two long sides, and a railing on the two short ends.
    for x in (-1.2, 1.2):
        add_box(mesh, (x, -2.05, 0), (0.1, 0.9, 1.8), "coral")
        add_box(mesh, (x, -1.55, 0), (0.14, 0.1, 1.9), "gold")
    for z in (-0.9, 0.9):
        add_box(mesh, (0, -1.95, z), (2.3, 0.12, 0.08), "cream")
        add_box(mesh, (0, -2.25, z), (2.3, 0.08, 0.08), "cream")
    # Bench seat in the middle; its top is at y = -2.0.
    add_box(mesh, (0, -2.25, 0), (1.3, 0.5, 0.9), "mint")
    return mesh


SWING_TOWER_HEIGHT = 8.0
SWING_ANCHOR_RADIUS = 4.6
SWING_ANCHOR_Y = -0.4
SWING_SEAT_COUNT = 8
SWING_CHAIN = 5.0


def make_swing_base() -> Mesh:
    """Round boarding platform and the tall central tower of the swing ride; origin is the ground center."""
    mesh = Mesh("ParkParkSwingBase")
    add_vertical_cylinder(mesh, 8.0, 0.05, 0.6, "cream", 48)
    add_vertical_cylinder(mesh, 8.02, 0.05, 0.4, "coral", 48)
    add_torus(mesh, 7.85, 0.12, 0.62, "gold", segments=48, sides=6)
    for index in range(16):
        angle = TAU * index / 16
        add_ellipsoid(mesh, (7.4 * math.cos(angle), 0.75, 7.4 * math.sin(angle)), (0.14, 0.14, 0.14), "gold" if index % 2 else "cream", slices=6, stacks=3)
    lathe(
        mesh,
        [
            (0.0, 0.55, "wood"),
            (1.7, 0.55, "wood"),
            (1.35, 1.1, "gold"),
            (1.05, 1.7, "coral"),
            (0.9, 3.0, "cream"),
            (0.82, 4.4, "cream"),
            (0.98, 4.6, "gold"),
            (0.78, 5.0, "mint"),
            (0.72, 6.9, "cream"),
            (0.88, 7.1, "gold"),
            (0.66, 7.4, "coral"),
            (0.62, SWING_TOWER_HEIGHT - 0.3, "cream"),
            (0.5, SWING_TOWER_HEIGHT, "gold"),
            (0.0, SWING_TOWER_HEIGHT, "gold"),
        ],
        32,
    )
    return mesh


def make_swing_crown() -> Mesh:
    """The turning crown: hub, arms out to eight anchor points, ring, striped roof, bulbs, and a star.

    The origin is the top of the tower, on the axis the crown turns about.
    """
    mesh = Mesh("ParkParkSwingCrown")
    lathe(mesh, [(0.0, -0.9, "gold"), (0.95, -0.9, "gold"), (1.05, -0.5, "coral"), (0.95, 0.1, "cream"), (0.7, 0.3, "gold"), (0.0, 0.3, "gold")], 24)
    for index in range(SWING_SEAT_COUNT):
        angle = TAU * index / SWING_SEAT_COUNT
        cosine, sine = math.cos(angle), math.sin(angle)
        anchor = (SWING_ANCHOR_RADIUS * cosine, SWING_ANCHOR_Y, SWING_ANCHOR_RADIUS * sine)
        add_cylinder_between(mesh, (0.6 * cosine, -0.2, 0.6 * sine), anchor, 0.15, 0.13, "gold", 8)
        add_ellipsoid(mesh, (anchor[0], anchor[1] - 0.1, anchor[2]), (0.24, 0.2, 0.24), "coral", slices=8, stacks=4)
    add_torus(mesh, SWING_ANCHOR_RADIUS + 0.35, 0.12, -0.35, "cream", segments=48, sides=6)
    for index in range(24):
        angle = TAU * index / 24
        add_ellipsoid(
            mesh,
            ((SWING_ANCHOR_RADIUS + 0.75) * math.cos(angle), -0.3, (SWING_ANCHOR_RADIUS + 0.75) * math.sin(angle)),
            (0.13, 0.13, 0.13),
            "gold" if index % 2 else "cream",
            slices=6,
            stacks=3,
        )
    # Striped umbrella roof above the arms, alternating coral and cream wedges.
    segments = 16
    for index in range(segments):
        material = "coral" if index % 2 == 0 else "cream"
        a0, a1 = TAU * index / segments, TAU * (index + 1) / segments
        ring = [(0.0, 2.3), (1.6, 1.75), (3.3, 1.2), (5.4, 0.55)]
        ids = []
        for radius, height in ring:
            ids.append((mesh.vertex((radius * math.cos(a0), height, radius * math.sin(a0))), mesh.vertex((radius * math.cos(a1), height, radius * math.sin(a1)))))
        for k in range(len(ring) - 1):
            quad = (ids[k][0], ids[k][1], ids[k + 1][1], ids[k + 1][0])
            # The roof is a thin shell, so both sides are drawn.
            mesh.face(material, *quad)
            mesh.face(material, *reversed(quad))
    add_torus(mesh, 5.4, 0.13, 0.5, "gold", segments=48, sides=6)
    add_cylinder_between(mesh, (0, 2.2, 0), (0, 3.0, 0), 0.16, 0.1, "gold", 8)
    add_star(mesh, 3.35, 0.4, "gold")
    return mesh


def make_swing_seat() -> Mesh:
    """One hanging chair: two chains from the anchor (the origin) to a bench with a backrest at +Z."""
    mesh = Mesh("ParkParkSwingSeat")
    add_box(mesh, (0, 0.08, 0), (1.3, 0.16, 0.16), "gold")
    for side in (-1, 1):
        add_cylinder_between(mesh, (side * 0.15, 0.05, 0), (side * 0.62, -SWING_CHAIN, 0), 0.05, 0.05, "ink", 5)
        add_box(mesh, (side * 0.78, -SWING_CHAIN - 0.3, 0.05), (0.14, 0.55, 1.0), "coral")
    add_box(mesh, (0, -SWING_CHAIN - 0.35, 0.02), (1.5, 0.18, 1.1), "coral")
    add_box(mesh, (0, -SWING_CHAIN + 0.15, 0.5), (1.5, 0.95, 0.14), "gold")
    add_box(mesh, (0, -SWING_CHAIN - 0.05, -0.36), (1.4, 0.08, 0.08), "cream")
    add_box(mesh, (0, -SWING_CHAIN - 0.75, -0.5), (1.4, 0.1, 0.4), "wood")
    return mesh


PIRATE_HUB_HEIGHT = 9.0
PIRATE_ARM_DROP = 6.4


def add_plane(mesh: Mesh, corners: list[tuple[float, float, float]], material: str) -> None:
    """A flat quad drawn on both sides (for thin sails)."""
    ids = [mesh.vertex(point) for point in corners]
    mesh.face(material, *ids)
    mesh.face(material, *reversed(ids))


def make_pirate_base() -> Mesh:
    """Round boarding platform and two A-frame towers carrying the axle; origin is the ground center."""
    mesh = Mesh("ParkParkPirateBase")
    add_vertical_cylinder(mesh, 8.0, 0.05, 0.6, "cream", 48)
    add_vertical_cylinder(mesh, 8.02, 0.05, 0.4, "wood", 48)
    add_torus(mesh, 7.85, 0.12, 0.62, "gold", segments=48, sides=6)
    for index in range(16):
        angle = TAU * index / 16
        add_ellipsoid(mesh, (7.4 * math.cos(angle), 0.75, 7.4 * math.sin(angle)), (0.14, 0.14, 0.14), "gold" if index % 2 else "cream", slices=6, stacks=3)
    apex_y = PIRATE_HUB_HEIGHT
    for x in (-4.4, 4.4):
        apex = (x, apex_y, 0.0)
        for foot_z in (-4.6, 4.6):
            add_cylinder_between(mesh, (x, 0.6, foot_z), apex, 0.34, 0.26, "wood", 8)
            add_box(mesh, (x, 0.75, foot_z), (1.0, 0.3, 1.0), "gold")
        add_cylinder_between(mesh, (x, 3.6, -2.6), (x, 3.6, 2.6), 0.16, 0.16, "cream", 6)
        add_ellipsoid(mesh, apex, (0.5, 0.5, 0.5), "gold", slices=10, stacks=5)
    # Axle beam between the towers, and pennants on top.
    add_cylinder_between(mesh, (-5.4, apex_y, 0), (5.4, apex_y, 0), 0.3, 0.3, "gold", 10)
    for x in (-4.4, 4.4):
        add_cylinder_between(mesh, (x, apex_y + 0.4, 0), (x, apex_y + 2.4, 0), 0.08, 0.06, "wood", 6)
        add_plane(mesh, [(x, apex_y + 2.4, 0), (x, apex_y + 1.5, 0), (x + 1.3 * (1 if x > 0 else -1), apex_y + 1.95, 0)], "coral")
    return mesh


def make_pirate_ship() -> Mesh:
    """The swinging ship, hanging from its axle at the origin (axle along X): arms, a double-ended hull with
    four benches, a mast with a striped sail, and a figurehead at each end. Symmetric front to back."""
    mesh = Mesh("ParkParkPirateShip")
    add_cylinder_between(mesh, (-3.4, 0, 0), (3.4, 0, 0), 0.36, 0.36, "gold", 12)
    for x in (-2.6, 2.6):
        add_cylinder_between(mesh, (x, 0, 0), (x, -PIRATE_ARM_DROP, 0), 0.2, 0.2, "wood", 8)
        add_ellipsoid(mesh, (x, 0, 0), (0.4, 0.4, 0.4), "gold", slices=8, stacks=4)
    floor_y = -7.3
    # Deck and hull: floor, two side walls, and raised prows at both ends.
    add_box(mesh, (0, floor_y, 0), (4.6, 0.3, 9.0), "wood")
    add_box(mesh, (0, floor_y - 0.4, 0), (3.6, 0.5, 8.0), "coral")
    for x in (-2.3, 2.3):
        add_box(mesh, (x, floor_y + 0.6, 0), (0.28, 1.2, 9.0), "coral")
        add_box(mesh, (x, floor_y + 1.28, 0), (0.36, 0.16, 9.2), "gold")
    for sign in (-1, 1):
        # Prow: a wall that rises and curls, ending in a gold figurehead.
        add_box(mesh, (0, floor_y + 0.9, sign * 4.5), (4.6, 1.8, 0.3), "coral")
        add_box(mesh, (0, floor_y + 1.9, sign * 4.5), (4.7, 0.2, 0.42), "gold")
        add_cylinder_between(mesh, (0, floor_y + 0.9, sign * 4.5), (0, floor_y + 2.4, sign * 5.5), 0.3, 0.2, "wood", 8)
        add_ellipsoid(mesh, (0, floor_y + 2.6, sign * 5.7), (0.45, 0.5, 0.6), "gold", slices=8, stacks=5)
        add_ellipsoid(mesh, (0, floor_y + 2.75, sign * 6.1), (0.16, 0.16, 0.2), "ink", slices=6, stacks=3)
    # Four benches, back to back around the mast (seat tops at y = floor_y + 0.65).
    for z in (-3.4, -1.9, 1.9, 3.4):
        add_box(mesh, (0, floor_y + 0.5, z), (3.6, 0.3, 0.9), "mint")
        add_box(mesh, (0, floor_y + 0.3, z), (3.2, 0.3, 0.7), "wood")
    # Mast hooked to the axle, with a striped sail and a flag.
    add_cylinder_between(mesh, (0, floor_y + 0.2, 0), (0, -0.4, 0), 0.2, 0.16, "wood", 8)
    stripe = 4
    for index in range(stripe):
        x0 = -1.5 + 3.0 * index / stripe
        x1 = -1.5 + 3.0 * (index + 1) / stripe
        add_plane(mesh, [(x0, -1.5, 0.02), (x1, -1.5, 0.02), (x1 * 0.85, -5.6, 0.02), (x0 * 0.85, -5.6, 0.02)], "coral" if index % 2 == 0 else "cream")
    add_star(mesh, -0.9, 0.0001 + 0.45, "gold")
    return mesh


def make_haunted_house(v2: bool = False) -> Mesh:
    """A crooked storybook mansion (front, with the door, is -Z): gabled roof, round tower, chimney, porch.

    The V2 variant puts the tower star on the tower tip instead of at the origin."""
    mesh = Mesh("ParkParkHauntedHouseV2" if v2 else "ParkParkHauntedHouse")
    add_box(mesh, (0, 0.3, 0), (12.8, 0.6, 9.8), "wood")
    add_box(mesh, (0, 3.6, 0), (12.0, 6.0, 9.0), "mint")
    add_box(mesh, (0, 0.9, -4.55), (12.2, 0.6, 0.2), "faded_mint")
    # Gabled roof over the main block, ridge along Z, with gable ends filled in.
    for sign in (-1, 1):
        add_slab(
            mesh,
            [
                (sign * 6.5, 6.2, -4.9),
                (0.0, 9.5, -4.9),
                (0.0, 9.85, -4.9),
                (sign * 6.6, 6.55, -4.9),
                (sign * 6.5, 6.2, 4.9),
                (0.0, 9.5, 4.9),
                (0.0, 9.85, 4.9),
                (sign * 6.6, 6.55, 4.9),
            ],
            "ink",
        )
    for z in (-4.5, 4.5):
        add_slab(
            mesh,
            [(-6.0, 6.0, z - 0.1), (6.0, 6.0, z - 0.1), (0.0, 9.4, z - 0.1), (0.0, 9.4, z - 0.1), (-6.0, 6.0, z + 0.1), (6.0, 6.0, z + 0.1), (0.0, 9.4, z + 0.1), (0.0, 9.4, z + 0.1)],
            "faded_mint",
        )
    # Round tower with a pointed cap, and a chimney with smoke puffs.
    lathe(
        mesh,
        [
            (0.0, 0.6, "wood"),
            (1.9, 0.6, "wood"),
            (1.75, 1.0, "faded_mint"),
            (1.7, 11.0, "mint"),
            (2.1, 11.2, "gold"),
            (2.2, 11.5, "ink"),
            (1.0, 13.6, "ink"),
            (0.0, 15.4, "ink"),
        ],
        20,
        transform=lambda x, y, z: (x + 5.4, y, z - 1.5),
    )
    add_star(mesh, 15.9, 0.35, "gold", *((5.4, -1.5) if v2 else (0.0, 0.0)))
    add_box(mesh, (-3.9, 9.9, 1.3), (1.3, 3.0, 1.3), "wood")
    add_box(mesh, (-3.9, 11.5, 1.3), (1.6, 0.25, 1.6), "gold")
    for x, y, z, r in ((-3.9, 12.3, 1.3, 0.5), (-3.6, 13.1, 1.4, 0.65), (-3.2, 14.1, 1.5, 0.75)):
        add_ellipsoid(mesh, (x, y, z), (r, r * 0.8, r), "faded_cream", slices=8, stacks=5)
    # Door with a gold arch frame and steps.
    add_box(mesh, (0, 2.2, -4.6), (2.4, 3.6, 0.3), "wood")
    add_box(mesh, (0, 4.15, -4.65), (3.2, 0.4, 0.4), "gold")
    for x in (-1.5, 1.5):
        add_box(mesh, (x, 2.2, -4.65), (0.35, 3.8, 0.4), "gold")
    add_ellipsoid(mesh, (0, 4.1, -4.7), (1.3, 0.55, 0.3), "gold", slices=10, stacks=4)
    add_ellipsoid(mesh, (0.7, 2.1, -4.8), (0.13, 0.13, 0.1), "gold", slices=6, stacks=4)
    for index, (width, y) in enumerate(((3.6, 0.15), (3.0, 0.35), (2.6, 0.55))):
        add_box(mesh, (0, y + 0.1, -5.3 - (2 - index) * 0.6 + 0.0), (width, 0.2, 0.7), "faded_cream")
    # Four glowing windows with gold frames on the front, two more on each side.
    for x in (-3.9, 3.9):
        for y in (2.9, 5.0):
            add_box(mesh, (x, y, -4.55), (1.9, 1.9, 0.2), "gold")
            add_box(mesh, (x, y, -4.65), (1.5, 1.5, 0.2), "dark_glass")
            add_box(mesh, (x, y, -4.72), (1.5, 0.12, 0.1), "gold")
            add_box(mesh, (x, y, -4.72), (0.12, 1.5, 0.1), "gold")
    for side in (-1, 1):
        for z in (-1.5, 1.8):
            add_box(mesh, (side * 6.05, 3.6, z), (0.2, 1.9, 1.9), "gold")
            add_box(mesh, (side * 6.15, 3.6, z), (0.2, 1.5, 1.5), "dark_glass")
    # A crooked little fence and two gravestones out front.
    for x in (-5.8, -4.6, -3.4, 3.4, 4.6, 5.8):
        add_box(mesh, (0, 0, 0), (0.35, 1.4, 0.35), "wood", tilted_transform((x, 0.9, -6.8), 0, 6 if x > 0 else -6))
    add_box(mesh, (-5.2, 0.6, -6.8), (3.4, 0.2, 0.2), "wood")
    add_box(mesh, (5.2, 0.6, -6.8), (3.4, 0.2, 0.2), "wood")
    return mesh


COASTER_CONTROL_POINTS = [
    # x, height, z: the station straight runs along +X on the south side, then the lift climbs round the
    # east end, the train crests on the north side, dips and climbs a second hill, and returns by the west.
    (-8.0, 1.2, -8.0),
    (0.0, 1.2, -8.0),
    (8.0, 1.2, -8.0),
    (14.0, 3.0, -6.0),
    (17.5, 8.0, 0.0),
    (14.0, 14.0, 7.0),
    (6.0, 15.0, 9.0),
    (-2.0, 7.0, 9.0),
    (-8.0, 3.0, 8.5),
    (-14.0, 9.0, 9.0),
    (-19.0, 6.0, 4.0),
    (-18.0, 3.0, -2.0),
    (-14.0, 2.0, -6.5),
]
COASTER_SAMPLES = 160
COASTER_STATION_POINT = 1
COASTER_LIFT_START_POINT = 3
COASTER_LIFT_END_POINT = 6
COASTER_GAUGE = 0.75


def coaster_path() -> tuple[list[tuple[float, float, float]], dict[str, int]]:
    """Sample the closed Catmull-Rom loop through the control points at equal arc length."""
    control = COASTER_CONTROL_POINTS
    count = len(control)
    dense: list[tuple[float, float, float]] = []
    dense_control: list[int] = []
    for index in range(count):
        p0, p1, p2, p3 = (control[(index + offset) % count] for offset in (-1, 0, 1, 2))
        for step in range(40):
            t = step / 40
            point = tuple(
                0.5
                * (
                    2 * p1[axis]
                    + (-p0[axis] + p2[axis]) * t
                    + (2 * p0[axis] - 5 * p1[axis] + 4 * p2[axis] - p3[axis]) * t * t
                    + (-p0[axis] + 3 * p1[axis] - 3 * p2[axis] + p3[axis]) * t**3
                )
                for axis in range(3)
            )
            dense.append(point)
            dense_control.append(index)
    lengths = [0.0]
    for index in range(len(dense)):
        a, b = dense[index], dense[(index + 1) % len(dense)]
        lengths.append(lengths[-1] + math.dist(a, b))
    total = lengths[-1]
    samples: list[tuple[float, float, float]] = []
    marks: dict[str, int] = {}
    cursor = 0
    for sample in range(COASTER_SAMPLES):
        target = total * sample / COASTER_SAMPLES
        while lengths[cursor + 1] < target:
            cursor += 1
        a, b = dense[cursor], dense[(cursor + 1) % len(dense)]
        span = lengths[cursor + 1] - lengths[cursor]
        fraction = 0.0 if span == 0 else (target - lengths[cursor]) / span
        samples.append(tuple(a[axis] + (b[axis] - a[axis]) * fraction for axis in range(3)))
        for name, point_index in (
            ("station", COASTER_STATION_POINT),
            ("liftStart", COASTER_LIFT_START_POINT),
            ("liftEnd", COASTER_LIFT_END_POINT),
        ):
            if dense_control[cursor] == point_index and name not in marks:
                marks[name] = sample
    return samples, marks


def make_coaster_track(v2: bool = False) -> Mesh:
    """Rails, ties, chain teeth on the lift, supports, and a striped station; origin is the ground centre."""
    mesh = Mesh("ParkParkCoasterTrackV2" if v2 else "ParkParkCoasterTrack")
    samples, marks = coaster_path()
    count = len(samples)
    for index in range(count):
        here, following = samples[index], samples[(index + 1) % count]
        tangent = tuple(following[axis] - here[axis] for axis in range(3))
        flat = math.hypot(tangent[0], tangent[2]) or 1.0
        lateral = (tangent[2] / flat, 0.0, -tangent[0] / flat)
        for side in (-1, 1):
            start = tuple(here[axis] + lateral[axis] * COASTER_GAUGE * side for axis in range(3))
            end = tuple(following[axis] + lateral[axis] * COASTER_GAUGE * side for axis in range(3))
            add_cylinder_between(mesh, start, end, 0.13, 0.13, "coral", 5)
        if index % 2 == 0:
            add_cylinder_between(
                mesh,
                tuple(here[axis] - lateral[axis] * (COASTER_GAUGE + 0.1) for axis in range(3)),
                tuple(here[axis] + lateral[axis] * (COASTER_GAUGE + 0.1) for axis in range(3)),
                0.07,
                0.07,
                "wood",
                4,
            )
        if marks["liftStart"] <= index <= marks["liftEnd"] and index % 2 == 0:
            add_box(mesh, (here[0], here[1] + 0.12, here[2]), (0.5, 0.14, 0.18), "gold")
        if index % 6 == 0 and here[1] > 2.2:
            add_cylinder_between(mesh, (here[0], 0.1, here[2]), (here[0], here[1] - 0.15, here[2]), 0.2, 0.16, "cream", 6)
            add_box(mesh, (here[0], 0.15, here[2]), (0.8, 0.3, 0.8), "gold")
    # Station: platform along the straight, four posts, and a striped roof.
    add_box(mesh, (0, 0.35, -8.0), (20.0, 0.7, 4.4), "cream")
    add_box(mesh, (0, 0.72, -8.0), (20.4, 0.1, 4.8), "gold")
    for x in (-9.0, -3.0, 3.0, 9.0):
        for z in (-9.8, -6.2):
            add_cylinder_between(mesh, (x, 0.7, z), (x, 4.6, z), 0.16, 0.16, "gold", 6)
    stripes = 8
    for index in range(stripes):
        x0 = -10.5 + 21.0 * index / stripes
        x1 = -10.5 + 21.0 * (index + 1) / stripes
        add_slab(
            mesh,
            [
                (x0, 4.5, -10.3),
                (x1, 4.5, -10.3),
                (x1, 4.65, -10.3),
                (x0, 4.65, -10.3),
                (x0, 5.3, -5.7),
                (x1, 5.3, -5.7),
                (x1, 5.45, -5.7),
                (x0, 5.45, -5.7),
            ],
            "coral" if index % 2 == 0 else "cream",
        )
    add_star(mesh, 6.3, 0.5, "gold", *((0.0, -8.0) if v2 else (0.0, 0.0)))
    return mesh


def make_coaster_car() -> Mesh:
    """One coaster car (origin at rail level, centred under the body); symmetric front to back, two rows of two."""
    mesh = Mesh("ParkParkCoasterCar")
    add_box(mesh, (0, 0.3, 0), (1.9, 0.5, 3.0), "coral")
    for x in (-0.82, 0.82):
        for z in (-1.0, 1.0):
            add_cylinder_between(mesh, (x - 0.12, 0.05, z), (x + 0.12, 0.05, z), 0.26, 0.26, "ink", 8)
    for x in (-1.0, 1.0):
        add_box(mesh, (x, 0.85, 0), (0.14, 0.9, 2.9), "coral")
        add_box(mesh, (x, 1.33, 0), (0.2, 0.1, 3.0), "gold")
    for z in (-0.65, 0.65):
        add_box(mesh, (0, 0.72, z), (1.7, 0.28, 0.9), "mint")
    for z in (-1.6, 1.6):
        add_ellipsoid(mesh, (0, 0.6, z), (0.75, 0.5, 0.42), "gold", slices=10, stacks=5)
    return mesh


def write_coaster_path() -> None:
    samples, marks = coaster_path()
    lines = [
        "--!strict",
        "",
        "-- Generated by tools/generate_parkpark_meshes.py: the roller coaster's centre line in unscaled OBJ units",
        "-- (x, height, z), sampled at equal arc length round the closed loop. Do not edit by hand.",
        "return {",
        f"\tStationIndex = {marks['station'] + 1},",
        f"\tLiftStartIndex = {marks['liftStart'] + 1},",
        f"\tLiftEndIndex = {marks['liftEnd'] + 1},",
        "\tPoints = {",
    ]
    for x, y, z in samples:
        lines.append(f"\t\tVector3.new({x:.4f}, {y:.4f}, {z:.4f}),")
    lines += ["\t},", "}", ""]
    (ROOT / "src" / "shared" / "Config" / "CoasterPath.luau").write_text("\n".join(lines), encoding="utf-8", newline="\n")


def make_decor_tree() -> Mesh:
    """A round storybook tree (origin at the base of the trunk): tapered trunk, lumpy canopy, a few fruits."""
    mesh = Mesh("ParkParkDecorTree")
    lathe(mesh, [(0.0, 0.0, "wood"), (0.66, 0.0, "wood"), (0.52, 1.4, "wood"), (0.42, 3.4, "wood"), (0.0, 3.4, "wood")], 12)
    add_ellipsoid(mesh, (0, 5.0, 0), (2.7, 2.2, 2.7), "mint", slices=12, stacks=6)
    add_ellipsoid(mesh, (1.5, 6.0, 0.6), (1.9, 1.7, 1.9), "mint", slices=10, stacks=5)
    add_ellipsoid(mesh, (-1.4, 6.3, -0.7), (1.8, 1.6, 1.8), "mint", slices=10, stacks=5)
    add_ellipsoid(mesh, (0.2, 7.1, -0.3), (1.5, 1.2, 1.5), "mint", slices=10, stacks=5)
    for x, y, z in ((2.2, 4.6, 1.2), (-2.3, 5.0, -0.4), (0.6, 3.9, -2.3), (-0.8, 6.9, 1.4), (1.9, 6.6, -1.1)):
        add_ellipsoid(mesh, (x, y, z), (0.24, 0.24, 0.24), "coral", slices=6, stacks=4)
    return mesh


def make_decor_bush() -> Mesh:
    mesh = Mesh("ParkParkDecorBush")
    add_ellipsoid(mesh, (0, 0.85, 0), (1.5, 1.0, 1.4), "mint", slices=10, stacks=5)
    add_ellipsoid(mesh, (1.1, 0.6, 0.5), (1.0, 0.7, 1.0), "mint", slices=9, stacks=5)
    add_ellipsoid(mesh, (-1.0, 0.55, -0.3), (0.9, 0.65, 0.9), "mint", slices=9, stacks=5)
    for x, y, z, material in ((0.5, 1.7, 0.4, "coral"), (-0.6, 1.5, -0.5, "gold"), (1.5, 1.2, 0.9, "coral"), (-1.4, 1.1, -0.4, "gold")):
        add_ellipsoid(mesh, (x, y, z), (0.2, 0.2, 0.2), material, slices=6, stacks=4)
    return mesh


def make_decor_lamp() -> Mesh:
    """A gaslight-style lamp post with a cream lantern and a coral cap (origin at the base)."""
    mesh = Mesh("ParkParkDecorLamp")
    lathe(
        mesh,
        [
            (0.0, 0.0, "wood"),
            (0.75, 0.0, "wood"),
            (0.55, 0.45, "gold"),
            (0.3, 0.8, "cream"),
            (0.22, 5.2, "cream"),
            (0.42, 5.4, "gold"),
            (0.0, 5.4, "gold"),
        ],
        14,
    )
    add_box(mesh, (0, 6.15, 0), (0.95, 1.3, 0.95), "cream")
    for x, z in ((-0.5, -0.5), (0.5, -0.5), (-0.5, 0.5), (0.5, 0.5)):
        add_cylinder_between(mesh, (x, 5.5, z), (x, 6.8, z), 0.06, 0.06, "gold", 5)
    lathe(mesh, [(0.85, 6.8, "coral"), (0.0, 7.6, "coral")], 8)
    add_ellipsoid(mesh, (0, 7.75, 0), (0.16, 0.16, 0.16), "gold", slices=6, stacks=4)
    return mesh


def make_decor_bench() -> Mesh:
    """A park bench (front, where sitters look, is -Z; origin at the ground centre)."""
    mesh = Mesh("ParkParkDecorBench")
    for z in (-0.36, 0.0, 0.36):
        add_box(mesh, (0, 0.95, z), (2.8, 0.12, 0.3), "wood")
    for y in (1.5, 1.85):
        add_box(mesh, (0, y, 0.6), (2.8, 0.26, 0.1), "wood")
    for x in (-1.3, 1.3):
        add_box(mesh, (x, 0.5, 0.0), (0.16, 1.0, 1.1), "coral")
        add_box(mesh, (x, 1.1, 0.0), (0.2, 0.12, 1.1), "gold")
        add_box(mesh, (x, 1.7, 0.6), (0.16, 1.0, 0.16), "coral")
    return mesh


def make_decor_fountain() -> Mesh:
    """A three-tier plaza fountain with a coral rim and a gold finial (origin at the ground centre)."""
    mesh = Mesh("ParkParkDecorFountain")
    add_vertical_cylinder(mesh, 4.4, 0.0, 0.9, "cream", 40)
    add_vertical_cylinder(mesh, 4.5, 0.55, 1.05, "coral", 40)
    add_torus(mesh, 4.45, 0.13, 1.08, "gold", segments=40, sides=6)
    add_vertical_cylinder(mesh, 3.95, 0.86, 0.9, "dark_glass", 40)
    lathe(
        mesh,
        [
            (0.0, 0.88, "cream"),
            (1.1, 0.88, "cream"),
            (0.75, 1.6, "gold"),
            (0.45, 2.6, "cream"),
            (1.7, 2.75, "coral"),
            (1.45, 3.1, "cream"),
            (0.35, 3.2, "cream"),
            (0.3, 4.2, "gold"),
            (0.0, 4.4, "gold"),
        ],
        24,
    )
    add_star(mesh, 4.9, 0.4, "gold")
    return mesh


def make_decor_flowers() -> Mesh:
    """A round flower bed (origin at the ground centre): a stone rim, soil, and a crowd of blooms on stems."""
    mesh = Mesh("ParkParkDecorFlowers")
    add_vertical_cylinder(mesh, 2.4, 0.0, 0.5, "cream", 24)
    add_vertical_cylinder(mesh, 2.1, 0.45, 0.55, "wood", 24)
    add_torus(mesh, 2.3, 0.12, 0.52, "gold", segments=24, sides=6)
    materials = ("coral", "gold", "cream", "mint", "coral")
    for index in range(16):
        angle = TAU * index / 16 * 2.3
        radius = 0.4 + 1.55 * ((index * 7) % 16) / 16
        x, z = radius * math.cos(angle), radius * math.sin(angle)
        height = 0.95 + 0.35 * ((index * 5) % 4) / 3
        add_cylinder_between(mesh, (x, 0.5, z), (x, height, z), 0.04, 0.04, "mint", 4)
        add_ellipsoid(mesh, (x, height + 0.1, z), (0.28, 0.2, 0.28), materials[index % 5], slices=7, stacks=4)
        add_ellipsoid(mesh, (x, height + 0.2, z), (0.1, 0.08, 0.1), "gold", slices=5, stacks=3)
    return mesh


def make_decor_gazebo() -> Mesh:
    """A small garden gazebo (origin at the ground centre): a round floor, six posts, a mint cone roof, and a gold finial."""
    mesh = Mesh("ParkParkDecorGazebo")
    add_vertical_cylinder(mesh, 3.3, 0.0, 0.35, "cream", 24)
    add_torus(mesh, 3.25, 0.1, 0.36, "gold", segments=24, sides=6)
    for index in range(6):
        angle = TAU * index / 6
        x, z = 2.7 * math.cos(angle), 2.7 * math.sin(angle)
        add_vertical_cylinder(mesh, 0.16, 0.35, 3.6, "coral", 8, x, z)
    for index in range(6):
        angle = TAU * (index + 0.5) / 6
        add_ellipsoid(mesh, (2.7 * math.cos(angle), 1.0, 2.7 * math.sin(angle)), (0.25, 0.25, 0.25), "mint", slices=6, stacks=4)
    add_torus(mesh, 2.75, 0.12, 3.6, "gold", segments=24, sides=6)
    lathe(mesh, [(3.4, 3.7, "mint"), (2.2, 4.4, "cream"), (1.0, 5.3, "mint"), (0.0, 6.0, "cream")], 18)
    add_ellipsoid(mesh, (0, 6.2, 0), (0.28, 0.4, 0.28), "gold", slices=8, stacks=5)
    add_box(mesh, (0, 0.9, 0), (1.6, 0.14, 0.7), "wood")
    return mesh


def make_decor_statue() -> Mesh:
    """A park mascot statue (origin at the ground centre): a stepped pedestal and a round gold-and-coral mascot with ears."""
    mesh = Mesh("ParkParkDecorStatue")
    add_box(mesh, (0, 0.3, 0), (3.2, 0.6, 3.2), "cream")
    add_box(mesh, (0, 0.95, 0), (2.4, 0.7, 2.4), "mint")
    add_box(mesh, (0, 1.4, 0), (2.7, 0.2, 2.7), "gold")
    add_ellipsoid(mesh, (0, 2.5, 0), (0.95, 1.05, 0.8), "coral", slices=12, stacks=7)
    add_ellipsoid(mesh, (0, 2.45, 0.55), (0.6, 0.7, 0.4), "cream", slices=10, stacks=6)
    add_ellipsoid(mesh, (0, 3.9, 0), (0.75, 0.7, 0.7), "coral", slices=12, stacks=7)
    for side in (-1, 1):
        add_ellipsoid(mesh, (side * 0.5, 4.75, 0), (0.22, 0.55, 0.16), "coral", slices=8, stacks=5)
        add_ellipsoid(mesh, (side * 0.28, 4.0, 0.62), (0.08, 0.1, 0.05), "ink", slices=5, stacks=3)
        add_ellipsoid(mesh, (side * 1.0, 2.7, 0.1), (0.2, 0.55, 0.22), "coral", slices=8, stacks=5)
    add_ellipsoid(mesh, (0, 3.75, 0.68), (0.14, 0.1, 0.08), "ink", slices=6, stacks=4)
    add_star(mesh, 6.0, 0.5, "gold")
    return mesh


def make_decor_balloons() -> Mesh:
    """A weighted bunch of balloons on strings (origin at the base)."""
    mesh = Mesh("ParkParkDecorBalloons")
    add_box(mesh, (0, 0.25, 0), (0.9, 0.5, 0.9), "wood")
    for x, y, z, material in (
        (0.0, 5.6, 0.0, "coral"),
        (1.1, 4.8, 0.5, "gold"),
        (-1.1, 4.9, -0.4, "mint"),
        (0.5, 4.3, -1.0, "cream"),
        (-0.4, 4.4, 1.0, "coral"),
    ):
        add_cylinder_between(mesh, (0, 0.5, 0), (x, y - 0.75, z), 0.03, 0.03, "ink", 4)
        add_ellipsoid(mesh, (x, y, z), (0.62, 0.78, 0.62), material, slices=9, stacks=6)
        add_ellipsoid(mesh, (x, y - 0.82, z), (0.1, 0.09, 0.1), material, slices=5, stacks=3)
    return mesh


FLUME_CONTROL_POINTS = [
    # x, height, z: a log-flume channel on the same plan as the coaster: station straight on the south side,
    # a lift round the east end, a high turn, a long plunge into a splash pool, and a lazy return.
    (-8.0, 1.0, -8.0),
    (0.0, 1.0, -8.0),
    (8.0, 1.0, -8.0),
    (13.0, 2.6, -6.0),
    (16.0, 6.5, 0.0),
    (13.0, 10.5, 6.0),
    (5.0, 11.0, 9.0),
    (-3.0, 6.0, 9.0),
    (-10.0, 2.2, 7.0),
    (-15.0, 1.0, 2.0),
    (-14.0, 1.0, -4.5),
]
FLUME_SAMPLES = 130
FLUME_HALF_WIDTH = 1.2


def track_samples(
    control: list[tuple[float, float, float]],
    station_point: int,
    lift_start_point: int,
    lift_end_point: int,
    sample_count: int,
) -> tuple[list[tuple[float, float, float]], dict[str, int]]:
    """Sample a closed Catmull-Rom loop through control points at equal arc length."""
    count = len(control)
    dense: list[tuple[float, float, float]] = []
    dense_control: list[int] = []
    for index in range(count):
        p0, p1, p2, p3 = (control[(index + offset) % count] for offset in (-1, 0, 1, 2))
        for step in range(40):
            t = step / 40
            point = tuple(
                0.5
                * (
                    2 * p1[axis]
                    + (-p0[axis] + p2[axis]) * t
                    + (2 * p0[axis] - 5 * p1[axis] + 4 * p2[axis] - p3[axis]) * t * t
                    + (-p0[axis] + 3 * p1[axis] - 3 * p2[axis] + p3[axis]) * t**3
                )
                for axis in range(3)
            )
            dense.append(point)
            dense_control.append(index)
    lengths = [0.0]
    for index in range(len(dense)):
        a, b = dense[index], dense[(index + 1) % len(dense)]
        lengths.append(lengths[-1] + math.dist(a, b))
    total = lengths[-1]
    samples: list[tuple[float, float, float]] = []
    marks: dict[str, int] = {}
    cursor = 0
    for sample in range(sample_count):
        target = total * sample / sample_count
        while lengths[cursor + 1] < target:
            cursor += 1
        a, b = dense[cursor], dense[(cursor + 1) % len(dense)]
        span = lengths[cursor + 1] - lengths[cursor]
        fraction = 0.0 if span == 0 else (target - lengths[cursor]) / span
        samples.append(tuple(a[axis] + (b[axis] - a[axis]) * fraction for axis in range(3)))
        for name, point_index in (("station", station_point), ("liftStart", lift_start_point), ("liftEnd", lift_end_point)):
            if dense_control[cursor] == point_index and name not in marks:
                marks[name] = sample
    return samples, marks


def flume_path() -> tuple[list[tuple[float, float, float]], dict[str, int]]:
    return track_samples(FLUME_CONTROL_POINTS, 1, 3, 5, FLUME_SAMPLES)


def write_track_path(file_name: str, what: str, samples: list, marks: dict[str, int]) -> None:
    lines = [
        "--!strict",
        "",
        f"-- Generated by tools/generate_parkpark_meshes.py: the {what}'s centre line in unscaled OBJ units",
        "-- (x, height, z), sampled at equal arc length round the closed loop. Do not edit by hand.",
        "return {",
        f"\tStationIndex = {marks['station'] + 1},",
        f"\tLiftStartIndex = {marks['liftStart'] + 1},",
        f"\tLiftEndIndex = {marks['liftEnd'] + 1},",
        "\tPoints = {",
    ]
    for x, y, z in samples:
        lines.append(f"\t\tVector3.new({x:.4f}, {y:.4f}, {z:.4f}),")
    lines += ["\t},", "}", ""]
    (ROOT / "src" / "shared" / "Config" / file_name).write_text("\n".join(lines), encoding="utf-8", newline="\n")


def channel_segment(
    mesh: Mesh,
    a: tuple[float, float, float],
    b: tuple[float, float, float],
    lateral: tuple[float, float, float],
    l0: float,
    l1: float,
    v0: float,
    v1: float,
    material: str,
) -> None:
    """One solid box of the channel between two path samples, from lateral l0..l1 and height v0..v1."""
    corners = []
    for point in (a, b):
        for lat, vert in ((l0, v0), (l1, v0), (l1, v1), (l0, v1)):
            corners.append(tuple(point[axis] + lateral[axis] * lat + (vert if axis == 1 else 0.0) for axis in range(3)))
    add_slab(mesh, corners, material)


def make_flume_track() -> Mesh:
    """A water channel (striped walls, water surface) with supports and a striped station; origin at the ground centre."""
    mesh = Mesh("ParkParkFlumeTrack")
    samples, marks = flume_path()
    count = len(samples)
    w = FLUME_HALF_WIDTH
    for index in range(count):
        here, following = samples[index], samples[(index + 1) % count]
        tangent = tuple(following[axis] - here[axis] for axis in range(3))
        flat = math.hypot(tangent[0], tangent[2]) or 1.0
        lateral = (tangent[2] / flat, 0.0, -tangent[0] / flat)
        wall = "coral" if (index // 3) % 2 == 0 else "cream"
        channel_segment(mesh, here, following, lateral, -w, w, -0.45, -0.05, "wood")
        channel_segment(mesh, here, following, lateral, -w, w, -0.05, 0.12, "mint")
        channel_segment(mesh, here, following, lateral, -w - 0.3, -w, -0.45, 0.85, wall)
        channel_segment(mesh, here, following, lateral, w, w + 0.3, -0.45, 0.85, wall)
        if marks["liftStart"] <= index <= marks["liftEnd"] and index % 3 == 0:
            for side in (-1, 1):
                add_box(mesh, (here[0] + lateral[0] * side * (w + 0.3), here[1] + 1.0, here[2] + lateral[2] * side * (w + 0.3)), (0.3, 0.3, 0.3), "gold")
        if index % 6 == 0 and here[1] > 2.0:
            add_cylinder_between(mesh, (here[0], 0.1, here[2]), (here[0], here[1] - 0.6, here[2]), 0.22, 0.18, "cream", 6)
            add_box(mesh, (here[0], 0.15, here[2]), (0.9, 0.3, 0.9), "gold")
    # Station: a dock along the straight with posts and a striped roof, like the coaster's.
    add_box(mesh, (0, 0.35, -8.0), (20.0, 0.7, 4.4), "cream")
    add_box(mesh, (0, 0.72, -8.0), (20.4, 0.1, 4.8), "gold")
    for x in (-9.0, -3.0, 3.0, 9.0):
        for z in (-9.8, -6.2):
            add_cylinder_between(mesh, (x, 0.7, z), (x, 4.6, z), 0.16, 0.16, "gold", 6)
    for index in range(8):
        x0 = -10.5 + 21.0 * index / 8
        x1 = -10.5 + 21.0 * (index + 1) / 8
        add_slab(
            mesh,
            [
                (x0, 4.5, -10.3),
                (x1, 4.5, -10.3),
                (x1, 4.65, -10.3),
                (x0, 4.65, -10.3),
                (x0, 5.3, -5.7),
                (x1, 5.3, -5.7),
                (x1, 5.45, -5.7),
                (x0, 5.45, -5.7),
            ],
            "mint" if index % 2 == 0 else "cream",
        )
    # A wave crest on the roof in place of the coaster's star.
    add_ellipsoid(mesh, (0, 5.9, -8.0), (1.6, 0.7, 0.4), "mint", slices=10, stacks=5)
    add_ellipsoid(mesh, (0.9, 6.3, -8.0), (0.8, 0.5, 0.4), "cream", slices=8, stacks=4)
    return mesh


def make_flume_boat() -> Mesh:
    """A round-ended log boat (origin at the water surface under its middle); symmetric front to back."""
    mesh = Mesh("ParkParkFlumeBoat")
    add_box(mesh, (0, 0.05, 0), (1.9, 0.5, 3.2), "wood")
    for sign in (-1, 1):
        add_ellipsoid(mesh, (0, 0.05, sign * 1.6), (0.95, 0.25, 0.55), "wood", slices=10, stacks=4)
        add_ellipsoid(mesh, (0, 0.45, sign * 1.85), (0.5, 0.45, 0.42), "coral", slices=8, stacks=4)
    for x in (-1.0, 1.0):
        add_box(mesh, (x, 0.55, 0), (0.16, 0.7, 3.1), "coral")
        add_box(mesh, (x, 0.95, 0), (0.22, 0.1, 3.2), "gold")
    for z in (-0.7, 0.7):
        add_box(mesh, (0, 0.52, z), (1.7, 0.26, 0.8), "mint")
    return mesh


DROP_TOWER_HEIGHT = 17.0
DROP_SEAT_RADIUS = 2.4


def make_drop_tower() -> Mesh:
    """Round boarding base and a four-post lattice tower with a striped crown; origin at the ground centre."""
    mesh = Mesh("ParkParkDropTower")
    add_vertical_cylinder(mesh, 6.0, 0.05, 0.6, "cream", 40)
    add_vertical_cylinder(mesh, 6.02, 0.05, 0.4, "coral", 40)
    add_torus(mesh, 5.85, 0.12, 0.62, "gold", segments=40, sides=6)
    for index in range(14):
        angle = TAU * index / 14
        add_ellipsoid(mesh, (5.4 * math.cos(angle), 0.76, 5.4 * math.sin(angle)), (0.14, 0.14, 0.14), "gold" if index % 2 else "cream", slices=6, stacks=3)
    post = 0.95
    for x in (-post, post):
        for z in (-post, post):
            add_cylinder_between(mesh, (x, 0.5, z), (x, DROP_TOWER_HEIGHT, z), 0.3, 0.26, "coral" if (x > 0) == (z > 0) else "cream", 8)
    y = 1.6
    while y < DROP_TOWER_HEIGHT:
        for a, b in (((-post, y, -post), (post, y, -post)), ((post, y, -post), (post, y, post)), ((post, y, post), (-post, y, post)), ((-post, y, post), (-post, y, -post))):
            add_cylinder_between(mesh, a, b, 0.11, 0.11, "gold" if int(y / 1.6) % 2 == 0 else "cream", 5)
        y += 1.6
    # Crown: striped roof, a bulb ring, and a star.
    add_box(mesh, (0, DROP_TOWER_HEIGHT + 0.2, 0), (2.9, 0.5, 2.9), "gold")
    segments = 12
    for index in range(segments):
        material = "coral" if index % 2 == 0 else "cream"
        a0, a1 = TAU * index / segments, TAU * (index + 1) / segments
        ring = [(2.6, DROP_TOWER_HEIGHT + 0.45), (1.4, DROP_TOWER_HEIGHT + 1.5), (0.0, DROP_TOWER_HEIGHT + 2.6)]
        ids = [(mesh.vertex((r * math.cos(a0), h, r * math.sin(a0))), mesh.vertex((r * math.cos(a1), h, r * math.sin(a1)))) for r, h in ring]
        for k in range(len(ring) - 1):
            quad = (ids[k][0], ids[k][1], ids[k + 1][1], ids[k + 1][0])
            mesh.face(material, *quad)
            mesh.face(material, *reversed(quad))
    add_star(mesh, DROP_TOWER_HEIGHT + 3.3, 0.45, "gold")
    return mesh


def make_drop_gondola() -> Mesh:
    """The ride car: a ring of eight outward-facing seats around a collar that slides on the tower.

    The origin is the centre of the ring at seat level; the collar leaves room for the tower (half-width 1.25).
    """
    mesh = Mesh("ParkParkDropGondola")
    add_torus(mesh, 1.55, 0.26, 0.0, "cream", segments=24, sides=6)
    add_torus(mesh, 3.1, 0.1, 0.32, "gold", segments=40, sides=5)
    for index in range(8):
        angle = TAU * index / 8
        yaw = -math.degrees(angle)
        cosine, sine = math.cos(angle), math.sin(angle)
        add_box(mesh, (0, 0, 0), (1.6, 0.22, 0.16), "cream", tilted_transform((2.1 * cosine, -0.02, 2.1 * sine), yaw + 90))
        add_box(mesh, (0, 0, 0), (1.0, 0.16, 0.9), "coral", tilted_transform((DROP_SEAT_RADIUS * cosine, 0.12, DROP_SEAT_RADIUS * sine), yaw + 90))
        add_box(mesh, (0, 0, 0), (1.0, 0.95, 0.12), "coral", tilted_transform((1.85 * cosine, 0.62, 1.85 * sine), yaw + 90))
        add_box(mesh, (0, 0, 0), (1.0, 0.1, 0.1), "gold", tilted_transform((2.85 * cosine, 0.62, 2.85 * sine), yaw + 90))
        add_cylinder_between(mesh, (2.85 * cosine, 0.2, 2.85 * sine), (2.85 * cosine, 0.62, 2.85 * sine), 0.05, 0.05, "gold", 4)
    return mesh


def make_gift_shop() -> Mesh:
    """A pastel gift shop (front, with the counter, is -Z): mint walls, a striped awning, a gift-box crest with a bow,
    shelves of presents, and a teddy bear on the counter. Same footprint as the snack stand."""
    mesh = Mesh("ParkParkGiftShop")
    add_box(mesh, (0, 0.1, 0), (6.6, 0.2, 4.2), "wood")
    # Back wall, side panels, and a shelf of presents on the back wall.
    add_box(mesh, (0, 1.7, 1.5), (5.6, 3.0, 0.15), "mint")
    add_box(mesh, (-2.75, 1.7, 0.2), (0.15, 3.0, 2.8), "mint")
    add_box(mesh, (2.75, 1.7, 0.2), (0.15, 3.0, 2.8), "mint")
    for y in (1.3, 2.3):
        add_box(mesh, (0, y, 1.3), (5.0, 0.12, 0.5), "wood")
    for x, y, size, material in (
        (-1.9, 1.62, 0.6, "coral"),
        (-1.0, 1.62, 0.5, "gold"),
        (0.2, 1.62, 0.7, "cream"),
        (1.3, 1.62, 0.5, "coral"),
        (2.0, 1.6, 0.45, "gold"),
        (-1.5, 2.62, 0.55, "cream"),
        (-0.3, 2.64, 0.6, "gold"),
        (1.0, 2.62, 0.5, "coral"),
    ):
        add_box(mesh, (x, y, 1.3), (size, size, size), material)
        add_box(mesh, (x, y + size / 2 + 0.01, 1.3), (size * 0.18, 0.04, size + 0.02), "ink" if material == "cream" else "cream")
    # Counter with a wooden top and mint front panels.
    add_box(mesh, (0, 0.65, -1.1), (5.4, 0.9, 1.0), "coral")
    add_box(mesh, (0, 1.16, -1.1), (5.7, 0.12, 1.3), "wood")
    for x in (-1.8, 0.0, 1.8):
        add_box(mesh, (x, 0.65, -1.62), (1.4, 0.6, 0.06), "mint")
    # Corner posts.
    for x in (-2.85, 2.85):
        for z in (-1.7, 1.6):
            add_vertical_cylinder(mesh, 0.1, 0.2, 3.5, "gold", 10, center_x=x, center_z=z)
    # Striped, sloping awning in mint and cream, with a scalloped front edge.
    stripes = 6
    width = 6.4 / stripes
    for index in range(stripes):
        x0 = -3.2 + index * width
        x1 = x0 + width
        material = "mint" if index % 2 == 0 else "cream"
        add_slab(
            mesh,
            [
                (x0, 3.15, -2.1),
                (x1, 3.15, -2.1),
                (x1, 3.27, -2.1),
                (x0, 3.27, -2.1),
                (x0, 3.7, 1.8),
                (x1, 3.7, 1.8),
                (x1, 3.82, 1.8),
                (x0, 3.82, 1.8),
            ],
            material,
        )
        add_box(mesh, ((x0 + x1) / 2, 3.0, -2.12), (width, 0.32, 0.06), material)
    # Crest: a big gift box on the roof with a gold ribbon and a bow.
    add_box(mesh, (0, 4.55, 0.3), (1.7, 1.4, 1.7), "coral")
    add_box(mesh, (0, 4.55, 0.3), (0.3, 1.42, 1.72), "gold")
    add_box(mesh, (0, 4.55, 0.3), (1.72, 1.42, 0.3), "gold")
    add_box(mesh, (0, 5.3, 0.3), (1.9, 0.25, 1.9), "coral")
    add_ellipsoid(mesh, (-0.45, 5.75, 0.3), (0.5, 0.32, 0.26), "gold", slices=8, stacks=4)
    add_ellipsoid(mesh, (0.45, 5.75, 0.3), (0.5, 0.32, 0.26), "gold", slices=8, stacks=4)
    add_ellipsoid(mesh, (0, 5.7, 0.3), (0.2, 0.2, 0.2), "gold", slices=6, stacks=4)
    add_star(mesh, 6.6, 0.25, "gold")
    # On the counter: a stack of presents (left) and a teddy bear (right).
    add_box(mesh, (-1.6, 1.52, -1.0), (0.9, 0.6, 0.8), "gold")
    add_box(mesh, (-1.6, 2.0, -1.0), (0.65, 0.4, 0.6), "cream")
    add_box(mesh, (-1.6, 2.28, -1.0), (0.4, 0.2, 0.4), "coral")
    add_ellipsoid(mesh, (1.7, 1.55, -1.0), (0.42, 0.45, 0.36), "wood", slices=8, stacks=5)
    add_ellipsoid(mesh, (1.7, 2.1, -1.0), (0.32, 0.3, 0.28), "wood", slices=8, stacks=5)
    for side in (-1, 1):
        add_ellipsoid(mesh, (1.7 + side * 0.25, 2.35, -1.0), (0.11, 0.11, 0.08), "wood", slices=6, stacks=4)
        add_ellipsoid(mesh, (1.7 + side * 0.4, 1.65, -1.0), (0.14, 0.2, 0.14), "wood", slices=6, stacks=4)
    add_ellipsoid(mesh, (1.7, 2.06, -1.25), (0.11, 0.09, 0.06), "cream", slices=6, stacks=4)
    # A barrel of balloons beside the stand.
    add_vertical_cylinder(mesh, 0.42, 0.2, 1.1, "wood", 12, center_x=3.95, center_z=-0.4)
    add_vertical_cylinder(mesh, 0.44, 0.55, 0.65, "gold", 12, center_x=3.95, center_z=-0.4)
    for y, material in ((2.2, "coral"), (1.9, "gold"), (2.4, "mint")):
        add_cylinder_between(mesh, (3.95, 1.1, -0.4), (3.95 + (y - 2.1) * 0.6, y, -0.4), 0.02, 0.02, "ink", 4)
        add_ellipsoid(mesh, (3.95 + (y - 2.1) * 0.6, y + 0.5, -0.4), (0.4, 0.5, 0.4), material, slices=8, stacks=5)
    return mesh


def make_decor_palm() -> Mesh:
    """A leaning palm tree (origin at the base of the trunk): segmented curved trunk, a fan of drooping fronds, coconuts."""
    mesh = Mesh("ParkParkDecorPalm")
    segments = 7
    points = []
    for index in range(segments + 1):
        t = index / segments
        points.append((1.9 * t * t, 8.4 * t, 0.0))
    for index in range(segments):
        radius_a = 0.62 - 0.32 * index / segments
        radius_b = 0.62 - 0.32 * (index + 1) / segments
        add_cylinder_between(mesh, points[index], points[index + 1], radius_a, radius_b, "wood" if index % 2 == 0 else "faded_coral", 8)
    top = points[-1]
    frond_count = 8
    for index in range(frond_count):
        angle = TAU * index / frond_count
        dx, dz = math.cos(angle), math.sin(angle)
        previous = top
        for step in range(1, 5):
            length = 1.15 * step
            droop = -0.32 * step * step * 0.35
            point = (top[0] + dx * length, top[1] + 0.55 + droop, top[2] + dz * length)
            add_cylinder_between(mesh, previous, point, 0.12 - 0.015 * step, 0.1 - 0.015 * step, "mint", 5)
            # Leaflets: flat paddles to each side of the rib.
            for side in (-1, 1):
                leaf = (point[0] - dz * side * 0.55, point[1] - 0.18, point[2] + dx * side * 0.55)
                add_ellipsoid(mesh, ((point[0] + leaf[0]) / 2, (point[1] + leaf[1]) / 2, (point[2] + leaf[2]) / 2), (0.34, 0.07, 0.34), "mint", slices=6, stacks=3)
            previous = point
    for angle in (0.4, 2.2, 4.1):
        add_ellipsoid(mesh, (top[0] + math.cos(angle) * 0.32, top[1] - 0.25, top[2] + math.sin(angle) * 0.32), (0.26, 0.26, 0.26), "wood", slices=7, stacks=4)
    return mesh


def make_decor_umbrella() -> Mesh:
    """A striped beach umbrella over a lounger and towel (origin at the pole's base)."""
    mesh = Mesh("ParkParkDecorUmbrella")
    add_cylinder_between(mesh, (0, 0, 0), (0, 4.6, 0), 0.1, 0.08, "wood", 6)
    segments = 10
    for index in range(segments):
        material = "coral" if index % 2 == 0 else "cream"
        a0, a1 = TAU * index / segments, TAU * (index + 1) / segments
        ring = [(2.5, 3.9), (1.3, 4.5), (0.0, 4.85)]
        ids = [(mesh.vertex((r * math.cos(a0), h, r * math.sin(a0))), mesh.vertex((r * math.cos(a1), h, r * math.sin(a1)))) for r, h in ring]
        for k in range(len(ring) - 1):
            quad = (ids[k][0], ids[k][1], ids[k + 1][1], ids[k + 1][0])
            mesh.face(material, *quad)
            mesh.face(material, *reversed(quad))
    add_ellipsoid(mesh, (0, 4.95, 0), (0.14, 0.14, 0.14), "gold", slices=6, stacks=4)
    # Lounger: frame, striped cushion, and a raised back.
    add_box(mesh, (1.9, 0.45, 0), (2.4, 0.12, 0.9), "wood")
    add_box(mesh, (1.9, 0.6, 0), (2.3, 0.16, 0.85), "mint")
    add_box(mesh, (3.15, 0.95, 0), (0.12, 0.9, 0.85), "mint", tilted_transform((3.1, 0.9, 0), 0, 35))
    for x in (0.9, 2.9):
        for z in (-0.35, 0.35):
            add_box(mesh, (x, 0.2, z), (0.1, 0.4, 0.1), "wood")
    add_box(mesh, (-1.2, 0.04, 1.4), (1.5, 0.05, 0.9), "gold", tilted_transform((-1.2, 0.05, 1.4), 25))
    return mesh


def make_decor_pond() -> Mesh:
    """A round pond with a sand rim, a lily pad or two, and a few stones (origin at the ground centre)."""
    mesh = Mesh("ParkParkDecorPond")
    add_vertical_cylinder(mesh, 6.4, 0.0, 0.32, "cream", 36)
    add_vertical_cylinder(mesh, 5.6, 0.0, 0.34, "mint", 36)
    add_torus(mesh, 5.7, 0.2, 0.34, "faded_cream", segments=36, sides=6)
    for x, z, r in ((-1.6, 1.2, 0.8), (1.8, -1.0, 0.65), (0.4, 2.6, 0.55)):
        add_vertical_cylinder(mesh, r, 0.34, 0.4, "faded_mint", 10, center_x=x, center_z=z)
    add_ellipsoid(mesh, (-1.6, 0.55, 1.2), (0.2, 0.18, 0.2), "coral", slices=6, stacks=4)
    add_ellipsoid(mesh, (1.8, 0.5, -1.0), (0.16, 0.14, 0.16), "gold", slices=6, stacks=4)
    for angle, radius in ((0.3, 6.4), (1.4, 6.6), (2.6, 6.4), (3.9, 6.6), (5.1, 6.5)):
        add_ellipsoid(mesh, (radius * math.cos(angle), 0.35, radius * math.sin(angle)), (0.7, 0.45, 0.6), "faded_cream", slices=7, stacks=4)
    return mesh


def make_decor_sandcastle() -> Mesh:
    """A small sandcastle with towers, a gate, and pennants (origin at the ground centre)."""
    mesh = Mesh("ParkParkDecorSandcastle")
    add_vertical_cylinder(mesh, 3.2, 0.0, 0.5, "cream", 24)
    add_box(mesh, (0, 1.2, 0), (3.0, 1.4, 3.0), "gold")
    add_box(mesh, (0, 2.2, 0), (2.0, 0.7, 2.0), "cream")
    for x, z, height in ((-1.9, -1.9, 2.4), (1.9, -1.9, 2.0), (-1.9, 1.9, 2.0), (1.9, 1.9, 2.6)):
        add_vertical_cylinder(mesh, 0.7, 0.4, height, "gold", 10, center_x=x, center_z=z)
        lathe(mesh, [(0.85, height, "cream"), (0.0, height + 0.9, "coral")], 10, transform=lambda a, b, c, x=x, z=z: (a + x, b, c + z))
    add_box(mesh, (0, 0.8, -1.55), (0.9, 1.0, 0.2), "ink")
    add_cylinder_between(mesh, (0, 2.55, 0), (0, 4.0, 0), 0.05, 0.04, "wood", 4)
    add_box(mesh, (0.35, 3.75, 0), (0.7, 0.4, 0.05), "coral")
    for x, z in ((-2.7, 0.4), (2.6, -0.5), (0.5, 2.8)):
        add_ellipsoid(mesh, (x, 0.35, z), (0.3, 0.2, 0.3), "coral", slices=6, stacks=4)
    return mesh


TRAIN_CONTROL_POINTS = [
    # x, height, z: a small loop for the kids' train: station straight on the south side, a gentle rise round the
    # east end, a low rolling run along the back, and a bend home on the west.
    (-8.0, 0.5, -6.0),
    (0.0, 0.5, -6.0),
    (8.0, 0.5, -6.0),
    (13.0, 0.9, -3.0),
    (14.5, 2.2, 3.0),
    (10.0, 2.5, 8.0),
    (2.0, 1.6, 9.5),
    (-8.0, 0.7, 8.5),
    (-14.0, 0.5, 3.0),
    (-14.0, 0.5, -2.5),
]
TRAIN_SAMPLES = 100
TRAIN_GAUGE = 0.8


def train_path() -> tuple[list[tuple[float, float, float]], dict[str, int]]:
    return track_samples(TRAIN_CONTROL_POINTS, 1, 3, 5, TRAIN_SAMPLES)


def make_train_track(v2: bool = False) -> Mesh:
    """Rails on a gravel bed with wooden ties, small flower beds along the way, and a striped station."""
    mesh = Mesh("ParkParkTrainTrackV2" if v2 else "ParkParkTrainTrack")
    samples, marks = train_path()
    count = len(samples)
    w = TRAIN_GAUGE
    for index in range(count):
        here, following = samples[index], samples[(index + 1) % count]
        tangent = tuple(following[axis] - here[axis] for axis in range(3))
        flat = math.hypot(tangent[0], tangent[2]) or 1.0
        lateral = (tangent[2] / flat, 0.0, -tangent[0] / flat)
        channel_segment(mesh, here, following, lateral, -w - 0.55, w + 0.55, -0.35, -0.02, "faded_cream")
        for side in (-1, 1):
            start = tuple(here[axis] + lateral[axis] * w * side for axis in range(3))
            end = tuple(following[axis] + lateral[axis] * w * side for axis in range(3))
            add_cylinder_between(mesh, start, end, 0.1, 0.1, "coral", 5)
        if index % 2 == 0:
            add_cylinder_between(
                mesh,
                tuple(here[axis] - lateral[axis] * (w + 0.2) for axis in range(3)),
                tuple(here[axis] + lateral[axis] * (w + 0.2) for axis in range(3)),
                0.07,
                0.07,
                "wood",
                4,
            )
    # Little flower beds on the inside of the loop.
    for x, z, material in ((-3.0, 2.5, "coral"), (0.0, 3.5, "gold"), (3.0, 2.0, "coral"), (6.0, 4.0, "gold")):
        add_ellipsoid(mesh, (x, 0.2, z), (1.0, 0.35, 0.8), "mint", slices=8, stacks=4)
        for dx, dz in ((-0.4, 0.0), (0.3, 0.2), (0.0, -0.3)):
            add_ellipsoid(mesh, (x + dx, 0.55, z + dz), (0.16, 0.16, 0.16), material, slices=6, stacks=3)
    # Station: a low platform, four posts, and a striped roof.
    add_box(mesh, (0, 0.2, -8.2), (16.0, 0.4, 2.6), "cream")
    add_box(mesh, (0, 0.42, -8.2), (16.4, 0.08, 2.9), "gold")
    for x in (-7.0, -2.3, 2.3, 7.0):
        for z in (-9.3, -7.1):
            add_cylinder_between(mesh, (x, 0.4, z), (x, 3.4, z), 0.14, 0.14, "gold", 6)
    for index in range(8):
        x0 = -8.4 + 16.8 * index / 8
        x1 = -8.4 + 16.8 * (index + 1) / 8
        add_slab(
            mesh,
            [
                (x0, 3.3, -9.7),
                (x1, 3.3, -9.7),
                (x1, 3.42, -9.7),
                (x0, 3.42, -9.7),
                (x0, 3.9, -6.7),
                (x1, 3.9, -6.7),
                (x1, 4.02, -6.7),
                (x0, 4.02, -6.7),
            ],
            "coral" if index % 2 == 0 else "cream",
        )
    add_star(mesh, 4.7, 0.4, "gold", *((0.0, -8.2) if v2 else (0.0, 0.0)))
    return mesh


def make_train_car() -> Mesh:
    """A small open wagon with a steam funnel between its two benches (origin at rail level); symmetric front to back."""
    mesh = Mesh("ParkParkTrainCar")
    add_box(mesh, (0, 0.3, 0), (2.0, 0.4, 3.6), "coral")
    for x in (-0.85, 0.85):
        for z in (-1.1, 1.1):
            add_cylinder_between(mesh, (x - 0.1, 0.12, z), (x + 0.1, 0.12, z), 0.24, 0.24, "ink", 8)
    for sign in (-1, 1):
        add_ellipsoid(mesh, (0, 0.35, sign * 1.85), (0.9, 0.3, 0.45), "gold", slices=8, stacks=4)
    for x in (-1.0, 1.0):
        add_box(mesh, (x, 0.8, 0), (0.12, 0.6, 3.4), "coral")
        add_box(mesh, (x, 1.12, 0), (0.18, 0.08, 3.5), "gold")
    for z in (-0.85, 0.85):
        add_box(mesh, (0, 0.62, z), (1.7, 0.24, 0.8), "mint")
    add_cylinder_between(mesh, (0, 0.5, 0), (0, 1.5, 0), 0.2, 0.26, "gold", 8)
    add_ellipsoid(mesh, (0, 1.55, 0), (0.34, 0.14, 0.34), "ink", slices=8, stacks=3)
    return mesh


def make_duck_hub() -> Mesh:
    """Rotating duck-pond deck: a mint pond ring, a lighthouse-style column, and a turntable per duck."""
    mesh = Mesh("ParkParkDuckHub")
    add_vertical_cylinder(mesh, 8.6, 0.0, 0.62, "cream", 48)
    add_vertical_cylinder(mesh, 8.62, 0.0, 0.5, "gold", 48)
    add_vertical_cylinder(mesh, 7.9, 0.5, 0.7, "mint", 48)
    add_torus(mesh, 8.4, 0.14, 0.72, "coral", segments=48, sides=6)
    lathe(
        mesh,
        [
            (0.0, 0.7, "wood"),
            (1.5, 0.7, "wood"),
            (1.1, 1.3, "gold"),
            (0.8, 1.7, "cream"),
            (0.7, 3.6, "coral"),
            (0.85, 3.7, "cream"),
            (0.7, 4.4, "coral"),
            (0.95, 4.55, "gold"),
            (0.0, 5.6, "coral"),
        ],
        28,
    )
    add_ellipsoid(mesh, (0, 6.0, 0), (0.5, 0.5, 0.5), "gold", slices=10, stacks=6)
    for index in range(6):
        angle = TAU * index / 6
        x, z = 5.6 * math.cos(angle), 5.6 * math.sin(angle)
        add_cylinder_between(mesh, (0, 0.95, 0), (x, 0.95, z), 0.2, 0.2, "coral", 8)
        add_vertical_cylinder(mesh, 1.9, 0.62, 0.96, "gold", 28, x, z)
        add_vertical_cylinder(mesh, 1.6, 0.96, 1.04, "cream", 28, x, z)
    return mesh


def make_duck() -> Mesh:
    """One duck in a swim ring (base at y=0): a guest sits on its back (seat surface at about y=1.75)."""
    mesh = Mesh("ParkParkDuck")
    add_torus(mesh, 1.5, 0.34, 0.34, "mint", segments=28, sides=8)
    add_torus(mesh, 1.5, 0.12, 0.62, "cream", segments=28, sides=6)
    add_ellipsoid(mesh, (0, 1.0, -0.1), (1.25, 0.85, 1.55), "gold", slices=16, stacks=8)
    # Neck, head, beak, and eyes at the front (+Z).
    add_ellipsoid(mesh, (0, 1.65, 1.05), (0.5, 0.65, 0.5), "gold", slices=10, stacks=6)
    add_ellipsoid(mesh, (0, 2.3, 1.3), (0.58, 0.55, 0.58), "gold", slices=12, stacks=7)
    add_box(mesh, (0, 2.2, 1.95), (0.72, 0.18, 0.62), "coral")
    add_box(mesh, (0, 2.04, 1.9), (0.6, 0.1, 0.5), "coral")
    for side in (-1, 1):
        add_ellipsoid(mesh, (side * 0.3, 2.45, 1.7), (0.1, 0.12, 0.08), "ink", slices=6, stacks=4)
        add_ellipsoid(mesh, (side * 1.12, 1.05, -0.2), (0.22, 0.55, 0.85), "cream", slices=8, stacks=5)
    # Tail tuft and a cushion on the back where the guest sits.
    add_ellipsoid(mesh, (0, 1.45, -1.55), (0.3, 0.4, 0.45), "gold", slices=8, stacks=5)
    add_vertical_cylinder(mesh, 0.85, 1.66, 1.8, "coral", 18, 0.0, -0.25)
    return mesh


def make_bounce_house() -> Mesh:
    """An inflatable bouncy castle (origin at the ground centre): a soft floor, tube walls, corner towers, a gate."""
    mesh = Mesh("ParkParkBounceHouse")
    half = 6.5
    add_box(mesh, (0, 0.5, 0), (half * 2 + 0.6, 1.0, half * 2 + 0.6), "gold")
    add_box(mesh, (0, 1.02, 0), (half * 2 - 1.2, 0.08, half * 2 - 1.2), "mint")
    colors = ("coral", "cream", "coral")
    for side_index, (ax, az) in enumerate(((1, 0), (-1, 0), (0, 1), (0, -1))):
        # Tube walls along each side; the +Z side leaves a gate gap in the middle.
        for row, height in enumerate((1.5, 2.45, 3.4)):
            if az == 0:
                a, b = (ax * half, height, -half), (ax * half, height, half)
                add_cylinder_between(mesh, a, b, 0.48, 0.48, colors[row], 10)
            elif az == -1:
                a, b = (-half, height, -half), (half, height, -half)
                add_cylinder_between(mesh, a, b, 0.48, 0.48, colors[row], 10)
            else:
                add_cylinder_between(mesh, (-half, height, half), (-2.6, height, half), 0.48, 0.48, colors[row], 10)
                add_cylinder_between(mesh, (2.6, height, half), (half, height, half), 0.48, 0.48, colors[row], 10)
    # Soft corner towers with domed tops and pennants.
    for index, (x, z) in enumerate(((-half, -half), (half, -half), (-half, half), (half, half))):
        material = ("mint", "gold", "gold", "mint")[index]
        add_vertical_cylinder(mesh, 1.15, 1.0, 5.0, material, 16, x, z)
        add_ellipsoid(mesh, (x, 5.0, z), (1.25, 1.0, 1.25), "coral", slices=14, stacks=6)
        add_cylinder_between(mesh, (x, 5.8, z), (x, 7.0, z), 0.07, 0.05, "wood", 5)
        add_box(mesh, (x + 0.45, 6.7, z), (0.9, 0.5, 0.06), "cream" if index % 2 else "coral")
    # The gate: a rainbow of two arch posts and a lintel with a star.
    for side in (-1, 1):
        add_vertical_cylinder(mesh, 0.55, 1.0, 4.4, "cream", 12, side * 2.6, half)
    add_box(mesh, (0, 4.6, half), (6.1, 0.9, 1.0), "coral")
    add_box(mesh, (0, 5.4, half), (5.0, 0.6, 0.8), "gold")
    return mesh


MINE_CONTROL_POINTS = [
    # x, height, z: the mine train. A straight station on the south side, a lift round the east end to the crest,
    # a plunge back across the middle, a low hill on the west and a bend home.
    (-8.0, 0.6, -6.0),
    (0.0, 0.6, -6.0),
    (9.0, 0.6, -6.0),
    (15.0, 2.5, -2.0),
    (17.0, 7.0, 5.0),
    (12.0, 11.0, 11.0),
    (3.0, 6.0, 14.0),
    (-6.0, 2.0, 12.0),
    (-13.0, 4.5, 8.0),
    (-17.0, 2.0, 1.0),
    (-14.0, 0.8, -4.0),
]
MINE_SAMPLES = 140
MINE_GAUGE = 0.8

SKY_CONTROL_POINTS = [
    # x, cable height, z: a long oval; the station straight is low and the cable climbs to the far end and back.
    (-8.0, 2.4, -6.0),
    (0.0, 2.2, -6.0),
    (8.0, 2.6, -6.0),
    (12.0, 5.0, 4.0),
    (12.0, 8.5, 16.0),
    (10.0, 9.5, 30.0),
    (4.0, 9.5, 42.0),
    (-4.0, 9.5, 42.0),
    (-10.0, 9.5, 30.0),
    (-12.0, 8.5, 16.0),
    (-12.0, 5.0, 4.0),
]
SKY_SAMPLES = 150


def mine_path() -> tuple[list[tuple[float, float, float]], dict[str, int]]:
    return track_samples(MINE_CONTROL_POINTS, 1, 3, 5, MINE_SAMPLES)


def sky_path() -> tuple[list[tuple[float, float, float]], dict[str, int]]:
    return track_samples(SKY_CONTROL_POINTS, 1, 3, 4, SKY_SAMPLES)


def station_shed(mesh: Mesh, roof_a: str, roof_b: str, post: str) -> None:
    """A low platform with four posts and a striped roof on the south straight (shared by train-like rides)."""
    add_box(mesh, (0, 0.2, -8.2), (16.0, 0.4, 2.6), "cream")
    add_box(mesh, (0, 0.42, -8.2), (16.4, 0.08, 2.9), "gold")
    for x in (-7.0, -2.3, 2.3, 7.0):
        for z in (-9.3, -7.1):
            add_cylinder_between(mesh, (x, 0.4, z), (x, 4.4, z), 0.14, 0.14, post, 6)
    for index in range(8):
        x0 = -8.4 + 16.8 * index / 8
        x1 = -8.4 + 16.8 * (index + 1) / 8
        add_slab(
            mesh,
            [
                (x0, 4.3, -9.7),
                (x1, 4.3, -9.7),
                (x1, 4.42, -9.7),
                (x0, 4.42, -9.7),
                (x0, 4.9, -6.7),
                (x1, 4.9, -6.7),
                (x1, 5.02, -6.7),
                (x0, 5.02, -6.7),
            ],
            roof_a if index % 2 == 0 else roof_b,
        )


def make_mine_track() -> Mesh:
    """A timber mine-train track: dark rails on wooden ties, trestle supports with cross braces, a rock-lined
    station shed; origin at the ground centre."""
    mesh = Mesh("ParkParkMineTrack")
    samples, marks = mine_path()
    count = len(samples)
    for index in range(count):
        here, following = samples[index], samples[(index + 1) % count]
        tangent = tuple(following[axis] - here[axis] for axis in range(3))
        flat = math.hypot(tangent[0], tangent[2]) or 1.0
        lateral = (tangent[2] / flat, 0.0, -tangent[0] / flat)
        for side in (-1, 1):
            start = tuple(here[axis] + lateral[axis] * MINE_GAUGE * side for axis in range(3))
            end = tuple(following[axis] + lateral[axis] * MINE_GAUGE * side for axis in range(3))
            add_cylinder_between(mesh, start, end, 0.12, 0.12, "ink", 5)
        if index % 2 == 0:
            add_cylinder_between(
                mesh,
                tuple(here[axis] - lateral[axis] * (MINE_GAUGE + 0.25) for axis in range(3)),
                tuple(here[axis] + lateral[axis] * (MINE_GAUGE + 0.25) for axis in range(3)),
                0.09,
                0.09,
                "wood",
                4,
            )
        if marks["liftStart"] <= index <= marks["liftEnd"] and index % 3 == 0:
            add_box(mesh, (here[0], here[1] + 0.1, here[2]), (0.4, 0.12, 0.16), "gold")
        if index % 5 == 0 and here[1] > 1.6:
            for side in (-1, 1):
                foot = (here[0] + lateral[0] * 0.7 * side, 0.0, here[2] + lateral[2] * 0.7 * side)
                top = (here[0] + lateral[0] * 0.5 * side, here[1] - 0.1, here[2] + lateral[2] * 0.5 * side)
                add_cylinder_between(mesh, foot, top, 0.17, 0.13, "wood", 5)
            if here[1] > 3.2:
                brace_y = here[1] * 0.5
                add_cylinder_between(
                    mesh,
                    (here[0] - lateral[0] * 0.65, brace_y, here[2] - lateral[2] * 0.65),
                    (here[0] + lateral[0] * 0.65, brace_y + 0.9, here[2] + lateral[2] * 0.65),
                    0.07,
                    0.07,
                    "wood",
                    4,
                )
            add_box(mesh, (here[0], 0.12, here[2]), (1.4, 0.24, 1.4), "faded_cream")
    station_shed(mesh, "wood", "gold", "wood")
    # Rock piles by the station and a hanging lantern.
    for x, z, size in ((-9.4, -11.0, 1.1), (9.6, -11.2, 0.9), (11.2, -9.6, 0.7)):
        add_ellipsoid(mesh, (x, size * 0.6, z), (size, size * 0.75, size * 0.9), "faded_cream", slices=7, stacks=4)
    add_cylinder_between(mesh, (0, 4.3, -8.2), (0, 3.7, -8.2), 0.04, 0.04, "ink", 4)
    add_ellipsoid(mesh, (0, 3.5, -8.2), (0.22, 0.28, 0.22), "gold", slices=8, stacks=4)
    return mesh


def make_mine_car() -> Mesh:
    """A wooden ore cart with iron bands and four seats (origin at rail level); symmetric front to back."""
    mesh = Mesh("ParkParkMineCar")
    add_box(mesh, (0, 0.3, 0), (2.0, 0.4, 3.6), "wood")
    for x in (-0.85, 0.85):
        for z in (-1.1, 1.1):
            add_cylinder_between(mesh, (x - 0.1, 0.12, z), (x + 0.1, 0.12, z), 0.24, 0.24, "ink", 8)
    for x in (-1.0, 1.0):
        add_box(mesh, (x, 0.8, 0), (0.12, 0.6, 3.4), "wood")
        add_box(mesh, (x, 1.12, 0), (0.18, 0.08, 3.5), "ink")
    for z in (-1.75, 1.75):
        add_box(mesh, (0, 0.8, z), (2.0, 0.6, 0.12), "wood")
    for z in (-0.85, 0.85):
        add_box(mesh, (0, 0.62, z), (1.7, 0.24, 0.8), "gold")
    return mesh


def make_sky_track(v2: bool = False) -> Mesh:
    """The sky ride: a steel cable on tall pylons and a low boarding station; origin at the ground centre."""
    mesh = Mesh("ParkParkSkyTrackV2" if v2 else "ParkParkSkyTrack")
    samples, marks = sky_path()
    count = len(samples)
    for index in range(count):
        here, following = samples[index], samples[(index + 1) % count]
        add_cylinder_between(mesh, here, following, 0.07, 0.07, "ink", 5)
    for control in SKY_CONTROL_POINTS[3:]:
        x, y, z = control
        add_cylinder_between(mesh, (x, 0.1, z), (x, y + 0.9, z), 0.28, 0.2, "cream", 8)
        add_box(mesh, (x, 0.12, z), (1.2, 0.24, 1.2), "gold")
        add_box(mesh, (x, y + 0.85, z), (1.4, 0.16, 0.5), "coral")
        add_ellipsoid(mesh, (x, y + 1.05, z), (0.22, 0.22, 0.22), "gold", slices=6, stacks=4)
    station_shed(mesh, "coral", "cream", "gold")
    # A tall entrance mast with a star beside the station.
    add_cylinder_between(mesh, (-9.5, 0.0, -9.0), (-9.5, 7.0, -9.0), 0.2, 0.14, "cream", 8)
    add_star(mesh, 7.6, 0.55, "gold", *((-9.5, -9.0) if v2 else (0.0, 0.0)))
    return mesh


def make_sky_car(v2: bool = False) -> Mesh:
    """A hanging open gondola: an arm up to the cable (origin at the cable), two benches, rails, a striped roof.

    The V2 variant hangs the floor, benches and rails 0.5 units lower so riders' heads clear the roof."""
    mesh = Mesh("ParkParkSkyCarV2" if v2 else "ParkParkSkyCar")
    drop = 0.5 if v2 else 0.0
    add_box(mesh, (0, -2.3 - drop, 0), (2.0, 0.2, 3.4), "wood")
    for x in (-0.95, 0.95):
        for z in (-1.6, 1.6):
            add_cylinder_between(mesh, (x, -2.2 - drop, z), (x, -0.55, z), 0.07, 0.07, "gold", 5)
        add_box(mesh, (x, -1.65 - drop, 0), (0.08, 0.08, 3.3), "gold")
        add_box(mesh, (x, -1.2 - drop, 0), (0.08, 0.08, 3.3), "gold")
    for z in (-0.85, 0.85):
        add_box(mesh, (0, -2.0 - drop, z), (1.7, 0.24, 0.8), "mint")
    add_box(mesh, (0, -0.45, 0), (2.3, 0.14, 3.6), "coral")
    add_box(mesh, (0, -0.33, 0), (1.9, 0.1, 3.2), "cream")
    add_cylinder_between(mesh, (0, -0.4, 0), (0, 0.0, 0), 0.1, 0.1, "ink", 6)
    add_box(mesh, (0, 0.0, 0), (0.5, 0.18, 0.5), "ink")
    return mesh


def make_bunny_hub() -> Mesh:
    """Rotating mini-carousel deck: a striped base, brass poles, a central column, and a scalloped canopy."""
    mesh = Mesh("ParkParkBunnyHub")
    add_vertical_cylinder(mesh, 6.8, 0.0, 0.5, "gold", 40)
    add_vertical_cylinder(mesh, 6.5, 0.5, 0.72, "mint", 40)
    add_torus(mesh, 6.6, 0.12, 0.74, "coral", segments=40, sides=6)
    lathe(
        mesh,
        [(0.0, 0.7, "wood"), (0.9, 0.7, "wood"), (0.6, 1.2, "gold"), (0.5, 5.4, "cream"), (0.8, 5.5, "gold")],
        24,
    )
    for index in range(6):
        angle = TAU * index / 6
        x, z = 4.4 * math.cos(angle), 4.4 * math.sin(angle)
        add_cylinder_between(mesh, (x, 0.72, z), (x, 5.2, z), 0.11, 0.11, "gold", 8)
    lathe(
        mesh,
        [
            (6.6, 5.1, "coral"),
            (6.8, 5.5, "cream"),
            (6.4, 5.7, "coral"),
            (3.4, 6.5, "cream"),
            (1.0, 7.3, "coral"),
            (0.0, 7.8, "gold"),
        ],
        36,
    )
    for index in range(18):
        angle = TAU * index / 18
        add_ellipsoid(
            mesh,
            (6.55 * math.cos(angle), 5.05, 6.55 * math.sin(angle)),
            (0.34, 0.2, 0.34),
            "gold" if index % 2 else "cream",
            slices=6,
            stacks=3,
        )
    add_star(mesh, 8.3, 0.5, "gold")
    return mesh


def make_bunny() -> Mesh:
    """A little bunny to ride (base at y=0, facing +Z), with a coral saddle on its back at about y=1.6."""
    mesh = Mesh("ParkParkBunny")
    add_ellipsoid(mesh, (0, 1.05, -0.05), (0.7, 0.62, 1.0), "cream", slices=12, stacks=7)
    add_ellipsoid(mesh, (0, 1.8, 0.95), (0.46, 0.46, 0.5), "cream", slices=10, stacks=6)
    for side in (-1, 1):
        add_ellipsoid(mesh, (side * 0.2, 2.65, 0.8), (0.13, 0.55, 0.1), "cream", slices=8, stacks=5)
        add_ellipsoid(mesh, (side * 0.2, 2.62, 0.84), (0.07, 0.4, 0.05), "coral", slices=6, stacks=4)
        add_ellipsoid(mesh, (side * 0.22, 1.92, 1.36), (0.07, 0.08, 0.05), "ink", slices=6, stacks=4)
        add_ellipsoid(mesh, (side * 0.45, 0.4, 0.55), (0.16, 0.4, 0.2), "cream", slices=6, stacks=4)
        add_ellipsoid(mesh, (side * 0.5, 0.35, -0.55), (0.2, 0.35, 0.45), "cream", slices=6, stacks=4)
    add_ellipsoid(mesh, (0, 1.75, 1.42), (0.12, 0.09, 0.08), "coral", slices=6, stacks=4)
    add_ellipsoid(mesh, (0, 1.1, -1.1), (0.28, 0.28, 0.28), "cream", slices=8, stacks=5)
    add_box(mesh, (0, 1.62, -0.2), (0.9, 0.12, 0.9), "coral")
    add_cylinder_between(mesh, (0, 0.0, 0.0), (0, 1.0, 0.0), 0.07, 0.07, "gold", 6)
    return mesh


def make_hedge_maze() -> Mesh:
    """A hedge maze (origin at the ground centre, entrance gap on the +Z side): concentric hedge rings with
    staggered gaps around a small gazebo with a pennant."""
    mesh = Mesh("ParkParkHedgeMaze")
    add_box(mesh, (0, 0.05, 0), (31.0, 0.1, 31.0), "faded_mint")

    def hedge(x0: float, z0: float, x1: float, z1: float) -> None:
        cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        width = abs(x1 - x0) + 1.2 if abs(x1 - x0) < 0.01 else abs(x1 - x0)
        depth = abs(z1 - z0) + 1.2 if abs(z1 - z0) < 0.01 else abs(z1 - z0)
        add_box(mesh, (cx, 1.6, cz), (width, 3.2, depth), "mint")
        length = max(abs(x1 - x0), abs(z1 - z0))
        steps = max(1, int(length / 1.4))
        for step in range(steps):
            t = (step + 0.5) / steps
            x = x0 + (x1 - x0) * t
            z = z0 + (z1 - z0) * t
            add_ellipsoid(mesh, (x, 3.3, z), (0.75, 0.45, 0.75), "mint", slices=6, stacks=3)
            if step % 4 == 2:
                add_ellipsoid(mesh, (x, 3.8, z), (0.18, 0.18, 0.18), "coral" if step % 8 == 2 else "gold", slices=5, stacks=3)

    # Ring half-extents and the side where each ring has its gap, staggered so the way winds inward.
    for half, gap_side in ((15.0, "+z"), (11.0, "-z"), (7.0, "+x")):
        gap = 2.2 if half > 14 else 1.8
        sides = {
            "+z": (-half, half, half, half),
            "-z": (-half, -half, half, -half),
            "+x": (half, -half, half, half),
            "-x": (-half, -half, -half, half),
        }
        for side, (x0, z0, x1, z1) in sides.items():
            if side == gap_side:
                if side in ("+z", "-z"):
                    hedge(x0, z0, -gap, z1)
                    hedge(gap, z0, x1, z1)
                else:
                    hedge(x0, z0, x1, -gap)
                    hedge(x0, gap, x1, z1)
            else:
                hedge(x0, z0, x1, z1)
    # Central gazebo.
    add_vertical_cylinder(mesh, 2.0, 0.1, 0.6, "cream", 16)
    for angle in range(6):
        a = TAU * angle / 6
        add_cylinder_between(
            mesh, (1.7 * math.cos(a), 0.6, 1.7 * math.sin(a)), (1.7 * math.cos(a), 3.6, 1.7 * math.sin(a)), 0.1, 0.1, "gold", 6
        )
    lathe(mesh, [(2.4, 3.6, "coral"), (1.6, 4.2, "cream"), (0.0, 5.0, "coral")], 16)
    add_cylinder_between(mesh, (0, 5.0, 0), (0, 6.6, 0), 0.05, 0.04, "wood", 4)
    add_box(mesh, (0.45, 6.3, 0), (0.9, 0.5, 0.06), "gold")
    return mesh


def make_decor_pine() -> Mesh:
    """A tiered pine tree for the adventure zone (origin at the base of the trunk)."""
    mesh = Mesh("ParkParkDecorPine")
    add_vertical_cylinder(mesh, 0.38, 0.0, 1.8, "wood", 8)
    for index, (radius, base, top) in enumerate(((2.3, 1.2, 3.8), (1.8, 2.8, 5.2), (1.3, 4.2, 6.5), (0.8, 5.5, 7.6))):
        material = "mint" if index % 2 == 0 else "faded_mint"
        lathe(mesh, [(radius, base, material), (radius * 0.55, (base + top) / 2, "mint"), (0.0, top, "mint")], 10)
    add_ellipsoid(mesh, (0.6, 2.3, 0.4), (0.14, 0.14, 0.14), "coral", slices=5, stacks=3)
    return mesh


def make_decor_rock() -> Mesh:
    """A cluster of three boulders (origin at the ground centre)."""
    mesh = Mesh("ParkParkDecorRock")
    add_ellipsoid(mesh, (0, 1.0, 0), (1.9, 1.3, 1.6), "faded_cream", slices=9, stacks=5)
    add_ellipsoid(mesh, (1.9, 0.7, 0.6), (1.2, 0.9, 1.1), "cream", slices=8, stacks=4)
    add_ellipsoid(mesh, (-1.5, 0.55, 1.2), (0.9, 0.7, 0.8), "faded_cream", slices=8, stacks=4)
    add_ellipsoid(mesh, (0.1, 1.9, -0.2), (0.7, 0.4, 0.6), "mint", slices=6, stacks=3)
    return mesh


def shop_base(mesh: Mesh, wall: str, awning_a: str, awning_b: str) -> None:
    """A little market stall (origin at the ground centre, counter on the +Z side): walls, a counter, a striped
    awning on two posts, a menu board, and a shelf of jars."""
    add_box(mesh, (0, 0.1, 0), (8.6, 0.2, 6.2), "cream")
    add_box(mesh, (0, 2.4, -1.6), (8.0, 4.4, 2.6), wall)
    add_box(mesh, (0, 4.75, -1.6), (8.4, 0.3, 3.0), "wood")
    # Counter with a gold top, and a shelf behind it.
    add_box(mesh, (0, 0.95, 1.1), (8.0, 1.5, 1.4), wall)
    add_box(mesh, (0, 1.78, 1.1), (8.4, 0.16, 1.7), "gold")
    add_box(mesh, (0, 2.6, -0.2), (7.0, 0.14, 0.7), "wood")
    for index in range(5):
        x = -2.8 + index * 1.4
        add_vertical_cylinder(mesh, 0.32, 2.67, 3.3, "coral" if index % 2 == 0 else "mint", 8, x, -0.2)
        add_vertical_cylinder(mesh, 0.36, 3.3, 3.42, "gold", 8, x, -0.2)
    # Striped awning sloping forward over the counter, held by two posts.
    for x in (-3.9, 3.9):
        add_cylinder_between(mesh, (x, 0.2, 2.5), (x, 4.2, 2.5), 0.14, 0.14, "gold", 6)
    for index in range(8):
        x0 = -4.4 + 8.8 * index / 8
        x1 = -4.4 + 8.8 * (index + 1) / 8
        add_slab(
            mesh,
            [
                (x0, 4.9, -3.0),
                (x1, 4.9, -3.0),
                (x1, 5.04, -3.0),
                (x0, 5.04, -3.0),
                (x0, 4.1, 3.2),
                (x1, 4.1, 3.2),
                (x1, 4.24, 3.2),
                (x0, 4.24, 3.2),
            ],
            awning_a if index % 2 == 0 else awning_b,
        )
    # Menu board on the front of the counter.
    add_box(mesh, (0, 0.95, 1.85), (3.6, 0.9, 0.1), "ink")
    for x in (-1.2, 0.0, 1.2):
        add_box(mesh, (x, 0.95, 1.92), (0.8, 0.14, 0.05), "cream")


def make_shop_ice_cream() -> Mesh:
    """Ice-cream parlour: mint walls, a giant cone with three scoops on the roof."""
    mesh = Mesh("ParkParkShopIceCream")
    shop_base(mesh, "mint", "coral", "cream")
    lathe(mesh, [(0.0, 5.0, "gold"), (0.9, 7.2, "gold"), (0.0, 7.2, "gold")], 12)
    lathe(mesh, [(0.95, 7.1, "wood"), (0.95, 7.3, "wood"), (0.0, 7.3, "wood")], 12)
    add_ellipsoid(mesh, (0, 7.9, 0), (1.05, 0.9, 1.05), "coral", slices=12, stacks=6)
    add_ellipsoid(mesh, (0, 8.9, 0), (0.92, 0.85, 0.92), "cream", slices=12, stacks=6)
    add_ellipsoid(mesh, (0, 9.8, 0), (0.78, 0.75, 0.78), "mint", slices=12, stacks=6)
    add_ellipsoid(mesh, (0, 10.65, 0), (0.22, 0.22, 0.22), "coral", slices=8, stacks=4)
    return mesh


def make_shop_pizza() -> Mesh:
    """Pizzeria: coral walls, a round pizza sign with toppings on a post."""
    mesh = Mesh("ParkParkShopPizza")
    shop_base(mesh, "coral", "mint", "cream")
    add_cylinder_between(mesh, (0, 5.0, 0), (0, 6.6, 0), 0.16, 0.16, "wood", 6)
    add_vertical_cylinder(mesh, 1.9, 6.6, 6.85, "gold", 24)
    add_vertical_cylinder(mesh, 1.55, 6.85, 6.95, "coral", 24)
    for angle, radius in ((0.4, 0.9), (1.6, 1.0), (2.8, 0.8), (4.0, 1.0), (5.2, 0.85), (0.0, 0.0)):
        add_ellipsoid(mesh, (radius * math.cos(angle), 7.05, radius * math.sin(angle)), (0.3, 0.1, 0.3), "ink" if radius else "mint", slices=7, stacks=3)
    for index in range(8):
        a = TAU * index / 8
        add_cylinder_between(mesh, (0, 6.97, 0), (1.5 * math.cos(a), 6.97, 1.5 * math.sin(a)), 0.03, 0.03, "gold", 4)
    return mesh


def make_shop_noodle() -> Mesh:
    """Noodle bar: wooden walls, a big bowl with steam curls and chopsticks on the roof."""
    mesh = Mesh("ParkParkShopNoodle")
    shop_base(mesh, "wood", "gold", "coral")
    lathe(
        mesh,
        [(0.0, 5.0, "ink"), (1.1, 5.0, "ink"), (1.7, 6.2, "cream"), (1.8, 6.6, "coral"), (1.55, 6.55, "gold"), (0.0, 6.4, "gold")],
        20,
    )
    for dx in (-0.5, 0.0, 0.5):
        add_ellipsoid(mesh, (dx, 6.65, 0.1), (0.35, 0.12, 0.8), "cream", slices=8, stacks=3)
    for x in (-0.25, 0.25):
        add_cylinder_between(mesh, (x, 6.7, 0.0), (x + 0.5, 8.4, 0.9), 0.06, 0.05, "wood", 5)
    for index, x in enumerate((-0.8, 0.0, 0.8)):
        add_cylinder_between(mesh, (x, 7.0, -0.2), (x + 0.3 * (1 if index % 2 else -1), 8.0, -0.2), 0.08, 0.03, "faded_cream", 5)
    return mesh


def make_swan_hub() -> Mesh:
    """Rotating swan-pond deck: a mint pond with a rim of lily pads, a fountain column, and a pedestal per swan."""
    mesh = Mesh("ParkParkSwanHub")
    add_vertical_cylinder(mesh, 6.8, 0.0, 0.5, "cream", 40)
    add_vertical_cylinder(mesh, 6.5, 0.5, 0.74, "mint", 40)
    add_torus(mesh, 6.6, 0.13, 0.76, "gold", segments=40, sides=6)
    for index in range(10):
        angle = TAU * index / 10 + 0.15
        add_vertical_cylinder(mesh, 0.5, 0.74, 0.8, "faded_mint", 10, 5.9 * math.cos(angle), 5.9 * math.sin(angle))
    lathe(
        mesh,
        [(0.0, 0.7, "wood"), (1.0, 0.7, "wood"), (0.7, 1.2, "gold"), (0.45, 3.4, "cream"), (1.1, 3.9, "mint"), (0.0, 4.2, "cream")],
        24,
    )
    for index in range(6):
        angle = TAU * index / 6
        x, z = 4.4 * math.cos(angle), 4.4 * math.sin(angle)
        add_cylinder_between(mesh, (0, 0.95, 0), (x, 0.95, z), 0.14, 0.14, "gold", 8)
        add_vertical_cylinder(mesh, 1.2, 0.74, 0.9, "gold", 20, x, z)
    add_star(mesh, 5.1, 0.45, "gold")
    return mesh


def make_swan(v2: bool = False) -> Mesh:
    """A swan boat (base at y=0, facing +Z): a white hull with an arched neck and a bench on its back at about y=1.5.

    The V2 variant joins the neck with tapered tubes instead of a stack of beads."""
    mesh = Mesh("ParkParkSwanV2" if v2 else "ParkParkSwan")
    add_ellipsoid(mesh, (0, 0.85, 0), (0.95, 0.65, 1.55), "cream", slices=14, stacks=7)
    add_ellipsoid(mesh, (0, 0.45, -1.35), (0.45, 0.35, 0.5), "cream", slices=8, stacks=5)
    for side in (-1, 1):
        add_ellipsoid(mesh, (side * 0.85, 1.15, -0.25), (0.22, 0.5, 1.0), "cream", slices=8, stacks=5)
    # Neck: a curved stack of spheres rising to the head, then the beak.
    neck = ((1.2, 1.2, 0.34), (1.7, 1.45, 0.3), (2.2, 1.5, 0.27), (2.55, 1.35, 0.25))
    if v2:
        for (y0, z0, r0), (y1, z1, r1) in zip(neck, neck[1:]):
            add_cylinder_between(mesh, (0, y0, z0), (0, y1, z1), r0 * 0.85, r1 * 0.85, "cream", 10)
            add_ellipsoid(mesh, (0, y1, z1), (r1 * 0.9, r1 * 0.9, r1 * 0.9), "cream", slices=8, stacks=5)
        add_ellipsoid(mesh, (0, 1.2, 1.2), (0.36, 0.36, 0.36), "cream", slices=8, stacks=5)
    else:
        for y, z, r in neck:
            add_ellipsoid(mesh, (0, y, z), (r, r, r), "cream", slices=8, stacks=5)
    add_ellipsoid(mesh, (0, 2.7, 1.45), (0.3, 0.28, 0.34), "cream", slices=9, stacks=5)
    add_box(mesh, (0, 2.62, 1.85), (0.2, 0.14, 0.36), "coral")
    for side in (-1, 1):
        add_ellipsoid(mesh, (side * 0.16, 2.78, 1.6), (0.05, 0.06, 0.04), "ink", slices=5, stacks=3)
    add_box(mesh, (0, 1.47, -0.1), (1.0, 0.14, 0.9), "gold")
    add_box(mesh, (0, 1.85, -0.55), (1.0, 0.7, 0.12), "gold")
    add_torus(mesh, 1.05, 0.12, 0.25, "mint", segments=18, sides=6)
    return mesh


def make_ball_pit() -> Mesh:
    """A square ball pit (origin at the ground centre, entrance gap on the +Z side): a padded rim, a mint floor
    full of coloured balls, and corner posts with balloons."""
    mesh = Mesh("ParkParkBallPit")
    half = 6.5
    add_box(mesh, (0, 0.4, 0), (half * 2 + 0.8, 0.8, half * 2 + 0.8), "gold")
    add_box(mesh, (0, 0.85, 0), (half * 2 - 1.0, 0.1, half * 2 - 1.0), "mint")
    # Padded rim: stacked soft rolls on three sides, a lower step on the +Z side.
    for row, (height, material) in enumerate(((1.3, "coral"), (2.2, "cream"))):
        add_cylinder_between(mesh, (-half, height, -half), (half, height, -half), 0.5, 0.5, material, 10)
        add_cylinder_between(mesh, (-half, height, -half), (-half, height, half), 0.5, 0.5, material, 10)
        add_cylinder_between(mesh, (half, height, -half), (half, height, half), 0.5, 0.5, material, 10)
        add_cylinder_between(mesh, (-half, height, half), (-2.4, height, half), 0.5, 0.5, material, 10)
        add_cylinder_between(mesh, (2.4, height, half), (half, height, half), 0.5, 0.5, material, 10)
    # Balls spread over the floor in a repeating pattern of colours.
    colours = ("coral", "gold", "mint", "cream")
    for ix in range(-5, 6):
        for iz in range(-5, 6):
            if (ix * 7 + iz * 3) % 3 == 0:
                continue
            offset = 0.18 * ((ix + iz) % 3 - 1)
            add_ellipsoid(
                mesh,
                (ix * 1.12 + offset, 1.2 + 0.1 * ((ix * iz) % 3), iz * 1.12 - offset),
                (0.5, 0.5, 0.5),
                colours[(ix * 5 + iz * 3) % 4],
                slices=6,
                stacks=4,
            )
    for x, z in ((-half, -half), (half, -half), (-half, half), (half, half)):
        add_vertical_cylinder(mesh, 0.35, 0.8, 4.4, "wood", 8, x, z)
        add_ellipsoid(mesh, (x, 5.2, z), (0.7, 0.9, 0.7), "coral" if (x + z) % 2 else "gold", slices=8, stacks=5)
    return mesh


def make_rocket_hub() -> Mesh:
    """Rotating launch-pad deck: a dark starburst pad, a radar mast, and a pedestal per rocket."""
    mesh = Mesh("ParkParkRocketHub")
    add_vertical_cylinder(mesh, 8.2, 0.0, 0.6, "ink", 44)
    add_vertical_cylinder(mesh, 8.25, 0.0, 0.45, "gold", 44)
    add_torus(mesh, 8.0, 0.14, 0.62, "coral", segments=44, sides=6)
    lathe(
        mesh,
        [(0.0, 0.6, "wood"), (1.4, 0.6, "wood"), (1.0, 1.4, "gold"), (0.6, 2.2, "cream"), (0.5, 5.0, "coral"), (0.9, 5.3, "gold"), (0.0, 6.4, "cream")],
        24,
    )
    for index in range(6):
        angle = TAU * index / 6
        x, z = 5.4 * math.cos(angle), 5.4 * math.sin(angle)
        add_cylinder_between(mesh, (0, 0.9, 0), (x, 0.9, z), 0.18, 0.18, "coral", 8)
        add_vertical_cylinder(mesh, 1.5, 0.6, 0.9, "gold", 24, x, z)
        add_vertical_cylinder(mesh, 1.2, 0.9, 0.98, "mint", 24, x, z)
    add_star(mesh, 7.0, 0.5, "gold")
    return mesh


def make_rocket() -> Mesh:
    """A rocket scooter (base at y=0, facing +Z): a cream hull with a coral nose, fins, a flame, and a seat on top
    at about y=1.7."""
    mesh = Mesh("ParkParkRocket")
    add_ellipsoid(mesh, (0, 1.0, -0.1), (0.75, 0.7, 1.7), "cream", slices=14, stacks=7)
    add_ellipsoid(mesh, (0, 1.05, 1.75), (0.5, 0.45, 0.8), "coral", slices=10, stacks=6)
    for angle in (0, 2.094, 4.188):
        fx, fy = math.sin(angle), math.cos(angle)
        add_box(mesh, (fx * 0.8, 1.0 + fy * 0.8, -1.5), (0.1 if abs(fx) < 0.5 else 0.7, 0.7 if abs(fx) < 0.5 else 0.1, 0.9), "mint")
    add_ellipsoid(mesh, (0, 1.0, -2.0), (0.45, 0.4, 0.8), "gold", slices=8, stacks=5)
    add_ellipsoid(mesh, (0, 1.0, -2.6), (0.28, 0.25, 0.6), "coral", slices=8, stacks=4)
    add_box(mesh, (0, 1.72, -0.2), (0.9, 0.14, 1.0), "mint")
    for side in (-1, 1):
        add_cylinder_between(mesh, (side * 0.5, 1.75, 0.35), (side * 0.5, 2.3, 0.7), 0.05, 0.05, "gold", 5)
    add_cylinder_between(mesh, (0, 0.0, 0.0), (0, 0.5, 0.0), 0.09, 0.09, "gold", 6)
    return mesh


def make_show_stage() -> Mesh:
    """A flower-trimmed show stage (origin at the ground centre, audience on the +Z side): a raised platform with
    steps, a proscenium arch with curtains, a painted backdrop, and spotlights on a truss."""
    mesh = Mesh("ParkParkShowStage")
    add_box(mesh, (0, 0.6, 0), (12.0, 1.2, 9.0), "wood")
    add_box(mesh, (0, 1.22, 0), (12.2, 0.1, 9.2), "gold")
    for index in range(3):
        add_box(mesh, (0, 0.2 + index * 0.2, 5.0 + (2 - index) * 0.6), (5.0, 0.4 + index * 0.4, 0.8), "cream")
    # Backdrop with a big star, and the proscenium arch.
    add_box(mesh, (0, 4.2, -4.3), (11.0, 6.0, 0.4), "cream")
    add_star(mesh, 4.6, 1.6, "gold", 0.0, -4.0)
    for side in (-1, 1):
        add_vertical_cylinder(mesh, 0.55, 1.2, 7.4, "coral", 14, side * 5.6, 3.6)
        add_ellipsoid(mesh, (side * 5.6, 7.6, 3.6), (0.8, 0.5, 0.8), "gold", slices=8, stacks=4)
        add_box(mesh, (side * 4.6, 4.4, 3.2), (1.6, 6.4, 0.5), "mint")
    add_box(mesh, (0, 7.2, 3.6), (12.4, 1.0, 0.8), "coral")
    add_box(mesh, (0, 7.8, 3.6), (10.0, 0.4, 0.6), "gold")
    # Truss with spotlights and a row of flowers along the stage edge.
    add_box(mesh, (0, 6.4, 3.0), (11.0, 0.18, 0.18), "ink")
    for index in range(5):
        x = -4.4 + index * 2.2
        add_cylinder_between(mesh, (x, 6.4, 3.0), (x, 5.6, 2.2), 0.09, 0.09, "ink", 5)
        add_ellipsoid(mesh, (x, 5.4, 2.0), (0.34, 0.34, 0.34), "gold", slices=8, stacks=4)
    for index in range(9):
        x = -5.2 + index * 1.3
        add_ellipsoid(mesh, (x, 1.45, 4.3), (0.32, 0.22, 0.32), "coral" if index % 2 else "cream", slices=6, stacks=3)
    return mesh


def make_ice_hub() -> Mesh:
    """Rotating ice-rink deck: a frosted disc, a crystal tower, and a turntable per penguin sled."""
    mesh = Mesh("ParkParkIceHub")
    add_vertical_cylinder(mesh, 8.2, 0.0, 0.6, "cream", 44)
    add_vertical_cylinder(mesh, 8.25, 0.0, 0.45, "mint", 44)
    add_vertical_cylinder(mesh, 7.4, 0.6, 0.72, "faded_mint", 44)
    add_torus(mesh, 8.0, 0.14, 0.62, "cream", segments=44, sides=6)
    lathe(
        mesh,
        [(0.0, 0.7, "wood"), (1.5, 0.7, "wood"), (1.0, 1.5, "mint"), (0.7, 2.6, "cream"), (1.0, 3.6, "mint"), (0.55, 5.0, "cream"), (0.0, 6.6, "mint")],
        8,
    )
    for index in range(6):
        angle = TAU * index / 6
        x, z = 5.4 * math.cos(angle), 5.4 * math.sin(angle)
        add_cylinder_between(mesh, (0, 0.95, 0), (x, 0.95, z), 0.18, 0.18, "cream", 8)
        add_vertical_cylinder(mesh, 1.5, 0.72, 0.95, "mint", 24, x, z)
    add_star(mesh, 7.3, 0.5, "gold")
    return mesh


def make_penguin() -> Mesh:
    """A penguin sled (base at y=0, facing +Z): a coral sled with runners, a penguin up front, a cushion behind."""
    mesh = Mesh("ParkParkPenguin")
    add_box(mesh, (0, 0.45, 0), (1.3, 0.22, 2.9), "coral")
    for side in (-1, 1):
        add_cylinder_between(mesh, (side * 0.55, 0.12, -1.5), (side * 0.55, 0.12, 1.5), 0.08, 0.08, "ink", 5)
        add_box(mesh, (side * 0.55, 0.28, 0.9), (0.08, 0.3, 0.08), "ink")
        add_box(mesh, (side * 0.55, 0.28, -0.9), (0.08, 0.3, 0.08), "ink")
    add_box(mesh, (0, 0.62, -0.55), (1.0, 0.14, 0.9), "mint")
    # Penguin: dark body, white belly, round head, beak, flippers.
    add_ellipsoid(mesh, (0, 1.25, 1.0), (0.55, 0.8, 0.5), "ink", slices=10, stacks=6)
    add_ellipsoid(mesh, (0, 1.2, 1.28), (0.38, 0.62, 0.25), "cream", slices=8, stacks=5)
    add_ellipsoid(mesh, (0, 2.15, 1.0), (0.42, 0.4, 0.4), "ink", slices=10, stacks=6)
    add_box(mesh, (0, 2.1, 1.4), (0.2, 0.1, 0.34), "gold")
    for side in (-1, 1):
        add_ellipsoid(mesh, (side * 0.18, 2.25, 1.32), (0.07, 0.08, 0.05), "cream", slices=5, stacks=3)
        add_ellipsoid(mesh, (side * 0.62, 1.3, 1.0), (0.12, 0.45, 0.22), "ink", slices=6, stacks=4)
        add_box(mesh, (side * 0.22, 0.58, 1.3), (0.28, 0.08, 0.34), "gold")
    return mesh


def make_ice_cave() -> Mesh:
    """An igloo (origin at the ground centre, entrance tunnel on the +Z side): ice-block dome, glowing windows,
    a pennant, and a lantern at the door."""
    mesh = Mesh("ParkParkIceCave")
    add_vertical_cylinder(mesh, 8.6, 0.0, 0.3, "faded_cream", 40)
    profile = []
    rows = 7
    for row in range(rows + 1):
        t = row / rows
        angle = t * math.pi / 2
        radius = 7.6 * math.cos(angle)
        y = 0.3 + 6.4 * math.sin(angle)
        material = "cream" if row % 2 == 0 else "mint"
        profile.append((max(radius, 0.001), y, material))
    lathe(mesh, profile, 28)
    # Entrance tunnel toward +Z with an arch.
    add_box(mesh, (0, 1.6, 8.2), (4.2, 3.2, 4.0), "cream")
    add_box(mesh, (0, 3.35, 8.2), (4.6, 0.4, 4.4), "mint")
    add_box(mesh, (0, 1.4, 10.25), (2.2, 2.8, 0.2), "ink")
    for side in (-1, 1):
        add_ellipsoid(mesh, (side * 2.4, 1.0, 10.3), (0.5, 0.5, 0.5), "mint", slices=6, stacks=4)
    add_cylinder_between(mesh, (0, 3.6, 10.2), (0, 3.0, 10.2), 0.04, 0.04, "ink", 4)
    add_ellipsoid(mesh, (0, 2.8, 10.2), (0.22, 0.28, 0.22), "gold", slices=8, stacks=4)
    # Round windows, a chimney, and a pennant on top.
    for angle in (0.7, 2.4, 4.0, 5.4):
        add_ellipsoid(mesh, (5.4 * math.cos(angle), 3.4, 5.4 * math.sin(angle)), (0.7, 0.7, 0.3), "gold", slices=8, stacks=4)
    add_cylinder_between(mesh, (0, 6.7, 0), (0, 8.4, 0), 0.07, 0.05, "wood", 5)
    add_box(mesh, (0.5, 8.0, 0), (1.0, 0.55, 0.06), "coral")
    return mesh


def make_snow_mound() -> Mesh:
    """A snowy bouncing mound (origin at the ground centre): a soft round hill with snowmen around the edge."""
    mesh = Mesh("ParkParkSnowMound")
    add_vertical_cylinder(mesh, 6.8, 0.0, 0.9, "cream", 36)
    lathe(mesh, [(6.6, 0.9, "cream"), (5.2, 1.3, "faded_cream"), (3.0, 1.55, "cream"), (0.0, 1.6, "cream")], 28)
    for index in range(4):
        angle = TAU * index / 4 + math.pi / 4
        x, z = 6.6 * math.cos(angle), 6.6 * math.sin(angle)
        add_ellipsoid(mesh, (x, 1.1, z), (0.95, 0.95, 0.95), "cream", slices=10, stacks=6)
        add_ellipsoid(mesh, (x, 2.4, z), (0.7, 0.7, 0.7), "cream", slices=10, stacks=6)
        add_ellipsoid(mesh, (x, 3.4, z), (0.5, 0.5, 0.5), "cream", slices=10, stacks=6)
        add_box(mesh, (x, 3.95, z), (0.75, 0.5, 0.75), "coral")
        add_box(mesh, (x, 3.4, z + 0.5), (0.1, 0.1, 0.4), "gold")
    for index in range(10):
        angle = TAU * index / 10 + 0.2
        add_ellipsoid(mesh, (5.4 * math.cos(angle), 1.5, 5.4 * math.sin(angle)), (0.7, 0.5, 0.7), "mint" if index % 2 else "cream", slices=6, stacks=4)
    return mesh


def make_shop_cocoa() -> Mesh:
    """Cocoa stall: dark wooden walls and a giant steaming mug on the roof."""
    mesh = Mesh("ParkParkShopCocoa")
    shop_base(mesh, "wood", "coral", "cream")
    lathe(mesh, [(0.0, 5.0, "coral"), (1.4, 5.0, "coral"), (1.5, 6.9, "cream"), (1.4, 7.1, "gold"), (0.0, 6.7, "wood")], 20)
    add_ellipsoid(mesh, (1.75, 6.2, 0.0), (0.2, 0.55, 0.45), "cream", slices=8, stacks=4)
    for dx in (-0.5, 0.0, 0.5):
        add_ellipsoid(mesh, (dx, 7.6 + abs(dx), 0.0), (0.22, 0.4, 0.22), "faded_cream", slices=6, stacks=4)
    return mesh


def make_reindeer_hub() -> Mesh:
    """Rotating frosted deck for the reindeer carousel: a snowy disc with a candy-striped column and a pedestal per reindeer."""
    mesh = Mesh("ParkParkReindeerHub")
    add_vertical_cylinder(mesh, 6.8, 0.0, 0.5, "cream", 40)
    add_vertical_cylinder(mesh, 6.5, 0.5, 0.74, "faded_mint", 40)
    add_torus(mesh, 6.6, 0.13, 0.76, "coral", segments=40, sides=6)
    for index in range(10):
        angle = TAU * index / 10 + 0.15
        add_ellipsoid(mesh, (5.9 * math.cos(angle), 0.95, 5.9 * math.sin(angle)), (0.45, 0.3, 0.45), "cream", slices=8, stacks=4)
    lathe(
        mesh,
        [(0.0, 0.7, "wood"), (1.0, 0.7, "wood"), (0.7, 1.2, "coral"), (0.45, 2.0, "cream"), (0.5, 2.8, "coral"), (0.45, 3.6, "cream"), (1.1, 4.1, "mint"), (0.0, 4.5, "cream")],
        24,
    )
    for index in range(6):
        angle = TAU * index / 6
        x, z = 4.4 * math.cos(angle), 4.4 * math.sin(angle)
        add_cylinder_between(mesh, (0, 0.95, 0), (x, 0.95, z), 0.14, 0.14, "coral", 8)
        add_vertical_cylinder(mesh, 1.2, 0.74, 0.9, "mint", 20, x, z)
    add_star(mesh, 5.1, 0.45, "gold")
    return mesh


def make_reindeer() -> Mesh:
    """A reindeer (base at y=0, facing +Z): brown body, cream chest, antlers, red nose, and a mint saddle at about y=1.5."""
    mesh = Mesh("ParkParkReindeer")
    add_ellipsoid(mesh, (0, 1.0, -0.1), (0.7, 0.62, 1.35), "wood", slices=14, stacks=7)
    add_ellipsoid(mesh, (0, 0.95, 0.75), (0.5, 0.5, 0.5), "cream", slices=10, stacks=6)
    for sx in (-1, 1):
        for sz in (-0.75, 0.6):
            add_cylinder_between(mesh, (sx * 0.38, 0.8, sz), (sx * 0.38, 0.0, sz), 0.13, 0.1, "wood", 6)
            add_box(mesh, (sx * 0.38, 0.05, sz + 0.06), (0.22, 0.12, 0.3), "ink")
    add_cylinder_between(mesh, (0, 1.2, 1.0), (0, 2.0, 1.45), 0.26, 0.2, "wood", 8)
    add_ellipsoid(mesh, (0, 2.1, 1.65), (0.3, 0.28, 0.4), "wood", slices=10, stacks=6)
    add_ellipsoid(mesh, (0, 2.0, 2.0), (0.16, 0.15, 0.14), "coral", slices=8, stacks=4)
    for sx in (-1, 1):
        add_ellipsoid(mesh, (sx * 0.14, 2.28, 1.88), (0.05, 0.06, 0.04), "ink", slices=5, stacks=3)
        add_cylinder_between(mesh, (sx * 0.16, 2.35, 1.55), (sx * 0.5, 2.95, 1.45), 0.05, 0.04, "gold", 5)
        add_cylinder_between(mesh, (sx * 0.5, 2.95, 1.45), (sx * 0.75, 3.35, 1.4), 0.04, 0.03, "gold", 5)
        add_cylinder_between(mesh, (sx * 0.4, 2.8, 1.5), (sx * 0.6, 2.9, 1.8), 0.03, 0.03, "gold", 5)
        add_ellipsoid(mesh, (sx * 0.2, 2.35, 1.45), (0.1, 0.18, 0.06), "cream", slices=6, stacks=4)
    add_box(mesh, (0, 1.47, -0.2), (1.0, 0.14, 0.9), "mint")
    add_box(mesh, (0, 1.8, -0.62), (1.0, 0.6, 0.12), "mint")
    add_ellipsoid(mesh, (0, 1.0, -1.5), (0.18, 0.2, 0.2), "cream", slices=6, stacks=4)
    return mesh


def make_snowflake_hub() -> Mesh:
    """Rotating snowflake deck: a pale-blue disc with six crystal arms in relief, a crystal tower, and a pedestal per pod."""
    mesh = Mesh("ParkParkSnowflakeHub")
    add_vertical_cylinder(mesh, 8.2, 0.0, 0.6, "faded_mint", 44)
    add_vertical_cylinder(mesh, 8.25, 0.0, 0.45, "cream", 44)
    add_torus(mesh, 8.0, 0.14, 0.62, "mint", segments=44, sides=6)
    for index in range(6):
        angle = TAU * index / 6 + TAU / 12
        add_cylinder_between(mesh, (0, 0.66, 0), (7.2 * math.cos(angle), 0.66, 7.2 * math.sin(angle)), 0.16, 0.16, "cream", 6)
    lathe(
        mesh,
        [(0.0, 0.6, "wood"), (1.4, 0.6, "wood"), (1.0, 1.4, "mint"), (0.6, 2.2, "cream"), (0.9, 3.4, "mint"), (0.45, 5.0, "cream"), (0.0, 6.6, "mint")],
        8,
    )
    for index in range(6):
        angle = TAU * index / 6
        x, z = 5.4 * math.cos(angle), 5.4 * math.sin(angle)
        add_cylinder_between(mesh, (0, 0.9, 0), (x, 0.9, z), 0.18, 0.18, "mint", 8)
        add_vertical_cylinder(mesh, 1.5, 0.6, 0.9, "cream", 24, x, z)
        add_vertical_cylinder(mesh, 1.2, 0.9, 0.98, "mint", 24, x, z)
    add_star(mesh, 7.0, 0.5, "gold")
    return mesh


def make_snow_pod() -> Mesh:
    """A round snow pod (base at y=0): a cream shell with a mint rim and a seat on top at about y=1.72."""
    mesh = Mesh("ParkParkSnowPod")
    add_ellipsoid(mesh, (0, 0.95, 0), (1.0, 0.75, 1.0), "cream", slices=14, stacks=7)
    add_torus(mesh, 1.0, 0.12, 1.0, "mint", segments=18, sides=6)
    for angle in (0.0, 2.094, 4.188):
        add_ellipsoid(mesh, (0.95 * math.cos(angle), 0.9, 0.95 * math.sin(angle)), (0.2, 0.2, 0.2), "coral", slices=6, stacks=4)
    add_box(mesh, (0, 1.72, -0.2), (0.9, 0.14, 1.0), "mint")
    for side in (-1, 1):
        add_cylinder_between(mesh, (side * 0.5, 1.75, 0.35), (side * 0.5, 2.3, 0.7), 0.05, 0.05, "gold", 5)
    add_cylinder_between(mesh, (0, 0.0, 0.0), (0, 0.5, 0.0), 0.09, 0.09, "gold", 6)
    return mesh


def make_shop_cookie() -> Mesh:
    """Cookie stall: cream walls, a mint-and-coral awning, and a giant gingerbread man on the roof."""
    mesh = Mesh("ParkParkShopCookie")
    shop_base(mesh, "cream", "mint", "coral")
    add_ellipsoid(mesh, (0, 6.4, 0), (0.95, 1.15, 0.3), "wood", slices=10, stacks=6)
    add_ellipsoid(mesh, (0, 7.95, 0), (0.7, 0.7, 0.3), "wood", slices=10, stacks=6)
    for sx in (-1, 1):
        add_ellipsoid(mesh, (sx * 1.35, 6.9, 0), (0.75, 0.3, 0.28), "wood", slices=8, stacks=4)
        add_ellipsoid(mesh, (sx * 0.5, 5.35, 0), (0.32, 0.8, 0.28), "wood", slices=8, stacks=4)
        add_ellipsoid(mesh, (sx * 0.25, 8.05, 0.28), (0.07, 0.07, 0.04), "ink", slices=5, stacks=3)
    for y in (6.9, 6.3, 5.7):
        add_ellipsoid(mesh, (0, y, 0.28), (0.12, 0.12, 0.05), "gold", slices=6, stacks=4)
    add_box(mesh, (0, 7.65, 0.3), (0.4, 0.05, 0.04), "coral")
    return mesh


def make_litter() -> Mesh:
    """A small cluster of park litter: a dropped cup, a wrapper, a popcorn tub, and an apple core."""
    mesh = Mesh("ParkParkLitter")
    # Tipped paper cup lying on its side.
    add_cylinder_between(mesh, (-0.6, 0.42, -0.3), (0.35, 0.3, -0.05), 0.42, 0.3, "faded_cream", 10)
    add_cylinder_between(mesh, (-0.3, 0.4, -0.2), (0.0, 0.36, -0.1), 0.44, 0.43, "coral", 10)
    # Crumpled wrapper.
    add_box(mesh, (0, 0, 0), (0.9, 0.08, 0.7), "faded_coral", tilted_transform((0.9, 0.09, 0.7), 35, 3))
    add_ellipsoid(mesh, (0.9, 0.22, 0.7), (0.3, 0.2, 0.28), "faded_coral", slices=7, stacks=4)
    # Popcorn tub with a few spilled kernels.
    add_box(mesh, (0, 0, 0), (0.8, 0.9, 0.8), "coral", tilted_transform((-0.9, 0.42, 0.85), 20, 0, 14))
    add_box(mesh, (0, 0, 0), (0.82, 0.16, 0.82), "cream", tilted_transform((-0.9, 0.8, 0.85), 20, 0, 14))
    for x, z in ((-0.2, 1.25), (0.05, 1.05), (-0.5, 1.4), (0.3, 1.4)):
        add_ellipsoid(mesh, (x, 0.1, z), (0.12, 0.1, 0.12), "cream", slices=6, stacks=4)
    # Apple core.
    add_ellipsoid(mesh, (1.3, 0.18, -0.6), (0.24, 0.2, 0.24), "faded_mint", slices=7, stacks=4)
    add_cylinder_between(mesh, (1.3, 0.2, -0.6), (1.3, 0.55, -0.6), 0.04, 0.03, "wood", 5)
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
        make_teacups_platform(),
        make_teacups_rotor(),
        make_teacups_hub(),
        make_teacup(),
        make_litter(),
        make_snack_stand(),
        make_ferris_wheel(),
        make_ferris_base(),
        make_ferris_cabin(),
        make_swing_base(),
        make_swing_crown(),
        make_swing_seat(),
        make_pirate_base(),
        make_pirate_ship(),
        make_haunted_house(),
        make_coaster_track(),
        make_coaster_car(),
        make_flume_track(),
        make_flume_boat(),
        make_drop_tower(),
        make_drop_gondola(),
        make_gift_shop(),
        make_decor_palm(),
        make_decor_umbrella(),
        make_decor_pond(),
        make_decor_sandcastle(),
        make_train_track(),
        make_train_car(),
        make_duck_hub(),
        make_duck(),
        make_mine_track(),
        make_mine_car(),
        make_sky_track(),
        make_sky_car(),
        make_bunny_hub(),
        make_bunny(),
        make_hedge_maze(),
        make_decor_pine(),
        make_decor_rock(),
        make_shop_ice_cream(),
        make_shop_pizza(),
        make_shop_noodle(),
        make_swan_hub(),
        make_show_stage(),
        make_ice_hub(),
        make_penguin(),
        make_ice_cave(),
        make_snow_mound(),
        make_shop_cocoa(),
        make_reindeer_hub(),
        make_reindeer(),
        make_snowflake_hub(),
        make_snow_pod(),
        make_shop_cookie(),
        make_swan(),
        make_swan(v2=True),
        make_sky_car(v2=True),
        make_sky_track(v2=True),
        make_coaster_track(v2=True),
        make_train_track(v2=True),
        make_haunted_house(v2=True),
        make_ball_pit(),
        make_rocket_hub(),
        make_rocket(),
        make_bounce_house(),
        make_decor_tree(),
        make_decor_bush(),
        make_decor_lamp(),
        make_decor_bench(),
        make_decor_fountain(),
        make_decor_balloons(),
        make_decor_flowers(),
        make_decor_gazebo(),
        make_decor_statue(),
        make_bumper_platform(),
        make_bumper_car(),
        make_entrance(),
        make_entrance_sign(),
        make_repair_console(),
        make_entrance_debris(),
    )
    write_coaster_path()
    flume_samples, flume_marks = flume_path()
    write_track_path("FlumePath.luau", "log flume", flume_samples, flume_marks)
    train_samples, train_marks = train_path()
    write_track_path("TrainPath.luau", "mini train", train_samples, train_marks)
    mine_samples, mine_marks = mine_path()
    write_track_path("MinePath.luau", "mine train", mine_samples, mine_marks)
    sky_samples, sky_marks = sky_path()
    write_track_path("SkyPath.luau", "sky ride", sky_samples, sky_marks)
    for mesh in meshes:
        path = OUTPUT / f"{mesh.name}.obj"
        vertices, triangles, minimum, maximum = mesh.write(path)
        bounds = tuple(round(maximum[axis] - minimum[axis], 2) for axis in range(3))
        print(f"{path.relative_to(ROOT)}: {vertices:,} vertices, {triangles:,} triangles, bounds {bounds} studs")


if __name__ == "__main__":
    main()

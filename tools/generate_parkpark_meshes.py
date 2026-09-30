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
        make_bumper_platform(),
        make_bumper_car(),
        make_entrance(),
        make_entrance_sign(),
        make_repair_console(),
        make_entrance_debris(),
    )
    for mesh in meshes:
        path = OUTPUT / f"{mesh.name}.obj"
        vertices, triangles, minimum, maximum = mesh.write(path)
        bounds = tuple(round(maximum[axis] - minimum[axis], 2) for axis in range(3))
        print(f"{path.relative_to(ROOT)}: {vertices:,} vertices, {triangles:,} triangles, bounds {bounds} studs")


if __name__ == "__main__":
    main()

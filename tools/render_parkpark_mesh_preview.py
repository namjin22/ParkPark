"""Render a lightweight, flat-shaded review sheet for the generated OBJ sources.

Requires Pillow. The preview is a geometry check, not a Roblox Studio render.
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "models" / "parkpark"
OUTPUT = ASSET_DIR / "ParkParkModelPreview.png"
MTL = ASSET_DIR / "ParkParkFairground.mtl"


def read_materials() -> dict[str, tuple[int, int, int]]:
	materials: dict[str, tuple[int, int, int]] = {}
	current = None
	for line in MTL.read_text(encoding="utf-8").splitlines():
		parts = line.split()
		if len(parts) == 2 and parts[0] == "newmtl":
			current = parts[1]
		elif current and len(parts) == 4 and parts[0] == "Kd":
			materials[current] = tuple(round(float(value) * 255) for value in parts[1:])
	return materials


def read_obj(path: Path) -> tuple[list[tuple[float, float, float]], list[tuple[str, tuple[int, ...]]]]:
	vertices: list[tuple[float, float, float]] = []
	faces: list[tuple[str, tuple[int, ...]]] = []
	material = "cream"
	for line in path.read_text(encoding="utf-8").splitlines():
		parts = line.split()
		if not parts:
			continue
		if parts[0] == "v":
			vertices.append(tuple(float(value) for value in parts[1:4]))
		elif parts[0] == "usemtl":
			material = parts[1]
		elif parts[0] == "f":
			face = tuple(int(value.split("/")[0]) - 1 for value in parts[1:])
			faces.append((material, face))
	return vertices, faces


def combine(paths: tuple[Path, ...]) -> tuple[list[tuple[float, float, float]], list[tuple[str, tuple[int, ...]]]]:
	vertices: list[tuple[float, float, float]] = []
	faces: list[tuple[str, tuple[int, ...]]] = []
	for path in paths:
		part_vertices, part_faces = read_obj(path)
		offset = len(vertices)
		vertices.extend(part_vertices)
		faces.extend((material, tuple(index + offset for index in face)) for material, face in part_faces)
	return vertices, faces


def shade(color: tuple[int, int, int], normal: tuple[float, float, float]) -> tuple[int, int, int]:
	light = (-0.35, 0.83, 0.43)
	length = math.sqrt(sum(axis * axis for axis in normal)) or 1
	lambert = abs(sum(normal[index] * light[index] for index in range(3)) / length)
	factor = 0.63 + 0.37 * lambert
	return tuple(max(0, min(255, round(channel * factor))) for channel in color)


def render_card(
	canvas: Image.Image,
	bounds: tuple[int, int, int, int],
	paths: tuple[Path, ...],
	materials: dict[str, tuple[int, int, int]],
	label: str,
) -> None:
	draw = ImageDraw.Draw(canvas)
	left, top, right, bottom = bounds
	vertices, faces = combine(paths)
	angle = math.radians(42)
	pitch = math.radians(29)
	cos_yaw, sin_yaw = math.cos(angle), math.sin(angle)
	cos_pitch, sin_pitch = math.cos(pitch), math.sin(pitch)
	projected: list[tuple[float, float, float]] = []
	for x, y, z in vertices:
		screen_x = x * cos_yaw - z * sin_yaw
		depth = x * sin_yaw + z * cos_yaw
		screen_y = y * cos_pitch - depth * sin_pitch
		projected.append((screen_x, screen_y, depth))

	min_x = min(point[0] for point in projected)
	max_x = max(point[0] for point in projected)
	min_y = min(point[1] for point in projected)
	max_y = max(point[1] for point in projected)
	padding = 44
	model_width = max_x - min_x
	model_height = max_y - min_y
	fit = min((right - left - 2 * padding) / model_width, (bottom - top - 100 - 2 * padding) / model_height)
	center_x = (left + right) / 2
	center_y = top + (bottom - top - 40) * 0.57

	def screen(point: tuple[float, float, float]) -> tuple[float, float]:
		x = center_x + (point[0] - (min_x + max_x) / 2) * fit
		y = center_y - (point[1] - (min_y + max_y) / 2) * fit
		return x, y

	triangles: list[tuple[float, str, tuple[int, int, int]]] = []
	for material, face in faces:
		for index in range(1, len(face) - 1):
			triangle = (face[0], face[index], face[index + 1])
			depth = sum(projected[vertex][2] for vertex in triangle) / 3
			triangles.append((depth, material, triangle))
	triangles.sort(key=lambda item: item[0])

	for _, material, triangle in triangles:
		a, b, c = (vertices[index] for index in triangle)
		ab = tuple(b[axis] - a[axis] for axis in range(3))
		ac = tuple(c[axis] - a[axis] for axis in range(3))
		normal = (
			ab[1] * ac[2] - ab[2] * ac[1],
			ab[2] * ac[0] - ab[0] * ac[2],
			ab[0] * ac[1] - ab[1] * ac[0],
		)
		points = [screen(projected[index]) for index in triangle]
		fill = shade(materials.get(material, (120, 120, 120)), normal)
		draw.polygon(points, fill=fill)

	font = ImageFont.load_default(size=22)
	draw.text((left + 26, bottom - 56), label, font=font, fill=(58, 67, 70))


def main() -> None:
	materials = read_materials()
	canvas = Image.new("RGB", (1800, 760), (255, 247, 229))
	draw = ImageDraw.Draw(canvas)
	font = ImageFont.load_default(size=40)
	subtitle_font = ImageFont.load_default(size=22)
	draw.text((72, 42), "ParkPark | first custom mesh pass", font=font, fill=(57, 67, 72))
	draw.text((74, 94), "Generated OBJ review sheet · geometry preview, not a Studio render", font=subtitle_font, fill=(99, 103, 98))

	columns = ((50, 170, 585, 705), (692, 170, 1227, 705), (1334, 170, 1750, 705))
	for left, top, right, bottom in columns:
		draw.rounded_rectangle((left, top, right, bottom), radius=26, fill=(255, 252, 244), outline=(225, 211, 181), width=2)

	platform = ASSET_DIR / "ParkParkCarouselPlatform.obj"
	rotor = ASSET_DIR / "ParkParkCarouselRotor.obj"
	canopy_restored = ASSET_DIR / "ParkParkCanopyRestored.obj"
	canopy_neglected = ASSET_DIR / "ParkParkCanopyNeglected.obj"
	entrance = ASSET_DIR / "ParkParkStorybookEntrance.obj"

	render_card(canvas, columns[0], (platform, rotor, canopy_restored), materials, "Restored carousel")
	render_card(canvas, columns[1], (platform, rotor, canopy_neglected), materials, "Neglected carousel")
	render_card(canvas, columns[2], (entrance,), materials, "Storybook entrance")
	canvas.save(OUTPUT)
	print(f"Wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
	main()

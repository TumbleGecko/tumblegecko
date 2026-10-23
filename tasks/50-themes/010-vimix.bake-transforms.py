#!/usr/bin/env python3
"""Moves every transform in an icon folder's SVG files into the shapes' own coordinates.

GTK 4.20 and newer read symbolic icons with their own small SVG reader, which ignores transform attributes,
so a shape moved or turned by one is drawn in the wrong place or outside the icon and the icon looks empty.

010-vimix.bake-transforms.py FOLDER          rewrites each file that needs it and names how many changed
010-vimix.bake-transforms.py --check FOLDER  fails while any file still needs it
"""

import math
import os
import re
import sys
import xml.etree.ElementTree as ElementTree

SVG_NAMESPACE = "http://www.w3.org/2000/svg"
SHAPES = {"path", "rect", "circle", "ellipse", "line", "polygon", "polyline"}
# Elements that only hold or describe shapes, which a transform above them never reaches
PASSIVE = {"defs", "title", "desc", "metadata", "style", "linearGradient", "radialGradient", "stop"}
GEOMETRY = {"x", "y", "width", "height", "rx", "ry", "cx", "cy", "r", "x1", "y1", "x2", "y2", "points", "d"}
NUMBER = r"[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?"
DECIMALS = 4
IDENTITY = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)


class CannotBake(Exception):
	"""A file whose drawing would change if its transforms moved into the shapes"""


def local_name(element):
	return element.tag.rsplit("}", 1)[-1]


def multiply(first, second):
	a1, b1, c1, d1, e1, f1 = first
	a2, b2, c2, d2, e2, f2 = second
	return (a1 * a2 + c1 * b2, b1 * a2 + d1 * b2, a1 * c2 + c1 * d2, b1 * c2 + d1 * d2,
		a1 * e2 + c1 * f2 + e1, b1 * e2 + d1 * f2 + f1)


def read_transform(text):
	matrix = IDENTITY
	for name, arguments in re.findall(r"(\w+)\s*\(([^)]*)\)", text):
		values = [float(value) for value in re.findall(NUMBER, arguments)]
		if name == "matrix" and len(values) == 6:
			step = tuple(values)
		elif name == "translate":
			step = (1, 0, 0, 1, values[0], values[1] if len(values) > 1 else 0)
		elif name == "scale":
			step = (values[0], 0, 0, values[1] if len(values) > 1 else values[0], 0, 0)
		elif name == "rotate":
			angle = math.radians(values[0])
			turn = (math.cos(angle), math.sin(angle), -math.sin(angle), math.cos(angle), 0, 0)
			if len(values) == 3:
				turn = multiply(multiply((1, 0, 0, 1, values[1], values[2]), turn), (1, 0, 0, 1, -values[1], -values[2]))
			step = turn
		elif name == "skewX":
			step = (1, 0, math.tan(math.radians(values[0])), 1, 0, 0)
		elif name == "skewY":
			step = (1, math.tan(math.radians(values[0])), 0, 1, 0, 0)
		else:
			raise CannotBake(f"unknown transform {name}")
		matrix = multiply(matrix, step)
	return matrix


def move_point(matrix, x, y):
	a, b, c, d, e, f = matrix
	return a * x + c * y + e, b * x + d * y + f


def write_number(value):
	text = f"{round(value, DECIMALS):.{DECIMALS}f}".rstrip("0").rstrip(".")
	return "0" if text in ("", "-0") else text


def read_path(text):
	"""Splits path data into commands with their numbers, keeping an arc's flags apart even when written together"""
	commands = []
	for letter, body in re.findall(r"([MmLlHhVvCcSsQqTtAaZz])([^MmLlHhVvCcSsQqTtAaZz]*)", text):
		if letter in "Aa":
			values = []
			rest = body
			while True:
				rest = rest.lstrip(" ,\t\n\r")
				if not rest:
					break
				for _ in range(3):
					match = re.match(NUMBER, rest)
					values.append(float(match.group()))
					rest = rest[match.end():].lstrip(" ,\t\n\r")
				for _ in range(2):
					values.append(float(rest[0]))
					rest = rest[1:].lstrip(" ,\t\n\r")
				for _ in range(2):
					match = re.match(NUMBER, rest)
					values.append(float(match.group()))
					rest = rest[match.end():].lstrip(" ,\t\n\r")
		else:
			values = [float(value) for value in re.findall(NUMBER, body)]
		commands.append((letter, values))
	return commands


def make_absolute(commands):
	"""Gives every command absolute points as M, L, C, Q, A or Z, so moving each point is enough"""
	result = []
	x = y = start_x = start_y = 0.0
	last_control = None
	last_letter = ""
	sizes = {"M": 2, "L": 2, "H": 1, "V": 1, "C": 6, "S": 4, "Q": 4, "T": 2, "A": 7, "Z": 0}
	for letter, values in commands:
		upper = letter.upper()
		is_relative = letter != upper
		size = sizes[upper]
		groups = [values[index:index + size] for index in range(0, len(values), size)] if size else [[]]
		for position, group in enumerate(groups):
			kind = "L" if upper == "M" and position > 0 else upper
			if kind == "Z":
				result.append(("Z", []))
				x, y = start_x, start_y
			elif kind in ("M", "L", "T"):
				end_x, end_y = group[0] + (x if is_relative else 0), group[1] + (y if is_relative else 0)
				if kind == "T":
					control = (2 * x - last_control[0], 2 * y - last_control[1]) if last_letter in "QT" else (x, y)
					result.append(("Q", [*control, end_x, end_y]))
					last_control = control
				else:
					result.append((kind, [end_x, end_y]))
				if kind == "M":
					start_x, start_y = end_x, end_y
				x, y = end_x, end_y
			elif kind == "H":
				x = group[0] + (x if is_relative else 0)
				result.append(("L", [x, y]))
			elif kind == "V":
				y = group[0] + (y if is_relative else 0)
				result.append(("L", [x, y]))
			elif kind in ("C", "S", "Q"):
				points = [(group[index] + (x if is_relative else 0), group[index + 1] + (y if is_relative else 0))
					for index in range(0, len(group), 2)]
				if kind == "S":
					first = (2 * x - last_control[0], 2 * y - last_control[1]) if last_letter in "CS" else (x, y)
					points.insert(0, first)
					kind = "C"
				result.append((kind, [value for point in points for value in point]))
				last_control = points[-2]
				x, y = points[-1]
			elif kind == "A":
				end_x, end_y = group[5] + (x if is_relative else 0), group[6] + (y if is_relative else 0)
				result.append(("A", [*group[:5], end_x, end_y]))
				x, y = end_x, end_y
			last_letter = kind if upper not in "ST" else upper
	return result


def move_arc(matrix, values):
	"""The ellipse an arc follows changes size and angle with the matrix, and a mirror flips its direction"""
	radius_x, radius_y, angle, large_arc, sweep, end_x, end_y = values
	a, b, c, d = matrix[:4]
	turn = math.radians(angle)
	cosine, sine = math.cos(turn), math.sin(turn)
	# The ellipse's two axes after the matrix, as the columns of one 2 by 2 matrix
	p, r = (a * cosine + c * sine) * radius_x, (b * cosine + d * sine) * radius_x
	q, s = (-a * sine + c * cosine) * radius_y, (-b * sine + d * cosine) * radius_y
	first, second, shared = p * p + q * q, r * r + s * s, p * r + q * s
	middle, spread = (first + second) / 2, math.hypot((first - second) / 2, shared)
	new_x, new_y = move_point(matrix, end_x, end_y)
	new_angle = math.degrees(0.5 * math.atan2(2 * shared, first - second))
	new_sweep = sweep if a * d - b * c > 0 else 1 - sweep
	return [math.sqrt(middle + spread), math.sqrt(max(middle - spread, 0)), new_angle, large_arc, new_sweep, new_x, new_y]


def move_path(matrix, text):
	parts = []
	for letter, values in make_absolute(read_path(text)):
		if letter == "A":
			values = move_arc(matrix, values)
			parts.append("A" + " ".join(write_number(value) for value in values))
			continue
		moved = []
		for index in range(0, len(values), 2):
			moved.extend(move_point(matrix, values[index], values[index + 1]))
		parts.append(letter + " ".join(write_number(value) for value in moved))
	return "".join(parts)


def number(element, name, fallback=0.0):
	text = element.get(name)
	return float(re.match(NUMBER, text).group()) if text else fallback


def draw_rect(element):
	x, y = number(element, "x"), number(element, "y")
	width, height = number(element, "width"), number(element, "height")
	radius_x, radius_y = element.get("rx"), element.get("ry")
	radius_x = number(element, "rx") if radius_x else number(element, "ry")
	radius_y = number(element, "ry") if radius_y else radius_x
	radius_x, radius_y = min(radius_x, width / 2), min(radius_y, height / 2)
	if radius_x <= 0 or radius_y <= 0:
		return f"M{x} {y}H{x + width}V{y + height}H{x}Z"
	corner = f"A{radius_x} {radius_y} 0 0 1"
	return (f"M{x + radius_x} {y}H{x + width - radius_x}{corner} {x + width} {y + radius_y}"
		f"V{y + height - radius_y}{corner} {x + width - radius_x} {y + height}H{x + radius_x}"
		f"{corner} {x} {y + height - radius_y}V{y + radius_y}{corner} {x + radius_x} {y}Z")


def draw_ellipse(center_x, center_y, radius_x, radius_y):
	return (f"M{center_x - radius_x} {center_y}A{radius_x} {radius_y} 0 1 0 {center_x + radius_x} {center_y}"
		f"A{radius_x} {radius_y} 0 1 0 {center_x - radius_x} {center_y}Z")


def draw_shape(element):
	name = local_name(element)
	if name == "path":
		return element.get("d", "")
	if name == "rect":
		return draw_rect(element)
	if name == "circle":
		radius = number(element, "r")
		return draw_ellipse(number(element, "cx"), number(element, "cy"), radius, radius)
	if name == "ellipse":
		return draw_ellipse(number(element, "cx"), number(element, "cy"), number(element, "rx"), number(element, "ry"))
	if name == "line":
		return f"M{number(element, 'x1')} {number(element, 'y1')}L{number(element, 'x2')} {number(element, 'y2')}"
	points = re.findall(NUMBER, element.get("points", ""))
	text = "M" + " ".join(points)
	return text + "Z" if name == "polygon" else text


def has_stroke(element, inherited):
	style = element.get("style", "")
	stroke = element.get("stroke")
	match = re.search(r"(?:^|;)\s*stroke\s*:\s*([^;]+)", style)
	if match:
		stroke = match.group(1).strip()
	return inherited if stroke is None else stroke != "none"


def refers_elsewhere(element):
	"""Paint from a gradient or pattern is placed in the coordinates the transform sets up, so it would move"""
	text = " ".join(element.attrib.values())
	return "url(" in text


def bake(element, matrix, is_stroked):
	"""Carries each transform down to the shapes below it, which take the combined matrix into their points"""
	matrix = multiply(matrix, read_transform(element.get("transform", "")))
	is_stroked = has_stroke(element, is_stroked)
	name = local_name(element)
	if matrix != IDENTITY and refers_elsewhere(element):
		raise CannotBake("paint that follows the transform")
	if name in SHAPES:
		if matrix != IDENTITY:
			if is_stroked and not math.isclose(abs(matrix[0] * matrix[3] - matrix[1] * matrix[2]), 1, abs_tol=1e-6):
				raise CannotBake("a stroke that the transform resizes")
			path = move_path(matrix, draw_shape(element))
			for attribute in GEOMETRY:
				element.attrib.pop(attribute, None)
			element.tag = f"{{{SVG_NAMESPACE}}}path"
			element.set("d", path)
		element.attrib.pop("transform", None)
		return
	if name not in PASSIVE and name not in ("g", "svg", "a", "switch") and matrix != IDENTITY:
		raise CannotBake(f"{name} inside a transform")
	element.attrib.pop("transform", None)
	for child in element:
		bake(child, matrix, is_stroked)


def register_namespaces(path):
	for _, (prefix, address) in ElementTree.iterparse(path, events=("start-ns",)):
		ElementTree.register_namespace(prefix, address)


def needs_baking(path):
	with open(path, encoding="utf-8") as file:
		return "transform=" in file.read()


def bake_file(path):
	register_namespaces(path)
	tree = ElementTree.parse(path)
	bake(tree.getroot(), IDENTITY, False)
	with open(path, encoding="utf-8") as file:
		has_declaration = file.read(5) == "<?xml"
	temporary = path + ".baking"
	tree.write(temporary, encoding="utf-8", xml_declaration=has_declaration)
	os.replace(temporary, path)


def list_files(folder):
	for root, _, names in os.walk(folder):
		for name in sorted(names):
			path = os.path.join(root, name)
			if name.endswith(".svg") and not os.path.islink(path) and needs_baking(path):
				yield path


def can_bake(path):
	"""A dry run on a copy in memory, so a file that cannot be baked is left alone and never counted as waiting"""
	try:
		register_namespaces(path)
		bake(ElementTree.parse(path).getroot(), IDENTITY, False)
	except (CannotBake, AttributeError, IndexError, ValueError):
		return False
	return True


def main():
	is_check = sys.argv[1:2] == ["--check"]
	folders = sys.argv[2:] if is_check else sys.argv[1:]
	if not folders:
		sys.exit(__doc__)
	waiting = [path for folder in folders for path in list_files(folder) if can_bake(path)]
	if is_check:
		sys.exit(1 if waiting else 0)
	for path in waiting:
		bake_file(path)
	print(f"baked {len(waiting)} icons")


if __name__ == "__main__":
	main()

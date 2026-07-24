#!/usr/bin/env python
"""
Materials pass for res://Assets/Kenney and res://Assets/Quaternius.

Run this (from the project root, after tools/extract_kenney_quaternius_materials.gd
has been run at least once so standalone .tres materials exist to edit) whenever
new assets are dragged into an already-adopted Kenney/Quaternius pack, so the
normal-map/roughness/metallic pass doesn't need to be redone by hand.

For every extracted StandardMaterial3D .tres:
  1. Locate the material's current albedo texture (if any) via its ext_resource.
  2. Look for a same-named "<basename>_Normal.<ext>" texture next to it, keyed
     off the albedo texture name, the .tres file's own name, and the source
     model's basename -- and also check res://Assets/Textures/ for one
     matching any of those.
  3. If found and not already wired: add an ext_resource + set
     normal_enabled/normal_texture/normal_scale.
  4. If not found anywhere: leave alone, record on the "needs sourcing" list.
  5. Standardize roughness/metallic unless a roughness_texture is already
     present (respected as an existing texture-based roughness source).

Does not touch albedo_texture/albedo_color at all.

Note: Godot's StandardMaterial3D .tres files do not use a load_steps field
(confirmed against real extracted output), so none is added/maintained here.
"""
import os
import re
import json

ROOT = os.getcwd()
SCAN_DIRS = [os.path.join(ROOT, "Assets", "Kenney"), os.path.join(ROOT, "Assets", "Quaternius")]
SHARED_TEXTURES_DIR = os.path.join(ROOT, "Assets", "Textures")

METAL_KEYWORDS = [
	"metal", "steel", "iron", "chain", "sword", "blade", "gun", "rifle",
	"pistol", "cannon", "anchor", "nail", "hinge", "lock", "coin",
	"armor", "armour", "shield", "trim_metal", "gold", "silver", "bronze",
	"copper", "rust", "sci-fi", "scifi", "robot", "mech",
]

NORMAL_EXTS = [".png", ".jpg", ".jpeg", ".tga", ".webp"]

# Suffixes commonly used for the albedo/base-color map, stripped off to
# recover the shared stem a pack uses across its parallel PBR maps, e.g.
# "T_WoodTrim_BaseColor.png" / "T_WoodTrim_Normal.png" / "T_WoodTrim_Roughness.png"
# all share the stem "T_WoodTrim".
ALBEDO_SUFFIXES = [
	"_basecolor", "_base_color", "_albedo", "_diffuse", "_color", "_colour", "_d",
]

ORGANIC_ROUGHNESS = 0.7
ORGANIC_METALLIC = 0.0
METAL_ROUGHNESS = 0.35
METAL_METALLIC = 0.9

# Global index of every "<stem>_Normal.<ext>" file under the scanned packs,
# keyed by lowercase stem -> list of absolute paths. Built once in main().
NORMAL_MAP_INDEX = {}
NORMAL_FILE_RE = re.compile(r"^(.*)_normal$", re.IGNORECASE)

EXT_RES_RE = re.compile(
	r'\[ext_resource type="([^"]+)"(?: uid="([^"]*)")? path="([^"]*)" id="([^"]+)"\]'
)
RESOURCE_SECTION_RE = re.compile(r'\[resource\](.*)\Z', re.DOTALL)
GD_RESOURCE_HEADER_RE = re.compile(r'^\[gd_resource type="([^"]+)"[^\]]*\]', re.MULTILINE)


def find_tres_files():
	out = []
	for base in SCAN_DIRS:
		for dirpath, _dirnames, filenames in os.walk(base):
			for fn in filenames:
				if fn.endswith(".tres"):
					out.append(os.path.join(dirpath, fn))
	return sorted(out)


def to_res_path(abs_path):
	rel = os.path.relpath(abs_path, ROOT).replace("\\", "/")
	return "res://" + rel


def from_res_path(res_path):
	rel = res_path[len("res://"):]
	return os.path.join(ROOT, *rel.split("/"))


def parse_ext_resources(text):
	# id -> (type, path)
	result = {}
	for m in EXT_RES_RE.finditer(text):
		res_type, _uid, path, rid = m.group(1), m.group(2), m.group(3), m.group(4)
		result[rid] = (res_type, path)
	return result


def get_next_ext_id(ext_ids):
	n = 1
	existing_nums = set()
	for rid in ext_ids:
		m = re.match(r"(\d+)", rid)
		if m:
			existing_nums.add(int(m.group(1)))
	while n in existing_nums:
		n += 1
	return str(n)


def build_normal_map_index():
	index = {}
	for base in SCAN_DIRS + [SHARED_TEXTURES_DIR]:
		for dirpath, _dirnames, filenames in os.walk(base):
			for fn in filenames:
				stem, ext = os.path.splitext(fn)
				if ext.lower() not in NORMAL_EXTS:
					continue
				m = NORMAL_FILE_RE.match(stem)
				if not m:
					continue
				key = m.group(1).lower()
				index.setdefault(key, []).append(os.path.join(dirpath, fn))
	return index


def strip_albedo_suffix(name):
	lower = name.lower()
	for suffix in ALBEDO_SUFFIXES:
		if lower.endswith(suffix) and len(name) > len(suffix):
			return name[: -len(suffix)]
	return None


def closest_match(material_dir, paths):
	def shared_prefix_len(p):
		a = os.path.normpath(material_dir).split(os.sep)
		b = os.path.normpath(os.path.dirname(p)).split(os.sep)
		n = 0
		for x, y in zip(a, b):
			if x == y:
				n += 1
			else:
				break
		return n

	return max(paths, key=shared_prefix_len)


def find_normal_map_candidate(material_dir, albedo_res_path, resource_name, tres_stem):
	stems = []

	if albedo_res_path:
		abs_albedo = from_res_path(albedo_res_path)
		albedo_base, _ext = os.path.splitext(os.path.basename(abs_albedo))
		stems.append(albedo_base)
		stripped = strip_albedo_suffix(albedo_base)
		if stripped:
			stems.append(stripped)

	stems.append(tres_stem)

	if resource_name and tres_stem.endswith("_" + resource_name):
		model_base = tres_stem[: -(len(resource_name) + 1)]
		if model_base:
			stems.append(model_base)

	if resource_name:
		stems.append(resource_name)

	seen = set()
	for stem in stems:
		key = stem.lower()
		if key in seen:
			continue
		seen.add(key)
		paths = NORMAL_MAP_INDEX.get(key)
		if paths:
			return closest_match(material_dir, paths)

	return None


def classify_metal(text_blobs):
	joined = " ".join(b.lower() for b in text_blobs if b)
	return any(kw in joined for kw in METAL_KEYWORDS)


def process_file(path):
	with open(path, "r", encoding="utf-8") as f:
		text = f.read()

	header_match = GD_RESOURCE_HEADER_RE.search(text)
	if not header_match or "StandardMaterial3D" not in header_match.group(1):
		return {"path": to_res_path(path), "skipped": "not a StandardMaterial3D resource"}

	ext_resources = parse_ext_resources(text)

	res_match = RESOURCE_SECTION_RE.search(text)
	if not res_match:
		return {"path": to_res_path(path), "skipped": "no [resource] section found"}
	resource_body = res_match.group(1)

	changes = []
	tres_stem = os.path.splitext(os.path.basename(path))[0]

	# --- resource_name ---
	name_match = re.search(r'resource_name\s*=\s*"([^"]*)"', resource_body)
	resource_name = name_match.group(1) if name_match else tres_stem

	# --- current albedo texture path (for normal-map basename matching only; never modified) ---
	albedo_res_path = None
	albedo_match = re.search(r'albedo_texture\s*=\s*ExtResource\("([^"]+)"\)', resource_body)
	if albedo_match:
		rid = albedo_match.group(1)
		if rid in ext_resources:
			albedo_res_path = ext_resources[rid][1]

	# --- does this material already have a normal map wired in? ---
	already_has_normal = bool(re.search(r'normal_texture\s*=\s*ExtResource\(', resource_body))

	normal_map_status = None
	if already_has_normal:
		normal_map_status = "already_wired"
	else:
		material_dir = os.path.dirname(path)
		found = find_normal_map_candidate(material_dir, albedo_res_path, resource_name, tres_stem)
		if found:
			found_res_path = to_res_path(found)
			new_id = get_next_ext_id(ext_resources.keys())
			ext_line = f'[ext_resource type="Texture2D" path="{found_res_path}" id="{new_id}"]\n'
			# Insert the new ext_resource right before the [resource] section.
			text = text.replace("[resource]", ext_line + "\n[resource]", 1)
			# Re-fetch resource body after insertion.
			res_match = RESOURCE_SECTION_RE.search(text)
			resource_body = res_match.group(1)

			addition = f'\nnormal_enabled = true\nnormal_texture = ExtResource("{new_id}")\nnormal_scale = 1.0'
			resource_body = resource_body.rstrip("\n") + addition + "\n"
			text = text[: res_match.start(1)] + resource_body + text[res_match.end(1):]

			changes.append(f"wired normal map: {found_res_path} (normal_scale=1.0)")
			normal_map_status = found_res_path
		else:
			normal_map_status = "NOT_FOUND"

	# --- roughness / metallic standardization ---
	has_roughness_texture = bool(re.search(r'roughness_texture\s*=\s*ExtResource\(', resource_body))
	if has_roughness_texture:
		changes.append("skipped roughness/metallic (texture-based roughness map already present)")
	else:
		blobs = [resource_name, albedo_res_path or "", path]
		is_metal = classify_metal(blobs)
		target_roughness = METAL_ROUGHNESS if is_metal else ORGANIC_ROUGHNESS
		target_metallic = METAL_METALLIC if is_metal else ORGANIC_METALLIC

		def set_or_add(body, prop, value):
			pattern = re.compile(rf'^{prop}\s*=\s*[^\n]*$', re.MULTILINE)
			line = f"{prop} = {value}"
			if pattern.search(body):
				return pattern.sub(line, body, count=1)
			else:
				return body.rstrip("\n") + f"\n{line}\n"

		res_match = RESOURCE_SECTION_RE.search(text)
		resource_body = res_match.group(1)
		old_rough_match = re.search(r'^roughness\s*=\s*([^\n]*)$', resource_body, re.MULTILINE)
		old_metal_match = re.search(r'^metallic\s*=\s*([^\n]*)$', resource_body, re.MULTILINE)
		old_rough = old_rough_match.group(1).strip() if old_rough_match else "1.0 (default)"
		old_metal = old_metal_match.group(1).strip() if old_metal_match else "0.0 (default)"

		resource_body = set_or_add(resource_body, "roughness", target_roughness)
		resource_body = set_or_add(resource_body, "metallic", target_metallic)
		text = text[: res_match.start(1)] + resource_body + text[res_match.end(1):]

		classification = "metal" if is_metal else "organic/cloth"
		changes.append(
			f"roughness {old_rough} -> {target_roughness}, metallic {old_metal} -> {target_metallic} "
			f"(classified: {classification})"
		)

	if changes:
		with open(path, "w", encoding="utf-8") as f:
			f.write(text)

	return {
		"path": to_res_path(path),
		"resource_name": resource_name,
		"changes": changes,
		"normal_map_status": normal_map_status,
	}


def main():
	global NORMAL_MAP_INDEX
	NORMAL_MAP_INDEX = build_normal_map_index()
	print(f"Indexed {sum(len(v) for v in NORMAL_MAP_INDEX.values())} normal map file(s) across {len(NORMAL_MAP_INDEX)} unique stem(s).")

	files = find_tres_files()
	results = []
	for f in files:
		try:
			results.append(process_file(f))
		except Exception as e:
			results.append({"path": to_res_path(f), "error": str(e)})

	report_path = os.path.join(ROOT, "materials_pass_report.json")
	with open(report_path, "w", encoding="utf-8") as f:
		json.dump(results, f, indent=2)

	total = len(results)
	no_normal = [r for r in results if r.get("normal_map_status") == "NOT_FOUND"]
	wired_normal = [r for r in results if r.get("normal_map_status") not in (None, "NOT_FOUND", "already_wired")]
	already = [r for r in results if r.get("normal_map_status") == "already_wired"]
	skipped = [r for r in results if "skipped" in r]
	errors = [r for r in results if "error" in r]

	print(f"Total .tres scanned: {total}")
	print(f"Normal map newly wired: {len(wired_normal)}")
	print(f"Already had normal map: {len(already)}")
	print(f"No normal map found (flagged): {len(no_normal)}")
	print(f"Skipped (not a StandardMaterial3D / no [resource] section): {len(skipped)}")
	print(f"Errors: {len(errors)}")
	print(f"Full report written to: {report_path}")


if __name__ == "__main__":
	main()

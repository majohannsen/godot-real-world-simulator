extends Node

const BATCH_SIZE = 20
const MAX_SURFACE_POLYGONS = 500
const SURFACE_Y_BASE = 0.02
const SURFACE_Y_STEP = 0.002
const SURFACE_OVERLAP_TRIM_EPSILON = 0.001
const UV_SCALE = 0.03

const SURFACE_TYPE_Z_BIAS := {
	"dirt": 0.0000,
	"gravel": 0.0002,
	"grass": 0.0004,
	"forest": 0.0006,
	"farmland": 0.0008,
	"residential": 0.0010,
	"industrial": 0.0012,
	"concrete": 0.0014,
	"asphalt": 0.0016,
	"water": 0.0018,
}

const SURFACE_COLORS := {
	"water": Color(0.13, 0.32, 0.68, 1.0),
	"grass": Color(0.23, 0.55, 0.19, 1.0),
	"forest": Color(0.14, 0.37, 0.14, 1.0),
	"residential": Color(0.66, 0.67, 0.61, 1.0),
	"industrial": Color(0.48, 0.49, 0.46, 1.0),
	"farmland": Color(0.63, 0.62, 0.35, 1.0),
	"asphalt": Color(0.21, 0.21, 0.23, 1.0),
	"concrete": Color(0.65, 0.65, 0.64, 1.0),
	"gravel": Color(0.53, 0.50, 0.44, 1.0),
	"dirt": Color(0.48, 0.33, 0.20, 1.0),
}

const DECORATIVE_DROP_ORDER := [
	"grass",
	"forest",
	"farmland",
	"residential",
	"industrial",
	"gravel",
	"dirt",
]

var ground = preload("res://objects/ground/ground.tscn")
var _material_cache: Dictionary = {}

@export var surface_textures: Dictionary = {}

func handleData(payload: Dictionary, container: Node3D, _tile_center_mx: float, _tile_center_my: float):
	if not is_instance_valid(container):
		return

	_spawn_fallback_base(container)

	var surfaces: Array = payload.get("surfaces", [])
	if surfaces.is_empty():
		return

	var filtered_surfaces = _apply_surface_budget(surfaces)
	var resolved_surfaces = _resolve_surface_overlaps(filtered_surfaces)

	for i in resolved_surfaces.size():
		if i % BATCH_SIZE == 0:
			await get_tree().process_frame
			if not is_instance_valid(container):
				return

		var item: Dictionary = resolved_surfaces[i]
		var polygon = item.get("polygon", PackedVector2Array())
		if not (polygon is PackedVector2Array):
			continue
		if polygon.size() < 3:
			continue

		var surface_type = String(item.get("surface_type", "grass"))
		var priority = int(item.get("priority", 1))
		var type_bias = float(SURFACE_TYPE_Z_BIAS.get(surface_type, 0.0))
		var y_offset = SURFACE_Y_BASE + (float(priority) * SURFACE_Y_STEP) + type_bias

		if not is_instance_valid(container):
			return
		var surface_mesh = _build_polygon_mesh(polygon, y_offset, surface_type)
		if surface_mesh:
			container.add_child(surface_mesh)

func _spawn_fallback_base(container: Node3D) -> void:
	var inst = ground.instantiate()
	if inst is Node3D:
		inst.transform.origin = Vector3.ZERO
	container.add_child(inst)

func _apply_surface_budget(surfaces: Array) -> Array:
	if surfaces.size() <= MAX_SURFACE_POLYGONS:
		return surfaces

	var reduced: Array = surfaces.duplicate()
	var overflow = reduced.size() - MAX_SURFACE_POLYGONS

	for surface_type in DECORATIVE_DROP_ORDER:
		if overflow <= 0:
			break
		var next: Array = []
		for item in reduced:
			if overflow > 0 and String(item.get("surface_type", "")) == surface_type:
				overflow -= 1
				continue
			next.append(item)
		reduced = next

	if reduced.size() > MAX_SURFACE_POLYGONS:
		reduced.resize(MAX_SURFACE_POLYGONS)

	return reduced

func _subtract_holes(outer: PackedVector2Array, holes: Array) -> Array:
	var pieces: Array = [outer]

	for hole in holes:
		if not (hole is PackedVector2Array):
			continue
		if hole.size() < 3:
			continue

		var next_pieces: Array = []
		for piece in pieces:
			if not (piece is PackedVector2Array):
				continue
			var remaining = _subtract_polygon_by_mask(piece, hole)
			for result_piece in remaining:
				next_pieces.append(result_piece)
		pieces = next_pieces
		if pieces.is_empty():
			break

	return pieces

func _subtract_polygon_by_mask(source_polygon: PackedVector2Array, mask_polygon: PackedVector2Array) -> Array:
	if source_polygon.size() < 3:
		return []
	if mask_polygon.size() < 3:
		return [source_polygon]

	var mask_candidates: Array = []
	var expanded = Geometry2D.offset_polygon(mask_polygon, SURFACE_OVERLAP_TRIM_EPSILON)
	if expanded is Array and not expanded.is_empty():
		for expanded_part in expanded:
			if expanded_part is PackedVector2Array and expanded_part.size() >= 3:
				mask_candidates.append(expanded_part)
	if mask_candidates.is_empty():
		mask_candidates.append(mask_polygon)

	var remaining_parts: Array = [source_polygon]
	for candidate in mask_candidates:
		var next_parts: Array = []
		for part in remaining_parts:
			if not (part is PackedVector2Array):
				continue
			var intersections: Array = Geometry2D.intersect_polygons(part, candidate)
			if intersections.is_empty():
				next_parts.append(part)
				continue
			var clipped: Array = Geometry2D.clip_polygons(part, candidate)
			for clipped_piece in clipped:
				if clipped_piece is PackedVector2Array and clipped_piece.size() >= 3:
					next_parts.append(clipped_piece)
		remaining_parts = next_parts
		if remaining_parts.is_empty():
			break

	return remaining_parts

func _resolve_surface_overlaps(surfaces: Array) -> Array:
	if surfaces.is_empty():
		return []

	var indexed: Array = []
	for i in surfaces.size():
		indexed.append({
			"index": i,
			"item": surfaces[i],
		})

	indexed.sort_custom(func(a, b):
		var a_item: Dictionary = a["item"]
		var b_item: Dictionary = b["item"]
		var pa = int(a_item.get("priority", 1))
		var pb = int(b_item.get("priority", 1))
		if pa == pb:
			return int(a["index"]) < int(b["index"])
		return pa > pb
	)

	var occupied_polygons: Array = []
	var resolved: Array = []

	for entry in indexed:
		var item: Dictionary = entry["item"]
		var outer = item.get("outer", PackedVector2Array())
		if not (outer is PackedVector2Array):
			continue
		if outer.size() < 3:
			continue

		var holes: Array = item.get("holes", [])
		var visible_parts = _subtract_holes(outer, holes)
		if visible_parts.is_empty():
			continue

		for occupied in occupied_polygons:
			if not (occupied is PackedVector2Array):
				continue
			var next_parts: Array = []
			for part in visible_parts:
				if not (part is PackedVector2Array):
					continue
				var remaining_parts = _subtract_polygon_by_mask(part, occupied)
				for remaining in remaining_parts:
					next_parts.append(remaining)
			visible_parts = next_parts
			if visible_parts.is_empty():
				break

		if visible_parts.is_empty():
			continue

		var surface_type = String(item.get("surface_type", "grass"))
		var priority = int(item.get("priority", 1))
		for part in visible_parts:
			if not (part is PackedVector2Array):
				continue
			resolved.append({
				"surface_type": surface_type,
				"priority": priority,
				"polygon": part,
			})
			occupied_polygons.append(part)

	return resolved

func _build_polygon_mesh(polygon: PackedVector2Array, y_offset: float, surface_type: String) -> MeshInstance3D:
	if polygon.size() < 3:
		return null

	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	if indices.size() < 3:
		return null

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for index in indices:
		var p: Vector2 = polygon[index]
		st.set_uv(Vector2(p.x * UV_SCALE, p.y * UV_SCALE))
		st.add_vertex(Vector3(p.x, y_offset, p.y))

	st.generate_normals()
	var mesh = st.commit()
	if mesh == null:
		return null

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.material_override = _get_surface_material(surface_type)
	return mesh_instance

func _get_surface_material(surface_type: String) -> StandardMaterial3D:
	if _material_cache.has(surface_type):
		return _material_cache[surface_type]

	var material = StandardMaterial3D.new()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	material.metallic = 0.0
	material.albedo_color = SURFACE_COLORS.get(surface_type, SURFACE_COLORS["grass"])

	var texture_candidate = surface_textures.get(surface_type)
	if texture_candidate is Texture2D:
		material.albedo_texture = texture_candidate

	_material_cache[surface_type] = material
	return material

func flush_all_instances():
	_material_cache.clear()

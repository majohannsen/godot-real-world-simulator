extends Node

const BATCH_SIZE = 20
const MAX_STREET_POLYGONS = 400
const STREET_Y_BASE = 0.08
const STREET_Y_STEP = 0.0012
const ROAD_OVERLAP_TRIM_EPSILON = 0.001
const UV_SCALE = 0.05

const ROAD_TYPE_Z_BIAS := {
	"dirt": 0.0000,
	"gravel": 0.0002,
	"concrete": 0.0004,
	"asphalt": 0.0006,
}

const ROAD_COLORS := {
	"asphalt": Color(0.16, 0.16, 0.18, 1.0),
	"concrete": Color(0.63, 0.63, 0.62, 1.0),
	"gravel": Color(0.49, 0.46, 0.41, 1.0),
	"dirt": Color(0.41, 0.28, 0.17, 1.0),
}

var _material_cache: Dictionary = {}

@export var road_textures: Dictionary = {}

func handleData(data: Array, container: Node3D, _tile_center_mx: float, _tile_center_my: float):
	if not is_instance_valid(container):
		return

	var roads = _prioritize_roads(data)
	var resolved_roads = _resolve_road_overlaps(roads)
	for i in resolved_roads.size():
		if i % BATCH_SIZE == 0:
			await get_tree().process_frame
			if not is_instance_valid(container):
				return

		var road_item: Dictionary = resolved_roads[i]
		var polygon = road_item.get("polygon", PackedVector2Array())
		if not (polygon is PackedVector2Array):
			continue
		if polygon.size() < 3:
			continue

		var surface_type = String(road_item.get("surface_type", "asphalt"))
		var priority = int(road_item.get("priority", 1))
		var type_bias = float(ROAD_TYPE_Z_BIAS.get(surface_type, 0.0))
		var y_offset = STREET_Y_BASE + (float(priority) * STREET_Y_STEP) + type_bias

		if not is_instance_valid(container):
			return
		var road_mesh = _build_polygon_mesh(polygon, y_offset, surface_type)
		if road_mesh:
			container.add_child(road_mesh)

func _prioritize_roads(data: Array) -> Array:
	if data.size() <= MAX_STREET_POLYGONS:
		return data

	var explicit: Array = []
	var buffered: Array = []
	for item in data:
		if String(item.get("source", "buffered")) == "explicit":
			explicit.append(item)
		else:
			buffered.append(item)

	var result: Array = []
	for item in explicit:
		if result.size() >= MAX_STREET_POLYGONS:
			break
		result.append(item)
	for item in buffered:
		if result.size() >= MAX_STREET_POLYGONS:
			break
		result.append(item)

	return result

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
	var expanded = Geometry2D.offset_polygon(mask_polygon, ROAD_OVERLAP_TRIM_EPSILON)
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

func _resolve_road_overlaps(roads: Array) -> Array:
	if roads.is_empty():
		return []

	var indexed: Array = []
	for i in roads.size():
		indexed.append({
			"index": i,
			"item": roads[i],
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

		var surface_type = String(item.get("surface_type", "asphalt"))
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
	mesh_instance.material_override = _get_road_material(surface_type)
	return mesh_instance

func _get_road_material(surface_type: String) -> StandardMaterial3D:
	if _material_cache.has(surface_type):
		return _material_cache[surface_type]

	var material = StandardMaterial3D.new()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	material.albedo_color = ROAD_COLORS.get(surface_type, ROAD_COLORS["asphalt"])

	var texture_candidate = road_textures.get(surface_type)
	if texture_candidate is Texture2D:
		material.albedo_texture = texture_candidate

	_material_cache[surface_type] = material
	return material

func flush_all_instances():
	_material_cache.clear()

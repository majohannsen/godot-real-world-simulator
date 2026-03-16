extends Node3D

@onready var streetLightSpawner = $StreetLightSpawner
@onready var treeSpawner = $TreeSpawner
@onready var picnicTableSpawner = $PicnicTableSpawner
@onready var groundSpawner = $GroundSpawner
@onready var streetSpawner = $StreetSpawner
@onready var houseSpawner = $HouseSpawner
@onready var trashBasketSpawner = $TrashBasketSpawner
@onready var hydrantSpawner = $HydrantSpawner
@onready var railSpawner = $RailSpawner

@onready var main = get_parent()

var _active_request: HTTPRequest = null
const MAX_RETRIES = 3
const RATE_LIMIT_DELAY = 20.0
const CACHE_DIR = "user://chunk_cache/"
const CACHE_TTL_SECONDS = 7 * 24 * 3600 # 7 days
const CHUNK_M = 1000.0
const QUERY_SCHEMA_VERSION = "overpass_ground_surfaces_v1"
const MIN_ROAD_WIDTH_M = 3.0
const MAX_ROAD_WIDTH_M = 40.0
const DEFAULT_LANE_WIDTH_M = 3.25

const SURFACE_DRAW_PRIORITY := {
	"grass": 1,
	"dirt": 2,
	"gravel": 3,
	"forest": 4,
	"farmland": 5,
	"residential": 6,
	"industrial": 7,
	"concrete": 8,
	"asphalt": 9,
	"water": 10,
}

const HIGHWAY_WIDTH_DEFAULTS := {
	"motorway": 16.0,
	"trunk": 14.0,
	"primary": 12.0,
	"secondary": 10.0,
	"tertiary": 9.0,
	"residential": 8.0,
	"service": 6.0,
	"unclassified": 7.0,
	"living_street": 6.0,
	"track": 5.0,
	"path": 4.0,
	"footway": 3.5,
	"cycleway": 4.0,
}

const ROAD_SURFACE_DRAW_PRIORITY := {
	"dirt": 1,
	"gravel": 2,
	"concrete": 3,
	"asphalt": 4,
}

var _pending_url: String = ""
var _loading_chunk: Vector2i
var _retry_count: int = 0
var _chunk_nodes: Dictionary = {} # Vector2i tile -> Node3D
var _load_queue: Array[Vector2i] = []
var _is_busy: bool = false

func _ready():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))

func _cache_path(tile: Vector2i) -> String:
	return CACHE_DIR + "tile_%d_%d_%s.json" % [tile.x, tile.y, QUERY_SCHEMA_VERSION]

func _load_cache(tile: Vector2i) -> String:
	var path = _cache_path(tile)
	if not FileAccess.file_exists(path):
		return ""
	var modified = FileAccess.get_modified_time(path)
	if (Time.get_unix_time_from_system() - modified) > CACHE_TTL_SECONDS:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return ""
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return ""
	return f.get_as_text()

func _save_cache(tile: Vector2i, json_text: String) -> void:
	var f = FileAccess.open(_cache_path(tile), FileAccess.WRITE)
	if f:
		f.store_string(json_text)

func _cancel_in_progress_load():
	# Only cancel the pending HTTP request — any already-running _processJson
	# coroutines are self-contained and will clean up via is_instance_valid guards.
	if _active_request and is_instance_valid(_active_request):
		_active_request.cancel_request()
		_active_request.queue_free()
		_active_request = null
	_pending_url = ""
	_retry_count = 0

func flush_all_instances():
	_cancel_in_progress_load()
	_load_queue = []
	_is_busy = false
	for tile in _chunk_nodes.keys():
		var node = _chunk_nodes[tile]
		if is_instance_valid(node):
			node.queue_free()
	_chunk_nodes = {}

func shift_all_roots(delta_mx: float, delta_my: float):
	for tile in _chunk_nodes.keys():
		var node = _chunk_nodes[tile]
		if is_instance_valid(node):
			node.position += Vector3(delta_mx, 0, delta_my)

func unload_chunk(tile: Vector2i):
	_load_queue.erase(tile)
	if _loading_chunk == tile:
		_cancel_in_progress_load()
		_on_load_done()
	var node = _chunk_nodes.get(tile)
	if node and is_instance_valid(node):
		node.queue_free()
	_chunk_nodes.erase(tile)

func spawn_chunk(tile: Vector2i):
	if _is_busy:
		if not _load_queue.has(tile):
			_load_queue.append(tile)
		return
	_load_tile(tile)

func _load_tile(tile: Vector2i):
	_is_busy = true
	_loading_chunk = tile
	var cached = _load_cache(tile)
	if cached != "":
		print("Loaded data for chunk %s from cache" % tile)
		_processJson(tile, cached)
		return
	_fetchAllCoordinates(tile)

func _on_load_done():
	if not _is_busy:
		return
	_is_busy = false
	while _load_queue.size() > 0:
		var next = _load_queue.pop_front()
		if main.loadedChunks.has(next) and not main.loadedChunks[next]:
			_load_tile(next)
			return

func _fetchAllCoordinates(tile: Vector2i):
	print("Fetching data for chunk %s from Overpass API..." % tile)
	var min_corner = main.calculator.metersToLatLon(tile.x * CHUNK_M, tile.y * CHUNK_M)
	var max_corner = main.calculator.metersToLatLon((tile.x + 1) * CHUNK_M, (tile.y + 1) * CHUNK_M)
	var lat1 = min_corner.x
	var lon1 = min_corner.y
	var lat2 = max_corner.x
	var lon2 = max_corner.y
	var baseUrl = 'https://overpass-api.de/api/interpreter' + "?data="
	var bbox = "[bbox:%s,%s,%s,%s]" % [lat1, lon1, lat2, lon2]
	var out = '[out:json]'
	var timeout = '[timeout:30]'
	var query = bbox + out + timeout + ';(' \
		+'node[highway=street_lamp];' \
		+'node[natural=tree];' \
		+'node[leisure=picnic_table];' \
		+'node[amenity=waste_basket]["indoor"!="yes"];' \
		+'node[emergency=fire_hydrant];' \
		+'way[highway];' \
		+'way["area:highway"];' \
		+'way[highway][area=yes];' \
		+'way[building];' \
		+'way["railway"="rail"];' \
		+'way[landuse];' \
		+'way[natural];' \
		+'way[surface];' \
		+'relation[type=multipolygon][landuse];' \
		+'relation[type=multipolygon][natural];' \
		+'relation[type=multipolygon][surface];' \
		+'relation[type=multipolygon][highway];' \
		+'relation[type=multipolygon]["area:highway"];' \
		+');out geom;'
	_pending_url = baseUrl + query.uri_encode()
	_retry_count = 0
	_doRequest()

func _doRequest():
	var request = HTTPRequest.new()
	add_child(request)
	_active_request = request
	request.request_completed.connect(_handleCombinedResponse)
	request.request(_pending_url)

func _handleCombinedResponse(result, response_code, _headers, body):
	# Capture tile locally — _loading_chunk may be overwritten if spawn_chunk
	# is called again before the awaited spawners finish.
	var tile = _loading_chunk
	if _active_request and is_instance_valid(_active_request):
		_active_request.queue_free()
		_active_request = null
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("Overpass request failed: result=%d, http=%d" % [result, response_code])
		var is_rate_limited = (response_code == 429)
		if not is_rate_limited:
			_retry_count += 1
		if (is_rate_limited or _retry_count <= MAX_RETRIES) and _pending_url != "":
			var delay: float
			if is_rate_limited:
				delay = RATE_LIMIT_DELAY
				print("Rate limited (429). Waiting %ds before retrying..." % delay)
			else:
				delay = pow(2, _retry_count - 1) # 1s, 2s, 4s
				print("Retrying in %ds (attempt %d/%d)..." % [delay, _retry_count, MAX_RETRIES])
			await get_tree().create_timer(delay).timeout
			if _pending_url != "": # may have been cancelled by flush
				_doRequest()
		else:
			_on_load_done()
		return
	var json_text = body.get_string_from_utf8()
	_save_cache(tile, json_text)
	_processJson(tile, json_text)

func _processJson(tile: Vector2i, json_text: String) -> void:
	var json = JSON.parse_string(json_text)
	if not json:
		print("Combined response is empty or invalid")
		_on_load_done()
		return

	print("Processing chunk %s, elements: %d" % [tile, json["elements"].size()])

	var all_elements = json["elements"]

	var street_lights = []
	var trees = []
	var picnic_tables = []
	var trash_baskets = []
	var hydrants = []
	var houses = []
	var rails = []
	var surface_way_candidates = []
	var surface_relation_candidates = []
	var road_explicit_way_candidates = []
	var road_centerline_way_candidates = []
	var road_relation_candidates = []

	for element in all_elements:
		if !element.has("tags"):
			continue
		var tags = element["tags"]
		if element["type"] == "node":
			if tags.has("highway") and tags["highway"] == "street_lamp":
				street_lights.append(element)
			elif tags.has("natural") and tags["natural"] == "tree":
				trees.append(element)
			elif tags.has("leisure") and tags["leisure"] == "picnic_table":
				picnic_tables.append(element)
			elif tags.has("amenity") and tags["amenity"] == "waste_basket":
				trash_baskets.append(element)
			elif tags.has("emergency") and tags["emergency"] == "fire_hydrant":
				hydrants.append(element)
		elif element["type"] == "way":
			if tags.has("building"):
				houses.append(element)
			if tags.has("railway") and tags["railway"] == "rail":
				rails.append(element)
			if _is_surface_way_candidate(tags):
				surface_way_candidates.append(element)
			if _is_road_way_candidate(tags):
				if _is_explicit_road_area(tags):
					road_explicit_way_candidates.append(element)
				elif tags.has("highway"):
					road_centerline_way_candidates.append(element)
		elif element["type"] == "relation":
			if _is_surface_relation_candidate(tags):
				surface_relation_candidates.append(element)
			if _is_road_relation_candidate(tags):
				road_relation_candidates.append(element)

	var tile_center_mx: float = (tile.x + 0.5) * CHUNK_M
	var tile_center_my: float = (tile.y + 0.5) * CHUNK_M

	var surface_payload = _build_surface_payload(
		surface_way_candidates,
		surface_relation_candidates,
		tile_center_mx,
		tile_center_my
	)

	var street_polygons = _build_street_payload(
		road_explicit_way_candidates,
		road_relation_candidates,
		road_centerline_way_candidates,
		tile_center_mx,
		tile_center_my
	)

	print("Chunk %s polygons: surfaces=%d roads=%d" % [tile, surface_payload["surfaces"].size(), street_polygons.size()])

	var chunk_root = Node3D.new()
	chunk_root.visible = false
	chunk_root.position = Vector3(tile_center_mx - main.origin_mx, 0, tile_center_my - main.origin_my)
	add_child(chunk_root)
	_chunk_nodes[tile] = chunk_root

	await groundSpawner.handleData(surface_payload, chunk_root, tile_center_mx, tile_center_my)
	if not is_instance_valid(chunk_root):
		return
	await streetLightSpawner.handleData(street_lights, chunk_root, tile_center_mx, tile_center_my)
	if not is_instance_valid(chunk_root):
		return
	await treeSpawner.handleData(trees, chunk_root, tile_center_mx, tile_center_my)
	if not is_instance_valid(chunk_root):
		return
	await picnicTableSpawner.handleData(picnic_tables, chunk_root, tile_center_mx, tile_center_my)
	if not is_instance_valid(chunk_root):
		return
	await trashBasketSpawner.handleData(trash_baskets, chunk_root, tile_center_mx, tile_center_my)
	if not is_instance_valid(chunk_root):
		return
	await hydrantSpawner.handleData(hydrants, chunk_root, tile_center_mx, tile_center_my)
	if not is_instance_valid(chunk_root):
		return
	await streetSpawner.handleData(street_polygons, chunk_root, tile_center_mx, tile_center_my)
	if not is_instance_valid(chunk_root):
		return
	await houseSpawner.handleData(houses, chunk_root, tile_center_mx, tile_center_my)
	if not is_instance_valid(chunk_root):
		return
	await railSpawner.handleData(rails, chunk_root, tile_center_mx, tile_center_my)

	if is_instance_valid(chunk_root):
		chunk_root.visible = true
		main.onChunkLoaded(tile)
	_on_load_done()

func _build_surface_payload(surface_ways: Array, surface_relations: Array, tile_center_mx: float, tile_center_my: float) -> Dictionary:
	var surfaces: Array = []
	var dedupe: Dictionary = {}

	for way in surface_ways:
		var tags: Dictionary = way.get("tags", {})
		var ring = _way_to_polygon_local(way, tile_center_mx, tile_center_my)
		if ring.size() < 3:
			continue
		var clipped_items = _clip_polygon_with_holes_to_chunk(ring, [])
		var surface_type = _classify_surface(tags)
		for item in clipped_items:
			var poly_key = "%s|%s" % [surface_type, _ring_signature(item["outer"])]
			if dedupe.has(poly_key):
				continue
			dedupe[poly_key] = true
			surfaces.append({
				"surface_type": surface_type,
				"priority": SURFACE_DRAW_PRIORITY.get(surface_type, 1),
				"outer": item["outer"],
				"holes": item["holes"],
			})

	for relation in surface_relations:
		var tags: Dictionary = relation.get("tags", {})
		var relation_polygons = _relation_to_polygons_local(relation, tile_center_mx, tile_center_my)
		if relation_polygons.is_empty():
			continue
		var surface_type = _classify_surface(tags)
		for relation_poly in relation_polygons:
			var clipped_items = _clip_polygon_with_holes_to_chunk(relation_poly["outer"], relation_poly["holes"])
			for item in clipped_items:
				var poly_key = "%s|%s" % [surface_type, _ring_signature(item["outer"])]
				if dedupe.has(poly_key):
					continue
				dedupe[poly_key] = true
				surfaces.append({
					"surface_type": surface_type,
					"priority": SURFACE_DRAW_PRIORITY.get(surface_type, 1),
					"outer": item["outer"],
					"holes": item["holes"],
				})

	return {
		"surfaces": surfaces,
	}

func _build_street_payload(explicit_road_ways: Array, road_relations: Array, centerline_road_ways: Array, tile_center_mx: float, tile_center_my: float) -> Array:
	var roads: Array = []
	var dedupe: Dictionary = {}
	var explicit_signatures: Dictionary = {}

	for way in explicit_road_ways:
		var tags: Dictionary = way.get("tags", {})
		var ring = _way_to_polygon_local(way, tile_center_mx, tile_center_my)
		if ring.size() < 3:
			continue
		var road_surface_type = _classify_road_surface(tags)
		var clipped_items = _clip_polygon_with_holes_to_chunk(ring, [])
		for item in clipped_items:
			var poly_key = "exp|%s|%s" % [road_surface_type, _ring_signature(item["outer"])]
			if dedupe.has(poly_key):
				continue
			dedupe[poly_key] = true
			roads.append({
				"surface_type": road_surface_type,
				"source": "explicit",
				"priority": _road_draw_priority(road_surface_type, "explicit"),
				"outer": item["outer"],
				"holes": item["holes"],
			})
		var signature = _road_signature(tags)
		if signature != "":
			explicit_signatures[signature] = true

	for relation in road_relations:
		var tags: Dictionary = relation.get("tags", {})
		var relation_polygons = _relation_to_polygons_local(relation, tile_center_mx, tile_center_my)
		if relation_polygons.is_empty():
			continue
		var road_surface_type = _classify_road_surface(tags)
		for relation_poly in relation_polygons:
			var clipped_items = _clip_polygon_with_holes_to_chunk(relation_poly["outer"], relation_poly["holes"])
			for item in clipped_items:
				var poly_key = "exprel|%s|%s" % [road_surface_type, _ring_signature(item["outer"])]
				if dedupe.has(poly_key):
					continue
				dedupe[poly_key] = true
				roads.append({
					"surface_type": road_surface_type,
					"source": "explicit",
					"priority": _road_draw_priority(road_surface_type, "explicit"),
					"outer": item["outer"],
					"holes": item["holes"],
				})
		var signature = _road_signature(tags)
		if signature != "":
			explicit_signatures[signature] = true

	for way in centerline_road_ways:
		var tags: Dictionary = way.get("tags", {})
		var signature = _road_signature(tags)
		if signature != "" and explicit_signatures.has(signature):
			continue
		var line = _way_to_polyline_local(way, tile_center_mx, tile_center_my)
		if line.size() < 2:
			continue
		var width_m = _derive_road_width(tags)
		var buffered_polygons = _buffer_polyline_to_polygons(line, width_m)
		if buffered_polygons.is_empty():
			continue
		var road_surface_type = _classify_road_surface(tags)
		for buffered in buffered_polygons:
			if not (buffered is PackedVector2Array):
				continue
			if buffered.size() < 3:
				continue
			var clipped_items = _clip_polygon_with_holes_to_chunk(buffered, [])
			for item in clipped_items:
				var poly_key = "buf|%s|%s" % [road_surface_type, _ring_signature(item["outer"])]
				if dedupe.has(poly_key):
					continue
				dedupe[poly_key] = true
				roads.append({
					"surface_type": road_surface_type,
					"source": "buffered",
					"priority": _road_draw_priority(road_surface_type, "buffered"),
					"width_m": width_m,
					"outer": item["outer"],
					"holes": item["holes"],
				})

	return roads

func _is_surface_way_candidate(tags: Dictionary) -> bool:
	if _is_road_tagged(tags):
		return false
	return tags.has("landuse") or tags.has("natural") or tags.has("surface")

func _is_surface_relation_candidate(tags: Dictionary) -> bool:
	if _is_road_tagged(tags):
		return false
	return tags.has("landuse") or tags.has("natural") or tags.has("surface")

func _is_road_way_candidate(tags: Dictionary) -> bool:
	return tags.has("highway") or tags.has("area:highway")

func _is_road_relation_candidate(tags: Dictionary) -> bool:
	return tags.has("highway") or tags.has("area:highway")

func _is_explicit_road_area(tags: Dictionary) -> bool:
	if tags.has("area:highway"):
		return true
	if tags.has("highway") and String(tags.get("area", "")).to_lower() == "yes":
		return true
	return false

func _is_road_tagged(tags: Dictionary) -> bool:
	return tags.has("highway") or tags.has("area:highway")

func _classify_surface(tags: Dictionary) -> String:
	var natural = String(tags.get("natural", "")).to_lower()
	var landuse = String(tags.get("landuse", "")).to_lower()
	var surface = String(tags.get("surface", "")).to_lower()

	# Deterministic precedence: water overrides all other generic tags.
	if natural == "water" or tags.has("water") or landuse == "reservoir" or landuse == "basin":
		return "water"

	if ["asphalt", "paved", "paving_stones", "sett", "chipseal"].has(surface):
		return "asphalt"
	if ["concrete", "concrete:plates", "concrete:lanes"].has(surface):
		return "concrete"
	if ["gravel", "fine_gravel", "pebblestone", "cobblestone", "compacted"].has(surface):
		return "gravel"
	if ["dirt", "ground", "earth", "mud", "sand", "clay", "unpaved"].has(surface):
		return "dirt"

	if ["industrial", "commercial", "retail", "brownfield", "construction"].has(landuse):
		return "industrial"
	if ["residential", "village_green", "recreation_ground", "cemetery"].has(landuse):
		return "residential"
	if ["farmland", "farmyard", "orchard", "vineyard", "allotments", "plant_nursery"].has(landuse):
		return "farmland"
	if ["forest", "wood"].has(landuse) or ["wood", "scrub", "heath"].has(natural):
		return "forest"
	if ["grass", "meadow", "greenfield", "greenery"].has(landuse) or ["grassland", "meadow"].has(natural):
		return "grass"

	# Unknown tags intentionally fall back to grass.
	return "grass"

func _classify_road_surface(tags: Dictionary) -> String:
	var surface = String(tags.get("surface", "")).to_lower()
	if ["concrete", "concrete:plates", "concrete:lanes"].has(surface):
		return "concrete"
	if ["gravel", "fine_gravel", "pebblestone", "compacted"].has(surface):
		return "gravel"
	if ["dirt", "ground", "earth", "mud", "sand", "clay", "unpaved"].has(surface):
		return "dirt"
	return "asphalt"

func _derive_road_width(tags: Dictionary) -> float:
	if tags.has("width"):
		var width_m = _extract_first_float(tags["width"])
		if width_m > 0.0:
			return clamp(width_m, MIN_ROAD_WIDTH_M, MAX_ROAD_WIDTH_M)

	if tags.has("lanes"):
		var lanes = _extract_first_float(tags["lanes"])
		if lanes > 0.0:
			return clamp(lanes * DEFAULT_LANE_WIDTH_M, MIN_ROAD_WIDTH_M, MAX_ROAD_WIDTH_M)

	var highway = String(tags.get("highway", "residential")).to_lower()
	if HIGHWAY_WIDTH_DEFAULTS.has(highway):
		return float(HIGHWAY_WIDTH_DEFAULTS[highway])
	return float(HIGHWAY_WIDTH_DEFAULTS["residential"])

func _extract_first_float(raw_value) -> float:
	var value_text = String(raw_value).replace(",", ".")
	if value_text.is_valid_float():
		return float(value_text)
	for token in value_text.split(" ", false):
		if token.is_valid_float():
			return float(token)
	for token in value_text.split(";", false):
		if token.is_valid_float():
			return float(token)
	return 0.0

func _way_to_polyline_local(way: Dictionary, tile_center_mx: float, tile_center_my: float) -> PackedVector2Array:
	var points = _geometry_to_local_points(way.get("geometry", []), tile_center_mx, tile_center_my)
	return _normalize_polyline(points)

func _way_to_polygon_local(way: Dictionary, tile_center_mx: float, tile_center_my: float) -> PackedVector2Array:
	var ring = _geometry_to_local_points(way.get("geometry", []), tile_center_mx, tile_center_my)
	if ring.size() < 3:
		return PackedVector2Array()
	if ring[0].distance_to(ring[ring.size() - 1]) > 0.01:
		ring.append(ring[0])
	return _normalize_ring(ring)

func _relation_to_polygons_local(relation: Dictionary, tile_center_mx: float, tile_center_my: float) -> Array:
	var outers: Array = []
	var inners: Array = []
	var members: Array = relation.get("members", [])

	for member in members:
		if not (member is Dictionary):
			continue
		if String(member.get("type", "")) != "way":
			continue
		var ring = _geometry_to_local_points(member.get("geometry", []), tile_center_mx, tile_center_my)
		if ring.size() < 3:
			continue
		if ring[0].distance_to(ring[ring.size() - 1]) > 0.01:
			ring.append(ring[0])
		var normalized = _normalize_ring(ring)
		if normalized.size() < 3:
			continue
		var role = String(member.get("role", "outer"))
		if role == "inner":
			inners.append(normalized)
		else:
			outers.append(normalized)

	var polygons: Array = []
	for outer in outers:
		var holes: Array = []
		for inner in inners:
			if Geometry2D.is_point_in_polygon(_polygon_center(inner), outer):
				holes.append(inner)
		polygons.append({
			"outer": outer,
			"holes": holes,
		})

	return polygons

func _geometry_to_local_points(geometry: Array, tile_center_mx: float, tile_center_my: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for point in geometry:
		if not (point is Dictionary):
			continue
		if not point.has("lat") or not point.has("lon"):
			continue
		var lat = float(point["lat"])
		var lon = float(point["lon"])
		points.append(Vector2(
			main.calculator.latToMeter(lat) - tile_center_mx,
			main.calculator.lonToMeter(lon) - tile_center_my
		))
	return points

func _normalize_polyline(line: PackedVector2Array) -> PackedVector2Array:
	var cleaned: PackedVector2Array = PackedVector2Array()
	for point in line:
		if cleaned.is_empty() or cleaned[cleaned.size() - 1].distance_to(point) > 0.01:
			cleaned.append(point)
	if cleaned.size() < 2:
		return PackedVector2Array()
	return cleaned

func _normalize_ring(ring: PackedVector2Array) -> PackedVector2Array:
	var cleaned: PackedVector2Array = PackedVector2Array()
	for point in ring:
		if cleaned.is_empty() or cleaned[cleaned.size() - 1].distance_to(point) > 0.01:
			cleaned.append(point)
	if cleaned.size() > 1 and cleaned[0].distance_to(cleaned[cleaned.size() - 1]) <= 0.01:
		cleaned.remove_at(cleaned.size() - 1)
	if cleaned.size() < 3:
		return PackedVector2Array()
	if abs(_signed_area(cleaned)) < 1.0:
		return PackedVector2Array()
	return cleaned

func _signed_area(ring: PackedVector2Array) -> float:
	var area = 0.0
	for i in ring.size():
		var j = (i + 1) % ring.size()
		area += (ring[i].x * ring[j].y) - (ring[j].x * ring[i].y)
	return area * 0.5

func _polygon_center(ring: PackedVector2Array) -> Vector2:
	var sum = Vector2.ZERO
	for p in ring:
		sum += p
	if ring.is_empty():
		return Vector2.ZERO
	return sum / float(ring.size())

func _buffer_polyline_to_polygons(polyline: PackedVector2Array, width_m: float) -> Array:
	if polyline.size() < 2:
		return []
	var half_width = max(width_m * 0.5, MIN_ROAD_WIDTH_M * 0.5)
	var offset_result = Geometry2D.offset_polyline(polyline, half_width)
	var polygons: Array = []

	if offset_result is Array and not offset_result.is_empty():
		for polygon in offset_result:
			if not (polygon is PackedVector2Array):
				continue
			var normalized = _normalize_ring(polygon)
			if normalized.size() >= 3:
				polygons.append(normalized)

	if polygons.is_empty():
		var fallback_polygon = _buffer_polyline_to_polygon_fallback(polyline, half_width)
		if fallback_polygon.size() >= 3:
			polygons.append(fallback_polygon)

	return polygons

func _buffer_polyline_to_polygon_fallback(polyline: PackedVector2Array, half_width: float) -> PackedVector2Array:
	var left_points: PackedVector2Array = PackedVector2Array()
	var right_points: PackedVector2Array = PackedVector2Array()

	for i in polyline.size():
		var p = polyline[i]
		var normal = Vector2.ZERO
		if i > 0:
			var prev_dir = polyline[i] - polyline[i - 1]
			if prev_dir.length() > 0.001:
				prev_dir = prev_dir.normalized()
				normal += Vector2(-prev_dir.y, prev_dir.x)
		if i < polyline.size() - 1:
			var next_dir = polyline[i + 1] - polyline[i]
			if next_dir.length() > 0.001:
				next_dir = next_dir.normalized()
				normal += Vector2(-next_dir.y, next_dir.x)
		if normal.length() <= 0.001:
			if i < polyline.size() - 1:
				var fallback_dir = (polyline[i + 1] - polyline[i]).normalized()
				normal = Vector2(-fallback_dir.y, fallback_dir.x)
			elif i > 0:
				var fallback_dir_end = (polyline[i] - polyline[i - 1]).normalized()
				normal = Vector2(-fallback_dir_end.y, fallback_dir_end.x)
		if normal.length() <= 0.001:
			continue
		normal = normal.normalized()
		left_points.append(p + normal * half_width)
		right_points.append(p - normal * half_width)

	if left_points.size() < 2 or right_points.size() < 2:
		return PackedVector2Array()

	var polygon: PackedVector2Array = PackedVector2Array()
	for p in left_points:
		polygon.append(p)
	for i in range(right_points.size() - 1, -1, -1):
		polygon.append(right_points[i])
	return _normalize_ring(polygon)

func _road_draw_priority(surface_type: String, source: String) -> int:
	var source_bonus = 0
	if source == "explicit":
		source_bonus = 10
	return source_bonus + int(ROAD_SURFACE_DRAW_PRIORITY.get(surface_type, 1))

func _clip_polygon_with_holes_to_chunk(outer: PackedVector2Array, holes: Array) -> Array:
	var chunk_bounds = PackedVector2Array([
		Vector2(-CHUNK_M * 0.5, -CHUNK_M * 0.5),
		Vector2(CHUNK_M * 0.5, -CHUNK_M * 0.5),
		Vector2(CHUNK_M * 0.5, CHUNK_M * 0.5),
		Vector2(-CHUNK_M * 0.5, CHUNK_M * 0.5),
	])

	var polygons: Array = []
	var clipped_outers: Array = Geometry2D.intersect_polygons(outer, chunk_bounds)
	for clipped_outer in clipped_outers:
		var normalized_outer = _normalize_ring(clipped_outer)
		if normalized_outer.size() < 3:
			continue

		var clipped_holes: Array = []
		for hole in holes:
			if not (hole is PackedVector2Array):
				continue
			var hole_parts: Array = Geometry2D.intersect_polygons(hole, normalized_outer)
			for hole_part in hole_parts:
				var normalized_hole = _normalize_ring(hole_part)
				if normalized_hole.size() >= 3:
					clipped_holes.append(normalized_hole)

		polygons.append({
			"outer": normalized_outer,
			"holes": clipped_holes,
		})

	return polygons

func _road_signature(tags: Dictionary) -> String:
	var highway = String(tags.get("highway", "")).to_lower()
	var road_name = String(tags.get("name", "")).to_lower()
	var ref = String(tags.get("ref", "")).to_lower()
	if highway == "" and road_name == "" and ref == "":
		return ""
	return "%s|%s|%s" % [highway, road_name, ref]

func _ring_signature(ring: PackedVector2Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for point in ring:
		parts.append("%.2f,%.2f" % [point.x, point.y])
	return "|".join(parts)

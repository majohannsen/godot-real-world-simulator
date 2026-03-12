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
const CACHE_DIR = "user://chunk_cache/"
const CACHE_TTL_SECONDS = 7 * 24 * 3600 # 7 days
const CHUNK_M = 1000.0
var _pending_url: String = ""
var _loading_chunk: Vector2i
var _retry_count: int = 0
var _chunk_nodes: Dictionary = {} # Vector2i tile -> Node3D
var _load_queue: Array[Vector2i] = []
var _is_busy: bool = false

func _ready():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))

func _cache_path(tile: Vector2i) -> String:
	return CACHE_DIR + "tile_%d_%d.json" % [tile.x, tile.y]

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
		+'way[building];' \
		+'way["railway"="rail"];' \
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
		_retry_count += 1
		if _retry_count <= MAX_RETRIES and _pending_url != "":
			var delay = pow(2, _retry_count - 1) # 1s, 2s, 4s
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
	var streets = []
	var houses = []
	var rails = []

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
			elif tags.has("highway"):
				streets.append(element)
			elif tags.has("railway") and tags["railway"] == "rail":
				rails.append(element)

	var tile_center_mx: float = (tile.x + 0.5) * CHUNK_M
	var tile_center_my: float = (tile.y + 0.5) * CHUNK_M

	var chunk_root = Node3D.new()
	chunk_root.visible = false
	chunk_root.position = Vector3(tile_center_mx - main.origin_mx, 0, tile_center_my - main.origin_my)
	add_child(chunk_root)
	_chunk_nodes[tile] = chunk_root

	groundSpawner.spawnGround(tile, chunk_root, tile_center_mx, tile_center_my)
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
	await streetSpawner.handleData(streets, chunk_root, tile_center_mx, tile_center_my)
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

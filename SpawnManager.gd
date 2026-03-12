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
var _pending_url: String = ""
var _loading_chunk: Vector2
var _retry_count: int = 0
var _chunk_nodes: Array[Node3D] = []

func _ready():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))

func _cache_path(chunk: Vector2) -> String:
	return CACHE_DIR + "chunk_%d_%d.json" % [int(chunk.x), int(chunk.y)]

func _load_cache(chunk: Vector2) -> String:
	var path = _cache_path(chunk)
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

func _save_cache(chunk: Vector2, json_text: String) -> void:
	var f = FileAccess.open(_cache_path(chunk), FileAccess.WRITE)
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
	for node in _chunk_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_chunk_nodes = []

func spawn_chunk(chunk: Vector2):
	_cancel_in_progress_load()
	_loading_chunk = chunk
	var cached = _load_cache(chunk)
	if cached != "":
		print("Loaded data for chunk %s from cache" % chunk)
		_processJson(chunk, cached)
		return
	_fetchAllCoordinates(chunk)

func _fetchAllCoordinates(chunk: Vector2):
	print("Fetching data for chunk %s from Overpass API..." % chunk)
	
	var lat1 = main.lat_center - main.lat_span / 2 + main.lat_span * chunk.x
	var lat2 = main.lat_center + main.lat_span / 2 + main.lat_span * chunk.x
	var lon1 = main.lon_center - main.lon_span / 2 + main.lon_span * chunk.y
	var lon2 = main.lon_center + main.lon_span / 2 + main.lon_span * chunk.y
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
	# Capture chunk locally — _loading_chunk may be overwritten if spawn_chunk
	# is called again before the awaited spawners finish.
	var chunk = _loading_chunk
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
		return
	var json_text = body.get_string_from_utf8()
	_save_cache(chunk, json_text)
	_processJson(chunk, json_text)

func _processJson(chunk: Vector2, json_text: String) -> void:
	var json = JSON.parse_string(json_text)
	if not json:
		print("Combined response is empty or invalid")
		return
	
	print("Processing chunk %s, elements: %d" % [chunk, json["elements"].size()])
	
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

	var chunk_root = Node3D.new()
	chunk_root.visible = false
	add_child(chunk_root)
	_chunk_nodes.append(chunk_root)

	groundSpawner.spawnGround(chunk, chunk_root)
	await streetLightSpawner.handleData(street_lights, chunk_root)
	await treeSpawner.handleData(trees, chunk_root)
	await picnicTableSpawner.handleData(picnic_tables, chunk_root)
	await trashBasketSpawner.handleData(trash_baskets, chunk_root)
	await hydrantSpawner.handleData(hydrants, chunk_root)
	await streetSpawner.handleData(streets, chunk_root)
	await houseSpawner.handleData(houses, chunk_root)
	await railSpawner.handleData(rails, chunk_root)

	if is_instance_valid(chunk_root):
		chunk_root.visible = true
		main.onChunkLoaded(chunk)

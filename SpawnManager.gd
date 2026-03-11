extends Node3D

@onready var streetLightSpawner = $StreetLightSpawner
@onready var treeSpawner = $TreeSpawner
@onready var picnicTableSpawner = $PicnicTableSpawner
@onready var groundSpawner = $GroundSpawner
@onready var streetSpawner = $StreetSpawner
@onready var houseSpawner = $HouseSpawner
@onready var trashBasketSpawner = $TrashBasketSpawner
@onready var hydrantSpawner = $HydrantSpawner

@onready var main = get_parent()

var _active_request: HTTPRequest = null

func flush_all_instances():
	if _active_request and is_instance_valid(_active_request):
		_active_request.cancel_request()
		_active_request.queue_free()
		_active_request = null
	streetLightSpawner.flush_all_instances()
	groundSpawner.flush_all_instances()
	streetSpawner.flush_all_instances()
	houseSpawner.flush_all_instances()
	treeSpawner.flush_all_instances()
	trashBasketSpawner.flush_all_instances()
	hydrantSpawner.flush_all_instances()
	picnicTableSpawner.flush_all_instances()

func spawn_chunk(chunk):
	groundSpawner.spawnGround(chunk)
	_fetchAllCoordinates(chunk)

func _fetchAllCoordinates(chunk: Vector2):
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
		+');out geom;'
	var request = HTTPRequest.new()
	add_child(request)
	_active_request = request
	request.request_completed.connect(_handleCombinedResponse)
	request.request(baseUrl + query.uri_encode())

func _handleCombinedResponse(_result, _response_code, _headers, body):
	if _active_request and is_instance_valid(_active_request):
		_active_request.queue_free()
		_active_request = null
	var json = JSON.parse_string(body.get_string_from_utf8())
	if !json:
		print("Combined response is empty")
		return
	var all_elements = json["elements"]

	var street_lights = []
	var trees = []
	var picnic_tables = []
	var trash_baskets = []
	var hydrants = []
	var streets = []
	var houses = []

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

	streetLightSpawner.handleData(street_lights)
	treeSpawner.handleData(trees)
	picnicTableSpawner.handleData(picnic_tables)
	trashBasketSpawner.handleData(trash_baskets)
	hydrantSpawner.handleData(hydrants)
	streetSpawner.handleData(streets)
	houseSpawner.handleData(houses)

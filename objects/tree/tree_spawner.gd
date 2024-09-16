extends Node

var tree = preload("res://objects/tree/tree.tscn")

@onready var main = get_parent().get_parent()

var elements: Array[Vector2] = []

func fetchCoordinates(chunk: Vector2):
	var lat1 = main.lat_center - main.lat_span/2 + main.lat_span * chunk.x
	var lat2 = main.lat_center + main.lat_span/2 + main.lat_span * chunk.x
	var lon1 = main.lon_center - main.lon_span/2 + main.lon_span * chunk.y
	var lon2 = main.lon_center + main.lon_span/2 + main.lon_span * chunk.y
	var baseUrl = 'https://overpass-api.de/api/interpreter'+"?data=" 
	var bbox = "[bbox:%s,%s,%s,%s]" % [lat1,lon1,lat2,lon2]
	var out = '[out:json]'
	var timeout = '[timeout:10]'
	var query = bbox+out+timeout+';node[natural=tree];out center;'
	var request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(handleOverpassResponse)
	request.request(baseUrl+query.uri_encode())

func handleOverpassResponse(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	if !json: 
		print("Response is empty")
		return
	var buildings = json["elements"]
	for building in buildings:
		var lat = building["lat"]
		var lon = building["lon"]
		elements.append(main.latLonToCoordsInMeters(lat, lon))
	for element in elements:
		await get_tree().create_timer(0).timeout
		await spawnTree(element)

func spawnTree(coords: Vector2):
	var inst = tree.instantiate()
	inst.transform.origin = Vector3(coords.x,0,coords.y)
	add_child(inst)

func flush_all_instances():
	for child in get_children():
		child.queue_free()
	elements = []

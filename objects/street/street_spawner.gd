extends Node

var street_shape = preload("res://objects/street/street_shape.tscn")

@onready var main = get_parent().get_parent()

var streets: Array = []

func fetchCoordinates(chunk: Vector2):
	var lat1 = main.lat_center - main.lat_span/2 + main.lat_span * chunk.x
	var lat2 = main.lat_center + main.lat_span/2 + main.lat_span * chunk.x
	var lon1 = main.lon_center - main.lon_span/2 + main.lon_span * chunk.y
	var lon2 = main.lon_center + main.lon_span/2 + main.lon_span * chunk.y
	var baseUrl = 'https://overpass-api.de/api/interpreter'+"?data=" 
	var bbox = "[bbox:%s,%s,%s,%s]" % [lat1,lon1,lat2,lon2]
	var out = '[out:json]'
	var timeout = '[timeout:10]'
	var query = bbox+out+timeout+';way[highway];out geom;'
	print(baseUrl+query.uri_encode())
	var request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(handleOverpassResponse)
	request.request(baseUrl+query.uri_encode())

func handleOverpassResponse(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	if !json: 
		print("Response is empty")
		return
	var fetchedStreets = json["elements"]
	for street in fetchedStreets:
		var points: Array[Vector2] = []
		for point in street["geometry"]:
			var lat = point["lat"]
			var lon = point["lon"]
			points.append(main.latLonToCoordsInMeters(lat, lon))
		streets.append(points)
	for street in streets:
		await get_tree().create_timer(0).timeout
		await spawnStreet(street)

func spawnStreet(street: Array[Vector2]):
	var path = Path3D.new()
	path.curve = Curve3D.new()
	for point in street:
		path.curve.add_point(Vector3(point.x,0.1,point.y))
	path.add_child(street_shape.instantiate())
	add_child(path)

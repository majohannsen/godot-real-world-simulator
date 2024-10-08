extends Node

var house = preload("res://objects/house/house.tscn")

@onready var main = get_parent().get_parent()

func fetchCoordinates(chunk: Vector2):
	var lat1 = main.lat_center - main.lat_span/2 + main.lat_span * chunk.x
	var lat2 = main.lat_center + main.lat_span/2 + main.lat_span * chunk.x
	var lon1 = main.lon_center - main.lon_span/2 + main.lon_span * chunk.y
	var lon2 = main.lon_center + main.lon_span/2 + main.lon_span * chunk.y
	var baseUrl = 'https://overpass-api.de/api/interpreter'+"?data=" 
	var bbox = "[bbox:%s,%s,%s,%s]" % [lat1,lon1,lat2,lon2]
	var out = '[out:json]'
	var timeout = '[timeout:10]'
	var query = bbox+out+timeout+';way[building];out geom;'
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
	var houses: Array = []
	var heights: Array = []
	for building in buildings:
		var corners = building["geometry"]
		var cornersInMeters = []
		for corner in corners:
			var lat = corner["lat"]
			var lon = corner["lon"]
			cornersInMeters.append(main.latLonToCoordsInMeters(lat, lon))
		houses.append(cornersInMeters)
		var height = 6
		if building.has("tags"):
			if building["tags"].has("height"):
				var h = building["tags"]["height"]
				if h:
					height = float(h)
			elif building["tags"].has("building:levels"):
				var h = building["tags"]["building:levels"]
				if h:
					height = int(h) * 3
		heights.append(height)
	for i in houses.size():
		await get_tree().create_timer(0).timeout
		await spawnHouse(houses[i], heights[i])

func spawnHouse(corners, height):
	var mesh: CSGPolygon3D = CSGPolygon3D.new()
	var collider: CollisionPolygon3D = CollisionPolygon3D.new()
	mesh.mode = CSGPolygon3D.MODE_DEPTH
	mesh.depth = height;
	collider.depth = height
	mesh.rotate_x(PI/2);
	collider.rotate_x(PI/2);
	mesh.polygon = corners
	collider.polygon = corners
	var pos = collider.transform.origin
	pos.y = height/2;
	collider.transform.origin = pos
	var inst: StaticBody3D = StaticBody3D.new()
	inst.add_child(mesh)
	inst.add_child(collider)
	add_child(inst)

func flush_all_instances():
	for child in get_children():
		child.queue_free()

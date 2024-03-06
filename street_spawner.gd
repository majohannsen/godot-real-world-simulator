extends Node

const earthCircumference = 40075000
var street_shape = preload("res://street_shape.tscn")
var point_node = preload("res://point.tscn")

var streets: Array = []

func fetchCoordinates():
	var baseUrl = 'https://overpass-api.de/api/interpreter'+"?data=" 
	var bbox = '[bbox:47.41903911416618,9.726977348327638,47.421456461055044,9.731220602989199]'
	var out = '[out:json]'
	var timeout = '[timeout:10]'
	var query = bbox+out+timeout+';way[highway];out geom;'
	print(baseUrl+query.uri_encode())
	$HTTPRequest.request_completed.connect(handleOverpassResponse)
	$HTTPRequest.request(baseUrl+query.uri_encode())
	

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
			points.append(latLonToCoordsInMeters(lat, lon))
		streets.append(points)
	for street in streets:
		spawnStreet(street)

func spawnStreet(street: Array[Vector2]):
	var path = Path3D.new()
	path.curve = Curve3D.new()
	for point in street:
#		var node = point_node.instantiate()
#		node.transform.origin = Vector3(point.x,0.1,point.y)
#		add_child(node)
		path.curve.add_point(Vector3(point.x,0.1,point.y))
	path.add_child(street_shape.instantiate())
	add_child(path)

func latLonToCoordsInMeters(lat, lon):
	return Vector2(
		lat * earthCircumference / 360,
		lon * earthCircumference / 360 * cos(deg_to_rad(lat))
	)

# Called when the node enters the scene tree for the first time.
func _ready():
	fetchCoordinates()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

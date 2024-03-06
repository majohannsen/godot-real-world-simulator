extends Node

const earthCircumference = 40075000
var house = preload("res://house.tscn")
var ground = preload("res://ground.tscn")
var street_shape = preload("res://street_shape.tscn")

var houses: Array[Vector2] = []


func fetchCoordinates():
	var baseUrl = 'https://overpass-api.de/api/interpreter'+"?data=" 
	var bbox = '[bbox:47.41903911416618,9.726977348327638,47.421456461055044,9.731220602989199]'
	var out = '[out:json]'
	var timeout = '[timeout:10]'
	var query = bbox+out+timeout+';way[building];out center;'
	print(baseUrl+query.uri_encode())
	$HTTPRequest.request_completed.connect(handleOverpassResponse)
	$HTTPRequest.request(baseUrl+query.uri_encode())
	

func handleOverpassResponse(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	if !json: 
		print("Response is empty")
		return
	var buildings = json["elements"]
	for building in buildings:
		var lat = building["center"]["lat"]
		var lon = building["center"]["lon"]
		houses.append(latLonToCoordsInMeters(lat, lon))
	for house in houses:
		spawnHouse(house)

func latLonToCoordsInMeters(lat, lon):
	return Vector2(
		lat * earthCircumference / 360,
		lon * earthCircumference / 360 * cos(deg_to_rad(lat))
	)

func spawnHouse(coords: Vector2):
	var inst: StaticBody3D = house.instantiate()
	inst.transform.origin = Vector3(coords.x,0,coords.y)
	add_child(inst)

# Called when the node enters the scene tree for the first time.
func _ready():
	fetchCoordinates()
#	var street = Path3D.new()
#	street.curve = Curve3D.new()
#	street.curve.add_point(Vector3(4,0,-6))
#	street.curve.add_point(Vector3(10,0,-2))
#	street.curve.add_point(Vector3(10,0,4))
#	street.curve.add_point(Vector3(6,0,4))
#	street.curve.add_point(Vector3(4,0,8))
#	street.add_child(street_shape.instantiate())
#	add_child(street)
	

#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

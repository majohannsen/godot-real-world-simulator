extends Node

var house = preload("res://house.tscn")
var ground = preload("res://ground.tscn")

var earthCircumference = 40075000;

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
	var buildings = json["elements"]
	for building in buildings:
		var lat = building["center"]["lat"]
		var lon = building["center"]["lon"]
		houses.append(latLonToCoordsInMeters(lat, lon))
	for house in houses:
		spawnHouse(house)
	setCameraPosition()
	spawnGround()

func latLonToCoordsInMeters(lat, lon):
	return Vector2(
		lon * earthCircumference / 360 * cos(deg_to_rad(lat)),
		lat * earthCircumference / 360
	)

func spawnHouse(coords: Vector2):
	var inst: StaticBody3D = house.instantiate()
	inst.transform.origin = Vector3(coords.x,0,coords.y)
	add_child(inst)

func setCameraPosition():
	var coords: Vector2 = houses[0]
	get_viewport().get_camera_3d().position.x = coords.x
	get_viewport().get_camera_3d().position.y = 100
	get_viewport().get_camera_3d().position.z = coords.y+150

func spawnGround():
	var coords: Vector2 = houses[0]
	var inst: StaticBody3D = ground.instantiate()
	inst.transform.origin = Vector3(coords.x,0,coords.y)
	add_child(inst)

# Called when the node enters the scene tree for the first time.
func _ready():
	fetchCoordinates()
	

#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

extends Node

var house = preload("res://house.tscn")
var ground = preload("res://ground.tscn")

var houses: Array[Vector2] = []

@onready var main = get_parent()

func fetchCoordinates():
	var lat1 = main.lat_center - main.lat_span/2
	var lat2 = main.lat_center + main.lat_span/2
	var lon1 = main.lon_center - main.lon_span/2
	var lon2 = main.lon_center + main.lon_span/2
	var baseUrl = 'https://overpass-api.de/api/interpreter'+"?data=" 
	var bbox = "[bbox:%s,%s,%s,%s]" % [lat1,lon1,lat2,lon2]
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
		houses.append(main.latLonToCoordsInMeters(lat, lon))
	for house in houses:
		spawnHouse(house)

func spawnHouse(coords: Vector2):
	var inst: StaticBody3D = house.instantiate()
	inst.transform.origin = Vector3(coords.x,0,coords.y)
	add_child(inst)

# Called when the node enters the scene tree for the first time.
func _ready():

	fetchCoordinates()


#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

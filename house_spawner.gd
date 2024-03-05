extends Node

var house = preload("res://house.tscn")
var ground = preload("res://ground.tscn")

var earthCircumference = 40075000;

var houses: Array[Vector2] = []

func fetchCoordinates():
	houses.append(Vector2(47.4050971, 9.7426105))
	houses.append(Vector2(47.4050583, 9.7436344))
	houses.append(Vector2(47.4054232, 9.7430115))
	houses.append(Vector2(47.4054460, 9.7426622))
	houses.append(Vector2(47.4047326, 9.7424377))
	houses.append(Vector2(47.4052588, 9.7428630))
	houses.append(Vector2(47.4053796, 9.7431154))


func spawnHouse(coords: Vector2):
	var inst: StaticBody3D = house.instantiate()
	inst.transform.origin = Vector3(coords.x,0,coords.y)
	add_child(inst)

func latLonToCoordsInMeters(lat, lon):
	return Vector2(
		lon * earthCircumference / 360 * cos(deg_to_rad(lat)),
		lat * earthCircumference / 360
	)

func setCameraPosition():
	var coords: Vector2 = latLonToCoordsInMeters(houses[0].x, houses[0].y)
	get_viewport().get_camera_3d().position.x = coords.x
	get_viewport().get_camera_3d().position.y = 100
	get_viewport().get_camera_3d().position.z = coords.y+150

func spawnGround():
	var coords: Vector2 = latLonToCoordsInMeters(houses[0].x, houses[0].y)
	var inst: StaticBody3D = ground.instantiate()
	inst.transform.origin = Vector3(coords.x,0,coords.y)
	add_child(inst)

# Called when the node enters the scene tree for the first time.
func _ready():
	fetchCoordinates()
	for house in houses:
		spawnHouse(latLonToCoordsInMeters(house.x, house.y))
	setCameraPosition()
	spawnGround()

#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

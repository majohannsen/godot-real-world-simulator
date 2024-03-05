extends Node

var house = preload("res://house.tscn")

var earthCircumference = 40075000;


func spawnHouse(coords: Vector2):
	var inst: StaticBody3D = house.instantiate()
	inst.transform.origin = Vector3(coords.x,0,coords.y)
	add_child(inst)

func latLonToCoordsInMeters(lat, lon):
	return Vector2(
		lon * earthCircumference / 360 * cos(deg_to_rad(lat)),
		lat * earthCircumference / 360
	)

func setCameraPosition(coords: Vector2):
	get_viewport().get_camera_3d().position.x = coords.x
	get_viewport().get_camera_3d().position.z = coords.y+1.5

# Called when the node enters the scene tree for the first time.
func _ready():
	spawnHouse(latLonToCoordsInMeters(47.4050971, 9.7426105))
	setCameraPosition(latLonToCoordsInMeters(47.4050971, 9.7426105))

#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

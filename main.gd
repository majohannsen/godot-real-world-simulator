extends Node

@export var lat_span = 0.002417346889
@export var lon_span = 0.004243254662
@export var lat_center = 47.41903911
@export var lon_center = 9.726977348

const earthCircumference = 40075000
var ground = preload("res://ground.tscn")

func latLonToCoordsInMeters(lat, lon):
	return Vector2(
		latToMeter(lat),
		lonToMeter(lat, lon)
	)

func latToMeter(lat):
	return lat * earthCircumference / 360

func lonToMeter(lat, lon):
	return lon * earthCircumference / 360 * cos(deg_to_rad(lat))

func setCameraPosition():
	var coords: Vector2 = calculateCameraPosition()
	
	get_viewport().get_camera_3d().position.x = coords.x-50
	get_viewport().get_camera_3d().position.y = 100
	get_viewport().get_camera_3d().position.z = coords.y

func calculateCameraPosition():
	var x = latToMeter(lat_center)
	var y = lonToMeter(lat_center, lon_center+lon_span/2)
	return Vector2(x,y)

func spawnGround():
	var inst: StaticBody3D = ground.instantiate()
	inst.transform.origin = Vector3(latToMeter(lat_center),0,lonToMeter(lat_center, lon_center))
	add_child(inst)

# Called when the node enters the scene tree for the first time.
func _ready():
	setCameraPosition()
	spawnGround()

#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

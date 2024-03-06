extends Node

const earthCircumference = 40075000
const lat_span = 0.002417346889
const lon_span = 0.004243254662
const lat_center = 47.41903911
const lon_center = 9.726977348

var center = Vector2(latToMeter(lat_center), lonToMeter(lat_center, lon_center))

var ground = preload("res://ground.tscn")

func latLonToCoordsInMeters(lat, lon):
	return Vector2(
		latToMeter(lat),
		lonToMeter(lat, lon)
	) - center

func latToMeter(lat):
	return lat * earthCircumference / 360

func lonToMeter(lat, lon):
	return lon * earthCircumference / 360 * cos(deg_to_rad(lat))

func setCameraPosition():
	var coords: Vector2 = calculateCameraPosition()
	
	$Player.position.x = coords.x
	$Player.position.y = 15
	$Player.position.z = coords.y-20

func calculateCameraPosition():
	var x = latToMeter(lat_center)
	var y = lonToMeter(lat_center, lon_center+lon_span/2)
	return Vector2(x,y) - center

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

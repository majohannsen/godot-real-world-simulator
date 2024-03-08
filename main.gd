extends Node

const earthCircumference = 40075000
const lat_span = 0.01
const lon_span = 0.01
const lat_center = 47.41903911
const lon_center = 9.726977348

var center = Vector2(latToMeter(lat_center), lonToMeter(lat_center, lon_center))

var ground = preload("res://ground.tscn")

@onready var groundSpawner = $GroundSpawner
@onready var street

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
	$Player.position.x = 0
	$Player.position.y = 150
	$Player.position.z = 0

func spawnChunk(chunk: Vector2):
	$GroundSpawner.spawnGround(chunk)
	$StreetSpawner.fetchCoordinates(chunk)
	$HouseSpawner.fetchCoordinates(chunk)

# Called when the node enters the scene tree for the first time.
func _ready():
	setCameraPosition()
	spawnChunk(Vector2(0,0))
	spawnChunk(Vector2(0,1))
	spawnChunk(Vector2(1,0))
	spawnChunk(Vector2(1,1))

#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

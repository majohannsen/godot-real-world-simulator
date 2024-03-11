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

var loadedChunks: Array[String] = []

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

func getCurrentChunk():
	var currentChunk = Vector2()
	var gamecoords = $Player.transform.origin
	# doesnt work right (offset) probably need meter to lat lon
	var coords = latLonToCoordsInMeters(lat_center, lon_center) + Vector2(gamecoords.x, gamecoords.z)
	currentChunk.x = round(coords.x/1000) 
	currentChunk.y = round(coords.y/1000) 
	return currentChunk

# Called when the node enters the scene tree for the first time.
func _ready():
	setCameraPosition()
	print(loadedChunks)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if loadedChunks.find(str(getCurrentChunk())) == -1:
		loadedChunks.append(str(getCurrentChunk()))
		spawnChunk(getCurrentChunk())

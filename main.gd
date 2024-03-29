extends Node

const earthCircumference = 40075000
const chunk_size = 1000
const lat_span = chunk_size / 100000.0
const lon_span = chunk_size / 100000.0
const lat_center = 47.41903911
const lon_center = 9.726977348

var center = Vector2(latToMeter(lat_center), lonToMeter(lat_center, lon_center))

var ground = preload("res://ground.tscn")

@onready var groundSpawner = $GroundSpawner

var loadedChunks: Dictionary = {}

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
	currentChunk.x = round(coords.x/chunk_size) 
	currentChunk.y = round(coords.y/chunk_size) 
	return currentChunk

# Called when the node enters the scene tree for the first time.
func _ready():
	setCameraPosition()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if !loadedChunks.has(getCurrentChunk()):
		loadedChunks[getCurrentChunk()] = true
		spawnChunk(getCurrentChunk())
		print(loadedChunks)

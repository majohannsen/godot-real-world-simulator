extends Node

const earthCircumference = 40075000
const chunk_size = 1000
const lat_span = chunk_size / 100000.0
const lon_span = chunk_size / 100000.0
#const lat_center = 47.41903911
#const lon_center = 9.726977348
const lat_center = 67.831433
const lon_center = 20.277365

var center = Vector2(latToMeter(lat_center), lonToMeter(lat_center, lon_center))

var ground = preload("res://ground.tscn")

@onready var groundSpawner = $GroundSpawner

var loadedChunks: Dictionary = {}

func latLonToCoordsInMeters(lat, lon):
	print(lat, " ", lon)
	print(log(tan(PI/4 + lat/2)))
	print(Vector2(
		latToMeter(lat),
		lonToMeter(lat, lon)
	))
	return Vector2(
		latToMeter(lat),
		lonToMeter(lat, lon)
	) - center

## use Web Mercator projection

func latToMeter(lat):
	return -floor((1/(2*PI))*pow(2, 17.5)*(PI-(log(tan(PI/4 + lat/2)))))

func lonToMeter(lat, lon):
	return floor((1/(2*PI))*pow(2, 17.5)*(PI+lon))

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
	DebugDraw3D.scoped_config().set_thickness(1)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if !loadedChunks.has(getCurrentChunk()):
		loadedChunks[getCurrentChunk()] = true
		spawnChunk(getCurrentChunk())
		print(loadedChunks)
	for key in loadedChunks.keys():
		var chunk = Vector2(key)
		var lat1 = lat_center - lat_span/2 + lat_span * chunk.x
		var lat2 = lat_center + lat_span/2 + lat_span * chunk.x
		var lon1 = lon_center - lon_span/2 + lon_span * chunk.y
		var lon2 = lon_center + lon_span/2 + lon_span * chunk.y
		var pos1 = latLonToCoordsInMeters(lat1, lon1)
		var pos2 = latLonToCoordsInMeters(lat2, lon2)
		DebugDraw3D.draw_line(Vector3(pos1.x, 0, pos1.y), Vector3(pos2.x, 0, pos2.y), Color(1, 1, 0))
		DebugDraw3D.draw_line(Vector3(pos1.x, 0, pos1.y), Vector3(pos1.x, 0, pos2.y), Color(1, 1, 0))
		DebugDraw3D.draw_line(Vector3(pos1.x, 0, pos1.y), Vector3(pos2.x, 0, pos1.y), Color(1, 1, 0))
		DebugDraw3D.draw_line(Vector3(pos2.x, 0, pos1.y), Vector3(pos2.x, 0, pos2.y), Color(1, 1, 0))
		DebugDraw3D.draw_line(Vector3(pos1.x, 0, pos2.y), Vector3(pos2.x, 0, pos2.y), Color(1, 1, 0))

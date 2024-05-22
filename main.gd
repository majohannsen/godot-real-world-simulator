extends Node

const earthCircumference = 40075000
const chunk_size = 1000
const lat_span = chunk_size / 100000.0
const lon_span = chunk_size / 100000.0
const lat_center = 48.185717
const lon_center = 16.4136193
#const lat_center = 67.831433
#const lon_center = 20.277365

var center = Vector2(latToMeter(lat_center), lonToMeter(lat_center, lon_center))

var ground = preload("res://ground.tscn")

@onready var groundSpawner = $GroundSpawner

var loadedChunks: Dictionary = {}

func latLonToCoordsInMeters(lat, lon):
	return Vector2(
		latToMeter(lat),
		lonToMeter(lat, lon)
	) - center

func getChunkWidth():
	var lat1 = lat_center - lat_span/2  
	var lat2 = lat_center + lat_span/2  
	var lon1 = lon_center - lon_span/2 
	var lon2 = lon_center + lon_span/2 
	var pos1 = latLonToCoordsInMeters(lat1, lon1)
	var pos2 = latLonToCoordsInMeters(lat2, lon2)
	return pos2.x - pos1.x

func getChunkHeight():
	var lat1 = lat_center - lat_span/2  
	var lat2 = lat_center + lat_span/2  
	var lon1 = lon_center - lon_span/2 
	var lon2 = lon_center + lon_span/2 
	var pos1 = latLonToCoordsInMeters(lat1, lon1)
	var pos2 = latLonToCoordsInMeters(lat2, lon2)
	return pos2.y - pos1.y

## use Web Mercator projection

func latToMeter(lat):
	var latInRad = lat*PI/180
	return floor((1/(2*PI))*(earthCircumference/2)*((log(tan(PI/4 + latInRad/2)))))

func lonToMeter(lat, lon):
	var lonInRad = lon*PI/180
	return floor((1/(2*PI))*(earthCircumference/2)*(lonInRad))

func setPlayerPosition():
	$Player.position.x = 0
	$Player.position.y = 15
	$Player.position.z = 0

func spawnChunk(chunk: Vector2):
	$GroundSpawner.spawnGround(chunk)
	$StreetSpawner.fetchCoordinates(chunk)
	$HouseSpawner.fetchCoordinates(chunk)
	$StreetLightSpawner.fetchCoordinates(chunk)

func getCurrentChunk():
	var currentChunk = Vector2()
	var gamecoords = $Player.transform.origin
	var coords = latLonToCoordsInMeters(lat_center, lon_center) + Vector2(gamecoords.x, gamecoords.z)
	currentChunk.x = round(coords.x/getChunkWidth()) 
	currentChunk.y = round(coords.y/getChunkHeight()) 
	return currentChunk

# Called when the node enters the scene tree for the first time.
func _ready():
	setPlayerPosition()
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

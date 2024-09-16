extends Node

const chunk_size = 1000
const lat_span = chunk_size / 100000.0
const lon_span = chunk_size / 100000.0

var lat_center = 48.18574
var lon_center = 16.413616



@onready var spawner = $Spawner
@onready var pauseMenu = $PauseMenu
@onready var playerManager = $PlayerManager

@onready var calculator = $Calculator

var loadedChunks: Dictionary = {}

var center

func latLonToCoordsInMeters(lat, lon):
	return calculator.latLonToCoordsInMeters(lat, lon, center)

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

func setNewCenterPosition(lat, lon):
	lat_center = lat
	lon_center = lon
	center = Vector2(calculator.latToMeter(lat), calculator.lonToMeter(lat, lon))
	spawner.flush_all_instances()
	loadedChunks = {}
	spawnChunk(getCurrentChunk())

func spawnChunk(chunk: Vector2):
	spawner.spawn_chunk(chunk)
	

func getCurrentChunk():
	var currentChunk = Vector2()
	var gamecoords = playerManager.getPlayerPosition()
	var coords = latLonToCoordsInMeters(lat_center, lon_center) + Vector2(gamecoords.x, gamecoords.z)
	currentChunk.x = round(coords.x/getChunkWidth()) 
	currentChunk.y = round(coords.y/getChunkHeight()) 
	return currentChunk

# Called when the node enters the scene tree for the first time.
func _ready():
	pauseMenu.hide()
	center = Vector2(calculator.latToMeter(lat_center), calculator.lonToMeter(lat_center, lon_center))
	DebugDraw3D.scoped_config().set_thickness(1)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if pauseMenu.visible:
			pauseMenu.hide()
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			pauseMenu.show()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if !loadedChunks.has(getCurrentChunk()):
		loadedChunks[getCurrentChunk()] = true
		spawnChunk(getCurrentChunk())
		print("loadedChunks")
		print(center)
		print(lat_center)
		print(12)
	
	#for key in loadedChunks.keys():
		#var chunk = Vector2(key)
		#var lat1 = lat_center - lat_span/2 + lat_span * chunk.x
		#var lat2 = lat_center + lat_span/2 + lat_span * chunk.x
		#var lon1 = lon_center - lon_span/2 + lon_span * chunk.y
		#var lon2 = lon_center + lon_span/2 + lon_span * chunk.y
		#var pos1 = latLonToCoordsInMeters(lat1, lon1)
		#var pos2 = latLonToCoordsInMeters(lat2, lon2)
		#DebugDraw3D.draw_line(Vector3(pos1.x, 0, pos1.y), Vector3(pos2.x, 0, pos2.y), Color(1, 1, 0))
		#DebugDraw3D.draw_line(Vector3(pos1.x, 0, pos1.y), Vector3(pos1.x, 0, pos2.y), Color(1, 1, 0))
		#DebugDraw3D.draw_line(Vector3(pos1.x, 0, pos1.y), Vector3(pos2.x, 0, pos1.y), Color(1, 1, 0))
		#DebugDraw3D.draw_line(Vector3(pos2.x, 0, pos1.y), Vector3(pos2.x, 0, pos2.y), Color(1, 1, 0))
		#DebugDraw3D.draw_line(Vector3(pos1.x, 0, pos2.y), Vector3(pos2.x, 0, pos2.y), Color(1, 1, 0))

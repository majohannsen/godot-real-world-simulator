extends Node

const CHUNK_M = 1000.0
const CENTER_SHIFT_THRESHOLD = 5000.0

@onready var spawner = $Spawner
@onready var pauseMenu = $PauseMenu
@onready var playerManager = $PlayerManager

@onready var calculator = $Calculator

var loadedChunks: Dictionary = {}

# Floating origin in absolute Web Mercator meters (64-bit precision).
# origin_mx = northing (latToMeter axis), origin_my = easting (lonToMeter axis).
var origin_mx: float
var origin_my: float

var render_distance: int = 3

func getCurrentTile() -> Vector2i:
	var pos = playerManager.getPlayerPosition()
	return Vector2i(int(floor((origin_mx + pos.x) / CHUNK_M)), int(floor((origin_my + pos.z) / CHUNK_M)))

func setNewCenterPosition(lat, lon):
	_recenter(lat, lon)
	playerManager.setPlayerPositionOnZero()

func _recenter(new_lat: float, new_lon: float):
	var new_mx = calculator.latToMeter(new_lat)
	var new_my = calculator.lonToMeter(new_lon)
	var delta_mx = origin_mx - new_mx
	var delta_my = origin_my - new_my
	origin_mx = new_mx
	origin_my = new_my
	spawner.shift_all_roots(delta_mx, delta_my)
	playerManager.shift_player(delta_mx, delta_my)

func onChunkLoaded(tile: Vector2i):
	loadedChunks[tile] = true
	print("Spawned chunk: ", tile)

func drawDebugChunkOutline():
	for tile in loadedChunks.keys():
		var p1 = Vector3(tile.x * CHUNK_M - origin_mx, 0, tile.y * CHUNK_M - origin_my)
		var p2 = Vector3((tile.x + 1) * CHUNK_M - origin_mx, 0, (tile.y + 1) * CHUNK_M - origin_my)
		DebugDraw3D.draw_line(Vector3(p1.x, 0, p1.z), Vector3(p2.x, 0, p2.z), Color(1, 1, 0))
		DebugDraw3D.draw_line(Vector3(p1.x, 0, p1.z), Vector3(p1.x, 0, p2.z), Color(1, 1, 0))
		DebugDraw3D.draw_line(Vector3(p1.x, 0, p1.z), Vector3(p2.x, 0, p1.z), Color(1, 1, 0))
		DebugDraw3D.draw_line(Vector3(p2.x, 0, p1.z), Vector3(p2.x, 0, p2.z), Color(1, 1, 0))
		DebugDraw3D.draw_line(Vector3(p1.x, 0, p2.z), Vector3(p2.x, 0, p2.z), Color(1, 1, 0))

# Called when the node enters the scene tree for the first time.
func _ready():
	pauseMenu.hide()
	origin_mx = calculator.latToMeter(48.18574)
	origin_my = calculator.lonToMeter(16.413616)
	DebugDraw3D.scoped_config().set_thickness(1)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if pauseMenu.visible:
			pauseMenu.hide()
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			pauseMenu.show()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var pos = playerManager.getPlayerPosition()
	if abs(pos.x) > CENTER_SHIFT_THRESHOLD or abs(pos.z) > CENTER_SHIFT_THRESHOLD:
		var new_latlon = calculator.metersToLatLon(origin_mx + pos.x, origin_my + pos.z)
		_recenter(new_latlon.x, new_latlon.y)

	var player_tile = getCurrentTile()
	var desired: Array[Vector2i] = []
	for dx in range(-render_distance, render_distance + 1):
		for dy in range(-render_distance, render_distance + 1):
			desired.append(player_tile + Vector2i(dx, dy))

	for tile in desired:
		if not loadedChunks.has(tile):
			loadedChunks[tile] = false
			spawner.spawn_chunk(tile)

	var to_unload: Array[Vector2i] = []
	for tile in loadedChunks.keys():
		if not desired.has(tile):
			to_unload.append(tile)
	for tile in to_unload:
		spawner.unload_chunk(tile)
		loadedChunks.erase(tile)

	drawDebugChunkOutline()

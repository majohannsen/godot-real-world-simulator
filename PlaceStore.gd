extends Node

const STORE_PATH = "user://teleport_places.json"
const MAX_RECENTS = 20

var _favorites: Array = []
var _recents: Array = []

const SEED_FAVORITES: Array = [
	{"id": "seed_gasometer", "name": "Gasometer", "address": "", "city": "Wien", "country": "Austria", "lat": 47.42380, "lon": 9.65680, "source": "favorite", "last_used_unix": 0},
	{"id": "seed_stefansplatz", "name": "Stefansplatz", "address": "", "city": "Wien", "country": "Austria", "lat": 48.208415403250875, "lon": 16.37215091689916, "source": "favorite", "last_used_unix": 0},
	{"id": "seed_lustenau", "name": "Lustenau", "address": "", "city": "Lustenau", "country": "Austria", "lat": 47.42380, "lon": 9.65680, "source": "favorite", "last_used_unix": 0},
	{"id": "seed_karlsplatz", "name": "Karlsplatz", "address": "", "city": "Wien", "country": "Austria", "lat": 48.1999922, "lon": 16.3702657, "source": "favorite", "last_used_unix": 0},
	{"id": "seed_vienna_hbf", "name": "Vienna Hbf", "address": "", "city": "Wien", "country": "Austria", "lat": 48.1850709, "lon": 16.3763051, "source": "favorite", "last_used_unix": 0},
]

func _ready() -> void:
	load_store()

func load_store() -> void:
	if not FileAccess.file_exists(STORE_PATH):
		_favorites = []
		for seed in SEED_FAVORITES:
			_favorites.append(seed.duplicate())
		_recents = []
		save_store()
		return
	var f = FileAccess.open(STORE_PATH, FileAccess.READ)
	if not f:
		_favorites = []
		_recents = []
		return
	var text = f.get_as_text()
	f = null
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		_favorites = []
		_recents = []
		return
	_favorites = parsed.get("favorites", [])
	_recents = parsed.get("recents", [])

func save_store() -> void:
	var data = {"favorites": _favorites, "recents": _recents}
	var f = FileAccess.open(STORE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func get_favorites() -> Array:
	return _favorites.duplicate()

func get_recents() -> Array:
	return _recents.duplicate()

func is_favorite(id: String) -> bool:
	if id.is_empty():
		return false
	for p in _favorites:
		if p.get("id", "") == id:
			return true
	return false

func add_favorite(place: Dictionary) -> void:
	var id = place.get("id", "")
	if id.is_empty():
		return
	if not is_favorite(id):
		_favorites.append(place.duplicate())
		save_store()

func remove_favorite(id: String) -> void:
	if id.is_empty():
		return
	_favorites = _favorites.filter(func(p): return p.get("id", "") != id)
	save_store()

func toggle_favorite(place: Dictionary) -> bool:
	var id = place.get("id", "")
	if id.is_empty():
		return false
	if is_favorite(id):
		remove_favorite(id)
		return false
	else:
		add_favorite(place)
		return true

func add_recent(place: Dictionary) -> void:
	var id = place.get("id", "")
	if id.is_empty():
		return
	_recents = _recents.filter(func(p): return p.get("id", "") != id)
	var entry = place.duplicate()
	entry["last_used_unix"] = int(Time.get_unix_time_from_system())
	entry["source"] = "recent"
	_recents.push_front(entry)
	if _recents.size() > MAX_RECENTS:
		_recents = _recents.slice(0, MAX_RECENTS)
	save_store()

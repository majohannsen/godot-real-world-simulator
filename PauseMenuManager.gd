extends Control

@export var geoapify_api_key: String = ""

@onready var _player_manager = $"../PlayerManager"

@onready var _search_input: LineEdit = $PanelContainer/MarginContainer/HBoxContainer/LocationsVBox/SearchInput
@onready var _status_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LocationsVBox/StatusLabel
@onready var _favorites_header: Label = $PanelContainer/MarginContainer/HBoxContainer/LocationsVBox/ScrollContainer/ListsContainer/FavoritesHeader
@onready var _favorites_list: VBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/LocationsVBox/ScrollContainer/ListsContainer/FavoritesList
@onready var _recents_header: Label = $PanelContainer/MarginContainer/HBoxContainer/LocationsVBox/ScrollContainer/ListsContainer/RecentsHeader
@onready var _recents_list: VBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/LocationsVBox/ScrollContainer/ListsContainer/RecentsList
@onready var _search_header: Label = $PanelContainer/MarginContainer/HBoxContainer/LocationsVBox/ScrollContainer/ListsContainer/SearchHeader
@onready var _search_results_list: VBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/LocationsVBox/ScrollContainer/ListsContainer/SearchResultsList

@onready var _car_button: Button = $PanelContainer/MarginContainer/HBoxContainer/PlayersVbox/CarButton
@onready var _fly_button: Button = $PanelContainer/MarginContainer/HBoxContainer/PlayersVbox/FlyAroundButton
@onready var _render_slider: HSlider = $PanelContainer/MarginContainer/HBoxContainer/RenderDistanceVBox/RenderDistanceSlider
@onready var _render_label: Label = $PanelContainer/MarginContainer/HBoxContainer/RenderDistanceVBox/RenderDistanceLabel

@onready var _place_store: Node = $PlaceStore
@onready var _search_service: Node = $GeoapifySearch

const PlaceRowScene = preload("res://ui/place_row.tscn")

var _last_search_results: Array = []

func _ready() -> void:
	_search_service.geoapify_api_key = geoapify_api_key
	_search_service.search_completed.connect(_on_search_completed)
	_search_service.search_failed.connect(_on_search_failed)

	_car_button.pressed.connect(_switch_to_car)
	_fly_button.pressed.connect(_switch_to_fly)
	_render_slider.value = get_parent().render_distance
	_render_slider.value_changed.connect(_on_render_distance_changed)
	_search_input.text_changed.connect(_on_search_changed)

	_render_lists()

func _on_render_distance_changed(value: float) -> void:
	var dist = int(value)
	get_parent().render_distance = dist
	_render_label.text = "Render distance: %d chunks" % dist

func _switch_to_car() -> void:
	_player_manager.switchToCar()
	hide()

func _switch_to_fly() -> void:
	_player_manager.switchToFlyAround()
	hide()

func _on_search_changed(text: String) -> void:
	_status_label.text = ""
	var trimmed: String = text.strip_edges()
	if trimmed.length() < 2:
		_search_service.cancel()
		_last_search_results = []
		_clear_list(_search_results_list)
		_search_header.visible = false
	else:
		_search_service.search(trimmed)
	_render_favs_recents()

func _on_search_completed(results: Array) -> void:
	_status_label.text = ""
	_last_search_results = results
	_render_search_results()

func _on_search_failed(error: String) -> void:
	_status_label.text = error
	_last_search_results = []
	_clear_list(_search_results_list)
	_search_header.visible = false

func _place_matches(place: Dictionary, filter: String) -> bool:
	return place.get("name", "").to_lower().contains(filter) \
		or place.get("city", "").to_lower().contains(filter) \
		or place.get("address", "").to_lower().contains(filter) \
		or place.get("country", "").to_lower().contains(filter)

func _render_lists() -> void:
	_render_favs_recents()
	_render_search_results()

func _render_favs_recents() -> void:
	_clear_list(_favorites_list)
	_clear_list(_recents_list)
	var filter: String = _search_input.text.strip_edges().to_lower()
	var filtering: bool = filter.length() >= 2
	var favs: Array = _place_store.get_favorites()
	var recents: Array = _place_store.get_recents()
	if filtering:
		favs = favs.filter(func(p): return _place_matches(p, filter))
		recents = recents.filter(func(p): return _place_matches(p, filter))
	_favorites_header.visible = favs.size() > 0
	for place in favs:
		_add_row(_favorites_list, place)
	_recents_header.visible = recents.size() > 0
	for place in recents:
		_add_row(_recents_list, place)

func _render_search_results() -> void:
	_clear_list(_search_results_list)
	_search_header.visible = _last_search_results.size() > 0
	for place in _last_search_results:
		_add_row(_search_results_list, place)

func _add_row(container: VBoxContainer, place: Dictionary) -> void:
	var row = PlaceRowScene.instantiate()
	container.add_child(row)
	row.setup(place, _place_store.is_favorite(place.get("id", "")))
	row.teleport_requested.connect(_on_teleport_requested)
	row.favorite_toggled.connect(_on_favorite_toggled)

func _clear_list(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()

func _on_teleport_requested(place: Dictionary) -> void:
	_player_manager.setPlayerPositionOnZero()
	get_parent().setNewCenterPosition(place.get("lat", 0.0), place.get("lon", 0.0))
	if not place.get("id", "").is_empty():
		_place_store.add_recent(place)
	_search_service.cancel()
	_search_input.text = ""
	_last_search_results = []
	_status_label.text = ""
	_render_lists()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	hide()

func _on_favorite_toggled(place: Dictionary) -> void:
	_place_store.toggle_favorite(place)
	_render_lists()

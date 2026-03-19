extends HBoxContainer

signal teleport_requested(place: Dictionary)
signal favorite_toggled(place: Dictionary)

var place: Dictionary = {}
var _is_favorite: bool = false

@onready var _name_label: Label = $InfoVBox/NameLabel
@onready var _addr_label: Label = $InfoVBox/AddrLabel
@onready var _teleport_btn: Button = $TeleportButton
@onready var _fav_btn: Button = $FavButton

func setup(p: Dictionary, is_fav: bool) -> void:
	place = p
	_is_favorite = is_fav
	_name_label.text = p.get("name", "Unknown")
	var city: String = p.get("city", "")
	var country: String = p.get("country", "")
	var address: String = p.get("address", "")
	var addr_parts: Array = []
	if not address.is_empty():
		addr_parts.append(address)
	var location_str: String = ""
	if not city.is_empty() and not country.is_empty():
		location_str = "%s, %s" % [city, country]
	elif not city.is_empty():
		location_str = city
	elif not country.is_empty():
		location_str = country
	if not location_str.is_empty():
		addr_parts.append(location_str)
	_addr_label.text = ", ".join(addr_parts)
	_addr_label.visible = not _addr_label.text.is_empty()
	_update_fav_button()

func set_favorite_state(is_fav: bool) -> void:
	_is_favorite = is_fav
	_update_fav_button()

func _update_fav_button() -> void:
	_fav_btn.text = "★" if _is_favorite else "☆"

func _ready() -> void:
	_teleport_btn.pressed.connect(func(): teleport_requested.emit(place))
	_fav_btn.pressed.connect(func(): favorite_toggled.emit(place))

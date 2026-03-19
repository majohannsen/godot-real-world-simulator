extends Node

signal search_completed(results: Array)
signal search_failed(error: String)

@export var geoapify_api_key: String = ""

const BASE_URL = "https://api.geoapify.com/v1/geocode/autocomplete"
const MAX_RESULTS = 10
const DEBOUNCE_SECONDS = 0.3

var _debounce_timer: Timer = null
var _http_request: HTTPRequest = null
var _pending_query: String = ""
var _active_query: String = ""
var _query_cache: Dictionary = {}

func _ready() -> void:
	_debounce_timer = Timer.new()
	_debounce_timer.one_shot = true
	_debounce_timer.wait_time = DEBOUNCE_SECONDS
	_debounce_timer.timeout.connect(_on_debounce_timeout)
	add_child(_debounce_timer)

func search(query: String) -> void:
	_pending_query = query.strip_edges()
	_debounce_timer.stop()
	if _pending_query.length() < 2:
		return
	_debounce_timer.start()

func cancel() -> void:
	_debounce_timer.stop()
	_cancel_request()

func _on_debounce_timeout() -> void:
	var query = _pending_query
	if query.length() < 2:
		return
	if _query_cache.has(query):
		search_completed.emit(_query_cache[query])
		return
	_do_search(query)

func _do_search(query: String) -> void:
	if geoapify_api_key.is_empty():
		search_failed.emit("API key not set. Add it to the PauseMenu node in the Inspector.")
		return
	_cancel_request()
	_active_query = query
	var url = "%s?text=%s&limit=%d&apiKey=%s" % [
		BASE_URL, query.uri_encode(), MAX_RESULTS, geoapify_api_key.uri_encode()
	]
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed.bind(query))
	var err = _http_request.request(url)
	if err != OK:
		search_failed.emit("HTTP request failed.")
		_cleanup_request()

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, query: String) -> void:
	if query != _active_query:
		_cleanup_request()
		return
	_cleanup_request()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		if response_code == 429:
			search_failed.emit("Rate limit reached. Please wait and try again.")
		else:
			search_failed.emit("Search failed (HTTP %d)." % response_code)
		return
	var text = body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		search_failed.emit("Invalid response from search service.")
		return
	var features = parsed.get("features", [])
	var results: Array = []
	for feat in features:
		var props = feat.get("properties", {})
		results.append(_normalize(props))
	_query_cache[query] = results
	search_completed.emit(results)

func _normalize(props: Dictionary) -> Dictionary:
	var name_val: String = props.get("name", props.get("street", props.get("address_line1", "")))
	var address: String = props.get("address_line2", props.get("formatted", ""))
	var city: String = props.get("city", props.get("town", props.get("village", "")))
	var country: String = props.get("country", "")
	var lat: float = float(props.get("lat", 0.0))
	var lon: float = float(props.get("lon", 0.0))
	return {
		"id": props.get("place_id", ""),
		"name": name_val,
		"address": address,
		"city": city,
		"country": country,
		"lat": lat,
		"lon": lon,
		"source": "search",
		"last_used_unix": 0,
	}

func _cancel_request() -> void:
	if _http_request and is_instance_valid(_http_request):
		_http_request.cancel_request()
		_http_request.queue_free()
		_http_request = null
	_active_query = ""

func _cleanup_request() -> void:
	if _http_request and is_instance_valid(_http_request):
		_http_request.queue_free()
		_http_request = null

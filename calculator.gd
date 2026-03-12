extends Node

# WGS84 equatorial radius — the standard used by Web Mercator (EPSG:3857)
const EARTH_RADIUS = 6378137.0
const CHUNK_M = 1000.0

func latToMeter(lat):
	var latInRad = lat * PI / 180.0
	return EARTH_RADIUS * log(tan(PI / 4.0 + latInRad / 2.0))

func lonToMeter(lon):
	return EARTH_RADIUS * lon * PI / 180.0

func latLonToTile(lat, lon) -> Vector2i:
	return Vector2i(int(floor(latToMeter(lat) / CHUNK_M)), int(floor(lonToMeter(lon) / CHUNK_M)))

func metersToLatLon(mx: float, my: float) -> Vector2:
	var lat = (2.0 * atan(exp(mx / EARTH_RADIUS)) - PI / 2.0) * 180.0 / PI
	var lon = (my / EARTH_RADIUS) * 180.0 / PI
	return Vector2(lat, lon)

func meterPlusCenterToCoords(lat, lon, center: Vector2, position: Vector2):
	var new_latitude = lat + ((center.y - position.y) / EARTH_RADIUS) * (180.0 / PI)
	var new_longitude = lon + ((center.x - position.x) / EARTH_RADIUS) * (180.0 / PI) / cos(new_latitude * PI / 180.0)
	return Vector2(new_latitude, new_longitude)

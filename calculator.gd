extends Node

# WGS84 equatorial radius — the standard used by Web Mercator (EPSG:3857)
const EARTH_RADIUS = 6378137.0
const chunk_size = 1000
const lat_span = chunk_size / 100000.0
const lon_span = chunk_size / 100000.0

func latToMeter(lat):
	var latInRad = lat * PI / 180.0
	return EARTH_RADIUS * log(tan(PI / 4.0 + latInRad / 2.0))

func lonToMeter(_lat, lon):
	return EARTH_RADIUS * lon * PI / 180.0

# center_x and center_y are 64-bit floats — subtraction is done before packing
# into Vector2 to avoid the ~1 m precision loss of 32-bit Vector2 at absolute
# Web Mercator magnitudes (~6 million m).
func latLonToCoordsInMeters(lat, lon, center_x: float, center_y: float):
	var rel_x: float = latToMeter(lat) - center_x
	var rel_y: float = lonToMeter(lat, lon) - center_y
	return Vector2(rel_x, rel_y)

func meterPlusCenterToCoords(lat, lon, center: Vector2, position: Vector2):
	var new_latitude = lat + ((center.y - position.y) / EARTH_RADIUS) * (180.0 / PI)
	var new_longitude = lon + ((center.x - position.x) / EARTH_RADIUS) * (180.0 / PI) / cos(new_latitude * PI / 180.0)
	return Vector2(new_latitude, new_longitude)

extends Node

const earthCircumference = 40075000
const chunk_size = 1000
const lat_span = chunk_size / 100000.0
const lon_span = chunk_size / 100000.0

func latToMeter(lat):
	var latInRad = lat*PI/180
	return floor((1/(2*PI))*(earthCircumference/2)*((log(tan(PI/4 + latInRad/2)))))

func lonToMeter(lat, lon):
	var lonInRad = lon*PI/180
	return floor((1/(2*PI))*(earthCircumference/2)*(lonInRad))

func latLonToCoordsInMeters(lat, lon, center):
	return Vector2(
		latToMeter(lat),
		lonToMeter(lat, lon)
	) - center

func meterPlusCenterToCoords(lat, lon, center: Vector2, position: Vector2):
	var new_latitude  = lat  + ((center.y - position.y) / earthCircumference) * (180 / PI);
	var new_longitude = lon + ((center.x - position.x) / earthCircumference) * (180 / PI) / cos(new_latitude * PI/180);
	return Vector2(new_latitude, new_longitude)

extends Node

var street_shape = preload("res://objects/street/street_shape.tscn")

@onready var main = get_parent().get_parent()



func handleData(data: Array):
	var streets: Array = []
	for street in data:
		var points: Array[Vector2] = []
		for point in street["geometry"]:
			var lat = point["lat"]
			var lon = point["lon"]
			points.append(main.latLonToCoordsInMeters(lat, lon))
		streets.append(points)
	for street in streets:
		await get_tree().create_timer(0).timeout
		await spawnStreet(street)

func spawnStreet(street: Array[Vector2]):
	var path = Path3D.new()
	path.curve = Curve3D.new()
	for point in street:
		path.curve.add_point(Vector3(point.x,0.1,point.y))
	path.add_child(street_shape.instantiate())
	add_child(path)

func flush_all_instances():
	for child in get_children():
		child.queue_free()

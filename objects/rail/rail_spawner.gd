extends Node

var rail_shape = preload("res://objects/rail/rail_shape.tscn")

@onready var main = get_parent().get_parent()


func handleData(data: Array):
	var rails: Array = []
	for rail in data:
		var points: Array[Vector2] = []
		for point in rail["geometry"]:
			var lat = point["lat"]
			var lon = point["lon"]
			points.append(main.latLonToCoordsInMeters(lat, lon))
		rails.append(points)
	for rail in rails:
		await get_tree().create_timer(0).timeout
		spawnRail(rail)

func spawnRail(rail: Array[Vector2]):
	var path = Path3D.new()
	path.curve = Curve3D.new()
	for point in rail:
		path.curve.add_point(Vector3(point.x, 0.05, point.y))
	path.add_child(rail_shape.instantiate())
	add_child(path)

func flush_all_instances():
	for child in get_children():
		child.queue_free()

extends Node

const BATCH_SIZE = 10
var rail_shape = preload("res://objects/rail/rail_shape.tscn")

@onready var main = get_parent().get_parent()


func handleData(data: Array, container: Node3D):
	var rails: Array = []
	for rail in data:
		var points: Array[Vector2] = []
		for point in rail["geometry"]:
			points.append(main.latLonToCoordsInMeters(point["lat"], point["lon"]))
		rails.append(points)
	for i in rails.size():
		if i % BATCH_SIZE == 0:
			await get_tree().process_frame
			if not is_instance_valid(container):
				return
		var path = Path3D.new()
		path.curve = Curve3D.new()
		for point in rails[i]:
			path.curve.add_point(Vector3(point.x, 0.05, point.y))
		path.add_child(rail_shape.instantiate())
		container.add_child(path)

func flush_all_instances():
	pass

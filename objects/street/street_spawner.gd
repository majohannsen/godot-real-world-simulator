extends Node

const BATCH_SIZE = 10
var street_shape = preload("res://objects/street/street_shape.tscn")

@onready var main = get_parent().get_parent()

func handleData(data: Array, container: Node3D, tile_center_mx: float, tile_center_my: float):
	var streets: Array = []
	for street in data:
		var points: Array[Vector2] = []
		for point in street["geometry"]:
			points.append(Vector2(
				main.calculator.latToMeter(point["lat"]) - tile_center_mx,
				main.calculator.lonToMeter(point["lon"]) - tile_center_my
			))
		streets.append(points)
	for i in streets.size():
		if i % BATCH_SIZE == 0:
			await get_tree().process_frame
			if not is_instance_valid(container):
				return
		var path = Path3D.new()
		path.curve = Curve3D.new()
		for point in streets[i]:
			path.curve.add_point(Vector3(point.x, 0.1, point.y))
		path.add_child(street_shape.instantiate())
		container.add_child(path)

func flush_all_instances():
	pass

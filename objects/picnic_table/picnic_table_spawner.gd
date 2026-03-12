extends Node

const BATCH_SIZE = 25
var object = preload("res://objects/picnic_table/picnic_table.tscn")

@onready var main = get_parent().get_parent()

func handleData(data: Array, container: Node3D, tile_center_mx: float, tile_center_my: float):
	var positions: Array[Vector2] = []
	for element in data:
		positions.append(Vector2(
			main.calculator.latToMeter(element["lat"]) - tile_center_mx,
			main.calculator.lonToMeter(element["lon"]) - tile_center_my
		))
	for i in positions.size():
		if i % BATCH_SIZE == 0:
			await get_tree().process_frame
			if not is_instance_valid(container):
				return
		var inst = object.instantiate()
		inst.transform.origin = Vector3(positions[i].x, 0, positions[i].y)
		container.add_child(inst)

func flush_all_instances():
	pass

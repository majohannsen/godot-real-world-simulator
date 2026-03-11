extends Node

var tree = preload("res://objects/tree/tree.tscn")

@onready var main = get_parent().get_parent()

var elements: Array[Vector2] = []

func handleData(data: Array):
	elements = []
	for element in data:
		var lat = element["lat"]
		var lon = element["lon"]
		elements.append(main.latLonToCoordsInMeters(lat, lon))
	for element in elements:
		await get_tree().create_timer(0).timeout
		await spawnTree(element)

func spawnTree(coords: Vector2):
	var inst = tree.instantiate()
	inst.transform.origin = Vector3(coords.x,0,coords.y)
	add_child(inst)

func flush_all_instances():
	for child in get_children():
		child.queue_free()
	elements = []

extends Node

var ground = preload("res://objects/ground/ground.tscn")

@onready var main = get_parent().get_parent()

func spawnGround(chunk: Vector2, container: Node3D):
	var lat = main.lat_center + main.lat_span * chunk.x
	var lon = main.lon_center + main.lon_span * chunk.y
	var coords = main.latLonToCoordsInMeters(lat, lon)
	var inst: StaticBody3D = ground.instantiate()
	inst.transform.origin = Vector3(coords.x, 0, coords.y)
	container.add_child(inst)

func flush_all_instances():
	pass

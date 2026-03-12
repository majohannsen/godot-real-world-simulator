extends Node

var ground = preload("res://objects/ground/ground.tscn")

func spawnGround(_tile: Vector2i, container: Node3D, _tile_center_mx: float, _tile_center_my: float):
	var inst: StaticBody3D = ground.instantiate()
	inst.transform.origin = Vector3(0, 0, 0)
	container.add_child(inst)

func flush_all_instances():
	pass

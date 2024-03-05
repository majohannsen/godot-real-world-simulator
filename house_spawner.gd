extends Node

var house = preload("res://house.tscn")

func spawnHouse():
	var inst = house.instantiate()
	add_child(inst)

# Called when the node enters the scene tree for the first time.
func _ready():
	spawnHouse()

#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

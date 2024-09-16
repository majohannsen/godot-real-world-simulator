extends Node

@onready var player = $Player
@onready var main = get_parent()

var car = preload("res://cars/Models/offroad_car/offroad_car.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player.position.x = 0
	player.position.y = 50
	player.position.z = 0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func getPlayerPosition():
	return player.transform.origin


func switchToCar():
	var inst = car.instantiate()
	inst.transform.origin = Vector3(0,10,0)
	add_child(inst)

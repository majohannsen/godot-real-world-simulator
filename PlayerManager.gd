extends Node

@onready var player = $Player
@onready var main = get_parent()

var carPrefab = preload("res://cars/Models/offroad_car/offroad_car.tscn")

var car

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player.position.x = 0
	player.position.y = 50
	player.position.z = 0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func getPlayerPosition():
	if car:
		return car.transform.origin
	else:
		return player.transform.origin

func switchToCar():
	car = carPrefab.instantiate()
	car.transform.origin = Vector3(0,10,0)
	add_child(car)

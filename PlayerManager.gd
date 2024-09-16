extends Node

@onready var main = get_parent()

var carPrefab = preload("res://cars/Models/offroad_car/offroad_car.tscn")
var playerPrefab = preload("res://assets/simple_fpsplayer/Player.tscn")

var car
var player

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	switchToFlyAround()


func setPlayerPositionOnZero():
	if is_instance_valid(player):
		player.position = Vector3(0, 50, 0)
	if is_instance_valid(car):
		car.position = Vector3(0, 10, 0)

func getPlayerPosition():
	if is_instance_valid(car):
		return car.transform.origin
	else:
		return player.transform.origin

func switchToCar():
	if (!is_instance_valid(car)):
		car = carPrefab.instantiate()
		car.transform.origin = Vector3(0,10,0)
		add_child(car)
	if is_instance_valid(player):
		player.queue_free()


func switchToFlyAround():
	if (!is_instance_valid(player)):
		player = playerPrefab.instantiate()
		player.transform.origin = Vector3(0,50,0)
		add_child(player)
	if is_instance_valid(car):
		car.queue_free()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

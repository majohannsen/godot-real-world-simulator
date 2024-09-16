extends Control

@onready var playerManager = $"../PlayerManager"

@onready var carButton = $PanelContainer/MarginContainer/HBoxContainer/PlayersVbox/CarButton
@onready var flyAroundButton = $PanelContainer/MarginContainer/HBoxContainer/PlayersVbox/FlyAroundButton

@onready var gasometerButton = $PanelContainer/MarginContainer/HBoxContainer/LocationsVBox/Gasometer
@onready var lustenauButton = $PanelContainer/MarginContainer/HBoxContainer/LocationsVBox/Lustenau

const lustenau_lat = 47.42380
const lustenau_lon = 9.65680

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	carButton.pressed.connect(self.switchToCar)
	flyAroundButton.pressed.connect(self.switchToFlyAround)
	gasometerButton.pressed.connect(self.centerOnGasometer)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func switchToCar():
	playerManager.switchToCar()
	hide()


func switchToFlyAround():
	playerManager.switchToFlyAround()
	hide()
	
func centerOnGasometer():
	playerManager.setPlayerPositionOnZero()
	get_parent().setNewCenterPosition(lustenau_lat, lustenau_lon)
	
	hide()

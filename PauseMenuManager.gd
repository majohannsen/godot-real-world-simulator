extends Control

@onready var playerManager = $"../PlayerManager"

@onready var carButton = $PanelContainer/MarginContainer/HBoxContainer/PlayersVbox/CarButton
@onready var flyAroundButton = $PanelContainer/MarginContainer/HBoxContainer/PlayersVbox/FlyAroundButton

@onready var gasometerButton = $PanelContainer/MarginContainer/HBoxContainer/LocationsVBox/Gasometer
@onready var stefansplatzButton = $PanelContainer/MarginContainer/HBoxContainer/LocationsVBox/Stefansplatz
@onready var lustenauButton = $PanelContainer/MarginContainer/HBoxContainer/LocationsVBox/Lustenau
@onready var karlsplatzButton = $PanelContainer/MarginContainer/HBoxContainer/LocationsVBox/Karlsplatz
@onready var viennaHbfButton = $PanelContainer/MarginContainer/HBoxContainer/LocationsVBox/ViennaHbf

const gasometer_lat = 47.42380
const gasometer_lon = 9.65680

const stefansplatz_lat = 48.208415403250875
const stefansplatz_lon = 16.37215091689916

const lustenau_lat = 47.42380
const lustenau_lon = 9.65680

const karlsplatz_lat = 48.1999922
const karlsplatz_lon = 16.3702657

const viennaHbf_lat = 48.1850709
const viennaHbf_lon = 16.3763051

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	carButton.pressed.connect(self.switchToCar)
	flyAroundButton.pressed.connect(self.switchToFlyAround)
	gasometerButton.pressed.connect(self.centerOnGasometer)
	stefansplatzButton.pressed.connect(self.centerOnStefansplatz)
	lustenauButton.pressed.connect(self.centerOnLustenau)
	karlsplatzButton.pressed.connect(self.centerOnKarlsplatz)
	viennaHbfButton.pressed.connect(self.centerOnViennaHbf)

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
	get_parent().setNewCenterPosition(gasometer_lat, gasometer_lon)
	hide()
	
func centerOnStefansplatz():
	playerManager.setPlayerPositionOnZero()
	get_parent().setNewCenterPosition(stefansplatz_lat, stefansplatz_lon)
	hide()

func centerOnLustenau():
	playerManager.setPlayerPositionOnZero()
	get_parent().setNewCenterPosition(lustenau_lat, lustenau_lon)
	hide()

func centerOnKarlsplatz():
	playerManager.setPlayerPositionOnZero()
	get_parent().setNewCenterPosition(karlsplatz_lat, karlsplatz_lon)
	hide()

func centerOnViennaHbf():
	playerManager.setPlayerPositionOnZero()
	get_parent().setNewCenterPosition(viennaHbf_lat, viennaHbf_lon)
	hide()

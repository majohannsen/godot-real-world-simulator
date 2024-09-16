extends Control

@onready var playerManager = $"../PlayerManager"

@onready var carButton = $PanelContainer/MarginContainer/HBoxContainer/CarButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	carButton.pressed.connect(self.switchToCar)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func switchToCar():
	playerManager.switchToCar()
	hide()

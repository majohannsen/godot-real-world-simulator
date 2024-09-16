extends VehicleBody3D
var ghostPositions = null
var index = 0

func _ready() -> void:
	if ResourceLoader.exists("CanyonRunGhostSave.tres"):
		var ghostResource = ResourceLoader.load("CanyonRunGhostSave.tres")
		ghostPositions = ghostResource.ghostPositions
	else:
		queue_free()

func _physics_process(delta):
	if ghostPositions == null:
		return
	global_position = ghostPositions[index].position
	global_rotation = ghostPositions[index].rotation
	index += 1
	if index >= ghostPositions.size():
		queue_free()

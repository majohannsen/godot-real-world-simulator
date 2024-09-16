extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func spawn_chunk(chunk):
	$GroundSpawner.spawnGround(chunk)
	$StreetSpawner.fetchCoordinates(chunk)
	$HouseSpawner.fetchCoordinates(chunk)
	$StreetLightSpawner.fetchCoordinates(chunk)
	$TreeSpawner.fetchCoordinates(chunk)
	$TrashBasketSpawner.fetchCoordinates(chunk)
	$HydrantSpawner.fetchCoordinates(chunk)
	$PicnicTableSpawner.fetchCoordinates(chunk)

extends Node3D

@onready var streetLightSpawner = $StreetLightSpawner
@onready var treeSpawner = $TreeSpawner
@onready var picnicTableSpawner = $PicnicTableSpawner
@onready var groundSpawner = $GroundSpawner
@onready var streetSpawner = $StreetSpawner
@onready var houseSpawner = $HouseSpawner
@onready var trashBasketSpawner = $TrashBasketSpawner
@onready var hydrantSpawner = $HydrantSpawner

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func flush_all_instances():
	streetLightSpawner.flush_all_instances()
	groundSpawner.flush_all_instances()
	streetSpawner.flush_all_instances()
	houseSpawner.flush_all_instances()
	treeSpawner.flush_all_instances()
	trashBasketSpawner.flush_all_instances()
	hydrantSpawner.flush_all_instances()
	picnicTableSpawner.flush_all_instances()

func spawn_chunk(chunk):
	groundSpawner.spawnGround(chunk)
	streetSpawner.fetchCoordinates(chunk)
	houseSpawner.fetchCoordinates(chunk)
	streetLightSpawner.fetchCoordinates(chunk)
	treeSpawner.fetchCoordinates(chunk)
	trashBasketSpawner.fetchCoordinates(chunk)
	hydrantSpawner.fetchCoordinates(chunk)
	picnicTableSpawner.fetchCoordinates(chunk)

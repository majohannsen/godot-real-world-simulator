extends Node

const DEFAULT_HEIGHT = 12
var house = preload("res://objects/house/house.tscn")

@onready var main = get_parent().get_parent()


func handleData(data: Array):
	var houses: Array = []
	var heights: Array = []
	for building in data:
		var corners = building["geometry"]
		var cornersInMeters = []
		for corner in corners:
			var lat = corner["lat"]
			var lon = corner["lon"]
			cornersInMeters.append(main.latLonToCoordsInMeters(lat, lon))
		houses.append(cornersInMeters)
		var height = DEFAULT_HEIGHT
		if building.has("tags"):
			if building["tags"].has("height"):
				var h = building["tags"]["height"]
				if h:
					height = float(h)
			elif building["tags"].has("building:levels"):
				var h = building["tags"]["building:levels"]
				if h:
					height = int(h) * 3
		heights.append(height)
	for i in houses.size():
		await get_tree().create_timer(0).timeout
		await spawnHouse(houses[i], heights[i])

func spawnHouse(corners, height):
	var mesh: CSGPolygon3D = CSGPolygon3D.new()
	var collider: CollisionPolygon3D = CollisionPolygon3D.new()
	mesh.mode = CSGPolygon3D.MODE_DEPTH
	mesh.depth = height;
	collider.depth = height
	mesh.rotate_x(PI / 2);
	collider.rotate_x(PI / 2);
	mesh.polygon = corners
	collider.polygon = corners
	var pos = collider.transform.origin
	pos.y = height / 2;
	collider.transform.origin = pos
	var inst: StaticBody3D = StaticBody3D.new()
	inst.add_child(mesh)
	inst.add_child(collider)
	add_child(inst)

func flush_all_instances():
	for child in get_children():
		child.queue_free()

extends Node

const DEFAULT_HEIGHT = 12
var house = preload("res://objects/house/house.tscn")

@onready var main = get_parent().get_parent()


func handleData(data: Array, container: Node3D):
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
	print("Loaded ", houses.size(), " houses")
	for i in houses.size():
		if i % 5 == 0:
			await get_tree().process_frame
			if not is_instance_valid(container):
				return
		var mesh: CSGPolygon3D = CSGPolygon3D.new()
		var collider: CollisionPolygon3D = CollisionPolygon3D.new()
		mesh.mode = CSGPolygon3D.MODE_DEPTH
		mesh.depth = heights[i]
		collider.depth = heights[i]
		mesh.rotate_x(PI / 2)
		collider.rotate_x(PI / 2)
		mesh.polygon = houses[i]
		collider.polygon = houses[i]
		var cpos = collider.transform.origin
		cpos.y = heights[i] / 2.0
		collider.transform.origin = cpos
		var inst: StaticBody3D = StaticBody3D.new()
		inst.add_child(mesh)
		inst.add_child(collider)
		container.add_child(inst)
	print("Spawned ", houses.size(), " houses")

func flush_all_instances():
	pass

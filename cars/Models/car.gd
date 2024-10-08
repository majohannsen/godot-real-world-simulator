extends VehicleBody3D

@onready var skidMark = preload("res://SkidMark.tscn")

@export var STEER_SPEED = 1.5
@export var STEER_LIMIT = 0.6
var steer_target = 0
@export var engine_force_value = 40
var race_ongoing = false
var ghostSave

signal speed_changed(speed)

func _physics_process(delta):
	var speed = linear_velocity.length()*Engine.get_frames_per_second()*delta
	traction(speed)
	emit_signal("speed_changed", round(speed*3.8))
	
	var fwd_mps = transform.basis.x.x
	steer_target = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	steer_target *= STEER_LIMIT
	
	if Input.is_action_pressed("ui_down"):
	# Increase engine force at low speeds to make the initial acceleration faster.

		if speed < 20 and speed != 0:
			engine_force = clamp(engine_force_value * 3 / speed, 0, 300)
		else:
			engine_force = engine_force_value
	else:
		engine_force = 0
	if Input.is_action_pressed("ui_up"):
		# Increase engine force at low speeds to make the initial acceleration faster.
		if fwd_mps >= -1:
			if speed < 30 and speed != 0:
				engine_force = -clamp(engine_force_value * 10 / speed, 0, 300)
			else:
				engine_force = -engine_force_value
		else:
			brake = 1.0
	else:
		brake = 0.0
	
	if Input.is_action_pressed("ui_select"):
		skidMarks()
		brake=3
		$wheal2.wheel_friction_slip=0.8
		$wheal3.wheel_friction_slip=0.8
	else:
		$wheal2.wheel_friction_slip=3
		$wheal3.wheel_friction_slip=3
	
	steering = move_toward(steering, steer_target, STEER_SPEED * delta)


func traction(speed):
	apply_central_force(Vector3.DOWN*speed * 2)

func skidMarks():
	var b = skidMark.instantiate()
	get_parent().add_child(b)
	b.global_transform.origin = Vector3(global_transform.origin.x, global_transform.origin.y + 0.05, global_transform.origin.z)
	var r = get_rotation()
	b.set_rotation(r)

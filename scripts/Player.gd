extends KinematicBody
#Variables
var global = "root/global"

const GRAVITY = -32.8
var vel = Vector3()
const MAX_SPEED = 10
const JUMP_SPEED = 12

var dir = Vector3()

const ACCEL = 25
const DEACCEL= 40
const MAX_SLOPE_ANGLE = 40

var camera
var rotation_helper

var MOUSE_SENSITIVITY = 0.11

const MAX_SPRINT_SPEED = 20
const SPRINT_ACCEL = 18
var is_sprinting = false

export var no_clip = false

func _ready():
	camera = $rotation_helper/Camera
	rotation_helper = $rotation_helper

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	no_clip()

func _physics_process(delta):
	process_input(delta)
	process_movement(delta)

func no_clip() -> void:
	$collision_body.disabled = no_clip

	if no_clip:
		vel.y = 0

func process_input(delta):
	# Walking
	dir = Vector3()
	var cam_xform = camera.get_global_transform()

	var input_movement_vector = Vector2()

	if Input.is_key_pressed(KEY_Q):
		no_clip = not no_clip
		no_clip()

	var speed = 5
	if Input.is_action_pressed("movement_forward"):
		input_movement_vector.y += 1 * speed
	if Input.is_action_pressed("movement_backward"):
		input_movement_vector.y -= 1 * speed
	if Input.is_action_pressed("movement_left"):
		input_movement_vector.x -= 1 * speed
	if Input.is_action_pressed("movement_right"):
		input_movement_vector.x += 1 * speed

	input_movement_vector = input_movement_vector.normalized()

	dir += -cam_xform.basis.z.normalized() * input_movement_vector.y
	dir += cam_xform.basis.x.normalized() * input_movement_vector.x
	# ----------------------------------

	# Jumping
	if is_on_floor():
		if Input.is_action_just_pressed("movement_jump"):
			vel.y = JUMP_SPEED
	# ----------------------------------

	# Capturing/Freeing the cursor
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func process_movement(delta):
	dir.y = 0
	dir = dir.normalized()

	if not no_clip:
		vel.y += delta * GRAVITY

	var hvel = vel
	hvel.y = 0

	var target = dir
	target *= MAX_SPEED

	var accel
	if dir.dot(hvel) > 0:
		accel = ACCEL
	else:
		accel = DEACCEL

	var speed_multiplier = 1.4

	hvel = hvel.linear_interpolate(target, accel * delta)
	vel.x = hvel.x * speed_multiplier
	vel.z = hvel.z * speed_multiplier
	vel = move_and_slide(vel, Vector3(0, 1, 0), 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_helper.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY))
		self.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))

		var camera_rot = rotation_helper.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -70, 70)
		rotation_helper.rotation_degrees = camera_rot

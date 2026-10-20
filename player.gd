extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var start_position: Vector3

func _ready():
	platform_wall_layers = 1
	start_position = global_position

func _physics_process(delta):
	if global_position.y < -10.0:
		global_position = start_position
		velocity = Vector3.ZERO
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("ui_accept"):
		velocity.y = JUMP_VELOCITY

	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var dir := Vector3(input.x, 0, input.y)

	if dir != Vector3.ZERO:
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		var target := atan2(dir.x, dir.z)
		$Model.rotation.y = lerp_angle($Model.rotation.y, target, 0.2)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
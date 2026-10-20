extends AnimatableBody3D

@export var speed := 2.0
@export var wall_width := 20.0
@export var wall_height := 4.0
@export var thickness := 0.5
@export var hole_width := 1.6
@export var hole_height := 2.4
@export var hole_x := 0.0
@export var start_z := -9.0
@export var end_z := 11.0

func _ready():
	position = Vector3(0, 0, start_z)
	var half := wall_width / 2.0
	var hole_left := hole_x - hole_width / 2.0
	var hole_right := hole_x + hole_width / 2.0
	var lw := hole_left + half
	_add_box(Vector3((-half + hole_left) / 2.0, wall_height / 2.0, 0), Vector3(lw, wall_height, thickness))
	var rw := half - hole_right
	_add_box(Vector3((half + hole_right) / 2.0, wall_height / 2.0, 0), Vector3(rw, wall_height, thickness))
	var th := wall_height - hole_height
	_add_box(Vector3(0, hole_height + th / 2.0, 0), Vector3(wall_width, th, thickness))

func _add_box(center: Vector3, size: Vector3):
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = center
	add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = center
	add_child(col)

func _physics_process(delta):
	position.z += speed * delta
	if position.z > end_z:
		position.z = start_z

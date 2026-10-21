extends Camera3D

@export var target: Node3D
@export var look_offset := Vector3(0, 1, 0)  # aim at the chest, not the feet
@export var smoothing := 8.0

func _process(delta):
	if target == null:
		return
	var from := global_transform
	var to := from.looking_at(target.global_position + look_offset, Vector3.UP)
	global_transform = from.interpolate_with(to, clampf(smoothing * delta, 0.0, 1.0))

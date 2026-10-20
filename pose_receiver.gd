extends Node

var udp := PacketPeerUDP.new()
var pose := {}
var skel: Skeleton3D
var smooth_dirs := {}
@export var body_scale := 1.0
@export var padding := Vector2(0.25, 0.2)
@export var depth := 0.5
@export var show_debug := true

var col: CollisionShape3D
var box := BoxShape3D.new()
var dbg_box := BoxMesh.new()
var cur_size := Vector2(0.65, 1.8)
var cur_x := 0.0

# [bone, child bone, from landmark, to landmark]
const LIMBS = [
	["LeftArm", "LeftForeArm", "l_shoulder", "l_elbow"],
	["LeftForeArm", "LeftHand", "l_elbow", "l_wrist"],
	["RightArm", "RightForeArm", "r_shoulder", "r_elbow"],
	["RightForeArm", "RightHand", "r_elbow", "r_wrist"],
	["LeftUpLeg", "LeftLeg", "l_hip", "l_knee"],
	["LeftLeg", "LeftFoot", "l_knee", "l_ankle"],
	["RightUpLeg", "RightLeg", "r_hip", "r_knee"],
	["RightLeg", "RightFoot", "r_knee", "r_ankle"],
]

func _ready():
	udp.bind(4242, "127.0.0.1")
	skel = get_node("../Model").find_child("Skeleton3D", true, false)
	if skel == null:
		push_error("No Skeleton3D found under Model")

	col = get_parent().get_node("CollisionShape3D")
	col.shape = box
	if show_debug:
		var dbg := MeshInstance3D.new()
		dbg.mesh = dbg_box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.2, 0.2, 0.3)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dbg.material_override = mat
		col.add_child(dbg)

func _bone(short_name: String) -> int:
	for prefix in ["mixamorig_", "mixamorig:", "mixamorig"]:
		var i := skel.find_bone(prefix + short_name)
		if i != -1:
			return i
	return -1

func _lm(lm_name: String) -> Vector3:
	var a = pose[lm_name]
	return Vector3(a[0], a[1], a[2])

func _process(_delta):
	while udp.get_available_packet_count() > 0:
		var data = JSON.parse_string(udp.get_packet().get_string_from_utf8())
		if data is Dictionary:
			pose = data
	if skel == null or pose.is_empty():
		return
	_update_hitbox()
	for limb in LIMBS:
		_aim(limb[0], limb[1], limb[2], limb[3])

func _aim(bone_name: String, child_name: String, from_lm: String, to_lm: String):
	var b := _bone(bone_name)
	var c := _bone(child_name)
	if b == -1 or c == -1:
		push_error("Bone not found: " + bone_name)
		return
	var dir_player := (_lm(to_lm) - _lm(from_lm)).normalized()
	var dir_world: Vector3 = get_parent().global_basis * dir_player
	var target: Vector3 = (skel.global_basis.orthonormalized().inverse() * dir_world).normalized()
	var prev: Vector3 = smooth_dirs.get(bone_name, target)
	target = prev.lerp(target, 0.3).normalized()
	smooth_dirs[bone_name] = target
	var rest_b := skel.get_bone_global_rest(b)
	var rest_c := skel.get_bone_global_rest(c)
	var rest_dir := (rest_c.origin - rest_b.origin).normalized()
	var new_basis := Basis(Quaternion(rest_dir, target)) * rest_b.basis.orthonormalized()
	var parent := skel.get_bone_parent(b)
	var parent_basis := skel.get_bone_global_pose(parent).basis.orthonormalized()
	var local := parent_basis.inverse() * new_basis
	skel.set_bone_pose_rotation(b, local.get_rotation_quaternion())

func _update_hitbox():
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for k in pose:
		var p = pose[k]
		min_x = minf(min_x, p[0])
		max_x = maxf(max_x, p[0])
		min_y = minf(min_y, p[1])
		max_y = maxf(max_y, p[1])
	var w := (max_x - min_x + padding.x) * body_scale
	var h := (max_y - min_y + padding.y) * body_scale
	cur_size = cur_size.lerp(Vector2(w, h), 0.2)
	cur_x = lerpf(cur_x, (min_x + max_x) / 2.0 * body_scale, 0.2)
	box.size = Vector3(cur_size.x, cur_size.y, depth)
	dbg_box.size = box.size
	col.position = Vector3(cur_x, cur_size.y / 2.0, 0)

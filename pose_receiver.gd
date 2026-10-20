extends Node

var udp := PacketPeerUDP.new()
var pose := {}
var skel: Skeleton3D
var smooth_dirs := {}

# [bone, child bone, from landmark, to landmark]
const LIMBS = [
	["LeftArm", "LeftForeArm", "l_shoulder", "l_elbow"],
	["LeftForeArm", "LeftHand", "l_elbow", "l_wrist"],
	["RightArm", "RightForeArm", "r_shoulder", "r_elbow"],
	["RightForeArm", "RightHand", "r_elbow", "r_wrist"],
]

func _ready():
	udp.bind(4242, "127.0.0.1")
	skel = get_node("../Model").find_child("Skeleton3D", true, false)
	if skel == null:
		push_error("No Skeleton3D found under Model")

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
	for limb in LIMBS:
		_aim(limb[0], limb[1], limb[2], limb[3])

func _aim(bone_name: String, child_name: String, from_lm: String, to_lm: String):
	var b := _bone(bone_name)
	var c := _bone(child_name)
	if b == -1 or c == -1:
		push_error("Bone not found: " + bone_name)
		return

	# landmark direction -> Player space -> world -> skeleton space
	var dir_player := (_lm(to_lm) - _lm(from_lm)).normalized()
	var dir_world: Vector3 = get_parent().global_basis * dir_player
	var target: Vector3 = (skel.global_basis.orthonormalized().inverse() * dir_world).normalized()

	# smoothing
	var prev: Vector3 = smooth_dirs.get(bone_name, target)
	target = prev.lerp(target, 0.3).normalized()
	smooth_dirs[bone_name] = target

	# rotate the bone from its rest direction to the target direction
	var rest_b := skel.get_bone_global_rest(b)
	var rest_c := skel.get_bone_global_rest(c)
	var rest_dir := (rest_c.origin - rest_b.origin).normalized()
	var new_basis := Basis(Quaternion(rest_dir, target)) * rest_b.basis.orthonormalized()

	var parent := skel.get_bone_parent(b)
	var parent_basis := skel.get_bone_global_pose(parent).basis.orthonormalized()
	var local := parent_basis.inverse() * new_basis
	skel.set_bone_pose_rotation(b, local.get_rotation_quaternion())

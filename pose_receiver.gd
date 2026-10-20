extends Node

var udp := PacketPeerUDP.new()
var pose := {}
var skel: Skeleton3D
var smooth_dirs := {}
@export var body_scale := 1.0
@export var arm_radius := 0.07
@export var leg_radius := 0.09
@export var head_radius := 0.13
@export var torso_depth := 0.25
@export var torso_pad := 0.05
@export var foot_pad := 0.05
@export var show_debug := true

var parts := []
var ground_offset := 0.9
var dbg_mat: StandardMaterial3D

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

# [from landmark, to landmark, "arm" or "leg"]
const CAPSULES = [
	["l_shoulder", "l_elbow", "arm"],
	["l_elbow", "l_wrist", "arm"],
	["r_shoulder", "r_elbow", "arm"],
	["r_elbow", "r_wrist", "arm"],
	["l_hip", "l_knee", "leg"],
	["l_knee", "l_ankle", "leg"],
	["r_hip", "r_knee", "leg"],
	["r_knee", "r_ankle", "leg"],
]

const LM_TO_BONE = {
	"l_shoulder": "LeftArm", "l_elbow": "LeftForeArm", "l_wrist": "LeftHand",
	"r_shoulder": "RightArm", "r_elbow": "RightForeArm", "r_wrist": "RightHand",
	"l_hip": "LeftUpLeg", "l_knee": "LeftLeg", "l_ankle": "LeftFoot",
	"r_hip": "RightUpLeg", "r_knee": "RightLeg", "r_ankle": "RightFoot",
	"nose": "Head",
}

func _ready():
	udp.bind(4242, "127.0.0.1")
	skel = get_node("../Model").find_child("Skeleton3D", true, false)
	if skel == null:
		push_error("No Skeleton3D found under Model")

	# old single box is no longer used
	get_parent().get_node("CollisionShape3D").disabled = true

	dbg_mat = StandardMaterial3D.new()
	dbg_mat.albedo_color = Color(1, 0.2, 0.2, 0.3)
	dbg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for c in CAPSULES:
		parts.append(_make_part("capsule", c[0], c[1], arm_radius if c[2] == "arm" else leg_radius))
	parts.append(_make_part("box", "", "", 0.0))
	parts.append(_make_part("sphere", "nose", "", head_radius))

func _make_part(kind: String, a: String, b: String, radius: float) -> Dictionary:
	var node := CollisionShape3D.new()
	var shape: Shape3D
	var mesh: Mesh
	match kind:
		"capsule":
			shape = CapsuleShape3D.new()
			mesh = CapsuleMesh.new()
		"box":
			shape = BoxShape3D.new()
			mesh = BoxMesh.new()
		_:
			shape = SphereShape3D.new()
			mesh = SphereMesh.new()
	node.shape = shape
	if show_debug:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = dbg_mat
		node.add_child(mi)
	get_parent().add_child.call_deferred(node)
	return {"kind": kind, "a": a, "b": b, "radius": radius, "node": node, "shape": shape, "mesh": mesh}

func _bone(short_name: String) -> int:
	for prefix in ["mixamorig_", "mixamorig:", "mixamorig"]:
		var i := skel.find_bone(prefix + short_name)
		if i != -1:
			return i
	return -1

func _lm(lm_name: String) -> Vector3:
	var a = pose[lm_name]
	return Vector3(a[0], a[1], a[2])

# landmark in Player-local space (scaled, feet on the floor)
func _p(lm_name: String) -> Vector3:
	var i := _bone(LM_TO_BONE[lm_name])
	var g: Transform3D = skel.global_transform * skel.get_bone_global_pose(i)
	return get_parent().global_transform.affine_inverse() * g.origin

func _process(_delta):
	while udp.get_available_packet_count() > 0:
		var data = JSON.parse_string(udp.get_packet().get_string_from_utf8())
		if data is Dictionary:
			pose = data
	if skel == null or pose.is_empty():
		return
	for limb in LIMBS:
		_aim(limb[0], limb[1], limb[2], limb[3])
	_update_hitbox()

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
	for p in parts:
		match p["kind"]:
			"capsule":
				_set_capsule(p, _p(p["a"]), _p(p["b"]))
			"box":
				_set_torso(p)
			_:
				_set_head(p)

func _set_capsule(p: Dictionary, a: Vector3, b: Vector3):
	var length := a.distance_to(b)
	if length < 0.001:
		return
	var r: float = p["radius"] * body_scale
	var h := length + 2.0 * r
	p["shape"].radius = r
	p["shape"].height = h
	if show_debug:
		p["mesh"].radius = r
		p["mesh"].height = h
	var bs := Basis(Quaternion(Vector3.UP, (b - a) / length))
	p["node"].transform = Transform3D(bs, (a + b) / 2.0)

func _set_torso(p: Dictionary):
	var ls := _p("l_shoulder")
	var rs := _p("r_shoulder")
	var top := (ls + rs) / 2.0
	var bot := (_p("l_hip") + _p("r_hip")) / 2.0
	var up := top - bot
	if up.length() < 0.001:
		return
	var y := up.normalized()
	var x := rs - ls
	x = (x - y * x.dot(y)).normalized()
	var z := x.cross(y)
	var size := Vector3(
		(ls.distance_to(rs) + 2.0 * torso_pad * body_scale),
		up.length() + 2.0 * torso_pad * body_scale,
		torso_depth * body_scale)
	p["shape"].size = size
	if show_debug:
		p["mesh"].size = size
	p["node"].transform = Transform3D(Basis(x, y, z), (top + bot) / 2.0)

func _set_head(p: Dictionary):
	var r: float = p["radius"] * body_scale
	p["shape"].radius = r
	if show_debug:
		p["mesh"].radius = r
		p["mesh"].height = r * 2.0
	p["node"].transform = Transform3D(Basis.IDENTITY, _p("nose") + Vector3(0, 0.1, 0))

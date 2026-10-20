extends Node

var udp := PacketPeerUDP.new()
var pose := {}

func _ready():
	var err := udp.bind(4242, "127.0.0.1")
	if err != OK:
		push_error("UDP bind failed: %d" % err)

func _process(_delta):
	while udp.get_available_packet_count() > 0:
		var text := udp.get_packet().get_string_from_utf8()
		var data = JSON.parse_string(text)
		if data is Dictionary:
			pose = data
			print(pose.get("l_wrist"))

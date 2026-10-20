import socket, json, time, math

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
t = 0.0
while True:
    msg = {"left_elbow": 90 + 40 * math.sin(t)}
    sock.sendto(json.dumps(msg).encode(), ("127.0.0.1", 4242))
    t += 0.1
    time.sleep(1 / 30)
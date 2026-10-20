import cv2, mediapipe as mp, socket, json

NAMES = {
    0: "nose",
    7: "l_ear",       8: "r_ear",
    11: "l_shoulder", 12: "r_shoulder",
    13: "l_elbow",    14: "r_elbow",
    15: "l_wrist",    16: "r_wrist",
    23: "l_hip",      24: "r_hip",
    25: "l_knee",     26: "r_knee",
    27: "l_ankle",    28: "r_ankle",
}

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
mp_pose = mp.solutions.pose
pose = mp_pose.Pose(model_complexity=1, smooth_landmarks=True)
cap = cv2.VideoCapture(2)

while True:
    ok, frame = cap.read()
    if not ok:
        break
    res = pose.process(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
    if res.pose_world_landmarks:
        lm = res.pose_world_landmarks.landmark
        msg = {name: [lm[i].x, -lm[i].y, -lm[i].z] for i, name in NAMES.items()}
        sock.sendto(json.dumps(msg).encode(), ("127.0.0.1", 4242))
        mp.solutions.drawing_utils.draw_landmarks(
            frame, res.pose_landmarks, mp_pose.POSE_CONNECTIONS)
    cv2.imshow("pose", frame)
    if cv2.waitKey(1) & 0xFF == 27:
        break

cap.release()
cv2.destroyAllWindows()
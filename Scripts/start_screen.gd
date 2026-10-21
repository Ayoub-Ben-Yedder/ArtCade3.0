extends Control

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$VBoxContainer/Button_Easy.pressed.connect(Callable(self, "_on_easy"))
	$VBoxContainer/Button_Meduim.pressed.connect(Callable(self, "_on_medium"))
	$VBoxContainer/Button_Hard.pressed.connect(Callable(self, "_on_hard"))

func _on_easy():
	_start(0)

func _on_medium():
	_start(1)

func _on_hard():
	_start(2)

func _start(level: int):
	GameState.difficulty = level
	get_tree().change_scene_to_file("res://main.tscn")

extends Control

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$VBoxContainer/Button_Restart.pressed.connect(Callable(self, "_restart"))
func _restart ():
	get_tree().change_scene_to_file("res://StartScreen.tscn")
	

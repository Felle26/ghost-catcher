extends CanvasLayer



func _ready() -> void:
	Input.MOUSE_MODE_CAPTURED


func _on_button_2_pressed() -> void:
	get_tree().quit()


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Content/Levels/maps/main.tscn")

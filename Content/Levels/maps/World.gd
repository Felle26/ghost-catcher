extends Node3D

var current_collectibles_in_scene : int = 0


func _ready() -> void:
	
	for child in get_node("Collectible").get_children():
		current_collectibles_in_scene += 1
	
	print(current_collectibles_in_scene)
	

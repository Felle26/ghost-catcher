extends Node3D

var current_collectibles_in_scene : int = 0


func _ready() -> void:
	
	for child in get_node("Collectible").get_children():
		current_collectibles_in_scene += 1
	
	Global.actual_candy_in_scene = current_collectibles_in_scene
	


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.name == "Player" and (Global.current_points == Global.actual_candy_in_scene):
		Global.Finished = true

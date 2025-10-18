extends Node3D

@export var points : int = 1

func _ready() -> void:
	pass


func _on_area_3d_body_entered(body: Node3D) -> void:
	_destroy_sweets()
	
func _destroy_sweets() -> void:
	_send_points_to_player()
	$".".queue_free()
	
func _send_points_to_player() -> void:
	Global.Increase_current_points(1)

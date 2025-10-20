extends Node3D

@export var points : int = 1

func _ready() -> void:
	pass


func _on_area_3d_body_entered(_body: Node3D) -> void:
	$pickupSound.play()
	$Timer.start()


func _destroy_sweets() -> void:
	_send_points_to_player()
	$".".queue_free()
	
func _send_points_to_player() -> void:
	Global.Increase_current_points(1)
	


func _on_timer_timeout() -> void:
	_destroy_sweets()

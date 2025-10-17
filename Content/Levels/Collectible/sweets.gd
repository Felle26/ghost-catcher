extends Node3D


func _destroy_sweets() -> void:
	$".".queue_free()

func _on_area_3d_body_entered(body: Node3D) -> void:
	_destroy_sweets()

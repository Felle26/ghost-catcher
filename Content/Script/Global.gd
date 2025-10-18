extends Node

var current_points : int = 0

func Increase_current_points(points: int) -> void:
	current_points += points
	print_debug(current_points)

extends Node

var current_points : int = 0
var actual_candy_in_scene : int = 0

var current_player_health: int = 0

func Increase_current_points(points: int) -> void:
	current_points += points

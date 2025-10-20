extends CanvasLayer


func _ready() -> void:
	$candie_count.text = str(0)
	$Health_count.text = "+" + str(100)
func _process(_delta):
	$candie_count.text = str(Global.current_points) + "/" + str(Global.actual_candy_in_scene)
	$Health_count.text = "+" + str(Global.current_player_health)

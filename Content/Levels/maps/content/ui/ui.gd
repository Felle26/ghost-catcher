extends CanvasLayer

func _ready() -> void:
	$candie_count.text = str(0)
	$Health_count.text = "+" + str(100)
func _process(_delta):
	$candie_count.text = str(Global.current_points) + "/" + str(Global.actual_candy_in_scene)
	$Health_count.text = "+" + str(Global.current_player_health)
	
	if Global.current_points == 20:
		$Game_info.text = "Boooh...."
		$AnimationPlayer.play("Fade Information")
		
		
	elif Global.current_points == 40:
		$Game_info.text = "The Ghost get´s stronger"
		$AnimationPlayer.play("Fade Information")
		
	
	elif Global.current_points == 60:
		$Game_info.text = "Little spookey Jumpscare"
		$AnimationPlayer.play("Fade Information")
	
	elif Global.current_points == 80:
		$Game_info.text = "The Ghost hastens through the shadows."
		$AnimationPlayer.play("Fade Information")
		
	elif Global.current_points == 90:
		$Game_info.text = "One More Scary Moment"
		$AnimationPlayer.play("Fade Information")
		
	elif Global.current_points == 100:
		$Game_info.text = "The ghost grows swifter with every whisper of the wind."
		$AnimationPlayer.play("Fade Information")
		
	elif  Global.current_points == Global.actual_candy_in_scene:
		$Game_info.text = "Go to the Cathedral on the Graveyard to finish"
		$AnimationPlayer.play("Fade Information")
		
	elif Global.Finished == true:
		$Game_info.text = "You Have Collected all Candies and Finished the Game"
		$AnimationPlayer.play("Fade Information")

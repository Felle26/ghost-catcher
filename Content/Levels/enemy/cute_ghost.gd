extends CharacterBody3D

var player = null
var state_machine

var speed : float = 3.9 #4.0 standard speed
const ATTACK_RANGE : float = 2.5

var damage: int = 5


@export var player_path : NodePath

@onready var nav_agent = $NavigationAgent3D
@onready var anim_tree = $AnimationTree
func _ready() -> void:
	player = get_node(player_path)
	state_machine = anim_tree.get("parameters/playback")
	
	
func _process(_delta : float) -> void:
	if Global.player_is_dead == false:
		velocity = Vector3.ZERO
		
		if Global.current_points == 40:
			damage = 10
		
		if Global.current_points == 80:
			speed = 4.0
		
		if Global.current_points == 100:
			speed = 4.1
		
		match state_machine.get_current_node():
			"idle":
				nav_agent.set_target_position(player.global_transform.origin)
				var next_nav_point = nav_agent.get_next_path_position()
				velocity = (next_nav_point - global_transform.origin).normalized() * speed
				look_at(Vector3(global_position.x + velocity.x, global_position.y + velocity.y, global_position.z + velocity.z), Vector3.UP)
			"attack":
				look_at(Vector3(player.global_position.x, player.global_position.y, player.global_position.z), Vector3.UP)
		
		
		
		anim_tree.set("parameters/conditions/attack", _target_in_range())
		anim_tree.set("parameters/conditions/walk", !_target_in_range())
		
		anim_tree.get("parameters/playback")
		move_and_slide()
	
func _target_in_range() -> bool:
	return global_position.distance_to(player.global_position) < ATTACK_RANGE
	
func _hit_finished() ->void:
	$ghostAttack.play()
	player.hit(damage, "ghost")

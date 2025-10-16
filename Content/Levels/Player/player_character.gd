extends CharacterBody3D

@export var look_sensitivity : float = 0.006
@export var controller_look_sensitivity : float = 0.05

@export var jump_velocity : float = 6.0
@export var auto_bhop : bool = true


const HEADBOB_MOVE_AMOUNT : float = 0.06
const HEADBOB_FREQUENCY : float = 2.4
var headbob_time : float = 0.0

#Ground Movement settings
@export var walk_speed : float = 7.0
@export var sprint_speed : float = 8.5
@export var ground_Accel : float = 14.0
@export var ground_decel : float = 10.0
@export var ground_friction : float = 6.0

@export var air_cap : float = 0.85
@export var air_accel : float = 800.0
@export var air_move_speed : float = 500.0

var wish_dir : Vector3 = Vector3.ZERO

func get_move_speed() -> float:
	return sprint_speed if Input.is_action_pressed("MOVE_SPRINT") else walk_speed
	

func _ready() -> void:
	for child in %WorldModel.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * look_sensitivity)
			%Camera3D.rotate_x(-event.relative.y * look_sensitivity)
			%Camera3D.rotation.x = clamp(%Camera3D.rotation.x, deg_to_rad(-80), deg_to_rad(80))
			
func _headbob_effect(delta: float) -> void:
	headbob_time += delta * self.velocity.length()
	%Camera3D.transform.origin = Vector3(
		cos(headbob_time * HEADBOB_FREQUENCY * 0.5) * HEADBOB_MOVE_AMOUNT,
		sin(headbob_time * HEADBOB_FREQUENCY) * HEADBOB_MOVE_AMOUNT,
		0,
	)
var _cur_controller_look = Vector2()
func _handle_controller_look_input(delta : float) -> void:
	var target_look = Input.get_vector("look_left","look_right","look_down","look_up").normalized()
	if target_look.length() < _cur_controller_look.length():
		_cur_controller_look = target_look
	else:
		_cur_controller_look = _cur_controller_look.lerp(target_look, 5.0 * delta)
	
	rotate_y(-_cur_controller_look.x * controller_look_sensitivity)
	%Camera3D.rotate_x(_cur_controller_look.y * controller_look_sensitivity)


func _process(delta: float) -> void:
	_handle_controller_look_input(delta)
	
func clip_velocity(normal: Vector3, overbounce : float, delta : float) -> void:
	var backoff := self.velocity.dot(normal) * overbounce
	if backoff >= 0: return
	
	var change := normal * backoff
	self.velocity -= change
	
	var adjust := self.velocity.dot(normal)
	if adjust < 0.0:
		self.velocity -= normal * adjust	

func _handle_ground_physics(delta: float) -> void:
	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir)
	var add_speed_till_cap = get_move_speed() - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = ground_Accel * delta * get_move_speed()
		accel_speed = min(accel_speed, add_speed_till_cap)
		self.velocity += accel_speed * wish_dir
		
		var control = max(self.velocity.length(), ground_decel)
		var drop = control * ground_friction * delta
		var new_speed = max(self.velocity.length() - drop, 0.0)
		if self.velocity.length() > 0:
			new_speed /= self.velocity.length()
		self.velocity *= new_speed
		
	
	
	_headbob_effect(delta)
func is_surface_too_steep( normal: Vector3) -> bool:
	var max_slope_ang_dot = Vector3(0,1,0).rotated(Vector3(1.0,0,0), self.floor_max_angle).dot(Vector3(0,1,0))
	if normal.dot(Vector3(0,1,0)) < max_slope_ang_dot:
		return true
	return false
	
func _handle_air_physics(delta:float) ->void:
	self.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	 #classic battle tested & fan fav source Quake air Movement
	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir)
	var capped_speed = min((air_move_speed * wish_dir).length(), air_cap)
	var add_speed_till_cap = capped_speed - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = air_accel * air_move_speed * delta
		accel_speed = min(accel_speed, add_speed_till_cap)
		self.velocity += accel_speed * wish_dir
	
	if is_on_wall():
		if is_surface_too_steep(get_wall_normal()):
			self.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING 
		else:
			self.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
		clip_velocity(get_wall_normal(), 1, delta)
			

func _physics_process(delta: float) -> void:
	var input_dir = Input.get_vector("MOVE_LEFT","MOVE_RIGHT","MOVE_FORWARD","MOVE_BACKWARD").normalized()
	wish_dir = self.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	
	if is_on_floor():
		if Input.is_action_just_pressed("MOVE_JUMP") or (auto_bhop and Input.is_action_just_pressed("MOVE_JUMP")):
			self.velocity.y = jump_velocity
		_handle_ground_physics(delta)
	else:
		_handle_air_physics(delta)
		
	move_and_slide()
		

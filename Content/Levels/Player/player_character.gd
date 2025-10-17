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
var cam_aligned_wish_dir : Vector3 = Vector3.ZERO

const CROUCH_TRANSLATE : float = 0.7
const CROUCH_JUMP_ADD : float = CROUCH_TRANSLATE * 0.9
var is_crouched : bool = false

var noclip_speed_mult : float = 3.0
var noclip : bool = false

const MAX_STEP_HEIGHT : float = 0.5
var _snapped_to_stairs_last_frame : bool = false
var _last_frame_was_on_floor = -INF

func get_move_speed() -> float:
	if is_crouched:
		return walk_speed * 0.8
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
			
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			noclip_speed_mult = min(100.0, noclip_speed_mult * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			noclip_speed_mult = max(0.1, noclip_speed_mult * 0.9)
			
			
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
	
var _saved_camera_global_pos = null

func _saved_camera_global_pos_for_smoothing() -> void:
	if _saved_camera_global_pos == null:
		_saved_camera_global_pos = %CameraSmooth.global_position 

func _slide_camera_smooth_back_to_origin(delta : float) -> void:
	if _saved_camera_global_pos == null: return
	%CameraSmooth.global_position.y = _saved_camera_global_pos.y
	%CameraSmooth.position.y = clampf(%CameraSmooth.position.y, -0.7, 0.7)
	var move_amount = max(self.velocity.length() * delta, walk_speed/2 * delta)
	%CameraSmooth.position.y = move_toward(%CameraSmooth.position.y, 0.0, move_amount)
	_saved_camera_global_pos = %CameraSmooth.global_position
	if %CameraSmooth.position.y == 0:
		_saved_camera_global_pos = null
	
#Walk Downstairs
func _snap_down_to_stairs_check() -> void:
	var did_snap : bool = false
	var floor_below : bool = %StairsBelowRayCast3D.is_colliding() and not is_surface_too_steep(%StairsBelowRayCast3D.get_collision_normal())
	var was_on_floor_last_frame = Engine.get_physics_frames() - _last_frame_was_on_floor == 1
	if not is_on_floor() and velocity.y <= 0 and (was_on_floor_last_frame or _snapped_to_stairs_last_frame) and floor_below:
		var body_test_result = PhysicsTestMotionResult3D.new()
		if _run_body_test_motion(self.global_transform, Vector3(0, -MAX_STEP_HEIGHT,0), body_test_result):
			_saved_camera_global_pos_for_smoothing()
			var translate_y = body_test_result.get_travel().y
			self.position.y += translate_y
			apply_floor_snap()
			did_snap = true
	_snapped_to_stairs_last_frame = did_snap

#walk Upstairs
func _snap_up_stairs_check(delta) -> bool:
	if not is_on_floor() and not _snapped_to_stairs_last_frame: return false
	# Don't snap stairs if trying to jump, also no need to check for stairs ahead if not moving
	if self.velocity.y > 0 or (self.velocity * Vector3(1,0,1)).length() == 0: return false
	var expected_move_motion = self.velocity * Vector3(1,0,1) * delta
	var step_pos_with_clearance = self.global_transform.translated(expected_move_motion + Vector3(0, MAX_STEP_HEIGHT * 2, 0))
	# Run a body_test_motion slightly above the pos we expect to move to, towards the floor.
	#  We give some clearance above to ensure there's ample room for the player.
	#  If it hits a step <= MAX_STEP_HEIGHT, we can teleport the player on top of the step
	#  along with their intended motion forward.
	var down_check_result = KinematicCollision3D.new()
	if (self.test_move(step_pos_with_clearance, Vector3(0,-MAX_STEP_HEIGHT*2,0), down_check_result)
	and (down_check_result.get_collider().is_class("StaticBody3D") or down_check_result.get_collider().is_class("CSGShape3D"))):
		var step_height = ((step_pos_with_clearance.origin + down_check_result.get_travel()) - self.global_position).y
		# Note I put the step_height <= 0.01 in just because I noticed it prevented some physics glitchiness
		# 0.02 was found with trial and error. Too much and sometimes get stuck on a stair. Too little and can jitter if running into a ceiling.
		# The normal character controller (both jolt & default) seems to be able to handled steps up of 0.1 anyway
		if step_height > MAX_STEP_HEIGHT or step_height <= 0.01 or (down_check_result.get_position() - self.global_position).y > MAX_STEP_HEIGHT: return false
		%StairsAheadRayCast3D.global_position = down_check_result.get_position() + Vector3(0,MAX_STEP_HEIGHT,0) + expected_move_motion.normalized() * 0.1
		%StairsAheadRayCast3D.force_raycast_update()
		if %StairsAheadRayCast3D.is_colliding() and not is_surface_too_steep(%StairsAheadRayCast3D.get_collision_normal()):
			_saved_camera_global_pos_for_smoothing()
			self.global_position = step_pos_with_clearance.origin + down_check_result.get_travel()
			apply_floor_snap()
			_snapped_to_stairs_last_frame = true
			return true
	return false
#crouching
@onready var _original_capsule_height = $CollisionShape3D.shape.height
func _handle_crouch(delta : float) -> void:
	var was_crouched_last_frame : bool = is_crouched
	if Input.is_action_pressed("MOVE_CROUCH"):
		is_crouched = true
	elif is_crouched and not self.test_move(self.transform, Vector3(0, CROUCH_TRANSLATE, 0)):
		is_crouched = false
		
		var translate_y_if_possible := 0.0
		if was_crouched_last_frame != is_crouched and not is_on_floor() and not _snapped_to_stairs_last_frame:
			translate_y_if_possible = CROUCH_JUMP_ADD if is_crouched else -CROUCH_JUMP_ADD
		if translate_y_if_possible != 0.0:
			var result = KinematicCollision3D.new()
			self.test_move(self.transform, Vector3(0, translate_y_if_possible, 0), result)
			self.position.y += result.get_travel().y
			%Head.position.y -= result.get_travel().y
			%Head.position.y = clampf(%Head.position.y, -CROUCH_TRANSLATE, 0)
		
	%Head.position.y = move_toward(%Head.position.y, -(CROUCH_TRANSLATE / 2) if is_crouched else 0, 7.0 * delta)  #umbau von CROUCH_TRANSLATE zu (CROUCH_TRANSLATE / 2 [= 0.35]) wegen Player Character fehler vom mir
	$CollisionShape3D.shape.height = _original_capsule_height - (CROUCH_TRANSLATE + 0.2) if is_crouched else _original_capsule_height #umbau von CROUCH_TRANSLATE zu (CROUCH_TRANSLATE + 0.2) wegen Player Character fehler vom mir
	$CollisionShape3D.position.y = $CollisionShape3D.shape.height / 2
	
	
#Noclip Debug Function
func _handle_noclip(delta : float) -> bool:
	if Input.is_action_just_pressed("_Noclip") and OS.has_feature("debug"):
		noclip = !noclip
		noclip_speed_mult = 3.0
	$CollisionShape3D.disabled = noclip
	if not noclip:
		return false
		
	var speed = get_move_speed() * noclip_speed_mult
	if Input. is_action_just_pressed("MOVE_SPRINT"):
		speed *= 3.0
	
	self.velocity = cam_aligned_wish_dir * speed
	global_position += self.velocity * delta
	
	return true
	
	
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
	return normal.angle_to(Vector3.UP) > self.floor_max_angle
	
func _run_body_test_motion(from: Transform3D, motion : Vector3, result = null) -> bool:
	if not result: result = PhysicsTestMotionResult3D.new()
	var params = PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	return PhysicsServer3D.body_test_motion(self.get_rid(), params, result)
	
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
		
		var wall_normal = get_wall_normal()
		var is_wall_vertical = abs(wall_normal.dot(Vector3.UP)) < 0.1
		if is_surface_too_steep(wall_normal) and not is_wall_vertical:
			self.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING 
		else:
			self.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
		clip_velocity(wall_normal, 1, delta)
			

func _physics_process(delta: float) -> void:
	if is_on_floor(): _last_frame_was_on_floor = Engine.get_physics_frames()
	
	var input_dir = Input.get_vector("MOVE_LEFT","MOVE_RIGHT","MOVE_FORWARD","MOVE_BACKWARD").normalized()
	wish_dir = self.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	cam_aligned_wish_dir = %Camera3D.global_transform.basis * Vector3(input_dir.x, 0., input_dir.y)
	
	_handle_crouch(delta)
	
	if not _handle_noclip(delta):
		if is_on_floor() or _snapped_to_stairs_last_frame:
			if Input.is_action_just_pressed("MOVE_JUMP") or (auto_bhop and Input.is_action_just_pressed("MOVE_JUMP")):
				self.velocity.y = jump_velocity
			_handle_ground_physics(delta)
		else:
			_handle_air_physics(delta)
		
		if not _snap_up_stairs_check(delta):
			move_and_slide()
			_snap_down_to_stairs_check()
	
	_slide_camera_smooth_back_to_origin(delta)
		
		
#SONSTIGER CUSTOM STUFF FLASHLIGHT ETC.

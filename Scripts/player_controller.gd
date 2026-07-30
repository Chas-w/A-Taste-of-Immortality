extends Node3D
@export_category("Movement")
@export var player_body : RigidBody3D
@export var lower_body_visual : MeshInstance3D
@export var ground_cast : RayCast3D
@export var climb_checker : RayCast3D
@export var max_stamina : float
@export var climb_speed = 3
var rot_offset : Vector2
var grounded
var climbing : bool 
var speed
var input_dir 
var direction 
var climb_dir
#basic move variables
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 8
var sens = 0.0004
var default_sens =  0.0004

@export_category("Point and Click Variables")
@export var nav_agent : NavigationAgent3D
@export var pc_rotation_speed : float
var pc_moving : bool 

@export_category("Collisions")
@export var body_collision : CollisionShape3D

@export_category("Player Data Info")
@export var health : float
@export var morality : float
var target_item : Node3D
var can_pickup : bool 
var status_dictionary
var inventory_dictionary #consider inventory in sep. node
var database
var time_to_autosave_max = 600
var autosave_timer

@export_category("States")
enum Move_State{Idle,Moving, PC_Moving, Climbing, Null}
@export var move_state : Move_State = Move_State.Idle
enum Interact_State{Talk, Inspect, In_Menu, In_Other_View, Null}
@export var interact_state : Interact_State = Interact_State.Null

func _ready():
	for game_obj in get_tree().get_nodes_in_group("Database"): #assign database
		database = game_obj
	database.access_player = self
	status_dictionary = database._JSON_to_dictionary(database.player_status_path)
	inventory_dictionary = database._JSON_to_dictionary(database.player_inventory_path)
	_load_in()

func _load_in():
	speed = WALK_SPEED
	health = status_dictionary.Health
	autosave_timer = time_to_autosave_max
	
	#spawn location
	position = Vector3(status_dictionary.Position[0],status_dictionary.Position[1],status_dictionary.Position[2])
func _process(delta):
	#ground check
	grounded = ground_cast.is_colliding()
	#save game behavior
	if (database.saving):
		_update_JSON_data()
		print("SAVING...")
		autosave_timer = time_to_autosave_max
		database.saving = false
	if (database.autosave_enabled):
		_handle_autosave()
		
	#handle move check
	if (!database.pause_game && move_state != Move_State.Null):
		input_dir = Input.get_vector("left", "right", "up", "down")
		direction = (player_body.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		_handle_adding_inventory()
		if(direction && move_state != Move_State.Moving && !climbing && grounded):
			_set_move_state(Move_State.Moving)
	match(move_state):
		Move_State.PC_Moving:
				#region Applying Point and Click Movement
				if(nav_agent.is_navigation_finished() ): #if navigation is finished do NOTHING (breaks the movement loop)
					return
				else:
					_move_to_target(delta,WALK_SPEED) #otherwise, continuously move towards the target position at preset speed (move_speed)
				#endregion

func _move_to_target(delta,speed): #setting point and click movement parameters
	var target_position = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(target_position)
	#region Rotate To Look At Target
	if (player_body.linear_velocity != Vector3.ZERO):
		var target2D : Vector2 = Vector2(target_position.x, target_position.z)
		var player2D : Vector2 = Vector2(global_position.x, global_position.z)
		var face_direction = -(target2D - player2D)
		player_body.rotation.y = lerp_angle(rotation.y, atan2(face_direction.x, face_direction.y), delta * pc_rotation_speed)
		pc_moving = true
	else:
		pc_moving = false
	#endregion
	player_body.linear_velocity = direction * speed

func _input(event):
	#region Checking for Point and Click Ability
	if(Input.is_action_just_pressed("click")):
		var mouse_pos = get_viewport().get_mouse_position() #mouse position in world space
		var ray_length = 1000 #length of raycast shot from mouse position
		var from = database.cam.project_ray_origin(mouse_pos) #starting position of raycast
		var to = from + database.cam.project_ray_normal(mouse_pos) * ray_length #target of raycast
		var space = get_world_3d().direct_space_state #where raycast is being translated from
		var ray_query = PhysicsRayQueryParameters3D.new() #new raycast
		ray_query.from = from
		ray_query.to = to
		var result = space.intersect_ray(ray_query) #where the raycast intersects with an object
		if(result != { }): #ensuring that this is a clickable space
			var clicked_node = result.collider
			if (clicked_node.is_in_group("Ground")): #ensuring that this is where we want the player to be targeting
				nav_agent.set_target_position(result.position) #apply navigation
				_set_move_state(Move_State.PC_Moving)
		print(result)
	#region turn in place
	if (Input.is_action_just_pressed("sprint") && !pc_moving):
		rotation.y += 1
	#endregion
	#endregion

func _physics_process(delta):
	#rotation
	_body_rotation()
	# jump
	if(Input.is_action_just_pressed("jump") && grounded && !climbing && move_state != Move_State.Null):
		player_body.linear_velocity.y += JUMP_VELOCITY * 45 * delta
	else:
		player_body.gravity_scale = 2
	#visual 
	lower_body_visual.global_position = player_body.global_position #only when the rotation has reached a certain edge
	
	#movement state machine
	match(move_state):
		Move_State.Moving:
			_handle_movement()
			pass
	
	if (database.pause_game):
		player_body.linear_velocity = Vector3.ZERO

func _handle_autosave():
	if(autosave_timer >= 0):
		autosave_timer -= get_process_delta_time()
	else:
		_update_JSON_data()
		print("AUTOSAVING...")
		autosave_timer = time_to_autosave_max

func _handle_adding_inventory(): ##handles adding an item to your inventory
	if(Input.is_action_just_pressed("interact")):
		if(can_pickup && target_item != null):
			if(!target_item.permanent):
				inventory_dictionary.Removable.append(target_item.ID)
				target_item.queue_free()
				can_pickup = false
			else:
				#this is called when the player grabs a permanent item
				pass

func _handle_movement():
	# Get the input direction and handle the movement/deceleration.
	if direction:
		player_body.linear_velocity.x = direction.x *  speed
		player_body.linear_velocity.z = direction.z * speed
	else:
		player_body.linear_velocity.x = lerp(player_body.linear_velocity.x, direction.x * speed, get_process_delta_time()   * 7.0)
		player_body.linear_velocity.z = lerp(player_body.linear_velocity.z, direction.z * speed, get_process_delta_time()   * 7.0)
	player_body.position.normalized()
	#exit move
	if(player_body.linear_velocity.x <= 0 && player_body.linear_velocity.y <= 0):
		_set_move_state(Move_State.Idle)

func _body_rotation():
	pass
	#if(move_state != Move_State.Idle):
		#if(input_dir.x):
			#print("x")
			#
		#if(input_dir.y):
			#print("y")
			#

func _set_move_state(next_move_state:int):
	var prev_move_state := move_state
	move_state = next_move_state
		
	#check last state
	match(prev_move_state):
		Move_State.Climbing:
			climbing = false
			player_body.gravity_scale = 2
	#check upcoming state
	match(next_move_state):
		Move_State.Moving:
			pass

func _set_interact_state(next_interact_state:int):
	var prev_interact_state := interact_state
	interact_state = next_interact_state
		
	#check last state
	match(prev_interact_state):
		pass
	#check upcoming state
	match(next_interact_state):
		pass

func _update_JSON_data():
	status_dictionary.Health = health
	status_dictionary.Morality = morality
	
	status_dictionary.Position[0] = player_body.global_position.x
	status_dictionary.Position[1] = player_body.global_position.y
	status_dictionary.Position[2] = player_body.global_position.z
	
	database._save_JSON_file(database.player_status_path, status_dictionary)
	database._save_JSON_file(database.player_inventory_path, inventory_dictionary)

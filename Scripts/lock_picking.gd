extends Control
@export_category("Visuals")
@export var lock_background : TextureRect
@export var pick : Node2D 
@export var stabilizer :TextureRect

@export_category("Pick Zone")
@export var limit : Node2D
##how easy to get in range
@export_range(.5,20,.5) var safety : float
@export var pick_limits : Vector2
@export var pick_tip : Node2D
@export var limit_tip : Node2D
@export var pivot : Node2D
@export var pick_amount : int
var move_pick : bool 
var pick_speed : float = 4
var higher : bool
var mouse_speed : float

##the target angle between limit and pick
var solution_value : float = 90
## how long the pick has to move before breaking
var pick_time_limit_max : float = 2
var pick_time_limit :float
var break_pick : bool
@export_range(.1,2,.1) var break_buffer_max : float = .5
var break_buffer 

var solve_speed_max = 5
var solve_speed_min = .1
var solve_speed = 1
var solving : bool
var reset : bool 
var solved : bool 
var database
var controller_vector

func _ready(): 
	for game_obj in get_tree().get_nodes_in_group("Database"): #assign database
		database = game_obj
	##setup
	#set a random rotation for the solution
	var new_rot = (randf_range(deg_to_rad(pick_limits.x), deg_to_rad(pick_limits.y)))
	limit.rotation = new_rot
	break_buffer = break_buffer_max
	pick_time_limit = pick_time_limit_max

func _process(delta):
	_handle_pick_rotation()
	_handle_solver()
	if(database.controller_used):
		controller_vector = Input.get_vector("cam_right","cam_left","cam_up","cam_down")
		mouse_speed = absf(controller_vector.x) * 20
		move_pick = true
		if(controller_vector.x < 0):
			higher = true
		else:
			higher = false
		
	if (break_pick):
		_handle_break_pick()

##handles the behavior while the player attempts to solve
func _handle_solver():
	if (Input.is_action_just_pressed("interact")):
		solving = true
	if (Input.is_action_pressed("interact") && pick_amount > 0): #if the player has sufficient amount of picks
		##if the pick is within solvable range
		if(_get_angle(pivot.global_position,pick_tip.global_position, limit_tip.global_position) <= 90 + safety && _get_angle(pivot.global_position,pick_tip.global_position, limit_tip.global_position) >= 90 - safety):
			if (lock_background.rotation > deg_to_rad(-90)):
				lock_background.rotation -=  get_process_delta_time() * solve_speed
			else:
				lock_background.rotation = deg_to_rad(-90)
				solved = true
			#success
		else:
			##variable to represent how long the lock will solve for before failing
			var time_modifier = (90 - _get_angle(pivot.global_position,pick_tip.global_position, limit_tip.global_position))/3
			if (pick_time_limit > 0): #solve
				pick_time_limit -= get_process_delta_time() * time_modifier
				if (lock_background.rotation > deg_to_rad(-90)):
					lock_background.rotation -=  get_process_delta_time() * solve_speed
				else:
					lock_background.rotation = deg_to_rad(-90)
			else: #when time is up start break sequence
				break_pick = true
	else: #when the player releases input reset 
		solving = false
		if (!break_pick):
			if(lock_background.rotation < deg_to_rad(0)):
				lock_background.rotation +=  get_process_delta_time() * 3
			else:
				lock_background.rotation = deg_to_rad(0)
			if(pick_time_limit != pick_time_limit_max):
				pick_time_limit = pick_time_limit_max

##handles behavior after a failed attempt
func _handle_break_pick():
	if(solving): #if the player continues to try and solve
		if(break_buffer > 0): #give a buffer
			break_buffer -= get_process_delta_time()
		else: #once the time is up reset the lock
			if(lock_background.rotation < deg_to_rad(0)):
				lock_background.rotation +=  get_process_delta_time() 
			else: #remove a pick and reset
				break_pick = false
				break_buffer = break_buffer_max
				pick_amount -= 1
				print("PICK BREAK")
				solving = false
				#break animation
	else: #otherwise reset without removing a pick
		break_pick = false
		break_buffer = break_buffer_max

##handles making the picker follow mouse movement
func _handle_pick_rotation(): 
	if (move_pick && !solving && !break_pick):
		if(higher):
			pick.rotation += deg_to_rad(pick_speed * mouse_speed * get_process_delta_time())
		else:
			pick.rotation -= deg_to_rad(pick_speed * mouse_speed * get_process_delta_time())
	move_pick = false

##returns how close to the solution the picker is
func _get_angle(vec1 : Vector2, vec2 : Vector2, vec3 : Vector2):
	var length_a = sqrt(pow(vec2.x - vec1.x, 2) + pow(vec2.y - vec1.y,2))
	var length_b = sqrt(pow(vec3.x - vec2.x,2) + pow(vec3.y - vec2.y, 2))
	var length_c = sqrt(pow(vec3.x - vec1.x,2) + pow(vec3.y - vec1.y, 2))
	
	var calculation = ((length_a * length_a) + (length_b * length_b) - (length_c * length_c)) / (2 * length_a * length_b)
	return rad_to_deg(acos(calculation)) 

func _input(event: InputEvent) -> void:
	if(!database.controller_used):
		if event is InputEventMouseMotion:
			mouse_speed = absf(event.relative.x)
			move_pick = true
			if(event.relative.x > 0):
				higher = true
			else:
				higher = false

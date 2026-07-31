extends CharacterBody3D
func _variables():
	#using this as a quick link to the top of the script
	pass
#https://youtu.be/KT06pv06Q1U?si=Oyfxr4sBKFvDll4
@export_category("Movement Variables")
@export var nav_agent : NavigationAgent3D
@export var rotation_speed : float
@export var move_speed : float
var moving : bool 

@export_category("Movement States")
enum Move_State{POINT_AND_CLICK, CHATTING, INSPECTING, MOVE_NULL}
@export var move_state : Move_State = Move_State.POINT_AND_CLICK
enum PC_State{PC_WALK, PC_NULL}
@export var pc_state : PC_State = PC_State.PC_WALK


@export_category("Camera Variables")
@export var rotation_target : Node3D
var timer : float

@export_category("Interaction Variables")
@export var can_interact : bool 
@export var dialogue_interaction : bool
var interaction_source : Node3D

@export_category("Player Data Info")
@export var health : float
var target_item : Node3D
var can_pickup : bool 
var status_dictionary
var inventory_dictionary #consider inventory in sep. node
var database
var time_to_autosave_max = 600
var autosave_timer

func _ready():
	_set_move_state(Move_State.POINT_AND_CLICK) #setup for point and click
	for game_obj in get_tree().get_nodes_in_group("Database"): #assign database
		database = game_obj
	database.access_player = self
	status_dictionary = database._JSON_to_dictionary(database.player_status_path)
	inventory_dictionary = database._JSON_to_dictionary(database.player_inventory_path)
		
	#spawn location
	position = Vector3(status_dictionary.Position[0],status_dictionary.Position[1],status_dictionary.Position[2])

func _handle_saving():
	if (database.saving):
		_update_JSON_data()
		print("SAVING...")
		autosave_timer = time_to_autosave_max
		database.saving = false
	if (database.autosave_enabled):
		_handle_autosave()

func _handle_autosave():
	if(autosave_timer >= 0):
		autosave_timer -= get_process_delta_time()
	else:
		_update_JSON_data()
		print("AUTOSAVING...")
		autosave_timer = time_to_autosave_max

func _process(delta):
	_handle_saving()
	match(move_state):
		Move_State.POINT_AND_CLICK:
			match(pc_state):
				PC_State.PC_WALK:
					#region Applying Point and Click Movement
					if(nav_agent.is_navigation_finished() ): #if navigation is finished do NOTHING (breaks the movement loop)
						return
					else:
						_move_to_target(delta,move_speed) #otherwise, continuously move towards the target position at preset speed (move_speed)
					#endregion
		Move_State.CHATTING:
			if (interaction_source.can_exit && (Input.is_action_just_pressed("exit") || interaction_source.database.exit_interaction_button.button_pressed)):
				interaction_source._exit_dialogue()
				_set_move_state(Move_State.POINT_AND_CLICK)
			if (interaction_source.can_move_scene && Input.is_action_just_pressed("enter")):
				interaction_source._next_scene()
			pass
		Move_State.INSPECTING:
			pass

func _move_to_target(delta,speed): #setting point and click movement parameters
	var target_position = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(target_position)
	#region Rotate To Look At Target
	if (velocity != Vector3.ZERO):
		var target2D : Vector2 = Vector2(target_position.x, target_position.z)
		var player2D : Vector2 = Vector2(global_position.x, global_position.z)
		var face_direction = -(target2D - player2D)
		rotation.y = lerp_angle(rotation.y, atan2(face_direction.x, face_direction.y), delta * rotation_speed)
		moving = true
	else:
		moving = false
	#endregion
	velocity = direction * speed
	move_and_slide()

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

func _set_move_state(next_move_state:int):
	var prev_move_state := move_state
	move_state = next_move_state
		
	#check last state
	match(prev_move_state):
		Move_State.CHATTING:
			interaction_source.get_child(1).priority = 0
		pass
	#check upcoming state
	match(next_move_state):
		Move_State.POINT_AND_CLICK:
			if(interaction_source != null):
				interaction_source.hover_label.visible = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
			_set_PC_state(PC_State.PC_WALK)
		Move_State.CHATTING:
			nav_agent.set_target_position(position) #stop the movement, reset the target position
			interaction_source.get_child(1).priority = 100
			if(!interaction_source.entered):
				interaction_source._enter_dialogue()
			else:
				interaction_source._progress_dialogue("Default")
			pass
		Move_State.INSPECTING:
			pass

func _set_PC_state(next_PC_state:int):
	var prev_PC_state := pc_state
	pc_state = next_PC_state
	
	#check last state
	match(prev_PC_state):
		pass
	#check upcoming state
	match(next_PC_state):
		pass
	pass

func _input(event):
	#region Checking for Point and Click Ability
	if(Input.is_action_just_pressed("click") &&  move_state != Move_State.CHATTING && move_state != Move_State.INSPECTING && !database.pause_game):
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
	#region turn in place
	if (Input.is_action_just_pressed("sprint") && move_state == Move_State.POINT_AND_CLICK && !moving):
		rotation.y += 1
	#endregion
	#endregion

	#region interact input
	if(event.is_action_pressed("interact") && can_interact && move_state != Move_State.CHATTING):
		_set_move_state(Move_State.CHATTING)
	#endregion

func _on_interaction_detector_area_entered(area):
	if(area.is_in_group("Interaction")):
		can_interact = true
		interaction_source = area.get_parent()
		interaction_source.hover_label.text = "E"
func _on_interaction_detector_area_exited(area):
	if(area.is_in_group("Interaction")):
		can_interact = false
		interaction_source.hover_label.text = " "

func _update_JSON_data():
	status_dictionary.Health = health
	
	status_dictionary.Position[0] = global_position.x
	status_dictionary.Position[1] = global_position.y
	status_dictionary.Position[2] = global_position.z
	
	database._save_JSON_file(database.player_status_path, status_dictionary)
	database._save_JSON_file(database.player_inventory_path, inventory_dictionary)

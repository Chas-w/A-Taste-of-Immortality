extends Node3D
@export_category("Info")
@export var ID : String
@export var permanent : bool 
@export var interact_label : Label3D
var interact_message = "E"
var database 
var player

@export_category("UI") 
##path to ui texture
@export var item_ui_tex : String
##path to rotatable mesh
@export var item_rotate_mesh : String


func _ready():
	for game_obj in get_tree().get_nodes_in_group("Database"): #assign database
		database = game_obj
	for game_obj_1 in get_tree().get_nodes_in_group("Player Controller"): #assign database
		player = game_obj_1
	interact_label.text = interact_message
	interact_label.visible = false

func _on_equip_range_body_entered(body):
	if (body.is_in_group("Player")):
		interact_label.visible = true
		player.target_item = self
		player.can_pickup = true

func _on_equip_range_body_exited(body):
	if (body.is_in_group("Player")):
		interact_label.visible = false
		player.target_item = null
		player.can_pickup = false

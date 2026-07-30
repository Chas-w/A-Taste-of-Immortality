extends Node3D
@export var locked : bool
@export var lock_picking : Control
@export var barrier : CollisionShape3D
var player
var door_buffer_max = 4
var door_buffer
var picking:bool
func _ready():
	if (!locked):
		lock_picking.queue_free() #if the door isn't locked get rid of this node
	else:
		lock_picking.visible = false #hide this node
	door_buffer = door_buffer_max

func _process(delta):
	if (player != null):
		if(Input.is_action_just_pressed("interact")):
			if (!locked):
				barrier.disabled = true
				self.visible = false
			if(locked && !picking):
				picking = true
				lock_picking.visible = true
				player._set_move_state(player.Move_State.Null)
	if (barrier.disabled):
		if(door_buffer > 0):
			door_buffer -= delta
		else:
			if(player == null):
				door_buffer = door_buffer_max
				barrier.disabled = false
				self.visible = true
	
	if(picking):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if(lock_picking.solved):
			barrier.disabled = true
			self.visible = false
			locked = false
			player._set_move_state(player.Move_State.Idle)
			lock_picking.queue_free() #if the door isn't locked get rid of this node
			picking = false
			Input.mouse_mode = Input.MOUSE_MODE_CONFINED

func _on_open_trigger_body_entered(body):
	if(body.is_in_group("Player")):
		player = body.get_parent()


func _on_open_trigger_body_exited(body):
	if(body.is_in_group("Player")):
		player = null

extends Spatial

# Constants
const MIN_X_ANGLE = -30
const MAX_X_ANGLE =  30
const MIN_Y_ANGLE = -90
const MAX_Y_ANGLE =  90
const LOOK_SENS =  10
const BONE_HEAD =  12

# Player Parts
onready var head = $Head
onready var user = $Head/Name/Margin/Inner/Centered/Label
onready var face = $Head/Face
onready var anim  = $AnimationTree
onready var pov_cam = $Head/FaceCam
onready var top_cam = $Topdown

# Trackers
onready var amPlayer = false
onready var isActive = false
onready var mouse_delta = Vector2()

#-----------------------------------------------------------------------------#

# PLAYER SETUP #

func setup_self():
	pov_cam.make_current()
	amPlayer = true
	isActive = true

func setup_all(p_name, index):
	user.text = p_name
	anim.set_idle(index)
	update_face(0)

#-----------------------------------------------------------------------------#

# UPDATING THE PLAYER #

func update_head(transform):
	head.global_transform = transform

func update_face(idx):
	var texture = Global.FACES[idx]
	face.material.albedo_texture = texture

func update_idle():
	anim.change_idle()
	broadcast("idle", null)

func toggle_hand(flag):
	if flag: anim.raise_hand()
	else:    anim.lower_hand()
	broadcast("hand", flag)

func swap_camera():
	if pov_cam.current: top_cam.make_current()
	else: pov_cam.make_current()

#-----------------------------------------------------------------------------#

# HEAD TRACKING #

func _input(event):
	if event is InputEventMouseMotion:
		mouse_delta = event.relative

func _process(delta):
	if amPlayer and not mouse_delta.is_equal_approx(Vector2()):
		head.rotation_degrees.x += mouse_delta.y * LOOK_SENS * delta
		head.rotation_degrees.x = clamp(head.rotation_degrees.x, MIN_X_ANGLE, MAX_X_ANGLE)
		head.rotation_degrees.y -= mouse_delta.x * LOOK_SENS * delta
		head.rotation_degrees.y = clamp(head.rotation_degrees.y, MIN_Y_ANGLE, MAX_Y_ANGLE)
		broadcast("head", head.global_transform)
		mouse_delta = Vector2()

#-----------------------------------------------------------------------------#

# NETWORKING #

# ! Player.gd version handles sending all info except the voice data.
func broadcast(msg, data) -> void:
	if amPlayer and isActive:
		var packet_data = Global.createPacket()
		packet_data.msg = msg
		packet_data.inf = data
		Global.broadcastPacket(packet_data)

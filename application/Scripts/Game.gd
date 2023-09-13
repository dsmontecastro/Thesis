extends Spatial


# Player Instance
const PLAYER = preload("res://Scenes/Player.tscn")
var player_self

# Player References
onready var host    = Global.LOBBY[0].id
onready var players = $Players
onready var spawner = $SpawnPoints.get_children()
onready var player_list = Global.LOBBY

# GUI References
onready var quit = $GUI/FS_Margin/Options
onready var face = $GUI/LR_Margin/Face/Centered/Texture

# Audio Elements
const AUDIO_DELAY = 0.5
onready var timer = $Audio
onready var mic   = AudioServer.get_bus_effect(AudioServer.get_bus_index("Record"), 0)
onready var mute  = false

# Face Trackers
const FACES = 15
var faceIdx = 0

#-----------------------------------------------------------------------------#

func _ready():

	# Initial Settings
	Steam.connect("lobby_chat_update", self, "_on_Lobby_Chat_Update")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)		# Mouse Handling
	mic.set_recording_active(false)						# Mic Starts Off
	timer.wait_time = AUDIO_DELAY						# VChat Latency
	face.texture = load("res://assets/Faces/0.png")		# Use Base Face

	# Player Spawning
	for localID in player_list: spawn_player(localID)

#-----------------------------------------------------------------------------#

# PLAYER(S) SPAWN

func get_spawn_point(index):
	return spawner[index].global_transform.origin


remote func spawn_player(localID):

	# Creates new instance of Player Character
	var playerChar = PLAYER.instance()
	var playerInfo = player_list[localID]
	playerChar.name = str(playerInfo.id)
	players.add_child(playerChar)
	playerChar.setup_all(playerInfo.name, localID)

	# Sets up Own and Other Player Character(s)
	if Global.STEAM_ID == playerInfo.id:
		playerChar.setup_self()
		player_self = players.get_node(str(playerInfo.id))
	else:
		var speaker  = AudioStreamPlayer.new()
		speaker.name = str(playerInfo.id)
		timer.add_child(speaker)

	# Adjusts Player Character Spawn & Rotation
	playerChar.global_transform.origin = get_spawn_point(localID)
	if localID < 1:
		playerChar.rotate(Vector3(0,1,0), -PI/2)
	else:
		playerChar.rotate(Vector3(0,1,0),  PI/2)

#-----------------------------------------------------------------------------#

# VOICE CHAT

func _on_Mic_toggled(button_pressed):
	mic.set_recording_active(button_pressed)
	if button_pressed: timer.start()
	else: timer.stop()

func _on_Mute_toggled(button_pressed):
	mute = button_pressed


# Send audio sample every [AUDIO_DELAY] seconds
func _on_Audio_timeout():
	if mic.is_recording_active():
		mic.set_recording_active(false)
		var recording = mic.get_recording()
		if (recording != null): broadcast("talk", recording.get_data())
		mic.set_recording_active(true)


# Creates AudioStreamSample object from PoolByteArray data
func sample(sample):
	var audio = AudioStreamSample.new()
	audio.format    = AudioStreamSample.FORMAT_16_BITS
	audio.loop_mode = AudioStreamSample.LOOP_DISABLED
	audio.mix_rate  = 44100 * 2 # No clue how this works but it does
	audio.data      = sample
	return audio

#-----------------------------------------------------------------------------#

# PLAYER CONTROLS #

func _on_Pose_pressed():
	player_self.update_idle()

func _on_Camera_pressed():
	player_self.swap_camera()

func _on_Hand_toggled(button_pressed):
	player_self.toggle_hand(button_pressed)

func setPlayerActive():
	player_self.isActive = !quit.visible

func updateFace(flag):

	# Cycle FaceIdx
	faceIdx = (faceIdx + flag) % FACES
	if faceIdx < 0: faceIdx += FACES

	# Change Face Image
	player_self.update_face(faceIdx)
	face.texture = Global.FACES[faceIdx]

	broadcast("face", faceIdx)

#-----------------------------------------------------------------------------#

# ESC/EXIT MENU #

func _on_Exit_Menu_pressed():
	quit.visible = !quit.visible
	if quit.visible: Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else: Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	setPlayerActive()

func _on_Quit_No_pressed():
	quit.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	setPlayerActive()

func _on_FullScreen_toggled(button_pressed):
	OS.window_fullscreen = button_pressed
	$GUI/FS_Margin/Options/ColorRect.rect_size = OS.window_size
	$GUI/FS_Margin/Options/Centered.rect_size  = OS.window_size

#-----------------------------------------------------------------------------#

# PLAYER QUITS/DISCONNECTS #

func _on_Lobby_Chat_Update(_lobbyID, changedID, _makingChangeID, chatState):
	if (chatState > 1):     # a player leaves the lobby
		players.get_node(str(changedID)).queue_free()
		timer.get_node(str(changedID)).queue_free()


func _on_Quit_Yes_pressed():

	# Change Lobby Owner to next Member in Steam Lobby
	var lobbyID = Global.LOBBY_ID
	if (Global.STEAM_ID == Steam.getLobbyOwner(lobbyID)):
		var members = Steam.getNumLobbyMembers(lobbyID)
		if (members > 1):
			var ownerID = Steam.getLobbyMemberByIndex(lobbyID, 1)
			Steam.setLobbyOwner(lobbyID, ownerID)

	# Properly leave the Steam Lobby (procs LobbyChatUpdate function above)
	yield(get_tree().create_timer(0.5), "timeout")
	Global.reset()
	get_tree().change_scene("res://Scenes/MainMenu.tscn")

#-----------------------------------------------------------------------------#

# ACTIVE PROCESSSES #

func _process(_delta):
	readPacket()	# Checks for packets per frame

func _input(event):
	if   event.is_action_pressed("ui_up"):        updateFace(+1)
	elif event.is_action_pressed("ui_page_up"):   updateFace(+1)
	elif event.is_action_pressed("ui_down"):      updateFace(-1)
	elif event.is_action_pressed("ui_page_down"): updateFace(-1)
	elif event.is_action_pressed("ui_left"):      updateFace(-5)
	elif event.is_action_pressed("ui_right"):     updateFace(+5)

#-----------------------------------------------------------------------------#

# NETWORKING #

# ! Game.gd version only handles sending the voice data.
func broadcast(msg, data) -> void:
	if !quit.visible:
		var packet_data = Global.createPacket()
		packet_data.msg = msg
		packet_data.inf = data
		Global.broadcastPacket(packet_data)


func readPacket() -> void:
	var PACKET_SIZE: int = Steam.getAvailableP2PPacketSize(0)
	if (PACKET_SIZE > 0):	# There is a Packet
		var PACKET  : Dictionary = Steam.readP2PPacket(PACKET_SIZE, 0)
		var READABLE: Dictionary = bytes2var(PACKET.data.subarray(1, PACKET_SIZE - 1))

		var pID = READABLE["src"]
		var msg = READABLE["msg"]
		var inf = READABLE["inf"]

		# Response per P2P Packet Received
		if (msg == "talk" and not mute):
			var speaker = timer.get_node(str(pID))
			speaker.stream = sample(inf)
			speaker.play()
		else:
			var player =  players.get_node(str(pID))
			if    msg == "hand": player.toggle_hand(inf)
			elif  msg == "head": player.update_head(inf)
			elif  msg == "face": player.update_face(inf)
			elif  msg == "idle": player.update_idle()

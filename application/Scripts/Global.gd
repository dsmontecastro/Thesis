extends Node

# Game Constants
const MAX_PLAYER: int = 4
const NUM_FACES : int = 15

# Steam Variables
var IS_ONLINE: bool = false
var IS_OWNED:  bool = false
var STEAM_ID:  int  = 0
var STEAM_USERNAME: String = ""

# Lobby Variables
var  IS_HOST: bool = false
var  HOST_ID: int = 0
var LOBBY_ID: int = 0
var    LOBBY = {}
var OPPONENT = { id = 0, name = "" }

#-----------------------------------------------------------------------------#

func _process(_delta):
	Steam.run_callbacks()

func _ready():

	# Steam Initializer
	var INIT: Dictionary = Steam.steamInit()
	if (INIT['status'] != 1) : get_tree().quit()
	IS_ONLINE = Steam.loggedOn()
	IS_OWNED  = Steam.isSubscribed()
	STEAM_ID  = Steam.getSteamID()
	STEAM_USERNAME = Steam.getPersonaName()
	if (IS_OWNED == false) : get_tree().quit()

	# Global Preloader
	load_faces()

#-----------------------------------------------------------------------------#

var FACES = []

# FACE PRELOADING #
func load_faces():
	for idx in range(NUM_FACES):
		var path = "res://assets/Faces/" + str(idx) + ".png"
		FACES.append(load(path))

#-----------------------------------------------------------------------------#

func reset():

	# Steam-side
	Steam.leaveLobby(LOBBY_ID)
	Steam.stopVoiceRecording()
	for member in LOBBY:
		var target  = LOBBY[member].id
		if (target != STEAM_ID):
			Steam.closeP2PSessionWithUser(target)

	# User-side
	LOBBY_ID = 0
	HOST_ID  = 0
	IS_HOST  = false
	LOBBY.clear()

#-----------------------------------------------------------------------------#

# NETWORKING #

# Creates Packet Dictionary with Default Values
func createPacket():
	return { "src": STEAM_ID, "msg": "Start", "inf": null }

func broadcastPacket(packet):
	var DATA: PoolByteArray
	DATA.append(256)
	DATA.append_array(var2bytes(packet))
	for member in LOBBY:
		var target = LOBBY[member].id
		if (target != STEAM_ID):
			Steam.sendP2PPacket(target, DATA, 2, 0)

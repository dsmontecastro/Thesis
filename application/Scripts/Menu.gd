extends Control

const KEY = "[198]"
var lobbyButtonScene = preload("res://Scenes/LobbyButton.tscn")
var playerInfoScene  = preload("res://Scenes/PlayerInfo.tscn")

# MAIN MENU  #
onready var main = $Main

# LOBBY MENU #
onready var lobby      = $Lobby
onready var lobbyTitle = $Lobby/Panels/NamePanel/LobbyTitle
onready var start      = $Lobby/Panels/Buttons/StartGame
onready var playerList = $Lobby/Panels/PlayerPanel/Players

# LOBBY LIST MENU #
onready var lobbyList = $LobbyList
onready var lobbyListContainer = $LobbyList/Panels/ScrollList/Lobbies

#-----------------------------------------------------------------------------#

func _ready():
	Steam.connect("lobby_created", self, "_on_Lobby_Created")
	Steam.connect("lobby_match_list", self, "_on_Lobby_Match_List")
	Steam.connect("lobby_joined", self, "_on_Lobby_Joined")
	Steam.connect("join_requested", self, "_on_Lobby_Join_Requested")
	Steam.connect("lobby_chat_update", self, "_on_Lobby_Chat_Update")
	Steam.connect("p2p_session_request", self, "_on_P2P_Session_Request")
	Steam.connect("p2p_session_connect_fail", self, "_on_P2P_Session_Connect_Fail")

#-----------------------------------------------------------------------------#

func setMenu(menu):
	match menu:
		"main":
			main.visible = true
			lobby.visible = false
			lobbyList.visible = false
		"lobby":
			main.visible = false
			lobby.visible = true
			lobbyList.visible = false
			if (Global.IS_HOST) : start.visible = true
			else : start.visible = false
		"lobbyList":
			main.visible = false
			lobby.visible = false
			lobbyList.visible = true

#-----------------------------------------------------------------------------#

# BUTTONS CALLBACKS #

# MAIN MENU  #
func _on_CreateLobby_pressed():
	Global.IS_HOST = true
	if (Global.LOBBY_ID == 0):
		Steam.createLobby(2, Global.MAX_PLAYER) # Lobby type : Public
	setMenu("lobby")

func _on_FindLobby_pressed():
	clearNodes(lobbyListContainer.get_children())
	Steam.addRequestLobbyListDistanceFilter(3) # Distance to search : Worldwide
	Steam.addRequestLobbyListStringFilter("name", KEY, 2)
	Steam.requestLobbyList()
	setMenu("lobbyList")

func _on_Quit_pressed():
	get_tree().quit()


# LOBBY MENU #
func _on_LeaveLobby_pressed():
	Global.reset()
	setMenu("main")

func _on_StartGame_pressed():
	broadcast()
	Steam.setLobbyJoinable(Global.LOBBY_ID, false)
	get_tree().change_scene("res://Scenes/Game.tscn")


# LOBBY LIST MENU #
func _on_Back_pressed():
	setMenu("main")

func _on_Refresh_pressed():
	_on_FindLobby_pressed()

func _on_Join_Lobby_Pressed(lobbyID: int):
	Steam.joinLobby(lobbyID)
	setMenu("lobby")

#-----------------------------------------------------------------------------#

# STEAM CALLBACKS #

# Creating the Lobby
func _on_Lobby_Created(connect: int, lobbyID: int) -> void:
	if (connect == 1):
		var lobby = KEY + " " + str(Global.STEAM_USERNAME) + "'s Lobby"
		var host  = { id = Global.STEAM_ID, name = Global.STEAM_USERNAME }

		# Steam-side
		Steam.setLobbyData(lobbyID, "name", lobby)				# Set lobby name
		Steam.setLobbyJoinable(Global.LOBBY_ID, true)			# Open lobby

		# User-side
		Global.LOBBY[0] = host									# Set self as Host
		Global.LOBBY_ID = lobbyID								# Set the lobby ID
		lobbyTitle.text = Steam.getLobbyData(lobbyID, "name")	# Set lobby name


# Joining the Lobby
func _on_Lobby_Match_List(lobbies: Array) -> void:
	for lobbyID in lobbies:								# For each Lobby found:
		var lobbyName = str(Steam.getLobbyData(lobbyID, "name"))
		var lobbyBttn = lobbyButtonScene.instance()		# Create a Button for the Lobby
		lobbyBttn.set_name("lobby_" + str(lobbyID))
		lobbyBttn.set_text(lobbyName)
		lobbyBttn.connect("pressed", self, "_on_Join_Lobby_Pressed", [lobbyID])
		lobbyListContainer.add_child(lobbyBttn)			# Add the new Lobby to the LobbyList

func _on_Lobby_Joined(lobbyID: int, _permissions: int, _locked: bool, _response: int) -> void:
	lobbyTitle.text = str(Steam.getLobbyData(lobbyID, "name"))
	Global.HOST_ID  = Steam.getLobbyOwner(lobbyID)
	Global.LOBBY_ID = lobbyID
	update_lobby()

func _on_Lobby_Join_Requested(lobbyID: int, _friendID: int) -> void:
	_on_Join_Lobby_Pressed(lobbyID)


# Updating the Lobby (Player Joins/Leaves)
func _on_Lobby_Chat_Update(_lobbyID: int, _changedID: int, _makingChangeID: int, _chatState: int) -> void:
	update_lobby()

#-----------------------------------------------------------------------------#

# AUXILIARY FUCTIONS #

func clearNodes(nodes):
	for node in nodes: node.queue_free()

func update_lobby():

	# Clear previous Global settings
	Global.LOBBY.clear()
	var lobbyID : int = Global.LOBBY_ID
	var members : int = Steam.getNumLobbyMembers(lobbyID)
	var players = playerList.get_children()
	clearNodes(players)

	# Remake Global LOBBY
	for member in range(0, members):

		# Get Member data from Steam Lobby
		var pID = Steam.getLobbyMemberByIndex(lobbyID, member)
		var tmp = { id = pID, name = Steam.getFriendPersonaName(pID) }

		# Set Member data for Global LOBBY
		var playerInfo  = playerInfoScene.instance()
		playerInfo.text = tmp.name
		playerList.add_child(playerInfo)
		Global.LOBBY[member] = tmp

#-----------------------------------------------------------------------------#

func _on_P2P_Session_Request(remoteID: int) -> void:
	Steam.acceptP2PSessionWithUser(remoteID)

func _on_P2P_Session_Connect_Fail(lobbyID: int, session_error: int) -> void:
	var msg =  "WARNING: Session failure with " + str(lobbyID) + " "
	if   session_error == 0: msg += "[no error given]."
	elif session_error == 1: msg += "[target user not running the same game]."
	elif session_error == 2: msg += "[local user doesn't own app / game]."
	elif session_error == 3: msg += "[target user isn't connected to Steam]."
	elif session_error == 4: msg += "[connection timed out]."
	elif session_error == 5: msg += "[unused]."
	else: msg += "[unknown error " + str(session_error) + "]."
	print_debug(msg)

#-----------------------------------------------------------------------------#

# NETWORKING #

func _process(_delta):
	if (lobby.visible == true):
		var PACKET = Steam.getAvailableP2PPacketSize(0)
		for pack in PACKET: readPacket()

func broadcast() -> void:
	var packet_data = Global.createPacket()
	Global.broadcastPacket(packet_data)

func readPacket() -> void:
	var PACKET_SIZE: int = Steam.getAvailableP2PPacketSize(0)
	if (PACKET_SIZE > 0):  # There is a Packet
		var PACKET  : Dictionary = Steam.readP2PPacket(PACKET_SIZE, 0)
		var READABLE: Dictionary = bytes2var(PACKET.data.subarray(1, PACKET_SIZE - 1))
		if (READABLE["msg"] == "Start"):get_tree().change_scene("res://Scenes/Game.tscn")

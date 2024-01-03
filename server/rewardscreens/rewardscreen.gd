extends Node

onready var lobby := Lobby.get_lobby(self)

var time := 0.0
var accepted := {}
var needed_oks := -1

func _ready():
	match lobby.minigame_summary.state.minigame_type:
		Lobby.MINIGAME_TYPES.GNU_SOLO, Lobby.MINIGAME_TYPES.NOLOK_SOLO:
			needed_oks = 1
		Lobby.MINIGAME_TYPES.DUEL:
			needed_oks = 2
		Lobby.MINIGAME_TYPES.FREE_FOR_ALL, Lobby.MINIGAME_TYPES.GNU_COOP, \
		Lobby.MINIGAME_TYPES.NOLOK_COOP, Lobby.MINIGAME_TYPES.ONE_VS_THREE, \
		Lobby.MINIGAME_TYPES.TWO_VS_TWO:
			needed_oks = 4
		_:
			assert(false, "Missing minigame type")

func _server_process(delta):
	time += delta
	for info in lobby.player_info:
		if info and info.is_ai() and time >= 5 + 0.1 * info.player_id:
			_accept_internal(info.player_id)
		if lobby.timeout >= 0 and time >= lobby.timeout:
			_accept_internal(info.player_id)

master func accept(player_id: int):
	var info := lobby.get_player_by_id(player_id)
	if info.addr.peer_id != multiplayer.get_rpc_sender_id():
		return
	_accept_internal(player_id)

func _accept_internal(player_id):
	if player_id in accepted:
		return
	accepted[player_id] = true
	# We don't want to continue before the cookie adding animation has finished
	# However we still want the players be able to press ready before that
	# Therefore we wait until there've been 6 seconds elapsed in the reward screen
	var delay := 6.0 - time
	get_tree().create_timer(delay).connect("timeout", self, "player_accepted")
	lobby.broadcast(self, "client_accepted", [player_id])

func player_accepted():
	needed_oks -= 1
	if needed_oks == 0:
		get_tree().create_timer(0.5).connect("timeout", lobby, "_goto_scene_board")

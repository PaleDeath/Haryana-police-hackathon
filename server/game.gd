extends Node

func _ready():
	multiplayer.connect("network_peer_disconnected", self, "_on_peer_disconnected")
	get_tree().connect("node_added", self, "_on_node_added")
	multiplayer.set_root_node(self)

func _process(delta: float) -> void:
	# We have to poll the custom multiplayer ourselves
	# The scene tree will only handle the global multiplayer!
	# This will only be set for local singleplayer
	if self.custom_multiplayer:
		self.custom_multiplayer.poll()
	# Run the server main loop
	self.propagate_call("_server_process", [delta])

func _on_node_added(node: Node):
	# Enable our local multiplayer for all nodes that are added on
	# the (local) server
	if is_a_parent_of(node):
		node.custom_multiplayer = custom_multiplayer
		# Hack to disable audio playback in the server scene tree
		# I don't know of a better way to do this :(
		if (node is AudioStreamPlayer) or (node is AudioStreamPlayer2D) or \
				(node is AudioStreamPlayer3D):
			node.stream = null
			node.queue_free()

master func get_version():
	rpc_id(multiplayer.get_rpc_sender_id(), "version_callback",
			Global.PROTOCOL_VERSION, Global.VERSION_STRING)

master func get_public_lobbies():
	var lobbies := []
	for child in get_children():
		if child.is_public():
			lobbies.append([child.name, child.current_board])
	rpc_id(multiplayer.get_rpc_sender_id(), "public_lobbies_callback", lobbies)

master func create_lobby():
	var peer := multiplayer.get_rpc_sender_id()
	var name: String
	for _i in range(5):
		name = Marshalls.raw_to_base64(Crypto.new().generate_random_bytes(6))
		if not has_node(name):
			break
	if not name:
		rpc_id(peer, "lobby_creation_failed")
		return
	var lobby: Lobby = preload("res://server/lobby.tscn").instance()
	lobby.name = name
	add_child(lobby)
	if not lobby.join(Lobby.PlayerAddress.new(peer, 0)):
		# It should not fail to join an empty lobby
		lobby.delete()
		rpc_id(peer, "lobby_creation_failed")
		return
	rpc_id(peer, "lobby_created", name)
	lobby.update_playerlist()
	lobby.send_settings(peer)
	lobby.send_board(peer)

master func join_lobby(name: String):
	var peer = multiplayer.get_rpc_sender_id()
	# Prevent tree traversal
	if "." in name or "/" in name:
		return false
	var lobby = get_node_or_null(name)
	if not lobby:
		rpc_id(peer, "lobby_join_failed")
		return
	if not lobby.join(Lobby.PlayerAddress.new(peer, 0)):
		rpc_id(peer, "lobby_join_failed")
		return
	rpc_id(peer, "lobby_joined")
	lobby.update_playerlist()
	lobby.send_settings(peer)
	lobby.send_board(peer)

func _on_peer_disconnected(id: int):
	for child in get_children():
		child.leave(id)

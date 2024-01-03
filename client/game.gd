extends Node

signal create_lobby_callback(name)
signal join_lobby_callback(success)
signal public_lobbies(list)
signal version(prot, name)

var current_lobby

func _ready():
	multiplayer.set_root_node(self)
	multiplayer.connect("server_disconnected", self, "_on_connection_lost")

func _on_connection_lost():
	current_lobby = null
	var scene := get_tree().current_scene
	if not scene or scene.filename != "res://client/menus/main_menu.tscn":
		get_tree().change_scene("res://client/menus/main_menu.tscn")
	Global.shutdown_connection()

func _process(delta: float):
	# Run the client main loop
	self.propagate_call("_client_process", [delta])

func create_lobby() -> Node:
	rpc_id(1, "create_lobby")
	var name = yield(self, "create_lobby_callback")
	if not name:
		return null
	var lobby = preload("res://client/lobby.tscn").instance()
	lobby.name = name
	add_child(lobby)
	current_lobby = lobby
	return lobby

func join_lobby(name: String) -> Node:
	var lobby = preload("res://client/lobby.tscn").instance()
	lobby.name = name
	add_child(lobby)
	rpc_id(1, "join_lobby", name)
	if not yield(self, "join_lobby_callback"):
		lobby.free()
		return null
	current_lobby = lobby
	return lobby

func update_lobbies():
	rpc_id(1, "get_public_lobbies")

func get_version():
	rpc_id(1, "get_version")
	var timer = get_tree().create_timer(3)
	timer.connect("timeout", self, "_on_version_timeout")
	var res = yield(self, "version")
	timer.disconnect("timeout", self, "_on_version_timeout")
	return res

func _on_version_timeout():
	emit_signal("version", null)

puppet func public_lobbies_callback(list: Array):
	emit_signal("public_lobbies", list)

puppet func lobby_creation_failed():
	emit_signal("create_lobby_callback", null)

puppet func lobby_created(name: String):
	emit_signal("create_lobby_callback", name)

puppet func lobby_join_failed():
	emit_signal("join_lobby_callback", false)

puppet func lobby_joined():
	emit_signal("join_lobby_callback", true)

puppet func version_callback(id: int, name: String):
	emit_signal("version", id, name)

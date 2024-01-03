extends Control

var lobby_menu
var server
var mainmenu

func _ready():
	server.connect("public_lobbies", self, "_on_public_lobbies_updated")
	$VBoxContainer/Footer/Create.grab_focus()
	refresh()
	
	if server.current_lobby:
		lobby_joined(server.current_lobby)
		server.current_lobby.refresh()

func refresh() -> void:
	if is_instance_valid(server):
		server.update_lobbies()
	else:
		mainmenu.get_node("MainMenu").show()
		if lobby_menu:
			lobby_menu.queue_free()
		queue_free()

func _on_public_lobbies_updated(list):
	for child in $VBoxContainer/ScrollContainer/List.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	for entry in list:
		var button := Button.new()
		button.text = entry[0]
		button.connect("pressed", self, "_on_join_lobby", [entry[0]])
		$VBoxContainer/ScrollContainer/List.add_child(button)

func _on_join_lobby(id: String) -> void:
	var lobby = yield(server.join_lobby(id), "completed")
	lobby_joined(lobby)

func lobby_joined(lobby: Lobby):
	lobby_menu = preload("res://client/menus/lobby/lobby_menu.tscn").instance()
	lobby_menu.lobby = lobby
	lobby_menu.mainmenu = mainmenu
	lobby_menu.servermenu = self
	get_parent().add_child(lobby_menu)
	hide()

func _on_lobby_create() -> void:
	var lobby = yield(server.create_lobby(), "completed")
	if lobby:
		lobby_menu = preload("res://client/menus/lobby/lobby_menu.tscn").instance()
		lobby_menu.lobby = lobby
		lobby_menu.mainmenu = mainmenu
		lobby_menu.servermenu = self
		get_parent().add_child(lobby_menu)
		hide()

func _on_Leave_pressed() -> void:
	mainmenu.get_node("MainMenu").show()
	queue_free()

func _on_Join_pressed() -> void:
	var lobby = yield(server.join_lobby($VBoxContainer/Footer/HBoxContainer/LineEdit.text), "completed")
	if lobby:
		lobby_menu = preload("res://client/menus/lobby/lobby_menu.tscn").instance()
		lobby_menu.lobby = lobby
		lobby_menu.mainmenu = mainmenu
		lobby_menu.servermenu = self
		get_parent().add_child(lobby_menu)
		hide()

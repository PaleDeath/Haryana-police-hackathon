extends Node

var lobby: Lobby

var mainmenu
var servermenu

func _ready():
	lobby.set_current_scene(mainmenu)
	lobby.connect("board_selected", self, "_on_board_selected")
	lobby.connect("player_info_updated", self, "_on_player_info_updated")
	lobby.connect("settings_changed", self, "_on_settings_changed")
	$MarginContainer/VBoxContainer/Content/VBoxContainer/Board.disabled = true
	$MarginContainer/VBoxContainer/Footer/Start.disabled = true
	$MarginContainer/VBoxContainer/Footer/HBoxContainer/Lobby.text = "Join code: " + lobby.name
	
	for board in PluginSystem.board_loader.get_loaded_boards():
		var boards := $MarginContainer/VBoxContainer/Content/VBoxContainer/Board
		boards.add_item(board)
		boards.set_item_metadata(boards.get_item_count() - 1, board)
	$MarginContainer/VBoxContainer/Footer/Start.grab_focus()

func _on_settings_changed(settings: Array):
	var root := $MarginContainer/VBoxContainer/Content/ScrollContainer/Sidebar
	for child in root.get_children():
		child.queue_free()
		root.remove_child(child)
	var label := Label.new()
	label.text = "MENU_LOBBY_SETTINGS"
	label.align = Label.ALIGN_CENTER
	root.add_child(label)
	for entry in settings:
		var id = entry[0]
		var setting = entry[1]
		match setting.type:
			Lobby.Settings.TYPE_BOOL:
				var checkbox := CheckButton.new()
				checkbox.text = setting.name
				checkbox.pressed = setting.value
				checkbox.disabled = not lobby.is_lobby_owner(multiplayer.get_network_unique_id())
				checkbox.connect("toggled", self, "_on_change_setting", [id])
				root.add_child(checkbox)
			Lobby.Settings.TYPE_INT:
				var container := HBoxContainer.new()
				var option_label := Label.new()
				var slider := SpinBox.new()
				slider.min_value = setting.value[1]
				slider.max_value = setting.value[2]
				slider.value = setting.value[0]
				slider.editable = lobby.is_lobby_owner(multiplayer.get_network_unique_id())
				option_label.text = setting.name
				option_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				slider.connect("value_changed", self, "_on_setting_slider_change", [id])
				container.add_child(option_label)
				container.add_child(slider)
				root.add_child(container)
			Lobby.Settings.TYPE_OPTIONS:
				var container := HBoxContainer.new()
				var option_label := Label.new()
				var optionbutton := OptionButton.new()
				for option in setting.value[1]:
					optionbutton.add_item(option)
				optionbutton.select(setting.value[1].find(setting.value[0]))
				optionbutton.disabled = not lobby.is_lobby_owner(multiplayer.get_network_unique_id())
				option_label.text = setting.name
				option_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				optionbutton.connect("item_selected", self, "_on_setting_option_change", [optionbutton, id])
				container.add_child(option_label)
				container.add_child(optionbutton)
				root.add_child(container)

func _on_change_setting(value, id: String):
	lobby.update_setting(id, value)

func _on_setting_slider_change(value: float, id: String):
	lobby.update_setting(id, int(value))

func _on_setting_option_change(idx: int, node: OptionButton, id: String):
	lobby.update_setting(id, node.get_item_text(idx))

func _on_board_selected(board: String):
	$MarginContainer/VBoxContainer/Content/VBoxContainer/Board.text = board

func _on_player_info_updated(info: Array):
	var owner: bool = lobby.is_lobby_owner(multiplayer.get_network_unique_id())
	$MarginContainer/VBoxContainer/Content/VBoxContainer/Board.disabled = not owner
	$MarginContainer/VBoxContainer/Footer/Start.disabled = not owner
	
	var characters = $MarginContainer/VBoxContainer/Content/VBoxContainer/Characters
	for child in characters.get_children():
		child.queue_free()
		characters.remove_child(child)
	
	var remaining_player_indices = range(4)
	for playerinfo in info:
		if playerinfo.addr.peer_id == multiplayer.get_network_unique_id():
			remaining_player_indices.erase(playerinfo.addr.idx)
		var player = preload("res://client/menus/lobby/lobby_player.tscn").instance()
		var name: LineEdit = player.get_node("PanelContainer/HBoxContainer/Name")
		var character: Button = player.get_node("PanelContainer/HBoxContainer/Character")
		var remove: Button = player.get_node("PanelContainer/HBoxContainer/Remove")
		name.text = playerinfo.name
		name.connect("text_entered", self, "_on_name_changed", [playerinfo.addr.idx])
		if playerinfo.character:
			character.icon = PluginSystem.character_loader.load_character_icon(playerinfo.character)
		character.connect("pressed", self, "_on_character_select", [playerinfo.addr])
		remove.connect("pressed", self, "_on_remove_player", [playerinfo.addr.idx])
		if playerinfo.addr.peer_id != multiplayer.get_network_unique_id():
			name.editable = false
			character.disabled = true
			remove.disabled = true
		characters.add_child(player)

	while characters.get_child_count() < lobby.LOBBY_SIZE:
		var placeholder = preload("res://client/menus/lobby/player_join_placeholder.tscn").instance()
		placeholder.available = remaining_player_indices
		placeholder.connect("add_player", self, "_on_add_player")
		characters.add_child(placeholder)

func _on_add_player(idx: int):
	lobby.add_player(idx)

func _on_remove_player(idx: int):
	lobby.remove_player(idx)

func _on_name_changed(name: String, idx: int):
	lobby.set_player_name(idx, name)

func _on_character_select(addr):
	$CharacterMenu.connect("character_selected", self, "_on_CharacterMenu_character_selected", [addr.idx], CONNECT_ONESHOT)
	$CharacterMenu.select_character(lobby.get_player_by_addr(addr).character)

func _on_CharacterMenu_character_selected(character: String, idx: int) -> void:
	lobby.select_character(idx, character)

func _on_Board_item_selected(index: int) -> void:
	lobby.select_board($MarginContainer/VBoxContainer/Content/VBoxContainer/Board.get_item_metadata(index))

func _on_Leave_pressed() -> void:
	queue_free()
	if servermenu:
		servermenu.show()
		servermenu.refresh()
	else:
		Global.destroy_local_server()
		mainmenu.get_node("MainMenu").show()

func _on_Start_pressed() -> void:
	lobby.start()

func _on_lobby_code_copy() -> void:
	OS.clipboard = lobby.name

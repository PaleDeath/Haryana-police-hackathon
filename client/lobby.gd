extends Lobby

signal player_info_updated(player_info)
signal settings_changed(settings)
signal board_selected(board)
signal game_start
signal savegame_saved

const MINIGAME_TEAM_COLORS = [Color(1, 0, 0), Color(0, 0, 1)]

const MINIGAME_REWARD_SCREEN_FFA =\
		preload("res://client/rewardscreens/ffa/ffa.tscn")
const MINIGAME_REWARD_SCREEN_DUEL =\
		preload("res://client/rewardscreens/duel/duel.tscn")
const MINIGAME_REWARD_SCREEN_1V3 =\
		preload("res://client/rewardscreens/1v3/1v3.tscn")
const MINIGAME_REWARD_SCREEN_2V2 =\
		preload("res://client/rewardscreens/2v2/2v2.tscn")
const MINIGAME_REWARD_SCREEN_NOLOK_SOLO =\
		preload("res://client/rewardscreens/nolok_solo/nolok_solo.tscn")
const MINIGAME_REWARD_SCREEN_NOLOK_COOP =\
		preload("res://client/rewardscreens/nolok_coop/nolok_coop.tscn")
const MINIGAME_REWARD_SCREEN_GNU_SOLO =\
		preload("res://client/rewardscreens/gnu_solo/gnu_solo.tscn")
const MINIGAME_REWARD_SCREEN_GNU_COOP =\
		preload("res://client/rewardscreens/gnu_coop/gnu_coop.tscn")

var _board_loaded_translations := []
var _minigame_loaded_translations := []

var started := false

var current_savegame := SaveGameLoader.SaveGame.new()
var savegame_name := ""
var is_new_savegame := true

func leave():
	get_tree().change_scene("res://client/menus/main_menu.tscn")
	Global.shutdown_connection()

puppet func game_start():
	started = true
	assign_player_ids()
	emit_signal("game_start")
	load_board()

puppet func board_selected(board: String):
	if not board in PluginSystem.board_loader.get_loaded_boards():
		push_error("Unknown board: " + board)
		leave()
		return
	self.current_board = PluginSystem.board_loader.get_board_path(board)
	
	emit_signal("board_selected", board)

puppet func replace_by_ai(player_id: int, new_addr: Array):
	# This does only make sense when the game has already started
	if not started:
		return
	var addr = PlayerAddress.decode(new_addr)
	for player in player_info:
		if player.player_id == player_id:
			player.addr = addr

puppet func lobby_joined(playerlist: Array):
	if started:
		return
	var decoded := []
	for player in playerlist:
		var obj = PlayerInfo.decode(self, player)
		var valid: bool = obj.character == "" or obj.character in PluginSystem.character_loader.get_loaded_characters()
		if not valid:
			push_error("Unknown character: " + obj.character)
			leave()
			return
		decoded.append(obj)
	self.player_info = decoded
	emit_signal("player_info_updated", self.player_info)

puppet func update_settings(settings: Array):
	var decoded := []
	for entry in settings:
		var obj := Lobby.Settings.decode(entry[1])
		if not obj:
			push_error("Invalid settings received: " + str(entry))
			leave()
			return
		decoded.append([entry[0], obj])
	emit_signal("settings_changed", decoded)

puppet func playerstate_updated(playerstates: Array):
	var decoded := []
	for player in playerstates:
		var obj = PlayerState.decode(self, player)
		decoded.append(obj)
	self.playerstates = decoded

puppet func add_player_failed():
	# TODO: error reporting
	pass

func update_setting(id: String, value):
	rpc_id(1, "update_setting", id, value)

func add_player(idx: int):
	rpc_id(1, "add_player", idx)

func remove_player(idx: int):
	rpc_id(1, "remove_player", idx)

func start():
	rpc_id(1, "start")

func end():
	playerstates = []
	current_scene.queue_free()
	current_scene = null
	get_tree().change_scene_to(load("res://client/menus/main_menu.tscn"))

func refresh():
	rpc_id(1, "refresh")

func select_board(board: String):
	rpc_id(1, "select_board", board)

func select_character(idx: int, character: String):
	rpc_id(1, "select_character", idx, character)

func set_player_name(idx: int, name: String):
	rpc_id(1, "set_player_name", idx, name)

func _input(event: InputEvent) -> void:
	# Convert local input events to their respective player_id
	# Why is this necessary?
	# Local coop looks like this:
	# Player1(Peer(net_id, 0)), Player2(Peer(net_id, 1)), ...
	# The players input is named "player1_{action}" to "player4_{action}"
	# A lot of code uses this system to handle player inputs
	# In online multiplayer however, the players are sitting on multiple devices
	# Player3 may be the only player on their device and would want to use the input mappings
	# of Player1 (they are the first player on their machine after all)
	# In order to not break stuff, we have to convert these input events from the local player index to the (global) player_id
	
	# If this event is generated by the game, we do not need to convert it
	# This prevents an endless loop arising from event conversion and generated events are already consistent with the player_id naming
	# InputEventAction cannot be naturally generated by user input!
	if event is InputEventAction:
		return
	
	# If we're not in the game already, remapping makes no sense
	if not started:
		return
	var actions = ["up", "down", "left", "right", "action1", "action2", "action3", "action4", "ok", "pause"]
	for player in player_info:
		if player.is_local():
			for action in actions:
				var action_source := "player{id}_{action}".format({"id": player.addr.idx + 1, "action": action})
				if event.is_action(action_source):
					# Now build an InputEventAction with
					var converted := InputEventAction.new()
					converted.action = "player{id}_{action}".format({"id": player.player_id, "action": action})
					converted.pressed = event.is_pressed()
					converted.strength = event.get_action_strength(action_source)
					get_tree().set_input_as_handled()
					get_tree().input_event(converted)
					# Do not break/return here as an optimization!
					# There may be multiple events mapped to the same key

# ----- Scene changing code ----- #

# Internal function for actually changing scene without saving any game state.
func _goto_scene(path: String, wait=true) -> void:
	_interactive_load_scene(path, null, "", null, wait)

func _goto_scene_board():
	_interactive_load_scene(current_board, self, "_goto_scene_board_callback", null)

func _goto_scene_board_callback(scene: Node, _arg):
	for t in _minigame_loaded_translations:
		TranslationServer.remove_translation(t)
	_minigame_loaded_translations.clear()

	for i in range(len(player_info)):
		var player = scene.get_node("Player" + str(i + 1))
		_load_player(player, player_info[i])

# Internal function for changing scene to a minigame while handling player objects.
func _goto_scene_minigame(path: String, minigame_state) -> void:
	_interactive_load_scene(path, self, "_goto_scene_minigame_callback", minigame_state)

func _goto_scene_minigame_callback(scene: Node, minigame_state):
	scene.add_child(preload("res://client/menus/pause_menu.tscn").instance())

	var i := 1
	for team_id in range(len(minigame_state.minigame_teams)):
		var team = minigame_state.minigame_teams[team_id]
		for player_id in team:
			var player = scene.get_node("Player" + str(i))
			_load_player(player, player_info[player_id - 1])
			if minigame_state.minigame_type == MINIGAME_TYPES.TWO_VS_TWO:
				_load_team_indicator(player, player_info[player_id - 1], team_id)

			i += 1

	# Remove unnecessary players.
	while i <= get_player_count():
		var player = scene.get_node_or_null("Player" + str(i))
		if player:
			scene.remove_child(player)
			player.queue_free()
		i += 1

func _load_team_indicator(player: Node, info: PlayerInfo, team: int):
	if not player.has_node("Model"):
		# We do not have a character model loaded, maybe this minigame is not 3D?
		# Subsequently, we do not need to add a team indicator
		return
	# Loading the character here again shouldn't do any actual loading. It should already be cached
	var model: Spatial = PluginSystem.character_loader.load_character(info.character)
	var shape: CollisionShape = model.get_node_or_null(model.collision_shape)
	if shape:
		# global_transform only works when the node is in the scene tree
		# Therefore, we have to compute it ourselves
		var transform := shape.transform
		var parent := shape.get_parent()
		while parent != null:
			if parent is Spatial:
				transform = parent.transform * transform
			parent = parent.get_parent()
		var bbox := Utility.get_aabb_from_shape(shape.shape, transform)
		var indicator: Sprite3D = preload(\
				"res://client/team_indicator/team_indicator.tscn"\
				).instance()
		indicator.modulate = MINIGAME_TEAM_COLORS[team]
		indicator.translation.y = bbox.size.y / 2 + shape.translation.y + 0.1
		player.get_node("Model").add_child(indicator)

func load_board():
	var dir = Directory.new()
	dir.open(current_board.get_base_dir() + "/translations")
	dir.list_dir_begin(true)
	while true:
		var file_name = dir.get_next()
		if file_name == "":
			break

		if file_name.ends_with(".translation") or file_name.ends_with(".po"):
			_load_interactive(dir.get_current_dir() + "/" + file_name, self, "_install_translation_board", file_name)

	dir.list_dir_end()

func goto_minigame(is_try: bool):
	rpc_id(1, "_goto_minigame", is_try)

puppet func return_to_board():
	_goto_scene_board()

puppet func game_ended():
	_goto_scene("res://client/menus/victory_screen/victory_screen.tscn", false)
	started = false

puppet func load_minigame():
	_goto_scene_minigame(self.minigame_state.minigame_config.scene_path, self.minigame_state)

puppet func minigame_ended(was_try: bool, placement, reward):
	if not minigame_state:
		return
	if was_try:
		_goto_scene_board()
		return
	minigame_summary = MinigameSummary.new()
	minigame_summary.state = minigame_state
	minigame_summary.placement = placement
	minigame_summary.reward = reward
	minigame_state = null
	match minigame_summary.state.minigame_type:
		MINIGAME_TYPES.FREE_FOR_ALL:
			call_deferred("_goto_scene_instant", MINIGAME_REWARD_SCREEN_FFA)
		MINIGAME_TYPES.TWO_VS_TWO:
			call_deferred("_goto_scene_instant", MINIGAME_REWARD_SCREEN_2V2)
		MINIGAME_TYPES.ONE_VS_THREE:
			call_deferred("_goto_scene_instant", MINIGAME_REWARD_SCREEN_1V3)
		MINIGAME_TYPES.DUEL:
			call_deferred("_goto_scene_instant", MINIGAME_REWARD_SCREEN_DUEL)
		MINIGAME_TYPES.NOLOK_SOLO:
			call_deferred("_goto_scene_instant", MINIGAME_REWARD_SCREEN_NOLOK_SOLO)
		MINIGAME_TYPES.NOLOK_COOP:
			call_deferred("_goto_scene_instant", MINIGAME_REWARD_SCREEN_NOLOK_COOP)
		MINIGAME_TYPES.GNU_SOLO:
			call_deferred("_goto_scene_instant", MINIGAME_REWARD_SCREEN_GNU_SOLO)
		MINIGAME_TYPES.GNU_COOP:
			call_deferred("_goto_scene_instant", MINIGAME_REWARD_SCREEN_GNU_COOP)

func _install_translation_board(translation, file_name: String):
	if not translation is Translation:
		push_warning("Error: file " + file_name + " is not a valid translation")
		return

	TranslationServer.add_translation(translation)
	_board_loaded_translations.push_back(translation)

func load_minigame_translations(minigame_config: MinigameLoader.MinigameConfigFile) -> void:
	var dir := Directory.new()
	dir.open(minigame_config.translation_directory)
	dir.list_dir_begin(true)
	while true:
		var file_name: String = dir.get_next()
		if file_name == "":
			break

		if file_name.ends_with(".translation") or file_name.ends_with(".po"):
			_install_translation_minigame(load(dir.get_current_dir() + "/" + file_name), file_name)

	dir.list_dir_end()

func _install_translation_minigame(translation, file_name: String):
	if not translation is Translation:
		push_warning("Error: file " + file_name + " is not a valid translation")
		return

	TranslationServer.add_translation(translation)
	_minigame_loaded_translations.push_back(translation)

const LOADING_SCREEN = preload("res://client/menus/loading_screen.tscn")
func _interactive_load_scene(path: String, base: Object, method: String, arg, wait := true):
	if current_scene:
		current_scene.queue_free()
	current_scene = LOADING_SCREEN.instance()
	add_child(current_scene)
	if wait:
		connect("loading_finished", self, "rpc_id", [1, "client_ready"], CONNECT_ONESHOT)
	else:
		connect("loading_finished", self, "loading_finished", [], CONNECT_ONESHOT)
	_load_interactive(path, self, "_scene_loaded", [base, method, arg])

puppet func loading_finished():
	if _objects_to_load == 0:
		change_scene()
	else:
		# Server is misbehaving
		leave()

func _scene_loaded(s: PackedScene, arg: Array):
	loaded_scene = s.instance()

	if arg[0]:
		arg[0].call(arg[1], loaded_scene, arg[2])

# ----- Save game code ----- #

func load_savegame(name: String, savegame: SaveGameLoader.SaveGame):
	is_new_savegame = false
	current_savegame = savegame
	savegame_name = name
	rpc_id(1, "load_savegame", savegame.serialize())

var sent_savegame_request := false

puppet func save_game_callback(data: Dictionary, error: String):
	if error:
		push_warning(error)
		Global.show_error(error)
	elif sent_savegame_request:
		current_savegame = SaveGameLoader.SaveGame.from_data(data)
		
		Global.savegame_loader.save(savegame_name, current_savegame)
		emit_signal("savegame_saved")
		sent_savegame_request = false

func save_game() -> void:
	sent_savegame_request = true
	rpc_id(1, "save_game")
extends CenterContainer

const USER_OPTIONS_FILE = "user://options.cfg"

var _options_file = ConfigFile.new()
var _is_loading_options = false

#warning-ignore:unused_signal
signal quit

func _ready():
	# Populate with toggled translations in 'Project Settings > Localization > Locales Filter'.
	var languages = ProjectSettings.get("locale/locale_filter")[1]
	var language_control = $Menu/TabContainer/Visual/Language/OptionButton
	for i in languages.size():
		language_control.add_item(
				TranslationServer.get_locale_name(languages[i]), i + 1)
		language_control.set_item_metadata(i + 1, languages[i])
	
	load_options()

func _input(event):
	if get_focus_owner() and $Menu/TabContainer.is_a_parent_of(get_focus_owner()):
		if event.is_action_pressed("ui_focus_prev"):
			$Menu/TabContainer.current_tab = ($Menu/TabContainer.current_tab + $Menu/TabContainer.get_tab_count() - 1) % $Menu/TabContainer.get_tab_count()
			$Menu/TabContainer.get_current_tab_control().get_child(0).grab_focus()
			get_tree().set_input_as_handled()
		elif event.is_action_pressed("ui_focus_next"):
			$Menu/TabContainer.current_tab = ($Menu/TabContainer.current_tab + 1) % $Menu/TabContainer.get_tab_count()
			$Menu/TabContainer.get_current_tab_control().get_child(0).grab_focus()
			get_tree().set_input_as_handled()

func _on_Fullscreen_toggled(button_pressed):
	OS.window_fullscreen = button_pressed
	
	save_option("visual", "fullscreen", button_pressed)

func _on_VSync_toggled(button_pressed):
	OS.vsync_enabled = button_pressed
	
	save_option("visual", "vsync", button_pressed)


func _on_FXAA_toggled(button_pressed):
	get_viewport().set_use_fxaa(button_pressed)
	
	save_option("visual", "fxaa", button_pressed)

func _on_Language_item_selected(ID):
	var locales = ProjectSettings.get("locale/locale_filter")[1]
	var option_meta = $Menu/TabContainer/Visual/Language/OptionButton.get_item_metadata(ID)
	if option_meta == "":
		TranslationServer.set_locale(OS.get_locale())
	elif not locales.has(option_meta):
		TranslationServer.set_locale(OS.get_locale())
		
		save_option("visual", "language", "")
		Global.emit_signal("language_changed")
		return
	
	TranslationServer.set_locale(option_meta)
	
	save_option("visual", "language", option_meta)
	Global.emit_signal("language_changed")

func _on_FrameCap_item_selected(ID):
	match ID:
		0:
			Engine.target_fps = 30
		1:
			Engine.target_fps = 60
		2:
			Engine.target_fps = 120
		3:
			Engine.target_fps = 144
		4:
			Engine.target_fps = 240
		5:
			Engine.target_fps = 0 # A zero value uncaps the frames.
	
	save_option("visual", "frame_cap", ID)

func _on_MSAA_item_selected(ID):
	match ID:
		0:
			get_viewport().set_msaa(0) #MSAA_DISABLED
		1:
			get_viewport().set_msaa(1) #MSAA_2X
		2:
			get_viewport().set_msaa(2) #MSAA_4X
		3:
			get_viewport().set_msaa(3) #MSAA_8X
		4:
			get_viewport().set_msaa(4) #MSAA_16X
	
	save_option("visual", "msaa", ID)

func _on_bus_toggled(enabled, index):
	AudioServer.set_bus_mute(index, not enabled)
	
	save_option("audio", AudioServer.get_bus_name(index).to_lower() + "_muted", not enabled)

func _on_volume_changed(value, index):
	AudioServer.set_bus_volume_db(index, value)
	
	var percentage = str((value + 80) / 80 * 100).pad_decimals(0) + "%"
	match index:
		0:
			$Menu/TabContainer/Audio/Master/Label.text = percentage
		1:
			$Menu/TabContainer/Audio/Music/Label.text = percentage
		2:
			$Menu/TabContainer/Audio/Effects/Label.text = percentage
	
	save_option("audio", AudioServer.get_bus_name(index).to_lower() + "_volume", value)

func _on_MuteUnfocus_toggled(button_pressed):
	Global.mute_window_unfocus = button_pressed
	
	save_option("audio", "mute_window_unfocus", button_pressed)

func _on_PauseUnfocus_toggled(button_pressed):
	Global.pause_window_unfocus = button_pressed
	
	save_option("misc", "pause_window_unfocus", button_pressed)

func get_option_value_safely(section, key, default, min_value=null, max_value=null):
	var value = _options_file.get_value(section, key, default)
	if typeof(value) != typeof(default) or min_value != null and value < min_value or max_value != null and value > max_value:
		return default
	
	return value

func load_options():
	var err = _options_file.load(USER_OPTIONS_FILE)
	if err != OK:
		print("Error while loading options: " + Utility.error_code_to_string(err))
		return
	
	_is_loading_options = true # Avoid saving options while loading them.
	
	var language = get_option_value_safely("visual", "language", "")
	var language_id = ProjectSettings.get("locale/locale_filter")[1].find(language)
	if language_id == -1:
		language_id = 0
	else:
		language_id += 1
	_on_Language_item_selected(language_id)
	$Menu/TabContainer/Visual/Language/OptionButton.select(language_id)
	
	OS.window_fullscreen = get_option_value_safely("visual", "fullscreen", false)
	$Menu/TabContainer/Visual/Fullscreen.pressed = OS.window_fullscreen
	
	var fxaa = get_option_value_safely("visual", "fxaa", false)
	$Menu/TabContainer/Visual/FXAA.pressed = fxaa
	
	OS.vsync_enabled = get_option_value_safely("visual", "vsync", false)
	$Menu/TabContainer/Visual/VSync.pressed = OS.vsync_enabled
	
	var frame_id = get_option_value_safely("visual", "frame_cap", 1, 0, 5)
	_on_FrameCap_item_selected(frame_id)
	$Menu/TabContainer/Visual/FrameCap/OptionButton.select(frame_id)
	
	var msaa = get_option_value_safely("visual", "msaa", 0)
	$Menu/TabContainer/Visual/MSAA/OptionButton.select(msaa)
	
	var quality = get_option_value_safely("visual", "quality", 0)
	$Menu/TabContainer/Visual/Quality/OptionButton.select(quality)
	
	AudioServer.set_bus_mute(0, get_option_value_safely("audio", "master_muted", false))
	AudioServer.set_bus_mute(1, get_option_value_safely("audio", "music_muted", false))
	AudioServer.set_bus_mute(2, get_option_value_safely("audio", "effects_muted", false))
	
	$Menu/TabContainer/Audio/Master/CheckBox.pressed = not AudioServer.is_bus_mute(0)
	$Menu/TabContainer/Audio/Music/CheckBox.pressed = not AudioServer.is_bus_mute(1)
	$Menu/TabContainer/Audio/Effects/CheckBox.pressed = not AudioServer.is_bus_mute(2)
	
	Global.mute_window_unfocus = get_option_value_safely("audio", "mute_window_unfocus", true)
	$Menu/TabContainer/Audio/MuteUnfocus.pressed = Global.mute_window_unfocus
	
	# Setting the 'value' of 'Range' nodes directly also fires their signals.
	$Menu/TabContainer/Audio/MasterVolume.value = get_option_value_safely("audio", "master_volume", 0.0, -80, 0)
	$Menu/TabContainer/Audio/MusicVolume.value = get_option_value_safely("audio", "music_volume", 0.0, -80, 0)
	$Menu/TabContainer/Audio/EffectsVolume.value = get_option_value_safely("audio", "effects_volume", 0.0, -80, 0)
	
	Global.pause_window_unfocus = get_option_value_safely("misc", "pause_window_unfocus", true)
	$Menu/TabContainer/Misc/PauseUnfocus.pressed = Global.pause_window_unfocus
	
	_is_loading_options = false

func save_option(section, key, value):
	if _is_loading_options:
		return
	
	_options_file.set_value(section, key, value)
	var err = _options_file.save(USER_OPTIONS_FILE)
	if err != OK:
		print("Error while saving options: " + Utility.error_code_to_string(err))

func _on_GraphicQuality_item_selected(ID):
	match ID:
		0: # High
			ProjectSettings.set_setting("rendering/quality/shadow_atlas/size", 8192)
			ProjectSettings.set_setting("rendering/quality/directional_shadow/size", 8192)
			ProjectSettings.set_setting("rendering/quality/shadows/filter_mode", 1)
			ProjectSettings.set_setting("rendering/quality/shading/force_vertex_shading", false)
		1: # Medium
			ProjectSettings.set_setting("rendering/quality/shadow_atlas/size", 4096)
			ProjectSettings.set_setting("rendering/quality/directional_shadow/size", 4096)
			ProjectSettings.set_setting("rendering/quality/shadows/filter_mode", 1)
			ProjectSettings.set_setting("rendering/quality/shading/force_vertex_shading", false)
		2: # Low
			ProjectSettings.set_setting("rendering/quality/shadow_atlas/size", 2048)
			ProjectSettings.set_setting("rendering/quality/directional_shadow/size", 2048)
			ProjectSettings.set_setting("rendering/quality/shadows/filter_mode", 0)
			ProjectSettings.set_setting("rendering/quality/shading/force_vertex_shading", false)
	$Menu/AcceptDialog.dialog_text = "MENU_GRAPHIC_QUALITY_REBOOT_NOTICE"
	
	$Menu/AcceptDialog.popup_centered()
	save_option("visual", "quality", ID)
	
	# Kind of ugly way to get it working
	# The graphic options must be loaded before the engine starts up, because
	# some options can not be changed after initialization
	#
	# So the only possibility to change them is to change the value loaded in the project settings
	# But we don't want to override the local render settings on a new version (it's stored in the pck distributed with the game after all)
	# 
	# Luckily, Godot offers a way to load a custom project settings file, which we naturally point to 'user://render_settings.godot'
	# There we are able to change all settings we like and they will persist
	# But we should not just save the options with `ProjectSettings.save_custom`
	# because this will save everything, but we just want the render settings, as the remaining settings could be updated in a new game version
	#
	# Therefore we're forging such a file. This is an horrible hack and I hope Godot 4.0 will have a better way to do this
	#
	# Idea found here: https://github.com/godotengine/godot/issues/30087#issuecomment-505879289
	var file = ConfigFile.new()
	file.set_value("rendering", "quality/shadow_atlas/size", ProjectSettings.get_setting("rendering/quality/shadow_atlas/size"))
	file.set_value("rendering", "quality/directional_shadow/size", ProjectSettings.get_setting("rendering/quality/directional_shadow/size"))
	file.set_value("rendering", "quality/shadows/filter_mode", ProjectSettings.get_setting("rendering/quality/shadows/filter_mode"))
	file.set_value("rendering", "quality/shading/force_vertex_shading", ProjectSettings.get_setting("rendering/quality/shading/force_vertex_shading"))

	file.save("user://render_settings.godot")

func _on_change_controls_pressed(player_id: int):
	$Menu.hide()
	$ControlRemapper.player_id = player_id
	$ControlRemapper.show()

func _on_ControlRemapper_quit():
	$Menu.show()
	var button := $Menu/TabContainer/Controls.get_child($ControlRemapper.player_id - 1)
	button.grab_focus()
	
#*** Credits menu ***#
func process_hyperlinks(input: String) -> String:
	var out := ""
	
	var pos = input.find("[")
	while pos != -1:
		var end = input.find("]")
		if end != -1 and input[end+1] == "(":
			var urlend = input.find(")", end+1)
			out += input.substr(0, pos)
			out += "[color=#00aaff][url=" + input.substr(end+2, urlend - end - 2) + "]" \
					+ input.substr(pos + 1, end - pos - 1) + "[/url][/color]"
			input = input.substr(urlend+1, input.length() - urlend)
		else:
			out += input.substr(0, pos+1)
			input = input.substr(pos+1, input.length() - pos)
		pos = input.find("[")
	out += input
	return out

func print_licenses(f: File) -> String:
	var text = ""
	
	var current_dir := ""
	var has_files = true
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("## "):
			current_dir = line.substr(3, line.length() - 3)
			if not current_dir.ends_with("/"):
				current_dir += "/"
			has_files = false
		elif line.begins_with("### "):
			var unescaped := line.substr(4, line.length() - 4).replace("\\*", "*")
			var files = unescaped.split("|")
			for file in files:
				text += "[color=#ffffff]" + current_dir + file.lstrip(" \t\v").rstrip(" \t\v") + ":[/color]\n"
			has_files = true
		else:
			if not has_files: # Special edge case: toplevel entries start with '## '
				text += "[color=#ffffff]" + current_dir.substr(0, current_dir.length() - 1) + ":[/color]\n"
				has_files = true
			text += "[indent]" + process_hyperlinks(line) + '[/indent]\n'
	
	return text

func _on_TabContainer_tab_selected(tab):
	if tab == 4:
		var text = """[color=#ffffff][center]SuperTuxParty is brought to you by:[/center]
[color=#ffaa00][center][url=https://gitlab.com/Dragoncraft89]Dragoncraft89[/url], [url=https://gitlab.com/Antiwrapper]Antiwrapper[/url], [url=https://yeldham.itch.io]Yeldham[/url], [url=https://gitlab.com/RiderExMachina]RiderExMachina[/url], [url=https://gitlab.com/Hejka26]Hejka26[/url], [url=https://gitlab.com/airon90]airon90[/url], [url=https://gitlab.com/swolfschristophe]swolfschristophe[/url], [url=https://gitlab.com/pastmidnight14]pastmidnight14[/url], [url=https://gitlab.com/kratz00]kratz00[/url], [url=https://gitlab.com/Independent-Eye]Independent-Eye[/url] and [url=https://gitlab.com/doggoofspeed]DoggoOfSpeed[/url][/center][color=#e5e5e5]

[center]with [color=#66aa00]ART[/color] by:[/center]
"""
		var license_art := File.new()
		license_art.open("res://licenses/LICENSE-ART.md", File.READ)
		text += print_licenses(license_art)
		license_art.close()
	
		text += "[center]and [color=#66aa00]MUSIC[/color] by:[/center]\n"
	
		var license_music := File.new()
		license_music.open("res://licenses/LICENSE-MUSIC.md", File.READ)
		text += print_licenses(license_music)
		license_music.close()
	
		text += "[center][color=#66aa00]SHADERS[/color] by:[/center]\n"
	
		var license_shader := File.new()
		license_shader.open("res://licenses/LICENSE-SHADER.md", File.READ)
		text += print_licenses(license_shader)
		license_shader.close()
	
		var license_fonts := File.new()
		license_fonts.open("res://licenses/LICENSE-FONTS.md", File.READ)
		text += print_licenses(license_fonts)
		license_shader.close()
		
		$Menu/TabContainer/Credits/RichTextLabel.bbcode_text = text

func _on_Credits_meta_clicked(meta):
	OS.shell_open(meta) # Open links in the credits
	




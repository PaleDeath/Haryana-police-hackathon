extends Control

onready var lobby = Lobby.get_lobby(self)

func _process(_delta):
	var progress = Global.get_loader_progress()
	
	if progress[1] == 0:
		progress[1] = 1
		progress[0] = 1
	
	$CenterContainer/VBoxContainer/ProgressBar.max_value = progress[1]
	$CenterContainer/VBoxContainer/ProgressBar.value = progress[0]

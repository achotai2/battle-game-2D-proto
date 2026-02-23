extends Node
class_name TeamMemory

signal team_changed(new_team_id: int)

# In Godot 4, this setter runs automatically anytime something changes this variable
@export var current_team: int = 0:
	set(value):
		current_team = value
		team_changed.emit(current_team) # Announce it to the void!


func return_team() -> int:
	return current_team

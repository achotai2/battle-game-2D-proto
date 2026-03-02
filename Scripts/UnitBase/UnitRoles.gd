extends Node


enum UnitType {
	PLAYER,
	PEASANT,
	SOLDIER,
	ARCHER,
	WORKER,
	LORD,
}

var role_groups := {
	UnitType.PLAYER: [
		&"Attackable",
		&"Player",
	],
	UnitType.PEASANT: [
		&"Minions",
		&"Peasants",
		&"Interactable"
	],
	UnitType.LORD: [
		&"Minions",
		&"Interactable",
		&"Lord",
	],
	UnitType.SOLDIER: [
		&"Minions",
		&"Attackable",
		&"Interactable"
	],
	UnitType.ARCHER: [
		&"Minions",
		&"Attackable",
		&"Interactable"
	],
	UnitType.WORKER: [
		&"Minions",
		&"Attackable",
		&"Interactable",
		&"Workers",
	],
}

func get_role_groups(role: UnitType) -> Array:
	return role_groups.get(role, [])


# role -> player -> SpriteFrames
var frames := {
	UnitType.PLAYER: {
		1: preload("res://Art/SpriteFrames/Player.tres"),
		2: preload("res://Art/SpriteFrames/Player.tres"),
	},
	UnitType.PEASANT: {
		1: preload("res://Art/SpriteFrames/Peasant_Blue.tres"),
		2: preload("res://Art/SpriteFrames/Peasant_Red.tres"),
	},
	UnitType.SOLDIER: {
		1: preload("res://Art/SpriteFrames/Soldier_Blue.tres"),
		2: preload("res://Art/SpriteFrames/Soldier_Red.tres"),
	},
	UnitType.ARCHER: {
		1: preload("res://Art/SpriteFrames/Archer_Blue.tres"),
		2: preload("res://Art/SpriteFrames/Archer_Red.tres"),
	},
	UnitType.WORKER: {
		1: preload("res://Art/SpriteFrames/Worker_Blue.tres"),
		2: preload("res://Art/SpriteFrames/Worker_Red.tres"),
	},
	UnitType.LORD: {
		1: preload("res://Art/SpriteFrames/Soldier_Yellow.tres"),
		2: preload("res://Art/SpriteFrames/Soldier_Yellow.tres"),
	},
}

func get_frames(role: UnitType, player: int) -> SpriteFrames:
	if frames.has(role) and frames[role].has(player):
		return frames[role][player]
	# fallback: player 1 if missing
	return frames.get(role, {}).get(1, null)


# The Blueprint
var role_blueprints: Dictionary = {
	UnitType.PLAYER: {
		"advisors": [preload("res://Scripts/AgentNodes/Advisors/a_player_interact.gd"), preload("res://Scripts/AgentNodes/Advisors/a_player_movement.gd")],
		"memory": [preload("res://Scripts/MemoryNodes/GoldWallet.gd"), preload("res://Scripts/MemoryNodes/health.gd"), preload("res://Scripts/MemoryNodes/TeamMemory.gd")],
		"sensors": [preload("res://Scripts/SensorNodes/GoldTracker.gd"), preload("res://Scenes/AgentNodes/player_interactor.tscn"), preload("res://Scripts/SensorNodes/player_controls.gd")],
		"motor": [preload("res://Scripts/AgentNodes/agent_animate.gd"), preload("res://Scripts/AgentNodes/agent_move.gd"), preload("res://Scripts/AgentNodes/GoldGiver.gd")],
		"weapons": [preload("res://Scenes/Weapons/weapon_sword.tscn")],
	},
	UnitType.SOLDIER: {
	}
}

# The Manufacturer
func get_role_components(role: UnitType) -> Dictionary:
	var blueprint = role_blueprints.get(role, {})
	var generated_components := {
		"memory": [],
		"motor": [],
		"weapons": [],
		"sensors": [],
		"advisors": []
	}
	
	# Loop through each category in the blueprint
	for category in blueprint.keys():
		for resource in blueprint[category]:
			var new_node: Node
			
			# 1. Instantiate based on resource type
			if resource is PackedScene:
				new_node = resource.instantiate() # It's a .tscn
			elif resource is GDScript:
				new_node = resource.new() # It's a .gd script
			else:
				continue
				
			# 2. Extract a clean name from the file path
			# e.g., "res://Advisors/BehaviorWork.gd" -> "BehaviorWork"
			var clean_name = resource.resource_path.get_file().get_basename()
			
			# 3. Package them together in a dictionary and add to the list
			var component_package = {
				"node": new_node,
				"name": clean_name
			}
			generated_components[category].append(component_package)
			
	return generated_components
	

# --- DEPRECIATED ---
var weapons := {
	UnitType.PLAYER: preload("res://Scenes/Weapons/weapon_sword.tscn"),
	UnitType.SOLDIER: preload("res://Scenes/Weapons/weapon_sword.tscn"),
	UnitType.ARCHER: preload("res://Scenes/Weapons/weapon_bow.tscn"),
}

# --- DEPRECIATED ---
func get_weapon(role: UnitType) -> PackedScene:
	return weapons.get(role)


# --- DEPRECIATED ---
var taskers := {
	UnitType.PEASANT: MinionTasker,
	UnitType.WORKER: MinionTasker,
}

# --- DEPRECIATED ---
func get_tasker(role: UnitType) -> GDScript:
	return taskers.get(role)


# --- DEPRECIATED ---
var tasker_kinds := {
	UnitType.PEASANT: CastleJobBoard.JobBoardType.PEASANTS,
	UnitType.WORKER: CastleJobBoard.JobBoardType.WORKERS,
}

# --- DEPRECIATED ---
func get_tasker_kind(role: UnitType) -> Variant:
	return tasker_kinds.get(role, null)

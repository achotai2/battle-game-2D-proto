extends Node


enum UnitType {
	PLAYER,
	PEASANT,
	SOLDIER,
	ARCHER,
	WORKER,
	LORD,
	GOBLIN,
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
	UnitType.GOBLIN: [
		&"Minions",
		&"Attackable",
		&"Interactable",
	],
}

func get_role_groups(role: UnitType) -> Array:
	return role_groups.get(role, [])


var min_tax_times := {
	UnitType.PLAYER: null,
	UnitType.LORD: 0.0,
	UnitType.PEASANT: 60.0,
	UnitType.WORKER: 60.0,
	UnitType.SOLDIER: 60.0,
	UnitType.ARCHER: 60.0,
	UnitType.GOBLIN: null,
}

func get_min_tax_time(role: UnitType) -> Variant:
	return min_tax_times.get(role, null)

# role -> player -> SpriteFrames
var frames := {
	UnitType.PLAYER: {
		0: preload("res://Art/SpriteFrames/Player.tres"),
		1: preload("res://Art/SpriteFrames/Player.tres"),
		2: preload("res://Art/SpriteFrames/Player.tres"),
	},
	UnitType.PEASANT: {
		0: preload("res://Art/SpriteFrames/Peasant_Yellow.tres"),
		1: preload("res://Art/SpriteFrames/Peasant_Blue.tres"),
		2: preload("res://Art/SpriteFrames/Peasant_Red.tres"),
	},
	UnitType.SOLDIER: {
		0: preload("res://Art/SpriteFrames/Soldier_Yellow.tres"),
		1: preload("res://Art/SpriteFrames/Soldier_Blue.tres"),
		2: preload("res://Art/SpriteFrames/Soldier_Red.tres"),
	},
	UnitType.ARCHER: {
		0: preload("res://Art/SpriteFrames/Archer_Yellow.tres"),
		1: preload("res://Art/SpriteFrames/Archer_Blue.tres"),
		2: preload("res://Art/SpriteFrames/Archer_Red.tres"),
	},
	UnitType.WORKER: {
		0: preload("res://Art/SpriteFrames/Worker_Yellow.tres"),
		1: preload("res://Art/SpriteFrames/Worker_Blue.tres"),
		2: preload("res://Art/SpriteFrames/Worker_Red.tres"),
	},
	UnitType.LORD: {
		0: preload("res://Art/SpriteFrames/Soldier_Yellow.tres"),
		1: preload("res://Art/SpriteFrames/Soldier_Yellow.tres"),
		2: preload("res://Art/SpriteFrames/Soldier_Yellow.tres"),
	},
	UnitType.GOBLIN: {
		0: preload("res://Art/SpriteFrames/Peasant_Yellow.tres"),
		1: preload("res://Art/SpriteFrames/Peasant_Blue.tres"),
		2: preload("res://Art/SpriteFrames/Peasant_Red.tres"),
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
		"advisors": [preload("res://Scripts/AgentNodes/Advisors/a_player_interact.gd"), preload("res://Scripts/AgentNodes/Advisors/a_player_movement.gd"), preload("res://Scripts/AgentNodes/Advisors/a_player_attack.gd")],
		"memory": [preload("res://Scripts/MemoryNodes/GoldWallet.gd"), preload("res://Scripts/MemoryNodes/health.gd"), preload("res://Scripts/MemoryNodes/TeamMemory.gd"), preload("res://Scripts/MemoryNodes/UnitSpeed.gd"), preload("res://Scripts/MemoryNodes/TaxLedger.gd")],
		"sensors": [preload("res://Scenes/AgentNodes/Tracker.tscn"), preload("res://Scenes/AgentNodes/player_interactor.tscn"), preload("res://Scripts/SensorNodes/player_controls.gd")],
		"motor": [preload("res://Scripts/AgentNodes/agent_animate.gd"), preload("res://Scripts/AgentNodes/agent_move.gd"), preload("res://Scripts/AgentNodes/GoldGiver.gd")],
		"weapons": [preload("res://Scenes/Weapons/weapon_sword.tscn")],
	},
	UnitType.PEASANT: {
		"advisors": [preload("res://Scripts/AgentNodes/Advisors/a_flee.gd"), preload("res://Scripts/AgentNodes/Advisors/a_transform.gd"), preload("res://Scripts/AgentNodes/Advisors/a_wander.gd"), preload("res://Scripts/AgentNodes/Advisors/a_taxed.gd"),],
		"memory": [preload("res://Scripts/MemoryNodes/GoldWallet.gd"), preload("res://Scripts/MemoryNodes/health.gd"), preload("res://Scripts/MemoryNodes/TeamMemory.gd"), preload("res://Scripts/MemoryNodes/minion_tasker.gd"), preload("res://Scripts/MemoryNodes/UnitSpeed.gd"), preload("res://Scripts/MemoryNodes/TaxLedger.gd")],
		"sensors": [preload("res://Scenes/AgentNodes/Tracker.tscn")],
		"motor": [preload("res://Scripts/AgentNodes/agent_animate.gd"), preload("res://Scripts/AgentNodes/agent_move.gd"), preload("res://Scripts/AgentNodes/GoldGiver.gd"), preload("res://Scenes/AgentNodes/MinionNavAgent.tscn")],
		"weapons": [],
	},
	UnitType.WORKER: {
		"advisors": [preload("res://Scripts/AgentNodes/Advisors/a_flee.gd"), preload("res://Scripts/AgentNodes/Advisors/a_work.gd"), preload("res://Scripts/AgentNodes/Advisors/a_wander.gd"), preload("res://Scripts/AgentNodes/Advisors/a_taxed.gd"),],
		"memory": [preload("res://Scripts/MemoryNodes/GoldWallet.gd"), preload("res://Scripts/MemoryNodes/health.gd"), preload("res://Scripts/MemoryNodes/TeamMemory.gd"), preload("res://Scripts/MemoryNodes/minion_tasker.gd"), preload("res://Scripts/MemoryNodes/UnitSpeed.gd"), preload("res://Scripts/MemoryNodes/TaxLedger.gd")],
		"sensors": [preload("res://Scenes/AgentNodes/Tracker.tscn")],
		"motor": [preload("res://Scripts/AgentNodes/agent_animate.gd"), preload("res://Scripts/AgentNodes/agent_move.gd"), preload("res://Scripts/AgentNodes/GoldGiver.gd"), preload("res://Scenes/AgentNodes/MinionNavAgent.tscn"), preload("res://Scripts/AgentNodes/work_action.gd")],
		"weapons": [],
	},
	UnitType.SOLDIER: {
		"advisors": [preload("res://Scripts/AgentNodes/Advisors/a_wander.gd"), preload("res://Scripts/AgentNodes/Advisors/a_taxed.gd"), preload("res://Scripts/AgentNodes/Advisors/a_attack.gd")],
		"memory": [preload("res://Scripts/MemoryNodes/GoldWallet.gd"), preload("res://Scripts/MemoryNodes/health.gd"), preload("res://Scripts/MemoryNodes/TeamMemory.gd"), preload("res://Scripts/MemoryNodes/UnitSpeed.gd"), preload("res://Scripts/MemoryNodes/TaxLedger.gd")],
		"sensors": [preload("res://Scenes/AgentNodes/Tracker.tscn")],
		"motor": [preload("res://Scripts/AgentNodes/agent_animate.gd"), preload("res://Scripts/AgentNodes/agent_move.gd"), preload("res://Scripts/AgentNodes/GoldGiver.gd"), preload("res://Scenes/AgentNodes/MinionNavAgent.tscn")],
		"weapons": [preload("res://Scenes/Weapons/weapon_sword.tscn")],
	},
	UnitType.ARCHER: {
		"advisors": [preload("res://Scripts/AgentNodes/Advisors/a_wander.gd"), preload("res://Scripts/AgentNodes/Advisors/a_taxed.gd"), preload("res://Scripts/AgentNodes/Advisors/a_attack.gd")],
		"memory": [preload("res://Scripts/MemoryNodes/GoldWallet.gd"), preload("res://Scripts/MemoryNodes/health.gd"), preload("res://Scripts/MemoryNodes/TeamMemory.gd"), preload("res://Scripts/MemoryNodes/UnitSpeed.gd"), preload("res://Scripts/MemoryNodes/TaxLedger.gd")],
		"sensors": [preload("res://Scenes/AgentNodes/Tracker.tscn")],
		"motor": [preload("res://Scripts/AgentNodes/agent_animate.gd"), preload("res://Scripts/AgentNodes/agent_move.gd"), preload("res://Scripts/AgentNodes/GoldGiver.gd"), preload("res://Scenes/AgentNodes/MinionNavAgent.tscn")],
		"weapons": [preload("res://Scenes/Weapons/weapon_bow.tscn")],
	},
	UnitType.LORD: {
		"advisors": [preload("res://Scripts/AgentNodes/Advisors/a_flee.gd"), preload("res://Scripts/AgentNodes/Advisors/a_wander.gd"), preload("res://Scripts/AgentNodes/Advisors/a_taxed.gd"), preload("res://Scripts/AgentNodes/Advisors/a_lord_tax.gd")],
		"memory": [preload("res://Scripts/MemoryNodes/GoldWallet.gd"), preload("res://Scripts/MemoryNodes/health.gd"), preload("res://Scripts/MemoryNodes/TeamMemory.gd"), preload("res://Scripts/MemoryNodes/UnitSpeed.gd"), preload("res://Scripts/MemoryNodes/TaxLedger.gd")],
		"sensors": [preload("res://Scenes/AgentNodes/Tracker.tscn")],
		"motor": [preload("res://Scripts/AgentNodes/agent_animate.gd"), preload("res://Scripts/AgentNodes/agent_move.gd"), preload("res://Scripts/AgentNodes/GoldGiver.gd"), preload("res://Scenes/AgentNodes/MinionNavAgent.tscn")],
		"weapons": [],
	},
	UnitType.GOBLIN: {
		"advisors": [preload("res://Scripts/AgentNodes/Advisors/a_goblin_march.gd"), preload("res://Scripts/AgentNodes/Advisors/a_attack.gd")],
		"memory": [preload("res://Scripts/MemoryNodes/target_location.gd"), preload("res://Scripts/MemoryNodes/health.gd"), preload("res://Scripts/MemoryNodes/TeamMemory.gd"), preload("res://Scripts/MemoryNodes/UnitSpeed.gd")],
		"sensors": [preload("res://Scenes/AgentNodes/Tracker.tscn")],
		"motor": [preload("res://Scripts/AgentNodes/agent_animate.gd"), preload("res://Scripts/AgentNodes/agent_move.gd"), preload("res://Scenes/AgentNodes/MinionNavAgent.tscn")],
		"weapons": [preload("res://Scenes/Weapons/weapon_sword.tscn")],
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

			# 1b. Configure specific components
			if new_node is MinionTasker:
				new_node.kind = get_tasker_kind(role)
				
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

# The exact Job Board frequency each unit type should tune into
var tasker_kinds: Dictionary = {
	UnitType.PEASANT: CastleJobBoard.JobBoardType.PEASANTS,
	UnitType.WORKER: CastleJobBoard.JobBoardType.WORKERS,
	# If soldiers eventually guard things, add them here!
}

func get_tasker_kind(role: UnitType) -> int:
	# Default to WORKERS (0) if not specified
	return tasker_kinds.get(role, CastleJobBoard.JobBoardType.WORKERS)

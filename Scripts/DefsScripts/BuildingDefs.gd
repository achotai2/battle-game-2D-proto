extends Node

const BARRACKS := &"barracks"
const HOUSE := &"house"
const ARCHERY := &"archery_range"

var _visuals := {
	HOUSE: {
		BuildingBase.BuildingState.DESTROYED: {
			1: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Destroyed.png"),
			2: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Destroyed.png"),
		},
		BuildingBase.BuildingState.CONSTRUCTING: {
			1: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Construction.png"),
			2: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Construction.png"),
		},
		BuildingBase.BuildingState.BUILT: {
			1: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Blue.png"),
			2: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Red.png"),
		},
	},
	BARRACKS: {
		BuildingBase.BuildingState.DESTROYED: {
			1: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/Castle/Castle_Destroyed.png"),
			2: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/Castle/Castle_Destroyed.png"),
		},
		BuildingBase.BuildingState.CONSTRUCTING: {
			1: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/Castle/Castle_Construction.png"),
			2: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/Castle/Castle_Construction.png"),
		},
		BuildingBase.BuildingState.BUILT: {
			1: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/Castle/Castle_Blue.png"),
			2: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/Castle/Castle_Red.png"),
		},
	},
	ARCHERY: {
		BuildingBase.BuildingState.DESTROYED: {
			1: preload("res://Art/Tiny Swords (Update 010)/Factions/Goblins/Buildings/Wood_House/Goblin_House_Destroyed.png"),
			2: preload("res://Art/Tiny Swords (Update 010)/Factions/Goblins/Buildings/Wood_House/Goblin_House_Destroyed.png"),
		},
		BuildingBase.BuildingState.CONSTRUCTING: {
			1: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Construction.png"),
			2: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Construction.png"),
		},
		BuildingBase.BuildingState.BUILT: {
			1: preload("res://Art/Tiny Swords (Update 010)/Factions/Goblins/Buildings/Wood_House/Goblin_House.png"),
			2: preload("res://Art/Tiny Swords (Update 010)/Factions/Goblins/Buildings/Wood_House/Goblin_House.png"),
		},
	},
}

var _interact_modes := {
	HOUSE: {
		BuildingBase.BuildingState.DESTROYED: InteractPrompt.IconType.CONSTRUCT,
		BuildingBase.BuildingState.CONSTRUCTING: InteractPrompt.IconType.NONE,
		BuildingBase.BuildingState.BUILT: InteractPrompt.IconType.TAX,
	},
	BARRACKS: {
		BuildingBase.BuildingState.DESTROYED: InteractPrompt.IconType.CONSTRUCT,
		BuildingBase.BuildingState.CONSTRUCTING: InteractPrompt.IconType.NONE,
		BuildingBase.BuildingState.BUILT: InteractPrompt.IconType.TAX,
	},
	ARCHERY: {
		BuildingBase.BuildingState.DESTROYED: InteractPrompt.IconType.CONSTRUCT,
		BuildingBase.BuildingState.CONSTRUCTING: InteractPrompt.IconType.NONE,
		BuildingBase.BuildingState.BUILT: InteractPrompt.IconType.ARCHER,
	},
}

var _spawn_configs := {
	HOUSE: {
		"unit_type": "worker",
		"cooldown": 1.0,
	},
	BARRACKS: {
		"unit_type": "soldier",
		"cooldown": 1.0,
	},
	ARCHERY: {
		"unit_type": "archer",
		"cooldown": 1.0,
	},
}


func get_frames(building_type: StringName, state: int, player: int) -> Resource:
	if _visuals.has(building_type) and _visuals[building_type].has(state):
		var options = _visuals[building_type][state]
		if options.has(player):
			return options[player]
		return options.get(1, null)
	return null


func get_interact_mode(building_type: StringName, state: int) -> InteractPrompt.IconType:
	if _interact_modes.has(building_type):
		return _interact_modes[building_type].get(state, InteractPrompt.IconType.CONSTRUCT)
	return InteractPrompt.IconType.CONSTRUCT


func get_spawn_config(building_type: StringName) -> Dictionary:
	return _spawn_configs.get(building_type, {})

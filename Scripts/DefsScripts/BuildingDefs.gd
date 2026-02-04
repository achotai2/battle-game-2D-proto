extends Node

enum BuildingType {
	BARRACKS,
	HOUSE,
	ARCHERY,
}

enum BuildingState {
	DESTROYED,
	CONSTRUCTING,
	BUILT
}


const _visuals := {
	BuildingType.HOUSE: {
		BuildingState.DESTROYED: {
			1: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Destroyed.png"),
			2: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Destroyed.png"),
		},
		BuildingState.CONSTRUCTING: {
			1: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Construction.png"),
			2: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Construction.png"),
		},
		BuildingState.BUILT: {
			1: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Blue.png"),
			2: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Red.png"),
		},
	},
	BuildingType.BARRACKS: {
		BuildingState.DESTROYED: {
			1: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/Castle/Castle_Destroyed.png"),
			2: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/Castle/Castle_Destroyed.png"),
		},
		BuildingState.CONSTRUCTING: {
			1: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/Castle/Castle_Construction.png"),
			2: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/Castle/Castle_Construction.png"),
		},
		BuildingState.BUILT: {
			1: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/Castle/Castle_Blue.png"),
			2: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/Castle/Castle_Red.png"),
		},
	},
	BuildingType.ARCHERY: {
		BuildingState.DESTROYED: {
			1: preload("res://Art/Tiny Swords (Update 010)/Factions/Goblins/Buildings/Wood_House/Goblin_House_Destroyed.png"),
			2: preload("res://Art/Tiny Swords (Update 010)/Factions/Goblins/Buildings/Wood_House/Goblin_House_Destroyed.png"),
		},
		BuildingState.CONSTRUCTING: {
			1: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Construction.png"),
			2: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Construction.png"),
		},
		BuildingState.BUILT: {
			1: preload("res://Art/Tiny Swords (Update 010)/Factions/Goblins/Buildings/Wood_House/Goblin_House.png"),
			2: preload("res://Art/Tiny Swords (Update 010)/Factions/Goblins/Buildings/Wood_House/Goblin_House.png"),
		},
	},
}

enum IconType {
	NONE,
	TAX,
	CONSTRUCT,
	CUT,
	ARCHER,
}

var _interact_modes := {
	BuildingType.HOUSE: {
		BuildingState.DESTROYED: IconType.CONSTRUCT,
		BuildingState.CONSTRUCTING: IconType.NONE,
		BuildingState.BUILT: IconType.TAX,
	},
	BuildingType.BARRACKS: {
		BuildingState.DESTROYED: IconType.CONSTRUCT,
		BuildingState.CONSTRUCTING: IconType.NONE,
		BuildingState.BUILT: IconType.TAX,
	},
	BuildingType.ARCHERY: {
		BuildingState.DESTROYED: IconType.CONSTRUCT,
		BuildingState.CONSTRUCTING: IconType.NONE,
		BuildingState.BUILT: IconType.ARCHER,
	},
}

var _spawn_configs := {
	BuildingType.HOUSE: {
		"unit_type": UnitRoles.UnitType.WORKER,
#		"cooldown": 1.0,
	},
	BuildingType.BARRACKS: {
		"unit_type": UnitRoles.UnitType.SOLDIER,
#		"cooldown": 1.0,
	},
	BuildingType.ARCHERY: {
		"unit_type": UnitRoles.UnitType.ARCHER,
#		"cooldown": 1.0,
	},
}


func get_frames(building_type: BuildingType, state: int, player: int) -> Resource:
	if _visuals.has(building_type) and _visuals[building_type].has(state):
		var options = _visuals[building_type][state]
		if options.has(player):
			return options[player]
		return options.get(1, null)
	return null


func get_interact_mode(building_type: BuildingType, state: int) -> IconType:
	if _interact_modes.has(building_type):
		return _interact_modes[building_type].get(state, IconType.CONSTRUCT)
	return IconType.CONSTRUCT


func get_spawn_config(building_type: BuildingType) -> Dictionary:
	return _spawn_configs.get(building_type, {})

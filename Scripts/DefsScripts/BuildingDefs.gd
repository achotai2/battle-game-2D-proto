extends Node
# Assuming this is an Autoload named 'BuildingDefs'

enum BuildingType {
	BARRACKS,
	HOUSE,
	ARCHERY,
	TREE,
	VILLAGE,
}

enum BuildingState {
	DESTROYED,
	CONSTRUCTING,
	BUILDING,
	BUILT
}

enum IconType {
	NONE,
	TAX,
	CONSTRUCT,
	CUT,
	ARCHER,
}

# --- VISUALS ---
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
		BuildingState.BUILDING: {
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
		BuildingState.BUILDING: {
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
		BuildingState.BUILDING: {
			1: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Construction.png"),
			2: preload("res://Art/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Construction.png"),
		},
		BuildingState.BUILT: {
			1: preload("res://Art/Tiny Swords (Update 010)/Factions/Goblins/Buildings/Wood_House/Goblin_House.png"),
			2: preload("res://Art/Tiny Swords (Update 010)/Factions/Goblins/Buildings/Wood_House/Goblin_House.png"),
		},
	},
BuildingType.TREE: {
		BuildingState.DESTROYED: {
			1: preload("res://Art/SpriteFrames/tree.tres"),
			2: preload("res://Art/SpriteFrames/tree.tres"),
		},
		BuildingState.CONSTRUCTING: {
			1: preload("res://Art/SpriteFrames/tree.tres"),
			2: preload("res://Art/SpriteFrames/tree.tres"),
		},
		BuildingState.BUILDING: {
			1: preload("res://Art/SpriteFrames/tree.tres"),
			2: preload("res://Art/SpriteFrames/tree.tres"),
		},
		BuildingState.BUILT: {
			1: preload("res://Art/SpriteFrames/tree.tres"),
			2: preload("res://Art/SpriteFrames/tree.tres"),
		},
	},
	BuildingType.VILLAGE: {
		BuildingState.DESTROYED: {
			0: preload("res://Art/Village.png"),
			1: preload("res://Art/Village.png"),
			2: preload("res://Art/Village.png"),
		},
		BuildingState.CONSTRUCTING: {
			0: preload("res://Art/Village.png"),
			1: preload("res://Art/Village.png"),
			2: preload("res://Art/Village.png"),
		},
		BuildingState.BUILDING: {
			0: preload("res://Art/Village.png"),
			1: preload("res://Art/Village.png"),
			2: preload("res://Art/Village.png"),
		},
		BuildingState.BUILT: {
			0: preload("res://Art/Village.png"),
			1: preload("res://Art/Village.png"),
			2: preload("res://Art/Village.png"),
		},
	},
}

# --- UI ICONS ---
const _interact_modes := {
	BuildingType.HOUSE: {
		BuildingState.DESTROYED: IconType.CONSTRUCT,
		BuildingState.CONSTRUCTING: IconType.NONE,
		BuildingState.BUILDING: IconType.NONE,
		BuildingState.BUILT: IconType.TAX,
	},
	BuildingType.BARRACKS: {
		BuildingState.DESTROYED: IconType.CONSTRUCT,
		BuildingState.CONSTRUCTING: IconType.NONE,
		BuildingState.BUILDING: IconType.NONE,
		BuildingState.BUILT: IconType.TAX,
	},
	BuildingType.ARCHERY: {
		BuildingState.DESTROYED: IconType.CONSTRUCT,
		BuildingState.CONSTRUCTING: IconType.NONE,
		BuildingState.BUILDING: IconType.NONE,
		BuildingState.BUILT: IconType.ARCHER,
	},
	BuildingType.TREE: {
		BuildingState.DESTROYED: IconType.CUT,
		BuildingState.CONSTRUCTING: IconType.NONE,
		BuildingState.BUILDING: IconType.NONE,
		BuildingState.BUILT: IconType.NONE,
	},
}

# --- CONSTRUCTION PARAMS ---
# How much "work" it takes to build the building from the DESTROYED state
const _construction_costs := {
	BuildingType.HOUSE: 5.0,
	BuildingType.BARRACKS: 15.0,
	BuildingType.ARCHERY: 10.0,
	BuildingType.TREE: 3.0,
}

# --- PRODUCTION PARAMS ---
# What does the building spawn?
const _spawn_configs := {
	BuildingType.HOUSE: { "unit_type": UnitRoles.UnitType.WORKER },
	BuildingType.BARRACKS: { "unit_type": UnitRoles.UnitType.SOLDIER },
	BuildingType.ARCHERY: { "unit_type": UnitRoles.UnitType.ARCHER },
}

# How much "work" does the specific unit take to train? 
# (You could also put this in UnitRoles, but keeping it here centralizes building logic)
const _unit_train_costs := {
	UnitRoles.UnitType.WORKER: 5.0,
	UnitRoles.UnitType.SOLDIER: 6.0,
	UnitRoles.UnitType.ARCHER: 5.0,
}


# --- GETTERS ---

func get_frames(building_type: BuildingType, state: BuildingState, player: int) -> Resource:
	if _visuals.has(building_type) and _visuals[building_type].has(state):
		var options = _visuals[building_type][state]
		
		# Return the specific player's color, or default to player 1 if it's missing
		if options.has(player):
			return options[player]
		else:
			return options.get(1, null)
			
	return null


func get_interact_mode(building_type: BuildingType, state: BuildingState) -> IconType:
	if _interact_modes.has(building_type):
		return _interact_modes[building_type].get(state, IconType.CONSTRUCT)
	return IconType.CONSTRUCT

func get_construction_cost(building_type: BuildingType) -> float:
	return _construction_costs.get(building_type, 100.0)

func get_spawn_config(building_type: BuildingType) -> Dictionary:
	return _spawn_configs.get(building_type, {})
	
func get_unit_train_cost(unit_type: UnitRoles.UnitType) -> float:
	return _unit_train_costs.get(unit_type, 50.0)

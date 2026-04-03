extends Node
# Autoload named 'BuildingDefs'

enum BuildingType {
	BARRACKS,
	HOUSE,
	ARCHERY,
	TREE,
	VILLAGE,
	WALL,
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
			1: preload("res://Art/Buildings_RTS/OBJ/House_Level1_BlueTeam.obj"),
			2: preload("res://Art/Buildings_RTS/OBJ/House_Level1_RedTeam.obj"),
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
			1: preload("res://Art/Buildings_RTS/OBJ/Blacksmith_BlueTeam.obj"),
			2: preload("res://Art/Buildings_RTS/OBJ/Blacksmith_RedTeam.obj"),
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
			1: preload("res://Art/Buildings_RTS/OBJ/GuardsBarracks_BlueTeam.obj"),
			2: preload("res://Art/Buildings_RTS/OBJ/GuardsBarracks_RedTeam.obj"),
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
	BuildingType.WALL: {
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
			1: preload("res://Art/Buildings_RTS/OBJ/Wall_Level1_BlueTeam.obj"),
			2: preload("res://Art/Buildings_RTS/BLEND/Wall_Level1_RedTeam.blend"),
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
	BuildingType.WALL: {
		BuildingState.DESTROYED: IconType.CONSTRUCT,
		BuildingState.CONSTRUCTING: IconType.NONE,
		BuildingState.BUILDING: IconType.NONE,
		BuildingState.BUILT: IconType.NONE,
	},
}


# ==========================================
# --- TIMERS & PROGRESS (Floats) ---
# ==========================================

# How much "work" it takes to build the building from the DESTROYED state
const _construction_work_time := {
	BuildingType.HOUSE: 5.0,
	BuildingType.BARRACKS: 15.0,
	BuildingType.ARCHERY: 10.0,
	BuildingType.TREE: 3.0,
	BuildingType.WALL: 5.0,
}

# How much "work" does the specific unit take to train before it spawns? 
const _unit_train_work_time := {
	UnitRoles.UnitType.WORKER: 5.0,
	UnitRoles.UnitType.SOLDIER: 6.0,
	UnitRoles.UnitType.ARCHER: 5.0,
}


# ==========================================
# --- ECONOMY (Integers/Gold) ---
# ==========================================

# How much GOLD it costs the Player to start constructing this building
const _building_gold_costs := {
	BuildingType.HOUSE: 10,
	BuildingType.BARRACKS: 25,
	BuildingType.ARCHERY: 30,
	BuildingType.TREE: 3,
	BuildingType.VILLAGE: 0,
	BuildingType.WALL: 5,
}

# How much GOLD it costs the Player to click the building and spawn a unit
const _unit_gold_costs := {
	UnitRoles.UnitType.WORKER: 5,
	UnitRoles.UnitType.SOLDIER: 15,
	UnitRoles.UnitType.ARCHER: 20,
}

const _spawn_configs := {
	BuildingType.HOUSE: { "unit_type": UnitRoles.UnitType.WORKER },
	BuildingType.BARRACKS: { "unit_type": UnitRoles.UnitType.SOLDIER },
	BuildingType.ARCHERY: { "unit_type": UnitRoles.UnitType.ARCHER },
}


# --- GETTERS ---

func get_frames(building_type: BuildingType, state: BuildingState, player: int) -> Resource:
	if _visuals.has(building_type) and _visuals[building_type].has(state):
		var options = _visuals[building_type][state]
		if options.has(player):
			return options[player]
		else:
			return options.get(1, null)
	return null

func get_interact_mode(building_type: BuildingType, state: BuildingState) -> IconType:
	if _interact_modes.has(building_type):
		return _interact_modes[building_type].get(state, IconType.CONSTRUCT)
	return IconType.CONSTRUCT

func get_spawn_config(building_type: BuildingType) -> Dictionary:
	return _spawn_configs.get(building_type, {})

# --- WORK GETTERS (Floats) ---
func get_construction_work(building_type: BuildingType) -> float:
	return _construction_work_time.get(building_type, 10.0)

func get_unit_train_work(unit_type: UnitRoles.UnitType) -> float:
	return _unit_train_work_time.get(unit_type, 5.0)

# --- GOLD GETTERS (Ints) ---
func get_building_gold_cost(building_type: BuildingType) -> int:
	return _building_gold_costs.get(building_type, 0)

func get_unit_gold_cost(unit_type: UnitRoles.UnitType) -> int:
	return _unit_gold_costs.get(unit_type, 0)

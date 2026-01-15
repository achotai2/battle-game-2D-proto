extends Node

const BARRACKS := &"barracks"

var _visuals := {
	BARRACKS: {
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
}

var _work_required := {
	BARRACKS: 20.0,
}

var _interact_modes := {
	BARRACKS: {
		BuildingBase.BuildingState.DESTROYED: &"rebuild",
		BuildingBase.BuildingState.CONSTRUCTING: &"",
		BuildingBase.BuildingState.BUILT: &"spawn",
	}
}

var _spawn_configs := {
	BARRACKS: {
		"unit_type": "Soldier",
		"cooldown": 1.0,
	},
}


func get_frames(building_type: StringName, state: int, player: int) -> Resource:
	if _visuals.has(building_type) and _visuals[building_type].has(state):
		var options := _visuals[building_type][state]
		if options.has(player):
			return options[player]
		return options.get(1, null)
	return null


func get_work_required(building_type: StringName) -> float:
	return _work_required.get(building_type, 0.0)


func get_interact_mode(building_type: StringName, state: int) -> StringName:
	if _interact_modes.has(building_type):
		return _interact_modes[building_type].get(state, &"")
	return &""


func get_spawn_config(building_type: StringName) -> Dictionary:
	return _spawn_configs.get(building_type, {})

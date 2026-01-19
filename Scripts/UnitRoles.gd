extends Node


const PLAYER := &"player"
const PEASANT := &"peasant"
const SOLDIER := &"soldier"
const ARCHER := &"archer"
const WORKER := &"worker"


var role_groups := {
	PLAYER: [
		&"Attackable",
		&"Player",
	],
	PEASANT: [
		&"Minions",
		&"Peasants",
		&"Interactable"
	],
	SOLDIER: [
		&"Minions",
		&"Attackable",
		&"Interactable"
	],
	ARCHER: [
		&"Minions",
		&"Attackable",
		&"Interactable"
	],
	WORKER: [
		&"Minions",
		&"Attackable",
		&"Interactable",
		&"Workers",
	],
}

func get_role_groups(role: StringName) -> Array:
	return role_groups.get(role, [])


# role -> player -> SpriteFrames
var frames := {
	PLAYER: {
		1: preload("res://Art/SpriteFrames/Player.tres"),
		2: preload("res://Art/SpriteFrames/Player.tres"),
	},
	PEASANT: {
		1: preload("res://Art/SpriteFrames/Peasant_Blue.tres"),
		2: preload("res://Art/SpriteFrames/Peasant_Red.tres"),
	},
	SOLDIER: {
		1: preload("res://Art/SpriteFrames/Soldier_Blue.tres"),
		2: preload("res://Art/SpriteFrames/Soldier_Red.tres"),
	},
	ARCHER: {
		1: preload("res://Art/SpriteFrames/Archer_Blue.tres"),
		2: preload("res://Art/SpriteFrames/Archer_Red.tres"),
	},
	WORKER: {
		1: preload("res://Art/SpriteFrames/Worker_Blue.tres"),
		2: preload("res://Art/SpriteFrames/Worker_Red.tres"),
	},
}

func get_frames(role: StringName, player: int) -> SpriteFrames:
	if frames.has(role) and frames[role].has(player):
		return frames[role][player]
	# fallback: player 1 if missing
	return frames.get(role, {}).get(1, null)


var weapons := {
	PLAYER: preload("res://Scenes/weapon_sword.tscn"),
	SOLDIER: preload("res://Scenes/weapon_sword.tscn"),
	ARCHER: preload("res://Scenes/weapon_bow.tscn"),
}

func get_weapon(role: StringName) -> PackedScene:
	return weapons.get(role)


var tacticals := {
	PEASANT: TacticalPeasant,
	SOLDIER: TacticalSoldier,
	ARCHER: TacticalArcher,
	WORKER: TacticalWorker,
}

func get_tactical(role: StringName) -> GDScript:
	return tacticals.get(role)


var taskers := {
	PEASANT: MinionTasker,
	WORKER: MinionTasker,
}

func get_tasker(role: StringName) -> GDScript:
	return taskers.get(role)

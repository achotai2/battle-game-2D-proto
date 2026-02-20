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


var weapons := {
	UnitType.PLAYER: preload("res://Scenes/Weapons/weapon_sword.tscn"),
	UnitType.SOLDIER: preload("res://Scenes/Weapons/weapon_sword.tscn"),
	UnitType.ARCHER: preload("res://Scenes/Weapons/weapon_bow.tscn"),
}

func get_weapon(role: UnitType) -> PackedScene:
	return weapons.get(role)


var taskers := {
	UnitType.PEASANT: MinionTasker,
	UnitType.WORKER: MinionTasker,
}

func get_tasker(role: UnitType) -> GDScript:
	return taskers.get(role)


var tasker_kinds := {
	UnitType.PEASANT: CastleJobBoard.JobBoardType.PEASANTS,
	UnitType.WORKER: CastleJobBoard.JobBoardType.WORKERS,
}

func get_tasker_kind(role: UnitType) -> Variant:
	return tasker_kinds.get(role, null)

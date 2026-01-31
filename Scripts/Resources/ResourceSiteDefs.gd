class_name ResourceSiteDefs
extends Node

enum ResourceType {
	GOLD,
	FOOD,
	SHEEP,
	WOOD,
	METAL,
}

# TODO: Create scenes for FOOD, WOOD, and METAL and update the paths below.
# Current paths are set to null as placeholders.
const RESOURCES := {
	ResourceType.GOLD: preload("res://Scenes/Resources/Gold.tscn"),
	ResourceType.FOOD: preload("res://Scenes/Resources/Food.tscn"),
	ResourceType.SHEEP: preload("res://Scenes/Resources/Sheep.tscn"),
	ResourceType.WOOD: null, # TODO: preload("res://Scenes/Wood.tscn")
	ResourceType.METAL: null, # TODO: preload("res://Scenes/Metal.tscn")
}

static func get_scene(type: ResourceType) -> PackedScene:
	return RESOURCES.get(type, null)

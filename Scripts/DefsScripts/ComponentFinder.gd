class_name ComponentFinder extends RefCounted

# The 'static' keyword means this function belongs to the class itself, 
# not to any specific instance. You can call it from anywhere!
static func get_component(starter_node: Node, target_name: String) -> Node:
	var root = get_base(starter_node)
	
	if root == null: 
		return null
		
	# 2. Look down through all folders to find the specific component
	return root.find_child(target_name, true, false)


static func get_base(starter_node: Node) -> Node:
	var current = starter_node.get_parent()
	var root = current
	
	# 1. Walk up to the top of the unit
	# (Checking for PhysicsBody3D covers both CharacterBody3D units and StaticBody3D buildings)
	while current != null:
		root = current
		if current is AgentBase or current is BuildingBase:
			break
		current = current.get_parent()

	return root

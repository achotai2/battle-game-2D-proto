class_name ComponentFinder extends RefCounted

# The 'static' keyword means this function belongs to the class itself, 
# not to any specific instance. You can call it from anywhere!
static func get_component(starter_node: Node, target_class: String) -> Node:
	var root := get_base(starter_node)
	if root == null: 
		return null
		
	# 2. Search by CLASS TYPE, ignoring the node's actual name!
	# "*" means "I don't care what the node's name is."
	# target_class is the class_name we are looking for.
	var matching_nodes = root.find_children("*", target_class, true, false)
	
	# 3. Return the first one we find
	if matching_nodes.size() > 0:
		return matching_nodes[0]
		
	return null


static func get_base(starter_node: Node) -> Node:
	var current = starter_node
	var root = current
	
	# 1. Walk up to the top of the unit
	# (Checking for PhysicsBody3D covers both CharacterBody3D units and StaticBody3D buildings)
	while current != null:
		root = current
		if current is AgentBase or current is BuildingBase:
			break
		current = current.get_parent()

	return root

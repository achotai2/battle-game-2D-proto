class_name ComponentFinder extends RefCounted


static func get_component_by_name(starter_node: Node, target_name: String) -> Node:
	var root := get_base(starter_node)
	if root == null: 
		return null
		
	# Search by EXACT NODE NAME, ignoring the class type.
	# Parameter 1: target_name (The name we want)
	# Parameter 2: "" (We don't care what class it is)
	var matching_nodes = root.find_children(target_name, "", true, false)
	
	# Loop through all matches and return the first one that is NOT in the trash
	for node in matching_nodes:
		if not node.is_queued_for_deletion():
			return node
			
	return null
	

static func get_component(starter_node: Node, target_class: String) -> Node:
	var root := get_base(starter_node)
	if root == null: 
		print_debug("Could not find base node from ", starter_node)
		return null
		
	# Search by CLASS TYPE, ignoring the node's actual name.
	var matching_nodes = root.find_children("*", target_class, true, false)
	
	# Loop through all matches and return the first one that is NOT in the trash
	for node in matching_nodes:
		if not node.is_queued_for_deletion():
			return node
	
	print_debug("Could not find node ", target_class, " from ", starter_node)
	return null


static func get_base(starter_node: Node) -> Node:
	var current = starter_node
	var root = current
	
	# Walk up to the top of the unit
	while current != null:
		root = current
		if current is AgentBase or current is BuildingBase:
			break
		current = current.get_parent()

	return root

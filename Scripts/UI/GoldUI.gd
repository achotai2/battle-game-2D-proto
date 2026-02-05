extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Find player GoldHolder node.
	var player = get_tree().get_first_node_in_group("Player")

	if is_instance_valid(player) and is_instance_valid(player.gold):
		if not player.gold.goldChanged.is_connected(_update_gold_display):
			player.gold.goldChanged.connect(_update_gold_display)


func _update_gold_display(gold: int) -> void:
	text = "Gold: %d" % gold

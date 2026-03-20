extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Find player GoldHolder node.
	var player = get_tree().get_first_node_in_group("Player")
	if not player: return

	var goldWallet: GoldWallet = player.get("gold_wallet")
	if not goldWallet: return

	if not goldWallet.gold_changed.is_connected(_update_gold_display):
		goldWallet.gold_changed.connect(_update_gold_display)


func _update_gold_display(gold: int) -> void:
	text = "Gold: %d" % gold

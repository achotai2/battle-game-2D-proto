extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# We need to wait for the GoldWallet to be initialized,
	# so we will check for it in _process.
	set_process(true)


func _process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if not player: return

	var goldWallet: GoldWallet = player.get("gold_wallet")
	if not goldWallet: return

	if not goldWallet.gold_changed.is_connected(_update_gold_display):
		goldWallet.gold_changed.connect(_update_gold_display)

	# Call it once to initialize the display
	_update_gold_display(goldWallet.get_gold())

	# Stop polling once we've successfully connected
	set_process(false)


func _update_gold_display(gold: int) -> void:
	text = "Gold: %d" % gold

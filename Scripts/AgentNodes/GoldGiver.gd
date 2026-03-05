extends Node
class_name GoldGiver


func give_gold(target: Node3D, amount: int) -> bool:
	# Find target wallet
	var target_wallet: GoldWallet = ComponentFinder.get_component(target, "GoldWallet")

	if target_wallet:
		target_wallet.add_gold(amount)
		return true

	return false

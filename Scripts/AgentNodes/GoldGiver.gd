extends Node
class_name GoldGiver

@export var agent: AgentBase

func give_gold(target: Node, amount: int) -> bool:
	if not agent:
		return false

	# Assume agent has gold property pointing to GoldWallet, or find it
	var my_wallet: GoldWallet = null
	if "gold" in agent and agent.gold is GoldWallet:
		my_wallet = agent.gold
	else:
		my_wallet = agent.find_child("GoldWallet", true, false)

	if not my_wallet:
		return false

	if my_wallet.get_gold() < amount:
		return false

	# Find target wallet
	var target_wallet: GoldWallet = null
	if "gold" in target and target.gold is GoldWallet:
		target_wallet = target.gold
	elif target.has_node("Memory/GoldWallet"):
		target_wallet = target.get_node("Memory/GoldWallet")
	elif target.has_node("GoldWallet"):
		target_wallet = target.get_node("GoldWallet")

	if target_wallet:
		my_wallet.subtract_gold(amount)
		target_wallet.add_gold(amount)
		return true

	return false

extends Node
class_name Health

signal damaged
signal died

@export_range(1, 50, 1) var max_hp: int = 3
@export_range(0, 100, 1) var defense: int = 10

var hp: int

func _ready() -> void:
	hp = max_hp

func deactivate() -> void:
	pass

func activate() -> void:
	pass

func return_health() -> int:
	return hp

func is_dead() -> bool:
	return hp <= 0

func apply_hit(attack: AttackData) -> bool:
	# returns true if it penetrated (removed 1 HP)
	if hp <= 0:
		return false

	var penetrated := _roll_penetration(attack.attack_power, defense)

	if penetrated:
		hp -= 1
		damaged.emit()
		if hp <= 0:
			died.emit()
		return true
	else:
		#damaged.emit(hp, false, attack)
		return false


func _roll_penetration(attack_power: int, def: int) -> bool:
	# You can tune this. This version is smooth and intuitive:
	#   p = attack / (attack + defense)   (with small offsets to avoid 0/0)
	# Examples:
	#  attack=10 def=10 => 50%
	#  attack=20 def=10 => 67%
	#  attack=5  def=15 => 25%
	var a: int = max(0, attack_power)
	var d: int = max(0, def)
	var p: float = float(a + 1) / float(a + d + 2)
	return randf() < p

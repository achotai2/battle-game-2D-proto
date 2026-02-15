extends Area2D
class_name AgentTracking

signal target_changed(new_target: Node2D)
signal target_lost()

enum TargetKind { ATTACKABLE, INTERACTABLE }

@export var my_agent: Node2D
@export var target_kind: TargetKind = TargetKind.ATTACKABLE

# --- Team Logic ---
# 0 = Neutral, 1 = Team 1, 2 = Team 2
@export var my_team_id: int = 1 
@export var target_same_team: bool = false
@export var target_opposing: bool = true
@export var target_neutral: bool = true

# --- Tuning ---
@export_enum("Nearest", "Lowest Health") var target_bias: String = "Nearest"
@export_range(0.1, 2.0) var scan_interval: float = 0.5

var current_target: Node2D = null
var _timer: Timer


func _ready() -> void:
	# 1. Setup the Timer
	_timer = Timer.new()
	_timer.wait_time = scan_interval
	_timer.autostart = true
	_timer.one_shot = false
	_timer.timeout.connect(_scan_for_targets)
	add_child(_timer)
	
	# Stagger start to prevent lag spikes
	_timer.start(scan_interval + randf() * 0.2)
	
	# 2. Setup Collision Mask (The Logic Replacement)
	_update_collision_mask()


func _update_collision_mask() -> void:
	# Reset mask (scan nothing)
	collision_mask = 0 
	
	collision_layer = GamePhysics.get_mask_bit(GamePhysics.LAYER_TRACKING)

	if target_kind == TargetKind.ATTACKABLE:
		collision_mask = GamePhysics.get_tracking_mask(my_team_id, target_neutral, target_opposing, target_same_team)


func _scan_for_targets() -> void:
	# 1. Get pre-filtered list from Physics Engine (Fast C++)
	var bodies = get_overlapping_bodies()
	
	if bodies.is_empty():
		if current_target != null:
			current_target = null
			target_lost.emit()
		return

	# 2. Find the best target
	var best_target = null
	var best_score = INF
	
	var my_pos = global_position
	
	for body in bodies:
		# Sanity check (ignore self or dead units)
		if body == my_agent or not is_instance_valid(body):
			continue
			
		# Optional: Keep your Group check if you have non-unit physics bodies
		# if not body.is_in_group("Attackable"): continue

		var score = 0.0
		
		# --- Scoring Logic ---
		if target_bias == "Nearest":
			score = my_pos.distance_squared_to(body.global_position)
		elif target_bias == "Lowest Health":
			# Assuming body has a 'health' node or property
			if body.has_method("get_health_percent"):
				score = body.get_health_percent()
			else:
				score = 100.0 # Deprioritize non-health objects
		
		if score < best_score:
			best_score = score
			best_target = body

	# 3. Update State
	if best_target != current_target:
		current_target = best_target
		target_changed.emit(current_target)


# ---- Public API ----

func force_scan() -> void:
# For manual refreshing if needed
	_scan_for_targets()


func setup_player(player: int) -> void:
# Set team id and update collision mask.
	my_team_id = player
	_update_collision_mask()

extends Node2D

@export_group("Setup")
# Optional: Assign the main body node here to auto-sync animations
@export var main_body_path: NodePath
@onready var main_body = get_node_or_null(main_body_path)

func _process(_delta):
	# 1. SYNC ANIMATION (Optional)
	# If you assigned a Main Body, copy its frame data
	if main_body:
		if "animation" in main_body and "animation" in self:
			self.animation = main_body.animation
		if "frame" in main_body and "frame" in self:
			self.frame = main_body.frame
		if "flip_h" in main_body and "flip_h" in self:
			self.flip_h = main_body.flip_h

	# 2. READ FROM GLOBAL SUN
	# We access the variables we just created in the GlobalSun script
	var angle_rad = deg_to_rad(Sun.current_sun_angle)
	var length = Sun.current_shadow_length
	var width = Sun.shadow_width

	# 3. CALCULATE PROJECTION VECTOR
	# This determines where the "Head" of the shadow lands
	var shadow_vec = Vector2(sin(angle_rad), -cos(angle_rad)) * length

	# 4. CONSTRUCT TRANSFORM MATRIX
	# We manually build the X and Y axes of this node to project it flat.
	
	# X-AXIS (Width): 
	# We keep this horizontal (1, 0) so the shadow doesn't get skinny.
	transform.x = Vector2(width, 0.0)
	
	# Y-AXIS (Height):
	# We force the Y-axis to lie along the shadow vector.
	# We negate shadow_vec because Godot's Y is Down (positive), 
	# but we want to project 'Up' relative to the feet.
	transform.y = -shadow_vec 

	# 5. POSITION LOCK
	# Ensure the shadow stays anchored to (0,0) of its parent/origin
	position = Vector2.ZERO

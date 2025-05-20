extends Camera2D

@export var shake_decay: float = 12.0

# Add shake variables
var shake_amount: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var shake_intensity: float = 0.0
var shake_direction: Vector2 = Vector2.ZERO
var shake_offset: Vector2 = Vector2.ZERO

# Camera push variables
var push_offset: Vector2 = Vector2.ZERO
var push_target: Vector2 = Vector2.ZERO
var push_timer: float = 0.0
var push_duration: float = 0.0

# Add a proper shake method
func shake(duration: float = 0.2, amount: float = 10.0, intensity: float = 5.0, direction: Vector2 = Vector2.ZERO):
	shake_amount = amount
	shake_intensity = intensity
	shake_duration = duration
	shake_timer = 0.0
	shake_direction = direction.normalized()
	
	print("Camera shake triggered: ", amount, " duration: ", duration)

func push_in_direction(direction: Vector2, amount: float = 40.0, duration: float = 0.15):
	push_target = direction.normalized() * amount
	push_offset = push_target
	push_timer = 0.0
	push_duration = duration

func _process(delta):
	# Camera push logic
	if push_timer < push_duration:
		push_timer += delta
		var t = clamp(push_timer / push_duration, 0.0, 1.0)
		# Ease out for smooth return
		push_offset = push_target.lerp(Vector2.ZERO, t)
	else:
		push_offset = Vector2.ZERO
	
	# Process shake
	shake_offset = Vector2.ZERO
	if shake_timer < shake_duration:
		shake_timer += delta
		
		# Calculate shake strength that falls off over time
		var strength = shake_amount * (1.0 - (shake_timer / shake_duration))
		
		# Apply random shake or directional shake
		if shake_direction == Vector2.ZERO:
			# Random shake in all directions
			shake_offset = Vector2(
				randf_range(-1.0, 1.0) * strength, 
				randf_range(-1.0, 1.0) * strength
			)
		else:
			# Directional shake with randomness
			var perpendicular = Vector2(shake_direction.y, -shake_direction.x)
			shake_offset = shake_direction * strength * randf_range(0.8, 1.0)
			shake_offset += perpendicular * strength * 0.3 * randf_range(-1.0, 1.0)
	
	# Combine push and shake effects
	offset = push_offset + shake_offset

extends CharacterBody2D

# Set your movement speed (pixels per second)
var speed := 200
var jump_velocity := -400 # Adjust as needed for your jump height
var gravity := 900 # Adjust as needed
var jump_gravity := 1800 # Extra gravity when jump is released

# Player health variables
var max_health := 100
var current_health := 100
var is_invincible := false
var invincibility_time := 1.0
var invincibility_timer := 0.0
var knockback_force := 400
var is_alive := true

# Dash variables
var dash_speed := 1500  # Increased from 1200 for faster dash
var dash_duration := 0.25  # Slightly increased duration
var dash_cooldown := 0.3
var can_dash := true
var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := 0  # Store dash direction
var dash_frame := 0  # Track dash animation frame
var afterimages = []  # Store afterimage sprites
var max_afterimages = 8  # Increased from 6 to 8 for more visual effect
var afterimage_spacing = 0.015  # Decreased from 0.02 for more frequent afterimages
var last_afterimage_time = 0.0  # Track when we last created an afterimage
var screen_shake_intensity := 0.0  # For screen shake effect
var motion_blur := 0.0  # For motion blur effect

# New dash momentum variables
var dash_momentum_speed := 500  # Increased from 400 for stronger momentum feeling
var dash_momentum_duration := 0.15  # Increased from 0.1
var dash_momentum_timer := 0.0
var is_in_momentum := false

# New dash wind-up variables
var dash_windup_duration := 0.03  # Keep faster wind-up
var dash_windup_timer := 0.0
var is_winding_up := false

var jump_start_timer = 0.0
const JUMP_START_DURATION = 0.12
var was_on_floor = true
var y_velocity_at_impact_check: float = 0.0

var dash_slowdown_timer := 0.0
var dash_slowdown_duration := 0.1
var dash_slowdown_active := false

var dash_time_tween: Tween = null

# Add a timer for echo spawning during dash
var echo_trail_timer := 0.0
var echo_trail_interval := 0.05  # seconds between echoes

# Add variables for dash animation frame cycling
var dash_anim_frames = [4, 5, 2, 0]  # Using jump frames for dash in specific order, adding frame 0 at the end
var dash_anim_index = 0
var dash_anim_timer := 0.0
var dash_anim_interval := 0.04  # Faster interval for jump sequence
var dash_start_frames = [0, 1, 2]  # Running animation frames for dash start
var dash_start_index = 0
var dash_start_timer := 0.0
var is_dash_start := false

# Attack variables
var attack_damage_1 := 10
var attack_damage_2 := 15 
var attack_damage_3 := 20
var attack_cooldown := 0.3
var attack_cooldown_timer := 0.0
var can_attack := true

# Parry variables
var can_parry := true
var parry_window := 0.2
var parry_cooldown := 0.5
var parry_cooldown_timer := 0.0
var is_parrying := false
var parry_active_timer := 0.0
var parry_counter_damage := 25

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_collision: CollisionShape2D = $jumpCollisionShape2D
@onready var run_collision: CollisionPolygon2D = $runCollisionPolygon2D
@onready var idle_collision: CollisionPolygon2D = $idleCollisionPolygon2D
@onready var attack_collision: CollisionShape2D = $attackCollisionShape2D
@onready var SpeedLines: CPUParticles2D = $Camera2D/SpeedLines

# New attack collision nodes
@onready var attacks_node = $attacks
@onready var attack_1_collision = $attacks/Attack_1_CollisionPolygon2D
@onready var attack_2_collision = $attacks/Attack_2_CollisionPolygon2D 
@onready var attack_3_collision = $attacks/Attack_3_CollisionPolygon2D

# Add signals for game events
signal health_changed(new_health, max_health)
signal player_died
signal attack_hit(attack_type, attack_position)

func _ready():
	print("Available animations: ", sprite.sprite_frames.get_animation_names())
	sprite.animation_finished.connect(_on_animation_finished)
	# Add the player to "player" group for easy identification
	add_to_group("player")
	# Emit initial health
	health_changed.emit(current_health, max_health)
	
	# Initialize attack collisions
	disable_all_attack_collisions()

func _on_animation_finished():
	# Reset any attack-related states when animation finishes
	if sprite.animation.begins_with("attack"):
		disable_all_attack_collisions()
		attack_cooldown_timer = attack_cooldown
		can_attack = false
	
	# Handle parry animation completion
	if sprite.animation == "protection":
		is_parrying = false

func _physics_process(delta):
	if not is_alive:
		return
		
	# Handle attack cooldown
	if not can_attack:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer <= 0:
			can_attack = true
	
	# Handle parry cooldown
	if not can_parry:
		parry_cooldown_timer -= delta
		if parry_cooldown_timer <= 0:
			can_parry = true
	
	# Handle active parry window
	if is_parrying:
		parry_active_timer -= delta
		if parry_active_timer <= 0:
			is_parrying = false
		
	# Handle invincibility frames
	if is_invincible:
		invincibility_timer -= delta
		# Flash the sprite during invincibility
		sprite.modulate.a = 0.5 if int(invincibility_timer * 10) % 2 == 0 else 1.0
		
		if invincibility_timer <= 0:
			is_invincible = false
			sprite.modulate.a = 1.0
	
	var direction = 0

	# Check if we're currently in an attack animation or parrying
	var is_attacking = sprite.animation.begins_with("attack") and sprite.is_playing()
	var is_animation_locked = is_attacking or (sprite.animation == "protection" and sprite.is_playing())

	# Handle dash cooldown
	if not can_dash:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0:
			can_dash = true

	# Handle dash wind-up
	if is_winding_up:
		if dash_windup_timer == null:
			dash_windup_timer = 0.0
		dash_windup_timer -= delta
		if dash_windup_timer <= 0:
			is_winding_up = false
			is_dashing = true
			is_dash_start = true  # Start with running animation
			dash_start_timer = dash_anim_interval
			dash_start_index = 0
			sprite.play("run")  # Start with run animation
			sprite.frame = dash_start_frames[0]  # Start with first run frame
			if dash_timer == null:
				dash_timer = 0.0
			dash_timer = dash_duration
			can_dash = false
			dash_cooldown_timer = dash_cooldown
			dash_frame = 0
			$Camera2D.push_in_direction(Vector2(dash_direction, 0), 70.0, 0.15)
			print("Dashing!")
			$Camera2D/SpeedLines.scale.x = -dash_direction
			$Camera2D/SpeedLines.emitting = true
			if dash_time_tween:
				dash_time_tween.kill()
			dash_time_tween = create_tween()
			dash_time_tween.tween_property(Engine, "time_scale", 0.7, 0.02).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			dash_time_tween.tween_property(Engine, "time_scale", 1.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			dash_slowdown_timer = dash_slowdown_duration
			dash_slowdown_active = true
			echo_trail_timer = 0.0  # Reset echo trail timer
			dash_anim_index = 0
			dash_anim_timer = 0.0

	# Handle dash duration (continuous echo trail)
	if is_dashing:
		if dash_timer == null:
			dash_timer = 0.0
		dash_timer -= delta

		# Handle dash start animation
		if is_dash_start:
			dash_start_timer -= delta
			if dash_start_timer <= 0.0:
				sprite.play("run")
				sprite.frame = dash_start_frames[dash_start_index]
				dash_start_index = (dash_start_index + 1) % dash_start_frames.size()
				dash_start_timer = dash_anim_interval
				if dash_start_index == 0:  # After one complete cycle
					is_dash_start = false
					dash_anim_index = 0
					dash_anim_timer = 0.0
					sprite.play("jump")  # Switch to jump animation
					sprite.frame = dash_anim_frames[0]  # Start with first jump frame
		else:
			# Dash animation frame cycling
			dash_anim_timer -= delta
			if dash_anim_timer <= 0.0:
				sprite.play("jump")  # Use jump animation
				sprite.frame = dash_anim_frames[dash_anim_index]
				dash_anim_index = (dash_anim_index + 1) % dash_anim_frames.size()
				dash_anim_timer = dash_anim_interval
				# Reset animation index when dash is about to end
				if dash_timer <= dash_anim_interval:
					dash_anim_index = 0

		# Spawn echo at intervals during dash
		echo_trail_timer -= delta
		if echo_trail_timer <= 0.0:
			create_burst_echo(global_position, 1, 1)  # Use idx=1, total=1 for full opacity
			echo_trail_timer = echo_trail_interval

		if dash_timer <= 0:
			is_dashing = false
			dash_frame = 0
			sprite.scale = Vector2(1, 1)  # Reset scale
			sprite.rotation = 0.0  # Reset rotation
			$Camera2D/SpeedLines.emitting = false
			motion_blur = 0.0  # Reset motion blur
			# Start momentum phase
			is_in_momentum = true
			if dash_momentum_timer == null:
				dash_momentum_timer = 0.0
			dash_momentum_timer = dash_momentum_duration
			# Add impact effect
			$Camera2D.push_in_direction(Vector2(dash_direction, 0), 30.0, 0.1)
		else:
			# No sprite stretching during dash
			sprite.scale = Vector2(1, 1)
			# Add slight screen stretch in dash direction
			var screen_stretch = lerp(1.1, 1.0, dash_timer / dash_duration)
			$Camera2D.scale = Vector2(
				screen_stretch if dash_direction > 0 else 1.0,
				screen_stretch if dash_direction < 0 else 1.0
			)
			$Camera2D/SpeedLines.emitting = true
			$Camera2D/SpeedLines.scale.x = -dash_direction
			$Camera2D/SpeedLines.scale.y = 1.0

	# Handle dash momentum
	if is_in_momentum:
		if dash_momentum_timer == null:
			dash_momentum_timer = 0.0
		dash_momentum_timer -= delta
		if dash_momentum_timer <= 0:
			is_in_momentum = false
		else:
			# Gradually reduce speed during momentum phase
			var momentum_progress = dash_momentum_timer / dash_momentum_duration
			velocity.x = dash_direction * dash_momentum_speed * momentum_progress

	# Failsafe for Engine.time_scale
	if not is_dashing and not is_in_momentum and not is_winding_up:
		if Engine.time_scale != 1.0:
			Engine.time_scale = 1.0
		# If time_scale was potentially corrected, ensure dash_slowdown_active is false too,
		# as its corresponding timer might have been stalled if time_scale was very low.
		# This prevents dash_slowdown_active's logic from redundantly running after a manual fix.
		if dash_slowdown_active: # Only change if it was true
			dash_slowdown_active = false

	# Only process movement input if not in locked animation
	if not is_animation_locked:
		if Input.is_action_pressed("move_left"):
			direction -= 1
		if Input.is_action_pressed("move_right"):
			direction += 1

	# Handle dash input
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing and not is_winding_up and direction != 0:
		# Create an initial burst effect at the start position
		for i in range(3):
			create_burst_echo(global_position, i, 3)
		
		is_winding_up = true
		dash_windup_timer = dash_windup_duration
		dash_direction = direction  # Store the direction when dash starts
		
		# Add wind-up effect
		sprite.scale = Vector2(0.85, 1.15)  # More pronounced compression
		sprite.rotation = -0.15 * dash_direction  # More noticeable rotation
		$Camera2D.push_in_direction(Vector2(-dash_direction, 0), 30.0, 0.05)  # Stronger camera push
		
		# Add a subtle screen freeze for anticipation
		Engine.time_scale = 0.8
		await get_tree().create_timer(0.02 * Engine.time_scale).timeout
		Engine.time_scale = 1.0

	# Handle parry input
	if Input.is_action_just_pressed("protection") and can_parry and not is_animation_locked:
		attempt_parry()

	# Handle movement
	if is_dashing:
		velocity.x = dash_direction * dash_speed
	elif not is_in_momentum:  # Only apply normal movement if not in momentum
		velocity.x = direction * speed

	# Sprite flipping
	if direction < 0:
		sprite.flip_h = true
		run_collision.scale.x = -1
		idle_collision.scale.x = -1
		# Update attack collisions based on direction
		update_attack_collisions_direction(true)
	elif direction > 0:
		sprite.flip_h = false
		run_collision.scale.x = 1
		idle_collision.scale.x = 1
		# Update attack collisions based on direction
		update_attack_collisions_direction(false)

	# Store y-velocity before collision processing for landing animation decision
	y_velocity_at_impact_check = velocity.y

	# --- JUMP LOGIC ---
	var intent_jump = Input.is_action_just_pressed("jump") and is_on_floor()

	if intent_jump:
		velocity.y = jump_velocity
		jump_start_timer = JUMP_START_DURATION

	# Variable jump height logic
	if velocity.y < 0 and not Input.is_action_pressed("jump"):
		# If going up and jump is released, apply extra gravity
		velocity.y += jump_gravity * delta
	elif not is_on_floor():
		# Normal gravity when falling or holding jump
		velocity.y += gravity * delta

	move_and_slide()

	# Check if player is jumping on enemies (stomping)
	check_for_enemy_stomp()

	# Track landing state after move_and_slide
	var landed_this_frame = (not was_on_floor) and is_on_floor()
	was_on_floor = is_on_floor()

	# --- ANIMATION STATE MACHINE ---
	# Handle attack and parry inputs
	if not is_animation_locked:
		if Input.is_action_just_pressed("attack_1") and can_attack:
			sprite.play("attack_1")
			enable_attack_collision(1)
		elif Input.is_action_just_pressed("attack_2") and can_attack:
			sprite.play("attack_2")
			enable_attack_collision(2)
		elif Input.is_action_just_pressed("attack_3") and can_attack:
			sprite.play("attack_3")
			enable_attack_collision(3)
		elif is_dashing:
			# Dash animation is handled in the dash section above
			pass
		elif jump_start_timer > 0:
			jump_start_timer -= delta
			var progress = 1.0 - (jump_start_timer / JUMP_START_DURATION)
			if progress < 0.33:
				sprite.play("jump")
				sprite.frame = 0
			elif progress < 0.66:
				sprite.play("jump")
				sprite.frame = 1
			else:
				sprite.play("jump")
				sprite.frame = 2
		elif not is_on_floor():
			sprite.play("jump")
			if velocity.y < 0:
				if abs(velocity.y) > abs(jump_velocity) * 0.5:
					sprite.frame = 3
				else:
					sprite.frame = 4
			else:
				if abs(velocity.y) < speed * 0.5:
					sprite.frame = 5
				else:
					sprite.frame = 6
		elif landed_this_frame and sprite.animation == "jump":
			if abs(y_velocity_at_impact_check) >= speed * 0.9:
				sprite.play("jump")
				sprite.frame = 7
			else:
				sprite.play("jump")
				sprite.frame = 8
			if direction != 0:
				sprite.play("run")
			else:
				sprite.play("idle")
		elif direction != 0:
			sprite.play("run")
		else:
			sprite.play("idle")

	# --- COLLISION SHAPE MANAGEMENT ---
	# Disable all by default
	jump_collision.disabled = true
	run_collision.disabled = true
	idle_collision.disabled = true

	if jump_start_timer > 0 or not is_on_floor():
		jump_collision.disabled = false
	elif is_attacking:
		# Attack collisions are handled separately
		pass
	elif direction != 0:
		run_collision.disabled = false
	else:
		idle_collision.disabled = false

	# Handle dash slowdown timer
	if dash_slowdown_active:
		dash_slowdown_timer -= delta
		if dash_slowdown_timer <= 0.0:
			Engine.time_scale = 1.0
			dash_slowdown_active = false

# Disable all attack collision polygons
func disable_all_attack_collisions():
	if attack_1_collision:
		attack_1_collision.disabled = true
	if attack_2_collision:
		attack_2_collision.disabled = true
	if attack_3_collision:
		attack_3_collision.disabled = true
	if attack_collision:
		attack_collision.disabled = true

# Enable specific attack collision and check for hits
func enable_attack_collision(attack_num):
	# Disable all attack collisions first
	disable_all_attack_collisions()
	
	# Enable the corresponding collision polygon
	match attack_num:
		1:
			if attack_1_collision:
				attack_1_collision.disabled = false
				check_for_hit(attack_num, attack_damage_1)
		2:
			if attack_2_collision:
				attack_2_collision.disabled = false
				check_for_hit(attack_num, attack_damage_2)
		3:
			if attack_3_collision:
				attack_3_collision.disabled = false 
				check_for_hit(attack_num, attack_damage_3)

# Check for enemies hit by the attack
func check_for_hit(attack_num, damage_amount):
	# Schedule a physics process to detect hits
	await get_tree().process_frame
	
	# Get potential hit position
	var hit_position = global_position
	if sprite.flip_h:
		hit_position.x -= 50  # Left side
	else:
		hit_position.x += 50  # Right side
	
	# Emit signal for hit detection
	attack_hit.emit(attack_num, hit_position)
	
	# Find enemies in the scene
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		# Check if enemy overlaps with our attack collision
		var overlap_node = attack_1_collision
		if attack_num == 2:
			overlap_node = attack_2_collision
		elif attack_num == 3:
			overlap_node = attack_3_collision
			
		if is_enemy_in_attack_range(enemy, overlap_node):
			# Apply damage directly
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage_amount, global_position)
				print("Hit enemy with attack ", attack_num)

# Helper to check if an enemy is in attack range
func is_enemy_in_attack_range(enemy, collision_polygon):
	if not enemy or not collision_polygon or collision_polygon.disabled:
		return false
		
	# Simple distance check
	var attack_center = global_position
	var attack_range = 75  # Estimated range
	
	if sprite.flip_h:
		attack_center.x -= 30  # Adjust for left attacks
	else:
		attack_center.x += 30  # Adjust for right attacks
		
	var distance = enemy.global_position.distance_to(attack_center)
	
	# Check if enemy is in front of player (based on facing direction)
	var is_in_front = (sprite.flip_h and enemy.global_position.x < global_position.x) or \
					  (not sprite.flip_h and enemy.global_position.x > global_position.x)
	
	return distance < attack_range and is_in_front

# Update attack collision direction based on player facing
func update_attack_collisions_direction(flip_h):
	if attack_1_collision:
		attack_1_collision.scale.x = -1 if flip_h else 1
	if attack_2_collision:
		attack_2_collision.scale.x = -1 if flip_h else 1
	if attack_3_collision:
		attack_3_collision.scale.x = -1 if flip_h else 1

func spawn_dash_echoes():
	var echo_count = 5
	var echo_spacing = 24  # pixels between echoes
	for i in range(1, echo_count + 1):
		var offset = Vector2(dash_direction * i * echo_spacing, 0)
		create_burst_echo(global_position + offset, i, echo_count)

func create_burst_echo(position, idx = 0, total = 3):
	var echo = Sprite2D.new()
	echo.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	echo.global_position = position
	echo.scale = sprite.scale
	echo.rotation = sprite.rotation
	echo.flip_h = sprite.flip_h
	
	# Calculate the opacity based on the index and total
	var opacity = 0.7 * (1.0 - (float(idx) / float(total)))
	
	# Apply a stylistic color effect - blue trail for dash
	var echo_color = Color(0.7, 0.8, 1.0, opacity)
	echo.modulate = echo_color
	
	# Add glow effect
	var glow = RichTextEffect.new()
	echo.material = glow
	
	get_parent().add_child(echo)
	afterimages.append(echo)
	
	# Use a Tween for fade and scale
	var tween = create_tween()
	tween.tween_property(echo, "modulate", Color(0.7, 0.8, 1.0, 0), 0.3)
	tween.parallel().tween_property(echo, "scale", echo.scale * 1.2, 0.3)
	tween.tween_callback(func(): 
		if is_instance_valid(echo):
			echo.queue_free()
			if echo in afterimages:
				afterimages.erase(echo)
	)

func take_damage(amount, source_position = null):
	if is_invincible or not is_alive:
		return
		
	current_health -= amount
	health_changed.emit(current_health, max_health)
	
	# Apply knockback if source position is provided
	if source_position:
		var knockback_dir = (global_position - source_position).normalized()
		velocity = knockback_dir * knockback_force
	
	# Start invincibility
	is_invincible = true
	invincibility_timer = invincibility_time
	
	# Check for death immediately
	if current_health <= 0:
		die()
		return
	
	# Only play hurt animation if not dead
	sprite.play("hurt")
	await sprite.animation_finished
	
	# Return to previous animation if not dead
	if velocity.x != 0:
		sprite.play("run")
	else:
		sprite.play("idle")

func die():
	is_alive = false
	velocity = Vector2.ZERO
	
	print("Player died! Playing death animation.")
	
	# Play death animation
	sprite.play("death")
	
	# Disable collision
	jump_collision.set_deferred("disabled", true)
	run_collision.set_deferred("disabled", true)
	idle_collision.set_deferred("disabled", true)
	attack_collision.set_deferred("disabled", true)
	disable_all_attack_collisions()
	
	# Disable input processing
	set_process_input(false)
	
	# Emit signal
	player_died.emit()
	
	# Optional: restart level after delay
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

func heal(amount):
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
	
	# Play protection animation for healing visual feedback
	sprite.play("protection")
	await sprite.animation_finished
	
	# Return to previous animation
	if velocity.x != 0:
		sprite.play("run")
	else:
		sprite.play("idle")

# Add a new function to activate the protection animation (could be used for power-ups)
func activate_protection(duration = 5.0):
	is_invincible = true
	invincibility_timer = duration
	
	# Play protection animation
	sprite.play("protection")
	await sprite.animation_finished
	
	# Return to normal animation but keep invincibility active
	if velocity.x != 0:
		sprite.play("run")
	else:
		sprite.play("idle")

# Attempt to parry incoming attacks
func attempt_parry():
	is_parrying = true
	can_parry = false
	parry_active_timer = parry_window
	parry_cooldown_timer = parry_cooldown
	
	# Play protection animation for parry
	sprite.play("protection")
	
	# Short invincibility during parry
	is_invincible = true
	invincibility_timer = parry_window
	
	# Check for nearby enemies to counter attack
	await get_tree().create_timer(parry_window / 2).timeout
	if is_parrying:
		counter_attack()

# Counter attack after successful parry
func counter_attack():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var parry_range = 100
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var distance = global_position.distance_to(enemy.global_position)
		if distance <= parry_range:
			# Apply counter damage
			if enemy.has_method("take_damage"):
				enemy.take_damage(parry_counter_damage, global_position)
				
				# Apply stronger knockback
				var direction = (enemy.global_position - global_position).normalized()
				if enemy is CharacterBody2D:
					enemy.velocity = direction * knockback_force * 1.5

# Check if player is jumping on enemies (stomping)
func check_for_enemy_stomp():
	# Only check when player is falling
	if velocity.y > 0:
		# Get all collisions
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			
			# Check if collider is an enemy and we're hitting from above
			if collider is CharacterBody2D and collider.is_in_group("enemies") and collision.get_normal().y < -0.7:
				# Normal.y < -0.7 means we're hitting from above (with some tolerance)
				if collider.has_method("damaged_by_stomp"):
					collider.damaged_by_stomp(self)
					# Add a small bounce
					velocity.y = jump_velocity * 0.5
				break

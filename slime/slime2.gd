extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var detection_area = $DetectionArea
@onready var attack_area = $DetectionArea/AttackArea

const SPEED = 100.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var player = null
var can_attack = true
var facing_direction = "front" # 'front', 'back', 'left', 'right'
var state = "idle"
var attack_cooldown = 1.0
var attack_cooldown_timer = 0.0
var player_in_attack_range = false

# Enemy stats
var max_health = 50
var current_health = 50
var attack_damage = 10
var is_invincible = false
var invincibility_time = 0.3
var invincibility_timer = 0.0
var xp_value = 10  # XP given to player when defeated
var is_alive = true
var died_from_jump = false  # Track if killed by player jumping

# Physics properties
var mass = 5.0  # Higher mass makes it harder to push
var friction = 0.8  # Higher friction reduces sliding

# Direction change cooldown to prevent flickering
var direction_change_cooldown = 0.3
var direction_timer = 0.0
var last_direction = "front"

# Create an enum for state management
enum STATES {IDLE, WALK, ATTACK, HURT, DIE}
var current_state = STATES.IDLE

# Add signals
signal enemy_died(xp_value)
signal enemy_hit(enemy, damage)

func _ready():
	animated_sprite.play("idle_front")
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_area.body_exited.connect(_on_attack_area_body_exited)
	# Add to enemy group
	add_to_group("enemies")
	
	# Explicitly print debug info
	print("Slime added to 'enemies' group: ", is_in_group("enemies"))
	
	# Set collision properties
	set_collision_layer_value(2, true)  # Layer 2 for enemies
	set_collision_mask_value(1, true)   # Collide with layer 1 (environment)
	set_collision_mask_value(3, false)  # Don't collide with player attacks (layer 3)
	set_collision_mask_value(4, true)   # Collide with player (assuming player is on layer 4)
	
	print("Slime collision layer: ", get_collision_layer())
	print("Slime collision mask: ", get_collision_mask())

func _physics_process(delta):
	if not is_alive:
		return
		
	# Always apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle attack cooldown
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer <= 0:
			can_attack = true
			
	# Handle invincibility frames
	if is_invincible:
		invincibility_timer -= delta
		# Flash the sprite during invincibility
		animated_sprite.modulate.a = 0.5 if int(invincibility_timer * 10) % 2 == 0 else 1.0
		
		if invincibility_timer <= 0:
			is_invincible = false
			animated_sprite.modulate.a = 1.0
			
	# Update direction change timer
	if direction_timer > 0:
		direction_timer -= delta

	# State machine
	match current_state:
		STATES.IDLE:
			process_idle_state(delta)
		STATES.WALK:
			process_walk_state(delta)
		STATES.ATTACK:
			process_attack_state(delta)
		STATES.HURT:
			# Hurt state handled by animation signal
			pass
		STATES.DIE:
			# Death state handled by animation signal
			pass

	# Check for state transitions
	if current_state != STATES.ATTACK and current_state != STATES.HURT and current_state != STATES.DIE:
		if player_in_attack_range and can_attack:
			change_state(STATES.ATTACK)
		elif player and current_state != STATES.ATTACK:
			change_state(STATES.WALK)
		elif not player and current_state != STATES.IDLE:
			change_state(STATES.IDLE)
			
	# Apply friction to reduce sliding
	if current_state != STATES.WALK and is_on_floor():
		velocity.x = lerp(velocity.x, 0.0, friction)
		
	# Optimize movement to reduce lag
	if abs(velocity.x) < 5:
		velocity.x = 0
	if abs(velocity.y) < 5 and is_on_floor():
		velocity.y = 0
			
	move_and_slide()
	
	# Prevent extreme sliding due to player collision
	if get_slide_collision_count() > 0:
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			if collision.get_collider() is CharacterBody2D and collision.get_collider().is_in_group("player"):
				# Apply counter-force to resist being pushed
				velocity = velocity.bounce(collision.get_normal()) * 0.2

# Handle being damaged by player
func take_damage(amount, source_position = null):
	if is_invincible or not is_alive or current_state == STATES.DIE:
		return
		
	current_health -= amount
	enemy_hit.emit(self, amount)
	
	# Apply knockback if source position is provided
	if source_position:
		var knockback_dir = (global_position - source_position).normalized()
		velocity = knockback_dir * 150
	
	# Start invincibility
	is_invincible = true
	invincibility_timer = invincibility_time
	
	# Check for death immediately
	if current_health <= 0:
		die()
		return
	
	# Only enter hurt state if not dead
	change_state(STATES.HURT)

# Called when player jumps on slime
func damaged_by_stomp(player_obj):
	print("Slime damaged_by_stomp called!")
	
	# Set flag to indicate death by jump
	died_from_jump = true
	
	# Apply special visual effect before death
	animated_sprite.modulate = Color(1, 0.5, 0.5, 1)
	
	# Add a slight delay for visual feedback
	await get_tree().create_timer(0.05).timeout
	
	# Kill instantly with damage from above
	take_damage(current_health, player_obj.global_position) # Kill instantly
	
	# Create death particles/effect
	if is_instance_valid(self):
		# Optional: Create a splat effect
		animated_sprite.scale = Vector2(1.2, 0.8) # Squash effect
		
		# Make the player bounce
		if player_obj and player_obj.has_method("bounce"):
			print("Calling player bounce method")
			player_obj.bounce()

func die():
	# Mark as dead immediately to prevent any further state changes or movement
	is_alive = false
	current_state = STATES.DIE  # Set state directly to avoid potential state change blocking
	
	# Disable attack detection immediately
	player_in_attack_range = false
	can_attack = false
	
	# Emit signal for XP/score
	enemy_died.emit(xp_value)
	
	# Stop all movement
	velocity = Vector2.ZERO
	
	# Disable collision with player to prevent pushing
	set_collision_mask_value(2, false)
	
	# Disable collision shape for physics interactions
	$CollisionShape2D.set_deferred("disabled", true)
	
	# Play the appropriate death animation based on facing direction
	var death_anim = "death_" + facing_direction
	if animated_sprite.sprite_frames.has_animation(death_anim):
		animated_sprite.play(death_anim)
		# Start at frame 3 if killed by jumping on
		if died_from_jump and animated_sprite.sprite_frames.get_frame_count(death_anim) > 3:
			animated_sprite.frame = 3
	else:
		# Use any available death animation as fallback
		var available_death_anims = ["death_front", "death_back", "death_left", "death_right"]
		for anim in available_death_anims:
			if animated_sprite.sprite_frames.has_animation(anim):
				animated_sprite.play(anim)
				if died_from_jump and animated_sprite.sprite_frames.get_frame_count(anim) > 3:
					animated_sprite.frame = 3
				break
		if not animated_sprite.sprite_frames.has_animation(animated_sprite.animation):
			animated_sprite.play("idle_" + facing_direction)
			animated_sprite.modulate = Color(1, 0.5, 0.5, 0.5)
	
	# Wait for death animation to finish before removing
	await animated_sprite.animation_finished
	
	# Schedule cleanup
	await get_tree().create_timer(0.5).timeout
	queue_free()

func process_idle_state(_delta):
	velocity.x = 0
	if is_on_floor():
		velocity.y = 0
	animated_sprite.play("idle_" + facing_direction)

func process_walk_state(_delta):
	if not player:
		change_state(STATES.IDLE)
		return
		
	update_facing_direction()
	animated_sprite.play("run_" + facing_direction)
	
	var to_player = player.global_position - global_position
	
	# Horizontal movement - smoother approach
	if abs(to_player.x) > abs(to_player.y):
		velocity.y = 0
		var target_velocity = SPEED * sign(to_player.x)
		velocity.x = lerp(velocity.x, target_velocity, 0.2)  # Smoother acceleration
	# Vertical movement - smoother approach
	else:
		velocity.x = 0
		var target_velocity = SPEED * sign(to_player.y)
		velocity.y = lerp(velocity.y, target_velocity, 0.2)  # Smoother acceleration

func process_attack_state(_delta):
	# Attack is handled via animation signals
	pass

func change_state(new_state):
	# Don't change states if dead
	if not is_alive:
		return
		
	# Exit current state
	match current_state:
		STATES.ATTACK, STATES.HURT, STATES.DIE:
			# Don't interrupt these animations
			if animated_sprite.is_playing() and current_state != STATES.ATTACK:
				return
				
	# Enter new state
	var previous_state = current_state
	current_state = new_state
	
	match new_state:
		STATES.IDLE:
			velocity = Vector2.ZERO
			animated_sprite.play("idle_" + facing_direction)
		STATES.WALK:
			animated_sprite.play("run_" + facing_direction)
		STATES.ATTACK:
			start_attack()
		STATES.HURT:
			velocity = Vector2.ZERO
			# Play the appropriate hurt animation based on facing direction
			var hurt_anim = "hurt_" + facing_direction
			if animated_sprite.sprite_frames.has_animation(hurt_anim):
				animated_sprite.play(hurt_anim)
			else:
				animated_sprite.play("idle_" + facing_direction) # Fallback
			
			# Return to previous state after hurt animation completes
			await animated_sprite.animation_finished
			if is_alive and current_state == STATES.HURT:
				if player:
					change_state(STATES.WALK)
				else:
					change_state(STATES.IDLE)
		STATES.DIE:
			velocity = Vector2.ZERO
			# Death animations are handled in die() function

func start_attack():
	# Don't start attack if dead
	if not is_alive:
		return
		
	velocity = Vector2.ZERO
	can_attack = false
	attack_cooldown_timer = attack_cooldown
	
	# Update facing direction before attack
	if player:
		update_facing_direction()
	
	# Play attack animation
	var anim = "attack_" + facing_direction
	if not animated_sprite.sprite_frames.has_animation(anim):
		anim = "attack_front"
	
	animated_sprite.play(anim)
	
	# Connect to animation finished signal - use one-shot connection
	if animated_sprite.animation_finished.is_connected(on_attack_animation_finished):
		animated_sprite.animation_finished.disconnect(on_attack_animation_finished)
	animated_sprite.animation_finished.connect(on_attack_animation_finished, CONNECT_ONE_SHOT)

func on_attack_animation_finished():
	# Don't process attack completion if dead
	if not is_alive:
		return
		
	# Apply damage to player if still in range
	if player_in_attack_range and player and is_instance_valid(player):
		# Call the player's take_damage function
		player.take_damage(attack_damage, global_position)
	
	# Push away from player
	if player:
		var away_vector = (global_position - player.global_position).normalized()
		velocity = away_vector * SPEED
		global_position += away_vector * 15
	
	# Check if we should attack again
	if player_in_attack_range and can_attack:
		change_state(STATES.ATTACK)
	elif player:
		change_state(STATES.WALK)
	else:
		change_state(STATES.IDLE)

func update_facing_direction():
	if not player:
		return
		
	# Don't change direction if timer is still active
	if direction_timer > 0:
		return
		
	var to_player = player.global_position - global_position
	var new_direction = ""
	
	# Determine facing direction based on player position
	if abs(to_player.x) > abs(to_player.y):
		# Horizontal facing priority
		if to_player.x > 0:
			new_direction = "right"
		else:
			new_direction = "left"
	else:
		# Vertical facing priority
		if to_player.y > 0:
			new_direction = "front"
		else:
			new_direction = "back"
			
	# Only change direction if it's different and set cooldown
	if new_direction != facing_direction:
		facing_direction = new_direction
		direction_timer = direction_change_cooldown

func _on_detection_area_body_entered(body):
	if body.name == "player" and is_alive:
		player = body
		if current_state == STATES.IDLE:
			change_state(STATES.WALK)

func _on_detection_area_body_exited(body):
	if body.name == "player":
		player = null
		if current_state != STATES.ATTACK and is_alive:
			change_state(STATES.IDLE)

func _on_attack_area_body_entered(body):
	if body.name == "player" and is_alive:
		player_in_attack_range = true
		if can_attack and current_state != STATES.ATTACK:
			change_state(STATES.ATTACK)

func _on_attack_area_body_exited(body):
	if body.name == "player":
		player_in_attack_range = false

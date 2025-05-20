extends Area2D

enum CollectibleType { COIN, HEALTH, POWER_UP }

@export var type: CollectibleType = CollectibleType.COIN
@export var value: int = 1  # Value could be score for coins, health for health packs, etc.
@export var bob_height: float = 10.0
@export var bob_speed: float = 2.0

@onready var sprite = $AnimatedSprite2D
@onready var original_y = 0.0
@onready var collect_sound = $CollectSound
@onready var collision_shape = $CollisionShape2D

var time_passed = 0.0
var collected = false
var player_ref = null

# Add signals
signal item_collected(type, value)

func _ready():
	# Store original position for bobbing animation
	original_y = global_position.y
	
	# Setup visual based on type
	match type:
		CollectibleType.COIN:
			sprite.play("coin")
		CollectibleType.HEALTH:
			sprite.play("health")
		CollectibleType.POWER_UP:
			sprite.play("power_up")
			
	# Connect body entered signal
	body_entered.connect(_on_body_entered)

func _process(delta):
	if collected:
		return
		
	# Simple bobbing animation
	time_passed += delta
	var bob_offset = sin(time_passed * bob_speed) * bob_height
	global_position.y = original_y + bob_offset

func _on_body_entered(body):
	if collected or not body.is_in_group("player"):
		return
		
	collected = true
	player_ref = body
	
	# Apply effect based on collectible type
	match type:
		CollectibleType.COIN:
			# Find HUD and add score
			var hud = get_tree().get_first_node_in_group("hud")
			if hud:
				hud.add_score(value)
				
		CollectibleType.HEALTH:
			# Heal the player
			if player_ref.has_method("heal"):
				player_ref.heal(value)
				
		CollectibleType.POWER_UP:
			# Could implement different power-ups later
			pass
			
	# Play collection animation/sound
	collision_shape.set_deferred("disabled", true)
	
	# Play collection animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.chain().tween_callback(queue_free)
	
	# Play sound if available
	if collect_sound:
		collect_sound.play()
	
	# Emit signal for any listeners
	item_collected.emit(type, value) 
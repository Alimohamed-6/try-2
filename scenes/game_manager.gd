extends Node

# Game State Management
enum GameState { PLAYING, PAUSED, GAME_OVER }
var current_state = GameState.PLAYING

# Level Management
var current_level = 1
var max_level = 3

# References to important nodes
@onready var hud = $GameHUD
@onready var pause_menu = $PauseMenu
@onready var level_holder = $LevelHolder

# Player progression
var player_score = 0
var collected_coins = 0
var defeated_enemies = 0

# Add signals
signal game_state_changed(new_state)
signal level_completed(level_num)
signal enemy_defeated(enemy_type, position)

func _ready():
	# Add to game_manager group for easy access
	add_to_group("game_manager")
	
	# Initialize UI elements
	pause_menu.visible = false
	
	# Connect enemy signals
	connect_enemy_signals()

func _process(_delta):
	# Handle pause input
	if Input.is_action_just_pressed("pause"):
		toggle_pause()

func toggle_pause():
	if current_state == GameState.PLAYING:
		set_game_state(GameState.PAUSED)
	elif current_state == GameState.PAUSED:
		set_game_state(GameState.PLAYING)

func set_game_state(new_state):
	current_state = new_state
	
	match new_state:
		GameState.PLAYING:
			get_tree().paused = false
			pause_menu.visible = false
		GameState.PAUSED:
			get_tree().paused = true
			pause_menu.visible = true
		GameState.GAME_OVER:
			get_tree().paused = true
			# Game over handled by HUD
	
	game_state_changed.emit(new_state)

func on_player_died():
	set_game_state(GameState.GAME_OVER)

func connect_enemy_signals():
	# Wait a frame to ensure all nodes are loaded
	await get_tree().process_frame
	
	# Connect to all existing enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not enemy.enemy_died.is_connected(on_enemy_died):
			enemy.enemy_died.connect(on_enemy_died)

func on_enemy_died(xp_value):
	# Update score
	player_score += xp_value
	defeated_enemies += 1
	
	# Update HUD score
	if hud:
		hud.add_score(xp_value)
	
	# Check for level completion conditions
	check_level_completion()

func on_collectible_collected(type, value):
	match type:
		0: # COIN
			collected_coins += 1
			player_score += value
	
	# Check for level completion conditions
	check_level_completion()

func check_level_completion():
	# Example condition: collected all coins and defeated all enemies
	var required_enemies = 5  # Placeholder value
	var required_coins = 10   # Placeholder value
	
	if defeated_enemies >= required_enemies and collected_coins >= required_coins:
		complete_level()

func complete_level():
	# Show level completion UI
	print("Level " + str(current_level) + " completed!")
	
	# Emit signal
	level_completed.emit(current_level)
	
	# Check if this was the final level
	if current_level >= max_level:
		# Game completed
		print("Game completed!")
	else:
		# Prepare for next level
		current_level += 1
		# Could add a transition or loading screen here
		
func restart_game():
	# Reset all variables
	player_score = 0
	collected_coins = 0
	defeated_enemies = 0
	current_level = 1
	current_state = GameState.PLAYING
	
	# Reload the current scene
	get_tree().reload_current_scene()

func quit_to_menu():
	# Could transition to a main menu scene
	get_tree().quit() # For now, just quit 

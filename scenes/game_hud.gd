extends CanvasLayer

@onready var health_bar = $MarginContainer/HBoxContainer/HealthBar
@onready var health_text = $MarginContainer/HBoxContainer/HealthText
@onready var score_text = $MarginContainer/HBoxContainer/ScoreText
@onready var game_over_panel = $GameOverPanel

var player_score = 0

func _ready():
	# Initialize HUD elements
	health_bar.value = 100
	health_bar.max_value = 100
	health_text.text = "100/100"
	score_text.text = "Score: 0"
	game_over_panel.visible = false
	
	# Connect to player signals if player exists
	await get_tree().process_frame
	connect_to_player()

func connect_to_player():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_player_health_changed)
		player.player_died.connect(_on_player_died)
		
		# Set initial health values
		_on_player_health_changed(player.current_health, player.max_health)
	else:
		print("Error: No player found in the scene!")

func _on_player_health_changed(new_health, max_health):
	health_bar.max_value = max_health
	health_bar.value = new_health
	health_text.text = str(new_health) + "/" + str(max_health)
	
	# Update health bar color based on health percentage
	var health_percent = float(new_health) / float(max_health)
	if health_percent > 0.6:
		health_bar.modulate = Color(0.0, 1.0, 0.0) # Green
	elif health_percent > 0.3:
		health_bar.modulate = Color(1.0, 1.0, 0.0) # Yellow
	else:
		health_bar.modulate = Color(1.0, 0.0, 0.0) # Red

func _on_player_died():
	game_over_panel.visible = true
	$GameOverPanel/VBoxContainer/ScoreLabel.text = "Final Score: " + str(player_score)

func add_score(amount):
	player_score += amount
	score_text.text = "Score: " + str(player_score)

func _on_retry_button_pressed():
	# Restart the current scene
	get_tree().reload_current_scene()

func _on_quit_button_pressed():
	# Return to the main menu or quit the game
	get_tree().quit() 
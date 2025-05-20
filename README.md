# Godot 4 Platformer Game
# Godot 4 Platformer Project Documentation

This project is a 2D platformer game built with Godot 4. It features a player character with health and combat mechanics, enemy AI with states and animations, collectibles, a comprehensive HUD system, and game state management.

## Main Features

### Player
- **Location:** `player/character_body_2d.tscn`, `player/character_body_2d.gd`
- **Movement:** Standard platformer controls (walk, run, jump)
- **Dash Mechanics:** 
  - Fast dash with enhanced momentum and particle effects
  - Stylized blue afterimages with glow effects
  - Screen freeze and camera push during wind-up for anticipation
  - Smoother acceleration and deceleration
  - Visual feedback through character compression and rotation
- **Combat:** Multiple attack animations (attack_1, attack_2, attack_3)
- **Enemy Interactions:**
  - Can stomp on enemies by jumping on them from above
  - Jumping on slimes triggers a special death animation and gives a small bounce
- **Health System:** 
  - Health tracking with damage, healing, and death
  - Invincibility frames after taking damage
  - Visual feedback through hurt, death, and protection animations
- **Animations:** Includes idle, jump, run, walk, hurt, death, and protection animations
- **Camera:** Dynamic camera with push effects during dash and damage
- **Groups:** The player node is in the `player` group for enemy AI and collectible interactions

### Enemy: Slime AI
- **Location:** `slime/slime.tscn`, `slime/slime2.gd`
- **Node Structure:**
  ```
  slime (CharacterBody2D)
  ├─ AnimatedSprite2D
  ├─ CollisionShape2D
  ├─ DetectionArea (Area2D)
  │   ├─ CollisionShape2D
  │   └─ AttackArea (Area2D)
  │       └─ CollisionShape2D
  ```
- **State Machine:**
  - `IDLE`: Default state when no player detected
  - `WALK`: Active chase state when player is detected
  - `ATTACK`: Attack state when player is in range
  - `HURT`: Triggered when taking damage
  - `DIE`: Triggered when health reaches zero
- **Directional System:** 
  - Adapts facing direction based on player position (front, back, left, right)
  - Includes direction change cooldown to prevent animation flickering
- **Death Animations:**
  - Standard death animation when defeated by player attacks
  - Special death animation starting at frame 3 when player jumps on the slime
- **Health System:** Can take damage and die, with appropriate animation transitions
- **Attack System:** Attacks player when in range with cooldown mechanism
- **Physics Properties:**
  - Improved friction and mass to reduce sliding
  - Smoother acceleration when chasing player
  - Bounce effect to prevent being pushed around by player
- **Groups:** Added to the `enemies` group for game manager tracking

### Collectibles System
- **Location:** `scenes/collectible.tscn`, `scenes/collectible.gd`
- **Types:**
  - `COIN`: Adds to player score
  - `HEALTH`: Heals the player
  - `POWER_UP`: Framework for future power-up effects
- **Visual Effects:**
  - Bobbing animation for visibility
  - Collection animations with scaling and fading
  - Directional animations based on type
- **Interaction:** Detects player collision and applies appropriate effects
- **Groups:** Added to the `collectibles` group for game manager tracking

### HUD System
- **Location:** `scenes/game_hud.tscn`, `scenes/game_hud.gd`
- **Features:**
  - Dynamic health bar with color changes based on health percentage
  - Score counter for tracking points
  - Game over panel with retry and quit options
- **Signals:** Connects to player's health and death signals
- **Groups:** Added to the `hud` group for game manager and collectible access

### Game Manager
- **Location:** `scenes/game_manager.gd`
- **State Management:**
  - `PLAYING`: Normal gameplay state
  - `PAUSED`: Paused game state
  - `GAME_OVER`: End game state
- **Level Tracking:** Manages current level and tracks progression
- **Score System:** Tracks player score, defeated enemies, and collected coins
- **Level Completion:** Checks conditions and handles level transitions
- **Signal Connections:** Connects to enemy, collectible, and player signals

### Map System
- **Location:** `map/`
- **Structure:** Modular tilemaps and scenes for backgrounds, blocks, bridges, ground, water, and pickups
- **Tileset:** Custom tileset in `map/tileset.png` and `map/tileset.tres`
- **Main Map Scene:** `map/Map.tscn` and `scenes/main.tscn` for the main game world

### Art & Assets
- **Sprites:** Located in `sprites/` and subfolders (e.g., `Samurai/`, `slime mobs/`)
- **Animations:** Sprite sheets for all characters include directional variants for all states
- **Licensing:** See `sprites/Licens.txt` for asset usage rights

## Gameplay Systems in Detail

### Health and Damage System
- **Player Health:**
  - `max_health`: Maximum health value (default: 100)
  - `current_health`: Current health value
  - `is_invincible`: Flag for invincibility frames
  - `invincibility_time`: Duration of invincibility after damage (default: 1.0s)
  - `knockback_force`: Force applied when taking damage (default: 400)
  
- **Enemy Health:**
  - `max_health`: Maximum health (default: 50)
  - `current_health`: Current health value
  - `attack_damage`: Damage dealt to player (default: 10)
  - `xp_value`: Score value when defeated (default: 10)

- **Damage Functions:**
  - `take_damage(amount, source_position)`: Applies damage and knockback
  - `die()`: Handles death state and animations
  - `heal(amount)`: Restores health with visual feedback

### Animation Systems
- **Player Animations:**
  - Movement: idle, run, jump (with multiple frames for jump states)
  - Combat: attack_1, attack_2, attack_3
  - Status: hurt, death, protection
  
- **Slime Animations:**
  - Directional variants (_front, _back, _left, _right) for all states
  - Movement: idle, run
  - Combat: attack
  - Status: hurt, death

- **Animation Transitions:**
  - State-based transitions ensure proper animation sequencing
  - Animations connect to proper callbacks upon completion
  - Direction-specific animations reflect current facing direction

### Signal Systems
- **Player Signals:**
  - `health_changed(new_health, max_health)`: Emitted when health changes
  - `player_died`: Emitted on death
  
- **Enemy Signals:**
  - `enemy_died(xp_value)`: Emitted when enemy dies
  - `enemy_hit(enemy, damage)`: Emitted when enemy takes damage
  
- **Collectible Signals:**
  - `item_collected(type, value)`: Emitted when item is collected
  
- **Game Manager Signals:**
  - `game_state_changed(new_state)`: Emitted on game state changes
  - `level_completed(level_num)`: Emitted when level is completed
  - `enemy_defeated(enemy_type, position)`: Triggered by enemy death

## How the Game Works
1. The player moves, jumps, dashes, and attacks using standard platformer controls
2. Slime enemies detect the player, chase, and attack when close enough
3. The player can defeat enemies, triggering hurt and death animations
4. Collectibles provide score and health benefits
5. The HUD displays health and score information
6. The game manager tracks overall game state and level progression

## Customization & Extension
- **Add new enemies:** Duplicate the slime implementation and adjust behavior
- **Add new collectibles:** Extend the CollectibleType enum and add new effects
- **Create new power-ups:** Implement through the POWER_UP collectible type
- **Add new levels:** Create new scenes and update the level progression
- **Enhance player abilities:** Add new attack types or movement options

## Requirements
- Godot 4.x (tested with 4.4.1)
- Proper node structure and grouping for system interactions
- Animation naming conventions must be followed for direction-specific animations

## Troubleshooting
- **Enemy not transitioning states:** Check state machine conditions and signal connections
- **Animations not playing:** Verify animation names match exactly what's expected in code
- **Collectibles not working:** Ensure player is in the "player" group
- **HUD not updating:** Check signal connections and group assignments
- **Game manager not tracking progress:** Verify all required nodes are in their respective groups

## Recent Updates and Improvements

### Slime Movement and Animation
- **Direction Change Cooldown:** Added a 0.3-second cooldown between direction changes to prevent animation flickering when rapidly changing direction.
- **Smoother Movement:** Implemented gradual acceleration and deceleration for more natural movement.
- **Physics Improvements:** Added counter-force when colliding with the player to prevent excessive pushing and sliding.

### Player Dash Mechanism
- **Enhanced Visual Effects:**
  - Stylized blue afterimages with fading and scaling effects
  - Initial burst effect at dash start
  - More frequent afterimages during dash
- **Improved Dash Performance:**
  - Increased dash speed (1500) and slightly longer duration (0.25s)
  - Stronger momentum feeling after dash (500 speed, 0.15s duration)
  - More pronounced character compression and rotation for visual feedback
- **Animation Polishing:**
  - Better transitions between dash states (wind-up, dash, momentum)
  - Subtle screen freeze (0.8 time scale) for anticipation
  - Stronger camera push effects

### Enemy Interaction
- **Stomp Mechanism:** Added ability to jump on enemies from above, triggering special actions
- **Slime Death by Stomp:**
  - Special death animation starts at frame 3 when killed by jumping on it
  - Player receives a small upward bounce when successfully stomping on a slime
  - Flag system to track death cause and apply appropriate visual effects

### Bug Fixes
- Fixed animation flickering when slime changes direction rapidly
- Fixed slime continuing to attack after death
- Fixed slimes being pushed around too easily by the player
- Improved performance by reducing debug prints and optimizing collision detection

---

This documentation covers the structure, systems, and implementation details of the game. For specific implementation details, refer to the comments in each script file.

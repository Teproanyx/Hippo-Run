extends Node

#preload obstacles
var stump_scene = preload("res://scenes/stump.tscn")
var rock_scene = preload("res://scenes/rock.tscn")
var barrel_scene = preload("res://scenes/barrel.tscn")
var bird_scene = preload("res://scenes/bird.tscn")
var heart_item_scene = preload("res://scenes/heart.tscn")
var powerup_item_scene = preload("res://scenes/powerup.tscn")

var obstacle_types := [stump_scene, rock_scene, barrel_scene]
var obstacles : Array
var bird_heights := [200, 300]

#game variables
const DINO_START_POS := Vector2i(150, 485)
const CAM_START_POS := Vector2i(576, 324)
var difficulty
const DIFFICULTY_SCALER : int = 2000
const MAX_DIFFICULTY : int = 2
var score : int
const SCORE_MODIFIER : int = 10
var high_score : int
var speed : float
const START_SPEED : float = 5.0
const MAX_SPEED : int = 25
const SPEED_MODIFIER : int = 25000
var screen_size : Vector2i 
var ground_height : int
var game_running : bool
var last_obs
var hearts : int = 3
var has_power = false
var power_timer = 0.0
const POWER_DURATION = 3.0  # อยู่ได้ 5 วินาที
var last_item_x = -9999  # ใช้เก็บตำแหน่ง x ของไอเทมล่าสุด
var last_item_spawn_x := -9999
var last_heart_spawn_x := -9999
var last_power_spawn_x := -9999
const ITEM_MIN_DISTANCE := 5000
const HEART_ITEM_MIN_DISTANCE := 5000
const POWER_ITEM_MIN_DISTANCE := 10000
const MAX_HEARTS := 3
const LOW_BIRD := 425

# Called when the node enters the scene tree for the first time.
func _ready():
	screen_size = get_window().size
	ground_height = $Ground.get_node("Sprite2D").texture.get_height()
	$GameOver.get_node("Button").pressed.connect(restart)
	new_game()

func new_game():
	#reset variables
	score = 0
	show_score()
	game_running = false
	get_tree().paused = false
	difficulty = 0
	
	#delete all obstacles
	for obs in obstacles:
		obs.queue_free()
	obstacles.clear()
	
	#reset the nodes
	$Dino.position = DINO_START_POS
	$Dino.velocity = Vector2i(0, 0)
	$Camera2D.position = CAM_START_POS 
	$Ground.position = Vector2i(0, 0)
	
	#reset hud and game over screen
	$HUD.get_node("StartLabel").show()
	$GameOver.hide()
	
	#Heart
	hearts = 3
	update_hearts()
	
func restart():
	new_game()
	game_running = true
	$HUD.get_node("StartLabel").hide()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if game_running:
		# ✅ ลดเวลาพลังพิเศษ
		if has_power:
			power_timer -= delta
			if power_timer <= 0:
				has_power = false

		# speed up and adjust difficulty
		speed = min(START_SPEED + score / SPEED_MODIFIER, MAX_SPEED)
		adjust_difficulty()
		
		# generate obstacles
		generate_obs()
		
		# move dino and camera
		$Dino.position.x += speed
		$Camera2D.position.x += speed
		
		# update score
		score += speed
		show_score()
		
		# update ground
		if $Camera2D.position.x - $Ground.position.x > screen_size.x * 1.5:
			$Ground.position.x += screen_size.x

		# remove old obstacles
		for obs in obstacles.duplicate():
			if obs != null and obs.position.x < ($Camera2D.position.x - screen_size.x):
				remove_obs(obs)
			
	else:
		if Input.is_action_pressed("ui_accept"):
			game_running = true
			$HUD.get_node("StartLabel").hide()

func generate_obs():
	# เริ่ม spawn obstacles ถ้าระยะจากอันล่าสุดไกลพอ
	if obstacles.is_empty() or last_obs.position.x < $Camera2D.position.x + randi_range(400, 600):

		var obs
		var total_width = 0
		var obs_count = randi_range(1, difficulty + 1)
		var last_type = null

		for i in range(obs_count):
			var obs_type = obstacle_types[randi_range(0, obstacle_types.size() - 1)]

			# ป้องกันไม่ให้ชนิดเดียวกันซ้ำกันติดๆ
			while obs_type == last_type:
				obs_type = obstacle_types[randi_range(0, obstacle_types.size() - 1)]

			obs = obs_type.instantiate()
			last_type = obs_type

			var obs_sprite = obs.get_node("Sprite2D")
			var obs_width = obs_sprite.texture.get_width() * obs_sprite.scale.x
			var spacing = randi_range(300, 400)

			var obs_x = screen_size.x + $Camera2D.position.x + total_width + spacing
			var obs_y = screen_size.y - ground_height - (obs_sprite.texture.get_height() * obs_sprite.scale.y / 2) + 5

			add_obs(obs, obs_x, obs_y)

			total_width += obs_width + spacing
			last_obs = obs

		# นกบิน (อาจโผล่แม้ difficulty ยังไม่สุด)
		if difficulty > 0 and randi_range(0, 3) == 0:
			var bird = bird_scene.instantiate()
			
			# Bird offset
			var bird_offset = randi_range(300, 500)
			var bird_x = last_obs.position.x + bird_offset
			
			# Quantize height for ducking:
			var bird_y: int
			if randi_range(0, 1) == 0:  # Random chance for low birds
				bird_y = LOW_BIRD  # This is your "duck height"
			else:
				bird_y = bird_heights[randi() % bird_heights.size()]  # High birds

			add_obs(bird, bird_x, bird_y)


	# Spawn heart item
	var safe_gap = 150
	var safe_width = get_obstacle_width_safe()
	var item_x = last_obs.position.x + safe_width + safe_gap
	if randi() % 10 == 0 \
		and abs(item_x - last_item_spawn_x) > ITEM_MIN_DISTANCE \
		and abs(item_x - last_heart_spawn_x) > HEART_ITEM_MIN_DISTANCE:

		var heart = heart_item_scene.instantiate()
		var item_y = screen_size.y - ground_height - 150

		add_obs(heart, item_x, item_y)
		last_item_spawn_x = item_x
		last_heart_spawn_x = item_x

	
	# Spawn power item
	var power_safe_gap = 200
	var power_obs_width = get_obstacle_width_safe()
	item_x = last_obs.position.x + power_obs_width + power_safe_gap
	if randi() % 15 == 0 \
		and abs(item_x - last_item_spawn_x) > ITEM_MIN_DISTANCE \
		and abs(item_x - last_power_spawn_x) > POWER_ITEM_MIN_DISTANCE:

		var power = powerup_item_scene.instantiate()
		var item_y = screen_size.y - ground_height - 180
		add_obs(power, item_x, item_y)
		last_item_spawn_x = item_x
		last_power_spawn_x = item_x

# ✅ ฟังก์ชันปลอดภัย 100% เช็ค obstacle width
func get_obstacle_width_safe():
	if last_obs == null:
		return 100

	if last_obs.has_node("CollisionShape2D"):
		var shape_node = last_obs.get_node_or_null("CollisionShape2D")
		if shape_node != null:
			var shape_data = shape_node.shape
			if shape_data != null:
				return shape_data.extents.x * 2

	return 100

func add_obs(obs, x, y):
	obs.position = Vector2(x, y)
	if obs.has_signal("body_entered"):
		obs.body_entered.connect(on_obstacle_body_entered.bind(obs))  # ส่ง obs ไปด้วย
	add_child(obs)
	obstacles.append(obs)

func on_obstacle_body_entered(body, obs):
	if body.name == "Dino":
		if $Dino.is_hurt:
			return
		$HitSound.play()
		
		if body.has_power:
			obs.queue_free()  # ชนแล้วทำลายได้
			obstacles.erase(obs)
			return

		$Dino.take_hit()
		# ⚠️ Pause 
		get_tree().paused = true
		await get_tree().create_timer(0.1).timeout
		get_tree().paused = false
		
		hearts -= 1
		update_hearts()
		if hearts <= 0:
			game_over()

func remove_obs(obs):
	obs.queue_free()
	obstacles.erase(obs)

func show_score():
	$HUD.get_node("ScoreLabel").text = "SCORE: " + str(score / SCORE_MODIFIER)

func check_high_score():
	if score > high_score:
		high_score = score
		$HUD.get_node("HighScoreLabel").text = "HIGH SCORE: " + str(high_score / SCORE_MODIFIER)

func adjust_difficulty():
	difficulty = min(score / DIFFICULTY_SCALER, MAX_DIFFICULTY)

func game_over():
	check_high_score()
	get_tree().paused = true
	
	$Dino.get_node("JumpSound").stop()
	$HeartPickUp.stop()
	$PowerUpGrab.stop()
	
	$HitSound.playing = true
		
	game_running = false
	$GameOver.show()

func update_hearts():
	var heart_label = $HUD.get_node("HeartLabel")  # แนะนำให้เพิ่ม Label ชื่อ HeartLabel ใน HUD
	heart_label.text = "♥️ x " + str(hearts)

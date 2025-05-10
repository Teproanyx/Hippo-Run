extends CharacterBody2D

const GRAVITY : int = 6000
const JUMP_SPEED : int = -1800
const FAST_FALL_GRAVITY : int = 20000  # ตกเร็วขึ้นเวลา ui_down กลางอากาศ
var has_power := false
var power_timer := 0.0
const POWER_DURATION := 3.0
var is_hurt := false
var grace_period := 0.0
const GRACE := 1.0


func take_hit():
	if is_hurt:
		return
	is_hurt = true
	grace_period = GRACE
	$AnimatedSprite2D.play("hurt")

func _physics_process(delta):
	if is_on_floor():
		velocity.y = 0  # รีเซ็ตความเร็วแนวตั้งเวลาแตะพื้น
	else:
		# ถ้ากลางอากาศและกดหมอบ → ตกเร็ว
		if Input.is_action_pressed("ui_down"):
			velocity.y += FAST_FALL_GRAVITY * delta
		else:
			velocity.y += GRAVITY * delta

	var next_anim = ""
	var pause_anim = false
	# Movement logic stays the same
	if not get_parent().game_running:
			next_anim = "idle"  # Idle overrides everything
	else:
		if is_on_floor():
			$RunCol.disabled = false
			if Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
				velocity.y = JUMP_SPEED
				$JumpSound.play()
			elif Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
				next_anim = "duck"
				$RunCol.disabled = true
			else:
				next_anim = "run"
		else:
			next_anim = "jump"

		if is_hurt:
			grace_period -= delta
			pause_anim = true
			
			var blink_speed = 15.0  # Tweak to taste
			var alpha = float(sin(Time.get_ticks_msec() / 1000.0 * blink_speed * PI) > 0)
			$AnimatedSprite2D.modulate.a = alpha 
			
			if grace_period <= 0:
				is_hurt = false
				$AnimatedSprite2D.modulate.a = 1.0
				pause_anim = false
				next_anim = "run"

		# Power override, but only if not idling
		if has_power:
			next_anim = "power"
			pause_anim = false
			power_timer -= delta
		
			# Blink effect in last second
			if power_timer <= 1.0:
				var blink_speed = 15.0  # Tweak to taste
				var alpha = 1.0 if (sin(Time.get_ticks_msec() / 1000.0 * blink_speed * PI) > 0) else 0.3
				$AnimatedSprite2D.modulate.a = alpha
			else:
				$AnimatedSprite2D.modulate.a = 1.0

			# Power ends
			if power_timer <= 0:
				has_power = false
				$AnimatedSprite2D.modulate.a = 1.0  # Reset transparency
				next_anim = "run"
				
			$RunCol.disabled = false
	
	if not pause_anim:
		$AnimatedSprite2D.play(next_anim)

	move_and_slide()

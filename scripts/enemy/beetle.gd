extends Enemy
class_name Beetle

@export_category("Stats")
@export var hold_dist: float
@export var bomb: PackedScene
@export var buffer: float = 10.0
@export var throw_arc: float

@onready var throw_timer: Timer = $ThrowTimer
@onready var fuzzy_hold_dist = randf_range((hold_dist * 0.7), (hold_dist * 1.2))

var about_to_throw: bool = false
var can_throw: bool = true

func _ready() -> void:
	super()
	throw_timer.wait_time = 3.0
	throw_timer.timeout.connect(_on_timer_timeout)
	throw_timer.start()

func move_towards_target() -> void:
	if current_target == null or about_to_throw:
		velocity.x = move_toward(velocity.x, 0, 10)
		return
	
	var target_dir = sign(current_target.global_position.x - global_position.x)
	var target_x = current_target.global_position.x - (target_dir * fuzzy_hold_dist)
	var move_dir = sign(target_x - global_position.x)
	
	if abs(global_position.x - target_x) > buffer:
		velocity.x = move_dir * speed
	else:
		velocity.x = move_toward(velocity.x, 0, 10)
	
	# sprite feedback
	if enemy_sprite:
		if velocity.x != 0:
			enemy_sprite.play("walk")
			enemy_sprite.flip_h = target_dir > 0
		else:
			enemy_sprite.play("idle")

func _on_timer_timeout() -> void:
	if not about_to_throw and current_target:
		prepare_bomb()

func prepare_bomb() -> void:
	about_to_throw = true
	velocity.x = 0.0
	#print("preparing to bomb")
	
	# form bomb
	if bomb and not stomped:
		var bomb_visual = bomb.instantiate()
		add_child(bomb_visual)
		#print("temp bomb has been instantiated")
		
		# kill physics on da bomb until actually thrown
		bomb_visual.process_mode = Node.PROCESS_MODE_DISABLED
		
		# initialize the bomb's position
		bomb_visual.position = Vector2(0, -10)
		
		# sprite feedback
		var bomb_sprite = bomb_visual.get_node("Sprite")
		if bomb_sprite and bomb_sprite is AnimatedSprite2D:
			bomb_sprite.play("default")
		
		# move to beetle hands
		var tween = create_tween()
		var offset_to_hands = Vector2(2 * (1 if enemy_sprite.flip_h else -1), -15.0)
		tween.tween_property(bomb_visual, "position", offset_to_hands, 0.2)
		
		# throw when tween ends
		tween.tween_callback(func(): throw_bomb(bomb_visual))
		#print("temp bomb has moved to beetle hands")

func throw_bomb(temp_bomb: Node2D) -> void:
	#print("getting ready to throw bomb")
	# kill temp bomb
	temp_bomb.queue_free()
	#print("deleted temp bomb")
	# get the real one in
	if bomb:
		var real_bomb = bomb.instantiate()
		get_parent().add_child(real_bomb)
		#print("added real bomb to scene")
		# place in same position as temp bomb before it was freed
		real_bomb.global_position = temp_bomb.global_position
		
		# decide throw direction
		var throw_dir = sign(current_target.global_position.x - global_position.x)
		if throw_dir == 0: throw_dir = 1
		
		# yeet
		real_bomb.setup(throw_dir, throw_arc)
		#print("passing control off to bomb")
	about_to_throw = false

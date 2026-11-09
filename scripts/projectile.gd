class_name Projectile extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 520.0
var travel_range: float = 420.0
var damage_amount: int = 1

var _travelled: float = 0.0
var _has_hit: bool = false


func setup(p_direction: Vector2, tuning: Tuning) -> void:
	if p_direction != Vector2.ZERO:
		direction = p_direction.normalized()
	if tuning != null:
		speed = tuning.projectile_speed
		travel_range = tuning.projectile_range
		damage_amount = tuning.projectile_damage
	rotation = direction.angle()


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _has_hit:
		return
	var step := direction * speed * delta
	position += step
	_travelled += step.length()
	if _travelled >= travel_range:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.85, 0.25, 1.0))
	draw_circle(Vector2.ZERO, 2.5, Color(1.0, 1.0, 0.9, 1.0))


func _on_body_entered(body: Node2D) -> void:
	if _has_hit:
		return
	_has_hit = true
	if body != null and body.has_method("take_damage"):
		body.call("take_damage", damage_amount, direction)
	set_deferred("monitoring", false)
	queue_free()

class_name Projectile
extends Area2D
## Projectile générique réutilisable par n'importe quelle technique à distance
## (Frappe de Qi, et futures techniques Murim).
##
## Se déplace en ligne droite à vitesse constante, inflige ses dégâts au
## premier corps détecté (qui doit exposer `take_damage(amount: float)`),
## puis se détruit. S'auto-détruit aussi après sa durée de vie pour éviter
## toute fuite mémoire si la cible est manquée.

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 0.0
var _damage: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Configure et active le projectile. À appeler juste après instantiate().
func launch(direction: Vector2, damage: float, speed: float, lifetime: float) -> void:
	_direction = direction.normalized()
	_damage = damage
	_speed = speed
	rotation = _direction.angle()

	var lifetime_timer := get_tree().create_timer(lifetime)
	lifetime_timer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	global_position += _direction * _speed * delta


## Appelé quand le projectile touche un corps physique (ex: Enemy en collision_layer "enemies").
func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(_damage)
	queue_free()

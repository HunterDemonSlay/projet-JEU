class_name Projectile
extends Area2D
## Projectile générique réutilisable par n'importe quelle technique à distance
## (Frappe de Qi, et futures techniques Murim).
##
## Se déplace en ligne droite à vitesse constante, inflige ses dégâts au
## premier corps détecté (qui doit exposer `take_damage(amount: float)`),
## puis se recycle via ObjectPooler. Se recycle aussi après sa durée de vie
## (LifetimeTimer) si la cible est manquée.
##
## Géré par ObjectPooler : utilise un Timer enfant redémarrable plutôt qu'un
## SceneTreeTimer à usage unique, pour pouvoir relancer le compte à rebours
## à chaque réactivation sans fuite ni signal fantôme d'une vie précédente.

@onready var lifetime_timer: Timer = $LifetimeTimer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 0.0
var _damage: float = 0.0
var _connected_signals: bool = false


func _ready() -> void:
	_connect_signals_once()


## Configure et active le projectile. À appeler juste après ObjectPooler.acquire().
func launch(direction: Vector2, damage: float, speed: float, lifetime: float) -> void:
	_direction = direction.normalized()
	_damage = damage
	_speed = speed
	rotation = _direction.angle()

	lifetime_timer.start(lifetime)


func _physics_process(delta: float) -> void:
	global_position += _direction * _speed * delta


## Appelée par ObjectPooler quand cette instance est réutilisée.
func on_pool_activate() -> void:
	monitoring = true
	collision_shape.disabled = false
	_connect_signals_once()


## Appelée par ObjectPooler quand cette instance retourne au pool.
func on_pool_deactivate() -> void:
	monitoring = false
	collision_shape.disabled = true
	lifetime_timer.stop()


func _connect_signals_once() -> void:
	if _connected_signals:
		return
	body_entered.connect(_on_body_entered)
	lifetime_timer.timeout.connect(despawn)
	_connected_signals = true


## Renvoie ce projectile dans le pool de ObjectPooler au lieu de le détruire.
## Différé via call_deferred : appelée depuis _on_body_entered, en pleine
## étape physique, où désactiver le monitoring (on_pool_deactivate) lèverait
## une erreur Godot ("flushing queries") si elle s'exécutait immédiatement.
func despawn() -> void:
	ObjectPooler.call_deferred("release", self)


## Appelé quand le projectile touche un corps physique (ex: Enemy en collision_layer "enemies").
func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(_damage)
	despawn()

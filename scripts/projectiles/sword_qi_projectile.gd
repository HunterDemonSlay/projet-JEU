class_name SwordQiProjectile
extends Area2D
## "Sword Qi" : vague d'énergie directionnelle qui s'oriente elle-même vers
## l'ennemi le plus proche au moment où elle est activée, contrairement à
## `Projectile.gd` (Frappe de Qi) qui reçoit sa direction de l'arme qui le tire.
##
## Géré par ObjectPooler comme tous les projectiles du jeu (voir Étape 6) :
## fire() configure et active l'instance recyclée, on_pool_activate()/
## on_pool_deactivate() remettent l'état à neuf, despawn() la renvoie au pool
## au lieu de la détruire.

## Image de la vague d'énergie, assignable directement dans l'inspecteur.
@export var texture: Texture2D:
	set(value):
		texture = value
		if sprite != null:
			sprite.texture = value

## Durée du fondu (en secondes) avant le retour au pool, à l'impact ou en fin de vie.
@export var fade_out_duration: float = 0.25

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var lifetime_timer: Timer = $LifetimeTimer

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 0.0
var _damage: float = 0.0
var _is_fading: bool = false
var _connected_signals: bool = false


func _ready() -> void:
	if texture != null:
		sprite.texture = texture
	_connect_signals_once()


## Oriente la vague vers l'ennemi le plus proche puis l'active.
## À appeler juste après ObjectPooler.acquire().
func fire(damage: float, speed: float, lifetime: float) -> void:
	_damage = damage
	_speed = speed
	_direction = _find_direction_to_nearest_enemy()
	rotation = _direction.angle()

	lifetime_timer.start(lifetime)


func _physics_process(delta: float) -> void:
	if _is_fading:
		return
	global_position += _direction * _speed * delta


## Cherche l'ennemi le plus proche dans le groupe "enemies" et renvoie la
## direction vers lui. Contrairement à WeaponBase._find_nearest_enemy(), pas
## de limite de portée : cette technique vise toujours quelqu'un si possible.
func _find_direction_to_nearest_enemy() -> Vector2:
	var nearest: Node2D = null
	var nearest_distance_sq := INF

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var distance_sq := global_position.distance_squared_to(enemy.global_position)
		if distance_sq < nearest_distance_sq:
			nearest_distance_sq = distance_sq
			nearest = enemy

	if nearest == null:
		return Vector2(cos(rotation), sin(rotation))

	return (nearest.global_position - global_position).normalized()


## Appelée par ObjectPooler quand cette instance est réutilisée.
func on_pool_activate() -> void:
	monitoring = true
	collision_shape.disabled = false
	modulate.a = 1.0
	_is_fading = false
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
	lifetime_timer.timeout.connect(_on_lifetime_expired)
	_connected_signals = true


func _on_body_entered(body: Node) -> void:
	if _is_fading:
		return
	if body.has_method("take_damage"):
		body.take_damage(_damage)
	_start_fade_out()


func _on_lifetime_expired() -> void:
	_start_fade_out()


## Fondu via Tween avant de retourner au pool, plutôt qu'une disparition nette.
## monitoring est coupé en différé (set_deferred) : _start_fade_out() peut être
## appelée depuis _on_body_entered, donc en pleine étape physique, où changer
## directement l'état de collision lève une erreur Godot ("flushing queries"),
## comme déjà rencontré sur Enemy.gd et Projectile.gd.
func _start_fade_out() -> void:
	if _is_fading:
		return
	_is_fading = true
	set_deferred("monitoring", false)

	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, fade_out_duration)
	fade_tween.finished.connect(despawn)


func despawn() -> void:
	ObjectPooler.call_deferred("release", self)

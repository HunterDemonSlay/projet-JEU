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

## Chemin par défaut où déposer votre image de vague de Qi (fond noir, mode
## additif). Chargée automatiquement si `texture` n'est pas déjà assignée
## dans l'inspecteur — voir _ready(). ResourceLoader.exists() évite toute
## erreur si le fichier n'existe pas encore (contrairement à preload(), qui
## empêcherait le projet entier de s'ouvrir tant que le fichier est absent).
const DEFAULT_TEXTURE_PATH := "res://assets/vfx/qi_strike_wave.png"

## Image de la vague d'énergie. Peut être assignée directement dans
## l'inspecteur, ou laissée vide pour utiliser DEFAULT_TEXTURE_PATH.
@export var texture: Texture2D:
	set(value):
		texture = value
		if sprite != null and value != null:
			sprite.texture = value

## Si la texture source ne pointe pas naturellement vers la droite (+X),
## corrige l'angle ici (en degrés) pour aligner son "avant" avec _direction.
@export var sprite_forward_offset_deg: float = 0.0

## VFX d'explosion joué à l'endroit de l'impact (voir QiImpactVFX.gd).
@export var impact_vfx_scene: PackedScene

## Durée du fondu + rétrécissement avant le retour au pool, à l'impact ou en fin de vie.
@export var fade_out_duration: float = 0.25

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var lifetime_timer: Timer = $LifetimeTimer

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 0.0
var _damage: float = 0.0
var _is_fading: bool = false
var _connected_signals: bool = false
var _fade_tween: Tween


func _ready() -> void:
	if texture == null and ResourceLoader.exists(DEFAULT_TEXTURE_PATH):
		texture = load(DEFAULT_TEXTURE_PATH)
	elif texture != null:
		sprite.texture = texture

	_connect_signals_once()


## Oriente la vague vers l'ennemi le plus proche puis l'active.
## À appeler juste après ObjectPooler.acquire().
func fire(damage: float, speed: float, lifetime: float) -> void:
	# Une instance recyclée peut encore avoir un Tween de mort en cours
	# (cas limite : réutilisée juste après son fondu précédent) ; le tuer
	# avant de réinitialiser scale/modulate évite qu'il n'écrase nos valeurs
	# une frame plus tard.
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	_damage = damage
	_speed = speed
	_is_fading = false
	scale = Vector2.ONE
	modulate.a = 1.0

	_direction = _find_direction_to_nearest_enemy()
	rotation = _direction.angle() + deg_to_rad(sprite_forward_offset_deg)

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
	scale = Vector2.ONE
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
	QiImpactVFX.spawn(impact_vfx_scene, get_tree().current_scene, global_position)
	_start_fade_out()


func _on_lifetime_expired() -> void:
	_start_fade_out()


## Dissipation : rétrécissement + fondu simultanés via un Tween, plutôt
## qu'une disparition nette, puis retour au pool.
## monitoring est coupé en différé (set_deferred) : _start_fade_out() peut être
## appelée depuis _on_body_entered, donc en pleine étape physique, où changer
## directement l'état de collision lève une erreur Godot ("flushing queries"),
## comme déjà rencontré sur Enemy.gd et Projectile.gd.
func _start_fade_out() -> void:
	if _is_fading:
		return
	_is_fading = true
	set_deferred("monitoring", false)

	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(self, "scale", Vector2.ZERO, fade_out_duration)
	_fade_tween.tween_property(self, "modulate:a", 0.0, fade_out_duration)
	_fade_tween.finished.connect(despawn)


func despawn() -> void:
	ObjectPooler.call_deferred("release", self)

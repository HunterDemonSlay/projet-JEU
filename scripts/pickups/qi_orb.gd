class_name QiOrb
extends Area2D
## Orbe de Qi lâchée par les ennemis vaincus.
##
## Reste totalement immobile (et ne consomme aucun temps CPU par frame, voir
## `set_physics_process(false)`) tant que le joueur n'est pas à portée. Quand
## `start_attraction()` est appelé (par Player, sur entrée dans son
## PickupArea), l'orbe accélère vers lui pour un effet de "magnet" satisfaisant.
##
## Performance : avec des centaines d'orbes à l'écran, seules celles
## effectivement en cours d'attraction exécutent `_physics_process` ; les
## orbes immobiles ne coûtent rien tant qu'elles ne sont pas détectées par
## la zone d'attraction du joueur (détection déléguée au moteur physique,
## pas à un sondage GDScript par orbe).

## Quantité de Qi accordée au joueur lors du ramassage.
@export var qi_value: float = 1.0
## Vitesse initiale de l'attraction, en pixels/seconde.
@export var base_attraction_speed: float = 200.0
## Accélération de la vitesse d'attraction par seconde (effet "magnet").
@export var attraction_acceleration: float = 900.0
## Distance en-dessous de laquelle l'orbe est considérée comme ramassée.
@export var pickup_distance: float = 12.0

var _is_attracted: bool = false
var _current_speed: float = 0.0
var _target: Node2D


func _ready() -> void:
	# Aucune logique par frame tant que l'orbe n'est pas attirée.
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target):
		queue_free()
		return

	_current_speed += attraction_acceleration * delta
	var direction := (_target.global_position - global_position).normalized()
	global_position += direction * _current_speed * delta

	if global_position.distance_to(_target.global_position) <= pickup_distance:
		_collect()


## Démarre le vol vers `target`. Idempotent : un second appel est ignoré.
func start_attraction(target: Node2D) -> void:
	if _is_attracted:
		return

	_is_attracted = true
	_target = target
	_current_speed = base_attraction_speed
	set_physics_process(true)


## Crédite le Qi au joueur puis détruit l'orbe.
func _collect() -> void:
	if _target.has_method("add_qi"):
		_target.add_qi(qi_value)
	queue_free()

class_name Player
extends CharacterBody2D
## Contrôleur du personnage joueur.
##
## Gère le déplacement fluide à 8 directions (ZQSD / flèches), avec
## accélération et friction. Les statistiques de Cultivation (Qi, vie,
## vitesse, attraction) sont déléguées à la Resource `CultivationStats`
## pour rester découplées de la logique de mouvement.

@export_group("Mouvement")
## Vitesse de déplacement maximale, en pixels/seconde.
@export var max_speed: float = 300.0
## Accélération appliquée lorsque le joueur appuie sur une direction.
@export var acceleration: float = 2000.0
## Décélération appliquée en l'absence d'input, pour un arrêt progressif.
@export var friction: float = 1800.0

@export_group("Cultivation")
## Statistiques du joueur (Qi, vie, vitesse, attraction). Voir CultivationStats.
@export var stats: CultivationStats = CultivationStats.new()

## Référence à la zone de ramassage, dont le rayon suit `stats.pickup_radius`.
@onready var pickup_area: Area2D = $PickupArea
@onready var pickup_shape: CollisionShape2D = $PickupArea/CollisionShape2D


func _ready() -> void:
	_update_pickup_radius()


func _physics_process(delta: float) -> void:
	var input_direction := _get_input_direction()
	velocity = _compute_velocity(velocity, input_direction, delta)
	move_and_slide()


## Lit les actions d'input (ZQSD / flèches) et retourne un vecteur normalisé.
func _get_input_direction() -> Vector2:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return direction


## Calcule la nouvelle vélocité à partir de la vélocité actuelle, de la
## direction d'input et du delta-time. Applique l'accélération si une
## direction est pressée, sinon la friction pour un arrêt progressif.
func _compute_velocity(current_velocity: Vector2, input_direction: Vector2, delta: float) -> Vector2:
	var effective_max_speed := max_speed * stats.move_speed_multiplier

	if input_direction != Vector2.ZERO:
		var target_velocity := input_direction * effective_max_speed
		return current_velocity.move_toward(target_velocity, acceleration * delta)

	return current_velocity.move_toward(Vector2.ZERO, friction * delta)


## Synchronise le rayon de la zone de ramassage avec les statistiques de Cultivation.
## À appeler après toute modification de `stats.pickup_radius`.
func _update_pickup_radius() -> void:
	if pickup_shape.shape is CircleShape2D:
		(pickup_shape.shape as CircleShape2D).radius = stats.pickup_radius

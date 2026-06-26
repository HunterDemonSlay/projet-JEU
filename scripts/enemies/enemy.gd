class_name Enemy
extends CharacterBody2D
## Ennemi de base ("Bête Démoniaque de Rang inférieur").
##
## Poursuite vectorielle simple (pas de pathfinding A*) pour rester
## performant avec des centaines d'instances simultanées : un seul
## get_first_node_in_group() est fait une fois en cache, puis chaque
## frame ne coûte qu'une soustraction de vecteurs + normalize().

## Statistiques de cet ennemi (HP, vitesse, dégâts). Assigner une Resource
## .tres différente par archétype pour varier les ennemis sans dupliquer le script.
@export var stats: EnemyStats = EnemyStats.new()

@onready var hurtbox: Area2D = $Hurtbox

var current_health: float
## Cache de la référence au joueur, résolue une seule fois (voir _ready).
## Évite un appel get_tree().get_first_node_in_group() à chaque frame.
var _player: Node2D


func _ready() -> void:
	current_health = stats.max_health
	_player = get_tree().get_first_node_in_group("player")
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return

	var direction := (_player.global_position - global_position).normalized()
	velocity = direction * stats.speed
	move_and_slide()


## Applique des dégâts et déclenche la mort si les HP tombent à zéro.
func take_damage(amount: float) -> void:
	current_health -= amount
	if current_health <= 0.0:
		_die()


func _die() -> void:
	# TODO Étape 3 : spawn d'un pickup d'essence de Qi (stats.qi_reward) ici.
	queue_free()


## Inflige les dégâts de contact à toute zone du joueur entrant dans la hurtbox.
## La méthode take_damage_from_enemy() sera ajoutée au Player à l'étape combat ;
## has_method() évite une erreur tant qu'elle n'existe pas encore.
func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_hurtbox"):
		return
	var target := area.get_parent()
	if target.has_method("take_damage_from_enemy"):
		target.take_damage_from_enemy(stats.contact_damage)

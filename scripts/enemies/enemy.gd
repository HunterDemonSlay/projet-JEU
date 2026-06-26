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
## Scène de l'orbe de Qi déposée à la mort (voir QiOrb.gd).
@export var qi_orb_scene: PackedScene

@onready var hurtbox: Area2D = $Hurtbox

var current_health: float
## Cache de la référence au joueur, résolue une seule fois (voir _ready).
## Évite un appel get_tree().get_first_node_in_group() à chaque frame.
var _player: Node2D


func _ready() -> void:
	current_health = stats.max_health
	_player = get_tree().get_first_node_in_group("player")
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	# Permet aux armes (WeaponBase) de trouver l'ennemi le plus proche
	# sans avoir à parcourir tous les nœuds de la scène.
	add_to_group("enemies")


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
	_drop_qi_orb()
	queue_free()


## Instancie un QiOrb à la position de l'ennemi, avec la récompense définie
## dans ses stats (stats.qi_reward).
## _die() est appelée depuis le callback de collision d'un projectile
## (en pleine étape physique) : ajouter l'orbe à la scène doit donc être
## différé via call_deferred, sinon Godot refuse de modifier l'état physique
## ("flushing queries") et lève une erreur au runtime.
func _drop_qi_orb() -> void:
	if qi_orb_scene == null:
		return

	var orb := qi_orb_scene.instantiate() as QiOrb
	orb.global_position = global_position
	orb.qi_value = stats.qi_reward
	get_tree().current_scene.call_deferred("add_child", orb)


## Inflige les dégâts de contact à toute zone du joueur entrant dans la hurtbox.
## La méthode take_damage_from_enemy() sera ajoutée au Player à l'étape combat ;
## has_method() évite une erreur tant qu'elle n'existe pas encore.
func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_hurtbox"):
		return
	var target := area.get_parent()
	if target.has_method("take_damage_from_enemy"):
		target.take_damage_from_enemy(stats.contact_damage)

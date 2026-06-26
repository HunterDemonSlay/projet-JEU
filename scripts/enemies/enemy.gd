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
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var current_health: float
## Cache de la référence au joueur, résolue une seule fois (voir _ready /
## on_pool_activate). Évite un appel get_tree().get_first_node_in_group()
## à chaque frame.
var _player: Node2D
var _hurtbox_connected: bool = false


func _ready() -> void:
	# Permet aux armes (WeaponBase) de trouver l'ennemi le plus proche
	# sans avoir à parcourir tous les nœuds de la scène.
	add_to_group("enemies")
	on_pool_activate()


## Appelée par ObjectPooler quand cette instance est réutilisée : remet
## l'ennemi dans un état "neuf" (vie pleine, collisions actives, cible à jour).
func on_pool_activate() -> void:
	current_health = stats.max_health
	velocity = Vector2.ZERO
	_player = get_tree().get_first_node_in_group("player")
	hurtbox.monitoring = true
	collision_shape.disabled = false

	# Le signal ne doit être connecté qu'une fois par instance, pas à
	# chaque réactivation (sinon il se déclencherait plusieurs fois).
	if not _hurtbox_connected:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
		_hurtbox_connected = true


## Appelée par ObjectPooler quand cette instance retourne au pool : coupe
## tout ce qui pourrait continuer à interagir avec la scène une fois cachée.
func on_pool_deactivate() -> void:
	velocity = Vector2.ZERO
	hurtbox.monitoring = false
	collision_shape.disabled = true


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
	_grant_spirit_stones()
	despawn()


## Crédite directement le joueur en Pierres d'Esprit (monnaie de méta-
## progression), contrairement au Qi qui passe par un QiOrb ramassable.
func _grant_spirit_stones() -> void:
	if is_instance_valid(_player) and _player.has_method("earn_spirit_stones"):
		_player.earn_spirit_stones(stats.spirit_stone_reward)


## Renvoie cet ennemi dans le pool de ObjectPooler au lieu de le détruire.
## Différé via call_deferred : _die() est appelée depuis le callback de
## collision d'un projectile (en pleine étape physique), et désactiver les
## collisions (on_pool_deactivate) à ce moment précis lève une erreur Godot
## ("flushing queries"), comme déjà rencontré avec _drop_qi_orb().
func despawn() -> void:
	ObjectPooler.call_deferred("release", self)


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

class_name WeaponBase
extends Node2D
## Classe de base pour toutes les techniques de combat automatique.
##
## Gère le ciblage automatique (ennemi le plus proche dans `targeting_range`)
## à intervalle régulier via un Timer interne, oriente l'arme vers la cible,
## puis délègue l'action concrète (spawn de projectile, AoE, soin...) aux
## classes filles via `_perform_attack()`. Chaque nouvelle technique Murim
## n'a donc qu'à hériter de WeaponBase et implémenter cette seule méthode.

@export_group("Statistiques")
## Dégâts infligés par une attaque.
@export var damage: float = 10.0
## Temps entre deux attaques, en secondes.
@export var attack_cooldown: float = 1.0
## Vitesse des projectiles éventuellement générés par cette arme.
@export var projectile_speed: float = 400.0

@export_group("Ciblage")
## Portée maximale de détection de l'ennemi le plus proche.
@export var targeting_range: float = 500.0

var _attack_timer: Timer


func _ready() -> void:
	_attack_timer = Timer.new()
	_attack_timer.wait_time = attack_cooldown
	_attack_timer.autostart = true
	_attack_timer.timeout.connect(_on_attack_timer_timeout)
	add_child(_attack_timer)


func _on_attack_timer_timeout() -> void:
	var target := _find_nearest_enemy()
	if target == null:
		return

	look_at(target.global_position)
	_perform_attack(target)


## Action concrète de la technique (spawn de projectile, AoE, etc.).
## Chaque arme fille DOIT surcharger cette méthode.
func _perform_attack(_target: Node2D) -> void:
	push_error("WeaponBase._perform_attack() doit être surchargée par une classe fille.")


## Renvoie l'ennemi le plus proche dans `targeting_range`, ou null si aucun.
## O(n) sur le nombre d'ennemis, mais appelé seulement à chaque cooldown
## (pas à chaque frame), donc négligeable même avec des centaines d'ennemis.
func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance_sq := targeting_range * targeting_range

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var distance_sq := global_position.distance_squared_to(enemy.global_position)
		if distance_sq <= nearest_distance_sq:
			nearest_distance_sq = distance_sq
			nearest = enemy

	return nearest

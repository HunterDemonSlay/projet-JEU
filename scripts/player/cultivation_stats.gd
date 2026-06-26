class_name CultivationStats
extends Resource
## Conteneur de données pour les statistiques de Cultivation du joueur.
##
## Séparer les statistiques du joueur dans une Resource permet de les
## sauvegarder/charger facilement (système de sauvegarde, presets de
## difficulté, bonus de reliques...) sans toucher au script Player.gd.

## Points de Qi actuels (ressource de "mana" thématique Murim).
@export var qi: float = 100.0
## Quantité maximale de Qi que le joueur peut accumuler.
@export var max_qi: float = 100.0

## Points de vie actuels.
@export var health: float = 100.0
## Points de vie maximum.
@export var max_health: float = 100.0

## Multiplicateur de vitesse de déplacement (1.0 = vitesse de base).
## Modifié par les percées de cultivation, reliques, buffs temporaires, etc.
@export var move_speed_multiplier: float = 1.0

## Rayon d'attraction des objets au sol (essences de Qi, butin...).
@export var pickup_radius: float = 48.0


func is_alive() -> bool:
	return health > 0.0


func take_damage(amount: float) -> void:
	health = clampf(health - amount, 0.0, max_health)


func heal(amount: float) -> void:
	health = clampf(health + amount, 0.0, max_health)


func spend_qi(amount: float) -> bool:
	if qi < amount:
		return false
	qi = clampf(qi - amount, 0.0, max_qi)
	return true


func restore_qi(amount: float) -> void:
	qi = clampf(qi + amount, 0.0, max_qi)

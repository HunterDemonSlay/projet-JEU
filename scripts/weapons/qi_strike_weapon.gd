class_name QiStrikeWeapon
extends WeaponBase
## "Frappe de Qi" : première technique du joueur.
##
## Tire un projectile en ligne droite vers l'ennemi le plus proche. Toute la
## logique de ciblage/cadence est déjà fournie par WeaponBase ; cette classe
## ne fait qu'instancier et configurer le projectile.

## Scène du projectile à instancier (doit avoir un script Projectile ou enfant).
@export var projectile_scene: PackedScene
## Durée de vie du projectile avant auto-destruction s'il ne touche rien.
@export var projectile_lifetime: float = 2.0


func _perform_attack(target: Node2D) -> void:
	if projectile_scene == null:
		return

	var direction := (target.global_position - global_position).normalized()
	var projectile := projectile_scene.instantiate() as Projectile

	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	projectile.launch(direction, damage, projectile_speed, projectile_lifetime)

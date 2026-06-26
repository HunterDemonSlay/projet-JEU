class_name SwordQiWeapon
extends WeaponBase
## Technique "Sword Qi" : tire une vague d'énergie qui s'oriente elle-même
## vers l'ennemi le plus proche (voir SwordQiProjectile.fire()).
##
## Contrairement à QiStrikeWeapon, ne calcule pas de direction ici : c'est
## le projectile lui-même qui fait son propre ciblage à l'activation, donc
## cette classe se contente de l'acquérir auprès du pool et de le lancer.

## Scène du projectile (doit avoir un script SwordQiProjectile).
@export var projectile_scene: PackedScene
## Durée de vie du projectile avant retour au pool s'il ne touche rien.
@export var projectile_lifetime: float = 2.0


func _perform_attack(_target: Node2D) -> void:
	if projectile_scene == null:
		return

	var projectile := ObjectPooler.acquire(projectile_scene, get_tree().current_scene) as SwordQiProjectile
	projectile.global_position = global_position
	projectile.fire(damage, projectile_speed, projectile_lifetime)

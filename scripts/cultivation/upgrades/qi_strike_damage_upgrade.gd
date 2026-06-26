class_name QiStrikeDamageUpgrade
extends UpgradeEffect
## Manuel Secret : "Poing de Qi Renforcé" — augmente les dégâts de la Frappe de Qi.


func _init() -> void:
	title = "Poing de Qi Renforcé"
	description = "+20% de dégâts de la Frappe de Qi"


func apply(player: Player) -> void:
	var weapon := player.get_node("WeaponPivot") as WeaponBase
	if weapon:
		weapon.damage *= 1.2

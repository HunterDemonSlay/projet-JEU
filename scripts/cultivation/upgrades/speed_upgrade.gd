class_name SpeedUpgrade
extends UpgradeEffect
## Manuel Secret : "Pas du Vent Léger" — augmente la vitesse de déplacement.


func _init() -> void:
	title = "Pas du Vent Léger"
	description = "+15% de vitesse de déplacement"


func apply(player: Player) -> void:
	player.stats.move_speed_multiplier += 0.15

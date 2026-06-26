class_name QiRegenUpgrade
extends UpgradeEffect
## Manuel Secret : "Respiration Profonde" — augmente la régénération passive de Qi.


func _init() -> void:
	title = "Respiration Profonde"
	description = "+1 régénération de Qi par seconde"


func apply(player: Player) -> void:
	player.stats.qi_regen_rate += 1.0

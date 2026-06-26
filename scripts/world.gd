class_name World
extends Node2D
## Scène principale : assemble le joueur, le spawner d'ennemis et le HUD.
##
## Seule responsabilité ici : relier le HUD au joueur courant au démarrage.
## Le reste (ciblage, spawn, percée...) est entièrement découplé via les
## groupes ("player", "enemies") et l'autoload CultivationManager.

@onready var hud: HUD = $HUD


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		hud.bind_player(player)

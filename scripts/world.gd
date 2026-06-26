class_name World
extends Node2D
## Scène principale : assemble le joueur, le spawner d'ennemis et le HUD.
##
## Relie le HUD au joueur courant au démarrage, et déclenche la sauvegarde
## de la méta-progression (SaveManager) à la mort du joueur, qui marque la
## fin de la run. Le reste (ciblage, spawn, percée...) est entièrement
## découplé via les groupes ("player", "enemies") et les autres autoloads.

@onready var hud: HUD = $HUD


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		hud.bind_player(player)
		player.died.connect(_on_player_died)


## Fin de la run : on persiste tout de suite la méta-progression accumulée
## (Pierres d'Esprit, Royaume max, améliorations permanentes), pour ne rien
## perdre même si le joueur ferme le jeu depuis l'écran de fin sans attendre.
func _on_player_died() -> void:
	SaveManager.save_game()

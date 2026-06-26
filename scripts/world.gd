class_name World
extends Node2D
## Scène principale : assemble le joueur, le spawner d'ennemis et le HUD.
##
## Relie le HUD au joueur courant au démarrage. À la mort du joueur : met
## le jeu en pause, crédite la méta-progression (SaveManager) avec les
## Pierres d'Esprit gagnées pendant la run, sauvegarde, puis affiche
## l'écran de fin. Le reste (ciblage, spawn, percée...) reste découplé via
## les groupes ("player", "enemies") et les autres autoloads.

@onready var hud: HUD = $HUD
@onready var game_over_screen: GameOverScreen = $GameOverScreen


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		hud.bind_player(player)
		player.died.connect(_on_player_died.bind(player))


## Fin de la run : pause, crédite et persiste la méta-progression, puis
## affiche les résultats. L'ordre (créditer avant d'afficher) garantit que
## le total affiché est déjà à jour.
func _on_player_died(player: Player) -> void:
	get_tree().paused = true

	var earned := player.session_spirit_stones
	SaveManager.add_spirit_stones(earned)
	SaveManager.save_game()

	game_over_screen.show_results(earned, SaveManager.get_spirit_stones())

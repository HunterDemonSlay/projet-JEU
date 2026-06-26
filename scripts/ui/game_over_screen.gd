class_name GameOverScreen
extends CanvasLayer
## Écran de fin de run : affiche les Pierres d'Esprit gagnées pendant la
## partie (et le total cumulé en méta-progression), puis propose de relancer.
##
## Masqué par défaut. Pur affichage : ne touche jamais aux données du
## joueur ni à SaveManager directement — World.gd lui fournit déjà les
## montants calculés via `show_results()`, après avoir crédité la
## méta-progression. Reste actif pendant la pause (process_mode = ALWAYS)
## pour que le bouton "Rejouer" soit cliquable.

@onready var earned_label: Label = $CenterContainer/PanelContainer/VBoxContainer/EarnedLabel
@onready var total_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TotalLabel
@onready var replay_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ReplayButton


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	replay_button.pressed.connect(_on_replay_pressed)


## Affiche l'écran avec les montants déjà calculés par World.gd.
func show_results(spirit_stones_earned: int, total_spirit_stones: int) -> void:
	earned_label.text = "Pierres d'Esprit gagnées : %d" % spirit_stones_earned
	total_label.text = "Total cumulé : %d" % total_spirit_stones
	visible = true


func _on_replay_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

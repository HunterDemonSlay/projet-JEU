class_name BreakthroughMenu
extends Control
## Écran de choix d'amélioration affiché à chaque percée de Cultivation.
##
## Masqué par défaut. S'affiche et se peuple dynamiquement de 3 cartes
## cliquables quand `CultivationManager` (autoload) émet `upgrades_offered`.
## Ne modifie jamais les stats du joueur directement : le choix du clic est
## simplement transmis à `CultivationManager.select_upgrade()`, qui reste
## seul responsable d'appliquer l'effet et de relancer la partie.

@onready var choices_container: HBoxContainer = $CenterContainer/PanelContainer/VBoxContainer/ChoicesContainer


func _ready() -> void:
	visible = false
	# Doit pouvoir être cliqué alors que get_tree().paused = true gèle le reste.
	process_mode = Node.PROCESS_MODE_ALWAYS
	CultivationManager.upgrades_offered.connect(_on_upgrades_offered)


func _on_upgrades_offered(choices: Array[UpgradeEffect]) -> void:
	_populate_choices(choices)
	visible = true


## Vide le conteneur puis crée une carte cliquable par amélioration proposée.
func _populate_choices(choices: Array[UpgradeEffect]) -> void:
	for existing_card in choices_container.get_children():
		existing_card.queue_free()

	for upgrade in choices:
		choices_container.add_child(_create_card(upgrade))


## Construit une carte (Button) affichant le titre et la description d'une
## amélioration. Un Button suffit ici ; remplaçable plus tard par une scène
## UpgradeCard.tscn dédiée si l'on veut une présentation plus riche (icône...).
func _create_card(upgrade: UpgradeEffect) -> Button:
	var card := Button.new()
	card.text = "%s\n\n%s" % [upgrade.title, upgrade.description]
	card.custom_minimum_size = Vector2(180, 220)
	card.autowrap_mode = TextServer.AUTOWRAP_WORD
	card.pressed.connect(_on_card_pressed.bind(upgrade))
	return card


func _on_card_pressed(upgrade: UpgradeEffect) -> void:
	visible = false
	CultivationManager.select_upgrade(upgrade)

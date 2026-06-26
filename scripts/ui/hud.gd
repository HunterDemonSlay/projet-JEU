class_name HUD
extends CanvasLayer
## Affichage temps réel des PV, du Qi et du Royaume de Cultivation actuel.
##
## Pur affichage : ce script ne lit ni n'écrit jamais directement les
## données du joueur après l'initialisation. Il se contente d'écouter les
## signaux `health_changed`, `qi_changed` et `realm_changed` émis par
## `Player`, ce qui garde l'UI totalement découplée de la logique de jeu.

@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var qi_bar: ProgressBar = $MarginContainer/VBoxContainer/QiBar
@onready var realm_label: Label = $MarginContainer/VBoxContainer/RealmLabel


func _ready() -> void:
	# Doit rester visible et à jour même pendant la pause du menu de percée.
	process_mode = Node.PROCESS_MODE_ALWAYS


## À appeler une fois depuis World.gd au démarrage de la partie, pour relier
## le HUD au joueur courant. Connecte les signaux puis synchronise
## immédiatement l'affichage avec l'état actuel du joueur.
func bind_player(player: Player) -> void:
	player.health_changed.connect(_on_health_changed)
	player.qi_changed.connect(_on_qi_changed)
	player.realm_changed.connect(_on_realm_changed)

	_on_health_changed(player.stats.health, player.stats.max_health)
	_on_qi_changed(player.stats.qi, player.stats.max_qi)
	_on_realm_changed(player.stats.get_realm_name())


func _on_health_changed(current: float, max_value: float) -> void:
	health_bar.max_value = max_value
	health_bar.value = current


func _on_qi_changed(current: float, max_value: float) -> void:
	qi_bar.max_value = max_value
	qi_bar.value = current


func _on_realm_changed(realm_name: String) -> void:
	realm_label.text = realm_name

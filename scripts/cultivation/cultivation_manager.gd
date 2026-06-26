class_name CultivationManager
extends Node
## Autoload singleton : gère la boucle de percée (Breakthrough) de Cultivation.
##
## Écoute `Player.breakthrough_reached` (émis quand le Qi atteint son
## maximum). À ce moment : met le jeu en pause, tire 3 améliorations
## distinctes au hasard dans le pool, et notifie l'UI via `upgrades_offered`.
## L'UI appelle ensuite `select_upgrade()` avec le choix du joueur, ce qui
## applique l'effet et relance la partie.

## Émis avec les 3 choix proposés ; à connecter par l'écran de percée (UI).
signal upgrades_offered(choices: Array[UpgradeEffect])

## Pool de tous les Manuels Secrets disponibles. Ajouter une ligne ici suffit
## à faire entrer une nouvelle amélioration dans la rotation aléatoire.
var _upgrade_pool: Array[UpgradeEffect] = [
	SpeedUpgrade.new(),
	QiStrikeDamageUpgrade.new(),
	QiRegenUpgrade.new(),
]

var _player: Player
var _pending_choices: Array[UpgradeEffect] = []


func _ready() -> void:
	# Doit continuer à fonctionner (et être cliquable) même quand
	# get_tree().paused = true gèle le reste de la partie.
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_connect_to_player")


## Le joueur n'existe pas encore au moment où l'autoload devient _ready() ;
## on attend la fin de la frame (scène principale chargée) pour le résoudre.
func _connect_to_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.breakthrough_reached.connect(_on_breakthrough_reached)


func _on_breakthrough_reached() -> void:
	_pending_choices = _pick_random_upgrades(3)
	get_tree().paused = true
	upgrades_offered.emit(_pending_choices)


## Tire `count` améliorations distinctes au hasard dans le pool.
func _pick_random_upgrades(count: int) -> Array[UpgradeEffect]:
	var pool := _upgrade_pool.duplicate()
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


## À appeler par l'UI quand le joueur clique sur un des 3 choix proposés.
func select_upgrade(upgrade: UpgradeEffect) -> void:
	if is_instance_valid(_player):
		upgrade.apply(_player)
	_pending_choices.clear()
	get_tree().paused = false

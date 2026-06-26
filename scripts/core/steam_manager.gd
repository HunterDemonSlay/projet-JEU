extends Node
## Autoload singleton (nom déclaré dans project.godot : "SteamManager").
## Pas de class_name : éviterait un conflit avec le nom de l'autoload
## (déjà rencontré avec CultivationManager à l'Étape 5).
##
## Abstraction au-dessus de l'API Steam (plugin GodotSteam, optionnel).
## Le reste du jeu n'appelle jamais GodotSteam directement : il passe par
## `unlock_achievement()` ici, qui bascule de façon transparente sur un
## "mode simulation" si Steam n'est pas disponible (plugin absent, jeu
## lancé hors de Steam, init échouée...). Ainsi aucun appel à une API
## potentiellement inexistante ne peut planter le jeu.

## True une fois l'API Steam réellement initialisée. False en mode simulation.
var is_steam_active: bool = false

## Référence vers le singleton "Steam" exposé par GodotSteam, ou null en mode simulation.
var _steam: Object

## En mode simulation, on garde quand même la trace des succès "débloqués"
## (utile pour le debug/les tests, et pour éviter de spammer la console).
var _mock_unlocked_achievements: Dictionary = {}


func _ready() -> void:
	_try_init_steam()
	if not is_steam_active:
		print("SteamManager: Steam non disponible, passage en mode simulation.")


func _process(_delta: float) -> void:
	# GodotSteam exige un run_callbacks() régulier pour faire avancer
	# l'API (réception des résultats asynchrones, etc.).
	if is_steam_active:
		_steam.run_callbacks()


## Tente d'initialiser l'API Steam via GodotSteam. Ne lève jamais d'erreur
## bloquante : toute condition manquante (plugin absent, init refusée par
## Steam) bascule simplement `is_steam_active` à false.
func _try_init_steam() -> void:
	if not Engine.has_singleton("Steam"):
		return  # Plugin GodotSteam non compilé dans ce build : mode simulation.

	_steam = Engine.get_singleton("Steam")

	var init_result: Dictionary = _steam.steamInitEx()
	if init_result.get("status", 1) != 0:
		push_warning("SteamManager: échec de l'initialisation Steam (%s)." % init_result.get("verbal", "raison inconnue"))
		_steam = null
		return

	is_steam_active = true


## À appeler depuis n'importe où dans le jeu pour débloquer un succès Steam
## (ex: SteamManager.unlock_achievement("PREMIERE_PERCEE")).
## `api_name` doit correspondre exactement à l'API Name configuré sur la
## page Steamworks du jeu.
func unlock_achievement(api_name: String) -> void:
	if is_steam_active:
		_steam.setAchievement(api_name)
		_steam.storeStats()
		return

	if not _mock_unlocked_achievements.has(api_name):
		_mock_unlocked_achievements[api_name] = true
		print("[Mode simulation] Succès débloqué : %s" % api_name)


## Utile pour l'UI (ex: griser un succès déjà obtenu) sans dépendre de Steam.
func is_achievement_unlocked(api_name: String) -> bool:
	if is_steam_active:
		var result: Dictionary = _steam.getAchievement(api_name)
		return result.get("achieved", false)
	return _mock_unlocked_achievements.has(api_name)

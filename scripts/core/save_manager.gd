extends Node
## Autoload singleton (nom déclaré dans project.godot : "SaveManager").
## Pas de class_name : éviterait un conflit avec le nom de l'autoload
## (déjà rencontré avec CultivationManager à l'Étape 5).
##
## Persiste la méta-progression (entre les parties) en JSON dans user://.
## N'importe quel script peut lire/écrire via les accesseurs publics
## ci-dessous ; personne d'autre ne doit toucher au fichier directement.

const SAVE_PATH := "user://savegame.json"
## Incrémenté si la structure change un jour ; permet de migrer d'anciennes
## sauvegardes au lieu de simplement les rejeter.
const SAVE_VERSION := 1

## Données actuellement chargées en mémoire. Toujours valide après _ready()
## (load_game() retombe sur une sauvegarde par défaut si besoin).
var data: Dictionary = {}


func _ready() -> void:
	load_game()


## Construit une sauvegarde par défaut "vierge". Une fonction (pas une
## constante) pour ne jamais renvoyer une référence partagée au même
## Dictionary, ce qui causerait des bugs d'aliasing entre appels.
func _default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"spirit_stones": 0,
		"max_realm_reached": 0,
		"permanent_upgrades": {},
	}


## Charge la sauvegarde depuis le disque. En l'absence de fichier, ou s'il
## est corrompu/illisible, retombe silencieusement sur une sauvegarde par
## défaut plutôt que de planter — la meilleure méta-progression perdue
## reste préférable à un jeu qui ne démarre plus.
func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		data = _default_data()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: impossible d'ouvrir %s (%s). Sauvegarde par défaut utilisée." % [SAVE_PATH, FileAccess.get_open_error()])
		data = _default_data()
		return

	var raw_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw_text)
	if not (parsed is Dictionary) or not _is_valid_save(parsed):
		push_warning("SaveManager: fichier de sauvegarde corrompu ou invalide. Sauvegarde par défaut utilisée.")
		data = _default_data()
		return

	# Fusionne sur une base par défaut : une sauvegarde plus ancienne (avant
	# l'ajout d'un nouveau champ) reste utilisable sans tout perdre.
	data = _default_data()
	for key in parsed.keys():
		data[key] = parsed[key]


## Écrit la sauvegarde actuelle sur le disque, au format JSON lisible.
func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: impossible d'écrire %s (%s)." % [SAVE_PATH, FileAccess.get_open_error()])
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()


## Vérifie qu'un Dictionary parsé a la forme minimale attendue avant de lui
## faire confiance (un JSON valide mais arbitraire ne doit pas planter le jeu).
func _is_valid_save(candidate: Dictionary) -> bool:
	return candidate.get("spirit_stones") is float or candidate.get("spirit_stones") is int


## -- Accesseurs publics : aucun autre script ne doit lire/écrire `data` directement. --

func get_spirit_stones() -> int:
	return data.get("spirit_stones", 0)


func add_spirit_stones(amount: int) -> void:
	data["spirit_stones"] = get_spirit_stones() + amount


func get_max_realm_reached() -> int:
	return data.get("max_realm_reached", 0)


## Ne fait jamais reculer le record (utiliser à chaque percée du joueur).
func record_realm_reached(realm_index: int) -> void:
	data["max_realm_reached"] = maxi(get_max_realm_reached(), realm_index)


func get_permanent_upgrade_tier(upgrade_id: String) -> int:
	var upgrades: Dictionary = data.get("permanent_upgrades", {})
	return upgrades.get(upgrade_id, 0)


func set_permanent_upgrade_tier(upgrade_id: String, tier: int) -> void:
	var upgrades: Dictionary = data.get("permanent_upgrades", {})
	upgrades[upgrade_id] = tier
	data["permanent_upgrades"] = upgrades

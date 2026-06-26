class_name Player
extends CharacterBody2D
## Contrôleur du personnage joueur.
##
## Gère le déplacement fluide à 8 directions (ZQSD / flèches), avec
## accélération et friction. Les statistiques de Cultivation (Qi, vie,
## vitesse, attraction) sont déléguées à la Resource `CultivationStats`
## pour rester découplées de la logique de mouvement.

## Émis quand le Qi atteint son maximum : déclenche une percée de Cultivation
## (écouté par CultivationManager pour proposer un choix d'amélioration).
signal breakthrough_reached
## Émis à chaque variation de vie. Écouté par le HUD (lecture seule).
signal health_changed(current: float, max_value: float)
## Émis à chaque variation de Qi. Écouté par le HUD (lecture seule).
signal qi_changed(current: float, max_value: float)
## Émis quand le Royaume de Cultivation change, après une percée.
signal realm_changed(realm_name: String)
## Émis une seule fois quand les PV tombent à zéro (fin de la run).
signal died

@export_group("Mouvement")
## Vitesse de déplacement maximale, en pixels/seconde.
@export var max_speed: float = 300.0
## Accélération appliquée lorsque le joueur appuie sur une direction.
@export var acceleration: float = 2000.0
## Décélération appliquée en l'absence d'input, pour un arrêt progressif.
@export var friction: float = 1800.0

@export_group("Cultivation")
## Statistiques du joueur (Qi, vie, vitesse, attraction). Voir CultivationStats.
@export var stats: CultivationStats = CultivationStats.new()

@export_group("Habillage")
## Position du Marker2D SwordTip (pointe d'épée pour la traînée de combat),
## relative à PlayerSprite. Ajustable au pixel près depuis l'inspecteur sans
## toucher au code, tant qu'on n'édite pas la scène dans l'éditeur visuel.
@export var sword_tip_offset: Vector2 = Vector2(100, -50):
	set(value):
		sword_tip_offset = value
		if sword_tip != null:
			sword_tip.position = value

## Chemin de l'illustration HD unique. Chargée automatiquement si présente ;
## sinon le PlaceholderTexture2D de la scène reste affiché (aucune erreur).
const PLAYER_SPRITE_PATH := "res://assets/player/player_sprite.png"

## Référence à la zone de ramassage, dont le rayon suit `stats.pickup_radius`.
@onready var pickup_area: Area2D = $PickupArea
@onready var pickup_shape: CollisionShape2D = $PickupArea/CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
## Pétales de fleurs de prunier qui se détachent du personnage en mouvement
## (esthétique manhwa). Purement visuel : aucune incidence sur le gameplay.
@onready var plum_blossom_particles: GPUParticles2D = $PlumBlossomParticles
## Illustration HD unique qui remplace le rig cut-out (CharacterRig, masqué).
@onready var player_sprite: Sprite2D = $PlayerSprite
## Pointe de l'épée, suivie par SwordTrail pour dessiner la traînée de combat.
@onready var sword_tip: Marker2D = $PlayerSprite/SwordTip

## Vitesse minimale (px/s) à partir de laquelle les pétales se détachent.
const PETAL_EMIT_SPEED_THRESHOLD := 10.0

## Pierres d'Esprit accumulées pendant cette run (non encore persistées).
## Voir World._on_player_died(), qui les crédite à SaveManager à la mort.
var session_spirit_stones: int = 0

var _is_dead: bool = false


func _ready() -> void:
	# Permet aux ennemis de retrouver le joueur via get_first_node_in_group(),
	# sans dépendance directe ni recherche par chemin de scène.
	add_to_group("player")
	# Déclarer un groupe via `groups = [...]` dans le .tscn ne fonctionne pas
	# de façon fiable (constaté en testant le combat en conditions réelles :
	# le groupe restait vide au runtime) ; add_to_group() en code est sûr.
	hurtbox.add_to_group("player_hurtbox")
	_update_pickup_radius()
	pickup_area.area_entered.connect(_on_pickup_area_entered)

	# Réapplique l'offset maintenant que sword_tip (@onready) est résolu : le
	# setter de sword_tip_offset s'exécute aussi avant _ready() (à la
	# construction, avec sa valeur par défaut), trop tôt pour toucher au nœud.
	sword_tip.position = sword_tip_offset

	if ResourceLoader.exists(PLAYER_SPRITE_PATH):
		player_sprite.texture = load(PLAYER_SPRITE_PATH)


func _process(delta: float) -> void:
	if stats.qi_regen_rate > 0.0:
		add_qi(stats.qi_regen_rate * delta)


func _physics_process(delta: float) -> void:
	var input_direction := _get_input_direction()
	velocity = _compute_velocity(velocity, input_direction, delta)
	move_and_slide()

	plum_blossom_particles.emitting = velocity.length() > PETAL_EMIT_SPEED_THRESHOLD


## Ajoute du Qi et déclenche une percée (breakthrough) si le maximum est atteint.
## Le palier suivant demande un peu plus de Qi, pour une courbe de progression
## qui ralentit naturellement (comme la montée en Royaume dans le Murim).
func add_qi(amount: float) -> void:
	stats.restore_qi(amount)
	qi_changed.emit(stats.qi, stats.max_qi)

	if stats.qi >= stats.max_qi:
		stats.qi = 0.0
		stats.max_qi *= 1.2
		stats.current_realm_index += 1
		qi_changed.emit(stats.qi, stats.max_qi)
		realm_changed.emit(stats.get_realm_name())
		breakthrough_reached.emit()

		SaveManager.record_realm_reached(stats.current_realm_index)
		if stats.get_realm_name() == "Fondation du Qi":
			SteamManager.unlock_achievement("PREMIERE_PERCEE")


## Appelé par la zone de contact d'un ennemi (voir Enemy._on_hurtbox_area_entered).
func take_damage_from_enemy(amount: float) -> void:
	if _is_dead:
		return

	stats.take_damage(amount)
	health_changed.emit(stats.health, stats.max_health)

	if not stats.is_alive():
		_is_dead = true
		died.emit()


## Appelé par un ennemi à sa mort (voir Enemy._grant_spirit_stones).
func earn_spirit_stones(amount: int) -> void:
	session_spirit_stones += amount


## Appelé quand un objet (typiquement un QiOrb) entre dans le rayon d'attraction.
## Démarre son vol vers le joueur ; QiOrb gère lui-même sa propre attraction.
func _on_pickup_area_entered(area: Area2D) -> void:
	if area.has_method("start_attraction"):
		area.start_attraction(self)


## Lit les actions d'input (ZQSD / flèches) et retourne un vecteur normalisé.
func _get_input_direction() -> Vector2:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return direction


## Calcule la nouvelle vélocité à partir de la vélocité actuelle, de la
## direction d'input et du delta-time. Applique l'accélération si une
## direction est pressée, sinon la friction pour un arrêt progressif.
func _compute_velocity(current_velocity: Vector2, input_direction: Vector2, delta: float) -> Vector2:
	var effective_max_speed := max_speed * stats.move_speed_multiplier

	if input_direction != Vector2.ZERO:
		var target_velocity := input_direction * effective_max_speed
		return current_velocity.move_toward(target_velocity, acceleration * delta)

	return current_velocity.move_toward(Vector2.ZERO, friction * delta)


## Synchronise le rayon de la zone de ramassage avec les statistiques de Cultivation.
## À appeler après toute modification de `stats.pickup_radius`.
func _update_pickup_radius() -> void:
	if pickup_shape.shape is CircleShape2D:
		(pickup_shape.shape as CircleShape2D).radius = stats.pickup_radius

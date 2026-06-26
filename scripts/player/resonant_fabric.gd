extends Node2D
## Fait osciller un morceau de tissu/cheveux (RobeTail, Hair) de façon
## procédurale, sans aucune keyframe d'AnimationPlayer.
##
## Combine 3 composantes, pondérées par la vitesse du `Player` :
## 1. Un balancement d'ambiance ("vent léger"), actif même à l'arrêt.
## 2. Une traînée de mouvement : le tissu est tiré dans la direction opposée
##    au déplacement, proportionnellement à la vitesse actuelle.
## 3. Un battement haute fréquence ("flutter"), qui casse la régularité
##    parfaite du sinus pour un rendu plus organique en course rapide.
## Le résultat est lissé par interpolation exponentielle (lerp_angle avec un
## facteur dépendant du delta) plutôt qu'assigné directement, pour donner un
## effet de ressort/inertie au lieu d'un mouvement mécanique.
##
## Attaché directement aux nœuds Hair et RobeTail (pas à leurs Sprite2D
## enfants) : ce sont eux qui pivotent, le sprite suit par héritage de
## transform. Ne JAMAIS aussi animer leur rotation depuis l'AnimationPlayer :
## les deux entreraient en conflit (cf. Player_animator.gd).

@export_group("Balancement d'ambiance")
## Amplitude du balancement permanent, même à l'arrêt (degrés).
@export var idle_sway_amplitude_deg: float = 8.0
## Fréquence du balancement permanent.
@export var idle_sway_frequency: float = 1.5

@export_group("Réaction au mouvement")
## Amplitude supplémentaire à pleine vitesse (degrés), ajoutée à l'idle sway.
@export var velocity_sway_amplitude_deg: float = 25.0
## Vitesse de référence (px/s) pour normaliser l'effet de la vélocité.
## Doit correspondre à peu près à Player.max_speed.
@export var max_speed_reference: float = 300.0

@export_group("Ressort")
## Plus la valeur est élevée, plus le tissu "rattrape" vite sa cible
## (réactif). Une valeur basse donne un effet plus lourd/trainant.
@export var spring_responsiveness: float = 6.0

var _time: float = 0.0
var _base_rotation: float
var _player: Player


func _ready() -> void:
	_base_rotation = rotation
	_player = _find_player_ancestor()


func _process(delta: float) -> void:
	_time += delta

	var velocity := _player.velocity if is_instance_valid(_player) else Vector2.ZERO
	var speed_ratio := clampf(velocity.length() / max_speed_reference, 0.0, 1.0)

	var idle_sway := sin(_time * idle_sway_frequency) * deg_to_rad(idle_sway_amplitude_deg)

	# Le tissu traîne derrière le sens du déplacement horizontal.
	var drag_direction := signf(-velocity.x) if absf(velocity.x) > 1.0 else 0.0
	var motion_sway := drag_direction * speed_ratio * deg_to_rad(velocity_sway_amplitude_deg)

	var flutter := sin(_time * idle_sway_frequency * 4.0) * deg_to_rad(velocity_sway_amplitude_deg) * 0.25 * speed_ratio

	var target_rotation := _base_rotation + idle_sway + motion_sway + flutter

	# Lissage exponentiel indépendant du framerate (cf. Godot docs sur
	# lerp_angle + exp(-k*delta)) : se comporte comme un ressort amorti.
	rotation = lerp_angle(rotation, target_rotation, 1.0 - exp(-spring_responsiveness * delta))


## Remonte l'arbre de scène jusqu'à trouver le Player (le rig est instancié
## comme enfant de Player, potentiellement plusieurs niveaux plus bas).
func _find_player_ancestor() -> Player:
	var node := get_parent()
	while node != null:
		if node is Player:
			return node
		node = node.get_parent()
	return null

class_name SwordTrail
extends Line2D
## Traînée géométrique de l'épée, sans aucune image externe : un Line2D qui
## suit la position d'un Marker2D placé sur la pointe de la lame.
##
## `top_level = true` est essentiel : ça permet d'enregistrer les points en
## coordonnées globales malgré le fait que ce nœud soit imbriqué profondément
## dans le rig (qui tourne/bouge avec l'animation de bras), exactement comme
## pour TrailGlow/TrailCore sur Projectile.gd. Sans ça, la traînée se
## contracterait en un petit segment local au lieu de dessiner l'arc réel du
## mouvement de l'épée.
##
## Composant "bête" et réutilisable : il ne sait rien du combat ni de
## l'AnimationPlayer. C'est à l'appelant (voir PlayerAnimator.gd) de
## déclencher start_trail()/stop_trail() au bon moment.

## Marker2D sur la pointe de la lame, à assigner dans l'inspecteur.
@export var tip_marker: Marker2D
## Nombre de points conservés (fenêtre glissante). Plus haut = traînée plus longue.
@export var max_points: int = 16
## Couleur à la pointe (point le plus récent, proche de l'épée).
@export var tip_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## Couleur en fin de traînée (point le plus ancien, transparent).
@export var tail_color: Color = Color(1.0, 0.4, 0.75, 0.0)

var _is_active: bool = false


func _ready() -> void:
	# Coordonnées globales malgré la parenté avec un membre du rig qui bouge.
	top_level = true
	visible = false
	add_to_group("sword_trail")
	_apply_gradient()


func _apply_gradient() -> void:
	var trail_gradient := Gradient.new()
	trail_gradient.set_color(0, tail_color)
	trail_gradient.set_color(1, tip_color)
	gradient = trail_gradient


func _process(_delta: float) -> void:
	if _is_active and is_instance_valid(tip_marker):
		add_point(tip_marker.global_position)
		if get_point_count() > max_points:
			remove_point(0)
		visible = true
	elif get_point_count() > 0:
		# Laisse la traînée s'estomper progressivement plutôt que de
		# disparaître d'un coup : on continue à retirer le point le plus
		# ancien chaque frame même après l'arrêt de l'attaque.
		remove_point(0)
	else:
		visible = false


## À appeler au début du mouvement de l'épée (voir PlayerAnimator.gd).
func start_trail() -> void:
	_is_active = true


## À appeler à la fin du mouvement de l'épée. La traînée déjà dessinée
## continue de s'estomper naturellement (voir _process), elle ne se coupe pas net.
func stop_trail() -> void:
	_is_active = false

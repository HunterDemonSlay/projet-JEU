class_name QiImpactVFX
extends Sprite2D
## Explosion de Qi jouée brièvement à l'endroit où un projectile touche un
## ennemi. Grossit rapidement via un Tween, puis s'autodétruit — pas géré
## par ObjectPooler : contrairement aux ennemis/projectiles, ces VFX sont
## déclenchés bien moins souvent (un par impact, pas un par frame), donc le
## coût d'instantiate()/queue_free() est négligeable ici.

## Chemin par défaut où déposer votre image d'explosion (fond noir, mode
## additif). Chargée automatiquement si `texture` n'est pas déjà assignée
## dans l'inspecteur — voir _ready(). ResourceLoader.exists() évite toute
## erreur si le fichier n'existe pas encore (contrairement à preload(), qui
## empêcherait le projet entier de s'ouvrir tant que le fichier est absent).
const DEFAULT_TEXTURE_PATH := "res://assets/vfx/qi_impact_burst.png"

## Durée de la croissance initiale (effet "pop").
@export var grow_duration: float = 0.12
## Durée totale avant autodestruction.
@export var lifetime: float = 0.3
## Échelle de départ (petit, pour l'effet de croissance rapide).
@export var start_scale: float = 0.05
## Échelle finale. La texture source (qi_impact_burst.png) est une
## explosion HD pleine taille ; 1.3 la faisait couvrir tout l'écran.
@export var end_scale: float = 0.3


func _ready() -> void:
	if texture == null and ResourceLoader.exists(DEFAULT_TEXTURE_PATH):
		texture = load(DEFAULT_TEXTURE_PATH)

	scale = Vector2.ONE * start_scale
	modulate.a = 1.0

	var grow_tween := create_tween()
	grow_tween.tween_property(self, "scale", Vector2.ONE * end_scale, grow_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	get_tree().create_timer(lifetime).timeout.connect(queue_free)


## Raccourci pratique : instancie ce VFX à `position`, dans `parent`.
## Utilisé par SwordQiProjectile et Projectile au moment de l'impact.
static func spawn(scene: PackedScene, parent: Node, global_pos: Vector2) -> void:
	if scene == null:
		return
	var instance := scene.instantiate() as Node2D
	instance.global_position = global_pos
	parent.call_deferred("add_child", instance)

extends AnimationPlayer
## Pilote les transitions entre les états d'animation du joueur : Idle, Run
## (cheveux/robe qui volent), et QiStrike_Cast (attaque, non interruptible).
##
## Le personnage utilise désormais une illustration HD unique (PlayerSprite)
## à la place du rig articulé (CharacterRig, masqué) : il n'y a plus de
## squelette/spritesheet à piloter par images-clés. enable_body_animations
## court-circuite donc tout _process()/play() lié au corps, indépendamment de
## has_animation() (qui reste en place comme garde-fou en profondeur). Le
## déclenchement de la traînée d'épée (SwordTrail), lui, continue de
## fonctionner : il ne dépend d'aucun clip d'AnimationPlayer.
## Repassez ce flag à true le jour où vous remplacez l'illustration unique
## par un spritesheet animé et créez les clips Idle/Run/QiStrike_Cast.
@export var enable_body_animations: bool = false

const ANIM_IDLE := "Idle"
const ANIM_RUN := "Run"
const ANIM_ATTACK := "QiStrike_Cast"

## Vitesse minimale (px/s) à partir de laquelle on bascule sur "Run".
const RUN_SPEED_THRESHOLD := 10.0

## Durée pendant laquelle la traînée d'épée reste active après une attaque,
## tant que le clip QiStrike_Cast n'existe pas encore pour la piloter
## précisément via une piste "Call Method". À remplacer par des appels
## start_trail()/stop_trail() placés aux bonnes images-clés une fois le
## swing réellement animé.
const SWORD_TRAIL_DURATION := 0.3

@onready var _player: Player = get_parent()
@onready var _weapon: WeaponBase = get_parent().get_node("WeaponPivot")
@onready var _sword_trail: SwordTrail = get_tree().get_first_node_in_group("sword_trail")

## Empêche le mouvement (Idle/Run) d'interrompre une attaque en cours :
## la priorité va toujours à l'animation de cast tant qu'elle joue.
var _is_casting: bool = false


func _ready() -> void:
	animation_finished.connect(_on_animation_finished)
	_weapon.attack_performed.connect(_on_attack_performed)
	_weapon.attack_performed.connect(_on_attack_performed_trail)


func _process(_delta: float) -> void:
	if not enable_body_animations or _is_casting:
		return

	var target_animation := ANIM_RUN if _player.velocity.length() > RUN_SPEED_THRESHOLD else ANIM_IDLE
	if has_animation(target_animation) and current_animation != target_animation:
		play(target_animation)


func _on_attack_performed() -> void:
	if not enable_body_animations or not has_animation(ANIM_ATTACK):
		return
	_is_casting = true
	play(ANIM_ATTACK)


## Rend la main au cycle Idle/Run dès que l'animation d'attaque se termine.
func _on_animation_finished(finished_animation: StringName) -> void:
	if finished_animation == ANIM_ATTACK:
		_is_casting = false


## Démarre la traînée de l'épée et programme son arrêt. Indépendant de
## has_animation(ANIM_ATTACK) : contrairement au corps du personnage, la
## traînée n'a pas besoin d'un clip pour avoir un effet visuel dès maintenant.
func _on_attack_performed_trail() -> void:
	if not is_instance_valid(_sword_trail):
		return
	_sword_trail.start_trail()
	get_tree().create_timer(SWORD_TRAIL_DURATION).timeout.connect(_sword_trail.stop_trail)

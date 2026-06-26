extends AnimationPlayer
## Pilote les transitions entre les états d'animation du joueur : Idle, Run
## (cheveux/robe qui volent), et QiStrike_Cast (attaque, non interruptible).
##
## Les clips n'existent pas encore (le personnage n'a qu'un sprite
## placeholder) : chaque appel à play() est protégé par has_animation(), donc
## ce script ne provoque aucune erreur tant que l'art définitif n'est pas
## prêt, et fonctionnera tel quel dès que les animations "Idle"/"Run"/
## "QiStrike_Cast" seront ajoutées à l'AnimationPlayer.

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
	if _is_casting:
		return

	var target_animation := ANIM_RUN if _player.velocity.length() > RUN_SPEED_THRESHOLD else ANIM_IDLE
	if has_animation(target_animation) and current_animation != target_animation:
		play(target_animation)


func _on_attack_performed() -> void:
	if not has_animation(ANIM_ATTACK):
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

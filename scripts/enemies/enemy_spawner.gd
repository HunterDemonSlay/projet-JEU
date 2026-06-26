class_name EnemySpawner
extends Node2D
## Fait apparaître des ennemis à intervalle régulier, juste hors du champ
## de vision de la caméra du joueur, pour éviter le pop-in visuel.
##
## Le rayon de spawn est recalculé à chaque vague à partir de la taille du
## viewport et du zoom de la caméra active, donc il reste correct quel que
## soit la résolution ou un éventuel zoom dynamique.

## Scène de l'ennemi à instancier (doit hériter de Enemy.gd).
@export var enemy_scene: PackedScene
## Délai entre deux vagues, en secondes.
@export var spawn_interval: float = 2.0
## Nombre d'ennemis créés à chaque vague.
@export var enemies_per_wave: int = 1
## Marge ajoutée au-delà du bord visible de la caméra, pour garantir que
## l'ennemi apparaît bien hors champ même avec une caméra qui se déplace.
@export var spawn_margin: float = 64.0
## Nombre d'ennemis vivants au-delà duquel le spawner met en pause les
## nouvelles vagues (garde-fou de performance).
@export var max_active_enemies: int = 300

## Cache de la référence au joueur, résolue une seule fois.
var _player: Node2D
var _spawn_timer: Timer


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")

	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.autostart = true
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)


func _on_spawn_timer_timeout() -> void:
	if not is_instance_valid(_player) or enemy_scene == null:
		return
	if _count_active_enemies() >= max_active_enemies:
		return

	for _i in enemies_per_wave:
		_spawn_one_enemy()


## Recycle un ennemi inactif du pool (ou en instancie un nouveau si le pool
## est vide) et le repositionne hors champ de caméra. Remplace l'ancien
## couple instantiate()/queue_free() pour éviter le coût de
## création/destruction répétée de centaines d'ennemis.
func _spawn_one_enemy() -> void:
	var enemy := ObjectPooler.acquire(enemy_scene, get_tree().current_scene)
	enemy.global_position = _get_random_position_outside_view()


## Compte les ennemis actuellement actifs (visibles), qu'ils viennent d'être
## instanciés ou recyclés depuis le pool. Les ennemis "morts" restent dans
## l'arbre de scène (cachés, en attente de recyclage) : on ne peut donc plus
## se fier à tree_exited pour les compter, contrairement à avant le pooling.
func _count_active_enemies() -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.visible:
			count += 1
	return count


## Calcule un point aléatoire sur un cercle centré sur le joueur, dont le
## rayon dépasse juste la diagonale visible de la caméra (+ marge).
func _get_random_position_outside_view() -> Vector2:
	var spawn_radius := _get_camera_visible_radius() + spawn_margin
	var angle := randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * spawn_radius
	return _player.global_position + offset


## Demi-diagonale de la zone visible par la caméra active, en unités monde
## (tient compte du zoom de la caméra).
func _get_camera_visible_radius() -> float:
	var camera := get_viewport().get_camera_2d()
	var viewport_size := get_viewport_rect().size

	if camera != null:
		viewport_size /= camera.zoom

	return viewport_size.length() * 0.5

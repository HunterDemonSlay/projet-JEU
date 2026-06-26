extends Node
## Autoload singleton (nom déclaré dans project.godot : "ObjectPooler").
## Pas de class_name ici : entrerait en conflit avec le nom de l'autoload
## (déjà rencontré avec CultivationManager à l'Étape 5).
##
## Bassin d'objets générique : recycle des instances de scène (ennemis,
## projectiles...) au lieu d'enchaîner `instantiate()` / `queue_free()`.
## Avec des centaines/milliers d'entités par vague, créer et détruire des
## nœuds en continu coûte cher (allocation, construction de l'arbre de
## scène, désallocation) ; les réutiliser élimine ce coût.
##
## Contrat attendu sur les scènes mises en pool (voir Enemy.gd, Projectile.gd) :
## - `on_pool_activate()` (optionnelle) : réinitialise l'état (vie,
##   monitoring de collision...) quand l'instance est réutilisée.
## - `on_pool_deactivate()` (optionnelle) : coupe ce qui doit l'être
##   (monitoring, vélocité...) quand l'instance retourne au pool.
## - une méthode `despawn()` sur l'entité elle-même, qui appelle
##   `ObjectPooler.release(self)` au lieu de `queue_free()`.

const POOL_KEY_META := "_object_pooler_key"

## String (resource_path de la scène) -> Array[Node] (instances inactives, prêtes à être réutilisées).
var _pools: Dictionary = {}


## Renvoie une instance prête à l'emploi : réutilise une instance inactive
## du pool de `scene` si disponible, sinon en instancie une nouvelle (le
## pool grossit automatiquement jusqu'à couvrir le pic de charge observé).
func acquire(scene: PackedScene, parent: Node) -> Node:
	var key := scene.resource_path
	var pool: Array = _pools.get(key, [])

	var instance: Node
	if pool.is_empty():
		instance = scene.instantiate()
		instance.set_meta(POOL_KEY_META, key)
		parent.add_child(instance)
	else:
		instance = pool.pop_back()
		if instance.get_parent() != parent:
			_reparent(instance, parent)

	_pools[key] = pool
	_activate(instance)
	return instance


## Renvoie `instance` dans son pool d'origine pour réutilisation future.
## À appeler uniquement via la méthode `despawn()` de l'instance elle-même,
## jamais directement depuis l'extérieur.
func release(instance: Node) -> void:
	if not instance.has_meta(POOL_KEY_META):
		# Instance non gérée par le pooler (ex: créée hors de acquire()) :
		# on retombe sur le comportement classique plutôt que de la perdre.
		instance.queue_free()
		return

	_deactivate(instance)

	var key: String = instance.get_meta(POOL_KEY_META)
	if not _pools.has(key):
		_pools[key] = []
	_pools[key].append(instance)


func _activate(instance: Node) -> void:
	instance.visible = true
	instance.set_physics_process(true)
	instance.set_process(true)
	if instance.has_method("on_pool_activate"):
		instance.on_pool_activate()


func _deactivate(instance: Node) -> void:
	instance.visible = false
	instance.set_physics_process(false)
	instance.set_process(false)
	if instance.has_method("on_pool_deactivate"):
		instance.on_pool_deactivate()


func _reparent(instance: Node, new_parent: Node) -> void:
	var old_parent := instance.get_parent()
	if old_parent:
		old_parent.remove_child(instance)
	new_parent.add_child(instance)

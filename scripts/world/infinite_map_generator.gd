class_name InfiniteMapGenerator
extends Node2D
## Génère le monde à l'infini, par chunks, au fur et à mesure que le joueur
## se déplace. Remplace l'ancien MapDecorator (carte finie).
##
## Choix technique important : Godot 4 propose un vrai système de "Terrains"
## (set_cells_terrain_connect) pour des transitions de bord lissées
## automatiquement, mais il exige des tuiles de coin/bord configurées
## visuellement dans l'éditeur TileSet (peering bits par tuile) — un travail
## d'éditeur, pas de code. Nos tuiles actuelles sont des couleurs plates sans
## variantes de bord ; utiliser le système de Terrain ne changerait donc rien
## au résultat visuel (toujours des carrés nets), tout en ajoutant un risque
## réel de configuration cassée que je ne peux pas vérifier sans rendu visuel.
## On peint donc chaque biome directement avec set_cell() : moins "joli aux
## bords" qu'un vrai autotile, mais fiable et entièrement testable.
##
## Performance : seuls les chunks dans `chunk_render_distance` autour du
## joueur sont peints. Les chunks qui sortent de ce rayon sont déchargés
## (tuiles effacées, props libérées) pour ne pas accumuler indéfiniment de la
## mémoire pendant une run. Le système de pooling des ennemis/projectiles
## (ObjectPooler, Étape 6) est ce qui garantit déjà les 60 FPS avec des
## centaines/milliers d'entités ; la génération de carte n'a aucune incidence
## sur ce point — son seul rôle ici est de ne pas ajouter un second problème
## de performance (mémoire qui grossit sans limite à mesure qu'on explore).

@export_group("Chunks")
## Taille d'un chunk, en tuiles (32x32 tuiles par chunk, comme demandé).
@export var chunk_size: int = 32
## Rayon de chargement autour du joueur, en chunks.
@export var chunk_render_distance: int = 3

@export_group("Bruit")
## Graine du bruit. Régénérée aléatoirement à chaque partie (voir _ready),
## sauf si vous décochez `randomize_seed` pour reproduire toujours la même carte.
@export var noise_seed: int = 12345
@export var randomize_seed: bool = true

@export_group("Tileset")
## IDs des TileSetAtlasSource dans ground_tileset.tres. Pas des IDs de
## "Terrain" Godot (voir note d'architecture ci-dessus) : on n'utilise pas
## ce système, juste l'identifiant de la source de tuile à peindre.
@export var grass_source_id: int = 0
@export var dirt_path_source_id: int = 1
@export var water_source_id: int = 2
@export var cliff_source_id: int = 3

@export_group("Végétation")
## Densité d'obstacles (arbres/rochers) : plus haut = moins fréquent.
@export var vegetation_threshold: float = 0.55
## Rayon (en pixels monde) autour de l'origine où aucun obstacle n'apparaît,
## pour garantir que le joueur ne spawn jamais coincé.
@export var obstacle_safe_radius: float = 120.0

const ATLAS_COORDS := Vector2i(0, 0)
## Layer physique "monde solide" : déjà utilisée implicitement par défaut
## sur Player (CharacterBody2D) et Enemy (collision_mask=1), donc un obstacle
## sur cette layer bloque les deux sans toucher à aucun autre script.
const OBSTACLE_COLLISION_LAYER := 1

const OBSTACLE_TEXTURE_PATHS := [
	"res://assets/decor/props/pine_tree.png",
	"res://assets/decor/props/round_tree.png",
	"res://assets/decor/props/rock.png",
]

@onready var ground_layer: TileMapLayer = $GroundTileMapLayer

var _terrain_noise := FastNoiseLite.new()
var _vegetation_noise := FastNoiseLite.new()
var _obstacle_textures: Array[Texture2D] = []

## chunk_coord (Vector2i) -> { "cells": Array[Vector2i], "props": Array[Node] }
var _generated_chunks: Dictionary = {}

var _player: Node2D
## Sentinelle hors de portée pour forcer le premier chargement au démarrage.
var _last_player_chunk: Vector2i = Vector2i(999999, 999999)


func _ready() -> void:
	if randomize_seed:
		randomize()
		noise_seed = randi()

	_configure_noise()
	_load_obstacle_textures()

	_player = get_tree().get_first_node_in_group("player")
	update_chunks()


func _configure_noise() -> void:
	_terrain_noise.seed = noise_seed
	_terrain_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_terrain_noise.frequency = 0.04

	_vegetation_noise.seed = noise_seed + 1
	_vegetation_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_vegetation_noise.frequency = 0.15


func _load_obstacle_textures() -> void:
	for path in OBSTACLE_TEXTURE_PATHS:
		_obstacle_textures.append(load(path) as Texture2D)


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	update_chunks()


## Calcule le chunk du joueur ; ne fait rien de coûteux si on n'a pas changé
## de chunk depuis le dernier appel (appelé chaque frame depuis _process).
func update_chunks() -> void:
	var player_chunk := _world_to_chunk_coord(_player.global_position)
	if player_chunk == _last_player_chunk:
		return
	_last_player_chunk = player_chunk

	var needed_chunks: Dictionary = {}
	for x in range(player_chunk.x - chunk_render_distance, player_chunk.x + chunk_render_distance + 1):
		for y in range(player_chunk.y - chunk_render_distance, player_chunk.y + chunk_render_distance + 1):
			var coord := Vector2i(x, y)
			needed_chunks[coord] = true
			if not _generated_chunks.has(coord):
				_generate_chunk(coord)

	for coord in _generated_chunks.keys().duplicate():
		if not needed_chunks.has(coord):
			_unload_chunk(coord)


func _world_to_chunk_coord(world_position: Vector2) -> Vector2i:
	var chunk_world_size := chunk_size * ground_layer.scale.x * 16.0
	return Vector2i(floori(world_position.x / chunk_world_size), floori(world_position.y / chunk_world_size))


## Peint les tuiles d'un chunk et y disperse des obstacles, selon le bruit.
## Échantillonné en coordonnées de TUILE (pas en pixels), pour des biomes de
## taille cohérente quelle que soit l'échelle visuelle du TileMapLayer.
func _generate_chunk(chunk_coord: Vector2i) -> void:
	var cells: Array[Vector2i] = []
	var props: Array[Node] = []

	var origin := chunk_coord * chunk_size
	for local_x in range(chunk_size):
		for local_y in range(chunk_size):
			var tile_coord := origin + Vector2i(local_x, local_y)
			var biome_value := _terrain_noise.get_noise_2d(tile_coord.x, tile_coord.y)
			var source_id := _biome_source_id(biome_value)

			ground_layer.set_cell(tile_coord, source_id, ATLAS_COORDS)
			cells.append(tile_coord)

			if source_id == grass_source_id:
				_maybe_spawn_obstacle(tile_coord, props)

	_generated_chunks[chunk_coord] = {"cells": cells, "props": props}


## Seuils de biome demandés :
## < -0.2 = Eau ; [-0.2, 0.4) = Herbe (avec chemin de terre sur [0.1, 0.3)) ;
## >= 0.4 = Falaise/Roche.
func _biome_source_id(noise_value: float) -> int:
	if noise_value < -0.2:
		return water_source_id
	if noise_value >= 0.4:
		return cliff_source_id
	if noise_value >= 0.1 and noise_value < 0.3:
		return dirt_path_source_id
	return grass_source_id


## N'apparaît que sur de l'herbe (jamais sur le chemin, l'eau ou la falaise),
## et jamais dans le rayon de sécurité autour du point d'apparition du joueur.
func _maybe_spawn_obstacle(tile_coord: Vector2i, props: Array[Node]) -> void:
	var world_pos := ground_layer.to_global(ground_layer.map_to_local(tile_coord))
	if world_pos.length() < obstacle_safe_radius:
		return

	var density := _vegetation_noise.get_noise_2d(tile_coord.x, tile_coord.y)
	if density <= vegetation_threshold:
		return

	var obstacle := _create_obstacle(world_pos)
	add_child(obstacle)
	props.append(obstacle)


func _create_obstacle(world_pos: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.global_position = world_pos
	body.collision_layer = OBSTACLE_COLLISION_LAYER
	body.collision_mask = 0

	var sprite := Sprite2D.new()
	sprite.texture = _obstacle_textures[randi() % _obstacle_textures.size()]
	sprite.scale = Vector2.ONE * randf_range(0.35, 0.55)
	body.add_child(sprite)

	var collision_shape := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	collision_shape.shape = shape
	body.add_child(collision_shape)

	return body


## Efface les tuiles peintes et libère les obstacles d'un chunk hors de portée.
func _unload_chunk(chunk_coord: Vector2i) -> void:
	var chunk_data: Dictionary = _generated_chunks[chunk_coord]

	for cell in chunk_data["cells"]:
		ground_layer.erase_cell(cell)

	for prop in chunk_data["props"]:
		if is_instance_valid(prop):
			prop.queue_free()

	_generated_chunks.erase(chunk_coord)

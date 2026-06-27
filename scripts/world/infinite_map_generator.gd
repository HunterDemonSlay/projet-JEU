class_name InfiniteMapGenerator
extends Node2D
## Génère le monde à l'infini, par chunks, avec 4 biomes macro (Forêt dense,
## Canyon de falaises, Marais/Rivière, Vallées rocheuses arides) calculés à
## partir de trois couches de bruit superposées.
##
## Architecture en 4 "couches" (demandée) :
## - GroundLayer (Layer0)  : eau profonde/peu profonde, sable, herbe, chemin.
## - CliffLayer (Layer1)   : falaises (sommet/paroi/ombre), au-dessus du sol.
## - DecorLayer (Layer2)   : petits éléments de sol (fleurs/cailloux), sans
##   collision ni navigation (le TileSet ne déclare aucune physics/nav layer,
##   donc c'est déjà le cas par construction).
## - DynamicEntities/PropsContainer (Layer3) : arbres/rochers en StaticBody2D
##   avec collision réelle, parent Y-sorted (voir World.tscn) pour que le
##   joueur passe naturellement devant/derrière. Les TileMapLayers, eux,
##   restent EN DEHORS du groupe Y-sort (z_index négatif uniquement) pour ne
##   pas risquer de faire passer le sol devant le joueur (cf. note plus bas).
##
## Décision d'architecture (actée avec l'utilisateur, à ne plus rediscuter) :
## pas de système de Terrain Godot 4 (set_cells_terrain_connect). Il exige des
## tuiles de bord/coin configurées visuellement dans l'éditeur TileSet (bits
## de raccordement), un travail qui ne peut pas se faire de façon fiable sans
## vérification visuelle. On peint donc chaque biome directement avec
## set_cell(), mais avec du bruit organique multi-couches + un jitter de
## bordure pour casser l'effet de grille/bandes nettes.

enum Biome { FOREST, CANYON, MARSH, ARID }

@export_group("Chunks")
## Taille d'un chunk, en tuiles.
@export var chunk_size: int = 32
## Rayon de chargement (chunks actifs et visibles) autour du joueur.
@export var chunk_render_distance: int = 3
## Anneau supplémentaire de chunks gardés en mémoire mais masqués (props
## invisibles) avant déchargement complet — évite un pop-in trop brutal.
@export var chunk_hidden_buffer: int = 1
## Nombre de rangées de tuiles traitées avant de céder une frame
## (await get_tree().process_frame), pour éviter les micro-saccades si la
## génération d'un chunk devient coûteuse (beaucoup de décor).
@export var rows_per_frame: int = 8

@export_group("Bruit")
@export var noise_seed: int = 12345
@export var randomize_seed: bool = true

@export_group("Tileset (IDs de TileSetAtlasSource, pas de Terrain Godot)")
@export var grass_source_id: int = 0
@export var dirt_path_source_id: int = 1
@export var water_deep_source_id: int = 2
@export var cliff_wall_source_id: int = 3
@export var sand_source_id: int = 4
@export var water_shallow_source_id: int = 5
@export var cliff_top_source_id: int = 6
@export var cliff_shadow_source_id: int = 7
@export var flower_clutter_source_id: int = 8
@export var pebble_clutter_source_id: int = 9

@export_group("Végétation")
## Densité de base des arbres/rochers (plus haut = plus rare). Modulée par biome.
@export var vegetation_threshold: float = 0.62
@export var obstacle_safe_radius: float = 120.0

const ATLAS_COORDS := Vector2i(0, 0)
const OBSTACLE_COLLISION_LAYER := 1

const TREE_TEXTURE_PATHS := [
	"res://assets/decor/props/big_tree.png",
	"res://assets/decor/props/round_tree.png",
	"res://assets/decor/props/pine_tree.png",
	"res://assets/decor/props/bush_round.png",
]
const CLIFF_BASE_TEXTURE_PATHS := [
	"res://assets/decor/props/rock.png",
	"res://assets/decor/props/rock_pile.png",
]
const MARSH_TEXTURE_PATHS := [
	"res://assets/decor/props/log_pile.png",
	"res://assets/decor/props/mushroom.png",
]

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var cliff_layer: TileMapLayer = $CliffLayer
@onready var decor_layer: TileMapLayer = $DecorLayer
## En dehors de cet arbre (voir World.tscn) : enfant de DynamicEntities, le
## même conteneur Y-sorted que Player, pour un tri de profondeur correct.
@onready var props_container: Node2D = get_node("../DynamicEntities/PropsContainer")

var _biome_noise := FastNoiseLite.new()
var _elevation_noise := FastNoiseLite.new()
var _clutter_noise := FastNoiseLite.new()
var _edge_jitter_noise := FastNoiseLite.new()

var _tree_textures: Array[Texture2D] = []
var _cliff_base_textures: Array[Texture2D] = []
var _marsh_textures: Array[Texture2D] = []

## chunk_coord (Vector2i) -> { ground_cells, cliff_cells, decor_cells, props, hidden, generating }
var _generated_chunks: Dictionary = {}

var _player: Node2D
var _last_player_chunk: Vector2i = Vector2i(999999, 999999)


func _ready() -> void:
	if randomize_seed:
		randomize()
		noise_seed = randi()

	_configure_noise()
	_load_textures()

	_player = get_tree().get_first_node_in_group("player")
	update_chunks()


func _configure_noise() -> void:
	_biome_noise.seed = noise_seed
	_biome_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	_biome_noise.frequency = 0.002

	_elevation_noise.seed = noise_seed + 1
	_elevation_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_elevation_noise.frequency = 0.015

	_clutter_noise.seed = noise_seed + 2
	_clutter_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_clutter_noise.frequency = 0.05

	# Bruit haute fréquence dédié à briser les bandes nettes entre biomes
	# (jitter de seuil), pas à définir un biome ou une densité en soi.
	_edge_jitter_noise.seed = noise_seed + 3
	_edge_jitter_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_edge_jitter_noise.frequency = 0.3


func _load_textures() -> void:
	for path in TREE_TEXTURE_PATHS:
		_tree_textures.append(load(path) as Texture2D)
	for path in CLIFF_BASE_TEXTURE_PATHS:
		_cliff_base_textures.append(load(path) as Texture2D)
	for path in MARSH_TEXTURE_PATHS:
		_marsh_textures.append(load(path) as Texture2D)


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	update_chunks()


## Ne fait du travail que lorsque le joueur a réellement changé de chunk.
func update_chunks() -> void:
	var player_chunk := _world_to_chunk_coord(_player.global_position)
	if player_chunk == _last_player_chunk:
		return
	_last_player_chunk = player_chunk

	var active_radius := chunk_render_distance
	var hidden_radius := chunk_render_distance + chunk_hidden_buffer

	for x in range(player_chunk.x - active_radius, player_chunk.x + active_radius + 1):
		for y in range(player_chunk.y - active_radius, player_chunk.y + active_radius + 1):
			var coord := Vector2i(x, y)
			if not _generated_chunks.has(coord):
				_generate_chunk_async(coord)
			elif _generated_chunks[coord]["hidden"]:
				_set_chunk_hidden(coord, false)

	for coord in _generated_chunks.keys().duplicate():
		var dist := maxi(absi(coord.x - player_chunk.x), absi(coord.y - player_chunk.y))
		if dist > hidden_radius:
			_unload_chunk(coord)
		elif dist > active_radius:
			if not _generated_chunks[coord]["hidden"]:
				_set_chunk_hidden(coord, true)


func _world_to_chunk_coord(world_position: Vector2) -> Vector2i:
	var chunk_world_size := chunk_size * ground_layer.scale.x * 16.0
	return Vector2i(floori(world_position.x / chunk_world_size), floori(world_position.y / chunk_world_size))


## Détermine le biome macro à partir du bruit cellulaire (remappé de [-1,1] à
## [0,1]) : [0,0.25)=Forêt, [0.25,0.5)=Canyon, [0.5,0.75)=Marais, [0.75,1]=Aride.
func _compute_biome(tile_coord: Vector2i) -> Biome:
	var raw := _biome_noise.get_noise_2d(tile_coord.x, tile_coord.y)
	var normalized := clampf((raw + 1.0) * 0.5, 0.0, 1.0)
	if normalized < 0.25:
		return Biome.FOREST
	if normalized < 0.5:
		return Biome.CANYON
	if normalized < 0.75:
		return Biome.MARSH
	return Biome.ARID


## Seuils d'élévation par biome (les marais ont beaucoup plus d'eau, les
## zones arides presque aucune ; les canyons ont des falaises plus basses
## donc plus fréquentes ; la forêt reste la configuration "par défaut").
func _biome_thresholds(biome: Biome) -> Dictionary:
	match biome:
		Biome.MARSH:
			return {"water": -0.05, "cliff": 0.6, "path_low": 0.1, "path_high": 0.2, "has_path": false}
		Biome.ARID:
			return {"water": -0.85, "cliff": 0.4, "path_low": -0.1, "path_high": 0.15, "has_path": true}
		Biome.CANYON:
			return {"water": -0.5, "cliff": 0.25, "path_low": 0.0, "path_high": 0.12, "has_path": true}
		_:
			return {"water": -0.5, "cliff": 0.55, "path_low": 0.05, "path_high": 0.2, "has_path": true}


func _generate_chunk_async(chunk_coord: Vector2i) -> void:
	var record := {
		"ground_cells": [] as Array[Vector2i],
		"cliff_cells": [] as Array[Vector2i],
		"decor_cells": [] as Array[Vector2i],
		"props": [] as Array[Node],
		"hidden": false,
	}
	_generated_chunks[chunk_coord] = record

	var origin := chunk_coord * chunk_size
	for local_y in range(chunk_size):
		for local_x in range(chunk_size):
			_paint_cell(origin + Vector2i(local_x, local_y), record)

		if local_y % rows_per_frame == 0:
			await get_tree().process_frame
			# Le joueur peut s'être éloigné assez vite pour que ce chunk ait
			# déjà été déchargé pendant qu'on attendait la frame suivante.
			if not _generated_chunks.has(chunk_coord):
				return


func _paint_cell(tile_coord: Vector2i, record: Dictionary) -> void:
	var biome := _compute_biome(tile_coord)
	var thresholds := _biome_thresholds(biome)

	var elevation := _elevation_noise.get_noise_2d(tile_coord.x, tile_coord.y)
	elevation += _edge_jitter_noise.get_noise_2d(tile_coord.x, tile_coord.y) * 0.06

	var ground_source := grass_source_id
	var cliff_source := -1

	if elevation < thresholds.water - 0.15:
		ground_source = water_deep_source_id
	elif elevation < thresholds.water:
		ground_source = water_shallow_source_id
	elif elevation < thresholds.water + 0.08:
		ground_source = sand_source_id
	elif elevation >= thresholds.cliff + 0.15:
		cliff_source = cliff_top_source_id
	elif elevation >= thresholds.cliff + 0.04:
		cliff_source = cliff_wall_source_id
	elif elevation >= thresholds.cliff:
		cliff_source = cliff_shadow_source_id
	elif thresholds.has_path and elevation > thresholds.path_low and elevation < thresholds.path_high:
		ground_source = dirt_path_source_id

	ground_layer.set_cell(tile_coord, ground_source, ATLAS_COORDS)
	record["ground_cells"].append(tile_coord)

	if cliff_source != -1:
		cliff_layer.set_cell(tile_coord, cliff_source, ATLAS_COORDS)
		record["cliff_cells"].append(tile_coord)

	_maybe_paint_ground_clutter(tile_coord, ground_source, cliff_source, record)
	_maybe_spawn_obstacle(tile_coord, ground_source, cliff_source, biome, record)


## Petits éléments de sol (Layer2) : fleurs sur l'herbe, cailloux sur le sable.
func _maybe_paint_ground_clutter(tile_coord: Vector2i, ground_source: int, cliff_source: int, record: Dictionary) -> void:
	if cliff_source != -1:
		return
	if ground_source != grass_source_id and ground_source != sand_source_id:
		return

	var density := _clutter_noise.get_noise_2d(tile_coord.x * 2.0, tile_coord.y * 2.0)
	if density < 0.55:
		return

	var source_id := pebble_clutter_source_id if ground_source == sand_source_id else flower_clutter_source_id
	decor_layer.set_cell(tile_coord, source_id, ATLAS_COORDS)
	record["decor_cells"].append(tile_coord)


## Gros obstacles (Layer3) : arbres en forêt, rochers/vignes en base de
## falaise, bois flotté dans les marais. Jamais dans le rayon de sécurité
## autour du point d'apparition du joueur.
func _maybe_spawn_obstacle(tile_coord: Vector2i, ground_source: int, cliff_source: int, biome: Biome, record: Dictionary) -> void:
	var world_pos := ground_layer.to_global(ground_layer.map_to_local(tile_coord))
	if world_pos.length() < obstacle_safe_radius:
		return

	# Base de falaise : rochers/broussailles épars contre la paroi.
	if cliff_source == cliff_shadow_source_id:
		if randf() < 0.12:
			_spawn_prop(world_pos, _cliff_base_textures, record, 0.3, 0.45)
		return
	if cliff_source != -1:
		return

	# Bois flotté épars au bord de l'eau (sable), peu importe le biome.
	if ground_source == sand_source_id:
		if randf() < 0.08:
			_spawn_prop(world_pos, _marsh_textures, record, 0.3, 0.45)
		return

	if ground_source != grass_source_id:
		return

	var density := _clutter_noise.get_noise_2d(tile_coord.x, tile_coord.y)
	var threshold := vegetation_threshold
	match biome:
		Biome.FOREST:
			threshold -= 0.08
		Biome.ARID:
			threshold += 0.3
		Biome.MARSH:
			threshold += 0.15
		Biome.CANYON:
			pass

	if density <= threshold:
		return

	# Au cœur d'un amas dense, on superpose 2 props légèrement décalés pour
	# casser toute impression de grille (demandé : "doivent se chevaucher").
	var cluster_size := 2 if (density > threshold + 0.25 and biome == Biome.FOREST) else 1
	for _i in cluster_size:
		var jitter := Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
		_spawn_prop(world_pos + jitter, _tree_textures, record, 0.4, 0.65)


func _spawn_prop(world_pos: Vector2, texture_pool: Array[Texture2D], record: Dictionary, min_scale: float, max_scale: float) -> void:
	if texture_pool.is_empty():
		return

	var body := StaticBody2D.new()
	body.global_position = world_pos
	body.collision_layer = OBSTACLE_COLLISION_LAYER
	body.collision_mask = 0

	var sprite := Sprite2D.new()
	sprite.texture = texture_pool[randi() % texture_pool.size()]
	sprite.scale = Vector2.ONE * randf_range(min_scale, max_scale)
	body.add_child(sprite)

	var collision_shape := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	collision_shape.shape = shape
	# Décalée vers le bas (le "tronc") : on ne veut pas bloquer le passage
	# sous la cime d'un arbre, seulement contre sa base.
	collision_shape.position = Vector2(0, 6)
	body.add_child(collision_shape)

	props_container.add_child(body)
	record["props"].append(body)


func _set_chunk_hidden(chunk_coord: Vector2i, hidden: bool) -> void:
	var record: Dictionary = _generated_chunks[chunk_coord]
	record["hidden"] = hidden
	for prop in record["props"]:
		if is_instance_valid(prop):
			prop.visible = not hidden


## Efface les tuiles peintes (3 layers) et libère les obstacles d'un chunk
## sorti du rayon de sécurité (render_distance + chunk_hidden_buffer).
func _unload_chunk(chunk_coord: Vector2i) -> void:
	var record: Dictionary = _generated_chunks[chunk_coord]

	for cell in record["ground_cells"]:
		ground_layer.erase_cell(cell)
	for cell in record["cliff_cells"]:
		cliff_layer.erase_cell(cell)
	for cell in record["decor_cells"]:
		decor_layer.erase_cell(cell)

	for prop in record["props"]:
		if is_instance_valid(prop):
			prop.queue_free()

	_generated_chunks.erase(chunk_coord)

extends Node2D
## Génère une variation de terrain (chemin de terre) et disperse des éléments
## de décor (rochers, buissons, arbres...) au démarrage de la partie.
##
## Peint le TileMapLayer par code (set_cell en boucle) plutôt que de figer des
## données de tuiles dans la scène : plus simple à faire fonctionner de façon
## fiable qu'un encodage manuel du format binaire des cellules, et tout aussi
## valide puisque la carte est régénérée à chaque partie (procédural).
## Purement visuel : aucun élément ici n'a de collision, donc rien ne peut
## perturber le mouvement du joueur, les ennemis ou les projectiles.

const GRASS_SOURCE_ID := 0
const DIRT_SOURCE_ID := 1
const ATLAS_COORDS := Vector2i(0, 0)

## Textures des éléments de décor dispersés aléatoirement sur la carte.
const PROP_TEXTURE_PATHS := [
	"res://assets/decor/props/rock.png",
	"res://assets/decor/props/bush.png",
	"res://assets/decor/props/mushroom.png",
	"res://assets/decor/props/pine_tree.png",
	"res://assets/decor/props/round_tree.png",
]

## Rayon (en tuiles) du chemin sinueux peint à travers la zone de jeu.
@export var path_half_length_tiles: int = 50
## Largeur du chemin, en tuiles, de part et d'autre du centre de la sinusoïde.
@export var path_width_tiles: int = 2

## Nombre d'éléments de décor à disperser.
@export var prop_count: int = 40
## Rayon minimum (autour de l'origine, où le joueur apparaît) sans décor.
@export var prop_min_radius: float = 150.0
## Rayon maximum de la zone de dispersion.
@export var prop_max_radius: float = 900.0

@onready var ground_layer: TileMapLayer = $GroundTileMapLayer


func _ready() -> void:
	_paint_dirt_path()
	_scatter_props()


## Trace un chemin de terre sinueux (sinusoïde) à travers la zone de spawn,
## pour casser l'uniformité du fond d'herbe.
func _paint_dirt_path() -> void:
	for x in range(-path_half_length_tiles, path_half_length_tiles + 1):
		var center_y := roundi(sin(x * 0.15) * 8.0)
		for offset in range(-path_width_tiles, path_width_tiles + 1):
			ground_layer.set_cell(Vector2i(x, center_y + offset), DIRT_SOURCE_ID, ATLAS_COORDS)


## Place des props (rochers, buissons, arbres...) à des positions aléatoires,
## en évitant un disque autour de l'origine pour ne pas gêner l'arrivée du joueur.
func _scatter_props() -> void:
	var textures: Array[Texture2D] = []
	for path in PROP_TEXTURE_PATHS:
		textures.append(load(path) as Texture2D)

	for _i in prop_count:
		var angle := randf() * TAU
		var distance := randf_range(prop_min_radius, prop_max_radius)
		var prop_position := Vector2(cos(angle), sin(angle)) * distance

		var prop := Sprite2D.new()
		prop.texture = textures[randi() % textures.size()]
		prop.position = prop_position
		prop.scale = Vector2.ONE * randf_range(0.35, 0.6)
		# Les arbres/buissons doivent se dessiner derrière le joueur et les
		# ennemis (qui restent à z_index 0 par défaut), pour ne pas donner
		# l'impression qu'ils flottent devant les personnages.
		prop.z_index = -1
		add_child(prop)

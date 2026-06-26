class_name UpgradeEffect
extends Resource
## Classe de base d'une amélioration ("Manuel Secret") proposée à la percée.
##
## Pour ajouter une nouvelle amélioration : créer un script héritant de
## UpgradeEffect, renseigner `title`/`description` dans `_init()`, et
## surcharger `apply()`. Aucune autre partie du code n'a besoin d'être
## modifiée — il suffit ensuite d'ajouter une instance dans le pool de
## CultivationManager._upgrade_pool.

## Nom affiché dans le choix de percée.
@export var title: String = ""
## Description courte affichée sous le titre.
@export var description: String = ""


## Applique l'effet de l'amélioration au joueur. À surcharger.
func apply(_player: Player) -> void:
	push_error("UpgradeEffect.apply() doit être surchargée par une classe fille.")

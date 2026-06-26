class_name EnemyStats
extends Resource
## Données de configuration d'un type d'ennemi (HP, vitesse, dégâts).
##
## Une Resource permet de créer plusieurs fichiers .tres (un par archétype :
## "Bête Démoniaque de Rang inférieur", "Rang moyen", "Boss"...) et de les
## assigner à la même scène Enemy.tscn sans dupliquer de code.

## Points de vie maximum de l'ennemi.
@export var max_health: float = 10.0
## Vitesse de déplacement, en pixels/seconde.
@export var speed: float = 80.0
## Dégâts infligés au joueur au contact.
@export var contact_damage: float = 5.0
## Quantité d'essence de Qi libérée à la mort (récompense de cultivation).
@export var qi_reward: float = 1.0

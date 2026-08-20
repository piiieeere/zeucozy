class_name SunRig
extends DirectionalLight3D

## Le SOLEIL REEL — la lampe qui traverse les baies du mur d'arene.
##
## Ouvert le 2026-08-20, et c'est la premiere `Light3D` du projet : l'examen du
## 2026-08-18 avait ferme lumieres et post-process, "Visual Art Direction"
## §6bis le rouvre explicitement pour les fenetres. Tout ce qu'il faut savoir
## avant d'y toucher est la-bas ; ce fichier n'en porte que les reglages.
##
## ⚠️ IL VIT ICI, DANS `systems/`, PAS DANS `main.tscn` — §6bis, consequence
## n°5. `unshaded` etait aussi ce qui rendait le rendu independant de
## l'environnement, et c'est ce qui fait qu'un reglage corrige au banc profite
## au jeu sans recopie. Le jour ou le jeu a une lampe et pas `cel_test.tscn`,
## les deux divergent exactement comme Blender et Godot ont diverge. Le banc et
## le jeu posent donc LE MEME nœud, et il n'en existe qu'une definition.
##
## ⚠️ SA COULEUR ET SON ENERGIE N'ONT AUCUN EFFET SUR L'IMAGE, et c'est voulu.
## `cel_sun.gdshaderinc` n'utilise que `ATTENUATION` — la lampe ne sert qu'a
## dire OU l'ombre tombe. Le ton de l'ombre est dans le shader, en un seul
## endroit, partage par le sol, les tapis, le mur, le chat et les ennemis. Une
## couleur reglee ici serait un second reglage muet, qui donnerait l'illusion
## d'agir. Elle reste ambre parce que §6 interdit toute source froide et qu'une
## valeur fausse dans l'inspecteur finit toujours par etre crue.

## Hauteur du soleil au-dessus de l'horizon.
##
## ⚠️ C'EST CE NOMBRE QUI DECIDE SI LE RAI ENTRE DANS LE CADRE, pas la taille
## des baies. Le mur n'affleure le bord de l'image que quand le chat colle a la
## bordure ; un soleil haut colle le rai au pied du mur, donc hors champ.
## A 26° l'appui (0,95 m) projette a 1,95 m du mur et le linteau (2,25 m) a
## 4,0 m : une bande de 2 m, a portee de regard. La contrepartie est la
## longueur des ombres de personnages — 3,8 m pour un chat de 1,86 — et c'est
## ce qui borne la descente : plus bas, chaque ennemi traine une trainee qui
## couvre ses voisins (§15).
@export var elevation_deg: float = 26.0

## Azimut, en degres. 180 = le soleil voyage vers +Z, donc il entre par le mur
## du FOND, celui que la camera regarde. Le decalage de 25° lui fait traverser
## AUSSI le mur de gauche : sans lui, les baies des deux murs lateraux sont
## rasantes et ne projettent rien.
@export var yaw_deg: float = 205.0

## Portee de la carte d'ombre, en metres.
##
## ⚠️ §6bis, consequence n°4 : l'arene fait 160 x 90 m et la camera n'en voit
## que ~29 x 25 m — mais LE MUR QUI PROJETTE EST HORS DE CE CADRE quand son
## ombre, elle, y entre. Une portee reglee au plus juste sur ce que la camera
## voit fait donc DISPARAITRE l'ombre au moment ou on s'en approche. 80 m
## laisse le mur, ses baies et les meubles de la cellule voisine dans la carte.
@export var shadow_distance: float = 80.0


func _ready() -> void:
	_read_cmdline_overrides()

	light_color = Color("#FFD9A0")
	light_energy = 1.0
	# Une lampe qui n'eclaire pas n'a pas a specularer non plus.
	light_specular = 0.0

	shadow_enabled = true
	directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	directional_shadow_max_distance = shadow_distance
	# ⛔ AUCUNE OMBRE DOUCE (§6bis, consequence n°2). Le filtrage rend
	# l'attenuation CONTINUE, donc un degrade — le 3e ton que la variante A
	# refuse. Le shader la requantifie au `step()`, mais un bord deja etale sur
	# quatre texels ne redevient pas franc : il redevient franc AU MAUVAIS
	# ENDROIT, et il bave d'un pixel a l'autre quand la camera bouge.
	light_angular_distance = 0.0
	shadow_blur = 0.0
	shadow_bias = 0.06
	shadow_normal_bias = 1.0

	rotation_degrees = Vector3(-elevation_deg, yaw_deg, 0.0)


## Le soleil se coupe et se regle en ligne de commande — meme convention que
## `--pitch=`, `--decor-outline=` et `--msaa=`.
##
##     ... -- --sun=off          LE TEST D'ACCEPTATION de §6bis
##     ... -- --sun-elev=18 --sun-yaw=200
##
## ✅ `--sun=off` retire le nœud, il ne baisse pas son energie. C'est ce qui
## rend le test BINAIRE : sans `DirectionalLight3D` dans la scene, `light()`
## n'est jamais appelee et le pixel vaut EXACTEMENT celui d'avant le
## 2026-08-20. Une energie a zero laisserait tourner la fonction, donc laisserait
## une divergence possible — et c'est precisement ce qu'on veut prouver absent.
static func wanted() -> bool:
	return not OS.get_cmdline_user_args().has("--sun=off")


func _read_cmdline_overrides() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sun-elev="):
			elevation_deg = float(argument.trim_prefix("--sun-elev="))
		elif argument.begins_with("--sun-yaw="):
			yaw_deg = float(argument.trim_prefix("--sun-yaw="))
		elif argument.begins_with("--sun-distance="):
			shadow_distance = float(argument.trim_prefix("--sun-distance="))

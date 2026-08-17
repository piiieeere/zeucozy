extends "res://scripts/skills/skill.gd"

## Le socle des competences ACTIVES — celles qu'une touche declenche.
##
## C'est le troisieme type de "Gameplay et Progression" §2.1, et le seul qui
## ajoute une DECISION a la boucle moment-to-moment : le placement et la visee
## sont continus, un actif est ponctuel. Le joueur choisit un INSTANT.
##
## Deux slots, deux clics (§2.4) : clic gauche = slot 1, clic droit = slot 2.
##
## ─── LE COOLDOWN VIT ICI, PAS DANS CHAQUE COMPETENCE ───
##
## Une competence concrete n'ecrit que son `_fire()`. Le decompte, le refus de
## partir a froid et le ratio que lit le HUD sont communs — les laisser a chaque
## actif, c'est six decomptes qui derivent, et surtout six facons pour une
## pastille de mentir sur ce qui est pret.
##
## ⚠️ LE COOLDOWN EST UNE VALEUR DE PALIER, comme tout le reste. Un T2 qui
## raccourcit l'attente est un vrai renfort, et il n'y a rien a soustraire : la
## valeur est absolue (voir `skill_definitions.gd`).
##
## ─── TOUT ACTIF CRIE, ET C'EST LE SOCLE QUI LE SAIT (2026-08-17) ───
##
## Chaque competence active porte une ONOMATOPEE — le bruit du coup, ecrit dans
## l'image en grosses lettres, a la maniere de l'anime TV 80-90. `CHOMP` pour la
## morsure.
##
## Ce n'est pas un ornement : un actif est le seul type de competence qui soit une
## decision d'INSTANT, et l'onomatopee est ce qui rend cet instant lisible. Le
## dessin de la competence dit ce qui se passe ; l'onomatopee dit que ca vient de
## partir, et que c'etait le joueur.
##
## ⚠️ RESERVEE AUX ACTIFS, jamais aux AUTO. Six armes qui crient a leur propre
## cadence rempliraient l'ecran de texte en permanence, et le mot cesserait
## d'annoncer quoi que ce soit. C'est le meme partage que les pastilles du HUD,
## qui n'existent que pour les actifs.
##
## Le socle le fait donc UNE fois, pour toutes les competences actives a venir.

const ShoutFx := preload("res://scripts/systems/shout_fx.gd")
const Locale := preload("res://scripts/systems/locale.gd")

## Le temps qu'il reste a attendre, en secondes. Zero = pret.
var cooldown_left := 0.0


## Le decompte. Un actif n'est avance QUE sur une run vivante, comme tout le
## reste : un cooldown qui tournerait derriere un carton de niveau rendrait la
## competence prete pendant une pause, ce qui ferait du level-up un moyen de
## recharger.
func tick(delta: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left = maxf(0.0, cooldown_left - delta)


func is_ready() -> bool:
	return cooldown_left <= 0.0


## De 0 (vient de partir) a 1 (pleine charge). C'est ce que la pastille du HUD
## dessine — et elle le QUANTIFIE en poses, elle ne le suit pas en continu
## (§2.4 : "jamais une barre lisse").
func charge_ratio() -> float:
	var total := float(values.get("cooldown", 0.0))

	if total <= 0.0:
		return 1.0

	return clampf(1.0 - cooldown_left / total, 0.0, 1.0)


## Declenche, si c'est pret. Rend `true` quand le coup est parti — l'appelant en
## a besoin : une touche pressee a froid ne doit RIEN faire, pas meme relancer
## le decompte.
func trigger() -> bool:
	if not is_ready():
		return false

	cooldown_left = float(values.get("cooldown", 0.0))
	_fire()
	return true


## Le crochet des sous-classes : le coup part. Tout ce qui est commun — le
## decompte, la garde a froid — a deja ete fait.
func _fire() -> void:
	pass


## Le bruit du coup, ecrit dans l'image. A appeler AU MOMENT OU IL SE PRODUIT.
##
## ⚠️ IL N'EST PAS APPELE AUTOMATIQUEMENT PAR `trigger()`, et c'est le seul
## endroit ou ce socle laisse du travail a la sous-classe. La raison est que
## "quand le coup part" et "quand le coup FAIT DU BRUIT" ne sont pas le meme
## instant : la morsure claque quatre crans apres le clic, et un CHOMP sur des
## machoires encore grandes ouvertes est un contresens qu'aucun reglage ne
## rattrape. Le socle ne peut pas deviner ce moment — il appartient au geste.
##
## Une competence dont le coup est instantane appelle simplement `shout()` en
## fin de `_fire()`.
func shout() -> void:
	if player == null:
		return

	var key := "skill.%s.shout" % id

	# Une competence sans onomatopee est un oubli, pas un choix : `Locale.t`
	# leve dessus, comme sur un titre ou une description manquants.
	var fx := ShoutFx.new()
	player.add_child(fx)
	fx.setup(Locale.t(key))
	# Sans ca, l'interpolation physique le fait partir de l'origine du monde sur
	# sa premiere frame — et sa premiere frame est celle ou il est le plus gros.
	fx.reset_physics_interpolation()

extends RefCounted

## ⭐ LA source des textes du jeu — francais et anglais.
##
## Meme role que ui_style.gd pour le style d'interface : tout ce qui s'affiche en
## mots vit ICI, et nulle part ailleurs. Un texte ecrit en dur dans un ecran est
## un texte qui ne sera jamais traduit, et rien dans le code ne le signalera.
##
## ─── Pourquoi PAS le systeme de traduction de Godot ───
##
## `tr()` + un CSV importe est la voie idiomatique, et elle a ete ecartee pour
## deux raisons concretes a ce projet :
##
##   * un CSV doit etre REIMPORTE a chaque edition (`--headless --import`), ce qui
##     ajoute une etape a chaque retouche de texte — contre "iterations rapides
##     et testables" ;
##   * `tr()` sur une cle absente rend LA CLE, en silence. On verrait
##     "card.level_sub" a l'ecran sans qu'aucune erreur ne soit levee. Ici, une
##     cle absente leve, et une traduction manquante retombe sur le francais en
##     le disant (voir `t`).
##
## Toute l'UI est deja construite en code (hud.gd), donc le rattrapage automatique
## des Control par `tr()` n'aurait rien apporte non plus.
##
## ─── La forme du dictionnaire ───
##
## UNE entree par cle, les deux langues COTE A COTE. C'est le point : deux
## dictionnaires separes (un par langue) laissent une cle non traduite passer
## inapercue, alors qu'ici le trou se voit en lisant le fichier.
##
## ⚠️ Les cles portent des PHRASES ENTIERES, jamais des morceaux a recoller.
## "PORTEE %.1f m" est une cle ; "PORTEE" + "%.1f" + "m" en serait trois, et
## l'ordre des mots n'est pas le meme d'une langue a l'autre. La regle vaut meme
## quand les deux langues s'accordent par hasard.

const DEFAULT := "fr"

## Les langues offertes, dans l'ordre ou le menu les propose.
const LANGUAGES: Array[String] = ["fr", "en"]

## Le nom d'une langue EST ECRIT DANS CETTE LANGUE. Un joueur perdu dans une
## langue qu'il ne lit pas cherche "English", pas "Anglais" — c'est la seule
## chaine du jeu qui ne doit surtout pas etre traduite.
const NATIVE_NAMES := {
	"fr": "FRANÇAIS",
	"en": "ENGLISH",
}

const STRINGS := {
	# ── HUD permanent ────────────────────────────────────────────────────────
	"hud.level": {"fr": "NIVEAU %d", "en": "LEVEL %d"},
	"hud.enemies": {"fr": "ENNEMIS %d", "en": "ENEMIES %d"},
	"hud.objective_survive": {"fr": "Survis", "en": "Survive"},
	"hud.objective_brutes": {"fr": "Brutes en approche", "en": "Brutes incoming"},

	# ── Releve de build, en bas d'ecran ──────────────────────────────────────
	#
	# Les separateurs en point median plutot qu'en double espace : a 12 px et en
	# creme assourdi, deux espaces ne separent plus rien.
	"stats.line": {
		"fr": "GRIFFURE %d · CADENCE %.2f s · PORTÉE %.1f m · VITESSE %.1f m/s · AIMANT %.1f m",
		"en": "CLAW %d · RATE %.2f s · RANGE %.1f m · SPEED %.1f m/s · MAGNET %.1f m",
	},
	"stats.breath": {"fr": " · HALEINE %.1f/s SUR %.1f m", "en": " · BREATH %.1f/s OVER %.1f m"},
	"stats.hairball": {
		"fr": " · BOULE %d À %.0f m · %.0f m/s",
		"en": " · HAIRBALL %d AT %.0f m · %.0f m/s",
	},
	"stats.bite": {"fr": " · MORSURE %d / %.1f s", "en": " · BITE %d / %.1f s"},

	# ── Cartons de moment ────────────────────────────────────────────────────
	"card.level_sub": {"fr": "Choisis une amélioration.", "en": "Choose an upgrade."},
	# Le marqueur de palier, en legende minuscule au-dessus du titre d'une carte.
	#
	# ⚠️ Il n'est pas decoratif. Sans lui, reprendre une competence affiche la
	# MEME carte qu'a sa premiere prise, et le joueur ne peut pas savoir s'il
	# debloque ou s'il renforce — "une competence qui n'ameliore rien de visible
	# est un mensonge a l'ecran" (§2.10) vaut aussi pour ce qu'on ne montre pas.
	"card.tier_new": {"fr": "NOUVEAU", "en": "NEW"},
	"card.tier": {"fr": "PALIER %d", "en": "TIER %d"},
	"card.tier_ultimate": {"fr": "ULTIME", "en": "ULTIMATE"},

	# Le type de competence, sur le bandeau en tete de carte — §9.9.
	#
	# ⚠️ CE SONT DES MOTS DE JEU, pas du jargon d'implementation. L'enum s'appelle
	# `Kind.AUTO / ACTIVE / PASSIVE` ; le joueur, lui, lit ce qu'il doit FAIRE.
	# "ACTIF" est ce qui demande une touche, "AUTO" ce qui se debrouille seul,
	# "PASSIF" ce qui ne se voit jamais. C'est la meme raison qui a fait ecrire
	# "NOUVEAU" plutot que "PALIER 1" juste au-dessus.
	"skill.kind.auto": {"fr": "AUTO", "en": "AUTO"},
	"skill.kind.active": {"fr": "ACTIF", "en": "ACTIVE"},
	"skill.kind.passive": {"fr": "PASSIF", "en": "PASSIVE"},
	"card.game_over_summary": {
		"fr": "Survie %d:%02d  ·  Niveau %d",
		"en": "Survived %d:%02d  ·  Level %d",
	},
	"card.restart": {"fr": "RELANCER", "en": "RESTART"},

	# ── Parametres ───────────────────────────────────────────────────────────
	"settings.title": {"fr": "RÉGLAGES", "en": "SETTINGS"},
	"settings.hint": {"fr": "Échap pour revenir au jeu.", "en": "Esc to go back to the game."},
	"settings.language": {"fr": "LANGUE", "en": "LANGUAGE"},
	"settings.close": {"fr": "REPRENDRE", "en": "RESUME"},

	# ── Competences ──────────────────────────────────────────────────────────
	#
	# Les cles se deduisent de l'`id` de la competence (voir `skill_title` et
	# `skill_description`) : le catalogue n'a donc aucun texte a porter, et une
	# competence ajoutee sans ses lignes ici leve a l'ouverture du carton plutot
	# que de sortir muette.
	#
	# ⚠️ LE TITRE EST UNIQUE, LA DESCRIPTION EST PAR PALIER. Un palier qui
	# renommerait la competence casserait la lecture — le joueur suit une carte
	# de run par son nom. Ce qui change d'un palier a l'autre, c'est ce qu'elle
	# FAIT, donc la description.
	#
	# Une competence dont tous les paliers disent la meme chose n'ecrit qu'un
	# `.desc` : `skill_description` y retombe. Ce n'est pas une economie de
	# frappe, c'est une facon de ne PAS ecrire trois fois la meme phrase et de
	# devoir ensuite les tenir synchronisees.
	#
	# ⛔ `damage`, `attack_speed` et `claw_range` ont ete SUPPRIMES le 2026-08-17
	# (voir `skill_definitions.gd`) : la griffure ayant ses propres paliers, les
	# garder ferait compter deux fois la meme montee.

	"skill.claw.title": {"fr": "Griffure", "en": "Claw swipe"},
	"skill.claw.t1.desc": {
		"fr": "Un coup de patte dans la direction visée.",
		"en": "A paw swipe in the direction you aim.",
	},
	"skill.claw.t2.desc": {
		"fr": "Griffe plus fort, plus vite et plus loin.",
		"en": "Claws harder, faster and further.",
	},
	"skill.claw.t3.desc": {
		"fr": "Griffe encore plus fort, plus vite et plus loin.",
		"en": "Claws harder, faster and further still.",
	},

	"skill.hairball.title": {"fr": "Boule de poils", "en": "Hairball"},
	"skill.hairball.t1.desc": {
		"fr": "Crache une boule sur l'ennemi le plus proche, de très loin.",
		"en": "Spits a ball at the nearest enemy, from far away.",
	},
	"skill.hairball.t2.desc": {
		"fr": "Crache plus souvent, plus vite et plus loin.",
		"en": "Spits more often, faster and further.",
	},
	"skill.hairball.t3.desc": {
		"fr": "Crache encore plus souvent, plus vite et plus loin.",
		"en": "Spits more often, faster and further still.",
	},

	# ── Onomatopees ──────────────────────────────────────────────────────────
	#
	# Le bruit d'une competence ACTIVE, ecrit dans l'image en grosses lettres a la
	# maniere de l'anime TV 80-90. Une par actif, sous la cle `skill.<id>.shout` —
	# `active_skill.shout()` la deduit de l'id, il n'y a rien a tenir a jour.
	#
	# ⚠️ Elles sont DANS `locale.gd` comme tout le reste, et pas en dur dans la
	# competence, meme si "CHOMP" s'ecrit pareil dans les deux langues. Une
	# onomatopee est un SON transcrit, et sa transcription change d'une langue a
	# l'autre — le chat francais fait "miaou", l'anglais "meow". Le jour ou l'une
	# d'elles divergera, la place existe deja ; l'ecrire en dur aujourd'hui, c'est
	# garantir qu'on ne la retrouvera pas.
	#
	# ⚠️ EN CAPITALES, toujours. C'est la seule chose que le mot partage avec
	# l'ATH (§9) : une onomatopee en bas de casse se lit comme une legende.
	"skill.bite.shout": {"fr": "CHOMP", "en": "CHOMP"},
	# Le feulement, lui, DIVERGE — et c'est le cas qui justifie la clé. Un chat
	# qui feule s'écrit "FFFCHH" en français et "HSSSS" en anglais.
	"skill.hiss.shout": {"fr": "FFFCHH", "en": "HSSSS"},

	"skill.bite.title": {"fr": "Morsure", "en": "Bite"},
	"skill.bite.t1.desc": {
		"fr": "Clic gauche : croque ce qui passe devant. Fort, mais de près.",
		"en": "Left click: chomps whatever comes in front. Strong, but up close.",
	},
	"skill.bite.t2.desc": {
		"fr": "Mord plus fort, un peu plus loin, et récupère plus vite.",
		"en": "Bites harder, a little further, and recovers faster.",
	},
	"skill.bite.t3.desc": {
		"fr": "Mord encore plus fort et récupère encore plus vite.",
		"en": "Bites harder still and recovers faster still.",
	},

	"skill.breath.title": {"fr": "Haleine puante", "en": "Stinky breath"},
	"skill.breath.t1.desc": {
		"fr": "Un halo de souffle blesse ce qui s'approche.",
		"en": "A halo of breath hurts whatever comes close.",
	},
	"skill.breath.t2.desc": {
		"fr": "Le souffle porte plus loin et mord plus fort.",
		"en": "The breath reaches further and bites harder.",
	},
	"skill.breath.t3.desc": {
		"fr": "Le souffle porte encore plus loin et mord encore plus fort.",
		"en": "The breath reaches further still and bites harder still.",
	},

	"skill.hiss.title": {"fr": "Feulement", "en": "Hiss"},
	"skill.hiss.t1.desc": {
		"fr": "Clic droit : une onde repousse tout autour. Ça ne tue pas, ça dégage.",
		"en": "Right click: a wave shoves everything back. It doesn't kill, it clears.",
	},
	"skill.hiss.t2.desc": {
		"fr": "L'onde porte plus loin, pique un peu plus et revient plus vite.",
		"en": "The wave reaches further, stings a little more and returns sooner.",
	},
	"skill.hiss.t3.desc": {
		"fr": "L'onde balaie tout le tour et revient bien plus vite.",
		"en": "The wave sweeps all around and returns much sooner.",
	},

	"skill.dust.title": {"fr": "Moutons de poussière", "en": "Dust bunnies"},
	"skill.dust.t1.desc": {
		"fr": "Sème des touffes derrière toi. Le premier qui marche dessus le sent passer.",
		"en": "Drops tufts behind you. Whoever steps on one feels it.",
	},
	"skill.dust.t2.desc": {
		"fr": "Des touffes plus grosses, plus souvent, et qui piquent davantage.",
		"en": "Bigger tufts, more often, and they sting harder.",
	},
	"skill.dust.t3.desc": {
		"fr": "Une vraie traînée de moutons, et chacun fait deux fois plus mal.",
		"en": "A proper trail of bunnies, each hurting twice as much.",
	},

	"skill.move_speed.title": {"fr": "Pas nerveux", "en": "Nervous step"},
	"skill.move_speed.desc": {"fr": "Court plus vite.", "en": "Runs faster."},

	"skill.max_health.title": {"fr": "Réserve de vie", "en": "Life reserve"},
	"skill.max_health.desc": {
		"fr": "+30 vie max, et soigne de 30.",
		"en": "+30 max health, and heals 30.",
	},

	"skill.pickup_radius.title": {"fr": "Aimant artisanal", "en": "Homemade magnet"},
	"skill.pickup_radius.desc": {
		"fr": "Ramasse les croquettes de plus loin.",
		"en": "Picks up kibble from further away.",
	},

	"skill.xp_gain.title": {"fr": "Gourmandise", "en": "Greedy guts"},
	"skill.xp_gain.desc": {
		"fr": "Chaque croquette compte davantage.",
		"en": "Every kibble counts for more.",
	},

	# Le nom dit le GESTE, pas le chiffre. « Crachat sec » se comprend sans avoir
	# lu la fiche : un crachat sec part plus vite qu'un crachat mou. En anglais,
	# *dry hack* est le terme courant pour la toux du chat qui rend une boule de
	# poils — c'est la traduction juste, pas la traduction litterale.
	"skill.projectile_speed.title": {"fr": "Crachat sec", "en": "Dry hack"},
	"skill.projectile_speed.desc": {
		"fr": "Les boules de poils partent bien plus vite.",
		"en": "Hairballs fly much faster.",
	},

	"skill.toughness.title": {"fr": "Pelage épais", "en": "Thick coat"},
	"skill.toughness.desc": {
		"fr": "Encaisse une partie des coups.",
		"en": "Soaks up part of every hit.",
	},
}

static var _language := DEFAULT


static func language() -> String:
	return _language


static func set_language(code: String) -> void:
	if code in LANGUAGES:
		_language = code


## La langue suivante dans la liste. C'est ce que fait le menu : avec deux
## langues c'est une bascule, avec trois ce sera un cycle, et l'appelant n'a rien
## a savoir de leur nombre.
static func next_language() -> String:
	var index := LANGUAGES.find(_language)
	return LANGUAGES[(index + 1) % LANGUAGES.size()]


## Le nom d'une langue, ecrit dans cette langue.
static func native_name(code: String) -> String:
	return NATIVE_NAMES.get(code, code.to_upper())


## Le texte d'une cle, dans la langue courante.
##
## ⚠️ Une cle INCONNUE leve — c'est une faute de code, pas une donnee manquante,
## et la laisser passer afficherait la cle a l'ecran comme le fait `tr()`.
## Une TRADUCTION manquante, elle, retombe sur le francais : le jeu reste jouable
## et le trou se voit a l'ecran, ce qui est exactement ou on veut le voir.
static func t(key: String) -> String:
	assert(STRINGS.has(key), "Cle de texte inconnue : " + key)
	var entry: Dictionary = STRINGS[key]
	return entry.get(_language, entry[DEFAULT])


static func skill_title(id: String) -> String:
	return t("skill.%s.title" % id)


## La description d'un PALIER. Retombe sur la description commune de la
## competence quand ce palier n'en a pas de propre — le cas des passifs, dont les
## trois paliers font la meme chose en plus grand.
##
## ⚠️ Le repli est sur une cle du MEME fichier, jamais sur une chaine vide ni sur
## l'id : une competence dont aucune description n'existe leve, comme partout
## ailleurs ici. C'est le contraire de `tr()`, qui aurait affiche
## "skill.claw.t2.desc" a l'ecran sans que rien ne s'en plaigne.
static func skill_description(id: String, tier: int) -> String:
	var tier_key := "skill.%s.t%d.desc" % [id, maxi(tier, 1)]
	return t(tier_key) if STRINGS.has(tier_key) else t("skill.%s.desc" % id)

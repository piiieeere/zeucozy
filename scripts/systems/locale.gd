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

	# ── Cartons de moment ────────────────────────────────────────────────────
	"card.level_sub": {"fr": "Choisis une amélioration.", "en": "Choose an upgrade."},
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

	# ── Upgrades ─────────────────────────────────────────────────────────────
	#
	# Les cles se deduisent de l'`id` de l'upgrade (voir `upgrade_title`) : le
	# pool n'a donc aucun texte a porter, et une upgrade ajoutee sans ses deux
	# lignes ici leve a l'ouverture du carton plutot que de sortir muette.
	"upgrade.damage.title": {"fr": "Griffes aiguisées", "en": "Sharp claws"},
	"upgrade.damage.desc": {"fr": "+1 dégât par griffure.", "en": "+1 damage per swipe."},

	"upgrade.attack_speed.title": {"fr": "Patte vive", "en": "Quick paw"},
	"upgrade.attack_speed.desc": {"fr": "Griffe plus souvent.", "en": "Claws more often."},

	"upgrade.move_speed.title": {"fr": "Pas nerveux", "en": "Nervous step"},
	"upgrade.move_speed.desc": {"fr": "Court plus vite.", "en": "Runs faster."},

	"upgrade.max_health.title": {"fr": "Réserve de vie", "en": "Life reserve"},
	"upgrade.max_health.desc": {
		"fr": "+30 vie max, et soigne de 30.",
		"en": "+30 max health, and heals 30.",
	},

	"upgrade.pickup_radius.title": {"fr": "Aimant artisanal", "en": "Homemade magnet"},
	"upgrade.pickup_radius.desc": {
		"fr": "Ramasse les croquettes de plus loin.",
		"en": "Picks up kibble from further away.",
	},

	"upgrade.claw_range.title": {"fr": "Grande allonge", "en": "Long reach"},
	"upgrade.claw_range.desc": {
		"fr": "La griffure porte plus loin et balaie plus large.",
		"en": "The swipe reaches further and sweeps wider.",
	},

	"upgrade.breath.title": {"fr": "Haleine puante", "en": "Stinky breath"},
	"upgrade.breath.desc": {
		"fr": "Un halo de souffle blesse ce qui s'approche. Se cumule.",
		"en": "A halo of breath hurts whatever comes close. Stacks.",
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


static func upgrade_title(id: String) -> String:
	return t("upgrade.%s.title" % id)


static func upgrade_description(id: String) -> String:
	return t("upgrade.%s.desc" % id)

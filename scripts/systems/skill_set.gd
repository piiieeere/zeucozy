extends Node3D

## ⭐ CE QUE LE CHAT PORTE — l'etat de build d'une run.
##
## Un dictionnaire `id -> palier`, et les nodes des competences jouees. C'est
## tout l'etat : de quoi redessiner le HUD, refaire un tirage ou reconstruire les
## armes sans rejouer l'historique des prises.
##
## ⚠️ L'ETAT EST UN PALIER, PAS UNE SOMME D'INCREMENTS. C'est la difference avec
## l'ancien `apply_upgrade`, qui faisait `claw_damage += 1` et perdait aussitot
## le compte : les valeurs de palier etant absolues (voir `skill_definitions.gd`),
## `{"claw": 2}` dit TOUT de la griffure du chat. Reappliquer un palier deux fois
## ne change rien, et retirer une competence ne laisse aucune trace a nettoyer —
## ce sont les deux prerequis du remplacement de slot (§2.3) et de l'ultime qui
## transforme (§2.2).
##
## ⚠️ C'est aussi lui qui tient L'HORLOGE de toutes les competences. Elles n'ont
## pas de `_process` : `player._process` appelle `tick`, et `player._process`
## rend deja la main quand la run est en pause. Une competence ne peut donc pas
## oublier de s'arreter derriere un carton de niveau — voir `skills/skill.gd`.

const SkillDefinitions := preload("res://scripts/systems/skill_definitions.gd")

## id -> palier atteint (1-base). Une competence absente de ce dictionnaire n'est
## pas prise.
var _tiers := {}

## id -> node de competence. Uniquement les AUTO et les ACTIFS : un passif ne se
## joue pas, il ne fait que poser des chiffres sur le chat.
var _nodes := {}

var _player = null


func setup(new_player) -> void:
	_player = new_player


func tick(delta: float) -> void:
	for node in _nodes.values():
		node.tick(delta)


## Les competences ACTIVES, DANS L'ORDRE OU ELLES ONT ETE PRISES.
##
## ⚠️ L'ordre vient de `_tiers`, et il n'est pas un hasard d'implementation : un
## Dictionary GDScript conserve son ordre d'insertion. La premiere competence
## active prise occupe donc la slot 1 (clic gauche) et y reste — une slot qui se
## reordonnerait toute seule ferait changer de touche une competence en pleine
## run, ce qu'aucun joueur ne peut suivre.
func active_slots() -> Array:
	var slots: Array = []

	for id in _tiers:
		if SkillDefinitions.kind_of(id) == SkillDefinitions.Kind.ACTIVE and _nodes.has(id):
			slots.append(_nodes[id])

	return slots


## Le joueur a presse la touche d'une slot. Une slot vide ou une competence a
## froid ne font RIEN — pas de son, pas de decompte relance, rien.
func trigger_slot(index: int) -> void:
	var slots := active_slots()

	if index < slots.size():
		slots[index].trigger()


## Ce que le HUD dessine : une charge par slot active, de 0 a 1. Vide tant que le
## chat n'a aucune competence active — auquel cas aucune pastille ne s'affiche,
## parce qu'une pastille eteinte annoncerait une touche qui ne fait rien.
func charge_report() -> Array[float]:
	var charges: Array[float] = []

	for skill in active_slots():
		charges.append(skill.charge_ratio())

	return charges


func has(id: String) -> bool:
	return _tiers.has(id)


func tier_of(id: String) -> int:
	return _tiers.get(id, 0)


## Les valeurs du palier courant, ou un dictionnaire vide si la competence n'est
## pas prise. C'est par la que le HUD lit la griffure pour son releve de build :
## la source est le catalogue, jamais une variable recopiee sur le chat.
func values_of(id: String) -> Dictionary:
	if not has(id):
		return {}

	return SkillDefinitions.tier_values(id, _tiers[id])


## Prend une competence, ou monte son palier d'un cran. Rend les valeurs du
## nouveau palier — l'appelant en a besoin pour les EVENEMENTS que le palier
## porte (le soin de "Reserve de vie"), qui se jouent une fois et ne sont pas un
## etat.
func take(id: String) -> Dictionary:
	var next := mini(tier_of(id) + 1, SkillDefinitions.max_tier(id))
	_tiers[id] = next

	var values := SkillDefinitions.tier_values(id, next)
	var definition := SkillDefinitions.find(id)

	if definition["kind"] != SkillDefinitions.Kind.PASSIVE:
		_ensure_node(definition).set_tier(next, values)

	return values


## Les valeurs permanentes de tous les passifs pris, fusionnees.
##
## ⚠️ `heal` en est EXCLU, et c'est la seule cle traitee a part : c'est un
## evenement de prise, pas un etat du chat. Fusionne ici, il resoignerait le chat
## a chaque recalcul.
func passive_values() -> Dictionary:
	var merged := {}

	for id in _tiers:
		var definition := SkillDefinitions.find(id)

		if definition["kind"] != SkillDefinitions.Kind.PASSIVE:
			continue

		var values := values_of(id)

		for key in values:
			if key != "heal":
				merged[key] = values[key]

	return merged


## Le tirage du level-up — 3 cartes, sans doublon, pondere par type (§2.6).
##
## Trois filtres, et chacun repond a un defaut connu :
##
##   • une competence a son palier maximum SORT du pool. C'est le defaut exact
##     des 7 upgrades d'avant : en fin de run, le tirage ne proposait plus que du
##     deja-vu ;
##   • une competence NEUVE ne sort pas si sa famille de slots est pleine
##     (§2.3). Le carton "quoi remplacer ?" n'existe pas encore — proposer une
##     7e arme serait proposer quelque chose que le jeu ne sait pas faire ;
##   • le poids penche du cote des armes, sans rien garantir.
func roll(count: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []

	for definition in SkillDefinitions.DEFINITIONS:
		var id: String = definition["id"]
		var next := tier_of(id) + 1

		if next > SkillDefinitions.max_tier(id):
			continue

		if next == 1 and _is_slot_family_full(definition["kind"]):
			continue

		pool.append({
			"id": id,
			"tier": next,
			"weight": SkillDefinitions.WEIGHTS[definition["kind"]],
		})

	var choices: Array[Dictionary] = []

	while choices.size() < count and not pool.is_empty():
		var index := _weighted_index(pool)
		choices.append({"id": pool[index]["id"], "tier": pool[index]["tier"]})
		# Retire du pool, pas seulement du tirage : "sans doublon DANS le tirage"
		# (§1.2) veut dire qu'une meme carte ne peut pas occuper deux des trois
		# emplacements.
		pool.remove_at(index)

	return choices


## Combien de slots d'un type sont occupees. Un palier ne compte pas double : ce
## sont les competences DISTINCTES qui occupent des slots.
func used_slots(kind: int) -> int:
	var used := 0

	for id in _tiers:
		if SkillDefinitions.kind_of(id) == kind:
			used += 1

	return used


func _is_slot_family_full(kind: int) -> bool:
	return used_slots(kind) >= SkillDefinitions.slot_limit(kind)


func _weighted_index(pool: Array[Dictionary]) -> int:
	var total := 0

	for entry in pool:
		total += int(entry["weight"])

	var pick := randf() * float(total)
	var running := 0.0

	for index in range(pool.size()):
		running += float(pool[index]["weight"])

		if pick < running:
			return index

	return pool.size() - 1


func _ensure_node(definition: Dictionary):
	var id: String = definition["id"]

	if _nodes.has(id) and is_instance_valid(_nodes[id]):
		return _nodes[id]

	var script: Script = load(definition["script"])
	var node = script.new()
	# Le nom du node EST l'id : c'est ce qui rend un build lisible dans le
	# debugueur de scene sans avoir a deplier quoi que ce soit.
	node.name = id
	add_child(node)
	node.setup(_player, id)
	_nodes[id] = node
	return node

# Plans de véhicules enregistrés par le joueur (DEC-071) : une grille complète, réutilisable dans toute partie.
# Stockés hors de la sauvegarde de partie (user://plans_grille.json) : un plan survit à une nouvelle partie.
class_name PlansGrille

const FICHIER := "user://plans_grille.json"
const MAX_PLANS := 40


static func lire() -> Array:   # [{nom, a}] du plus récent au plus ancien
	if not FileAccess.file_exists(FICHIER):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
	if typeof(d) != TYPE_ARRAY:
		return []
	var res := []
	for p in d:
		if typeof(p) == TYPE_DICTIONARY and ConstructionLibre.est_libre(p.get("a", {})):
			res.append({"nom": String(p.nom), "a": normaliser(p.a)})
	return res


static func _ecrire(liste: Array) -> void:
	var f := FileAccess.open(FICHIER, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(liste))


# Enregistre (ou remplace, même nom) le plan d'une grille. Un châssis d'origine devient de l'acier : le plan ne dépend d'aucune épave.
static func enregistrer(a: Dictionary) -> String:
	var b := a.duplicate(true)
	b.erase("origine")
	for c in b.get("cases", []):
		if c.size() > 2 and String(c[2]) == "origine":
			c[2] = "acier"
	var nom := String(b.get("nom", "Plan"))
	var liste := lire().filter(func(p): return p.nom != nom)
	liste.push_front({"nom": nom, "a": b})
	_ecrire(liste.slice(0, MAX_PLANS))
	return nom


static func supprimer(nom: String) -> void:
	_ecrire(lire().filter(func(p): return p.nom != nom))


# Adapte un plan à ce qui est disponible : palette = [{id, n}] (n = -1 sans limite). Les pièces absentes sont retirées.
static func adapter(plan: Dictionary, palette: Array) -> Dictionary:
	var dispo := {}
	for it in palette:
		dispo[it.id] = int(it.n)
	var b := plan.duplicate(true)
	var garde := []
	var manquantes := []
	for p in b.get("pieces", []):
		var id := String(p.piece)
		var n: int = dispo.get(id, 0)
		if n < 0 or n > 0:
			garde.append(p)
			if n > 0:
				dispo[id] = n - 1
		else:
			manquantes.append(Assemblage.piece(id).get("nom", id))
	b.pieces = garde
	return {"a": ConstructionLibre.nettoyer(b), "manquantes": manquantes}


# Le JSON lit les nombres en flottants : on remet des entiers là où la grille en attend
static func normaliser(b: Dictionary) -> Dictionary:
	for c in b.get("cases", []):
		c[0] = int(c[0])
		c[1] = int(c[1])
	for e in b.get("essieux", []):
		e.x = int(e.x)
	for p in b.get("pieces", []):
		p.pos = [int(p.pos[0]), int(p.pos[1])]
	for t in b.get("toles", []):   # tôles tracées (DEC-080)
		for k in 4:
			t[k] = int(t[k])
	return b

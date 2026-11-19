# Trois voies de profondeur (DEC-250) : voie par défaut, croisement d'un allié, dépassement, poursuivant sur le flanc
# et abordage, coup de flanc, couvert, voie occupée.
# godot --headless --path game -s res://tests/test_voies.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func marche(m: CombatModele, s: float) -> void:
	for i in int(s / CombatModele.DT):
		m.avancer()


func jeu(graine := 5) -> CombatModele:
	Textes.langue = "fr"
	var m := CombatModele.new(graine, {"bac_a_sable": true})
	m._prochain_x = INF   # pas de rencontre au hasard
	var a := ConstructionLibre.voiture("moyen")
	a.nom = "Essai"
	m.construire_grille(0, a)
	m.ordre_marche("avancer")
	return m


func _init() -> void:
	# 1) Par défaut, tout le convoi roule au milieu
	var m := jeu()
	marche(m, 5.0)
	ok(m.convoi.all(func(v): return not v.actif() or absf(v.voie_f) < 0.01), "par défaut : tout le convoi roule sur la voie du milieu")

	# 2) Croiser un convoi allié : on serre à droite (devant), lui reste au fond, aucun choc
	m = jeu()
	m.kit_apparaitre("face", {"types": ["citroen_t23"], "eperonne": false})
	var al = m.ennemis.back()
	al.allie = true
	var max_droite := 0.0
	for i in int(25.0 / CombatModele.DT):
		m.avancer()
		max_droite = maxf(max_droite, m._tete().voie_f)
	ok(max_droite > 0.9, "croisement d'un allié : notre tête serre à droite (voie de devant)")
	ok(absf(al.voie_f + 1.0) < 0.01, "croisement d'un allié : il passe sur la voie du fond")
	ok(not m.journal.any(func(l): return "Choc frontal" in String(l.txt)), "croisement d'un allié : aucun choc")

	# 3) Doubler un convoi plus lent (ordre « éviter ») : on passe par la gauche (fond) puis on revient au milieu
	m = jeu()
	m.kit_apparaitre("convoi_devant", {"types": ["citroen_t23"], "vitesse": 1.0})
	var lent = m.ennemis.back()
	var min_gauche := 0.0
	for i in int(80.0 / CombatModele.DT):
		m.avancer()
		min_gauche = minf(min_gauche, m._tete().voie_f)
	ok(min_gauche < -0.9, "dépassement : la tête passe par la voie du fond")
	ok(m._queue().x > lent.x + lent.longueur, "dépassement : tout le convoi est passé devant")
	ok(absf(m._tete().voie_f) < 0.01, "dépassement : la tête est revenue au milieu")

	# 4) Poursuivant : il monte sur un côté de sa cible et lance un abordage depuis la voie d'à côté
	m = jeu()
	var xq: float = m._queue().x
	for v in m.convoi:
		m.ordre_tir(v.uid, false)
	var e := m.creer_vehicule("citroen_traction", "ennemi", xq - 60.0)
	m.preparer_poursuivant(e, {"abordeurs": 1, "types": ["lame"]})
	m._intention[e.uid] = false
	e.armes = []
	m.ennemis.append(e)
	var saut := false
	var flanc := false
	for i in int(40.0 / CombatModele.DT):
		m.avancer()
		flanc = flanc or absf(absf(e.voie_f) - 1.0) < 0.01
		saut = saut or not m.abordeurs.is_empty()
	ok(flanc, "poursuivant : il roule sur une voie de côté")
	ok(saut, "poursuivant : un pillard saute à bord depuis la voie d'à côté")

	# 5) Coup de flanc : ordre « éperonner », un ennemi roule à hauteur sur la voie d'à côté
	m = jeu()
	m.ordre_conduite("eperonner")
	var t = m._tete()
	var cote := m.creer_vehicule("citroen_traction", "ennemi", t.x)
	cote.mode = "poursuite"
	cote.armes = []
	m.ennemis.append(cote)
	m._cote[cote.uid] = 1
	cote.voie_f = 1.0
	m._place[cote.uid] = true
	var pv0: float = cote.pieces.roulement.pv
	marche(m, 15.0)
	ok(m.journal.any(func(l): return "par le flanc" in String(l.txt) or "fossé" in String(l.txt)), "coup de flanc : on frappe l'ennemi qui roule à côté")
	ok(cote.pieces.roulement.pv < pv0 or cote.statut == "epave", "coup de flanc : ses roues encaissent")

	# 6) Couvert : cible au fond derrière un gros véhicule du milieu, tireur devant
	m = jeu()
	var gros = m._tete()
	var tireur := m.creer_vehicule("willys_mb", "ennemi", gros.x)
	var cible := m.creer_vehicule("willys_mb", "ennemi", gros.x + 1.0)
	tireur.voie_f = 1.0
	cible.voie_f = -1.0
	m.ennemis.append(tireur)
	m.ennemis.append(cible)
	ok(m._facteur_couvert(tireur, cible) < 1.0, "couvert : la cible du fond est cachée par le véhicule du milieu")
	cible.voie_f = 0.0
	ok(m._facteur_couvert(tireur, cible) == 1.0, "couvert : sur la voie voisine, rien ne la cache")

	# 7) Voie occupée : on ne se rabat pas sur un véhicule qui roule à hauteur
	m = jeu()
	var v0 = m._tete()
	var bloque := m.creer_vehicule("citroen_t23", "ennemi", v0.x)
	bloque.voie_f = 1.0
	m.ennemis.append(bloque)
	ok(m._voie_occupee(v0, 1), "voie occupée : le véhicule à hauteur bouche la voie de devant")
	ok(not m._voie_occupee(v0, -1), "voie libre : rien sur la voie du fond")

	# 8) Ancrages : un véhicule au fond est plus haut et plus petit à l'écran
	var y_fond := CombatModele.voie_dy(-1.0)
	ok(y_fond > 0.0 and CombatModele.voie_echelle(-1.0) < 1.0 and CombatModele.voie_dy(1.0) < 0.0 and CombatModele.voie_echelle(1.0) > 1.0, "rendu : fond plus haut et plus petit, devant plus bas et plus grand")

	print("%d ÉCHEC(S)" % echecs if echecs > 0 else "Tous les tests des voies passent.")
	quit()

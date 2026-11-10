# Carte fixe branchée au jeu (DEV-039, DEC-216) : mêmes secteurs à chaque partie, voyage par les routes, décor par région,
# difficulté forcée hors de la région de la quête principale, anciennes sauvegardes.
# godot --headless --path game -s res://tests/test_carte_jeu.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func _init() -> void:
	Textes.langue = "fr"
	var a := CombatModele.new(1)
	var b := CombatModele.new(999)
	var wa := a.monde
	var wb := b.monde
	ok(wa.secteurs.size() == CarteMonde.villes().size(), "un secteur par ville-étape de la carte (%d)" % wa.secteurs.size())
	var meme := true
	for i in wa.secteurs.size():
		meme = meme and wa.secteurs[i].nom == wb.secteurs[i].nom and wa.secteurs[i].niveau == wb.secteurs[i].niveau
	ok(meme, "la carte est identique à chaque partie, quelle que soit la graine")
	ok(String(wa.secteurs[wa.secteur].lieu) == "kerbrume" and wa.region_quete == "armorique", "départ à Kerbrume, quête dans l'Armorique")

	# Voyage : seulement par les routes
	var lointain := -1
	for s in wa.secteurs:
		if int(s.id) != wa.secteur and not wa.est_voisin(wa.secteur, int(s.id)):
			lointain = int(s.id)
	ok(lointain >= 0 and not wa.choisir_destination(lointain), "une ville sans route directe ne peut pas être choisie")
	ok(wa.prochaine_etape(lointain) >= 0 and wa.est_voisin(wa.secteur, wa.prochaine_etape(lointain)), "la prochaine étape vers une ville lointaine est une ville voisine")
	var voisins := wa.voisins_secteur(wa.secteur)
	ok(voisins.size() >= 2, "Kerbrume a %d routes" % voisins.size())

	# Difficulté forcée hors région
	var n0 := wa.niveau_a(wa.x_entree)
	var pertuis := wa.indice_lieu("pertuis")
	ok(wa.region_courante() == "armorique" and a.malus_hors_region() == 0, "dans la région de la quête : pas de malus")
	wa.secteur = pertuis
	ok(wa.region_courante() == "pertuis" and a.malus_hors_region() == 3, "hors de la région de la quête : +3 niveaux")
	ok(wa.niveau_a(wa.x_entree) == int(wa.secteurs[pertuis].niveau) + 3, "le niveau de rencontre inclut le malus")
	wa.region_quete = "pertuis"
	ok(a.malus_hors_region() == 0, "quand la quête change de région, le malus change aussi")
	wa.region_quete = ""
	ok(a.malus_hors_region() == 0, "sans région de quête : pas de malus")
	wa.region_quete = "armorique"
	wa.secteur = wa.indice_lieu("kerbrume")

	# Décor : la zone suit le secteur
	wa.secteur = wa.indice_lieu("loire")
	wa.trajet = {}
	Terrain.zone = "terre"
	wa.secteur = wa.indice_lieu("kerbrume")
	ok(wa.choisir_destination(wa.indice_lieu("estuaire")), "route de Kerbrume à Port-Estuaire")
	wa.trajet.reste = 0.0
	wa._cap(0.1)
	ok(wa.secteur == wa.indice_lieu("estuaire") and Terrain.zone == String(wa.secteurs[wa.secteur].zone), "arrivée : le décor suit la zone du secteur (%s)" % Terrain.zone)

	# Sauvegarde : nouvelle carte conservée, ancienne sauvegarde ramenée à Kerbrume
	var sv := a.sauver()
	ok(int(sv.monde.carte) == 2 and sv.monde.region_quete == "armorique", "la sauvegarde note la version de carte et la région de quête")
	var c := CombatModele.depuis_sauvegarde(JSON.parse_string(JSON.stringify(sv)))
	ok(c.monde.secteur == wa.secteur, "la reprise garde le secteur")
	var vieux: Dictionary = JSON.parse_string(JSON.stringify(sv))
	vieux.monde.erase("carte")
	vieux.monde.secteur = 11
	var d := CombatModele.depuis_sauvegarde(vieux)
	ok(String(d.monde.secteurs[d.monde.secteur].lieu) == "kerbrume", "ancienne sauvegarde (carte aléatoire) : le convoi repart de Kerbrume")
	if n0 < 0:
		ok(false, "niveau négatif")

	print("Échecs : %d" % echecs)
	quit(1 if echecs > 0 else 0)

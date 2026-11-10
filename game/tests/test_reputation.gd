# Réputation, rangs par vignette et bulles d'aide (lot D : DEC-184, 186, 187, 194, DEC-217).
# godot --headless --path game -s res://tests/test_reputation.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func _init() -> void:
	Textes.langue = "fr"
	var m := CombatModele.new(3)
	var w := m.monde
	# Départ : Réseau des Marées ami, Raffineurs hostiles, Compagnies neutres
	ok(String(m.rep_palier("FAC-003").id) == "amical", "départ : le Réseau des Marées est amical")
	ok(String(m.rep_palier("FAC-001").id) == "neutre" and String(m.rep_palier("FAC-007").id) == "hostile", "départ : Compagnies neutres, Péage hostile")
	ok(int(w.secteurs[w.secteur].faction) == 1, "Kerbrume (Marées) : attitude ami pour le monde")
	# Contrecoup : être aimé des Marées déplaît aux Raffineurs
	var r0 := m.rep_valeur("FAC-002")
	m.rep_changer("FAC-003", 10.0, "essai")
	ok(m.rep_valeur("FAC-003") == 30.0 and m.rep_valeur("FAC-002") == r0 - 5.0, "contrecoup : +10 chez les Marées, -5 chez les Raffineurs rivaux")
	ok(String(m.rep_palier("FAC-003").id) == "allie", "palier allié à 30")
	m.rep_changer("FAC-003", -200.0)
	ok(m.rep_valeur("FAC-003") == -100.0, "la réputation est bornée à -100")
	ok(int(w.secteurs[w.secteur].faction) == 3, "hostile : le monde considère la ville comme hostile")
	# Effets : prix, missions, accueil
	var m2 := CombatModele.new(4, {"villes": true})
	m2.rep_changer("FAC-003", 0.0)
	var base: float = float(m2.VD().marche.lot) * float(m2.VD().marche.prix_metal.eau)
	m2.reputation["FAC-003"] = 40.0
	ok(m2.ville_prix_lot("eau") == int(round(base * 0.8)), "allié : prix à 80 %")
	m2.reputation["FAC-003"] = -50.0
	ok(m2.ville_prix_lot("eau") == int(round(base * 1.6)), "hostile : prix à 160 %")
	ok(not m2.rep_missions_ok("FAC-003") and m2.rep_missions_ok("FAC-001"), "hostile : aucune mission proposée")
	ok(m2.rep_accueil("FAC-003") != "" and m2.rep_accueil("FAC-001") == "", "accueil : phrase du palier, rien au palier neutre")
	# Actes
	var m3 := CombatModele.new(5)
	var av := m3.rep_valeur("FAC-005")
	m3.rep_acte("camp_detruit", "camp_ami", "FAC-005", "camp")
	ok(m3.rep_valeur("FAC-005") == av - 20.0, "détruire un camp allié : -20 pour sa faction")
	# Sauvegarde
	var sv: Dictionary = JSON.parse_string(JSON.stringify(m3.sauver()))
	var m4 := CombatModele.depuis_sauvegarde(sv)
	ok(m4.rep_valeur("FAC-005") == av - 20.0, "la réputation survit à la sauvegarde")
	# Rangs : monter et descendre changent la place d'un véhicule
	var mk := CombatModele.new(6, {"bac_a_sable": true})
	var a := ConstructionLibre.voiture("moyen")
	a.nom = "Essai"
	mk.construire_grille(0, a)
	mk.construire_grille(1, a)
	var u0: int = mk.convoi[0].uid
	mk.descendre(u0)
	ok(mk.convoi[1].uid == u0, "rang : un véhicule passe vers l'arrière")
	mk.monter(u0)
	ok(mk.convoi[0].uid == u0, "rang : et revient vers l'avant")
	# Bulles d'aide : une seule fois, mémorisées
	Aide.chemin = "user://aide_test.json"
	Aide.reinitialiser()
	var t1 := Aide.prendre("002")
	var t2 := Aide.prendre("002")
	ok(t1 != "" and t2 == "" and Aide.vu("002"), "aide : montrée une seule fois")
	Aide.reinitialiser()
	ok(Aide.prendre("002") != "", "aide : réinitialisable")
	for k in ["001", "002", "003", "004", "005", "006", "007", "008"]:
		ok(Textes.donnees().fr.has("aide." + k) and Textes.donnees().en.has("aide." + k), "aide %s : texte fr et en" % k)
	Aide.reinitialiser()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://aide_test.json"))
	print("Échecs : %d" % echecs)
	quit(1 if echecs > 0 else 0)

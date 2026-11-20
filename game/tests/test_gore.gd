# Gore, annonces et caméra de contact (DEC-257).
# godot --headless --path game -s res://tests/test_gore.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func _init() -> void:
	Textes.langue = "fr"
	var m := CombatModele.new(11, {"bac_a_sable": true, "kit_groupe": true})
	m._prochain_x = INF
	var v: CombatModele.Veh = m.convoi[0]
	m.vider_evenements()
	var avant := v.equipage_vivant()
	m._blesser_equipage(v, 1000.0)
	var sang := m.vider_evenements().filter(func(e): return e.t == "sang")
	ok(sang.size() == 1 and bool(sang[0].mort) and v.equipage_vivant() == avant - 1, "un homme tué émet un événement « sang » mortel")
	m._blesser_equipage(v, 0.5)
	var leger := m.vider_evenements().filter(func(e): return e.t == "sang")
	ok(leger.is_empty() or not bool(leger[0].mort), "une blessure légère ne tue pas")
	# réglage Gore mémorisé
	Gore.regler(1)
	Gore.niveau = 0
	Gore._charge = false
	ok(Gore.lire() == 1, "le réglage Gore est relu depuis le disque")
	Gore.regler(2)
	# textes d'annonce
	ok(Textes.t("annonce.avant") != "annonce.avant" and Textes.t("gore.2") != "gore.2", "textes d'annonce et de gore présents")
	# annonce d'attaque par l'avant avec une rencontre
	var m2 := CombatModele.new(5, {})
	m2.ordre_marche("avancer")
	var vu := false
	for i in 4000:
		m2.avancer()
		for e in m2.vider_evenements():
			if e.t == "annonce":
				vu = true
		if vu:
			break
	ok(vu, "une rencontre ou une ville déclenche une annonce")
	print("Échecs : ", echecs)
	quit(1 if echecs > 0 else 0)

# Test sans écran du début de partie guidé (DEC-035) :
#   godot --headless --path game -s res://tests/test_ouverture.gd
# Caisse de pièces -> moto -> grange (side-car + survivant) -> essence -> arme et munitions -> premiers ennemis.
extends SceneTree

var echecs := 0


func verifier(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "ÉCHEC ") + msg)
	if not cond:
		echecs += 1


func _avancer(m: CombatModele, secondes: float) -> void:
	for i in int(secondes / CombatModele.DT):
		m.avancer()


# Avance jusqu'à la prochaine ruine non fouillée, la fouille, puis s'arrête. Renvoie la ruine.
func _fouiller_suivante(m: CombatModele):
	m.ordre_marche("avancer")
	var ru = null
	for i in 3000:
		m.avancer()
		for b in m.batiments:
			if not b.butin_pris and b.statut == "neutralise":
				ru = b
		if ru != null:
			break
	if ru == null:
		return null
	m.ordre_fouiller(ru.uid)
	for i in 3000:
		m.avancer()
		if ru.butin_pris:
			break
	m.ordre_marche("halte")
	_avancer(m, 1.0)
	return ru


func _init() -> void:
	var m := CombatModele.new(5, {"ouverture": true})
	verifier(m.en_kit and m.convoi.is_empty() and m.pieces_stock.size() == 6, "départ : aucun véhicule, une caisse de 6 pièces")
	_avancer(m, 5.0)
	verifier(m.temps == 0.0, "rien n'avance tant que la moto n'est pas assemblée")
	var at := m.atelier_possible()
	verifier(at.get("uid", -1) == 0 and at.get("plan", "") == "moto_bmw", "l'atelier propose d'assembler la moto")
	var incomplet := Assemblage.de_type("moto_bmw")
	incomplet.pieces.pop_back()
	verifier(not m.assembler(0, incomplet), "moto sans selle : refusée")
	verifier(m.assembler(0, Assemblage.de_type("moto_bmw")), "moto assemblée")
	var moto: CombatModele.Veh = m.convoi[0]
	verifier(moto.type == "moto_bmw" and moto.equipage.size() == 1 and moto.armes.is_empty() and m.pieces_stock.is_empty(),
		"une moto, un pilote, pas d'arme, caisse vide")
	verifier(absf(moto.vitesse() - 8.5) < 0.01, "la moto seule roule à 8,5 m/s")

	# 1. La grange : pièces du side-car et un survivant
	var ru = _fouiller_suivante(m)
	verifier(ru != null and ru.type == "grange", "première trouvaille : une grange")
	verifier(m.pieces_stock.size() == 3 and m.reserve_survivants == 1, "3 pièces de side-car et un survivant qui attend une place")
	verifier(m.ennemis.is_empty() and m.monde.vivants() == 0, "toujours aucun ennemi")
	at = m.atelier_possible()
	verifier(at.get("plan", "") == "side_bmw" and at.get("uid", 0) == moto.uid, "l'atelier propose le side-car")
	verifier(m.assembler(moto.uid, Assemblage.de_type("side_bmw")), "side-car assemblé au bord de la route")
	verifier(moto.type == "side_bmw" and moto.equipage.size() == 2 and m.reserve_survivants == 0, "le survivant monte dans le panier")
	verifier(absf(moto.vitesse() - 7.5) < 0.01, "le side-car roule moins vite (7,5 m/s)")

	# 2. L'essence
	var carb: float = m.stocks.fuel_l
	ru = _fouiller_suivante(m)
	verifier(ru != null and m.stocks.fuel_l >= carb + 19.0, "deuxième trouvaille : de l'essence (%.1f L)" % m.stocks.fuel_l)

	# 3. L'arme et les munitions
	ru = _fouiller_suivante(m)
	verifier(ru != null and m.stocks.ammo >= 80 and "arme_mitrailleuse" in m.ids_stock(), "troisième trouvaille : mitrailleuse et munitions")
	verifier(m.atelier_possible().get("plan", "") == "bmw_r75", "l'atelier propose de monter la mitrailleuse")
	verifier(m.assembler(moto.uid, Assemblage.de_type("bmw_r75")), "mitrailleuse montée")
	verifier(moto.type == "bmw_r75" and moto.armes.size() == 1 and not m.calme_ouverture(), "side-car armé : l'ouverture est finie")

	# 4. Puis viennent les ennemis
	m.ordre_marche("avancer")
	var contact := false
	for i in 6000:
		m.avancer()
		if not m.ennemis.is_empty() or m.batiments.any(func(b): return b.actif()) or m.monde.vivants() > 0:
			contact = true
			break
	verifier(contact, "ensuite, les ennemis arrivent (à %d m)" % int(m.x_tete))

	# 5. Sauvegarde : l'assemblage et la réserve sont conservés
	var m2 := CombatModele.depuis_sauvegarde(JSON.parse_string(JSON.stringify(m.sauver())))
	verifier(m2.convoi[0].type == "bmw_r75" and m2.ouverture and m2.convoi[0].assemblage.pieces.size() == 9, "sauvegarde et reprise du side-car assemblé")

	print("Échecs : %d" % echecs)
	quit(1 if echecs > 0 else 0)

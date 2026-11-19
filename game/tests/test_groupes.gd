# Groupes d'ennemis prêts à lancer, convois de départ du Kit, annonce (DEC-253).
# godot --headless --path game -s res://tests/test_groupes.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func kit(opts := {"bac_a_sable": true, "kit_groupe": true}) -> CombatModele:
	Textes.langue = "fr"
	var m := CombatModele.new(7, opts)
	m._prochain_x = INF
	return m


func _init() -> void:
	# 1) Convoi de départ du Kit
	var m := kit()
	ok(m.convoi.size() == 3 and m.convoi[0].principal and m.convoi[0].type == "berliet_gdr", "Kit : départ avec un convoi constitué (%d véhicules)" % m.convoi.size())
	ok(CombatModele.new(7, {"bac_a_sable": true}).convoi.size() == 1, "sans kit_groupe : Berliet seul (tests inchangés)")
	ok(m.kit_convoi_depart("blinde") and m.convoi.size() == 4 and m.convoi[0].principal, "convoi « blindé » : 4 véhicules, le camion principal reste")

	# 2) Tous les scénarios, toutes tailles, tous côtés : composition valide, annonce émise
	var G: Dictionary = CombatModele.donnees().groupes
	for sc in G.scenarios:
		for taille in ["petit", "moyen", "grand"]:
			for cote in sc.cotes.keys():
				m = kit()
				var avant: int = m.ennemis.size()
				var cr: bool = m.kit_scenario(String(sc.id), taille, String(cote))
				ok(cr and m.ennemis.size() > avant, "%s %s %s : lancé (%d véhicules)" % [sc.id, taille, cote, m.ennemis.size() - avant])
	# 3) Côté et agressivité
	m = kit()
	m.kit_scenario("marchands", "petit", "droite")
	ok(m.ennemis.all(func(e): return e.allie and e.armes.is_empty() and int(e.profil.agr) == 0), "marchands : alliés sans arme, pacifiques")
	m = kit()
	var x0: float = m._queue().x
	m.kit_scenario("raid", "moyen", "gauche")
	ok(m.ennemis.all(func(e): return e.x < x0 and e.mode == "poursuite" and int(e.profil.agr) == 2), "raid à gauche : derrière le convoi, en poursuite")
	m = kit()
	m.kit_scenario("raid", "moyen", "droite")
	ok(m.ennemis.all(func(e): return e.x > m.x_tete and e.mode == "approche"), "raid à droite : devant le convoi, à l'approche")
	m = kit()
	m.kit_scenario("patrouille", "petit", "droite")
	ok(m.ennemis.all(func(e): return e.mode == "face" and not e.allie and not m._intention.get(e.uid, true)), "patrouille : méfiante, croise sans éperonner")
	m = kit()
	ok(m.kit_scenario("hasard") and not m.ennemis.is_empty(), "scénario au hasard")
	ok(not m.kit_scenario("inconnu"), "scénario inconnu refusé")
	ok(not CombatModele.new(7, {}).kit_scenario("raid"), "hors Mode créatif : refusé")

	# 4) Textes et couleurs
	for i in 4:
		ok(Textes.t("groupe.a%d" % i) != "groupe.a%d" % i, "niveau %d : texte" % i)
		ok(Color(String(G.agressivite[i].couleur)) != Color(), "niveau %d : couleur" % i)
	for sc in G.scenarios:
		ok(Textes.t("groupe.s." + String(sc.id)) != "groupe.s." + String(sc.id), "scénario %s : texte" % sc.id)

	print("%d ÉCHEC(S)" % echecs if echecs > 0 else "Tous les tests de groupes passent.")
	quit()

# Captures : annonce de camp, carte, nuit et abri (planches, feu), camp allié, fantassins et animaux.
extends SceneTree

var vue
var frame := 0
var dossier := "/tmp"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		dossier = args[0]
	vue = load("res://scenes/convoi.tscn").instantiate()
	root.add_child(vue)


func _photo(nom: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [dossier, nom])
	print("capture ", nom)


func _camp(m, type: String, dx: float, ami: bool, fac: int):
	var b = m.creer_batiment(type, m.x_tete + dx)
	b.ami = ami
	b.faction = fac
	m.batiments.append(b)
	return b


func _process(_d: float) -> bool:
	frame += 1
	var m = vue.m
	if frame == 3:
		vue._nouvelle_partie(11)
		m = vue.m
		m._prochain_x = 1.0e9
		m.batiments.clear()
		m.epaves.clear()
		_camp(m, "camp_fortifie", 250.0, false, 3)
		_camp(m, "camp_ami", 420.0, true, 1)
	if frame == 30:
		_photo("m1_annonce")
		vue._ouvrir_carte()
		vue._carte_sel = 5
	if frame == 45:
		_photo("m2_carte")
		vue._fermer_carte()
	if frame == 50:
		vue._nouvelle_partie(12)
		m = vue.m
		m._prochain_x = 1.0e9
		m.batiments.clear()
		m.epaves.clear()
		var e = m.creer_batiment("eglise", m.x_tete + 14.0)
		e.statut = "neutralise"
		e.butin_pris = true
		m.batiments.append(e)
		m.ordre_marche("halte")
		m.monde.heure = 0.64
		vue.vitesse_sim = 3
	if frame == 200:
		_photo("m3_nuit_alerte")
		m.monde.ordre_nuit()
	if frame == 240:
		_photo("m4_planches")
	if frame == 280:
		_photo("m5_nuit_feu")
	if frame == 610:
		vue._nouvelle_partie(13)
		m = vue.m
		m._prochain_x = 1.0e9
		m.batiments.clear()
		m.epaves.clear()
		_camp(m, "camp_ami", 8.0, true, 1)
		m.ordre_marche("halte")
		vue.vitesse_sim = 1
	if frame == 640:
		_photo("m6_camp")
		vue._camp_ferme = m.monde.camp_proche().uid
		m.monde.pnj.append({"uid": 5, "x": m.x_tete + 22.0, "type": "marchand", "nom": "Marchand ambulant", "offre": 0, "statut": "attend", "peau": 1})
		m.monde.creer_pieton("loup", m.x_tete + 38.0)
		m.monde.creer_pieton("loup", m.x_tete + 44.0)
		m.monde.creer_pieton("pillard", m.x_tete + 50.0)
	if frame == 700:
		_photo("m7_fantassins")
		vue._ouvrir_surv()
		vue._surv_sel = {"veh": m.convoi[0].uid, "idx": 0, "nom": "Test"}
	if frame == 720:
		_photo("m8_survivants")
		vue._fermer_surv()
		m.batiments.clear()
		m.batiments.append(_camp(m, "maison", 14.0, false, 0))
		m.batiments[0].statut = "neutralise"
		m.monde.pietons.clear()
		m.monde.pnj.clear()
	if frame == 760:
		_photo("m9_fouiller")
		quit(0)
	return false

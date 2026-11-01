# Grille de construction libre (DEC-043), refaite pour l'iPhone (DEC-056 à DEC-058), puis en icônes (DEC-080) :
# - grille la plus grande possible, peu de texte ;
# - barre d'icônes à droite : coche (construire), croix (quitter), une icône par catégorie ;
# - la catégorie choisie ouvre un tiroir simplifié : vignettes des pièces (miniature du vrai dessin), listes courtes ;
# - toute pièce posée se reprend au doigt pour la déplacer, ou se lâche hors de la grille pour la retirer ;
# - tôles tracées d'un coin à l'autre (glisser), à l'angle voulu ; peinture de bande ; remorques ; véhicules du jeu (bac à sable).
# Aucune règle ici : tout passe par ConstructionLibre et CombatModele (grille_de, palette_grille, construire_grille).
class_name EditeurGrille
extends Control

signal ferme(construit: bool)

const C_FOND := Color(0.06, 0.065, 0.07)
const C_ZONE := Color(0.09, 0.095, 0.1)
const FOND_GRILLE: Texture2D = preload("res://assets/decor/fond_grille.png")
const C_GRILLE := Color(1, 1, 1, 0.07)
const C_CADRE := Color(1, 1, 1, 0.22)
const C_ACCENT := Color("#E8A33D")
const C_TEXTE := Color("#F2EEE6")
const C_DISCRET := Color("#A8A196")
const C_VERT := Color("#5FB36B")
const C_ROUGE := Color("#D9674A")
const C_SOL := Color(0.55, 0.45, 0.3)
const C_TUILE := Color(0.12, 0.115, 0.11, 0.82)
# Barre d'icônes : deux actions, puis les catégories dans l'ordre de construction
const ACTIONS := ["valider", "quitter"]
const ONGLETS := [["chassis", "Châssis"], ["essieux", "Essieux"], ["roues", "Roues"], ["suspension", "Suspension"], ["moteur", "Moteurs"],
	["poste", "Postes"], ["coque", "Carrosserie"], ["toles", "Tôles"], ["arme", "Armes"], ["equipement", "Options"], ["equipage", "Équipage"],
	["peinture", "Peinture"], ["plans", "Plans"], ["vehicules", "Véhicules"]]
const AIDES := {"chassis": "Glissez d'un coin à l'autre", "essieux": "Touchez une colonne", "roues": "Touchez un essieu",
	"suspension": "Touchez un pont en l'air", "moteur": "Glissez sur la grille", "poste": "Glissez sur la grille",
	"coque": "Glissez ; se superposent", "toles": "Glissez d'un point à un autre", "arme": "Glissez sur la grille",
	"equipement": "Collées à l'extérieur", "equipage": "Touchez un siège", "peinture": "Ton de tout le véhicule",
	"plans": "Enregistrer ou charger", "vehicules": "Partir d'un véhicule"}
# Peintures de bande (DEC-080) : un ton par faction, à régler
const PEINTURES := [["", "Sans"], ["#5E6238", "Kaki"], ["#B0623A", "Rouille"], ["#3A3A38", "Suie"], ["#C9A23A", "Jaune"],
	["#6A86A8", "Bleu horizon"], ["#8A3030", "Sang"], ["#D8D4C8", "Hiver"], ["#4E6E58", "Vert-de-gris"]]
const COULEURS := {"moteur": Color("#A8552F"), "radiateur": Color("#6A6A60"), "cabine": Color("#5E6238"), "poste": Color("#6E5A3A"), "arme": Color("#9A2F2F"),
	"equipement": Color("#8A7A3A"), "coque": Color("#7A6A55"), "greffe": Color("#6A5A4A")}
# Essieux, roues et liaisons : lus dans le catalogue par famille (ajouter un modèle = une entrée dans pieces.json)
static func _famille(fam: String) -> Array:
	var res: Array = Assemblage.catalogue().pieces.keys().filter(func(id): return Assemblage.piece(id).get("famille", "") == fam and not Assemblage.piece(id).get("retire", false))
	res.sort_custom(func(p, q): return float(Assemblage.piece(p).get("charge_kg", 0)) < float(Assemblage.piece(q).get("charge_kg", 0)))
	return res
const NOMS_ROLES := {"conducteur": "Conducteur", "tireur": "Tireur", "chargeur": "Chargeur", "chef": "Chef de char",
	"mecanicien": "Mécanicien", "infirmier": "Infirmier", "passager": "Passager"}
const AIDE_ROLES := {"conducteur": "obligatoire", "tireur": "sert une arme", "chargeur": "recharge plus vite", "chef": "précision +10 %",
	"mecanicien": "répare plus vite", "infirmier": "soigne", "passager": "aucun rôle"}
const BROUILLON := "user://grille_brouillon.json"
const DECALAGE_DOIGT := 1.6   # la pièce glissée flotte au-dessus du doigt (en cases) pour rester visible

var m                       # CombatModele
var uid := 0                # véhicule modifié (0 = véhicule neuf)
var a := {}                 # grille en cours
var onglet := "chassis"
var outil := {"chassis": "acier", "essieux": "essieu_leger", "roues": "roue_moyenne", "suspension": "liaison_lames"}
var _palette: Array = []    # [{id, n}] ; n = -1 : sans limite
var _glisse := ""           # pièce tenue au doigt
var _miroir := false        # coque retournée (avant vers l'arrière), DEC-067
var _scie := ""             # "" | "v" | "h" : la scie coupe la coque touchée (DEC-072)
var _extra := {}            # morceau scié tenu au doigt : coupe, emprise, lot
var _essieu_tenu := {}      # essieu repris au doigt : lâché hors de la grille, il est retiré (DEC-076)
var _ecorche := false       # vue écorchée forcée dans l'onglet Carrosserie
var _suppr_plans := false   # onglet Plans : toucher un plan le supprime
var _rect0 := Vector2i(-99, -99)   # coin de départ du rectangle de châssis
var _rect1 := Vector2i(-99, -99)
var _tole0 := Vector2i(-99, -99)   # tôle en cours de tracé (coins de cases)
var _tole1 := Vector2i(-99, -99)
var _appui := false
var _doigt := Vector2.ZERO
var _vue := Rect2i(8, 0, 24, 10)   # fenêtre de la grille affichée (en cases)
var _grille := Rect2()
var _cell := 40.0
var _rail := Rect2()        # barre d'icônes
var _tiroir := Rect2()      # tiroir de la catégorie
var _rect_nom := Rect2()
var _mg := {}
var _page := 0
var _cartes: Array = []     # [{rect, action, actif}] : tout ce qui se touche en dehors de la grille
var _an := {}
var _message := ""
var _msg_t := 0.0
var _confirmer := false     # armes sans tireur : deuxième appui sur la coche pour confirmer
var _apercu: VehiculeDessin
var _dessus: Control
static var _minis := {}     # id -> formes de la pièce seule (miniatures du tiroir)


func ouvrir(modele, vehicule_uid: int) -> void:
	m = modele
	uid = vehicule_uid
	a = m.grille_de(uid)
	_palette = m.palette_grille(uid)
	var b := _lire_brouillon()
	if not b.is_empty():
		a = b
		_dire("Brouillon repris.")


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_apercu = VehiculeDessin.new()
	_apercu.equipage = true
	_apercu.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_apercu)
	_dessus = Control.new()
	_dessus.mouse_filter = MOUSE_FILTER_IGNORE
	_dessus.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_dessus.draw.connect(_dessiner_dessus)
	add_child(_dessus)
	resized.connect(_disposer)
	_maj(true)


func _choisir_onglet(id: String) -> void:
	onglet = id
	_scie = ""
	_page = 0
	_glisse = ""
	_suppr_plans = false
	_disposer()


# --- Mise en page : barre d'icônes à droite, tiroir à sa gauche, la grille prend tout le reste -------
func _disposer() -> void:
	if size.x < 10.0:
		return
	_mg = ZonesSures.marges(size)
	var g: float = _mg.g
	var d: float = size.x - _mg.d
	var haut := 10.0 + float(_mg.h)
	var bas := size.y - float(_mg.b) - 6.0
	var n := ACTIONS.size() + ONGLETS.size()
	var rangs := int(ceil(n / 2.0))
	var ic := clampf(floorf((bas - haut - (rangs - 1) * 8.0) / rangs), 56.0, 92.0)
	_rail = Rect2(Vector2(d - 2.0 * ic - 8.0, haut), Vector2(2.0 * ic + 8.0, rangs * (ic + 8.0) - 8.0))
	var tw := clampf(size.x * 0.16, 280.0, 330.0)
	_tiroir = Rect2(Vector2(_rail.position.x - 12.0 - tw, haut), Vector2(tw, bas - haut))
	_rect_nom = Rect2(Vector2(g, haut), Vector2(minf(560.0, _tiroir.position.x - g - 20.0), 44.0))
	var zone := Rect2(Vector2(g, haut + 52.0), Vector2(_tiroir.position.x - 16.0 - g, bas - haut - 52.0 - 64.0))
	var sous_sol := 2.2   # place pour les roues sous la ligne 0
	_cell = floorf(minf(zone.size.x / float(_vue.size.x), zone.size.y / (float(_vue.size.y) + sous_sol)))
	var taille := Vector2(_vue.size) * _cell
	_grille = Rect2(zone.position + Vector2((zone.size.x - taille.x) * 0.5, (zone.size.y - taille.y - sous_sol * _cell) * 0.5), taille)
	_placer_apercu()
	queue_redraw()
	_dessus.queue_redraw()


# Fenêtre affichée : le véhicule et une marge autour, au moins `grille_vue_min` cases
func _ajuster_vue() -> void:
	var G := ConstructionLibre.taille()
	var mini_v: Array = ConstructionLibre.R().get("grille_vue_min", [24, 10])
	var x0 := G.x
	var x1 := 0
	var y1 := 0
	for c in a.get("cases", []):
		x0 = mini(x0, int(c[0]))
		x1 = maxi(x1, int(c[0]) + 1)
		y1 = maxi(y1, int(c[1]) + 1)
	for p in a.get("pieces", []):
		var e: Array = p.get("emprise", Assemblage.piece(String(p.piece)).emprise)
		x0 = mini(x0, int(p.pos[0]))
		x1 = maxi(x1, int(p.pos[0]) + int(e[0]))
		y1 = maxi(y1, int(p.pos[1]) + int(e[1]))
	for t in a.get("toles", []):
		x0 = mini(x0, mini(int(t[0]), int(t[2])))
		x1 = maxi(x1, maxi(int(t[0]), int(t[2])))
		y1 = maxi(y1, maxi(int(t[1]), int(t[3])))
	if x1 <= x0:
		x0 = G.x / 2
		x1 = x0
	var w := clampi(x1 - x0 + 4, int(mini_v[0]), G.x)
	var h := clampi(y1 + 3, int(mini_v[1]), G.y)
	var cx := (x0 + x1) / 2
	var gx := clampi(cx - w / 2, 0, G.x - w)
	_vue = Rect2i(gx, 0, w, h)


# --- Changements ------------------------------------------------------------------------------
func _maj(revoir_vue := false) -> void:
	if not a.get("nom_choisi", false):
		a.nom = ConstructionLibre.nom_propose(a)
	_an = ConstructionLibre.analyser(a)
	_confirmer = false
	if revoir_vue:
		_ajuster_vue()
	_ecrire_brouillon()
	_disposer()


func _placer_apercu(b := {}) -> void:
	var source: Dictionary = a if b.is_empty() else b
	if source.get("cases", []).is_empty():
		_apercu.visible = false
		return
	var F := ConstructionLibre.forme(source, _ecorche or not onglet in ["coque", "equipage", "peinture", "vehicules", "toles"])   # coques transparentes quand on règle la mécanique
	_apercu.ppm = _cell / ConstructionLibre.C
	_apercu.configurer_d(F)
	_apercu.visible = true
	_apercu.position = _px(float(F.x0), float(F.sol)) - Vector2(0, _apercu.size.y)


func _process(delta: float) -> void:
	if m == null:
		return
	_msg_t = maxf(0.0, _msg_t - delta)
	_dessus.queue_redraw()


func _peut_construire() -> bool:
	return _an.get("ok", false) and (m.bac_a_sable or m.stocks.metal >= m.cout_grille(uid, a))


func _restant(id: String, n: int) -> int:
	if n < 0:
		return -1
	return n - ConstructionLibre.utilisees(a, id)


func _case(pos: Vector2) -> Vector2i:
	return Vector2i(_vue.position.x + int(floor((pos.x - _grille.position.x) / _cell)), int(floor((_grille.end.y - pos.y) / _cell)))


func _coin(pos: Vector2) -> Vector2i:   # coin de case le plus proche (tôles)
	return Vector2i(_vue.position.x + int(round((pos.x - _grille.position.x) / _cell)), int(round((_grille.end.y - pos.y) / _cell)))


func _px(x: float, y: float) -> Vector2:   # cases (absolues) -> écran
	return Vector2(_grille.position.x + (x - _vue.position.x) * _cell, _grille.end.y - y * _cell)


func _dans_grille(pos: Vector2) -> bool:
	return _grille.grow_individual(0, 0, 0, 2.2 * _cell).has_point(pos)


# --- Toucher ----------------------------------------------------------------------------------
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_doigt = e.position
		if e.pressed:
			_appui = true
			for c in _cartes:
				if c.rect.has_point(e.position):
					if c.actif:
						c.action.call()
					accept_event()
					return
			if _dans_grille(e.position):
				_appuyer(_case(e.position))
		else:
			_relacher(e.position)
			_appui = false
		accept_event()
	elif e is InputEventMouseMotion:
		_doigt = e.position
		if _appui and onglet == "chassis" and _rect0.x > -99:
			var c := _case(e.position)
			_rect1 = Vector2i(clampi(c.x, 0, ConstructionLibre.taille().x - 1), clampi(c.y, 0, ConstructionLibre.taille().y - 1))
		if _appui and _tole0.x > -99:
			_tole1 = _coin(e.position)
		if _glisse != "":
			_placer_apercu(_candidat())
		accept_event()


func _appuyer(cell: Vector2i) -> void:
	if onglet == "toles":
		_tole0 = _coin(_doigt)
		_tole1 = _tole0
		return
	# Une pièce posée se reprend au doigt depuis n'importe quelle catégorie (DEC-076, DEC-080) ; une coque seulement en Carrosserie
	if onglet != "coque" and onglet != "essieux":
		var ip := ConstructionLibre.piece_en(a, cell)
		if ip >= 0 and (onglet != "chassis" or not _est_coque(String(a.pieces[ip].piece))):
			_prendre(ip)
			return
	match onglet:
		"chassis":
			_rect0 = cell
			_rect1 = cell
		"essieux":
			var ex := ConstructionLibre.essieu_en(a, cell.x)
			if not ex.is_empty() and ex.piece == outil.essieux:   # même essieu : on le reprend au doigt (déplacer, ou glisser hors de la grille)
				_essieu_tenu = ex.duplicate()
				a = ConstructionLibre.retirer_essieu(a, cell.x)
				_maj()
				return
			var ip := ConstructionLibre.piece_en(a, cell)
			if ip >= 0:
				_prendre(ip)
				return
			var b := ConstructionLibre.poser_essieu(a, cell.x, outil.essieux, String(ex.get("train", "")), cell.y)
			if b.is_empty():
				_dire("Pas de châssis au-dessus.")
				return
			a = b
			if Assemblage.piece(outil.essieux).get("pont", false):
				_dire("Pont à %d cm sous le châssis : reliez-le (Suspension)." % (ConstructionLibre.ecart_pont(a, ConstructionLibre.essieu_en(a, cell.x)) * 25))
			_son()
			_maj()
		"roues":
			_monter_roue(cell.x)
		"suspension":
			var ex := ConstructionLibre.essieu_en(a, cell.x)
			if ex.is_empty() or not Assemblage.piece(String(ex.piece)).get("pont", false):
				_dire("Posez d'abord un pont rigide en l'air (Essieux).")
				return
			var lid: String = outil.suspension
			var b := ConstructionLibre.relier(a, cell.x, lid)
			if b.is_empty():   # la liaison choisie ne couvre pas l'écart : on prend celle qui convient
				var h := ConstructionLibre.ecart_pont(a, ex)
				var ok_ids := ConstructionLibre.liaisons_pour(h)
				if ok_ids.is_empty():
					_dire("Pont trop loin du châssis (%d cm)." % (h * 25))
					return
				lid = ok_ids[0]
				b = ConstructionLibre.relier(a, cell.x, lid)
				_dire("À %d cm : %s." % [h * 25, Assemblage.piece(lid).nom])
			a = b
			_son()
			_maj(true)
		"coque":
			var i := ConstructionLibre.piece_en(a, cell, true)
			if i >= 0 and _scie != "":
				var bs := ConstructionLibre.scier(a, i, cell, _scie)
				if bs.is_empty():
					_dire("Touchez l'intérieur de la coque.")
				else:
					a = bs
					_son()
					_maj()
				return
			if i >= 0:
				_prendre(i)


func _relacher(pos: Vector2) -> void:
	if _tole0.x > -99:
		var q0 := _tole0
		var q1 := _coin(pos)
		_tole0 = Vector2i(-99, -99)
		if q0 == q1:   # simple toucher : retire la tôle touchée
			var i := ConstructionLibre.tole_en(a, Vector2(_vue.position.x + (pos.x - _grille.position.x) / _cell, (_grille.end.y - pos.y) / _cell))
			if i >= 0:
				a = ConstructionLibre.retirer_tole(a, i)
				_son()
				_maj()
			return
		var b := ConstructionLibre.poser_tole(a, q0, q1)
		if b.is_empty():
			_dire("Une tôle part du véhicule ou d'une autre tôle.")
		else:
			a = b
			_son()
			_maj(true)
		return
	if onglet == "chassis" and _rect0.x > -99:
		var sorte: String = outil.chassis
		var b := a
		for x in range(mini(_rect0.x, _rect1.x), maxi(_rect0.x, _rect1.x) + 1):
			for y in range(mini(_rect0.y, _rect1.y), maxi(_rect0.y, _rect1.y) + 1):
				b = ConstructionLibre.peindre(b, Vector2i(x, y), sorte)
		_rect0 = Vector2i(-99, -99)
		if b != a:
			a = b
			_son()
		_maj(true)
		return
	if not _essieu_tenu.is_empty():
		var et := _essieu_tenu
		_essieu_tenu = {}
		if _dans_grille(pos):
			var c := _case(pos)
			var b := ConstructionLibre.poser_essieu(a, c.x, String(et.piece), String(et.get("train", "")), c.y)
			if not b.is_empty():
				if String(et.get("liaison", "")) != "":
					var bl := ConstructionLibre.relier(b, c.x, String(et.liaison))
					b = bl if not bl.is_empty() else b
				a = b
				_son()
			else:
				_dire("Pas de châssis au-dessus : essieu retiré.")
		else:
			_dire("Essieu retiré.")
		_maj(true)
		return
	if _glisse == "":
		return
	if not Assemblage.piece(_glisse).get("famille", "") in ConstructionLibre.FAMILLES_PIECES:   # roue tenue au doigt
		if _dans_grille(pos):
			_monter_roue(_case(pos).x)
		_glisse = ""
		return
	if not _dans_grille(pos):
		_dire("%s retiré." % Assemblage.piece(_glisse).get("nom", "Pièce"))
	else:
		var b := ConstructionLibre.poser(a, _glisse, _cible(pos, _glisse), _miroir and _est_coque(_glisse), _extra)
		if b.is_empty():
			_dire("Pas de place ni d'appui ici.")
		else:
			a = b
			_son()
	_glisse = ""
	_maj(true)


func _monter_roue(x: int) -> void:
	var b := ConstructionLibre.monter_train(a, x, outil.roues)
	if b.is_empty():
		_dire("Posez d'abord un essieu ici.")
		return
	a = b
	_son()
	_maj()


# Case visée par la pièce tenue : centrée sur le doigt, un peu au-dessus pour rester visible
func _cible(pos: Vector2, id: String) -> Vector2i:
	var e: Array = _extra.get("emprise", Assemblage.piece(id).emprise)
	var p := pos - Vector2(0, DECALAGE_DOIGT * _cell)
	return Vector2i(_vue.position.x + int(floor((p.x - _grille.position.x) / _cell - float(e[0]) * 0.5 + 0.5)),
		int(floor((_grille.end.y - p.y) / _cell - float(e[1]) * 0.5 + 0.5)))


func _candidat() -> Dictionary:
	if _glisse == "" or not _dans_grille(_doigt):
		return {}
	if not Assemblage.piece(_glisse).get("famille", "") in ConstructionLibre.FAMILLES_PIECES:
		return {}
	return ConstructionLibre.poser(a, _glisse, _cible(_doigt, _glisse), _miroir and _est_coque(_glisse), _extra)


func _prendre(i: int) -> void:   # pièce posée reprise au doigt : la relâcher ailleurs la déplace, hors de la grille la retire
	_glisse = String(a.pieces[i].piece)
	_miroir = bool(a.pieces[i].get("miroir", false))
	_extra = {}
	for k in ["coupe", "emprise", "lot"]:
		if a.pieces[i].has(k):
			_extra[k] = a.pieces[i][k]
	a = ConstructionLibre.retirer(a, i)
	_an = ConstructionLibre.analyser(a)
	_placer_apercu(_candidat())


func _tenir(id: String) -> void:   # pièce prise dans le tiroir
	_glisse = id
	_extra = {}


func _charger_plan(plan: Dictionary) -> void:
	var r := PlansGrille.adapter(plan.a, _palette)
	a = r.a
	a.nom_choisi = true
	_dire("Plan chargé." if r.manquantes.is_empty() else "Absent de la réserve : " + ", ".join(r.manquantes))
	_maj(true)


# Bac à sable (DEC-080) : partir d'un vrai véhicule du jeu
func _charger_vehicule(type: String) -> void:
	var h := Assemblage.de_type(type)
	if h.is_empty():
		return
	a = ConstructionLibre.convertir(h, type)
	a.nom_choisi = true
	_dire("%s : modifiez-le librement." % String(a.nom))
	_maj(true)


# Transforme la grille en remorque : moteurs et radiateurs démontés, timon posé à l'avant (DEC-080)
func _en_remorque() -> void:
	a = ConstructionLibre.en_remorque(a)
	_dire("Remorque : elle sera tirée par le véhicule devant elle dans le convoi.")
	_maj(true)


func _basculer_ecorche() -> void:
	_ecorche = not _ecorche
	_placer_apercu()


func _est_coque(id: String) -> bool:
	return Assemblage.piece(id).get("famille", "") == "coque"


func _son() -> void:
	var so := get_node_or_null("/root/Son")
	if so:
		so.effet("sfx_atelier", -6.0)


func _quitter() -> void:
	_effacer_brouillon()
	ferme.emit(false)
	queue_free()


func _terminer() -> void:
	if not _peut_construire():
		var errs: Array = _an.get("erreurs", [])
		_dire(String(errs[0].texte) if not errs.is_empty() else "Pas assez de métal.")
		return
	var manque := ConstructionLibre.tireurs_requis(a) - ConstructionLibre.roles_de(a).count("tireur")
	if manque > 0 and not _confirmer:
		_confirmer = true
		_dire("%d arme%s sans tireur. Touchez encore la coche pour construire." % [manque, "s" if manque > 1 else ""])
		_choisir_onglet("equipage")
		return
	if m.construire_grille(uid, a):
		_effacer_brouillon()
		ferme.emit(true)
		queue_free()
	else:
		_dire(m.journal[-1].txt if not m.journal.is_empty() else "Impossible de construire.")


func _dire(t: String) -> void:
	_message = t
	_msg_t = 3.5


# --- Nom ----------------------------------------------------------------------------------------
func _renommer() -> void:
	if OS.has_feature("web"):
		var r = JavaScriptBridge.eval("prompt('Nom du véhicule', %s)" % JSON.stringify(String(a.get("nom", ""))), true)
		if typeof(r) == TYPE_STRING:
			_nommer(String(r))
		return
	var champ := LineEdit.new()
	champ.text = String(a.get("nom", ""))
	champ.add_theme_font_size_override("font_size", 26)
	champ.position = _rect_nom.position
	champ.size = _rect_nom.size
	add_child(champ)
	champ.grab_focus()
	champ.select_all()
	champ.text_submitted.connect(func(t):
		_nommer(t)
		champ.queue_free())
	champ.focus_exited.connect(func():
		if is_instance_valid(champ):
			champ.queue_free())


func _nommer(t: String) -> void:
	t = t.strip_edges().left(40)
	if t == "":   # nom vidé : on revient au nom proposé
		a.erase("nom_choisi")
	else:
		a.nom = t
		a.nom_choisi = true
	_maj()


# --- Brouillon (la page web peut se recharger : on ne perd pas sa construction) ----------------
func _ecrire_brouillon() -> void:
	var f := FileAccess.open(BROUILLON, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"uid": uid, "bac": m.bac_a_sable, "a": a}))


func _lire_brouillon() -> Dictionary:
	if not FileAccess.file_exists(BROUILLON):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(BROUILLON))
	if typeof(d) != TYPE_DICTIONARY or int(d.get("uid", -1)) != uid or bool(d.get("bac", false)) != m.bac_a_sable:
		return {}
	var b: Dictionary = d.get("a", {})
	if not ConstructionLibre.est_libre(b):
		return {}
	return PlansGrille.normaliser(b)


func _effacer_brouillon() -> void:
	if FileAccess.file_exists(BROUILLON):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BROUILLON))


# --- Contenu du tiroir ------------------------------------------------------------------------
# Vignette : {id, titre, n (-1 = sans compte), actif, choisi, action, mini: Callable(c, rect)} ; ligne : {ligne: true, titre, detail, …}
func _items() -> Array:
	var res := []
	match onglet:
		"chassis":
			for s in [["tube", "Tubes"], ["poutre", "Poutres"], ["acier", "Acier"], ["blindage", "Blindage"], ["", "Gomme"]]:
				var sorte: String = s[0]
				res.append({"titre": s[1], "choisi": outil.chassis == sorte, "action": func(): outil.chassis = sorte,
					"mini": func(c, r): _mini_case(c, r, sorte)})
		"essieux":
			for id in _famille("essieu"):
				var f := Assemblage.piece(id)
				res.append({"titre": _court(f.nom), "detail": "%.1f t" % (float(f.charge_kg) / 1000.0), "choisi": outil.essieux == id,
					"action": func(): outil.essieux = id, "mini": func(c, r): _mini_essieu(c, r, bool(f.get("pont", false)))})
		"roues":
			for id in _famille("train"):
				var f := Assemblage.piece(id)
				res.append({"titre": _court(f.nom), "choisi": outil.roues == id, "action": func():
					outil.roues = id
					_tenir(id), "mini": func(c, r): _mini_roue(c, r, id)})
			res.append({"titre": "Démonter", "choisi": outil.roues == "", "action": func(): outil.roues = "",
				"mini": func(c, r): _mini_icone(c, r, "croix", C_ROUGE)})
		"suspension":
			for id in _famille("liaison"):
				var f := Assemblage.piece(id)
				res.append({"titre": _court(f.nom), "detail": "%d-%d cm" % [int(f.hauteur_min) * 25, int(f.hauteur_max) * 25], "choisi": outil.suspension == id,
					"action": func(): outil.suspension = id, "mini": func(c, r): _mini_liaison(c, r, String(f.get("dessin", "lames")))})
			res.append({"titre": "Détacher", "choisi": outil.suspension == "", "action": func(): outil.suspension = "",
				"mini": func(c, r): _mini_icone(c, r, "croix", C_ROUGE)})
		"toles":
			var n_t: int = a.get("toles", []).size()
			res.append({"ligne": true, "titre": "%d tôle%s" % [n_t, "s" if n_t > 1 else ""], "detail": "inclinée = plus épaisse ; fermée = caisse blindée", "actif": false})
			res.append({"ligne": true, "titre": "Toucher une tôle", "detail": "la retire", "actif": false})
			res.append({"ligne": true, "titre": "Tout retirer", "detail": "enlève toutes les tôles", "actif": n_t > 0, "action": func():
				a.toles = []
				_maj()})
		"peinture":
			for pe in PEINTURES:
				var hex: String = pe[0]
				res.append({"titre": pe[1], "choisi": String(a.get("peinture", "")) == hex, "action": func():
					if hex == "":
						a.erase("peinture")
					else:
						a.peinture = hex
					_maj(), "mini": func(c, r): _mini_couleur(c, r, hex)})
		"plans":   # plans enregistrés (DEC-071)
			var nom := String(a.get("nom", "Plan"))
			res.append({"ligne": true, "titre": "Enregistrer « %s »" % nom, "detail": "remplace un plan du même nom",
				"actif": not a.get("cases", []).is_empty(), "action": func():
					PlansGrille.enregistrer(a)
					_dire("Plan « %s » enregistré." % nom)})
			res.append({"ligne": true, "titre": "Supprimer : %s" % ("oui, touchez un plan" if _suppr_plans else "non"), "detail": "", "choisi": _suppr_plans,
				"action": func(): _suppr_plans = not _suppr_plans})
			for pl in PlansGrille.lire():
				var plan: Dictionary = pl
				res.append({"ligne": true, "titre": String(plan.nom), "detail": "%d cases · %d pièces" % [plan.a.get("cases", []).size(), plan.a.get("pieces", []).size()],
					"action": func():
						if _suppr_plans:
							PlansGrille.supprimer(String(plan.nom))
							_dire("Plan supprimé.")
						else:
							_charger_plan(plan)})
		"vehicules":   # remorque ; véhicules du jeu en bac à sable (DEC-080)
			res.append({"ligne": true, "titre": "Remorque : %s" % ("oui" if ConstructionLibre.remorque(a) else "non"),
				"detail": "démonte moteurs et radiateurs, pose un timon", "choisi": ConstructionLibre.remorque(a), "action": func():
					if ConstructionLibre.remorque(a):
						a.erase("remorque")
						_maj()
					else:
						_en_remorque()})
			if m.bac_a_sable:
				res.append({"ligne": true, "titre": "Grille vide", "detail": "repartir de zéro", "action": func():
					a = ConstructionLibre.nouvelle()
					_maj(true)})
				for type in VehiculeDessin.donnees().vehicules:
					if Assemblage.de_type(type).is_empty():
						continue
					var t: String = type
					res.append({"ligne": true, "titre": String(VehiculeDessin.donnees().vehicules[t].nom), "detail": "véhicule du jeu", "action": func(): _charger_vehicule(t)})
		"equipage":
			var sieges := ConstructionLibre.sieges_equipage(a)
			if sieges.is_empty():
				res.append({"ligne": true, "titre": "Aucun siège", "detail": "posez un poste", "actif": false})
			for i in sieges.size():
				var s: Dictionary = sieges[i]
				var k: int = s.k
				var r: String = s.role
				res.append({"ligne": true, "titre": "%d · %s" % [i + 1, NOMS_ROLES[r]], "detail": AIDE_ROLES[r] + (" · fixe" if s.fixe else ""),
					"actif": not s.fixe, "action": func(): _changer_role(k)})
			var nt := ConstructionLibre.places_troupes(a)
			if nt > 0:
				res.append({"ligne": true, "titre": "Bancs : %d soldat%s" % [nt, "s" if nt > 1 else ""], "detail": "débarquables en combat", "actif": false})
		_:
			if onglet == "coque":   # réglages du plan carrosserie (DEC-067)
				res.append({"titre": "Retourner", "choisi": _miroir, "action": func(): _miroir = not _miroir,
					"mini": func(c, r): _mini_icone(c, r, "retourner", C_TEXTE)})
				res.append({"titre": {"": "Scie", "v": "Scie |", "h": "Scie —"}[_scie], "choisi": _scie != "",
					"action": func(): _scie = {"": "v", "v": "h", "h": ""}[_scie], "mini": func(c, r): _mini_icone(c, r, "scie", C_TEXTE)})
				res.append({"titre": "Écorché", "choisi": _ecorche, "action": _basculer_ecorche,
					"mini": func(c, r): _mini_icone(c, r, "oeil", C_TEXTE)})
			for it in _palette:
				var f := Assemblage.piece(it.id)
				var fam := String(f.get("famille", ""))
				var ici := fam == onglet or (onglet == "poste" and fam == "cabine") or (onglet == "equipement" and fam == "greffe") or (onglet == "moteur" and fam == "radiateur")
				if not ici:
					continue
				var reste := _restant(it.id, int(it.n))
				var id: String = it.id
				var det := ""
				match fam:
					"moteur": det = "%d ch" % int(f.puissance_ch)
					"radiateur": det = "%d ch" % int(f.refroidit_ch)
				res.append({"titre": _court(f.nom), "detail": det, "n": reste, "actif": reste != 0, "choisi": _glisse == id,
					"action": func(): _tenir(id), "mini": func(c, r): _mini_piece(c, r, id)})
			if res.is_empty():
				res.append({"ligne": true, "titre": "Rien en réserve", "detail": "fouillez des épaves", "actif": false})
	return res


static func _court(t: String) -> String:   # nom tenant sur une vignette
	return t if t.length() <= 16 else t.left(15) + "…"


func _changer_role(k: int) -> void:   # k : rang parmi les sièges libres (a.roles)
	if k < 0:
		return
	var roles: Array = a.get("roles", []).duplicate()
	while roles.size() <= k:
		roles.append("tireur")
	var j := ConstructionLibre.ROLES.find(String(roles[k]))
	roles[k] = ConstructionLibre.ROLES[(j + 1) % ConstructionLibre.ROLES.size()]
	a.roles = roles
	_maj()


# --- Dessin -----------------------------------------------------------------------------------
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), C_FOND)
	if FOND_GRILLE != null:   # fond d'atelier (grange), recadré pour couvrir l'écran
		var ts := FOND_GRILLE.get_size()
		var k: float = maxf(size.x / ts.x, size.y / ts.y)
		draw_texture_rect(FOND_GRILLE, Rect2((size - ts * k) * 0.5, ts * k), false)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(_grille.position - Vector2(8, 8), _grille.size + Vector2(16, 16 + 2.2 * _cell)), Color(C_ZONE, 0.55))
	for i in _vue.size.x + 1:
		draw_line(_grille.position + Vector2(i * _cell, 0), _grille.position + Vector2(i * _cell, _grille.size.y), C_GRILLE, 1.0)
	for j in _vue.size.y + 1:
		draw_line(_grille.position + Vector2(0, j * _cell), _grille.position + Vector2(_grille.size.x, j * _cell), C_GRILLE, 1.0)
	draw_rect(_grille, C_CADRE, false, 2.0)


# Au-dessus du dessin du véhicule : repères, pièce tenue, tracés en cours, nom, barre d'icônes, tiroir, bilan
func _dessiner_dessus() -> void:
	var c := _dessus
	var police := get_theme_default_font()
	_cartes.clear()
	var det: Dictionary = _an.get("detail", {})
	if det.has("sol"):
		c.draw_line(_px(_vue.position.x, det.sol), _px(_vue.end.x, det.sol), C_SOL, 3.0)
	for p in a.get("pieces", []):   # contour léger des pièces posées (pour les reprendre au doigt)
		var e: Array = p.get("emprise", Assemblage.piece(String(p.piece)).emprise)
		c.draw_rect(Rect2(_px(int(p.pos[0]), int(p.pos[1]) + int(e[1])), Vector2(int(e[0]), int(e[1])) * _cell), Color(1, 1, 1, 0.14), false, 1.5)
	for e in ConstructionLibre.essieux_nus(a):   # essieux sans roue : un moyeu nu à monter
		var ctr := _px(int(e.x) + 0.5, ConstructionLibre.y_essieu(a, int(e.x)))
		c.draw_circle(ctr, _cell * 0.28, Color("#C9C6BC"))
		c.draw_arc(ctr, _cell * 0.9, 0, TAU, 24, Color(C_ACCENT, 0.8), 2.0)
	for d in det.get("essieux", []):   # charge sous chaque essieu
		var ctr := _px(float(d.x) + 0.5, float(d.y) - float(d.r))
		if d.has("charge") and float(d.charge) > float(d.capacite):
			c.draw_string(police, ctr + Vector2(-60, 26), "%.1f/%.0f t" % [float(d.charge) / 1000.0, float(d.capacite) / 1000.0], HORIZONTAL_ALIGNMENT_CENTER, 120, 16, C_ROUGE)
		elif not d.get("touche", true):
			c.draw_string(police, ctr + Vector2(-60, 26), "en l'air", HORIZONTAL_ALIGNMENT_CENTER, 120, 18, C_ROUGE)
	if det.has("cg"):
		var cg := _px(det.cg.x, det.cg.y)
		c.draw_circle(cg, 9.0, Color(1, 1, 1, 0.9))
		c.draw_line(cg - Vector2(12, 0), cg + Vector2(12, 0), Color.BLACK, 2.0)
		c.draw_line(cg - Vector2(0, 12), cg + Vector2(0, 12), Color.BLACK, 2.0)
	if onglet == "chassis" and _rect0.x > -99:   # rectangle de châssis en cours
		var x0 := mini(_rect0.x, _rect1.x)
		var r := Rect2(_px(x0, maxi(_rect0.y, _rect1.y) + 1), Vector2(absi(_rect1.x - _rect0.x) + 1, absi(_rect1.y - _rect0.y) + 1) * _cell)
		c.draw_rect(r, Color(C_ROUGE, 0.25) if outil.chassis == "" else Color(C_ACCENT, 0.3))
		c.draw_rect(r, C_ACCENT, false, 3.0)
		c.draw_string(police, r.position + Vector2(6, -10), "%.2f × %.2f m" % [r.size.x / _cell * ConstructionLibre.C, r.size.y / _cell * ConstructionLibre.C], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, C_TEXTE)
	if onglet == "toles":   # coins où accrocher une tôle, et tôle en cours avec son angle
		for x in range(_vue.position.x, _vue.end.x + 1):
			for y in range(0, _vue.size.y + 1):
				if ConstructionLibre.coin_accroche(a, Vector2i(x, y)):
					c.draw_circle(_px(x, y), 3.5, Color(C_ACCENT, 0.7))
		if _tole0.x > -99:
			var pa := _px(_tole0.x, _tole0.y)
			var pb := _px(_tole1.x, _tole1.y)
			c.draw_line(pa, pb, C_ACCENT, maxf(4.0, _cell * 0.22))
			c.draw_circle(pa, 7.0, C_ACCENT)
			if _tole1 != _tole0:
				var dd := Vector2(_tole1 - _tole0).abs()
				var ang := int(round(rad_to_deg(atan2(dd.x, dd.y))))   # 0° : verticale
				c.draw_string(police, pb + Vector2(12, -12), "%d°" % ang, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, C_TEXTE)
	# Pièce tenue : cadre vert (posable) ou rouge (non)
	if _glisse != "" and Assemblage.piece(_glisse).get("famille", "") in ConstructionLibre.FAMILLES_PIECES and _dans_grille(_doigt):
		var e: Array = _extra.get("emprise", Assemblage.piece(_glisse).emprise)
		var q := _cible(_doigt, _glisse)
		var ok := not _candidat().is_empty()
		var r := Rect2(_px(q.x, q.y + int(e[1])), Vector2(int(e[0]), int(e[1])) * _cell)
		if not ok:
			c.draw_rect(r, Color(C_ROUGE, 0.35))
		c.draw_rect(r, C_VERT if ok else C_ROUGE, false, 3.0)
	elif _glisse != "" and _appui:
		var r := Rect2(_doigt - Vector2(44, 88), Vector2(88, 88))
		_mini_piece_ou_roue(c, r, _glisse)
	# Nom (touchez pour renommer) et message
	c.draw_rect(_rect_nom, Color(0, 0, 0, 0.35))
	c.draw_string(police, _rect_nom.position + Vector2(12, 31), "✎ " + String(a.get("nom", "Véhicule")) + ("   ·   remorque" if ConstructionLibre.remorque(a) else ""),
		HORIZONTAL_ALIGNMENT_LEFT, _rect_nom.size.x - 20, 22, C_TEXTE)
	_cartes.append({"rect": _rect_nom, "action": _renommer, "actif": true})
	if _msg_t > 0.0:
		var mr := Rect2(Vector2(_grille.position.x, _rect_nom.end.y + 6), Vector2(_tiroir.position.x - _grille.position.x - 16.0, 36))
		c.draw_rect(mr, Color(0, 0, 0, 0.6))
		c.draw_string(police, mr.position + Vector2(12, 26), _message, HORIZONTAL_ALIGNMENT_LEFT, mr.size.x - 20, 20, C_ACCENT)
	_dessiner_rail(c, police)
	_dessiner_tiroir(c, police)
	_dessiner_bilan(c, police)


func _dessiner_rail(c: Control, police: Font) -> void:
	var ic := (_rail.size.x - 8.0) * 0.5
	var ids: Array = ACTIONS.duplicate()
	for o in ONGLETS:
		ids.append(o[0])
	for i in ids.size():
		var id: String = ids[i]
		var r := Rect2(_rail.position + Vector2((i % 2) * (ic + 8.0), (i / 2) * (ic + 8.0)), Vector2(ic, ic))
		var choisi := id == onglet
		var actif := id != "valider" or _peut_construire()
		var fond := C_TUILE
		if id == "valider":
			fond = Color(0.16, 0.32, 0.18, 0.9) if actif else Color(0.15, 0.15, 0.15, 0.7)
		elif id == "quitter":
			fond = Color(0.35, 0.14, 0.12, 0.9)
		c.draw_rect(r, fond)
		c.draw_rect(r, C_ACCENT if choisi else Color(1, 1, 1, 0.15), false, 3.0 if choisi else 1.0)
		_icone(c, r.grow(-ic * 0.16), id, C_TEXTE if actif else C_DISCRET)
		var act: Callable
		match id:
			"valider": act = _terminer
			"quitter": act = _quitter
			_: act = func(): _choisir_onglet(id)
		_cartes.append({"rect": r, "action": act, "actif": true})


func _dessiner_tiroir(c: Control, police: Font) -> void:
	var T := _tiroir
	c.draw_rect(T, Color(0.05, 0.05, 0.05, 0.55))
	var titre := ""
	for o in ONGLETS:
		if o[0] == onglet:
			titre = o[1]
	c.draw_string(police, T.position + Vector2(12, 34), titre, HORIZONTAL_ALIGNMENT_LEFT, T.size.x - 20, 28, C_ACCENT)
	c.draw_string(police, T.position + Vector2(12, 60), String(AIDES.get(onglet, "")), HORIZONTAL_ALIGNMENT_LEFT, T.size.x - 20, 17, C_DISCRET)
	var items := _items()
	var y0 := T.position.y + 76.0
	var bas := T.end.y - 64.0
	var cols := 3
	var tw := (T.size.x - 16.0 - (cols - 1) * 8.0) / cols
	var th := tw + 30.0
	# Mise en page de toutes les cartes, puis la page affichée
	var pages := [[]]
	var x := 0
	var y := y0
	for it in items:
		var h: float = 70.0 if it.get("ligne", false) else th
		if it.get("ligne", false) and x > 0:
			x = 0
			y += th + 8.0
		if y + h > bas:
			pages.append([])
			x = 0
			y = y0
		var w: float = T.size.x - 16.0 if it.get("ligne", false) else tw
		pages.back().append({"it": it, "r": Rect2(T.position + Vector2(8.0 + x * (tw + 8.0), y - T.position.y), Vector2(w, h))})
		if it.get("ligne", false):
			y += h + 8.0
		else:
			x += 1
			if x >= cols:
				x = 0
				y += th + 8.0
	_page = clampi(_page, 0, pages.size() - 1)
	for q in pages[_page]:
		var it: Dictionary = q.it
		var r: Rect2 = q.r
		var actif: bool = it.get("actif", true)
		var choisi: bool = it.get("choisi", false)
		c.draw_rect(r, C_TUILE if actif else Color(C_TUILE, 0.4))
		c.draw_rect(r, C_ACCENT if choisi else Color(1, 1, 1, 0.15), false, 3.0 if choisi else 1.0)
		if it.get("ligne", false):
			c.draw_string(police, r.position + Vector2(12, 30), String(it.titre), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 21, C_TEXTE if actif else C_DISCRET)
			c.draw_string(police, r.position + Vector2(12, 56), String(it.get("detail", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 15, C_DISCRET)
		else:
			var mr := Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, r.size.x - 12))
			if it.has("mini"):
				it.mini.call(c, mr)
			c.draw_string(police, Vector2(r.position.x + 4, r.end.y - 8), String(it.titre), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 14, C_TEXTE if actif else C_DISCRET)
			var n: int = it.get("n", -1)
			if n >= 0:
				c.draw_string(police, r.position + Vector2(r.size.x - 34, 20), "×%d" % n, HORIZONTAL_ALIGNMENT_RIGHT, 30, 16, C_ACCENT if n > 0 else C_ROUGE)
			if String(it.get("detail", "")) != "":
				c.draw_string(police, r.position + Vector2(6, 18), String(it.detail), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40, 13, C_DISCRET)
		if it.has("action"):
			_cartes.append({"rect": r, "action": it.action, "actif": actif})
	if pages.size() > 1:   # pages du tiroir
		var bw := (T.size.x - 24.0) * 0.5
		var rh := Rect2(Vector2(T.position.x + 8, T.end.y - 56), Vector2(bw, 48))
		var rb := Rect2(Vector2(rh.end.x + 8, T.end.y - 56), Vector2(bw, 48))
		for z in [[rh, "▲", _page > 0, func(): _page -= 1], [rb, "▼", _page < pages.size() - 1, func(): _page += 1]]:
			c.draw_rect(z[0], C_TUILE if z[2] else Color(C_TUILE, 0.3))
			c.draw_string(police, z[0].position + Vector2(0, 34), z[1], HORIZONTAL_ALIGNMENT_CENTER, z[0].size.x, 24, C_TEXTE if z[2] else C_DISCRET)
			_cartes.append({"rect": z[0], "action": z[3], "actif": z[2]})


func _dessiner_bilan(c: Control, police: Font) -> void:
	var x := _grille.position.x
	var lw := _tiroir.position.x - x - 24.0
	var y := size.y - float(_mg.get("b", 20.0)) - 40.0
	if not _an.get("ok", false):
		var errs: Array = _an.get("erreurs", [])
		if not errs.is_empty():
			c.draw_string(police, Vector2(x, y), "✗ " + String(errs[0].texte), HORIZONTAL_ALIGNMENT_LEFT, lw, 20, C_ROUGE)
		return
	var s: Dictionary = _an.stats
	var roule := float(s.vitesse) > 0.0
	c.draw_string(police, Vector2(x, y), ("▶ %.1f m/s" % s.vitesse) if roule else "■ immobile", HORIZONTAL_ALIGNMENT_LEFT, 170, 22, C_VERT if roule else C_ROUGE)
	var ligne := "%d kg   ·   blindage %d   ·   %d place%s" % [int(s.poids_kg), int(s.blindage), int(s.equipage), "s" if int(s.equipage) > 1 else ""]
	var cout: float = m.cout_grille(uid, a)
	if cout > 0.0:
		ligne += "   ·   %d / %d métal" % [int(ceil(cout)), int(m.stocks.metal)]
	c.draw_string(police, Vector2(x + 180, y), ligne, HORIZONTAL_ALIGNMENT_LEFT, lw - 180, 18, C_DISCRET)
	var defauts: Array = _an.defauts
	if not defauts.is_empty():
		var d: Dictionary = defauts[0]
		for q in defauts:
			if q.grave:
				d = q
				break
		c.draw_string(police, Vector2(x, y + 28), "• " + String(d.texte) + ("  (+%d)" % (defauts.size() - 1) if defauts.size() > 1 else ""), HORIZONTAL_ALIGNMENT_LEFT, lw, 17, C_ROUGE if d.grave else C_ACCENT)


# --- Icônes et miniatures (dessinées : aucune image à produire) --------------------------------
func _icone(c: Control, r: Rect2, id: String, col: Color) -> void:
	var w := r.size.x
	var o := r.position
	var ep := maxf(2.0, w * 0.07)
	match id:
		"valider":
			c.draw_polyline(PackedVector2Array([o + Vector2(w * 0.1, w * 0.55), o + Vector2(w * 0.4, w * 0.85), o + Vector2(w * 0.92, w * 0.18)]), C_VERT.lightened(0.2), ep * 1.6)
		"quitter":
			_mini_icone(c, r, "croix", Color("#F0A090"))
		"chassis":
			for i in 3:
				for j in 2:
					c.draw_rect(Rect2(o + Vector2(w * (0.05 + 0.31 * i), w * (0.3 + 0.24 * j)), Vector2(w * 0.27, w * 0.2)), col.darkened(0.2))
		"essieux":
			_mini_essieu(c, r, false)
		"roues":
			_tex_dans(c, r, VehiculeDessin._tex("roue_grande"))
		"suspension":   # ressort entre deux coupelles
			c.draw_rect(Rect2(o + Vector2(w * 0.2, w * 0.08), Vector2(w * 0.6, w * 0.08)), col)
			c.draw_rect(Rect2(o + Vector2(w * 0.2, w * 0.84), Vector2(w * 0.6, w * 0.08)), col)
			var zz := PackedVector2Array()
			for k in 9:
				zz.append(o + Vector2(w * (0.3 if k % 2 == 0 else 0.7), w * (0.16 + 0.085 * k)))
			c.draw_polyline(zz, Color("#C07A4A"), ep)
		"moteur":
			_tex_dans(c, r, VehiculeDessin._tex("moteur_moyen"))
		"poste":
			_mini_piece(c, r, "poste_conduite")
		"coque":
			_tex_dans(c, r, VehiculeDessin._tex("coques/coque_berline"))
		"toles":
			c.draw_line(o + Vector2(w * 0.15, w * 0.9), o + Vector2(w * 0.75, w * 0.1), Color("#6E7550"), ep * 2.2)
			for k in 3:
				c.draw_circle(o + Vector2(w * (0.27 + 0.2 * k), w * (0.74 - 0.27 * k)), ep * 0.45, Color("#C8C8B0"))
		"arme":
			_tex_dans(c, r, VehiculeDessin._tex("arme_mitrailleuse"))
		"equipement":
			_mini_piece(c, r, "greffe_pare_buffle")
		"equipage":
			c.draw_circle(o + Vector2(w * 0.5, w * 0.42), w * 0.18, Color("#D9A57A"))
			c.draw_rect(Rect2(o + Vector2(w * 0.28, w * 0.18), Vector2(w * 0.44, w * 0.14)), Color("#5E6238"))
			c.draw_rect(Rect2(o + Vector2(w * 0.25, w * 0.62), Vector2(w * 0.5, w * 0.3)), Color("#5E6238"))
		"peinture":
			var pc := Color(String(a.get("peinture", "#B0623A")))
			c.draw_circle(o + Vector2(w * 0.5, w * 0.6), w * 0.28, pc)
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.5, w * 0.08), o + Vector2(w * 0.25, w * 0.5), o + Vector2(w * 0.75, w * 0.5)]), pc)
		"plans":
			c.draw_rect(Rect2(o + Vector2(w * 0.15, w * 0.08), Vector2(w * 0.7, w * 0.84)), Color("#3E5C7A"))
			for k in 4:
				c.draw_line(o + Vector2(w * 0.25, w * (0.25 + 0.17 * k)), o + Vector2(w * 0.75, w * (0.25 + 0.17 * k)), Color("#C8D8E8"), 2.0)
		"vehicules":
			_tex_dans(c, r, VehiculeDessin._tex("vehicules/willys_mb"))


func _mini_icone(c: Control, r: Rect2, id: String, col: Color) -> void:
	var w := r.size.x
	var o := r.position
	var ep := maxf(2.0, w * 0.08)
	match id:
		"croix":
			c.draw_line(o + Vector2(w * 0.2, w * 0.2), o + Vector2(w * 0.8, w * 0.8), col, ep * 1.4)
			c.draw_line(o + Vector2(w * 0.8, w * 0.2), o + Vector2(w * 0.2, w * 0.8), col, ep * 1.4)
		"retourner":
			c.draw_line(o + Vector2(w * 0.15, w * 0.35), o + Vector2(w * 0.85, w * 0.35), col, ep)
			c.draw_line(o + Vector2(w * 0.7, w * 0.2), o + Vector2(w * 0.85, w * 0.35), col, ep)
			c.draw_line(o + Vector2(w * 0.15, w * 0.65), o + Vector2(w * 0.85, w * 0.65), col, ep)
			c.draw_line(o + Vector2(w * 0.3, w * 0.8), o + Vector2(w * 0.15, w * 0.65), col, ep)
		"scie":
			c.draw_rect(Rect2(o + Vector2(w * 0.1, w * 0.3), Vector2(w * 0.65, w * 0.25)), Color("#B9B2A0"))
			var pts := PackedVector2Array()
			for k in 9:
				pts.append(o + Vector2(w * (0.1 + 0.08 * k), w * (0.55 + (0.08 if k % 2 == 0 else 0.0))))
			c.draw_polyline(pts, Color("#B9B2A0"), ep * 0.6)
			c.draw_rect(Rect2(o + Vector2(w * 0.72, w * 0.22), Vector2(w * 0.18, w * 0.42)), Color("#6D5032"))
		"oeil":
			c.draw_arc(o + Vector2(w * 0.5, w * 0.75), w * 0.45, -PI * 0.85, -PI * 0.15, 16, col, ep * 0.6)
			c.draw_arc(o + Vector2(w * 0.5, w * 0.25), w * 0.45, PI * 0.15, PI * 0.85, 16, col, ep * 0.6)
			c.draw_circle(o + Vector2(w * 0.5, w * 0.5), w * 0.12, col)


func _tex_dans(c: Control, r: Rect2, t: Texture2D) -> void:   # texture contenue dans r, centrée
	if t == null:
		return
	var k := minf(r.size.x / t.get_size().x, r.size.y / t.get_size().y)
	var s := t.get_size() * k
	c.draw_texture_rect(t, Rect2(r.position + (r.size - s) * 0.5, s), false)


func _mini_case(c: Control, r: Rect2, sorte: String) -> void:
	var o := r.position + r.size * 0.15
	var s := r.size.x * 0.7
	var h := s * 0.5
	match sorte:
		"":
			_mini_icone(c, r, "croix", C_ROUGE)
		"tube":
			for k in 2:
				var x0 := o.x + k * h
				c.draw_rect(Rect2(Vector2(x0, o.y + h * 0.5), Vector2(h, h)), Color("#8A8A80"), false, 2.0)
				c.draw_line(Vector2(x0, o.y + h * 1.5), Vector2(x0 + h, o.y + h * 0.5), Color("#8A8A80"), 2.0)
		"poutre":
			c.draw_rect(Rect2(Vector2(o.x, o.y + h * 0.5), Vector2(s, h * 0.18)), Color("#5A5A52"))
			c.draw_rect(Rect2(Vector2(o.x, o.y + h * 0.68), Vector2(s, h * 0.64)), Color("#3A3A34"))
			c.draw_rect(Rect2(Vector2(o.x, o.y + h * 1.32), Vector2(s, h * 0.18)), Color("#5A5A52"))
		_:
			var col := Color("#4C5236") if sorte == "blindage" else Color("#77736A")
			for k in 2:
				c.draw_rect(Rect2(Vector2(o.x + k * h, o.y + h * 0.5), Vector2(h - 3, h - 3)), col)


func _mini_essieu(c: Control, r: Rect2, pont: bool) -> void:
	var w := r.size.x
	var o := r.position
	c.draw_line(o + Vector2(w * 0.1, w * 0.5), o + Vector2(w * 0.9, w * 0.5), Color("#8C867A"), w * 0.08)
	for x in [0.15, 0.85]:
		c.draw_circle(o + Vector2(w * x, w * 0.5), w * 0.1, Color("#C9C6BC"))
	if pont:
		c.draw_circle(o + Vector2(w * 0.5, w * 0.5), w * 0.16, Color("#3C3C3A"))


func _mini_roue(c: Control, r: Rect2, id: String) -> void:
	var f := Assemblage.piece(id)
	if String(f.get("type", "")) == "chenilles":
		var o := r.position + Vector2(0, r.size.y * 0.3)
		var rr := Rect2(o + Vector2(r.size.x * 0.05, 0), Vector2(r.size.x * 0.9, r.size.y * 0.4))
		c.draw_rect(rr, Color("#1E1D1B"))
		for k in 4:
			c.draw_circle(rr.position + Vector2(rr.size.x * (0.14 + 0.24 * k), rr.size.y * 0.5), rr.size.y * 0.32, Color("#5A5650"))
		return
	var d := float(f.get("diametre_cases", 2))
	var k := clampf(d / 8.0, 0.35, 1.0)   # une grande roue paraît grande
	var s := r.size * k
	var t := VehiculeDessin._tex("roue_petite" if d < 2.5 else ("roue_moyenne" if d < 4.0 else "roue_grande"))
	c.draw_texture_rect(t, Rect2(r.position + Vector2((r.size.x - s.x) * 0.5, r.size.y - s.y), s), false)


func _mini_liaison(c: Control, r: Rect2, dessin: String) -> void:
	var formes := []
	ConstructionLibre._formes_liaison(formes, dessin, 0.65, 1.0, 0.35, true)
	_mini_formes(c, r, formes, Rect2(0.0, 0.1, 2.2, 1.0))


func _mini_couleur(c: Control, r: Rect2, hex: String) -> void:
	if hex == "":
		c.draw_rect(r.grow(-r.size.x * 0.15), Color("#77736A"), false, 3.0)
		_mini_icone(c, r.grow(-r.size.x * 0.2), "croix", C_DISCRET)
		return
	c.draw_rect(r.grow(-r.size.x * 0.12), Color(hex))
	c.draw_rect(r.grow(-r.size.x * 0.12), Color(1, 1, 1, 0.3), false, 2.0)


func _mini_piece_ou_roue(c: Control, r: Rect2, id: String) -> void:
	if Assemblage.piece(id).get("famille", "") in ConstructionLibre.FAMILLES_PIECES:
		_mini_piece(c, r, id)
	else:
		_mini_roue(c, r, id)


# Miniature du vrai dessin d'une pièce : la pièce seule passée par ConstructionLibre.forme (mise en cache)
func _mini_piece(c: Control, r: Rect2, id: String) -> void:
	var f := Assemblage.piece(id)
	if f.get("famille", "") == "arme":
		var w := String(f.arme)
		var sid := "arme_mortier" if w == "mortier" else ("arme_lance_flammes" if w == "lance_flammes" else ("arme_mitrailleuse" if w.begins_with("mitrailleuse") else ("arme_canon_37" if w.contains("leger") else ("arme_canon_88" if w.contains("88") else "arme_canon_75"))))
		_tex_dans(c, r, VehiculeDessin._tex(sid))
		return
	if not _minis.has(id):
		var seule := {"libre": true, "nom": "", "cases": [], "essieux": [], "pieces": [{"piece": id, "pos": [0, 0]}]}
		_minis[id] = ConstructionLibre.forme(seule).formes
	var e: Array = f.get("emprise", [1, 1])
	_mini_formes(c, r, _minis[id], Rect2(0.0, 0.0, float(e[0]) * ConstructionLibre.C, float(e[1]) * ConstructionLibre.C))


# Dessine des formes (mètres, y vers le haut) contenues dans `bornes`, centrées dans r
func _mini_formes(c: Control, r: Rect2, formes: Array, bornes: Rect2) -> void:
	var k := minf(r.size.x / maxf(0.01, bornes.size.x), r.size.y / maxf(0.01, bornes.size.y))
	var off := r.position + Vector2((r.size.x - bornes.size.x * k) * 0.5, r.size.y - (r.size.y - bornes.size.y * k) * 0.5)
	var P := func(q) -> Vector2: return off + Vector2((float(q[0]) - bornes.position.x) * k, -(float(q[1]) - bornes.position.y) * k)
	var teinte := Color(String(a.get("peinture", "#5E6238")))
	for z in [-1, 0, 1, 2, 3]:
		for fo in formes:
			if int(fo.get("z", 1)) != z:
				continue
			var col := _coul(String(fo.get("c", "caisse")), teinte)
			if fo.has("pts"):
				var pts := PackedVector2Array()
				for q in fo.pts:
					pts.append(P.call(q))
				if pts.size() >= 3:
					c.draw_colored_polygon(pts, col)
			elif fo.has("ligne"):
				c.draw_line(P.call(fo.ligne[0]), P.call(fo.ligne[1]), col, maxf(1.5, float(fo.get("ep", 0.04)) * k))
			elif fo.has("sprite"):
				var q: Array = fo.r
				var t := VehiculeDessin._tex(String(fo.sprite))
				var hg: Vector2 = P.call([q[0], float(q[1]) + float(q[3])])
				var dst := Rect2(hg, Vector2(float(q[2]), float(q[3])) * k)
				if bool(fo.get("miroir", false)):
					dst = Rect2(hg + Vector2(dst.size.x, 0), Vector2(-dst.size.x, dst.size.y))
				var uv: Array = fo.get("uv", [])
				if uv.size() == 4:
					var ts := t.get_size()
					c.draw_texture_rect_region(t, dst, Rect2(float(uv[0]) * ts.x, float(uv[1]) * ts.y, (float(uv[2]) - float(uv[0])) * ts.x, (float(uv[3]) - float(uv[1])) * ts.y))
				else:
					c.draw_texture_rect(t, dst, false)


static func _coul(nom: String, teinte: Color) -> Color:
	match nom:
		"caisse": return teinte
		"sombre": return teinte.darkened(0.38)
		"clair": return teinte.lightened(0.18)
		"vitre": return Color("#2E3A40")
		"metal": return Color("#3C3C3A")
		"pneu": return Color("#1E1D1B")
		"bois": return Color("#6D5032")
		"toile": return Color("#8A8460")
	return Color(nom)

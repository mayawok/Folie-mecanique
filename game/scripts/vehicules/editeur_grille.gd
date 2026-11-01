# Grille de construction libre (DEC-043), refaite pour l'iPhone (DEC-056 à DEC-058) :
# - grille agrandie et centrée entre les marges sûres (Dynamic Island, coins), fenêtre ajustée au véhicule ;
# - éléments classés par catégorie (onglets), dans l'ordre de construction, l'équipage en dernier ;
# - châssis tracé en rectangles (glisser d'un coin à l'autre) au lieu d'être peint case par case ;
# - essieu posé d'abord, roue ou chenille montée ensuite dessus ;
# - le vrai dessin du véhicule s'affiche sur la grille, y compris la pièce qu'on glisse ;
# - nom proposé d'après la construction, modifiable ; brouillon gardé si la page se recharge.
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
const COULEURS := {"moteur": Color("#A8552F"), "cabine": Color("#5E6238"), "poste": Color("#6E5A3A"), "arme": Color("#9A2F2F"), "equipement": Color("#8A7A3A"), "coque": Color("#7A6A55")}
const ONGLETS := [["chassis", "Châssis"], ["essieux", "Essieux"], ["roues", "Roues"], ["moteur", "Moteurs"],
	["poste", "Postes"], ["suspension", "Suspension"], ["coque", "Carrosserie"], ["arme", "Armes"], ["equipement", "Options"], ["equipage", "Équipage"]]
# Essieux, roues et liaisons : lus dans le catalogue par famille (ajouter un modèle = une entrée dans pieces.json)
static func _famille(fam: String) -> Array:
	var res: Array = Assemblage.catalogue().pieces.keys().filter(func(id): return Assemblage.piece(id).get("famille", "") == fam and not Assemblage.piece(id).get("retire", false))
	res.sort_custom(func(p, q): return float(Assemblage.piece(p).get("charge_kg", 0)) < float(Assemblage.piece(q).get("charge_kg", 0)))
	return res
const NOMS_ROLES := {"conducteur": "Conducteur", "tireur": "Tireur", "chargeur": "Chargeur", "chef": "Chef de char",
	"mecanicien": "Mécanicien", "infirmier": "Infirmier", "passager": "Passager"}
const AIDE_ROLES := {"conducteur": "obligatoire", "tireur": "1 canon + 1 mitrailleuse coaxiale, ou 1 arme",
	"chargeur": "recharge plus vite", "chef": "précision +10 %", "mecanicien": "répare plus vite", "infirmier": "soigne l'équipage",
	"passager": "aucun rôle"}
const BROUILLON := "user://grille_brouillon.json"
const CARTE_H := 84.0
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
var _extra := {}
var _essieu_tenu := {}       # essieu repris au doigt : lâché hors de la grille, il est retiré (DEC-076)            # morceau scié tenu au doigt : coupe, emprise, lot
var _ecorche := false       # vue écorchée forcée dans l'onglet Carrosserie
var _rect0 := Vector2i(-99, -99)   # coin de départ du rectangle de châssis
var _rect1 := Vector2i(-99, -99)
var _appui := false
var _doigt := Vector2.ZERO
var _vue := Rect2i(8, 0, 24, 10)   # fenêtre de la grille affichée (en cases)
var _grille := Rect2()
var _cell := 40.0
var _panneau := Rect2()
var _mg := {}
var _page := 0
var _cartes: Array = []     # [{rect, action, id, actif}]
var _an := {}
var _message := ""
var _msg_t := 0.0
var _confirmer := false     # armes sans tireur : deuxième appui sur Construire pour confirmer
var _onglets: Array = []
var _btn_ok: Button
var _btn_annuler: Button
var _btn_nom: Button
var _btn_plans: Button
var _btn_haut: Button
var _btn_bas: Button
var _apercu: VehiculeDessin
var _dessus: Control


func ouvrir(modele, vehicule_uid: int) -> void:
	m = modele
	uid = vehicule_uid
	a = m.grille_de(uid)
	_palette = m.palette_grille(uid)
	var b := _lire_brouillon()
	if not b.is_empty():
		a = b
		_dire("Brouillon repris là où vous l'aviez laissé.")


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
	for o in ONGLETS:
		var id: String = o[0]
		_onglets.append(_bouton(o[1], func(): _choisir_onglet(id)))
	_btn_nom = _bouton("", _renommer)
	_btn_nom.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_btn_ok = _bouton("Construire", _terminer)
	_btn_plans = _bouton("Plans", func(): _choisir_onglet("plans"))
	_btn_annuler = _bouton("Annuler", func():
		_effacer_brouillon()
		ferme.emit(false)
		queue_free())
	_btn_haut = _bouton("▲", func(): _page = maxi(0, _page - 1))
	_btn_bas = _bouton("▼", func(): _page += 1)
	resized.connect(_disposer)
	_maj(true)


func _bouton(texte: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(action)
	add_child(b)
	return b


func _choisir_onglet(id: String) -> void:
	onglet = id
	_scie = ""
	_page = 0
	_glisse = ""
	_disposer()


# --- Mise en page : marges sûres, panneau à droite, grille centrée dans le reste ------------
func _disposer() -> void:
	if size.x < 10.0:
		return
	_mg = ZonesSures.marges(size)
	var g: float = _mg.g
	var d: float = size.x - _mg.d
	var haut := 16.0 + float(_mg.h)
	var bas := size.y - float(_mg.b)
	var pw := clampf(size.x * 0.27, 420.0, 620.0)
	_panneau = Rect2(Vector2(d - pw, haut + 84.0), Vector2(pw, bas - haut - 84.0))
	# Barre du haut : nom à gauche, Annuler et Construire à droite
	var x := d
	for b in [_btn_ok, _btn_annuler, _btn_plans]:
		b.custom_minimum_size = Vector2(0, 68)
		b.reset_size()
		b.size.x = maxf(b.size.x, 190.0)
		x -= b.size.x
		b.position = Vector2(x, haut)
		x -= 14.0
	_btn_plans.modulate = C_ACCENT if onglet == "plans" else Color.WHITE
	_btn_nom.position = Vector2(g, haut)
	_btn_nom.custom_minimum_size = Vector2(0, 68)
	_btn_nom.size = Vector2(maxf(200.0, x - g - 20.0), 68)
	# Onglets : deux rangées de cinq en haut du panneau
	var tw := (_panneau.size.x - 4 * 8.0) / 5.0
	for i in _onglets.size():
		var b: Button = _onglets[i]
		b.custom_minimum_size = Vector2(tw, 64)
		b.size = Vector2(tw, 64)
		b.position = _panneau.position + Vector2((i % 5) * (tw + 8.0), (i / 5) * 72.0)
		b.add_theme_font_size_override("font_size", 17)
		b.modulate = C_ACCENT if ONGLETS[i][0] == onglet else Color.WHITE
	for b in [_btn_haut, _btn_bas]:
		b.custom_minimum_size = Vector2(96, 64)
		b.size = Vector2(96, 64)
	_btn_bas.position = Vector2(_panneau.end.x - 96.0, _panneau.end.y - 64.0)
	_btn_haut.position = Vector2(_panneau.end.x - 200.0, _panneau.end.y - 64.0)
	# Grille : tout l'espace à gauche du panneau, sous la barre, au-dessus du bilan
	var zone := Rect2(Vector2(g, haut + 84.0), Vector2(_panneau.position.x - 24.0 - g, bas - haut - 84.0 - 120.0))
	var sous_sol := 2.2   # place pour les roues sous la ligne 0
	_cell = floorf(minf(zone.size.x / float(_vue.size.x), zone.size.y / (float(_vue.size.y) + sous_sol)))
	var taille := Vector2(_vue.size) * _cell
	_grille = Rect2(zone.position + Vector2((zone.size.x - taille.x) * 0.5, (zone.size.y - taille.y - sous_sol * _cell) * 0.5), taille)
	_placer_apercu()
	queue_redraw()
	_dessus.queue_redraw()


# Fenêtre affichée : le véhicule et une marge autour, au moins `grille_vue_min` cases (24 × 10)
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
		var e: Array = Assemblage.piece(String(p.piece)).emprise
		x0 = mini(x0, int(p.pos[0]))
		x1 = maxi(x1, int(p.pos[0]) + int(e[0]))
		y1 = maxi(y1, int(p.pos[1]) + int(e[1]))
	if x1 <= x0:
		x0 = G.x / 2
		x1 = x0
	var w := clampi(x1 - x0 + 8, int(mini_v[0]), G.x)
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
	_btn_nom.text = "✎  " + String(a.get("nom", "Véhicule")) + ("  ·  bac à sable" if m.bac_a_sable else "")
	_ecrire_brouillon()
	_disposer()


func _placer_apercu(b := {}) -> void:
	var source: Dictionary = a if b.is_empty() else b
	if source.get("cases", []).is_empty():
		_apercu.visible = false
		return
	var F := ConstructionLibre.forme(source, _ecorche or not onglet in ["coque", "equipage"])   # coques transparentes quand on règle la mécanique
	_apercu.ppm = _cell / ConstructionLibre.C
	_apercu.configurer_d(F)
	_apercu.visible = true
	_apercu.position = _px(float(F.x0), float(F.sol)) - Vector2(0, _apercu.size.y)


func _process(delta: float) -> void:
	if m == null:
		return
	_msg_t = maxf(0.0, _msg_t - delta)
	_btn_ok.disabled = not _an.get("ok", false) or (not m.bac_a_sable and m.stocks.metal < m.cout_grille(uid, a))
	_btn_haut.disabled = _page <= 0
	_dessus.queue_redraw()


func _restant(id: String, n: int) -> int:
	if n < 0:
		return -1
	return n - ConstructionLibre.utilisees(a, id)


func _case(pos: Vector2) -> Vector2i:
	return Vector2i(_vue.position.x + int(floor((pos.x - _grille.position.x) / _cell)), int(floor((_grille.end.y - pos.y) / _cell)))


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
		if _glisse != "":
			_placer_apercu(_candidat())
		accept_event()


func _appuyer(cell: Vector2i) -> void:
	if onglet in ["essieux", "roues", "suspension", "equipage"]:   # une pièce posée se reprend au doigt depuis n'importe quel onglet (DEC-076)
		var ip := ConstructionLibre.piece_en(a, cell)
		if ip >= 0:
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
			var b := ConstructionLibre.poser_essieu(a, cell.x, outil.essieux, String(ex.get("train", "")), cell.y)
			if b.is_empty():
				_dire("Tracez d'abord le châssis au-dessus de cette colonne.")
				return
			a = b
			if Assemblage.piece(outil.essieux).get("pont", false):
				_dire("Pont placé à %d cm sous le châssis : reliez-le dans l'onglet Suspension." % (ConstructionLibre.ecart_pont(a, ConstructionLibre.essieu_en(a, cell.x)) * 25))
			_son()
			_maj()
		"roues":
			_monter_roue(cell.x)
		"suspension":
			var ex := ConstructionLibre.essieu_en(a, cell.x)
			if ex.is_empty() or not Assemblage.piece(String(ex.piece)).get("pont", false):
				_dire("Posez d'abord un pont rigide sous cette colonne (onglet Essieux), en l'air sous le châssis.")
				return
			var lid: String = outil.suspension
			var b := ConstructionLibre.relier(a, cell.x, lid)
			if b.is_empty():   # la liaison choisie ne couvre pas l'écart : on prend celle qui convient
				var h := ConstructionLibre.ecart_pont(a, ex)
				var ok_ids := ConstructionLibre.liaisons_pour(h)
				if ok_ids.is_empty():
					_dire("Pont trop loin du châssis (%d cm) : remontez-le (onglet Essieux)." % (h * 25))
					return
				lid = ok_ids[0]
				b = ConstructionLibre.relier(a, cell.x, lid)
				_dire("À %d cm du châssis, il faut : %s." % [h * 25, Assemblage.piece(lid).nom])
			a = b
			_son()
			_maj(true)
		"equipage":
			pass
		_:
			var i := ConstructionLibre.piece_en(a, cell, onglet == "coque")
			if i >= 0 and onglet == "coque" and _scie != "":
				var bs := ConstructionLibre.scier(a, i, cell, _scie)
				if bs.is_empty():
					_dire("Touchez l'intérieur de la coque, pas son bord : le trait passe par la case touchée.")
				else:
					a = bs
					_son()
					_maj()
				return
			if i >= 0:   # une pièce posée se reprend au doigt pour la déplacer
				_prendre(i)


func _relacher(pos: Vector2) -> void:
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
	if onglet == "roues" and not Assemblage.piece(_glisse).get("famille", "") in ConstructionLibre.FAMILLES_PIECES:
		if _dans_grille(pos):
			_monter_roue(_case(pos).x)
		_glisse = ""
		return
	if not _dans_grille(pos):
		_dire("%s retiré de la grille." % Assemblage.piece(_glisse).get("nom", "Pièce"))
	if _dans_grille(pos):
		var b := ConstructionLibre.poser(a, _glisse, _cible(pos, _glisse), _miroir and _est_coque(_glisse), _extra)
		if b.is_empty():
			_dire("%s doit reposer sur le châssis ou une autre pièce, sans chevaucher : rendue au bac." % Assemblage.piece(_glisse).nom)
		else:
			a = b
			_son()
	_glisse = ""
	_maj(true)


func _monter_roue(x: int) -> void:
	var b := ConstructionLibre.monter_train(a, x, outil.roues)
	if b.is_empty():
		_dire("Posez d'abord un essieu sous cette colonne (onglet Essieux).")
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


func _prendre(i: int) -> void:   # pièce posée reprise au doigt : la relâcher hors de la grille la retire
	_glisse = String(a.pieces[i].piece)
	_miroir = bool(a.pieces[i].get("miroir", false))
	_extra = {}
	for k in ["coupe", "emprise", "lot"]:
		if a.pieces[i].has(k):
			_extra[k] = a.pieces[i][k]
	a = ConstructionLibre.retirer(a, i)
	_an = ConstructionLibre.analyser(a)
	_placer_apercu(_candidat())


func _charger_plan(plan: Dictionary) -> void:
	var r := PlansGrille.adapter(plan.a, _palette)
	a = r.a
	a.nom_choisi = true
	_dire("Plan chargé." if r.manquantes.is_empty() else "Plan chargé ; absent de la réserve : " + ", ".join(r.manquantes))
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


func _terminer() -> void:
	var manque := ConstructionLibre.tireurs_requis(a) - ConstructionLibre.roles_de(a).count("tireur")
	if manque > 0 and not _confirmer:
		_confirmer = true
		_btn_ok.text = "Construire quand même"
		_dire("Attention : %d arme%s sans tireur ne tirer%s pas. Onglet Équipage, ou appuyez encore pour construire." % [manque, "s" if manque > 1 else "", "ont" if manque > 1 else "a"])
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
	_msg_t = 4.0


# --- Nom ----------------------------------------------------------------------------------------
func _renommer() -> void:
	if OS.has_feature("web"):
		var r = JavaScriptBridge.eval("prompt('Nom du véhicule', %s)" % JSON.stringify(String(a.get("nom", ""))), true)
		if typeof(r) == TYPE_STRING:
			_nommer(String(r))
		return
	var champ := LineEdit.new()
	champ.text = String(a.get("nom", ""))
	champ.add_theme_font_size_override("font_size", 28)
	champ.position = _btn_nom.position
	champ.size = _btn_nom.size
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


# --- Panneau des catégories -----------------------------------------------------------------
func _items() -> Array:   # [{titre, detail, id, actif, choisi, action, couleur}]
	var res := []
	match onglet:
		"chassis":
			for s in [["tube", "Tubes", "très léger et rapide, fragile, sans blindage"], ["acier", "Acier", "léger, peu protégé"], ["blindage", "Blindage", "lourd, blindage 45"], ["", "Gomme", "effacer des cases"]]:
				var sorte: String = s[0]
				res.append({"titre": s[1], "detail": "Glisser d'un coin à l'autre : " + s[2], "choisi": outil.chassis == sorte,
					"action": func(): outil.chassis = sorte, "couleur": Color("#8A8A80") if sorte == "tube" else Color("#77736A") if sorte == "acier" else (Color("#4C5236") if sorte == "blindage" else Color("#333"))})
			res.append({"titre": "+ plaque de blindage", "detail": "à l'avant (%d posée%s)" % [int(a.get("plaques", 0)), "s" if int(a.get("plaques", 0)) > 1 else ""],
				"action": func(): _plaque(1), "couleur": Color("#4C5236")})
			res.append({"titre": "− plaque de blindage", "detail": "retirer une plaque", "action": func(): _plaque(-1), "couleur": Color("#333")})
		"essieux":
			for id in _famille("essieu"):
				var f := Assemblage.piece(id)
				res.append({"titre": f.nom, "detail": "%d kg max%s · touchez une colonne (retouchez pour retirer)" % [int(f.charge_kg), " · à relier (onglet Suspension)" if f.get("pont", false) else ""],
					"choisi": outil.essieux == id, "action": func(): outil.essieux = id, "couleur": Color("#6B6A64")})
		"roues":
			for id in _famille("train"):
				var f := Assemblage.piece(id)
				res.append({"titre": String(f.nom), "detail": "%d kg max · %.1f m/s max · touchez un essieu" % [int(f.charge_kg), float(f.get("vitesse_max", 0))],
					"choisi": outil.roues == id, "action": func():
						outil.roues = id
						_glisse = id, "couleur": Color("#3E3C37")})
			res.append({"titre": "Démonter la roue", "detail": "touchez un essieu pour lui retirer sa roue", "choisi": outil.roues == "",
				"action": func(): outil.roues = "", "couleur": Color("#333")})
		"plans":   # plans enregistrés (DEC-071)
			var nom := String(a.get("nom", "Plan"))
			res.append({"titre": "Enregistrer « %s »" % nom, "detail": "remplace un plan du même nom ; renommez en haut à gauche pour en garder plusieurs",
				"actif": not a.get("cases", []).is_empty(), "action": func():
					PlansGrille.enregistrer(a)
					_dire("Plan « %s » enregistré." % nom), "couleur": Color("#4A6A4A")})
			for pl in PlansGrille.lire():
				var plan: Dictionary = pl
				res.append({"titre": "Charger : " + String(plan.nom), "detail": "%d cases · %d pièces · remplace la grille en cours" % [plan.a.get("cases", []).size(), plan.a.get("pieces", []).size()],
					"action": func(): _charger_plan(plan), "couleur": Color("#4A4A4A")})
				res.append({"titre": "Supprimer : " + String(plan.nom), "detail": "efface ce plan",
					"action": func():
						PlansGrille.supprimer(String(plan.nom))
						_disposer(), "couleur": Color("#3A2A2A")})
		"suspension":
			for id in _famille("liaison"):
				var f := Assemblage.piece(id)
				res.append({"titre": f.nom, "detail": "de %d à %d cm sous le châssis · %d kg max · débattement %d %% · touchez un pont" % [int(f.hauteur_min) * 25, int(f.hauteur_max) * 25, int(f.charge_kg), int(float(f.debattement) * 100)],
					"choisi": outil.suspension == id, "action": func(): outil.suspension = id, "couleur": Color("#5A5040")})
			res.append({"titre": "Détacher", "detail": "touchez un pont pour retirer sa liaison", "choisi": outil.suspension == "",
				"action": func(): outil.suspension = "", "couleur": Color("#333")})
		"equipage":
			var sieges := ConstructionLibre.sieges_equipage(a)
			if sieges.is_empty():
				res.append({"titre": "Aucun siège", "detail": "posez un poste (onglet Postes)", "actif": false, "couleur": Color("#333")})
			for i in sieges.size():
				var s: Dictionary = sieges[i]
				var k: int = s.k
				var r: String = s.role
				res.append({"titre": "Siège %d : %s" % [i + 1, NOMS_ROLES[r]], "detail": AIDE_ROLES[r] + (" · poste fixe" if s.fixe else ""),
					"actif": not s.fixe, "action": func(): _changer_role(k), "couleur": Color("#5E6238")})
			var nt := ConstructionLibre.places_troupes(a)
			if nt > 0:
				res.append({"titre": "Bancs : %d soldat%s" % [nt, "s" if nt > 1 else ""], "detail": "embarqués depuis la réserve, débarquables en combat",
					"actif": false, "couleur": Color("#6E5A3A")})
		_:
			if onglet == "coque":   # réglages du plan carrosserie (DEC-067)
				res.append({"titre": "Retourner : avant vers la %s" % ("gauche" if _miroir else "droite"),
					"detail": "s'applique à la prochaine coque posée ; reprenez une coque pour la retourner", "actif": true,
					"action": func(): _miroir = not _miroir, "couleur": Color("#4A4A4A")})
				res.append({"titre": "Scie : %s" % {"": "rangée", "v": "trait vertical", "h": "trait horizontal"}[_scie],
					"detail": "touchez une coque pour la couper en deux à cet endroit ; reprenez un morceau pour l'enlever", "actif": true,
					"action": func(): _scie = {"": "v", "v": "h", "h": ""}[_scie], "couleur": Color("#6A3A2A")})
				res.append({"titre": "Vue écorchée : %s" % ("oui" if _ecorche else "non"),
					"detail": "coques transparentes pour voir la mécanique dessous", "actif": true,
					"action": _basculer_ecorche, "couleur": Color("#4A4A4A")})
			for it in _palette:
				var f := Assemblage.piece(it.id)
				if f.get("famille", "") != onglet and not (onglet == "poste" and f.get("famille", "") == "cabine"):   # sièges d'origine (stock) rangés avec les postes
					continue
				var reste := _restant(it.id, int(it.n))
				var detail := ""
				match f.famille:
					"moteur": detail = "%d ch" % int(f.puissance_ch)
					"cabine": detail = "%d place%s%s" % [int(f.sieges), "s" if int(f.sieges) > 1 else "", ", ouverte" if f.ouvert else ""]
					"arme": detail = String(CombatModele.donnees().armes[f.arme].nom)
					"equipement": detail = "prend %.1f ch au moteur" % float(f.get("puissance_ch", 0))
					"coque": detail = "blindage %d%s" % [int(f.get("blindage", 0)), ", abrite l'équipage" if f.get("couvert", false) else ", ouverte"]
				var id: String = it.id
				res.append({"titre": "%s%s" % [f.nom, "" if reste < 0 else "  ×%d" % reste], "id": id,
					"detail": "%s · %d×%d cases · %d kg · glissez sur la grille" % [detail, int(f.emprise[0]), int(f.emprise[1]), int(f.get("poids_kg", 0))],
					"actif": reste != 0, "choisi": _glisse == id, "action": func():
						_glisse = id
						_extra = {}, "couleur": COULEURS.get(f.famille, Color("#555"))})
			if res.is_empty():
				res.append({"titre": "Rien en réserve", "detail": "fouillez des épaves ou démontez un véhicule", "actif": false, "couleur": Color("#333")})
	return res


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


func _plaque(d: int) -> void:
	a.plaques = maxi(0, int(a.get("plaques", 0)) + d)
	_maj()


# --- Dessin -----------------------------------------------------------------------------------
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), C_FOND)
	if FOND_GRILLE != null:   # fond d'atelier (grange), recadré pour couvrir l'écran
		var ts := FOND_GRILLE.get_size()
		var k: float = maxf(size.x / ts.x, size.y / ts.y)
		var r := Rect2((size - ts * k) * 0.5, ts * k)
		draw_texture_rect(FOND_GRILLE, r, false)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(_grille.position - Vector2(8, 8), _grille.size + Vector2(16, 16 + 2.2 * _cell)), Color(C_ZONE, 0.55))
	for i in _vue.size.x + 1:
		draw_line(_grille.position + Vector2(i * _cell, 0), _grille.position + Vector2(i * _cell, _grille.size.y), C_GRILLE, 1.0)
	for j in _vue.size.y + 1:
		draw_line(_grille.position + Vector2(0, j * _cell), _grille.position + Vector2(_grille.size.x, j * _cell), C_GRILLE, 1.0)
	draw_rect(_grille, C_CADRE, false, 2.0)


# Au-dessus du dessin du véhicule : repères, pièce tenue, rectangle tracé, panneau, bilan
func _dessiner_dessus() -> void:
	var c := _dessus
	var police := get_theme_default_font()
	var det: Dictionary = _an.get("detail", {})
	if det.has("sol"):
		c.draw_line(_px(_vue.position.x, det.sol), _px(_vue.end.x, det.sol), C_SOL, 3.0)
	# Contour léger des pièces posées (pour les reprendre au doigt)
	for p in a.get("pieces", []):
		var e: Array = Assemblage.piece(String(p.piece)).emprise
		var r := Rect2(_px(int(p.pos[0]), int(p.pos[1]) + int(e[1])), Vector2(int(e[0]), int(e[1])) * _cell)
		c.draw_rect(r, Color(1, 1, 1, 0.18), false, 1.5)
	# Essieux sans roue : un moyeu nu à monter
	for e in ConstructionLibre.essieux_nus(a):
		var ctr := _px(int(e.x) + 0.5, ConstructionLibre.y_essieu(a, int(e.x)))
		c.draw_circle(ctr, _cell * 0.28, Color("#C9C6BC"))
		c.draw_arc(ctr, _cell * 0.9, 0, TAU, 24, Color(C_ACCENT, 0.8), 2.0)
	# Charge sous chaque essieu
	for d in det.get("essieux", []):
		var ctr := _px(float(d.x) + 0.5, float(d.y) - float(d.r))
		if d.has("charge"):
			var sur: bool = float(d.charge) > float(d.capacite)
			c.draw_string(police, ctr + Vector2(-60, 26), "%.1f/%.0f t" % [float(d.charge) / 1000.0, float(d.capacite) / 1000.0], HORIZONTAL_ALIGNMENT_CENTER, 120, 16, C_ROUGE if sur else C_DISCRET)
		elif not d.get("touche", true):
			c.draw_string(police, ctr + Vector2(-60, 26), "en l'air", HORIZONTAL_ALIGNMENT_CENTER, 120, 18, C_ROUGE)
	if det.has("cg"):
		var cg := _px(det.cg.x, det.cg.y)
		c.draw_circle(cg, 9.0, Color(1, 1, 1, 0.9))
		c.draw_line(cg - Vector2(12, 0), cg + Vector2(12, 0), Color.BLACK, 2.0)
		c.draw_line(cg - Vector2(0, 12), cg + Vector2(0, 12), Color.BLACK, 2.0)
	# Rectangle de châssis en cours
	if onglet == "chassis" and _rect0.x > -99:
		var x0 := mini(_rect0.x, _rect1.x)
		var r := Rect2(_px(x0, maxi(_rect0.y, _rect1.y) + 1), Vector2(absi(_rect1.x - _rect0.x) + 1, absi(_rect1.y - _rect0.y) + 1) * _cell)
		c.draw_rect(r, Color(C_ROUGE, 0.25) if outil.chassis == "" else Color(C_ACCENT, 0.3))
		c.draw_rect(r, C_ACCENT, false, 3.0)
		c.draw_string(police, r.position + Vector2(6, -10), "%d × %d cases (%.2f × %.2f m)" % [int(r.size.x / _cell), int(r.size.y / _cell),
			r.size.x / _cell * ConstructionLibre.C, r.size.y / _cell * ConstructionLibre.C], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, C_TEXTE)
	# Pièce tenue : son vrai dessin est déjà sur la grille ; ici le cadre vert (posable) ou rouge (non)
	if _glisse != "" and onglet != "roues" and _dans_grille(_doigt):
		var e: Array = Assemblage.piece(_glisse).emprise
		var q := _cible(_doigt, _glisse)
		var ok := not _candidat().is_empty()
		var r := Rect2(_px(q.x, q.y + int(e[1])), Vector2(int(e[0]), int(e[1])) * _cell)
		if not ok:
			c.draw_rect(r, Color(C_ROUGE, 0.35))
		c.draw_rect(r, C_VERT if ok else C_ROUGE, false, 3.0)
	elif _glisse != "" and _appui:
		var f := Assemblage.piece(_glisse)
		c.draw_string(police, _doigt + Vector2(-80, -40), String(f.nom), HORIZONTAL_ALIGNMENT_CENTER, 160, 22, C_ACCENT)
	# Aide ou message, sous la barre du haut
	var aides := {"chassis": "Glissez d'un coin à l'autre pour tracer un rectangle de châssis.",
		"essieux": "Touchez une colonne : un essieu simple se fixe sous le châssis ; un pont rigide se place en l'air, à la hauteur touchée. Reprenez un essieu pour le déplacer, glissez-le hors de la grille pour le retirer.",
		"roues": "Choisissez une roue ou une chenille, puis touchez (ou glissez sur) un essieu.",
		"plans": "Enregistrez la grille en cours ou chargez un plan : les pièces absentes de la réserve sont laissées de côté.",
		"suspension": "Touchez un pont placé en l'air : la liaison relie le châssis au pont (lames jusqu'à 25 cm, tirants 25 à 75 cm, grands tirants 75 cm à 1,5 m).",
		"poste": "Poste de conduite, de commande ou banc de troupes (face avant ou arrière) : fabriqués en métal.",
		"cabine": "Une cabine se pose par-dessus les sièges : camion, voiture, blindée… (décor).",
		"equipage": "Les postes de conduite et de commande sont fixes. Touchez un autre siège pour changer son rôle."}
	var txt: String = _message if _msg_t > 0.0 else String(aides.get(onglet, "Glissez une pièce sur la grille. Touchez une pièce posée pour la déplacer."))
	c.draw_string(police, Vector2(_grille.position.x, _grille.position.y - 18), txt, HORIZONTAL_ALIGNMENT_LEFT, _panneau.position.x - _grille.position.x - 20.0,
		22, C_ACCENT if _msg_t > 0.0 else C_DISCRET)
	_dessiner_panneau(c, police)
	_dessiner_bilan(c, police)


func _dessiner_panneau(c: Control, police: Font) -> void:
	_cartes.clear()
	var items := _items()
	var y0 := _panneau.position.y + 152.0
	var place := int((_panneau.end.y - 76.0 - y0) / (CARTE_H + 8.0))
	_page = clampi(_page, 0, maxi(0, (items.size() - 1) / maxi(1, place)))
	_btn_bas.disabled = (_page + 1) * place >= items.size()
	_btn_haut.visible = items.size() > place
	_btn_bas.visible = items.size() > place
	for k in range(_page * place, mini(items.size(), (_page + 1) * place)):
		var it: Dictionary = items[k]
		var actif: bool = it.get("actif", true)
		var r := Rect2(Vector2(_panneau.position.x, y0 + (k - _page * place) * (CARTE_H + 8.0)), Vector2(_panneau.size.x, CARTE_H))
		_cartes.append({"rect": r, "action": it.get("action", func(): pass), "actif": actif})
		var col: Color = it.get("couleur", Color("#555"))
		c.draw_rect(r, Color(col.r, col.g, col.b, 0.4 if actif else 0.12))
		c.draw_rect(r, C_ACCENT if it.get("choisi", false) else Color(1, 1, 1, 0.2), false, 3.0 if it.get("choisi", false) else 1.5)
		c.draw_string(police, r.position + Vector2(14, 34), String(it.titre), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24, 24, C_TEXTE if actif else C_DISCRET)
		c.draw_string(police, r.position + Vector2(14, 66), String(it.detail), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24, 17, C_DISCRET)


func _dessiner_bilan(c: Control, police: Font) -> void:
	var x := _grille.position.x
	var lw := _panneau.position.x - x - 24.0
	var y := size.y - float(_mg.get("b", 20.0)) - 96.0
	if not _an.get("ok", false):
		for d in _an.get("erreurs", []):
			c.draw_string(police, Vector2(x, y), "• " + String(d.texte), HORIZONTAL_ALIGNMENT_LEFT, lw, 22, C_ROUGE)
			y += 28
		return
	var s: Dictionary = _an.stats
	var det: Dictionary = _an.detail
	var roule := float(s.vitesse) > 0.0
	var tireurs := ConstructionLibre.roles_de(a).count("tireur")
	var requis := ConstructionLibre.tireurs_requis(a)
	c.draw_string(police, Vector2(x, y), ("Roule : %.1f m/s" % s.vitesse) if roule else "Ne roule pas", HORIZONTAL_ALIGNMENT_LEFT, 260, 24, C_VERT if roule else C_ROUGE)
	var ligne := "%d kg · %.0f ch/t · conso %.1f L/km · blindage %d · %d place%s · tireurs %d/%d" % [int(s.poids_kg), det.ch_t, float(s.conso) * 10.0,
		int(s.blindage), int(s.equipage), "s" if int(s.equipage) > 1 else "", tireurs, requis]
	var cout: float = m.cout_grille(uid, a)
	if cout > 0.0:
		ligne += " · coût %d métal (stock %d)" % [int(ceil(cout)), int(m.stocks.metal)]
	c.draw_string(police, Vector2(x + 270, y), ligne, HORIZONTAL_ALIGNMENT_LEFT, lw - 270, 19, C_ACCENT if tireurs < requis else C_DISCRET)
	y += 30
	for d in _an.defauts.slice(0, 3):
		c.draw_string(police, Vector2(x, y), "• " + String(d.texte), HORIZONTAL_ALIGNMENT_LEFT, lw, 19, C_ROUGE if d.grave else C_ACCENT)
		y += 24

# Désert procédural qui défile (menu principal, garage) : ciel, dunes lointaines
# en parallaxe, sol bosselé avec cailloux. Terrain.sol(x) donne le relief en mètres,
# lu aussi par les véhicules pour leurs suspensions.
class_name Terrain
extends Control

# Type de sol (Kit, DEC-110) : sable, terre, cailloux ou eau. sol, crête, cailloux de premier plan, trois couches lointaines
static var zone := "terre"
const PALETTES := {
	"sable": {"sol": "#A87A4A", "crete": "#8C6238", "trace": "#7E5A34", "couches": ["#C9A57A", "#BC925F", "#B08452"],
		"decor": [["poteau", 0.18], ["cactus", 0.38], ["arbre", 0.55], ["rocher", 0.78], ["carcasse", 0.86]]},
	"terre": {"sol": "#6E5A3C", "crete": "#4F5B2E", "trace": "#54452C", "couches": ["#8E8A66", "#7B7C55", "#69703F"],
			"decor": [["poteau", 0.08], ["herbe", 0.30], ["arbre", 0.40], ["rocher", 0.47], ["epave", 0.53], ["cloture", 0.57], ["muret", 0.61],
				["objet", 0.70], ["bat", 0.76], ["ruine", 0.79], ["clocher", 0.81], ["chateau_eau", 0.83]]},
		"cailloux": {"sol": "#7A7570", "crete": "#5C5853", "trace": "#5A5651", "couches": ["#A7A29A", "#928D86", "#7E7973"],
		"decor": [["poteau", 0.08], ["rocher", 0.80], ["carcasse", 0.88]]},
	"neige": {"sol": "#D9DEE3", "crete": "#B9C4CE", "trace": "#AEB8C2", "couches": ["#E4E9ED", "#CDD6DD", "#BCC7D0"],
		"decor": [["poteau", 0.15], ["rocher", 0.70], ["carcasse", 0.84]]},
	"boue": {"sol": "#4A3B2A", "crete": "#3B3A22", "trace": "#33291D", "couches": ["#7A735A", "#6A6A4A", "#5A5E3C"],
		"decor": [["poteau", 0.15], ["herbe", 0.40], ["rocher", 0.62], ["carcasse", 0.80]]},
	"eau": {"sol": "#4F6B73", "crete": "#9BBBC2", "trace": "#86A9B1", "couches": ["#9DB4BA", "#8AA3AA", "#738E96"],
		"decor": [["poteau", 0.20], ["roseau", 0.60], ["carcasse", 0.68]]},
}

# Images du décor « terre et herbe » (DEV-011) ; sans les fichiers, on retombe sur le dessin vectoriel.
# genre -> [fichier, hauteur réelle en m]
const ELEMENTS := {"poteau": ["poteau", 5.0], "herbe": ["buissons", 1.0], "arbre": ["arbre", 6.0], "rocher": ["rocher", 1.3],
	"cloture": ["cloture", 1.2], "muret": ["muret", 1.0], "ruine": ["ruine", 7.0], "clocher": ["clocher", 14.0], "chateau_eau": ["chateau_eau", 12.0]}
# groupes tirés au hasard : [fichier, hauteur réelle en m]
const GROUPES := {
	"epave": [["epave_panzer", 2.7], ["epave_b1", 2.8], ["epave_chasseur", 3.0], ["epave_bombardier", 4.0], ["epave_traction", 1.6], ["epave_camion", 2.8], ["epave_autocar", 3.0], ["epave_canon", 1.6]],
	"objet": [["obj_meule", 3.0], ["obj_charrette", 1.6], ["obj_tracteur", 2.2], ["obj_citerne", 2.5], ["obj_panneau", 3.0], ["obj_borne", 1.1], ["obj_bidons", 1.2], ["obj_wagon", 3.4], ["obj_reverbere", 4.0], ["obj_sacs", 1.2]],
	"bat": [["bat_ferme", 8.0], ["bat_grange", 8.0], ["bat_silo", 12.0], ["bat_moulin", 11.0], ["bat_pylone", 14.0], ["bat_pont", 7.0], ["bat_gare", 6.0], ["bat_bunker", 3.0]]}
# premier plan (passe devant les véhicules) : [fichier, hauteur réelle en m]
const AVANT := [["av_herbes", 1.4], ["av_ronce", 1.2], ["av_fougeres", 1.0], ["av_roseaux", 2.0], ["av_pierres", 0.5], ["av_pneu", 0.7], ["av_planches", 0.8], ["av_flaque", 0.25], ["av_squelette", 1.0]]
static var _tex := {}
# Voies de profondeur (DEC-250) : le bord de la route, côté fond, est BAS_COTE m au-dessus de la voie du milieu.
# Les voies elles-mêmes (décalages, tailles) sont dans le bloc « voies » de combat_proto.json ; ornières : DY_VOIES.
const BAS_COTE := 1.15
const DY_VOIES := [0.75, 0.0, -0.85]

var avant := false      # vrai : ce calque ne dessine que le premier plan, posé devant les véhicules
var soir := 0.0         # 0..1 : ciel de fin de journée
var orage := 0.0        # 0..1 : ciel d'orage
var camera_x := 0.0     # position du monde (m) au point d'ancrage
var ppm := 55.0
var sol_y := 900.0      # ligne du sol (px) pour une hauteur nulle
var nuit := 0.0         # 0 = plein jour, 1 = pleine nuit
var ancre_x := 0.0      # abscisse écran (px) qui correspond à camera_x


# Route lisse (DEC-229) : longues ondulations douces, pente de quelques degrés au plus (avant : jusqu'à 15°)
static func _base(x: float) -> float:
	return 1.3 * sin(x / 60.0) + 0.45 * sin(x / 23.0 + 1.0) + 0.06 * sin(x / 8.0 + 2.0)


static func relief(x: float) -> float:
	var h := _base(x) + crete(x)
	for p in plats:
		var w := _poids_plat(p, x)
		if w > 0.0:
			h = lerpf(h, float(p[2]), w)
	return h


# Relief de la route sans les crêtes : pente ressentie par le convoi (vitesse en côte) et hauteur suivie par la caméra
static func route(x: float) -> float:
	var h := _base(x)
	for p in plats:
		var w := _poids_plat(p, x)
		if w > 0.0:
			h = lerpf(h, float(p[2]), w)
	return h


# --- Crêtes (DEC-233, DEC-261) : bosses isolées, rampe douce puis lèvre et retombée, comme une dune et sa face sous le vent,
# un bourrelet de route soulevé ou la lèvre d'un cratère. Un véhicule rapide y décolle vraiment (CombatModele._vols).
# Placées par un pseudo-hasard stable (même x, même crête) ; fréquence selon le sol (data/transmission.json, bloc « cretes »).
static var _cr := {}

static func _cretes() -> Dictionary:
	if _cr.is_empty():
		_cr = Transmission.donnees().get("cretes", {"pas": 240.0, "proba": {}})
	return _cr


# Probabilité qu'une case de `pas` mètres porte une crête : selon la zone de décor, ou nulle sur route forcée (Kit)
static func proba_crete() -> float:
	var C := _cretes()
	if PhysiqueRoulage.surface_forcee == "route":
		return 0.0
	var z := PhysiqueRoulage.surface_forcee if PhysiqueRoulage.surface_forcee != "" else zone
	return float(C.proba.get(z, 0.0))


# Crête de la case i : [début, longueur de montée, longueur de descente, hauteur], ou [] s'il n'y en a pas
static func crete_case(i: float) -> Array:
	var C := _cretes()
	if alea(i, 17.3) >= proba_crete():
		return []
	var a := lerpf(float(C.montee[0]), float(C.montee[1]), alea(i, 41.9))
	var h := minf(lerpf(float(C.hauteur[0]), float(C.hauteur[1]), alea(i, 73.1)), float(C.pente_max) * a * 0.5)
	var b := a * float(C.descente)
	var pas := float(C.pas)
	var marge := float(C.marge)
	var x0 := i * pas + marge + maxf(0.0, pas - 2.0 * marge - a - b) * alea(i, 5.7)
	return [x0, a, b, h]


static func crete(x: float) -> float:
	var C := _cretes()
	if C.proba.is_empty():
		return 0.0
	var c := crete_case(floorf(x / float(C.pas)))
	if c.is_empty():
		return 0.0
	var s := x - float(c[0])
	if s <= 0.0 or s >= float(c[1]) + float(c[2]):
		return 0.0
	if s < float(c[1]):
		var u := s / float(c[1])
		return float(c[3]) * u * u   # montée : de plus en plus raide jusqu'à la lèvre
	var w := (s - float(c[1])) / float(c[2])
	return float(c[3]) * (1.0 - w) * (1.0 - w)   # retombée qui s'adoucit jusqu'au sol


# Zones aplanies (villes, DEC-140) : [x0, x1, hauteur] ; rampe douce de RAMPE m de chaque côté
const RAMPE := 30.0
static var plats: Array = []

static func aplanir(x0: float, x1: float) -> void:
	plats = [[x0, x1, 0.0]]
	plats[0][2] = _base(x0)

static func aplanir_effacer() -> void:
	plats = []

static func _poids_plat(p: Array, x: float) -> float:
	if x < float(p[0]) - RAMPE or x > float(p[1]) + RAMPE:
		return 0.0
	if x >= float(p[0]) and x <= float(p[1]):
		return 1.0
	var d := float(p[0]) - x if x < float(p[0]) else x - float(p[1])
	return smoothstep(RAMPE, 0.0, d)


# Petites bosses et cailloux (secousses des suspensions)
static func bosses(x: float) -> float:
	var h := 0.07 * sin(x * 0.55) + 0.05 * sin(x * 1.7 + 1.3) + 0.02 * sin(x * 4.1)
	var k := floorf(x / 9.0)
	var c := k * 9.0 + 4.5 + 3.0 * sin(k * 12.9898)
	var d := (x - c) / 0.35
	h += 0.16 * exp(-d * d) * (0.5 + 0.5 * absf(sin(k * 78.233)))
	return h


static func sol(x: float) -> float:
	var b := bosses(x)
	for p in plats:
		b *= 1.0 - 0.75 * _poids_plat(p, x)   # sol tassé dans l'enceinte
	return relief(x) + b


# Pente moyenne (m/m) sur 6 m autour de x : positive en montée
# Les crêtes n'y comptent pas : une bosse de quelques mètres se passe sur l'élan, elle ne ralentit pas la marche.
static func pente(x: float) -> float:
	return (route(x + 3.0) - route(x - 3.0)) / 6.0


# Pseudo-hasard stable pour semer le décor
static func alea(k: float, graine: float) -> float:
	return fposmod(sin(k * 127.1 + graine * 311.7) * 43758.5453, 1.0)


static func texture(nom: String) -> Texture2D:
	if not _tex.has(nom):
		var chemin := "res://assets/decor/%s.png" % nom
		_tex[nom] = load(chemin) if ResourceLoader.exists(chemin) else null
	return _tex[nom]


func _avec_images() -> bool:
	return zone == "terre" and texture("terre_ciel") != null and texture("terre_sol") != null


func _bande(nom: String, vit: float, bas: float) -> void:
	var t := texture(nom)
	var k := size.y / t.get_height()
	var lw := t.get_width() * k
	var x0 := -fposmod(camera_x * ppm * vit, lw)
	var teinte := Color.WHITE.lerp(Color(0.25, 0.3, 0.5), nuit)
	while x0 < size.x:
		draw_texture_rect(t, Rect2(x0, bas - size.y, lw + 1.0, size.y), false, teinte)
		if bas < size.y:   # vallée : on prolonge la dernière ligne de l'image vers le bas, plus de trou
			draw_texture_rect_region(t, Rect2(x0, bas, lw + 1.0, size.y - bas), Rect2(0, t.get_height() - 1, t.get_width(), 1), teinte)
		x0 += lw


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func _process(_d: float) -> void:
	queue_redraw()


# Ruban entre deux lignes de même nombre de points, de gauche à droite (DEC-262) : triangles donnés au moteur directement,
# sans la triangulation qu'il refait à chaque image pour un polygone quelconque (des centaines de points par couche).
# couleurs : une seule, ou une par point (haut puis bas).
static var _indices_ruban := {}

func _ruban(haut: PackedVector2Array, bas: PackedVector2Array, couleurs: PackedColorArray) -> void:
	var n := haut.size()
	if n < 2 or bas.size() != n:
		return
	if not _indices_ruban.has(n):
		var ind := PackedInt32Array()
		for i in n - 1:
			ind.append_array([i, i + 1, n + i + 1, i, n + i + 1, n + i])
		_indices_ruban[n] = ind
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _indices_ruban[n], haut + bas, couleurs)


func ecran_x(xm: float) -> float:
	return ancre_x + (xm - camera_x) * ppm


# Sol dessiné par le code (DEC-153) : terre en couches qui suivent le relief, route tassée et ornières, cailloux,
# touffes d'herbe sur la crête (zone terre), le tout assombri la nuit.
func _sol_code(sol_pts: PackedVector2Array, crete: PackedVector2Array, pal: Dictionary) -> void:
	var nuitc := Color(0.08, 0.1, 0.18)
	var base := Color(pal.sol).lerp(nuitc, 0.62 * nuit)
	var fond_bas := PackedVector2Array()   # fond de terre : de la crête jusqu'au bas de l'écran
	for q in crete:
		fond_bas.append(Vector2(q.x, size.y + 4.0))
	_ruban(crete, fond_bas, PackedColorArray([base.darkened(0.25)]))
	# couches : [profondeur haute, profondeur basse (m), couleur]
	# bas-côté du fond, chaussée large de trois voies (DEC-250), puis la terre en couches
	var r1 := BAS_COTE + 1.2
	var couches := [[0.0, 0.25, Color(pal.sol).darkened(0.06)], [0.25, r1, Color(pal.trace).lightened(0.22)], [r1, r1 + 0.85, Color(pal.sol)],
		[r1 + 0.85, r1 + 2.0, Color(pal.sol).darkened(0.12)], [r1 + 2.0, r1 + 3.9, Color(pal.sol).darkened(0.24)]]
	for c in couches:
		var col: Color = Color(c[2]).lerp(nuitc, 0.62 * nuit)
		var h_pts := PackedVector2Array()
		var b_pts := PackedVector2Array()
		for q in crete:
			h_pts.append(q + Vector2(0, float(c[0]) * ppm))
			var ond := 0.12 * ppm * sin((q.x + camera_x * ppm) * 0.013 + float(c[1]))   # limite de couche un peu ondulée
			b_pts.append(q + Vector2(0, float(c[1]) * ppm + ond))
		_ruban(h_pts, b_pts, PackedColorArray([col]))
	# ornières : deux traces par voie, plus fines et plus pâles vers le fond
	for i in DY_VOIES.size():
		var prof := BAS_COTE - float(DY_VOIES[i])
		for d in [-0.06, 0.12]:
			var orn := PackedVector2Array()
			for p in crete:
				orn.append(p + Vector2(0, (prof + d) * ppm))
			draw_polyline(orn, Color(0, 0, 0, 0.08 + 0.05 * i), maxf(1.5, (0.05 + 0.015 * i) * ppm))
	# crête : liseré et touffes d'herbe (zone terre)
	draw_polyline(crete, Color(pal.crete).lerp(nuitc, 0.6 * nuit), maxf(2.0, 0.06 * ppm))
	if zone == "terre":
		var herbe := Color(pal.crete).lightened(0.12).lerp(nuitc, 0.6 * nuit)
		var k0 := floorf((camera_x - ancre_x / ppm) / 0.7)
		for i in int(size.x / ppm / 0.7) + 2:
			var k := k0 + i
			if alea(k, 31.0) < 0.45:
				continue
			var xm := k * 0.7 + 0.5 * alea(k, 32.0)
			var pied := Vector2(ecran_x(xm), sol_y - (sol(xm) + BAS_COTE) * ppm)
			var h := (0.12 + 0.22 * alea(k, 33.0)) * ppm
			for j in 3:
				var dx := (j - 1) * 0.06 * ppm
				draw_line(pied + Vector2(dx, 0), pied + Vector2(dx + (j - 1) * 0.05 * ppm + 0.03 * ppm * sin(k), -h * (0.7 + 0.3 * float(j % 2))), herbe, maxf(1.0, 0.035 * ppm))
	# cailloux pris dans la terre
	var m0 := floorf((camera_x - ancre_x / ppm) / 1.3)
	for i in int(size.x / ppm / 1.3) + 2:
		var k := m0 + i
		var xm2 := k * 1.3 + 0.9 * alea(k, 34.0)
		var prof := (0.7 + 3.2 * alea(k, 35.0)) * ppm
		var r := (0.04 + 0.1 * alea(k, 36.0)) * ppm
		var cp := Vector2(ecran_x(xm2), sol_y - sol(xm2) * ppm + prof)
		Disque.d(self, cp, r, Color(pal.trace).lightened(0.3 * alea(k, 37.0)).lerp(nuitc, 0.62 * nuit))
		Disque.d(self, cp + Vector2(-r * 0.3, -r * 0.3), r * 0.45, Color(1, 1, 1, 0.08 * (1.0 - nuit)))


# --- Lot profondeur (DEC-249) : décor dessiné par le code pour les zones sans images ---------------
# Six plans : mesas très lointaines, ville en ruine, trois rangs de dunes, ligne télégraphique. Plus un plan est loin,
# plus il est pâle et pris dans la couleur de l'horizon (perspective atmosphérique). Le soleil, à droite, éclaire
# les versants tournés vers lui ; les crêtes ont un liseré de lumière.

# Ciel selon l'heure et la météo : [zénith, horizon]
func _ciel() -> Array:
	var zen := Color("#6E9CC0")
	var hor := Color("#EAD3A6")
	if zone == "neige":
		hor = Color("#DCE3E8")
	elif zone == "eau" or zone == "boue":
		hor = Color("#D9D2B8")
	zen = zen.lerp(Color("#4B5C86"), soir)
	hor = hor.lerp(Color("#E8955A"), soir)
	zen = zen.lerp(Color("#5A5F66"), orage * 0.8)
	hor = hor.lerp(Color("#9A8F80"), orage * 0.8)
	zen = zen.lerp(Color("#070D1C"), nuit)
	hor = hor.lerp(Color("#2A2C48"), nuit)
	return [zen, hor]


func _etoiles(w: float) -> void:
	if nuit > 0.2:
		for i in 70:
			Disque.d(self, Vector2(fposmod(i * 137.5 + 40.0, w), 20.0 + fposmod(i * 71.3, sol_y * 0.55)), 1.0 + 1.3 * alea(i, 11.0), Color(1, 1, 0.9, nuit * (0.4 + 0.5 * alea(i, 12.0))))


# Bande de brume : transparente en haut et en bas, plus dense au milieu
func _brume(y0: float, y1: float, col: Color, a: float, w: float) -> void:
	var ym := (y0 + y1) * 0.5
	var c0 := Color(col, 0.0)
	var c1 := Color(col, a)
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, ym), Vector2(0, ym)]), PackedColorArray([c0, c0, c1, c1]))
	draw_polygon(PackedVector2Array([Vector2(0, ym), Vector2(w, ym), Vector2(w, y1), Vector2(0, y1)]), PackedColorArray([c1, c1, c0, c0]))


func _dune_y(x: float, vit: float, niveau: float, amp: float, graine: float) -> float:
	var u: float = (camera_x * ppm * vit + x) / 300.0
	return sol_y * niveau - amp * (0.6 * sin(u * 0.9 + graine) + 0.4 * sin(u * 2.1 + 2.0 * graine))


# Rang de dunes ombré : versants éclairés côté soleil, pieds plus sombres, liseré de lumière sur la crête
func _dune(w: float, hgt: float, vit: float, niveau: float, amp: float, col: Color, graine: float) -> void:
	var jour := (1.0 - nuit) * (1.0 - 0.7 * orage)
	var clair := col.lerp(Color("#FFE2B0") if soir > 0.3 else Color.WHITE, 0.22 * jour)
	var ombre := col.darkened(0.16 * jour + 0.05)
	var bande := amp * 1.8
	var haut := PackedVector2Array()
	var cols := PackedColorArray()
	var x := -20.0
	while x <= w + 20.0:
		var y := _dune_y(x, vit, niveau, amp, graine)
		var pente := _dune_y(x + 10.0, vit, niveau, amp, graine) - _dune_y(x - 10.0, vit, niveau, amp, graine)   # > 0 : descend vers la droite, face au soleil
		haut.append(Vector2(x, y))
		cols.append(col.lerp(clair if pente > 0.0 else ombre, clampf(absf(pente) / 9.0, 0.0, 1.0)))
		x += 20.0
	var pied := col.darkened(0.12)
	var bas_b := PackedVector2Array()
	var fond := PackedVector2Array()
	for p in haut:
		bas_b.append(p + Vector2(0, bande))
		cols.append(pied)
		fond.append(Vector2(p.x, hgt))
	_ruban(haut, bas_b, cols)
	var haut_f := PackedVector2Array()
	for p in haut:
		haut_f.append(p + Vector2(0, bande - 1.0))
	_ruban(haut_f, fond, PackedColorArray([pied]))
	draw_polyline(haut, Color(clair, 0.55 * jour), 2.0)


# Mesas plates très lointaines (plateaux érodés)
func _mesas(w: float, hgt: float, vit: float, base: float, col: Color) -> void:
	var cel := 150.0
	var dec := camera_x * ppm * vit
	var k0 := floorf(dec / cel) - 1.0
	var pts := PackedVector2Array([Vector2(-cel, hgt), Vector2(-cel, base)])
	var k := k0
	while (k * cel - dec) < w + cel:
		var x0 := k * cel - dec
		var r := alea(k, 41.0)
		if r < 0.55:
			var hm := 30.0 + 80.0 * alea(k, 42.0)
			var a := 18.0 + 22.0 * alea(k, 43.0)
			pts.append(Vector2(x0 + 8.0, base))
			pts.append(Vector2(x0 + a, base - hm * 0.85))
			pts.append(Vector2(x0 + a + 6.0, base - hm))
			pts.append(Vector2(x0 + cel - a - 6.0, base - hm * (0.92 + 0.08 * alea(k, 44.0))))
			pts.append(Vector2(x0 + cel - a, base - hm * 0.8))
			pts.append(Vector2(x0 + cel - 8.0, base))
		else:   # collines basses entre deux plateaux
			pts.append(Vector2(x0 + cel * 0.5, base - 10.0 - 14.0 * alea(k, 45.0)))
		k += 1.0
	pts.append(Vector2(w + cel * 2.0, base))
	pts.append(Vector2(w + cel * 2.0, hgt))
	draw_colored_polygon(pts, col)


# Silhouette d'une ville en ruine, très loin
func _ville_ruine(w: float, hgt: float, vit: float, base: float, col: Color) -> void:
	var ville := PackedVector2Array([Vector2(0, hgt)])
	var xv := 0.0
	while xv <= w + 24:
		var uu: float = floorf((camera_x * ppm * vit + xv) / 24.0)
		var bloc := alea(floorf(uu / 9.0), 46.0) > 0.45   # quartiers séparés par des vides
		var hh: float = (14.0 + 62.0 * alea(uu, 1.0) * (1.0 if alea(uu, 2.0) > 0.35 else 0.25)) if bloc else 3.0
		ville.append(Vector2(xv, base - hh))
		ville.append(Vector2(xv + 24, base - hh * (0.5 + 0.5 * alea(uu, 3.0))))
		xv += 24
	ville.append(Vector2(w, hgt))
	draw_colored_polygon(ville, col)


# Ligne télégraphique plantée sur le rang de dunes proche : poteaux penchés, fils qui pendent, quelques poteaux tombés
func _ligne_poteaux(w: float, vit: float, niveau: float, amp: float, graine: float, col: Color) -> void:
	var pas := 230.0
	var dec := camera_x * ppm * vit
	var k := floorf(dec / pas) - 1.0
	var h := 5.0 * ppm * 0.45
	var prec := Vector2.INF
	while k * pas - dec < w + pas:
		var x := k * pas - dec + 40.0 * alea(k, 47.0)
		var debout := alea(k, 48.0) > 0.18
		var pied := Vector2(x, _dune_y(x, vit, niveau, amp, graine) + 3.0)
		if debout:
			var tete := pied + Vector2((alea(k, 49.0) - 0.5) * 0.35 * h, -h)
			draw_line(pied, tete, col, maxf(2.0, ppm * 0.07))
			draw_line(tete + Vector2(-0.12 * h, 0.07 * h), tete + Vector2(0.14 * h, 0.06 * h), col, maxf(1.5, ppm * 0.05))
			if prec != Vector2.INF:   # fil qui pend entre deux poteaux debout
				var fil := PackedVector2Array()
				for j in 9:
					var t := j / 8.0
					fil.append(prec.lerp(tete, t) + Vector2(0, 0.12 * h * sin(PI * t)))
				draw_polyline(fil, Color(col, 0.6), 1.0)
			prec = tete
		else:
			draw_line(pied, pied + Vector2(0.9 * h, -0.08 * h), col, maxf(2.0, ppm * 0.07))   # poteau tombé
			prec = Vector2.INF
		k += 1.0


func _fond_profondeur(w: float, hgt: float, pal: Dictionary) -> void:
	var cs := _ciel()
	var zen: Color = cs[0]
	var hor: Color = cs[1]
	var y_h := sol_y * 0.72   # ligne d'horizon
	var mi := zen.lerp(hor, 0.55)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, y_h * 0.55), Vector2(0, y_h * 0.55)]), PackedColorArray([zen, zen, mi, mi]))
	draw_polygon(PackedVector2Array([Vector2(0, y_h * 0.55), Vector2(w, y_h * 0.55), Vector2(w, hgt), Vector2(0, hgt)]), PackedColorArray([mi, mi, hor, hor]))
	_etoiles(w)
	# Astre : soleil voilé de halos (bas et orangé le soir), lune la nuit
	if nuit < 0.5:
		var sp := Vector2(w * 0.78, lerpf(sol_y * 0.24, sol_y * 0.52, soir))
		var sc := Color(1.0, 0.96, 0.84).lerp(Color(1.0, 0.62, 0.3), soir)
		var r := lerpf(46.0, 62.0, soir)
		var voile := 1.0 - 0.75 * orage
		for k in 14:   # halo doux : beaucoup de disques très transparents
			Disque.d(self, sp, r * (1.0 + 0.28 * (14 - k)), Color(sc, 0.028 * voile))
		Disque.d(self, sp, r, Color(sc, 0.95 * voile))
	else:
		var lp := Vector2(w * 0.7, sol_y * 0.22)
		for k in 4:
			Disque.d(self, lp, 30.0 * (1.0 + 0.7 * (4 - k)), Color(0.75, 0.82, 1.0, 0.035 * nuit))
		Disque.d(self, lp, 30.0, Color(0.88, 0.9, 1.0, 0.9 * nuit))
	# Nuages étirés, pris dans la lumière de l'horizon
	for i in 5:
		var cx := fposmod(i * 460.0 + 120.0 - camera_x * ppm * 0.015 - Time.get_ticks_msec() * 0.004 * (1 + i % 2), w + 600.0) - 300.0
		var cy := 50.0 + 34.0 * alea(i, 4.0) + i * 12.0
		var cn := Color.WHITE.lerp(hor, 0.5)
		draw_set_transform(Vector2(cx, cy), 0.0, Vector2(2.2, 0.55))
		for j in 4:
			Disque.d(self, Vector2(j * 30.0, 8.0 * sin(j * 1.7)), 28.0 + 8.0 * alea(i + j, 5.0), Color(cn, 0.18 * (1.0 - 0.7 * nuit)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var cl: Array = pal.couches
	# Six plans, du plus lointain au plus proche ; la brume s'intercale entre eux
	_mesas(w, hgt, 0.02, y_h + 8.0, Color(cl[0]).lerp(hor, 0.7))
	_brume(y_h - 50.0, y_h + 30.0, hor, 0.55, w)
	_ville_ruine(w, hgt, 0.05, sol_y * 0.77, Color(cl[0]).darkened(0.15).lerp(hor, 0.55))
	_brume(sol_y * 0.70, sol_y * 0.80, hor, 0.4, w)
	_dune(w, hgt, 0.1, 0.75, 55.0, Color(cl[0]).lerp(hor, 0.38), 1.0)
	_brume(sol_y * 0.74, sol_y * 0.84, hor, 0.3, w)
	_dune(w, hgt, 0.2, 0.82, 46.0, Color(cl[1]).lerp(hor, 0.2), 2.0)
	# Sable soulevé par le vent, en traînées qui filent entre les plans (désert et neige)
	if zone == "sable" or zone == "neige" or zone == "cailloux":
		var t := Time.get_ticks_msec() * 0.001
		for i in 8:
			var sx := fposmod(i * 311.0 - t * (140.0 + 45.0 * (i % 3)) - camera_x * ppm * 0.25, w + 500.0) - 250.0
			var sy := sol_y * (0.78 + 0.018 * i) + 6.0 * sin(t * 0.7 + i)
			draw_set_transform(Vector2(sx, sy), 0.0, Vector2(7.0, 0.45))
			Disque.d(self, Vector2.ZERO, 16.0, Color(hor.lightened(0.15), 0.09 * (1.0 - nuit)))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_brume(sol_y * 0.80, sol_y * 0.92, hor, 0.22, w)
	_ligne_poteaux(w, 0.38, 0.9, 34.0, 3.0, Color("#3E3024").lerp(hor, 0.35))
	_dune(w, hgt, 0.38, 0.9, 34.0, Color(cl[2]).lerp(hor, 0.08), 3.0)


# Premier plan des zones dessinées (DEC-249) : lèvre de terrain sombre en bas de l'écran et, de temps en temps, une grosse
# silhouette floue (rocher, poteau, carcasse) qui passe devant la caméra, plus vite que la route.
const VIT_AVANT := 1.6
func _avant_code() -> void:
	var w := size.x
	var hgt := size.y
	var pal: Dictionary = PALETTES[zone] if PALETTES.has(zone) else PALETTES.sable
	var sombre := Color(pal.sol).darkened(0.62).lerp(Color(0.03, 0.035, 0.06), 0.7 * nuit)
	var s := ppm * VIT_AVANT
	var dec := camera_x * s
	var levre := PackedVector2Array()
	var x := -24.0
	while x <= w + 24.0:
		var xl := dec + x
		levre.append(Vector2(x, hgt - (26.0 + 16.0 * sin(xl / 170.0) + 9.0 * sin(xl / 61.0 + 1.0))))
		x += 24.0
	var fond := PackedVector2Array(levre)
	fond.append(Vector2(w + 24.0, hgt + 2.0))
	fond.append(Vector2(-24.0, hgt + 2.0))
	draw_polyline(levre, Color(sombre, 0.35), 8.0)   # bord adouci (hors du plan de netteté)
	draw_colored_polygon(fond, sombre)
	# Grosses silhouettes floues : une cellule tous les 40 m « de premier plan », moins d'une sur deux occupée
	var cel := 40.0
	var xm0 := camera_x + (-300.0 - ancre_x) / s
	var xm1 := camera_x + (w + 300.0 - ancre_x) / s
	var k := floorf(xm0 / cel)
	while k * cel <= xm1:
		if alea(k, 51.0) < 0.42:
			var xm := k * cel + cel * alea(k, 52.0)
			var pied := Vector2(ancre_x + (xm - camera_x) * s, hgt + 12.0)
			var genre := alea(k, 53.0)
			for e in [[7.0, 0.22], [3.5, 0.45], [0.0, 0.92]]:   # flou : la forme grossie et pâle, puis le cœur
				var c := Color(sombre, float(e[1]))
				var g := float(e[0])
				if genre < 0.45:   # amas de rochers
					for j in 3:
						Disque.d(self, pied + Vector2((j - 1) * 0.9 * s, -0.15 * s * j), (0.7 + 0.5 * alea(k + j, 54.0)) * s + g, c)
				elif genre < 0.7:   # poteau télégraphique tout proche
					var tete := pied + Vector2(0.4 * s, -7.0 * s)
					draw_line(pied, tete, c, 0.28 * s + 2.0 * g)
					draw_line(tete + Vector2(-1.1 * s, 0.6 * s), tete + Vector2(1.2 * s, 0.5 * s), c, 0.16 * s + 2.0 * g)
				else:   # carcasse de voiture
					draw_rect(Rect2(pied + Vector2(-2.2 * s - g, -1.5 * s - g), Vector2(4.4 * s + 2.0 * g, 1.3 * s + 2.0 * g)), c)
					draw_rect(Rect2(pied + Vector2(-1.1 * s - g, -2.3 * s - g), Vector2(2.2 * s + 2.0 * g, 0.9 * s + 2.0 * g)), c)
		k += 1.0


func _dessiner_avant() -> void:
	if not _avec_images():
		_avant_code()
		return
	var teinte := Color.WHITE.lerp(Color(0.25, 0.3, 0.5), nuit) * Color(0.82, 0.8, 0.78)
	var kk := floorf((camera_x - ancre_x / ppm - 6.0) / 13.0)
	while kk * 13.0 <= camera_x + (size.x - ancre_x) / ppm + 6.0:
		var xm := kk * 13.0 + alea(kk, 20.0) * 13.0
		if alea(kk, 21.0) < 0.6:
			var it: Array = AVANT[int(alea(kk, 22.0) * AVANT.size()) % AVANT.size()]
			var te := texture(String(it[0]))
			if te != null:
				var sc := float(it[1]) * 1.25 * ppm / te.get_height()
				var pied := Vector2(ecran_x(xm), sol_y - sol(xm) * ppm + 1.45 * ppm)
				draw_texture_rect(te, Rect2(pied + Vector2(-te.get_width() * sc * 0.5, -te.get_height() * sc), te.get_size() * sc), false, teinte)
		kk += 1.0


func _draw() -> void:
	if avant:
		_dessiner_avant()
		return
	var w := size.x
	var hgt := size.y
	var img := _avec_images()
	var teinte := Color.WHITE.lerp(Color(0.25, 0.3, 0.5), nuit)
	if img:
		var g := relief(camera_x - ancre_x / ppm + w * 0.5 / ppm) * ppm   # les collines lointaines suivent un peu la vallée
		draw_texture_rect(texture("terre_ciel"), Rect2(0, 0, w, hgt), false, teinte)
		for var_ciel in [["terre_ciel_soir", soir], ["terre_ciel_orage", orage]]:
			var tc := texture(var_ciel[0])
			if tc != null and float(var_ciel[1]) > 0.01:
				draw_texture_rect(tc, Rect2(0, 0, w, hgt), false, Color(teinte.r, teinte.g, teinte.b, float(var_ciel[1])))
		_bande("terre_lointain", 0.08, sol_y * 0.93 - g * 0.25)
		_bande("terre_moyen", 0.2, sol_y * 1.0 - g * 0.5)
	var pal: Dictionary = PALETTES[zone] if PALETTES.has(zone) else PALETTES.sable
	if img:
		_etoiles(w)
	else:
		_fond_profondeur(w, hgt, pal)   # lot profondeur (DEC-249) : ciel, brume, six plans en parallaxe
	# Sol proche
	var sol_pts := PackedVector2Array([Vector2(0, hgt)])
	var crete := PackedVector2Array()
	var x2 := 0.0
	while x2 <= w + 8:
		var xm := camera_x + (x2 - ancre_x) / ppm
		var p := Vector2(x2, sol_y - (sol(xm) + BAS_COTE) * ppm)   # bord du fond de la route (DEC-250)
		sol_pts.append(p)
		crete.append(p)
		x2 += 8
	sol_pts.append(Vector2(w, hgt))
	_sol_code(sol_pts, crete, pal)   # sol dessiné par le code (DEC-153), plus de texture d'image
	# Traces et cailloux de premier plan
	var m0 := floorf((camera_x - ancre_x / ppm) / 3.0)
	for i in int(w / ppm / 3.0) + 2:
		var k := m0 + i
		var xm2 := k * 3.0 + 1.5 * sin(k * 3.7)
		var px := ecran_x(xm2)
		var py := sol_y - sol(xm2) * ppm + 18 + 30 * absf(sin(k * 5.3))
		Disque.d(self, Vector2(px, py), 3 + 4 * absf(sin(k * 9.1)), Color(pal.trace))


	# Décor semé sur la route : poteaux, cactus, arbres morts, rochers, carcasses
	var k0 := floorf(camera_x - ancre_x / ppm - 4.0)
	var k1 := floorf(camera_x + (w - ancre_x) / ppm + 4.0)
	var pas := 11.0
	var kk := floorf(k0 / pas)
	while kk * pas <= k1:
		var xm3 := kk * pas + alea(kk, 6.0) * pas
		var r := alea(kk, 7.0)
		var pied := Vector2(ecran_x(xm3), sol_y - (sol(xm3) + BAS_COTE) * ppm)   # sur le bas-côté du fond (DEC-250)
		var genre := ""
		for dk in pal.decor:
			if r < float(dk[1]):
				genre = dk[0]
				break
		if img and (ELEMENTS.has(genre) or GROUPES.has(genre)):
			var te: Texture2D = null
			var hm := 1.0
			if GROUPES.has(genre):
				var gr: Array = GROUPES[genre]
				var it: Array = gr[int(alea(kk, 17.0) * gr.size()) % gr.size()]
				te = texture(String(it[0]))
				hm = float(it[1])
			else:
				te = texture("elem_" + String(ELEMENTS[genre][0]))
				hm = float(ELEMENTS[genre][1])
				if genre == "arbre" and alea(kk, 16.0) > 0.5:
					te = texture("elem_arbre_mort")
					hm = 5.0
			if te != null:
				# Posé sur le sol (plus de décalage en l'air) ; épaves, objets, clôtures et murets suivent la pente de la route,
				# les autres restent droits et s'enfoncent du côté haut pour ne jamais flotter
				var sc := hm * ppm / te.get_height()
				var lw := te.get_width() * sc
				var lh := te.get_height() * sc
				var demi := lw * 0.5 / ppm
				var y_g := sol_y - (relief(xm3 - demi) + BAS_COTE) * ppm
				var y_d := sol_y - (relief(xm3 + demi) + BAS_COTE) * ppm
				var y_c := pied.y
				if genre == "epave" or genre == "objet" or genre == "cloture" or genre == "muret":
					draw_set_transform(Vector2(pied.x, y_c + 0.06 * ppm), atan2(y_d - y_g, lw), Vector2.ONE)
					draw_texture_rect(te, Rect2(Vector2(-lw * 0.5, -lh), Vector2(lw, lh)), false, teinte)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					var y_bas := maxf(y_c, maxf(y_g, y_d)) + 0.06 * ppm
					draw_texture_rect(te, Rect2(Vector2(pied.x - lw * 0.5, y_bas - lh), Vector2(lw, lh)), false, teinte)
		elif genre == "poteau":   # poteau télégraphique penché
			var hp := 4.6 * ppm
			draw_line(pied, pied + Vector2(0.15 * ppm, -hp), Color("#4A3828"), maxf(3.0, ppm * 0.12))
			draw_line(pied + Vector2(-0.7 * ppm, -hp * 0.93), pied + Vector2(0.9 * ppm, -hp * 0.95), Color("#4A3828"), maxf(2.0, ppm * 0.08))
		elif genre == "cactus":
			var hc := (1.2 + 1.2 * alea(kk, 8.0)) * ppm
			var cc := Color("#5F7A4A")
			draw_line(pied, pied + Vector2(0, -hc), cc, maxf(4.0, ppm * 0.28))
			draw_line(pied + Vector2(0, -hc * 0.45), pied + Vector2(-0.5 * ppm, -hc * 0.45), cc, maxf(3.0, ppm * 0.18))
			draw_line(pied + Vector2(-0.5 * ppm, -hc * 0.45), pied + Vector2(-0.5 * ppm, -hc * 0.8), cc, maxf(3.0, ppm * 0.18))
		elif genre == "arbre":   # arbre mort
			var ha := (2.0 + 1.5 * alea(kk, 9.0)) * ppm
			var cb := Color("#3E2E22")
			draw_line(pied, pied + Vector2(0.1 * ppm, -ha), cb, maxf(3.0, ppm * 0.16))
			draw_line(pied + Vector2(0.1 * ppm, -ha * 0.6), pied + Vector2(0.9 * ppm, -ha * 0.95), cb, maxf(2.0, ppm * 0.08))
			draw_line(pied + Vector2(0.1 * ppm, -ha * 0.7), pied + Vector2(-0.8 * ppm, -ha * 1.0), cb, maxf(2.0, ppm * 0.08))
		elif genre == "rocher":
			for j in 3:
				Disque.d(self, pied + Vector2((j - 1) * 0.5 * ppm, 0.1 * ppm), (0.35 + 0.3 * alea(kk + j, 10.0)) * ppm, Color("#8A7358").darkened(0.1 * j))
		elif genre == "herbe":   # touffes d'herbe
			var cg := Color("#6C8A3C").darkened(0.2 * alea(kk, 13.0))
			for j in 6:
				var dx := (j - 2.5) * 0.18 * ppm
				draw_line(pied + Vector2(dx, 0), pied + Vector2(dx + (j - 2.5) * 0.06 * ppm, -(0.35 + 0.4 * alea(kk + j, 14.0)) * ppm), cg, maxf(2.0, ppm * 0.05))
		elif genre == "roseau":   # roseaux dans l'eau
			var cro := Color("#6F7F4A")
			for j in 4:
				var dx2 := (j - 1.5) * 0.2 * ppm
				draw_line(pied + Vector2(dx2, 0), pied + Vector2(dx2 + 0.1 * ppm, -(0.8 + 0.7 * alea(kk + j, 15.0)) * ppm), cro, maxf(2.0, ppm * 0.06))
			draw_line(pied + Vector2(-0.9 * ppm, 0.15 * ppm), pied + Vector2(0.9 * ppm, 0.15 * ppm), Color(1, 1, 1, 0.25), 2.0)
		elif genre == "carcasse":   # carcasse de voiture rouillée
			var cr := Color("#6B4A3A")
			draw_rect(Rect2(pied + Vector2(-1.6 * ppm, -0.9 * ppm), Vector2(3.2 * ppm, 0.7 * ppm)), cr)
			draw_rect(Rect2(pied + Vector2(-0.8 * ppm, -1.5 * ppm), Vector2(1.7 * ppm, 0.6 * ppm)), cr.darkened(0.15))
			Disque.d(self, pied + Vector2(-1.0 * ppm, -0.2 * ppm), 0.35 * ppm, Color("#2A2622"))
			Disque.d(self, pied + Vector2(1.0 * ppm, -0.2 * ppm), 0.35 * ppm, Color("#2A2622"))
		kk += 1.0
	if nuit > 0.01:
		draw_rect(Rect2(Vector2(0, 0), size), Color(0.02, 0.04, 0.12, 0.5 * nuit))

# Animation de l'écran d'accueil (DEC-087) : calque posé sur l'image, sans fichier d'image supplémentaire.
# mode « lumiere » (fusion additive) : lampe qui vacille, phares, soleil, poussières dorées ;
# mode « fumee » : fumées des usines au loin. Le parent (image + calques) respire d'un lent zoom.
# Coordonnées en pixels de l'image d'origine (1672 × 941), recadrée « cover » comme le fond.
class_name TitreAnim
extends Control

const L := 1672.0
const H := 941.0
const CHEMINEES := [Vector2(1252, 262), Vector2(1338, 250), Vector2(1385, 290), Vector2(1262, 278)]

var mode := "lumiere"
var _t := 0.0
var _fumees: Array = []
var _spawn := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	if mode == "lumiere":
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m
	else:
		for i in 90:   # fumée déjà installée à l'affichage
			_avancer(0.1)


func _process(d: float) -> void:
	if not is_visible_in_tree():
		return
	_t += d
	if mode == "lumiere":
		var p := get_parent() as Control
		if p != null:
			p.pivot_offset = p.size * 0.5
			var z := 1.03 + 0.02 * sin(_t * 0.18)
			p.scale = Vector2(z, z)
	else:
		_avancer(d)
	queue_redraw()


func _avancer(d: float) -> void:
	_spawn -= d
	if _spawn <= 0.0:
		_spawn = 0.45
		var c: Vector2 = CHEMINEES[randi() % CHEMINEES.size()]
		_fumees.append({"p": c + Vector2(randf_range(-4, 4), 0), "age": 0.0, "vie": randf_range(9.0, 13.0), "r": randf_range(10.0, 16.0)})
	for f in _fumees:
		f.age += d
		f.p += Vector2(20.0, -11.0) * d
	_fumees = _fumees.filter(func(f): return f.age < f.vie)


func _draw() -> void:
	var ech := maxf(size.x / L, size.y / H)
	var dec := (size - Vector2(L, H) * ech) * 0.5
	if mode == "lumiere":
		_lumiere(ech, dec)
	else:
		for f in _fumees:
			var u: float = f.age / f.vie
			var a := 0.30 * sin(u * PI) if u < 0.9 else 0.0
			_halo(dec + f.p * ech, (f.r + 70.0 * u) * ech, Color(0.20, 0.17, 0.24, a), 10)


func _lumiere(ech: float, dec: Vector2) -> void:
	# lampe : vacillement rapide + petite chute rare
	var v := 0.82 + 0.10 * sin(_t * 13.0) + 0.06 * sin(_t * 31.7 + 1.0)
	if sin(_t * 0.9) > 0.985:
		v *= 0.6
	_halo(dec + Vector2(718, 118) * ech, 170.0 * ech, Color(1.0, 0.72, 0.32, 0.40 * v), 16)
	# phares du camion : respiration lente
	var ph := 0.8 + 0.2 * sin(_t * 1.3)
	for x in [1165.0, 1352.0]:
		_halo(dec + Vector2(x, 632) * ech, 62.0 * ech, Color(1.0, 0.85, 0.5, 0.30 * ph), 12)
	# soleil couchant
	_halo(dec + Vector2(1095, 340) * ech, 230.0 * ech, Color(1.0, 0.6, 0.25, 0.14 + 0.03 * sin(_t * 0.5)), 16)
	# poussières dorées dans la lumière de la lampe
	for i in 28:
		var k := float(i)
		var x := fposmod(300.0 + k * 53.0 + _t * (4.0 + fmod(k, 5.0)) + 25.0 * sin(_t * 0.4 + k), 900.0) + 120.0
		var y := fposmod(140.0 + k * 31.0 - _t * (3.0 + fmod(k, 4.0)), 560.0) + 90.0
		var a := 0.5 + 0.5 * sin(_t * 1.6 + k * 2.1)
		var proche := clampf(1.0 - Vector2(x, y).distance_to(Vector2(718, 200)) / 520.0, 0.0, 1.0)
		draw_circle(dec + Vector2(x, y) * ech, (1.5 + fmod(k, 3.0)) * ech, Color(1.0, 0.85, 0.55, 0.55 * a * proche))


# Halo doux : cercles concentriques de plus en plus petits et opaques
func _halo(c: Vector2, r: float, couleur: Color, n: int) -> void:
	for i in n:
		var u := float(i) / float(n)
		draw_circle(c, r * (1.0 - u), Color(couleur.r, couleur.g, couleur.b, couleur.a / float(n) * 1.6))

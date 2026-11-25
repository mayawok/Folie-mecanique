# Formes pleines regroupables (chantier Performance, DEC-262).
# Le moteur (Godot 4.3, rendu « Compatibilité ») dessine chaque polygone et chaque polyligne par un appel à part, mais
# regroupe en un seul appel les primitives à quatre points qui se suivent (c'est ainsi qu'il trace draw_line). Ces fonctions
# découpent donc les petites formes en quadrilatères : buste, coiffe, roue, ressort, contour de carrosserie… et toute une
# silhouette ou tout un véhicule dessiné par le code tient en quelques appels au lieu de plusieurs dizaines.
# Bords francs, comme draw_colored_polygon. Pour les disques à bord doux, voir Disque.
class_name Pinceau
extends RefCounted

static var _vide := PackedVector2Array()


static func quad(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	ci.draw_primitive(PackedVector2Array([a, b, c, d]), PackedColorArray([col]), _vide)


static func rect(ci: CanvasItem, r: Rect2, col: Color) -> void:
	quad(ci, r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), col)


static func tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	ci.draw_primitive(PackedVector2Array([a, b, c, c]), PackedColorArray([col]), _vide)


# Polygone convexe (ou en éventail depuis le premier point) : quadrilatères en éventail
static func eventail(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	var n := pts.size()
	if n < 3:
		return
	var i := 1
	while i + 2 < n:
		quad(ci, pts[0], pts[i], pts[i + 1], pts[i + 2], col)
		i += 2
	if i + 1 < n:
		tri(ci, pts[0], pts[i], pts[i + 1], col)


# Polygone quelconque : triangulé (indices mis en cache par le demandeur s'il le veut), deux triangles par primitive
static func polygone(ci: CanvasItem, pts: PackedVector2Array, col: Color, indices := PackedInt32Array()) -> void:
	if pts.size() <= 4:
		eventail(ci, pts, col)
		return
	var ind := indices if not indices.is_empty() else Geometry2D.triangulate_polygon(pts)
	if ind.is_empty():
		eventail(ci, pts, col)
		return
	for k in range(0, ind.size(), 3):
		tri(ci, pts[ind[k]], pts[ind[k + 1]], pts[ind[k + 2]], col)


# Contour (remplace draw_polyline) : un trait par segment
static func contour(ci: CanvasItem, pts: PackedVector2Array, col: Color, ep: float, ferme := false) -> void:
	for k in pts.size() - 1:
		ci.draw_line(pts[k], pts[k + 1], col, ep)
	if ferme and pts.size() > 2:
		ci.draw_line(pts[-1], pts[0], col, ep)


# Disque à bord franc en éventail (pour rester dans le même appel que les traits voisins)
static func rond(ci: CanvasItem, c: Vector2, r: float, col: Color, cotes := 12) -> void:
	var pts := PackedVector2Array()
	for k in cotes:
		pts.append(c + Vector2.from_angle(TAU * k / cotes) * r)
	eventail(ci, pts, col)

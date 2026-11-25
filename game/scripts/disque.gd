# Disques pleins dessinés comme des rectangles texturés (chantier Performance, DEC-262).
# draw_circle fabrique un polygone, et chaque polygone coûte un appel de dessin à lui seul. Un rectangle texturé, lui, se
# regroupe avec ses voisins de même texture : cent gouttes de sang ou cent grains de poussière tiennent en un seul appel.
# Le disque de la texture a un bord adouci (deux pixels) ; deux tailles pour rester net en petit comme en grand.
class_name Disque
extends RefCounted

static var _petit: ImageTexture
static var _grand: ImageTexture


static func _fabriquer(cote: int) -> ImageTexture:
	var img := Image.create(cote, cote, false, Image.FORMAT_RGBA8)
	var r := cote * 0.5
	for y in cote:
		for x in cote:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			img.set_pixel(x, y, Color(1, 1, 1, clampf(r - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


static func texture(rayon_px: float) -> Texture2D:
	if rayon_px <= 20.0:
		if _petit == null:
			_petit = _fabriquer(48)
		return _petit
	if _grand == null:
		_grand = _fabriquer(256)
	return _grand


# Remplace ci.draw_circle(c, r, couleur) (disque plein)
static func d(ci: CanvasItem, c: Vector2, r: float, couleur: Color) -> void:
	if r <= 0.0:
		return
	ci.draw_texture_rect(texture(r), Rect2(c.x - r, c.y - r, r * 2.0, r * 2.0), false, couleur)

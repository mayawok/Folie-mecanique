"""Pièces provisoires ultra simplifiées des 3 chars (M3 Stuart, M4 Sherman, Tiger I).

ChatGPT refuse de dessiner les chars : ces aplats occupent l'espace (forme générale,
couleur, cotes) en attendant l'art final. Échelle : 256 px par mètre (64 px par cellule).

Usage : python3 tools/placeholders_chars.py   puis   python3 tools/specs_vehicules.py
        puis python3 tools/gabarits_vehicule.py docs/art/vehicules/<id>
"""
from pathlib import Path
from PIL import Image, ImageDraw

PX = 256  # px par mètre
OLIVE, SABLE = (92, 96, 58), (176, 150, 92)
GRIS, NOIR = (70, 68, 62), (38, 36, 33)


def ton(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def piece(path, w, h, polys, couleur, cercles=()):
    """polys : listes de points en mètres, origine en bas à gauche de la pièce."""
    im = Image.new("RGBA", (round(w * PX), round(h * PX)), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    to = lambda p: (p[0] * PX, (h - p[1]) * PX)
    for i, poly in enumerate(polys):
        pts = [to(p) for p in poly]
        d.polygon(pts, fill=ton(couleur, 1 - 0.08 * i), outline=ton(couleur, 0.55), width=4)
    # reflet en haut, ombre en bas (lumière du haut à gauche)
    top = min(y for poly in polys for _, y in (to(p) for p in poly))
    mask = im.split()[3]
    reflet = Image.new("RGBA", im.size, ton(couleur, 1.25) + (90,))
    bande = Image.new("L", im.size, 0); ImageDraw.Draw(bande).rectangle([0, top, im.width, top + 0.12 * PX], fill=255)
    im.paste(reflet, (0, 0), Image.composite(bande, Image.new("L", im.size, 0), mask))
    for cx, cy, r, c in cercles:
        x, y = to((cx, cy))
        d.ellipse([x - r * PX, y - r * PX, x + r * PX, y + r * PX], fill=c, outline=ton(c, 0.55), width=3)
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)


def chenille(path, L, H, n_dents):
    im = Image.new("RGBA", (round(L * PX), round(H * PX)), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    r = H * PX / 2
    d.rounded_rectangle([0, 0, im.width - 1, im.height - 1], radius=r, fill=NOIR, outline=ton(NOIR, 0.6), width=4)
    d.rounded_rectangle([0.1 * PX, 0.1 * PX, im.width - 0.1 * PX, im.height - 0.1 * PX], radius=r - 0.1 * PX, fill=GRIS)
    pas = im.width / n_dents  # patins
    for i in range(n_dents):
        x = i * pas
        d.line([x, 0, x, 0.1 * PX], fill=ton(NOIR, 1.6), width=3)
        d.line([x, im.height - 0.1 * PX, x, im.height], fill=ton(NOIR, 1.6), width=3)
    for cx in (r, im.width - r):  # barbotin et roue de tension
        d.ellipse([cx - r * 0.7, r - r * 0.7, cx + r * 0.7, r + r * 0.7], fill=ton(GRIS, 0.8), outline=NOIR, width=3)
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)


def galet(path, D, couleur):
    s = round(D * PX)
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, s - 1, s - 1], fill=NOIR)
    d.ellipse([s * .12, s * .12, s * .88, s * .88], fill=couleur, outline=ton(couleur, .55), width=3)
    d.ellipse([s * .4, s * .4, s * .6, s * .6], fill=ton(couleur, .7))
    im.save(path)


def boite(path, w, h, c):
    piece(path, w, h, [[(0, 0), (w, 0), (w, h), (0, h)]], c, [(w * .3, h * .5, min(w, h) * .18, ton(c, .7))])


# Cotes de prototypage (m). Caisse : profil simplifié, avant à droite.
CHARS = {
    "m3_stuart": dict(c=OLIVE, galet=0.50, chenille=(4.20, 0.72, 22),
        caisse=(4.40, 1.10, [(0, 0), (4.0, 0), (4.4, 0.55), (4.1, 1.10), (0.3, 1.10), (0, 0.75)]),
        tourelle=(1.60, 0.75, [(0, 0), (1.6, 0), (1.45, 0.75), (0.2, 0.75)]),
        canon=(1.30, 0.13), moteur=(0.90, 0.60), transmission=(0.70, 0.45)),
    "m4_sherman": dict(c=OLIVE, galet=0.52, chenille=(5.00, 0.85, 26),
        caisse=(5.84, 1.45, [(0, 0), (5.3, 0), (5.84, 0.55), (5.0, 1.45), (0.4, 1.45), (0, 1.0)]),
        tourelle=(2.20, 0.85, [(0, 0), (2.2, 0), (2.0, 0.65), (1.6, 0.85), (0.4, 0.85), (0.1, 0.55)]),
        canon=(1.60, 0.16), moteur=(1.20, 0.80), transmission=(0.90, 0.55)),
    "tiger_1": dict(c=SABLE, galet=0.80, chenille=(5.80, 1.00, 30),
        caisse=(6.32, 1.50, [(0, 0), (5.7, 0), (6.32, 0.70), (6.0, 1.50), (0, 1.50)]),
        tourelle=(2.80, 1.00, [(0, 0), (2.8, 0), (2.8, 0.8), (2.55, 1.0), (0.1, 1.0), (0, 0.85)]),
        canon=(4.70, 0.18), moteur=(1.40, 0.90), transmission=(1.00, 0.60)),
}


def main():
    root = Path("docs/art/vehicules")
    for vid, s in CHARS.items():
        art = root / vid / "art"
        c = s["c"]
        w, h, poly = s["caisse"]; piece(art / "caisse.png", w, h, [poly], c)
        w, h, poly = s["tourelle"]; piece(art / "tourelle.png", w, h, [poly], ton(c, 1.05))
        L, D = s["canon"]  # tube + frein de bouche
        piece(art / "canon.png", L, D * 1.6, [[(0, D * .3), (L - .25, D * .3), (L - .25, D * 1.3), (0, D * 1.3)],
                                               [(L - .25, 0), (L, 0), (L, D * 1.6), (L - .25, D * 1.6)]], ton(c, .9))
        L, H, n = s["chenille"]; chenille(art / "chenille.png", L, H, n)
        galet(art / "galet.png", s["galet"], ton(c, .9))
        boite(art / "moteur.png", *s["moteur"], GRIS)
        boite(art / "transmission.png", *s["transmission"], ton(GRIS, .85))
        print(vid, "ok")


if __name__ == "__main__":
    main()

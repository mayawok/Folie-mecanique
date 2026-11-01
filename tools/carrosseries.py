"""Carrosseries d'intercepteur (DEC-083) tirées de la berline peinte : découpe, rallonge, rouille, trous, sans vitres.
Usage : python3 tools/carrosseries.py   (depuis la racine du dépôt). 20 px par case de 0,25 m."""
import random
from PIL import Image, ImageDraw, ImageFilter, ImageChops

SRC = "game/assets/coques/coque_berline.png"
OUT = "game/assets/coques/"
BELT = 41          # ligne de ceinture (bas des vitres)
im = Image.open(SRC).convert("RGBA")
W, H = im.size


def cat(*parts):
    w = sum(b - a for a, b in parts)
    r = Image.new("RGBA", (w, H))
    x = 0
    for a, b in parts:
        r.paste(im.crop((a, 0, b, H)), (x, 0))
        x += b - a
    return r


def vider(img, x0, x1, y0, y1):
    d = ImageDraw.Draw(img)
    d.rectangle((x0, y0, x1 - 1, y1 - 1), fill=(0, 0, 0, 0))


def rouille(img, graine, force=0.55):
    rnd = random.Random(graine)
    w, h = img.size
    bruit = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(bruit)
    for _ in range(int(w * h / 260)):
        x, y, r = rnd.randrange(w), rnd.randrange(h), rnd.randint(2, 9)
        d.ellipse((x - r, y - r, x + r, y + r), fill=rnd.randint(80, 255))
    bruit = bruit.filter(ImageFilter.GaussianBlur(2.2)).point(lambda v: 0 if v < 120 else int((v - 120) * force * 1.9))
    rou = Image.new("RGBA", (w, h), (138, 68, 30, 255))
    alpha = ImageChops.multiply(bruit, img.getchannel("A"))
    rou.putalpha(alpha)
    return Image.alpha_composite(img, rou)


def trou(img, cx, cy, r, rnd):
    pts = []
    import math
    n = 9
    for k in range(n):
        a = 2 * math.pi * k / n
        rr = r * rnd.uniform(0.6, 1.15)
        pts.append((cx + rr * math.cos(a), cy + rr * 0.8 * math.sin(a)))
    d = ImageDraw.Draw(img)
    big = [(cx + (x - cx) * 1.45, cy + (y - cy) * 1.45) for x, y in pts]
    d.polygon(big, fill=(150, 78, 32, 255))       # bord écaillé
    mid = [(cx + (x - cx) * 1.15, cy + (y - cy) * 1.15) for x, y in pts]
    d.polygon(mid, fill=(62, 34, 18, 255))        # tôle rongée
    d.polygon(pts, fill=(0, 0, 0, 0))             # à jour


def impacts(img, cx, cy, rnd, n=4):
    d = ImageDraw.Draw(img)
    for _ in range(n):
        x, y = cx + rnd.randint(-10, 10), cy + rnd.randint(-6, 6)
        d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(120, 70, 35, 255))
        d.ellipse((x - 1, y - 1, x + 1, y + 1), fill=(0, 0, 0, 0))


def trouer(img, graine, n_trous, zones):
    rnd = random.Random(graine)
    for _ in range(n_trous):
        x0, x1 = rnd.choice(zones)
        trou(img, rnd.randint(x0, x1), rnd.randint(BELT + 12, H - 30), rnd.randint(3, 6), rnd)
    x0, x1 = rnd.choice(zones)
    impacts(img, rnd.randint(x0, x1), rnd.randint(BELT + 10, H - 35), rnd)


def vitre(img, x0, x1):   # pare-brise fêlé : seule vitre restante
    w, h = img.size
    a = img.getchannel("A")
    v = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(v)
    for x in range(x0, x1):
        col = [a.getpixel((x, y)) for y in range(0, BELT)]
        for y in range(4, BELT):
            if col[y] < 40 and any(c > 128 for c in col[:y]):
                d.point((x, y), fill=(150, 175, 170, 120))
    cx, cy = (x0 + x1) // 2, 26
    for ex, ey in [(x0 + 2, 14), (x1 - 3, 18), (x0 + 6, BELT - 3), (x1 - 6, BELT - 2), (cx, 12)]:
        d.line((cx, cy, ex, ey), fill=(225, 235, 230, 200), width=1)
    return Image.alpha_composite(img, v)


def lit(img, x1):   # plateau de pick-up : rebord et fond de benne
    d = ImageDraw.Draw(img)
    a = img.getchannel("A")
    for x in range(0, x1):
        if a.getpixel((x, BELT + 4)) > 128:
            d.line((x, BELT - 1, x, BELT + 2), fill=(70, 62, 50, 255))
    d.line((x1 + 1, 2, x1 + 1, BELT), fill=(50, 44, 36, 255), width=3)   # dos de cabine


def ecrire(img, nom):
    img.save(OUT + nom + ".png")
    print(nom, img.size)


# Court (15 cases) : on retire la porte arrière
court = cat((0, 100), (160, W))
c1 = rouille(court.copy(), 11)
trouer(c1, 11, 3, [(30, 90), (120, 150), (180, 260)])
ecrire(vitre(c1, 107, 156), "carrosserie_coupe")
c2 = court.copy()
vider(c2, 0, 168, 0, BELT)
c2 = rouille(c2, 12, 0.7)
trouer(c2, 12, 4, [(30, 90), (110, 150), (180, 260)])
ecrire(c2, "carrosserie_roadster")
# Moyen (18 cases) : berline trouée et pick-up
m1 = rouille(im.copy(), 21)
trouer(m1, 21, 4, [(30, 90), (110, 150), (170, 210), (240, 320)])
ecrire(m1, "carrosserie_berline")
m2 = im.copy()
vider(m2, 0, 160, 0, BELT)
lit(m2, 158)
m2 = rouille(m2, 22, 0.75)
trouer(m2, 22, 4, [(30, 90), (110, 150), (240, 320)])
ecrire(m2, "carrosserie_pickup")
# Long (21 cases) : on double la porte arrière
lg = cat((0, 162), (102, W))
l1 = rouille(lg, 31, 0.65)
trouer(l1, 31, 5, [(30, 90), (110, 150), (170, 210), (230, 270), (300, 380)])
ecrire(l1, "carrosserie_limousine")

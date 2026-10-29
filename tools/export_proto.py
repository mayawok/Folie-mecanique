"""Copie les images utiles au prototype dans game/assets (taille réduite pour le web).

Usage : python3 tools/export_proto.py
- Véhicules : recombinés à partir des pièces (gabarit.json), fond transparent, 128 px par mètre.
- Autres images : réduites à 1024 px de côté maximum (décor : 1920 px de large).
À relancer après chaque nouvelle image utile au jeu.
"""
import json, shutil
from pathlib import Path
from PIL import Image, ImageDraw

ART, OUT = Path("docs/art"), Path("game/assets")
VEHICULES = ["willys_mb", "bmw_r75", "m3_half_track", "citroen_traction", "citroen_t23"]
PX_M = 128


def vehicule(vid):
    folder = ART / "vehicules" / vid
    g = json.loads((folder / "gabarit.json").read_text())
    ppc = PX_M * g["cell_m"]
    images = {i["id"]: i for i in g["images"]}
    W, H = g["size_cells"]
    sheet = Image.new("RGBA", (round(W * ppc), round(H * ppc)), (0, 0, 0, 0))
    for inst in sorted(g["instances"], key=lambda k: k["z"]):
        img = images[inst["image"]]; bx, by, bw, bh = img["box"]; bx += inst["dx"]
        src = folder / "art" / f"{img['id']}.png"
        if not src.exists():
            continue
        piece = Image.open(src).convert("RGBA")
        if inst.get("trous"):
            k = piece.width / (bw * ppc); dr = ImageDraw.Draw(piece)
            for cx, cy, r in inst["trous"]:
                px, py, pr = (cx - bx) * ppc * k, (by + bh - cy) * ppc * k, r * ppc * k
                dr.ellipse([px - pr, py - pr, px + pr, py + pr], fill=(0, 0, 0, 0))
        px = piece.load()  # nettoie les restes de fond magenta
        for yy in range(piece.height):
            for xx in range(piece.width):
                r, g, b, a = px[xx, yy]
                if a and r > 150 and b > g + 8 and g < r * 0.65:
                    px[xx, yy] = (0, 0, 0, 0)
        piece = piece.resize((max(1, round(bw * ppc)), max(1, round(bh * ppc))), Image.LANCZOS)
        sheet.alpha_composite(piece, (round(bx * ppc), round((H - by - bh) * ppc)))
    sheet = sheet.crop(sheet.getbbox())  # bas de l'image = sol
    sheet.save(OUT / "vehicules" / f"{vid}.png")


def reduit(src, dst, maxi):
    im = Image.open(src)
    k = min(1.0, maxi / max(im.size))
    if k < 1:
        im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    im.save(dst, optimize=True)


def main():
    for sub in ("vehicules", "decor", "batiments", "ui", "carte", "personnages", "fx"):
        (OUT / sub).mkdir(parents=True, exist_ok=True)
    for v in VEHICULES:
        vehicule(v)
    for f in (ART / "decor").glob("bg_desert_*.png"):
        im = Image.open(f); k = 1920 / im.width
        im.resize((1920, round(im.height * k)), Image.LANCZOS).save(OUT / "decor" / f.name, optimize=True)
    for sub in ("batiments", "ui", "personnages"):
        for f in (ART / sub).glob("*.png"):
            reduit(f, OUT / sub / f.name, 512 if sub != "batiments" else 1024)
    for f in (ART / "carte").glob("*.png"):
        reduit(f, OUT / "carte" / f.name, 1536 if "fond" in f.name else 160)
    for n in ("fx_fumee", "fx_eclair_tir", "fx_flamme"):
        reduit(ART / "fx" / f"{n}.png", OUT / "fx" / f"{n}.png", 256)
    print("ok")


if __name__ == "__main__":
    main()

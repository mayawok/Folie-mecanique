"""Gabarits et recombinaison d'un véhicule en pièces (thème 6, DEC-021).

Usage : python3 tools/gabarits_vehicule.py docs/art/vehicules/willys_mb
- Écrit gabarits/<image>.png : silhouette noire sur blanc, à joindre à la consigne ChatGPT.
- Si une instance a des "trous", écrit art/<image>_avant.png : la caisse percée aux roues,
  à poser devant les roues (ordre : caisse, roues, caisse_avant).
- Écrit assemblage.png : véhicule recombiné sur la grille de 25 cm.
  Si art/<image>.png existe (pièce dessinée, fond transparent), elle remplace la silhouette.
"""
import json, sys
from pathlib import Path
from PIL import Image, ImageDraw

COLORS = {"chassis": (70, 70, 70), "transmission": (60, 110, 180), "moteur": (220, 130, 40),
          "roulement": (25, 25, 25), "carrosserie": (110, 120, 70), "armement": (180, 50, 50)}

def draw_shapes(draw, shapes, to_px, color, scale):
    for s in shapes:
        fill = tuple(min(255, c + 90) for c in color) if s.get("tone") == "light" else color
        if "poly" in s:
            draw.polygon([to_px(x, y) for x, y in s["poly"]], fill=fill)
        else:
            x, y, r = s["circle"]; cx, cy = to_px(x, y)
            draw.ellipse([cx - r * scale, cy - r * scale, cx + r * scale, cy + r * scale], fill=fill)

def main(folder):
    folder = Path(folder); g = json.loads((folder / "gabarit.json").read_text())
    ppc = g["px_per_cell"]; images = {i["id"]: i for i in g["images"]}
    (folder / "gabarits").mkdir(exist_ok=True)
    for img in images.values():  # gabarits individuels
        bx, by, bw, bh = img["box"]
        im = Image.new("RGB", (round(bw * ppc), round(bh * ppc)), "white")
        to_px = lambda x, y: ((x - bx) * ppc, (by + bh - y) * ppc)
        draw_shapes(ImageDraw.Draw(im), img["shapes"], to_px, (0, 0, 0), ppc)
        im.save(folder / "gabarits" / f"{img['id']}.png")
    W, H = g["size_cells"]; sheet = Image.new("RGBA", (round(W * ppc), round(H * ppc)), (245, 240, 230, 255))
    d = ImageDraw.Draw(sheet)
    for i in range(int(W) + 1): d.line([(i * ppc, 0), (i * ppc, H * ppc)], fill=(210, 200, 185))
    for j in range(int(H) + 1): d.line([(0, H * ppc - j * ppc), (W * ppc, H * ppc - j * ppc)], fill=(210, 200, 185))
    for inst in sorted(g["instances"], key=lambda k: k["z"]):  # recombinaison par profondeur
        img = images[inst["image"]]; bx, by, bw, bh = img["box"]; bx += inst["dx"]
        art = folder / "art" / f"{img['id']}.png"
        if art.exists():
            piece = Image.open(art).convert("RGBA")
            if inst.get("trous"):  # calque avant : la caisse percée là où passent les roues
                k = piece.width / (bw * ppc); dr = ImageDraw.Draw(piece)
                for cx, cy, r in inst["trous"]:
                    px, py, pr = (cx - bx) * ppc * k, (by + bh - cy) * ppc * k, r * ppc * k
                    dr.ellipse([px - pr, py - pr, px + pr, py + pr], fill=(0, 0, 0, 0))
                piece.save(folder / "art" / f"{img['id']}_avant.png")
            piece = piece.resize((round(bw * ppc), round(bh * ppc)))
            sheet.alpha_composite(piece, (round(bx * ppc), round((H - by - bh) * ppc)))
        else:
            layer = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
            to_px = lambda x, y, dx=inst["dx"]: ((x + dx) * ppc, (H - y) * ppc)
            draw_shapes(ImageDraw.Draw(layer), img["shapes"], to_px, COLORS[img["slot"]] + (230,), ppc)
            sheet.alpha_composite(layer)
    sheet.convert("RGB").save(folder / "assemblage.png")

if __name__ == "__main__":
    main(sys.argv[1])

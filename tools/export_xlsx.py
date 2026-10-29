"""Exporte chaque onglet d'un classeur .xlsx en CSV (UTF-8) + un index Markdown.

Usage : python3 tools/export_xlsx.py <classeur.xlsx> <dossier_sortie>
Le classeur reste l'outil d'édition ; les CSV sont la version lisible,
comparable dans Git et économique à lire pour une IA. Relancer après
chaque modification du classeur.
"""
import csv, re, sys, unicodedata
from pathlib import Path
import openpyxl

def slug(name):
    s = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")

def main(src, out):
    out = Path(out); out.mkdir(parents=True, exist_ok=True)
    wb = openpyxl.load_workbook(src, read_only=True, data_only=True)
    rows_idx = []
    for ws in wb.worksheets:
        rows = [r for r in ws.iter_rows(values_only=True) if any(c is not None for c in r)]
        width = max((max((i for i, c in enumerate(r) if c is not None), default=-1) for r in rows), default=-1) + 1
        name = slug(ws.title) + ".csv"
        with open(out / name, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            for r in rows:
                w.writerow(["" if c is None else c for c in r[:width]])
        header = ", ".join(str(c) for c in rows[0][:width] if c is not None)[:160] if rows else ""
        rows_idx.append((ws.title, name, max(len(rows) - 1, 0), header))
    with open(out / "INDEX.md", "w", encoding="utf-8") as f:
        f.write(f"# Index des tables — export de `{Path(src).name}`\n\n")
        f.write("Fichier généré par `tools/export_xlsx.py`. Ne pas éditer à la main.\n\n")
        f.write("| Onglet | Fichier | Lignes | Colonnes |\n|---|---|---|---|\n")
        for t, n, c, h in rows_idx:
            f.write(f"| {t} | `{n}` | {c} | {h.replace('|', '/')} |\n")
    print(f"{len(rows_idx)} onglets exportés vers {out}")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])

# Berliet GDR — art et assemblage (DEC-136 à 138)

- `planches/` : images d'origine reçues de ChatGPT le 08/11 (ne pas modifier). `reference_assemble.png` sert seulement de guide de pose.
- Découpe : `python3 tools/decouper_berliet.py docs/art/vehicules/berliet_gdr/planches game/assets/vehicules/berliet` (fond retiré, vitres de la cabine en intérieur sombre, images réduites de moitié).
- Pose : `game/data/berliet.json` (positions en pixels du châssis long, 250 px = 1 m). Aperçu sans Godot : `python3 tools/apercu_berliet.py sortie.png long crampons agraire 4 2 0`.
- Ajouter un pneu, un échappement, un réservoir : déposer la planche, ajouter son nom dans `PLANCHES` du script de découpe, puis une entrée dans `berliet.json`. Aucun code.
- Modules arrière (citerne, benne, grue, troupes, ridelles, plateau) : dessinés par le code dans `berliet_dessin.gd` en attendant de vraies images.
- Essai : Mode créatif → Kit → « Berliet GDR : pièces et halte ».

# Sons, musiques et voix avec ElevenLabs — Folie Mécanique

Statut : en cours (DEC-024). Le jeu lit déjà ces fichiers : il suffit de les déposer
dans `game/assets/audio/` avec **exactement** le nom indiqué. Un fichier absent est ignoré
(le jeu reste silencieux à cet endroit).

## Licence : à lire avant de produire

- **Offre gratuite** : 10 000 crédits par mois, **usage commercial interdit**, mention
  « elevenlabs.io » obligatoire en cas de publication. Suffisant pour le prototype.
- **Offre Starter** (≈ 6 $/mois) : licence commerciale, **valable seulement pour ce qui est
  généré pendant l'abonnement**. Un son produit en gratuit ne devient pas commercial après coup.
- Stratégie économique : prototype en gratuit maintenant ; avant la sortie, un mois de Starter
  pour **régénérer** la liste finale d'un coup. Noter l'offre utilisée dans `docs/art/asset-register.csv`.

## Économiser les crédits

1. Produire d'abord la liste **P0** ci-dessous (≈ 6 000 crédits, tient dans l'offre gratuite).
2. Fixer la **durée** de chaque bruitage au minimum utile (réglage « Duration ») au lieu du mode automatique.
3. Générer, écouter, garder la meilleure variante ; ne pas relancer pour un détail :
   le volume et la longueur se corrigent dans le jeu.
4. Pour les boucles (moteurs, vent), activer l'option **Loop** si elle est proposée.
5. Musique : 60 à 90 s suffisent, le jeu la fait tourner en boucle.

## Méthode

1. Ouvrir l'outil indiqué (Sound Effects, Music ou Text to Speech).
2. Copier la consigne telle quelle (en anglais : l'outil comprend mieux).
3. Télécharger en **MP3**, renommer avec le nom de fichier exact.
4. Déposer dans le dépôt GitHub : dossier `game/assets/audio/`, bouton
   **Add file → Upload files**, puis **Commit changes**. Le jeu en ligne se reconstruit
   tout seul en quelques minutes. Ou m'envoyer les fichiers, je les range.

Si un léger clic s'entend au moment où une boucle recommence, signale-le :
je convertis le fichier en `.ogg`, qui boucle sans coupure.

## P0 — branchés dans le prototype

### Musique (outil Music)

| Fichier | Durée | Consigne |
|---|---|---|
| `mus_menu.mp3` | 90 s | `Instrumental main menu theme for a post-apocalyptic 1940s desert survival game. Slow, epic and melancholic. Low brass, solo cello, distant snare drum march rhythm, wind-like synth pad, sparse metallic percussion. Inspired by Mad Max and WWII film scores. No vocals. Loopable, ends on the same chord it starts.` |
| `mus_base.mp3` | 90 s | `Calm instrumental background music for managing a survivor camp in a scorching desert, 1940s post-war wasteland. Sparse acoustic guitar, soft low strings, light hand percussion, faint harmonica, warm and tense at the same time. Unobtrusive, suitable to play for a long time. No vocals. Seamless loop.` |

### Ambiances (outil Sound Effects, durée 20 s, Loop)

| Fichier | Consigne |
|---|---|
| `amb_desert_jour.mp3` | `Hot desert wind ambience at midday, steady soft gusts, fine sand blowing, distant metal sheet rattling in the wind, occasional faraway bird of prey cry. No music. Seamless loop.` |
| `amb_desert_nuit.mp3` | `Cold desert night ambience, quiet low wind, crickets and insects, very distant animal howl once, crackling campfire nearby. No music. Seamless loop.` |

### Bruitages (outil Sound Effects)

| Fichier | Durée | Consigne |
|---|---|---|
| `sfx_ui_clic.mp3` | 0,5 s | `Short dry mechanical click of a metal toggle switch on a 1940s military radio panel. Single click, no reverb.` |
| `sfx_radio.mp3` | 2 s | `Short burst of 1940s military field radio static with a squelch beep at the start, crackling, then silence.` |
| `sfx_depart_convoi.mp3` | 4 s | `Several old military vehicles starting their engines and driving away on a gravel desert track, engine revving, gears grinding, fading into the distance.` |
| `sfx_depart_marche.mp3` | 3 s | `Small group of people walking away on sand and gravel with heavy boots, backpacks and metal canteens clinking, fading out.` |
| `sfx_tir_mitrailleuse.mp3` | 1,5 s | `Short burst of a WWII heavy machine gun firing outdoors in the desert, six rapid shots, metallic mechanical action, short open-air echo.` |
| `sfx_tir_canon.mp3` | 3 s | `Single powerful WWII tank cannon shot outdoors, deep boom, metallic recoil clank, long rolling echo across a desert valley.` |
| `sfx_moteur_jeep.mp3` | 6 s, Loop | `Steady idle and light driving engine sound of a 1940s four-cylinder military jeep, slightly rough, constant, seamless loop.` |
| `sfx_moteur_moto.mp3` | 6 s, Loop | `Steady engine sound of a 1940s boxer-twin military motorcycle with sidecar riding at moderate speed, constant, seamless loop.` |
| `sfx_moteur_voiture.mp3` | 6 s, Loop | `Steady engine sound of a worn-out 1930s four-cylinder sedan driving on a dirt road, rattling body panels, constant, seamless loop.` |
| `sfx_moteur_camion.mp3` | 6 s, Loop | `Steady engine sound of a heavy 1940s military truck driving slowly on rough ground, deep six-cylinder rumble, rattling cargo, seamless loop.` |
| `sfx_moteur_semi_chenille.mp3` | 6 s, Loop | `Steady sound of a WWII half-track vehicle driving: truck engine rumble mixed with clanking rubber tracks and squeaking road wheels, seamless loop.` |
| `sfx_moteur_char_leger.mp3` | 6 s, Loop | `Steady sound of a WWII light tank driving fast: high-revving radial engine and rattling metal tracks, seamless loop.` |
| `sfx_moteur_char.mp3` | 6 s, Loop | `Steady sound of a heavy WWII tank driving slowly: deep V12 engine growl, heavy squeaking and clanking steel tracks, seamless loop.` |

### Voix (outil Text to Speech)

Choisir une voix française masculine, grave, un peu usée (ou la créer avec Voice Design :
`A tired French man in his fifties, deep and slightly hoarse voice, calm, speaking over an old military radio.`).
Garder **la même voix** pour toutes les répliques du jeu.

| Fichier | Texte |
|---|---|
| `voix_retour_convoi.mp3` | `Ici le convoi. Nous sommes de retour à la base.` |

## P1 — préparés, branchés plus tard

| Fichier | Outil | Consigne ou texte |
|---|---|---|
| `mus_combat.mp3` | Music, 60 s | `Tense instrumental battle music, 1940s war film style, pounding timpani, aggressive low brass stabs, fast snare rolls, metallic percussion. No vocals. Loopable.` |
| `sfx_explosion.mp3` | Sound Effects, 3 s | `Vehicle explosion in the desert, fuel tank igniting, metal debris falling on sand.` |
| `sfx_impact_blindage.mp3` | Sound Effects, 1 s | `Bullet ricochet and heavy shell impact on thick steel armor plate, loud metallic clang.` |
| `sfx_meute.mp3` | Sound Effects, 4 s | `Pack of large wild desert dogs howling and growling aggressively, getting closer.` |
| `sfx_nuee.mp3` | Sound Effects, 4 s | `Dense swarm of locusts buzzing and rustling over food crates.` |
| `sfx_atelier.mp3` | Sound Effects, 5 s, Loop | `Mechanic workshop: hammer on steel, wrench ratchet, occasional welding hiss, seamless loop.` |
| `sfx_pompe.mp3` | Sound Effects, 4 s, Loop | `Old hand water pump squeaking, water splashing into a metal bucket, seamless loop.` |
| `voix_penurie.mp3` | Text to Speech | `Les réserves sont à sec. Il faut sortir, et vite.` |
| `voix_pillards.mp3` | Text to Speech | `Contact ! Des pillards sur la route !` |

Les voix du récit (système 8) seront listées une fois les moments narratifs écrits.

## Tambours de départ en mission (DEC-145, 08/11)

Version actuelle : `mus_tambours.wav`, **synthétisée** par `tools/synth_tambours.py` (aucun crédit). Pour une version produite :
déposer `mus_tambours.mp3` dans `game/assets/audio/` (le jeu prend l'ogg ou le mp3 avant le wav, puis supprimer le wav).

| Fichier | Outil | Consigne |
|---|---|---|
| `mus_tambours.mp3` | Music, 45 s | `Savage war drums for a desert raiding party leaving the gates: huge low taiko-like drums, tribal tom rolls, heavy snare hits, distorted low drone and growling bass, wild driving 120 BPM rhythm, post-apocalyptic, 1940s scrap-metal percussion (oil drums, metal sheets). No vocals, no melody lead. Loopable, ends on the downbeat.` |

## Musique de fin — convoi anéanti (DEC-055)

Fichier : `game/assets/audio/mus_fin.mp3` (outil **Music**, 60 à 90 s, sans boucle). Prompt à coller :

```
Slow, desolate desert lament for the end of a post-apocalyptic 1940s road journey. Sparse, wide and dusty: a lone oud or fretless guitar with long reverb, low wind-like drones, distant frame drum heartbeat, and a wordless human choir — a solo female voice humming and a few low male voices chanting softly, as if heard from far away across sand dunes. Melancholic, dignified, mysterious, not epic. No modern synths, no lyrics, no percussion build-up. Fades out slowly at the end. 70 BPM, D minor.
```

## Production par Claude via le plugin (DEC-084, 02/11)

Inventaire : tous les fichiers P0 et P1 sont présents dans `game/assets/audio/`. **Seul manque : `mus_fin.mp3`** (prompt ci-dessus, 60 à 90 s, instrumental avec voix humaines : régler `lyrics_type` sur instrumental ou auto selon l'essai).
Règles d'économie : une génération par fichier, durée minimale utile, pas de relance pour un détail, accord préalable sur le coût, effets (radio, distance) par « Audio Effects » (gratuit) plutôt que par régénération.

**02/11 — `mus_fin` générée sous licence Starter** : 20 s, `eleven_music_v2_5`, une seule version, 300 crédits (voix humaines sans paroles, `lyrics_type` auto). Fichier non téléchargeable depuis l'espace de travail de Claude (accès réseau refusé, 403) : à télécharger depuis le projet Music d'ElevenLabs et à déposer dans `game/assets/audio/mus_fin.mp3`. Coûts relevés : musique 20 s = 300 crédits.
**02/11 (suite)** : `mus_fin.mp3` déposée dans `game/assets/audio/` (20,04 s, 498 Ko, titre ElevenLabs « Last Caravan »). Importée automatiquement par la construction web (`godot --import`). Plus aucun son manquant.

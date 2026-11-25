# Du Mac à l'iPhone : installer Folie Mécanique en appli native

Préparé le 25/11/2026 pour l'arrivée du Mac (DEC-260). Compte Apple **gratuit** : l'appli s'installe sur ton iPhone et y reste
**7 jours** ; ensuite on la relance depuis Xcode (deux clics). Le compte payant (99 €/an) servira plus tard pour TestFlight et
l'App Store ; il n'est pas nécessaire pour tester.

Le dépôt est déjà prêt : préréglage d'export « iOS », icône App Store, écran de chargement, paysage dans les deux sens, zones
sûres de l'écran lues par le système, son même en mode silencieux, 60 images/s. L'export a été essayé de bout en bout
(projet Xcode généré sans erreur) ; il reste à le compiler et le signer sur le Mac, ce qui ne se fait que sur un Mac.

Compte une demi-journée la première fois, surtout à cause des téléchargements (Xcode pèse plus de 10 Go).

---

## Ce qu'on va faire, en une phrase

**GitHub** (le code) → **Godot** (fabrique un projet iPhone) → **Xcode** (le compile, le signe et l'envoie) → **iPhone**.

| Outil | Rôle | Où le trouver |
|---|---|---|
| GitHub Desktop | Récupérer le projet et ses mises à jour en un clic | desktop.github.com |
| Godot 4.3 | Le moteur du jeu ; il exporte un projet Xcode | godotengine.org, page « Archive » → 4.3-stable |
| Xcode | L'outil d'Apple qui installe l'appli sur l'iPhone | App Store du Mac |

**Important : Godot 4.3 exactement**, pas une version plus récente. C'est celle des tests automatiques et du site web ; un
changement de version se décidera ensemble (OQ-055).

---

## Étape 1 — Préparer le Mac (pendant que le reste télécharge)

1. Mets macOS à jour : menu Pomme (en haut à gauche) → Réglages Système → Général → Mise à jour de logiciels. Xcode exige un macOS récent.
2. Connecte-toi avec **le même identifiant Apple que ton iPhone**.
3. Ouvre l'**App Store**, cherche **Xcode**, clique « Obtenir ». Lance-le tout de suite : c'est le plus long.

## Étape 2 — Récupérer le projet

1. Installe **GitHub Desktop** et connecte-toi avec ton compte GitHub (mayawok).
2. File → Clone Repository → **mayawok/Folie-mecanique** → choisis un dossier, par exemple `Documents/Folie-mecanique`.
3. Plus tard, pour récupérer mon travail : bouton **Fetch origin**, puis **Pull origin**. C'est tout.

## Étape 3 — Installer Godot 4.3

1. Sur godotengine.org, page de téléchargement → **Archive** → **4.3-stable** → la version **macOS** (« universal »).
2. Ouvre le fichier .zip, glisse **Godot.app** dans **Applications**.
3. Premier lancement : clic droit sur Godot → **Ouvrir** → **Ouvrir** (macOS demande confirmation pour une appli téléchargée).
4. Dans Godot : **Importer** → va dans ton dossier du projet → **game** → `project.godot` → **Importer et éditer**.
   La première ouverture prend quelques minutes (Godot prépare les images et les sons).
5. Menu **Éditeur → Gérer les modèles d'export… → Télécharger et installer**. Ce sont les « moules » qui fabriquent l'appli
   iPhone (environ 1 Go).

Astuce : la touche **F5** lance le jeu directement sur le Mac, à la souris. Pratique pour un essai rapide sans téléphone.

## Étape 4 — Brancher ton compte Apple dans Xcode

1. Ouvre **Xcode**. Au premier lancement, accepte la licence et coche **iOS** dans les composants à installer.
2. Menu **Xcode → Settings… → Accounts** → bouton **+** → **Apple ID** → ton identifiant.
   Une équipe « **Ton Nom (Personal Team)** » apparaît. C'est ton compte gratuit de développeur.
3. Toujours là : sélectionne ton équipe → **Manage Certificates…** → **+** → **Apple Development**. Xcode crée ton certificat.
4. Récupère ton **Team ID** (10 caractères, lettres et chiffres). Ouvre l'appli **Terminal** et colle :

   ```
   security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject
   ```

   Dans la ligne qui s'affiche, ton Team ID est ce qui suit **OU=** (par exemple `OU=AB12CD34EF`).
   **Envoie-le-moi** : je l'inscrirai dans le dépôt pour que tu n'aies plus jamais à le retaper. Ce n'est pas un secret
   (il figure dans chaque appli publiée), mais ne mets jamais ton mot de passe Apple nulle part.

## Étape 5 — Préparer l'iPhone

1. Branche l'iPhone au Mac avec le câble. Sur l'iPhone : **Se fier à cet ordinateur** → code.
2. Active le **mode développeur** : Réglages → Confidentialité et sécurité → tout en bas, **Mode développeur** → activé.
   L'iPhone redémarre et demande confirmation. (L'option n'apparaît qu'après le branchement à un Mac équipé de Xcode.)

## Étape 6 — Fabriquer le projet iPhone avec Godot

1. Dans Godot : **Projet → Exporter…** → choisis **iOS** dans la liste de gauche.
2. Champ **App Store Team ID** : colle ton Team ID (étape 4). Si je l'ai déjà inscrit dans le dépôt, il est déjà rempli.
3. Ne touche pas au reste : identifiant `fr.foliemecanique.prototype` (provisoire, tu choisiras le définitif plus tard),
   icône, écran de chargement, « Export Project Only » coché.
4. **Exporter le projet…** → laisse coché **Exporter avec débogage** → va dans le dossier du dépôt, sous-dossier **build/ios**
   (crée-le) → nom `FolieMecanique.ipa` → **Enregistrer**. Un avertissement « .ipa can only be built… » ou « completed
   with warnings » est normal : on veut seulement le projet Xcode.

Le dossier `build/` n'est jamais envoyé sur GitHub (il est exclu exprès).

## Étape 7 — Installer sur l'iPhone avec Xcode

1. Double-clique sur **build/ios/FolieMecanique.xcodeproj** : Xcode l'ouvre.
2. Colonne de gauche : clique sur **FolieMecanique** (l'icône bleue tout en haut) → onglet **Signing & Capabilities**.
   Vérifie : **Automatically manage signing** coché ; **Team** = ton « Personal Team ». S'il y a une erreur rouge, choisis
   à nouveau ton équipe dans la liste.
3. Tout en haut de la fenêtre, à côté de « FolieMecanique », choisis **ton iPhone** comme destination (pas un simulateur).
4. Clique sur **▶** (ou Cmd + R). La première compilation prend plusieurs minutes.
5. Premier lancement : l'iPhone refuse d'ouvrir l'appli. Va dans Réglages → Général → **VPN et gestion de l'appareil** →
   ton identifiant → **Faire confiance**. Relance avec ▶.

L'appli « Folie Mécanique (prototype) » est maintenant sur ton écran d'accueil, avec son icône.

## Étape 8 — Les fois suivantes

1. GitHub Desktop : **Fetch origin** puis **Pull origin**.
2. Godot : **Projet → Exporter… → iOS → Exporter le projet…**, même dossier, accepte de remplacer.
3. Xcode : **▶**. (Si Xcode a perdu l'équipe, refais l'étape 7.2.)

Au bout de 7 jours, l'appli ne s'ouvre plus : rebranche l'iPhone et fais **▶** dans Xcode, rien d'autre.

Le site web (GitHub Pages) continue d'exister en parallèle ; rien ne change de ce côté.

---

## Ce que je te demanderai de vérifier sur l'iPhone

- L'icône, le nom sous l'icône et l'écran de chargement.
- Les deux sens du paysage (île à gauche, puis téléphone retourné) : les boutons ne doivent jamais passer sous l'île ni dans
  les coins arrondis.
- Le son avec le bouton silencieux activé, puis en revenant d'une autre appli.
- La fluidité en combat avec beaucoup d'ennemis, et la chaleur du téléphone au bout de 15 minutes.
- Pendant que le jeu tourne depuis Xcode : panneau de gauche, icône en forme de jauge (**Debug navigator**) → **CPU**,
  **Memory**, **FPS**. Une capture d'écran de ce panneau en plein combat m'aide beaucoup.
- Le **compteur d'images** du jeu (Options → « Compteur d'images ») si tu veux un chiffre sans Xcode.

## Si ça bloque

| Message | Ce qu'il faut faire |
|---|---|
| « App Store Team ID not specified » (Godot) | Étape 4.4 puis 6.2 |
| « No account for team … » ou « Signing requires a development team » (Xcode) | Étape 7.2 : choisis ton Personal Team |
| « Failed to register bundle identifier » | L'identifiant est déjà pris par quelqu'un : dis-le-moi, j'en propose un autre |
| « Developer Mode disabled » | Étape 5.2 |
| « Untrusted Developer » sur l'iPhone | Étape 7.5 |
| « Could not launch … » après 7 jours | ▶ dans Xcode, iPhone branché |
| Toute autre erreur rouge à la compilation | Fais une capture de la liste d'erreurs (icône ⚠ à gauche) et envoie-la-moi |

## Plus tard (rien à faire maintenant)

- **Identifiant définitif** de l'appli (OQ-055) : à choisir avant la première publication ; ensuite il ne change plus.
- **Compte payant** (99 €/an) : TestFlight (installer chez des testeurs), publication, plus de limite de 7 jours.
- **Nom sous l'icône** : aujourd'hui « Folie Mécanique (prototype) », tronqué par l'iPhone ; à raccourcir avant publication.
- **Version de Godot** : rester en 4.3 ou passer à une version plus récente (meilleur support iPhone, mais tout le jeu à
  revérifier) : OQ-055.

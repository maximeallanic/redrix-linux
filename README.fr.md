# redrix-linux

**Le dernier kilomètre de Linux sur le HP Elite Dragonfly Chromebook : retour haptique, stylet, caméra, micro,
haut-parleurs, veille et empreinte, depuis une seule liste à cocher où chaque étape est facultative, vérifiée et
réversible.**

[![CI](https://github.com/maximeallanic/redrix-linux/actions/workflows/ci.yml/badge.svg)](https://github.com/maximeallanic/redrix-linux/actions/workflows/ci.yml)
[![Licence : MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Testé sous Debian testing, GNOME 51, noyau 7.2](https://img.shields.io/badge/tested-Debian%20testing%20%C2%B7%20GNOME%2051%20%C2%B7%20kernel%207.2-informational)

[English](README.md) · [Matériel pris en charge](docs/hardware-support.md) · [Installation](docs/installation.md) ·
[Dépannage](docs/troubleshooting.md) (documentation détaillée en anglais)

<p align="center">
  <img src="docs/assets/support-at-a-glance.svg" width="900"
       alt="État du matériel en un coup d'œil. Fonctionne d'emblée : processeur, GPU, écran tactile, clavier, rétroéclairage, pavé tactile haptique, écran externe USB-C, Wi-Fi, Bluetooth, mode tablette, capteur de luminosité, batterie. Fonctionne avec le kit ou une étape de configuration : stylet, touches verrouillage et plein écran, haut-parleurs, prise casque, lecteur d'empreintes, veille S3. Partiel : mise à l'échelle de l'écran intégré, micros intégrés, caméra, stockage USB-C, s2idle, TPM. Ne fonctionne pas : Widevine L1, fonctions ChromeOS. Non testé : rotation de l'écran, modem LTE.">
</p>

Carte `redrix`, Intel Alder Lake, famille « Brya ». Testé sur une seule machine : Debian testing (forky), GNOME
Shell 51 sous Wayland, noyau 7.2, micrologiciel UEFI MrChromebox 2609.1. Ubuntu devrait fonctionner (mêmes outils de
paquets) mais n'a pas été testé ; les autres distributions sont
[en partie couvertes](docs/installation.md#other-distributions).

## Pourquoi

Faire démarrer Linux sur ce Chromebook, c'est la partie résolue : MrChromebox, chrultrabook et
[chromebook-linux-audio](https://github.com/WeirdTreeThing/chromebook-linux-audio) s'en chargent. Reste une
douzaine de petites choses qui donnent l'impression d'une machine inachevée :

| D'origine | Avec le kit |
|---|---|
| Le pavé tactile haptique ne vibre qu'au clic | De courtes vibrations sur les fenêtres, les bureaux, le verrouillage, et quand le volume bute ([haptics](docs/components/haptics.md)) |
| Le stylet part sur l'écran externe | Le stylet reste sur l'écran intégré et apparaît dans Paramètres ([pen](docs/components/pen.md)) |
| La touche de verrouillage met en veille ; la touche plein écran ne fait rien | Verrouiller verrouille, le plein écran fonctionne ([top-row](docs/components/top-row.md)) |
| Image de la caméra délavée et un peu verte | Niveau de noir et matrice de couleurs mesurés : écart de couleur de dE 18,8 à 6,8 sur une mire ([camera](docs/components/camera.md)) |
| Ventilateur et clavier audibles en visio | Un micro débruité, choisi par défaut : bruit de fond de -47,7 à -60,9 dBFS dans une pièce bruyante ([microphone](docs/components/microphone.md)) |
| `dsm_param_R_Google_Redrix.bin failed with error -2` : les amplis tournent sans modèle de haut-parleur | Les fichiers DSM de Google, extraits de l'image de récupération officielle sur votre machine ([speakers](docs/components/speakers.md)) |
| s2idle n'atteint jamais S0ix et vide la batterie | Vraie veille S3 à la fermeture du capot, et le pavé ne la réveille plus une seconde après ([suspend](docs/components/suspend.md)) |
| Aucun pilote d'empreinte dans le libfprint de Debian | Le pilote crfpmoc compilé pour vous, puis, si vous le voulez, connexion, déverrouillage et `sudo` par empreinte ([fingerprint](docs/components/fingerprint.md)) |
| Le logo du micrologiciel cède la place à un autre écran, l'arrêt saute sur du texte | Le logo reste de l'allumage à l'écran de connexion ([boot-splash](docs/components/boot-splash.md)) ; l'arrêt fond vers lui ([shutdown-splash](docs/components/shutdown-splash.md)) |

Les chiffres viennent de la machine testée ; chaque page d'élément explique comment ils ont été mesurés.

## Démarrage rapide

Depuis votre compte habituel, dans un terminal de votre session GNOME :

```sh
curl -fsSL https://raw.githubusercontent.com/maximeallanic/redrix-linux/main/install.sh | bash
```

Le script s'arrête aussitôt sur toute machine qui n'est pas un Redrix, télécharge une version épinglée, vérifie son
SHA-256 et ouvre une liste à cocher. Vous préférez lire d'abord ? Passez par une copie du dépôt :

```sh
git clone https://github.com/maximeallanic/redrix-linux
cd redrix-linux
./install.sh --list        # ce qui est disponible sur cette machine
./install.sh --dry-run     # chaque commande qui serait lancée, sans rien changer
./install.sh               # la liste à cocher
```

Ensuite, à tout moment :

```sh
./verify.sh                    # tous les éléments installés, une ligne par vérification
./uninstall.sh camera          # retirer un élément (ce qui en dépend est proposé aussi)
```

Tous les détails : [docs/installation.md](docs/installation.md).

## Ce que vous pouvez installer

Quatorze éléments. Ceux à faible risque utiles à tous sont précochés ; aucun autre ne l'est.

| Élément | Ce que vous obtenez | Risque |
|---|---|---|
| [haptics](docs/components/haptics.md) | Vibrations du pavé tactile (et de la MX Master 4) sur les fenêtres, bureaux et le verrouillage | faible, précoché |
| [pen](docs/components/pen.md) | Le stylet reste sur l'écran intégré avec un moniteur branché, apparaît dans Paramètres, point sous la pointe | faible, précoché |
| [top-row](docs/components/top-row.md) | La touche de verrouillage verrouille au lieu de mettre en veille ; la touche plein écran fonctionne | faible, précoché |
| [camera](docs/components/camera.md) | Couleurs et niveau de noir calibrés ; 32 entrées de caméra brutes inutilisables masquées | faible, précoché |
| [microphone](docs/components/microphone.md) | Un micro intégré débruité, choisi comme entrée par défaut | faible, précoché |
| [battery-guard](docs/components/battery-guard.md) | Pour une batterie usée qui s'éteint à quelques % : alerte à 20 %, arrêt propre à 6 % | faible |
| [keychron](docs/components/keychron.md) | Permet à launcher.keychron.com de configurer un clavier Keychron depuis Chrome | faible |
| [speakers](docs/components/speakers.md) | Fichiers de réglage des amplis extraits de l'image de récupération Google (~1,5 Go à télécharger) | moyen |
| [suspend](docs/components/suspend.md) | Vraie veille S3 à la fermeture du capot (micrologiciel MrChromebox seulement) | moyen |
| [fingerprint](docs/components/fingerprint.md) | Compile le pilote du capteur d'empreintes pour enregistrer des doigts ; connexion inchangée | moyen |
| [shutdown-splash](docs/components/shutdown-splash.md) | Fondu au noir puis logo du micrologiciel à l'arrêt et au redémarrage | moyen |
| [lockscreen-fingerprint](docs/components/lockscreen-fingerprint.md) | Toucher le capteur sur l'horloge de l'écran verrouillé pour déverrouiller | moyen |
| [fingerprint-login](docs/components/fingerprint-login.md) | Connexion, déverrouillage et `sudo` par empreinte ; le mot de passe reste valable | **élevé** |
| [boot-splash](docs/components/boot-splash.md) | Le logo du micrologiciel reste affiché de l'allumage à l'écran de connexion | **élevé** |

Chaque page d'élément a les mêmes quatre parties : contexte, ce qui change, comment vérifier, comment revenir en
arrière.

## Avant de commencer

- Linux déjà installé et qui démarre, avec GNOME sous Wayland. Micrologiciel : l'UEFI de MrChromebox, ou celui
  d'origine avec une charge RW_LEGACY/Submarine. Seul `suspend` exige MrChromebox.
- Pour le son, la configuration de [chromebook-linux-audio](https://github.com/WeirdTreeThing/chromebook-linux-audio)
  d'abord.
- Le kit ne flashe aucun micrologiciel, n'installe pas de chargeur d'amorçage et ne partitionne pas le disque.
  [docs/firmware.md](docs/firmware.md) et [docs/boot-chain.md](docs/boot-chain.md) décrivent la configuration de la
  machine testée, à titre de référence.

## Sécurité

Le kit modifie un portable dont vous dépendez ; il est donc conçu pour être prévisible :

- **Vous voyez avant qu'il agisse.** `--dry-run` affiche chaque commande, paquets compris. Les éléments à risque
  moyen montrent ce qu'ils modifient et comment revenir en arrière, puis demandent. Ceux à risque élevé exigent de
  taper leur nom ; `--yes` seul ne les installe jamais.
- **Il ne tourne que là où c'est utile.** L'installateur lit la carte dans `/sys/class/dmi/id` et s'arrête sur un
  autre matériel avant de télécharger quoi que ce soit. Les éléments qui ne peuvent pas fonctionner chez vous (par
  exemple `suspend` avec le micrologiciel d'origine) sont listés avec la raison et ne peuvent pas être choisis.
- **Connexion.** `fingerprint-login` sauvegarde `/etc/pam.d`, passe par l'outil Debian `pam-auth-update`, vérifie
  que la connexion par mot de passe est toujours là et vous demande d'essayer `sudo` dans un second terminal avant de
  fermer le premier. Gardez un shell root ou une clé USB live sous la main la première fois.
- **Démarrage.** `boot-splash` reconstruit l'initramfs. Les commandes exactes pour revenir à un autre thème Plymouth
  figurent sur sa page et à l'écran de confirmation.
- **Retour en arrière.** Chaque élément remet ce qu'il a remplacé et retire exactement les fichiers qu'il a
  installés. Les paquets installés avec `apt` restent, et le désinstallateur dit lesquels.
- **Fichiers tiers.** Les fichiers des haut-parleurs de Google, libfprint et le micrologiciel sont téléchargés ou
  compilés sur votre machine, épinglés par commit ou par empreinte, jamais stockés dans ce dépôt. Voir
  [NOTICE.md](NOTICE.md).
- **Code vérifié.** L'intégration continue passe ShellCheck sur chaque script shell et lance les tests sous Debian
  testing.

## Questions fréquentes

**Est-ce que ça marche sur d'autres Chromebooks ou d'autres cartes Brya ?**
Non testé. L'installateur s'arrête si la carte n'est pas un Redrix ; `--force` passe outre, mais la plupart des
éléments visent le matériel exact de ce modèle (pavé tactile, numériseur du stylet, capteur de la caméra, amplis,
microcontrôleur d'empreinte). Si vous essayez un élément sur une carte voisine, un
[rapport matériel](https://github.com/maximeallanic/redrix-linux/issues/new?template=hardware_report.yml) aide tout
le monde.

**Fedora, Arch, KDE ?**
Les paquets ne s'installent automatiquement que sous Debian et Ubuntu. Ailleurs, l'installateur liste ce qu'il faut
sous les noms Debian ; `fingerprint-login` et `boot-splash` sont propres à Debian. Le kit suppose GNOME sous
Wayland. Rien de tout cela n'a été testé hors Debian : voir
[autres distributions](docs/installation.md#other-distributions).

**Est-ce que ça règle le son ?**
Non. Le son vient de [chromebook-linux-audio](https://github.com/WeirdTreeThing/chromebook-linux-audio). Le kit
ajoute par-dessus les fichiers DSM des amplis et un micro débruité.

**Pourquoi `speakers` télécharge-t-il 1,5 Go ?**
Les fichiers DSM appartiennent à Google et ne sont pas redistribués. L'élément télécharge l'image de récupération
officielle du Redrix, la vérifie avec l'index de Google, en extrait quatre fichiers et ne les installe que s'ils
correspondent aux empreintes épinglées dans le kit. Il faut environ 7 Go libres dans `/var/tmp` pendant l'opération.

**Est-ce que je risque de briquer mon portable ?**
Le kit ne touche jamais au micrologiciel. Les deux éléments à risque élevé modifient la connexion (PAM) et le
démarrage (initramfs) ; ils sont facultatifs, exigent de taper leur nom et documentent un retour en arrière manuel
qui fonctionne même sans le kit.

**Qu'est-ce qui ne marche toujours pas ?**
Widevine L1 (le streaming repasse en L3), les applis Android et les mises à jour ChromeOS disparaissent quand on
quitte ChromeOS. s2idle n'atteint jamais S0ix, la caméra garde une dominante froide en lumière chaude, Mic2 est
inutilisable et une échelle fractionnaire vers 150 % n'est pas disponible. La liste complète est dans
[docs/hardware-support.md](docs/hardware-support.md).

**Et l'autonomie ?**
Non mesurée avec ce kit. Des retours de la communauté donnent 5 à 7 h sous Linux contre environ 11 h sous ChromeOS.

## Contribuer

Une seule machine a été testée pour l'instant : la contribution la plus utile est un retour depuis la vôtre. Ouvrez
un [rapport matériel](https://github.com/maximeallanic/redrix-linux/issues/new?template=hardware_report.yml) avec la
sortie de `./verify.sh --all`, que tout marche ou non. Les bogues vont dans le
[formulaire de bogue](https://github.com/maximeallanic/redrix-linux/issues/new?template=bug_report.yml) ; les
modifications de code suivent [CONTRIBUTING.md](CONTRIBUTING.md). Failles de sécurité : [SECURITY.md](SECURITY.md).

Si le kit vous a fait gagner une soirée, une étoile aide les autres propriétaires de Dragonfly à le trouver.

## Remerciements

Ce kit repose sur le travail de [MrChromebox](https://mrchromebox.tech) et [coreboot](https://coreboot.org)
(micrologiciel UEFI), de la communauté [chrultrabook](https://docs.chrultrabook.com) et de son
[fil de référence Redrix](https://forum.chrultrabook.com/t/the-ultimate-reference-guide-running-full-linux-on-hp-elite-dragonfly-chromebook-redrix-via-submarine/8149),
de [WeirdTreeThing](https://github.com/WeirdTreeThing/chromebook-linux-audio) (audio),
[Submarine](https://github.com/FyraLabs/submarine) (Fyra Labs), du
[pilote crfpmoc de libfprint](https://gitlab.freedesktop.org/3v1n0/libfprint) de Marco Trevisan et du
[projet HP Pro c640](https://github.com/samson1357924/hp-pro-c640-chromebook-linux) de Samson,
de [Solaar](https://github.com/pwr-Solaar/Solaar), du gestionnaire haptique du pavé tactile de Chromium, de
[libwacom](https://github.com/linuxwacom/libwacom), de [libcamera](https://libcamera.org), de l'annulation d'écho
WebRTC de PipeWire et d'[Adaptive Brightness](https://github.com/dmy3k/gnome-adaptive-brightness) de dmy3k.

## Licence

MIT, voir [LICENSE](LICENSE). Les composants tiers gardent leur propre licence : [NOTICE.md](NOTICE.md).

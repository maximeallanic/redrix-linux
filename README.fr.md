# redrix-linux

Prise en charge matérielle pour Linux sur le **HP Elite Dragonfly Chromebook** (carte `redrix`, Intel Alder Lake,
famille « Brya ») : retour haptique du pavé tactile, stylet, touches de la rangée du haut, couleurs de la caméra,
micro débruité, protection des haut-parleurs, veille profonde, connexion par empreinte et logo de démarrage sans
clignotement. Chaque élément est facultatif, vérifié et réversible.

[English](README.md)

> Testé sous Debian testing (forky) avec GNOME Shell 51, le noyau 7.2 et le micrologiciel UEFI MrChromebox 2609.1.
> Ubuntu devrait fonctionner (mêmes outils de paquets) mais n'a pas été testé. Autres distributions : voir
> [l'installation](docs/installation.md#other-distributions) (en anglais).

## Installer

Depuis votre compte habituel, dans votre session GNOME :

```sh
curl -fsSL https://raw.githubusercontent.com/maximeallanic/redrix-linux/main/install.sh | bash
```

Le script télécharge une version épinglée, vérifie son SHA-256, refuse de s'exécuter sur une autre machine, puis
ouvre une liste à cocher. Ou depuis une copie du dépôt :

```sh
git clone https://github.com/maximeallanic/redrix-linux
cd redrix-linux
./install.sh --list        # ce qui est disponible sur cette machine
./install.sh --dry-run     # chaque commande qui serait lancée, sans rien changer
./install.sh               # la liste à cocher
```

Seuls les éléments à faible risque sont précochés. Les éléments à risque moyen affichent ce qu'ils modifient et
comment revenir en arrière, puis demandent confirmation. Ceux à risque élevé (connexion et démarrage) exigent de
taper leur nom. Après l'installation, les vérifications s'exécutent et indiquent ce qui demande une reconnexion ou un
redémarrage. Tous les détails : [docs/installation.md](docs/installation.md).

Retirer un élément, ou le vérifier à tout moment :

```sh
./uninstall.sh camera          # un élément (ce qui en dépend est proposé aussi)
./verify.sh                    # tous les éléments installés, une ligne par vérification
```

## Avant de commencer

Linux doit déjà être installé et démarrer : micrologiciel UEFI de MrChromebox, ou micrologiciel d'origine avec une
charge RW_LEGACY/Submarine. Le son demande d'abord la configuration audio de
[chromebook-linux-audio](https://github.com/WeirdTreeThing/chromebook-linux-audio). Le kit ne flashe aucun
micrologiciel, n'installe pas de chargeur d'amorçage et ne partitionne pas le disque ;
[docs/firmware.md](docs/firmware.md) et [docs/boot-chain.md](docs/boot-chain.md) décrivent la configuration de cette
machine, à titre de référence.

## Éléments

| Élément | Ce que vous obtenez | Risque | Précoché |
|---|---|---|---|
| [haptics](docs/components/haptics.md) | Vibrations du pavé tactile (et de la MX Master 4) sur les fenêtres, bureaux et le verrouillage | faible | oui |
| [pen](docs/components/pen.md) | Le stylet reste sur l'écran intégré avec un moniteur branché, apparaît dans Paramètres, point sous la pointe | faible | oui |
| [top-row](docs/components/top-row.md) | La touche de verrouillage verrouille au lieu de mettre en veille ; la touche plein écran fonctionne | faible | oui |
| [camera](docs/components/camera.md) | Couleurs et niveau de noir calibrés ; 32 entrées de caméra brutes inutilisables masquées | faible | oui |
| [microphone](docs/components/microphone.md) | Un micro intégré débruité, choisi comme entrée par défaut | faible | oui |
| [battery-guard](docs/components/battery-guard.md) | Pour une batterie usée qui s'éteint à quelques % : alerte à 20 %, arrêt propre à 6 % | faible | non |
| [keychron](docs/components/keychron.md) | Permet à launcher.keychron.com de configurer un clavier Keychron depuis Chrome | faible | non |
| [speakers](docs/components/speakers.md) | Fichiers de réglage des amplis extraits de l'image de récupération Google (~1,5 Go à télécharger) | moyen | non |
| [suspend](docs/components/suspend.md) | Vraie veille S3 à la fermeture du capot (micrologiciel MrChromebox seulement) ; le pavé ne la réveille plus | moyen | non |
| [fingerprint](docs/components/fingerprint.md) | Compile le pilote du capteur d'empreintes pour enregistrer des doigts ; connexion inchangée | moyen | non |
| [shutdown-splash](docs/components/shutdown-splash.md) | Fondu au noir puis logo du micrologiciel à l'arrêt et au redémarrage | moyen | non |
| [lockscreen-fingerprint](docs/components/lockscreen-fingerprint.md) | Toucher le capteur sur l'horloge de l'écran verrouillé pour déverrouiller | moyen | non |
| [fingerprint-login](docs/components/fingerprint-login.md) | Connexion, déverrouillage et `sudo` par empreinte ; le mot de passe reste valable | **élevé** | non |
| [boot-splash](docs/components/boot-splash.md) | Le logo du micrologiciel reste affiché de l'allumage à l'écran de connexion | **élevé** | non |

Ce qui fonctionne d'emblée, ce que ce kit corrige et ce qui reste cassé sur cette machine :
[docs/hardware-support.md](docs/hardware-support.md). En cas de problème :
[docs/troubleshooting.md](docs/troubleshooting.md). La documentation détaillée est en anglais.

## Sécurité

- **Connexion.** `fingerprint-login` modifie PAM. Il sauvegarde `/etc/pam.d`, passe par l'outil Debian
  `pam-auth-update`, vérifie que la connexion par mot de passe est toujours là et vous demande d'essayer `sudo` dans
  un second terminal avant de fermer le premier. Gardez un shell root ou une clé USB live sous la main la première
  fois.
- **Démarrage.** `boot-splash` reconstruit l'initramfs. Si le logo se comporte mal, choisissez un autre thème avec
  `plymouth-set-default-theme` et reconstruisez ; les commandes exactes figurent sur sa page et à l'écran de
  confirmation.
- **Micrologiciel.** Rien ici ne flashe de micrologiciel. `tools/firmware/build-firmware.sh` se contente de produire
  une image ; la flasher reste votre décision, avec votre propre sauvegarde, après lecture de
  [docs/firmware.md](docs/firmware.md).
- **Fichiers tiers.** Les fichiers des haut-parleurs de Google, libfprint et le micrologiciel sont téléchargés ou
  compilés sur votre machine, épinglés par commit ou SHA-256, jamais stockés ici. Voir [NOTICE.md](NOTICE.md).

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

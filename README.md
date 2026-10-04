# Rituel — construis des habitudes qui durent

Application **Android + Windows** (Flutter) pour créer de nouvelles habitudes, suivre ta régularité,
être relancé par des notifications 100 % personnalisables, cocher depuis un widget, et te mesurer à tes amis.

## Fonctionnalités

| | |
|---|---|
| **Habitudes** | Nom, emoji, couleur, fréquence (chaque jour / jours fixes / X fois par semaine), objectif chiffré (ex. 8 verres), notes, pause/archivage. 8 modèles prêts à l'emploi. |
| **Suivi** | Série actuelle et record, force de l'habitude (moyenne mobile qui pardonne un raté), régularité sur 30 j, calendrier « ne casse pas la chaîne » (touche un jour pour corriger), graphiques semaine par semaine et 30 jours. |
| **Rappels** | Plusieurs par habitude, à l'heure de ton choix. **Titre et texte entièrement modifiables**, avec variables : `{habitude} {emoji} {serie} {record} {pourquoi} {identite} {declencheur} {lieu} {mini} {restant} {objectif} {prenom} {n}`. Aperçu en direct + bouton « notification de test ». |
| **Mode insistant** | Relance toutes les *N* minutes (5–120), jusqu'à *M* fois, avec ta propre liste de messages qui tournent, **jusqu'à ce que l'habitude soit validée**. Plage silencieuse réglable (par défaut 23 h → 7 h). Boutons dans la notification : *✓ C'est fait*, *+1*, *🤏 Version mini*, *⏰ Plus tard*. |
| **Widgets Android** | « Aujourd'hui » (liste redimensionnable, on coche directement depuis l'écran d'accueil sans ouvrir l'app) et « Progression » (anneau du jour, série, niveau). |
| **Mini-widget Windows** | Petite fenêtre toujours au premier plan avec les habitudes du jour, à cocher (Réglages → Windows, ou l'icône en bas de la barre latérale). |
| **Psychologie** | Habitudes basées sur l'identité (« Je suis quelqu'un qui… », avec compteur de votes), intentions de mise en œuvre / empilement (« Après mon café… » + lieu), règle des 2 minutes (version mini qui compte), motivation profonde rappelée dans les notifications, « Ne rate jamais deux fois » (alerte le lendemain d'un raté), gels de série (1 offert + 1 par 7 jours parfaits), récompenses variables (messages aléatoires, confettis aux paliers), XP / niveaux / 17 badges, principe du jour. |
| **Multijoueur** | Comptes, amis (par pseudo ou code ami), voir les séries et la régularité de tes amis, face-à-face, classement général, **défis communs** (une habitude partagée par code d'invitation, avec podium et classement de régularité sur 30 jours). Chaque habitude a un interrupteur « Visible par mes amis ». |
| **Le reste** | Thème sombre/clair/auto, 6 couleurs d'accent, vibrations, export/import JSON, fonctionne entièrement hors-ligne (le multijoueur est optionnel). |

## Installer

- **Android** : copie `build/app/outputs/flutter-apk/app-release.apk` sur ton téléphone et ouvre-le (autorise « installer des applis inconnues »).
  Au premier lancement, accepte les notifications. Pour des rappels à la minute près, autorise aussi les « alarmes et rappels » (Réglages → Notifications → *Autoriser les notifications* dans l'app).
  Widgets : appui long sur l'écran d'accueil → Widgets → Rituel (ou Réglages → *Ajouter le widget*).
- **Windows** : lance `build/windows/x64/runner/Release/Rituel.exe` (garde le dossier `Release` entier, l'exe a besoin des fichiers à côté).

> Conseil Android : sur certaines marques (Xiaomi, Samsung, Huawei…), désactive l'optimisation de batterie pour Rituel, sinon le système peut retarder les rappels.

## Activer le multijoueur (5 minutes, gratuit)

Le multijoueur a besoin d'un petit serveur partagé. On utilise [Supabase](https://supabase.com) (offre gratuite).

1. Crée un compte sur supabase.com → **New project** (choisis une région Europe).
2. Menu **SQL Editor** → colle tout le contenu de [`supabase/schema.sql`](supabase/schema.sql) → **Run**.
3. Menu **Authentication → Sign In / Providers → Email** : désactive **Confirm email** (sinon chaque ami devra cliquer un lien reçu par mail avant de se connecter).
4. Menu **Project Settings → API** (ou *Data API*) : copie l'**URL du projet** et la **clé publique** (`publishable` ou `anon`).
5. Dans l'app : **Réglages → Serveur multijoueur** → colle l'URL et la clé → *Enregistrer*.
   Tes amis font la même chose (ou tu leur donnes un APK compilé avec la config intégrée, voir ci-dessous).

La sécurité est gérée par des règles côté serveur (RLS) : chacun ne peut modifier que ses données, et ne voit que les stats de ses amis (habitudes marquées visibles) et des défis qu'il a rejoints.

Pour intégrer le serveur directement dans l'app (tes amis n'auront rien à saisir) :

```powershell
flutter build apk --release --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_KEY=ta_cle_publique
```

## Compiler soi-même

Prérequis : Flutter 3.47+, SDK Android (JDK 17), et pour Windows Visual Studio Build Tools (charge de travail C++) + Mode développeur activé.

```powershell
flutter pub get
flutter test                    # tests de la logique (séries, gels, messages…)
flutter build apk --release     # Android
flutter build windows --release # Windows
flutter run                     # lancer en mode debug sur l'appareil branché
```

## Organisation du code

```
lib/
  main.dart                    démarrage, providers, cycle de vie
  core/                        thème (couleurs, typo Outfit/Inter), dates, config serveur
  models/                      Habit, Reminder, AppSettings, modèles sociaux
  data/repository.dart         stockage JSON local (utilisable depuis les tâches de fond)
  data/habit_store.dart        état de l'app (ChangeNotifier)
  logic/stats.dart             séries, force, régularité
  logic/gamification.dart      XP, niveaux, jours parfaits, gels, badges
  logic/messages.dart          variables des notifications, récompenses, principes
  services/notification_service.dart  planification des rappels + mode insistant
  services/widget_service.dart        données envoyées aux widgets Android
  services/background.dart            actions depuis notification/widget sans ouvrir l'app
  services/social_service.dart        Supabase : comptes, amis, défis, classements
  services/desktop_service.dart       fenêtre Windows + mini-widget
  ui/                          écrans et composants
android/app/src/main/kotlin/…  widgets natifs (RemoteViews)
supabase/schema.sql            schéma + règles de sécurité du serveur
```

### Comment marchent les rappels

Les rappels sont programmés sur une fenêtre glissante de 7 jours (les relances insistantes sur 2 jours),
reconstruite à chaque ouverture de l'app, modification ou validation. Valider une habitude — depuis l'app,
le widget ou le bouton de la notification — annule immédiatement les relances restantes du jour.
Si tu n'ouvres pas l'app pendant plus d'une semaine, ouvre-la une fois pour reprogrammer les rappels.

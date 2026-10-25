# Asso E-commerce

Application mobile e-commerce développée avec Flutter et GetX.

## Structure du Projet

Le projet utilise l'architecture GetX Pattern avec la structure suivante :

```
lib/
├── app/
│   ├── core/
│   │   ├── utils/          # Utilitaires et helpers
│   │   ├── values/         # Constantes et valeurs
│   │   └── widgets/        # Widgets réutilisables
│   ├── data/
│   │   ├── models/         # Modèles de données
│   │   ├── providers/      # Providers API
│   │   └── repositories/   # Repositories
│   ├── modules/
│   │   └── home/           # Module Home (exemple)
│   │       ├── bindings/   # Dependency injection
│   │       ├── controllers/# Business logic
│   │       └── views/      # UI
│   └── routes/
│       ├── app_pages.dart  # Configuration des routes
│       └── app_routes.dart # Noms des routes
├── app_theme_system.dart   # Système de thème responsive
└── main.dart               # Point d'entrée

```

## Technologies Utilisées

- **Flutter** - Framework UI
- **GetX** (^4.7.3) - State management, navigation, dependency injection
- **get_cli** (^1.9.1) - CLI pour générer du code GetX

## Fonctionnalités

- Architecture GetX Pattern propre et scalable
- Système de thème dark/light automatique
- Design responsive (mobile, tablet, desktop)
- Navigation déclarative avec GetX
- Structure prête pour l'e-commerce

## Commandes Utiles

### Générer une nouvelle page
```bash
get create page:product
```

### Générer un nouveau controller
```bash
get create controller:cart
```

### Générer un provider
```bash
get create provider:api
```

### Lancer l'application
```bash
flutter run
```

### Lancer les tests
```bash
flutter test
```

## Getting Started

1. Installer les dépendances :
   ```bash
   flutter pub get
   ```

2. Lancer l'application :
   ```bash
   flutter run
   ```

## Prochaines Étapes

Le projet est maintenant configuré et prêt pour le développement. Vous pouvez commencer à créer vos pages e-commerce (produits, panier, checkout, etc.).

## Notifications (FR / EN)

Les paramètres permettent de gérer l'activation globale et les sept catégories,
synchronisées avec le compte. Le diagnostic distingue l'autorisation du téléphone,
la disponibilité APNs et l'inscription serveur ; son bouton de test est explicite.
Les nouveautés commerciales arrivent dans un résumé quotidien ouvrant une liste
paginée. Les alertes immobilières correspondent aux critères enregistrés.

Android utilise `ic_stat_asso` (symbole blanc sur fond transparent) dans la barre
d'état, et le logo ASSO en couleur dans la notification ouverte et l'historique.
Les canaux `asso_actions_v1` et `asso_updates_v1` séparent les actions importantes
des nouveautés silencieuses. Les réglages système restent prioritaires.

Sur iOS, le relais FlutterFire est activé et l'inscription attend le token APNs,
avec des reprises limitées. Il faut distribuer une nouvelle version signée pour
appliquer ces changements natifs. La réception réelle reste à vérifier sur un
iPhone avec l'autorisation accordée, les capacités Push du profil signé et une
clé APNs valide configurée dans Firebase ; ces éléments ne sont pas validables
par les tests Dart.

Déployer d'abord l'API et ses trois migrations du 25 octobre 2026, maintenir le
scheduler Laravel, puis distribuer la version mobile. Aucune modification ne
nécessite de réinstaller l'application pour enregistrer de nouveau son appareil.

Vérification :
```bash
flutter test test/notification_preferences_test.dart test/notification_branding_test.dart test/dispute_evidence_test.dart
```

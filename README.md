# Restaurant Map App

Application mobile Flutter de gestion et de localisation de restaurants sur une carte interactive, développée lors de mon stage de développeur mobile chez **HYDROLEADER** (juillet 2025).

## Objectif

Permettre de repérer des restaurants (points d'intérêt géoréférencés), de les gérer et de s'y rendre depuis une seule application.

## Fonctionnalités

- Carte interactive avec les restaurants enregistrés
- Position GPS de l'utilisateur
- Ajout d'un restaurant en touchant la carte
- Modification des restaurants enregistrés
- Itinéraire vers un restaurant
- Recherche et filtre des restaurants

## Technologies

| Domaine | Technologies |
|---|---|
| Application mobile | Flutter, Dart |
| Carte | flutter_map, OpenStreetMap |
| Base de données | Firebase Firestore (NoSQL) |
| Plateforme testée | Android |

## Aperçu

### Carte des restaurants

<img width="246" height="475" alt="image" src="https://github.com/user-attachments/assets/77022e8c-d75f-4c00-9d1f-48b3ff6c5bef" />


### Ajout d'un restaurant

![Ajout d'un restaurant](colle ici l'image)

### Recherche et filtre

![Recherche et filtre](colle ici l'image)

### Itinéraire vers un restaurant

![Itinéraire vers un restaurant](colle ici l'image)

## Lancer le projet

### Prérequis

- Flutter SDK installé ([guide d'installation](https://docs.flutter.dev/get-started/install))
- Un émulateur Android ou un téléphone Android en mode développeur

### Installation et démarrage

```bash
git clone https://github.com/omariabdelhadi/restaurant_map_app.git
cd restaurant_map_app
flutter pub get
flutter run
```

Au premier lancement, autorise l'accès à la localisation pour afficher ta position sur la carte.

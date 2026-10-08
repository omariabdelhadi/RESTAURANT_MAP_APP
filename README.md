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

<img width="237" height="490" alt="image" src="https://github.com/user-attachments/assets/08978483-d67c-401d-a1e2-b6dba898a3fd" />


### Recherche et filtre

<img width="273" height="586" alt="image" src="https://github.com/user-attachments/assets/394395f6-af31-48d4-89e6-0f2dd99823d3" />


### Itinéraire vers un restaurant

<img width="214" height="425" alt="image" src="https://github.com/user-attachments/assets/a50da3c2-8909-4cec-8fb2-0188e3005627" />


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

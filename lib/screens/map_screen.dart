// map_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:math' show pow;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../models/restaurant_model.dart';
import '../models/geometry_model.dart';
import 'dart:convert';
import 'dart:async';
import '../services/session_manager.dart';
import '../widgets/restaurant_form.dart';
import '../widgets/map_widgets.dart';
import '../services/local_db_sqlite.dart';
import '../widgets/restaurant_details.dart';
import 'package:http/http.dart' as http;

// Décodeur de polyline simplifié
List<LatLng> _decodePolyline(String encoded) {
  List<LatLng> points = [];
  int index = 0, len = encoded.length;
  int lat = 0, lng = 0;

  while (index < len) {
    int shift = 0, result = 0;
    int byte;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1F) << shift;
      shift += 5;
    } while (byte >= 0x20);
    int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1F) << shift;
      shift += 5;
    } while (byte >= 0x20);
    int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    points.add(LatLng(lat / 1E5, lng / 1E5));
  }
  return points;
}


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  final List<MapGeometry> _geometries = [];
  final List<Restaurant> _restaurants = [];
  List<Restaurant> _filteredRestaurants = [];
  List<LatLng> _currentPoints = [];
  LatLng? _currentUserLocation;
  GeometryType _selectedGeometryType = GeometryType.point;
  bool _isDrawing = false;
  bool _isLoading = true;
  StreamSubscription<Position>? _positionStreamSubscription;
  // For smooth location updates
  final _locationUpdateController = StreamController<LatLng>.broadcast();
  StreamSubscription<LatLng>? _smoothLocationSubscription;
  bool _isRouteSelectionMode = false; // Pour le mode de sélection d'itinéraire
  String? _currentUserId; // Pour stocker l'ID de l'utilisateur connecté
  double _circleRadius = 100.0;
  String? _selectedGeometryId; // Ajout pour la sélection
  List<LatLng>? _currentRoute; // Pour stocker l'itinéraire actuel

  // Ajout des styles de carte
  final List<_MapLayerOption> _mapLayers = [
    _MapLayerOption(
      name: 'Standard',
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      attribution: '© OpenStreetMap contributors',
    ),
    _MapLayerOption(
      name: 'Satellite',
      urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      attribution: 'Tiles © Esri',
    ),
    _MapLayerOption(
      name: 'Terrain',
      urlTemplate: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
      attribution: '© OpenTopoMap contributors',
    ),
  ];
  int _selectedLayerIndex = 0;

  Color _getGeometryColor(MapGeometry geometry) {
    if (geometry.id == _selectedGeometryId) {
      return Colors.red;
    }
    // La géométrie appartient à l'utilisateur actuel
    if (geometry.userId == _currentUserId) {
      return Colors.blue;
    }
    // La géométrie appartient à un autre utilisateur
    return Colors.grey;
  }

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _searchController.addListener(_filterRestaurants);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _positionStreamSubscription?.cancel();
    _smoothLocationSubscription?.cancel();
    _locationUpdateController.close();
    super.dispose();
  }

  void _filterRestaurants() {
    setState(() {
      if (_searchController.text.isEmpty) {
        _filteredRestaurants = List.from(_restaurants);
      } else {
        final searchText = _searchController.text.toLowerCase();
        _filteredRestaurants = _restaurants
            .where((restaurant) => restaurant.name
                .toLowerCase()
                .startsWith(searchText))
            .toList();
      }
    });
  }

  Future<void> _initializeMap() async {
    try {
      await _loadData();
      // Initialisation de la carte sans zoomer sur la localisation
      _mapController.move(const LatLng(0, 0), 2.0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    try {
      _currentUserId = Provider.of<SessionManager>(context, listen: false).currentUser?.id ?? '';
      debugPrint('Chargement des données pour l\'utilisateur: $_currentUserId');
      
      // Charger les restaurants pour tous les utilisateurs
      final restaurantMaps = await LocalDbSqlite.getAllRestaurants();
      debugPrint('Données des restaurants récupérées: $restaurantMaps');
      
      final List<Restaurant> loadedRestaurants = restaurantMaps.map((r) {
        List<String> imagesList = [];
        if (r['imageData'] != null && r['imageData'].toString().isNotEmpty) {
          imagesList = (r['imageData'] as String).split(',').where((img) => img.isNotEmpty).toList();
        }
        
        // Convertir les listes de chaînes
        List<String> cuisineTypes = [];
        if (r['cuisineTypes'] != null && r['cuisineTypes'].toString().isNotEmpty) {
          cuisineTypes = (r['cuisineTypes'] as String).split(',').where((s) => s.isNotEmpty).toList();
        }
        
        List<String> availableServices = [];
        if (r['availableServices'] != null && r['availableServices'].toString().isNotEmpty) {
          availableServices = (r['availableServices'] as String).split(',').where((s) => s.isNotEmpty).toList();
        }
        
        List<String> paymentMethods = [];
        if (r['paymentMethods'] != null && r['paymentMethods'].toString().isNotEmpty) {
          paymentMethods = (r['paymentMethods'] as String).split(',').where((s) => s.isNotEmpty).toList();
        }
        
        return Restaurant(
          id: r['id'] as String,
          name: r['name'] as String,
          description: r['description'] as String?,
          images: imagesList,
          coordinates: LatLng(
            (r['coordinates_lat'] as num).toDouble(),
            (r['coordinates_lng'] as num).toDouble(),
          ),
          createdAt: DateTime.parse(r['createdAt'] as String),
          updatedAt: DateTime.parse(r['updatedAt'] as String),
          userId: r['userId'] as String,
          isOpen: (r['isOpen'] as num?) == 1,
          employeeCount: r['employeeCount'] as int?,
          ownerName: r['ownerName'] as String?,
          ownerDegrees: r['ownerDegrees'] as String?,
          openingYear: r['openingYear'] as int?,
          signatureDishes: r['signatureDishes'] as String?,
          cuisineTypes: cuisineTypes,
          availableServices: availableServices,
          paymentMethods: paymentMethods,
          priceRange: r['priceRange'] as String?,
          noiseLevel: r['noiseLevel'] as String?,
          atmosphere: r['atmosphere'] as String?,
          rating: r['rating'] != null ? (r['rating'] is String ? int.tryParse(r['rating'].toString()) : r['rating'] as int?) : null,
          ratingComment: r['ratingComment'] as String?,
        );
      }).toList();

      debugPrint('${loadedRestaurants.length} restaurants chargés avec détails complets');
      
      setState(() {
        _restaurants.clear();
        _restaurants.addAll(loadedRestaurants);
        _filteredRestaurants = List.from(loadedRestaurants);
      });
      
      // Charger toutes les géométries
      final geometryMaps = await LocalDbSqlite.getGeometries();
      debugPrint('${geometryMaps.length} géométries trouvées dans la base de données');
      
      final geometries = <MapGeometry>[];
      
      for (final g in geometryMaps) {
        try {
          // Vérifier les champs requis
          if (g['id'] == null || g['type'] == null) {
            print('Géométrie invalide trouvée: ${g.toString()}');
            continue;
          }

          // Convertir la chaîne JSON des points en List
          List<LatLng> points = [];
          try {
            final pointsString = g['points'] as String;
            if (pointsString.isNotEmpty) {
              final decoded = jsonDecode(pointsString) as List;
              points = decoded.map((point) {
                final lat = point['latitude'] as num;
                final lng = point['longitude'] as num;
                return LatLng(lat.toDouble(), lng.toDouble());
              }).toList();
            }
          } catch (e) {
            print('Erreur lors de la conversion des points: $e');
            continue;
          }

          // Si c'est un cercle ou un point et qu'il n'y a pas de points, skip
          if ((g['type'] == 'circle' || g['type'] == 'point') && points.isEmpty) {
            print('Géométrie circle/point sans points trouvée');
            continue;
          }

          // Si c'est une ligne ou un polygone et qu'il y a moins de 2 points, skip
          if ((g['type'] == 'polyline' || g['type'] == 'polygon') && points.length < 2) {
            print('Géométrie polyline/polygon avec moins de 2 points trouvée');
            continue;
          }

          // Convertir le type
          GeometryType type;
          switch (g['type'].toString().toLowerCase()) {
            case 'point':
              type = GeometryType.point;
              break;
            case 'polyline':
              type = GeometryType.polyline;
              break;
            case 'polygon':
              type = GeometryType.polygon;
              break;
            case 'circle':
              type = GeometryType.circle;
              break;
            default:
              print('Type de géométrie inconnu: ${g['type']}');
              continue;
          }

          // Créer la géométrie
          final geometry = MapGeometry(
            id: g['id'] as String,
            type: type,
            points: points,
            radius: g['radius'] != null ? (g['radius'] as num).toDouble() : null,
            name: g['name'] as String?,
            description: g['description'] as String?,
            createdAt: DateTime.parse(g['createdAt'] as String),
            userId: g['userId'] as String,
          );

          geometries.add(geometry);
        } catch (e) {
          print('Erreur lors du traitement d\'une géométrie: $e');
          continue;
        }
      }

      print('${geometries.length} géométries valides chargées');

      if (mounted) {
        setState(() {
          _restaurants.clear();
          _restaurants.addAll(loadedRestaurants);
          _filteredRestaurants = List.from(loadedRestaurants);
          _geometries.clear();
          _geometries.addAll(geometries);
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Erreur lors du chargement des données: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des données: $e')),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('La permission de localisation est requise')),
            );
          }
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Les permissions de localisation sont désactivées de façon permanente. Veuillez les activer dans les paramètres.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Afficher un dialogue explicatif
        if (mounted) {
          final shouldOpenSettings = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Localisation désactivée'),
                content: const Text(
                  'Pour utiliser la localisation, vous devez l\'activer dans les paramètres de votre appareil. Voulez-vous ouvrir les paramètres maintenant ?'
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Plus tard'),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  TextButton(
                    child: const Text('Ouvrir les paramètres'),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              );
            },
          );

          if (shouldOpenSettings == true) {
            await Geolocator.openLocationSettings();
            // Attendre que l'utilisateur revienne à l'application
            await Future.delayed(const Duration(seconds: 3));
            // Vérifier à nouveau si la localisation est activée
            serviceEnabled = await Geolocator.isLocationServiceEnabled();
            if (!serviceEnabled && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Veuillez activer la localisation et réessayer.'),
                  duration: Duration(seconds: 3),
                ),
              );
              return;
            }
          } else {
            return; // L'utilisateur ne souhaite pas activer la localisation maintenant
          }
        }
      }

      // Obtenir la position initiale
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final userLocation = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _currentUserLocation = userLocation;
        });
        
        _mapController.move(
          userLocation,
          18.0,
        );
      }

      // Annuler les anciennes souscriptions s'il y en a
      await _positionStreamSubscription?.cancel();
      await _smoothLocationSubscription?.cancel();

      // Commencer à écouter les mises à jour de position avec une fréquence plus élevée
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0, // Pas de filtre de distance minimum
          intervalDuration: const Duration(milliseconds: 100), // Mises à jour très fréquentes
          forceLocationManager: true, // Utilise le gestionnaire de localisation natif
        ),
      ).listen(
        (Position position) {
          final newLocation = LatLng(position.latitude, position.longitude);
          _locationUpdateController.add(newLocation);
        },
        onError: (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur de suivi de localisation: $e')),
            );
          }
        },
      );

      // Configuration de l'animation fluide avec une approche plus sophistiquée
      _smoothLocationSubscription = _locationUpdateController.stream
          .distinct() // Évite les mises à jour en double
          .transform(StreamTransformer.fromHandlers(
            handleData: (LatLng target, EventSink<LatLng> sink) {
              if (_currentUserLocation == null) {
                sink.add(target);
                return;
              }

              const steps = 60; // Plus d'étapes pour une animation plus fluide
              const totalDuration = Duration(milliseconds: 1000);
              final stepDuration = totalDuration ~/ steps;
              
              final startLat = _currentUserLocation!.latitude;
              final startLng = _currentUserLocation!.longitude;
              
              // Utilisation d'une courbe d'accélération pour un mouvement plus naturel
              for (var i = 0; i < steps; i++) {
                if (!mounted) break;
                
                // Utilisation d'une fonction d'accélération
                final progress = _easeInOutQuad(i / steps);
                
                final interpolatedLocation = LatLng(
                  startLat + (target.latitude - startLat) * progress,
                  startLng + (target.longitude - startLng) * progress,
                );
                
                Future.delayed(stepDuration * i).then((_) {
                  if (mounted) {
                    sink.add(interpolatedLocation);
                  }
                });
              }
            },
          ))
          .listen((location) {
            if (mounted) {
              setState(() {
                _currentUserLocation = location;
              });
            }
          });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de localisation: $e')),
        );
      }
    }
  }

  void _handleTap(TapPosition _, LatLng point) {
    if (_isRouteSelectionMode) {
      if (_currentUserLocation != null) {
        _showRoute(Restaurant(
          id: '',
          name: 'Destination personnalisée',
          description: '',
          images: [],
          coordinates: point,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          userId: '',
          isOpen: true,
        ));
        setState(() {
          _isRouteSelectionMode = false;
        });
      }
      return;
    }
    
    if (_isDrawing) {
      setState(() {
        if (_selectedGeometryType == GeometryType.point || _selectedGeometryType == GeometryType.circle) {
          _currentPoints = [point];
        } else {
          _currentPoints.add(point);
        }
      });
    } else {
      // Détection du clic sur une géométrie existante
      const double tolerance = 0.0005; // Ajustez selon le niveau de zoom
      String? foundGeometryId;
      for (final g in _geometries) {
        switch (g.type) {
          case GeometryType.polyline:
          case GeometryType.polygon:
            for (final p in g.points) {
              if ((p.latitude - point.latitude).abs() < tolerance && (p.longitude - point.longitude).abs() < tolerance) {
                foundGeometryId = g.id;
                break;
              }
            }
            break;
          case GeometryType.circle:
            final center = g.points.first;
            final distanceInMeters = Distance().as(LengthUnit.Meter, center, point);
            if (distanceInMeters <= (g.radius ?? 100.0)) {
              foundGeometryId = g.id;
            }
            break;
          default:
            break;
        }
        if (foundGeometryId != null) break;
      }

      setState(() {
        if (foundGeometryId != null) {
          // Si on clique sur une forme, afficher directement sa description
          final geometry = _geometries.firstWhere((g) => g.id == foundGeometryId);
          _showGeometryDescription(geometry);
        } else {
          // Si on clique ailleurs, désélectionner la forme actuelle
          _selectedGeometryId = null;
        }
      });
      if (foundGeometryId != null) return;

      // Vérifier si on a cliqué sur un restaurant
      const double restaurantTolerance = 0.0005; // Tolérance pour la détection du clic
      
      // Trouver tous les restaurants proches du point cliqué
      final nearbyRestaurants = _restaurants.where(
        (r) => 
          (r.coordinates.latitude - point.latitude).abs() <= restaurantTolerance &&
          (r.coordinates.longitude - point.longitude).abs() <= restaurantTolerance
      ).toList();

      if (nearbyRestaurants.isNotEmpty) {
        // S'il y a des restaurants proches, prendre le plus proche
        _showRestaurantDetails(nearbyRestaurants.first);
      }
    }
  }

  void _handleLongPress(TapPosition _, LatLng point) {
    if (_isDrawing) return;

    // Détection du clic long sur une géométrie existante
    const double tolerance = 0.0005; // Ajustez selon le niveau de zoom
    String? foundGeometryId;
    for (final g in _geometries) {
      switch (g.type) {
        case GeometryType.polyline:
        case GeometryType.polygon:
          for (final p in g.points) {
            if ((p.latitude - point.latitude).abs() < tolerance && (p.longitude - point.longitude).abs() < tolerance) {
              foundGeometryId = g.id;
              break;
            }
          }
          break;
        case GeometryType.circle:
          final center = g.points.first;
          final distanceInMeters = Distance().as(LengthUnit.Meter, center, point);
          if (distanceInMeters <= (g.radius ?? 100.0)) {
            foundGeometryId = g.id;
          }
          break;
        default:
          break;
      }
      if (foundGeometryId != null) break;
    }

    setState(() {
      if (foundGeometryId != null) {
        // Si on fait un clic long sur une forme, la sélectionner pour suppression
        _selectedGeometryId = foundGeometryId;
      } else {
        // Si on fait un clic long ailleurs, ajouter un restaurant
        _addRestaurant(point);
      }
    });
  }

  Future<void> _showRoute(Restaurant restaurant) async {
    if (_currentUserLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord définir votre position en cliquant sur le bouton de localisation.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);
      
      // Utiliser OSRM pour obtenir l'itinéraire
      final response = await http.get(Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_currentUserLocation!.longitude},${_currentUserLocation!.latitude};'
        '${restaurant.coordinates.longitude},${restaurant.coordinates.latitude}'
        '?overview=full&geometries=polyline'
      ));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          // Décoder la géométrie de l'itinéraire (format polyline)
          final String geometry = data['routes'][0]['geometry'];
          // Décoder la géométrie de l'itinéraire
          final route = _decodePolyline(geometry);
          
          setState(() {
            _currentRoute = route;
          });

          // Ajuster la vue de la carte pour montrer l'itinéraire complet
          final bounds = LatLngBounds.fromPoints(route);
          _mapController.fitBounds(
            bounds,
            options: const FitBoundsOptions(padding: EdgeInsets.all(50.0)),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du calcul de l\'itinéraire: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showRestaurantDetails(Restaurant restaurant) {
    // Effacer l'itinéraire existant quand on sélectionne un nouveau restaurant
    setState(() {
      _currentRoute = null;
    });
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantDetails(
          restaurant: restaurant,
          currentUserId: _currentUserId ?? '',
          onEdit: restaurant.userId == _currentUserId ? () => _showRestaurantForm(restaurant) : null,
          onDeleted: restaurant.userId == _currentUserId ? () {
            setState(() {
              _restaurants.removeWhere((r) => r.id == restaurant.id);
              _filteredRestaurants = List.from(_restaurants);
            });
            _loadData(); // Recharger les données après la suppression
          } : null,
          onRoute: () {
            Navigator.pop(context); // Fermer la fenêtre de détails
            _showRoute(restaurant);
          },
        ),
      ),
    );
  }

  void _showRestaurantForm(Restaurant? restaurant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(restaurant == null ? 'Ajouter un restaurant' : 'Modifier le restaurant'),
          ),
          body: RestaurantForm(
            restaurant: restaurant,
            initialLocation: restaurant?.coordinates ?? _mapController.center,
            onSubmit: (Restaurant newRestaurant) async {
              await _handleRestaurantSubmit(newRestaurant, isEdit: restaurant != null);
              if (mounted) {
                // Fermer tous les écrans et revenir à la carte
                Navigator.popUntil(context, (route) => route.isFirst);
                // Recharger les données après la modification
                await _loadData();
                // Centrer la carte sur le restaurant modifié
                _mapController.move(newRestaurant.coordinates, _mapController.zoom);
              }
            },
          ),
        ),
      ),
    );
  }

  void _startDrawing(GeometryType type) {
    if (type == GeometryType.point) return; // Désactive le mode Point
    setState(() {
      _isDrawing = true;
      _selectedGeometryType = type;
      _currentPoints = [];
      if (type == GeometryType.circle) {
        // Ajuster le rayon initial en fonction du niveau de zoom
        final zoom = _mapController.zoom;
        // À un zoom de 1, nous voulons un rayon de base de 500m
        // Le rayon est multiplié par 2 pour chaque niveau de zoom en moins
        _circleRadius = 500.0 * pow(2, (13 - zoom));
      }
    });
  }

  void _finishDrawing() async {
    if (_currentPoints.isEmpty) return;

    // Vérifier si nous avons assez de points
    if (_selectedGeometryType == GeometryType.polyline || _selectedGeometryType == GeometryType.polygon) {
      if (_currentPoints.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Il faut au moins 2 points pour créer une ${_selectedGeometryType == GeometryType.polyline ? "ligne" : "polygone"}')),
        );
        return;
      }
    }

    try {
      final geometry = MapGeometry(
        id: DateTime.now().toIso8601String(),
        type: _selectedGeometryType,
        points: List.from(_currentPoints),
        radius: _selectedGeometryType == GeometryType.circle ? _circleRadius : null,
        description: '',  // Initialiser avec une chaîne vide
        createdAt: DateTime.now(),
        userId: Provider.of<SessionManager>(context, listen: false).currentUser?.id ?? '',
      );

      // Convertir les points en format JSON
      final pointsJson = geometry.points.map((point) => {
        'latitude': point.latitude,
        'longitude': point.longitude,
      }).toList();

      // Convertir le type en string
      String typeStr;
      switch (geometry.type) {
        case GeometryType.point:
          typeStr = 'point';
          break;
        case GeometryType.polyline:
          typeStr = 'polyline';
          break;
        case GeometryType.polygon:
          typeStr = 'polygon';
          break;
        case GeometryType.circle:
          typeStr = 'circle';
          break;
      }

      // Préparer les données pour la base de données
      final geometryData = {
        'id': geometry.id,
        'type': typeStr,
        'points': jsonEncode(pointsJson),
        'radius': geometry.radius,
        'description': geometry.description,
        'createdAt': geometry.createdAt.toIso8601String(),
        'userId': geometry.userId,
      };

      print('Sauvegarde de la géométrie: $typeStr avec ${pointsJson.length} points');

      // Sauvegarder dans la base de données
      await LocalDbSqlite.insertGeometry(geometryData);

      setState(() {
        _geometries.add(geometry);
        _isDrawing = false;
        _currentPoints = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Forme géométrique sauvegardée avec succès')),
      );
    } catch (e) {
      print('Erreur lors de la sauvegarde de la géométrie: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde: $e')),
      );
    }
  }

  void _cancelDrawing() {
    setState(() {
      _isDrawing = false;
      _currentPoints = [];
    });
  }

  Future<void> _addRestaurant(LatLng location) async {
    final result = await Navigator.push<Restaurant>(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Ajouter un restaurant'),
          ),
          body: RestaurantForm(
            initialLocation: location,
            onSubmit: (restaurant) {
              Navigator.of(context).pop(restaurant);
            },
          ),
        ),
      ),
    );

    if (result != null) {
      try {
        final insertResult = await LocalDbSqlite.insertRestaurant(result.toJson());
        
        if (insertResult > 0) {
          setState(() {
            _restaurants.add(result);
            if (_searchController.text.isEmpty ||
                result.name.toLowerCase().contains(_searchController.text.toLowerCase())) {
              _filteredRestaurants.add(result);
            }
          });

          // Centre la carte sur le nouveau restaurant
          _mapController.move(result.coordinates, _mapController.zoom);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Restaurant ajouté avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Échec de l\'ajout du restaurant');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde : ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        print('Erreur lors de la sauvegarde du restaurant : ${e.toString()}');
      }
    }
  }



  Future<void> _deleteSelectedGeometry() async {
    if (_selectedGeometryId == null) return;
    final geometry = _geometries.firstWhere((g) => g.id == _selectedGeometryId);
    
    // Vérifier si l'utilisateur est le propriétaire de la géométrie
    if (geometry.userId != _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous ne pouvez supprimer que vos propres formes géométriques'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Supprimer de la base de données
    await LocalDbSqlite.deleteGeometry(geometry.id);
    
    setState(() {
      _geometries.removeWhere((g) => g.id == geometry.id);
      _selectedGeometryId = null;
    });
  }

  void _zoomIn() {
    final currentZoom = _mapController.zoom;
    _mapController.move(_mapController.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.zoom;
    _mapController.move(_mapController.center, currentZoom - 1);
  }

  void _clearRoute() {
    setState(() {
      _currentRoute = null;
    });
  }

  Future<void> _showGeometryDescription(MapGeometry geometry) async {
    final TextEditingController descController = TextEditingController(text: geometry.description);
    final bool isOwner = geometry.userId == _currentUserId;

    if (!isOwner) {
      // Si l'utilisateur n'est pas le propriétaire, montrer seulement la description en lecture seule
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Description'),
          content: geometry.description?.isNotEmpty == true
            ? Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(geometry.description!),
              )
            : const Text('Aucune description'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
      return;
    }

    final isEditingMode = ValueNotifier<bool>(false);
    

    final result = await showDialog<String>(
  context: context,
  builder: (context) => StatefulBuilder(
    builder: (context, setDialogState) {
      final hasDescription = descController.text.isNotEmpty;
      
      return ValueListenableBuilder<bool>(
        valueListenable: isEditingMode,
        builder: (context, isEditing, _) {
          return SizedBox(
            width: 400,
            child: AlertDialog(
              title: Text(geometry.description?.isNotEmpty == true
                  ? 'Description de la forme'
                  : 'Ajouter une description'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!hasDescription || isEditing)
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        hintText: 'Entrez une description...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      enabled: isOwner && (!hasDescription || isEditing),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(descController.text),
                    ),
                  if (hasDescription && isOwner) ...[
                    const SizedBox(height: 16),
                    // Remplacer Wrap par Column + Row pour éviter l'overflow
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 4.0),
                                child: ElevatedButton.icon(
                                  icon: Icon(isEditing ? Icons.save : Icons.edit, size: 18),
                                  label: Text(
                                    isEditing ? 'garder' : 'Modifier',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () async {
                                    if (isEditing) {
                                      // Sauvegarder les modifications dans la base de données
                                      final updatedGeometry = MapGeometry(
                                        id: geometry.id,
                                        type: geometry.type,
                                        points: geometry.points,
                                        radius: geometry.radius,
                                        name: geometry.name,
                                        description: descController.text,
                                        createdAt: geometry.createdAt,
                                        userId: geometry.userId,
                                      );

                                      // Convertir les points en format JSON
                                      final pointsJson = updatedGeometry.points.map((point) => {
                                        'latitude': point.latitude,
                                        'longitude': point.longitude,
                                      }).toList();

                                      // Préparer les données pour la mise à jour
                                      final updateData = {
                                        'type': updatedGeometry.type.toString().split('.').last,
                                        'points': jsonEncode(pointsJson),
                                        'radius': updatedGeometry.radius,
                                        'description': updatedGeometry.description,
                                        'name': updatedGeometry.name,
                                      };

                                      // Mettre à jour la base de données
                                      await LocalDbSqlite.updateGeometry(geometry.id, updateData);

                                      // CORRECTION: Utiliser setState() au lieu de Navigator.of(context).setState()
                                      setState(() {
                                        final index = _geometries.indexWhere((g) => g.id == geometry.id);
                                        if (index != -1) {
                                          _geometries[index] = updatedGeometry;
                                        }
                                      });
                                      
                                      isEditingMode.value = false;
                                    } else {
                                      // Entrer en mode édition
                                      isEditingMode.value = true;
                                    }
                                    setDialogState(() {});
                                  },
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.delete, size: 18),
                                  label: const Text(
                                    'Supprimer',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    descController.clear();
                                    isEditingMode.value = false;
                                    setDialogState(() {});
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ), // CORRECTION: Parenthèse fermante pour Column content
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                if (!hasDescription || isEditing)
                  TextButton(
                    onPressed: () => Navigator.pop(context, descController.text),
                    child: const Text('OK'),
                  ),
              ],
            ), // CORRECTION: Parenthèse fermante pour AlertDialog
          ); // CORRECTION: Parenthèse fermante pour SizedBox
        },
      ); // CORRECTION: Parenthèse fermante pour ValueListenableBuilder
    },
  ), // CORRECTION: Parenthèse fermante pour StatefulBuilder
); // CORRECTION: Parenthèse fermante pour showDialog
    if (result != null) {
      final updatedGeometry = MapGeometry(
        id: geometry.id,
        type: geometry.type,
        points: geometry.points,
        radius: geometry.radius,
        name: geometry.name,
        description: result,
        createdAt: geometry.createdAt,
        userId: geometry.userId,
      );

      // Convertir les points en format JSON
      final pointsJson = updatedGeometry.points.map((point) => {
        'latitude': point.latitude,
        'longitude': point.longitude,
      }).toList();

      // Préparer les données pour la mise à jour
      final updateData = {
        'type': updatedGeometry.type.toString().split('.').last,
        'points': jsonEncode(pointsJson),
        'radius': updatedGeometry.radius,
        'description': updatedGeometry.description,
        'name': updatedGeometry.name,
      };

      // Mettre à jour la base de données
      await LocalDbSqlite.updateGeometry(geometry.id, updateData);

      // Mettre à jour l'état
      setState(() {
        final index = _geometries.indexWhere((g) => g.id == geometry.id);
        if (index != -1) {
          _geometries[index] = updatedGeometry;
        }
      });
    }
  }

  // Fonction d'accélération pour une animation fluide
  double _easeInOutQuad(double t) {
    return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
  }

  Future<void> _handleRestaurantSubmit(Restaurant restaurant, {bool isEdit = false}) async {
    try {
      final data = restaurant.toJson();
      debugPrint('Données avant soumission:');
      debugPrint('Rating: ${data['rating']}');
      debugPrint('RatingComment: ${data['ratingComment']}');

      if (isEdit) {
        // Récupérer les données existantes du restaurant
        final existingData = await LocalDbSqlite.getRestaurant(restaurant.id);
        
        if (existingData != null) {
          // Si les champs rating et ratingComment ne sont pas explicitement modifiés,
          // conserver les valeurs existantes
          if (!data.containsKey('rating') || data['rating'] == null) {
            data['rating'] = existingData['rating'];
          }
          if (!data.containsKey('ratingComment') || 
              data['ratingComment'] == null || 
              data['ratingComment'].toString().trim().isEmpty) {
            data['ratingComment'] = existingData['ratingComment'];
          }
        }
        
        // Log pour le débogage
        debugPrint('Données finales à sauvegarder:');
        debugPrint('Rating final: ${data['rating']}');
        debugPrint('RatingComment final: ${data['ratingComment']}');
      }

      if (isEdit) {
        await LocalDbSqlite.updateRestaurant(restaurant.id, data);
      } else {
        final newId = await LocalDbSqlite.insertRestaurant(data);
        // Mettre à jour l'ID du restaurant avec celui généré par la base de données
        restaurant = restaurant.copyWith(id: newId.toString());
      }

      // Mettre à jour la liste des restaurants en mémoire
      setState(() {
        if (isEdit) {
          final index = _restaurants.indexWhere((r) => r.id == restaurant.id);
          if (index != -1) {
            _restaurants[index] = restaurant;
          }
        } else {
          _restaurants.add(restaurant);
        }
        _filteredRestaurants = List.from(_restaurants);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Restaurant modifié' : 'Restaurant ajouté'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = [
      // Marqueur de la position actuelle de l'utilisateur
      if (_currentUserLocation != null)
        Marker(
          point: _currentUserLocation!,
          width: 20,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  spreadRadius: 2,
                )
              ],
            ),
          ),
        ),
      ..._filteredRestaurants.map(
        (restaurant) => Marker(
          point: restaurant.coordinates,
          width: 36,
          height: 36,
          child: GestureDetector(
            onTap: () => _showRestaurantDetails(restaurant),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: restaurant.isOpen ? Colors.green.withOpacity(0.8) : Colors.red.withOpacity(0.8),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: Opacity(
                opacity: restaurant.userId == _currentUserId ? 1.0 : 0.6,
                child: Icon(Icons.restaurant, 
                  color: Colors.white, 
                  size: 28),
              ),
            ),
          ),
        ),
      ),
      if (_isDrawing && _selectedGeometryType != GeometryType.circle)
        ..._currentPoints.map(
          (point) => Marker(
            point: point,
            width: 10,
            height: 10,
            child: const CircleAvatar(
              backgroundColor: Colors.blue,
              radius: 5,
            ),
          ),
        ),
    ];

    // Ajout du cercle temporaire dans la liste des cercles
    final circles = [
      ..._geometries
        .where((g) => g.type == GeometryType.circle)
        .map((g) => CircleMarker(
              point: g.points.first,
              radius: g.radius ?? 100.0,
              color: _getGeometryColor(g).withOpacity(0.2),
              borderColor: _getGeometryColor(g),
              borderStrokeWidth: 2.0,
              useRadiusInMeter: true,
            )),
      if (_isDrawing && _selectedGeometryType == GeometryType.circle && _currentPoints.isNotEmpty)
        CircleMarker(
          point: _currentPoints.first,
          radius: _circleRadius,
          color: Colors.blue.withOpacity(0.2),
          borderColor: Colors.blue,
          borderStrokeWidth: 2.0,
          useRadiusInMeter: true,
        ),
    ];

    // Affichage des géométries sans onTap
    final polylines = [
      ..._geometries
        .where((g) => g.type == GeometryType.polyline)
        .map((g) => Polyline(
              points: g.points,
              color: _getGeometryColor(g),
              strokeWidth: 3,
            )),
      if (_currentRoute != null)
        Polyline(
          points: _currentRoute!,
          color: Colors.green,
          strokeWidth: 4,
        ),
    ];
    final polygons = _geometries
      .where((g) => g.type == GeometryType.polygon)
      .map((g) => Polygon(
            points: g.points,
            color: _getGeometryColor(g).withOpacity(0.2),
            borderColor: _getGeometryColor(g),
            borderStrokeWidth: 2.0,
          ))
      .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () {
              Provider.of<SessionManager>(context, listen: false).logout();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(0, 0),
              initialZoom: 2.0,
              onTap: _handleTap,
              onLongPress: (position, latlng) => _handleLongPress(position, latlng),
            ),
            children: [
              TileLayer(
                urlTemplate: _mapLayers[_selectedLayerIndex].urlTemplate,
                userAgentPackageName: 'com.example.restaurant_map_app',
              ),
              PolylineLayer(polylines: polylines),
              PolygonLayer(polygons: polygons),
              CircleLayer(circles: circles),
              MarkerLayer(markers: markers),
            ],
          ),
          // Bouton d'effacement d'itinéraire et bouton de localisation
          Positioned(
            left: 16,
            top: MediaQuery.of(context).size.height * 0.5, // Position au milieu à gauche
            child: Column(
              children: [
                if (_currentRoute != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearRoute,
                        tooltip: 'Effacer l\'itinéraire',
                        color: Colors.red,
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.my_location),
                    onPressed: _getCurrentLocation,
                    tooltip: 'Ma position',
                  ),
                ),
              ],
            ),
          ),
          // Boutons de zoom
          Positioned(
            right: 16,
            top: MediaQuery.of(context).size.height * 0.4, // Position à 40% de la hauteur
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _zoomIn,
                    tooltip: 'Zoomer',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 1), // Petit espace entre les boutons
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _zoomOut,
                    tooltip: 'Dézoomer',
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          // Barre d'outils des formes géométriques
          if (_isDrawing)
            Positioned(
              top: 80, // Déplacé plus bas
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Center(
                      child: GeometryToolbar(
                        selectedType: _selectedGeometryType,
                        onTypeSelected: (type) {
                          if (type != GeometryType.point) {
                            _startDrawing(type);
                          }
                        },
                        onFinish: _finishDrawing,
                        onCancel: _cancelDrawing,
                      ),
                    ),
                    if (_selectedGeometryType == GeometryType.circle && _currentPoints.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          children: [
                            Text('Rayon du cercle : ${_circleRadius.toStringAsFixed(0)} m'),
                            Slider(
                              min: 100.0 * pow(2, (13 - _mapController.zoom)),
                              max: 1000.0 * pow(2, (13 - _mapController.zoom)),
                              divisions: 18,
                              value: _circleRadius,
                              label: _circleRadius.toStringAsFixed(0),
                              onChanged: (value) {
                                setState(() {
                                  _circleRadius = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          // Barre de recherche en bas
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher un restaurant...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          // Sélecteur de style de carte
          Positioned(
            top: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: DropdownButton<int>(
                  value: _selectedLayerIndex,
                  underline: const SizedBox(),
                  items: List.generate(_mapLayers.length, (i) => DropdownMenuItem(
                    value: i,
                    child: Text(_mapLayers[i].name),
                  )),
                  onChanged: (i) {
                    if (i != null) setState(() => _selectedLayerIndex = i);
                  },
                ),
              ),
            ),
          ),
          // Bouton de suppression flottant
          if (_selectedGeometryId != null)
            (() {
              final selectedGeometry = _geometries.firstWhere(
                (g) => g.id == _selectedGeometryId,
                orElse: () => MapGeometry(
                  id: '',
                  type: GeometryType.point,
                  points: [],
                  createdAt: DateTime.now(),
                  userId: '',
                ),
              );
              final isOwner = selectedGeometry.userId == _currentUserId && selectedGeometry.id.isNotEmpty;
              return Positioned(
                top: 80,
                right: 24,
                child: FloatingActionButton.small(
                  backgroundColor: isOwner ? Colors.red : Colors.grey.shade400,
                  onPressed: isOwner
                      ? () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Supprimer la forme ?'),
                              content: const Text('Voulez-vous vraiment supprimer cette forme ?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Annuler'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Supprimer'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _deleteSelectedGeometry();
                          }
                        }
                      : null,
                  child: const Icon(Icons.delete),
                  tooltip: isOwner ? 'Supprimer la forme' : 'Vous ne pouvez supprimer que vos propres formes',
                ),
              );
            })(),
          // Bouton d'ajout en haut à gauche
          if (!_isDrawing)
            Positioned(
              right: 16,
              bottom: 155,
              child: FloatingActionButton(
                heroTag: "routeBtn",
                onPressed: () {
                  if (_currentUserLocation == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Votre position actuelle n\'est pas disponible. Cliquez sur le bouton de localisation.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  setState(() {
                    _isRouteSelectionMode = !_isRouteSelectionMode;
                  });
                },
                backgroundColor: _isRouteSelectionMode ? Colors.blue : null,
                child: const Icon(Icons.route),
                tooltip: 'Sélectionner une destination',
              ),
            ),
          if (!_isDrawing)
            Positioned(
              top: 16, // Même hauteur que le sélecteur de carte
              left: 16,
              child: FloatingActionButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Choisir une forme'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.timeline),
                            title: const Text('Polyline'),
                            onTap: () {
                              Navigator.pop(context);
                              _startDrawing(GeometryType.polyline);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.format_shapes),
                            title: const Text('Polygon'),
                            onTap: () {
                              Navigator.pop(context);
                              _startDrawing(GeometryType.polygon);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.circle),
                            title: const Text('Circle'),
                            onTap: () {
                              Navigator.pop(context);
                              _startDrawing(GeometryType.circle);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                heroTag: 'addGeometry',
                child: const Icon(Icons.architecture),
                backgroundColor: Colors.blue,
                tooltip: 'Ajouter une forme géométrique',
              ),
            ),
        ],
      ),
    );
  }
}

// Classe utilitaire pour les options de couches de carte
class _MapLayerOption {
  final String name;
  final String urlTemplate;
  final String attribution;
  _MapLayerOption({required this.name, required this.urlTemplate, required this.attribution});
}

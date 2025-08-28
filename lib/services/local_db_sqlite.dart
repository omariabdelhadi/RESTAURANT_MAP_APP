import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDbSqlite {
  static Database? _database;
  static const String _userTable = 'users';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }


  static Future<Database> _initDb() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'restaurant.db');
      
      debugPrint('Initialisation de la base de données à : $path');
      
      return await openDatabase(
        path,
        version: 4, // Augmenté à 4 pour ajouter la colonne description à geometries
        onCreate: (db, version) async {
          debugPrint('Création des tables de la base de données (version $version)');
          
          // Table utilisateurs
          await db.execute('''
            CREATE TABLE $_userTable(
              id TEXT PRIMARY KEY,
              username TEXT UNIQUE,
              passwordHash TEXT
            )
          ''');
          debugPrint('Table users créée');
          
          // Table restaurants avec tous les champs
          final restaurantTable = '''
            CREATE TABLE restaurants(
              id TEXT PRIMARY KEY,
              name TEXT,
              description TEXT,
              imageData TEXT,
              coordinates_lat REAL,
              coordinates_lng REAL,
              createdAt TEXT,
              updatedAt TEXT,
              userId TEXT,
              isOpen INTEGER DEFAULT 1,
              employeeCount INTEGER,
              ownerName TEXT,
              ownerDegrees TEXT,
              openingYear INTEGER,
              signatureDishes TEXT,
              cuisineTypes TEXT,
              availableServices TEXT,
              paymentMethods TEXT,
              priceRange TEXT,
              noiseLevel TEXT,
              atmosphere TEXT,
              rating INTEGER,
              ratingComment TEXT,
              FOREIGN KEY (userId) REFERENCES $_userTable(id)
            )
          ''';
          await db.execute(restaurantTable);
          debugPrint('Table restaurants créée');
          
          // Table géométries
          await db.execute('''
            CREATE TABLE geometries(
              id TEXT PRIMARY KEY,
              type TEXT,
              points TEXT,
              radius REAL,
              name TEXT,
              description TEXT,
              createdAt TEXT,
              userId TEXT,
              FOREIGN KEY (userId) REFERENCES $_userTable(id)
            )
          ''');
          debugPrint('Table geometries créée');
          
          debugPrint('Toutes les tables créées avec succès');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          debugPrint('Mise à jour de la base de données de la version $oldVersion vers $newVersion');
          
          if (oldVersion < 4) {
            // Ajouter la colonne description à la table geometries si elle n'existe pas déjà
            try {
              await db.execute('ALTER TABLE geometries ADD COLUMN description TEXT;');
            } catch (e) {
              debugPrint('La colonne description existe peut-être déjà: $e');
            }
          }
          
          if (oldVersion < 3) {
            // Ajouter les nouvelles colonnes à la table restaurants
            await db.execute('''
              ALTER TABLE restaurants ADD COLUMN employeeCount INTEGER;
              ALTER TABLE restaurants ADD COLUMN ownerName TEXT;
              ALTER TABLE restaurants ADD COLUMN ownerDegrees TEXT;
              ALTER TABLE restaurants ADD COLUMN openingYear INTEGER;
              ALTER TABLE restaurants ADD COLUMN signatureDishes TEXT;
              ALTER TABLE restaurants ADD COLUMN cuisineTypes TEXT;
              ALTER TABLE restaurants ADD COLUMN availableServices TEXT;
              ALTER TABLE restaurants ADD COLUMN paymentMethods TEXT;
              ALTER TABLE restaurants ADD COLUMN priceRange TEXT;
              ALTER TABLE restaurants ADD COLUMN noiseLevel TEXT;
              ALTER TABLE restaurants ADD COLUMN rating INTEGER;
              ALTER TABLE restaurants ADD COLUMN ratingComment TEXT;
              ALTER TABLE restaurants ADD COLUMN atmosphere TEXT;
            ''');
          }
        },
      );
    } catch (e, stackTrace) {
      debugPrint('Erreur lors de l\'initialisation de la base de données: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // OPÉRATIONS SUR LES UTILISATEURS
  
  static Future<int> insertUser(Map<String, dynamic> data) async {
    try {
      debugPrint('Tentative d\'insertion d\'un utilisateur: ${data['username']}');
      final db = await database;
      return await db.insert(_userTable, data);
    } catch (e) {
      debugPrint('Erreur lors de l\'insertion de l\'utilisateur: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    try {
      debugPrint('Recherche de l\'utilisateur: $username');
      final db = await database;
      final result = await db.query(
        _userTable,
        where: 'username = ?',
        whereArgs: [username],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      debugPrint('Erreur lors de la recherche de l\'utilisateur: $e');
      rethrow;
    }
  }

  static Future<bool> userExists(String username) async {
    try {
      final db = await database;
      final result = await db.query(
        _userTable,
        where: 'username = ?',
        whereArgs: [username],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Erreur lors de la vérification de l\'existence de l\'utilisateur: $e');
      rethrow;
    }
  }

  // RESTAURANT CRUD
  static Future<int> insertRestaurant(Map<String, dynamic> data) async {
    try {
      debugPrint('Tentative d\'insertion d\'un restaurant avec les données : $data');
      debugPrint('Type de rating : ${data['rating']?.runtimeType}');
      debugPrint('Valeur du rating : ${data['rating']}');
      debugPrint('Type de ratingComment : ${data['ratingComment']?.runtimeType}');
      debugPrint('Valeur du ratingComment : ${data['ratingComment']}');
      final db = await database;
      
      // S'assurer que tous les champs sont présents avec des valeurs par défaut
      final Map<String, dynamic> sanitizedData = {
        ...data,
        'imageData': data['imageData'] ?? '',
        'description': data['description'] ?? '',
        'ownerName': data['ownerName'] ?? '',
        'ownerDegrees': data['ownerDegrees'] ?? '',
        'signatureDishes': data['signatureDishes'] ?? '',
        'cuisineTypes': data['cuisineTypes'] ?? '',
        'availableServices': data['availableServices'] ?? '',
        'paymentMethods': data['paymentMethods'] ?? '',
        'priceRange': data['priceRange'] ?? '',
        'noiseLevel': data['noiseLevel'] ?? '',
        'atmosphere': data['atmosphere'] ?? '',
        'rating': data['rating'],
        'ratingComment': data['ratingComment'] ?? '',
      };
      
      // Vérifier la structure de la table
      var tableInfo = await db.rawQuery("PRAGMA table_info(restaurants)");
      debugPrint('Structure de la table restaurants : $tableInfo');
      
      final result = await db.insert('restaurants', sanitizedData);
      debugPrint('Restaurant inséré avec succès, ID: $result');
      return result;
    } catch (e, stackTrace) {
      debugPrint('Erreur lors de l\'insertion du restaurant: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getRestaurants() async {
    final db = await database;
    return await db.query('restaurants');
  }

  // Récupérer tous les restaurants
  static Future<List<Map<String, dynamic>>> getAllRestaurants() async {
    final db = await database;
    final results = await db.query('restaurants');
    for (var restaurant in results) {
      debugPrint('Restaurant récupéré : ${restaurant['name']}');
      debugPrint('Rating : ${restaurant['rating']}');
      debugPrint('Rating Comment : ${restaurant['ratingComment']}');
    }
    return results;
  }

  // Récupérer les restaurants d'un utilisateur spécifique
  static Future<List<Map<String, dynamic>>> getRestaurantsByUser(String userId) async {
    final db = await database;
    return await db.query('restaurants', where: 'userId = ?', whereArgs: [userId]);
  }
  static Future<int> updateRestaurant(String id, Map<String, dynamic> data) async {
  try {
    final db = await database;
    return await db.update(
      'restaurants',
      data,
      where: 'id = ?',
      whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour: $e');
      rethrow;
    }
  }


  static Future<int> deleteRestaurant(String id) async {
    final db = await database;
    return await db.delete('restaurants', where: 'id = ?', whereArgs: [id]);
  }

  // Récupérer un restaurant spécifique par son ID
  static Future<Map<String, dynamic>?> getRestaurant(String id) async {
    try {
      final db = await database;
      final results = await db.query(
        'restaurants',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      debugPrint('Erreur lors de la récupération du restaurant: $e');
      rethrow;
    }
  }

  // GEOMETRY CRUD
  static Future<int> insertGeometry(Map<String, dynamic> data) async {
    final db = await database;
    // points must be encoded as JSON string
    return await db.insert('geometries', data);
  }

  static Future<List<Map<String, dynamic>>> getGeometries() async {
    final db = await database;
    return await db.query('geometries');
  }

  // Récupérer les géométries d'un utilisateur spécifique
  static Future<List<Map<String, dynamic>>> getGeometriesByUser(String userId) async {
    final db = await database;
    return await db.query('geometries', where: 'userId = ?', whereArgs: [userId]);
  }

  static Future<int> deleteGeometry(String id) async {
    final db = await database;
    return await db.delete('geometries', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> updateGeometry(String id, Map<String, dynamic> data) async {
    try {
      debugPrint('Mise à jour de la géométrie avec l\'ID: $id');
      debugPrint('Données de mise à jour: $data');
      
      final db = await database;
      final result = await db.update(
        'geometries',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
      
      debugPrint('Mise à jour réussie, nombre de lignes affectées: $result');
      return result;
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour de la géométrie: $e');
      rethrow;
    }
  }
}
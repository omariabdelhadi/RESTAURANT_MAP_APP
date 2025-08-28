// lib/services/local_db.dart

import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

import '../models/restaurant_model.dart';
import '../models/geometry_model.dart';

// Use the web database factory for web-only support
final DatabaseFactory _dbFactory = databaseFactoryWeb;

class LocalDatabase {
  static const String _userStoreName = 'users';
  static const String _restaurantStoreName = 'restaurants';
  static const String _geometryStoreName = 'geometries';

  late Database _db;
  late StoreRef<String, Map<String, dynamic>> _userStore;
  late StoreRef<String, Map<String, dynamic>> _restaurantStore;
  late StoreRef<String, Map<String, dynamic>> _geometryStore;

  static final LocalDatabase _singleton = LocalDatabase._();

  LocalDatabase._();

  static LocalDatabase get instance => _singleton;

  Future<void> init() async {
    String dbPath = 'restaurant_app.db';
    _db = await _dbFactory.openDatabase(dbPath);

    _userStore = stringMapStoreFactory.store(_userStoreName);
    _restaurantStore = stringMapStoreFactory.store(_restaurantStoreName);
    _geometryStore = stringMapStoreFactory.store(_geometryStoreName);
  }

  // Méthodes utilisateur

  Future<bool> createUser(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final users = prefs.getString('users') ?? '{}';
    final usersMap = json.decode(users) as Map<String, dynamic>;

    if (usersMap.containsKey(username)) {
      return false; // utilisateur existe déjà
    }

    usersMap[username] = password;
    await prefs.setString('users', json.encode(usersMap));
    return true;
  }

  Future<bool> authenticateUser(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final users = prefs.getString('users') ?? '{}';
    final usersMap = json.decode(users) as Map<String, dynamic>;

    return usersMap[username] == password;
  }

  // Méthodes restaurants

  Future<void> saveRestaurant(Restaurant restaurant) async {
    await _restaurantStore.record(restaurant.id).put(_db, restaurant.toJson());
  }
  Future<List<Restaurant>> getAllRestaurantsForUser(String userId) async {
  final records = await _restaurantStore.find(_db);
  return records
      .map((r) => Restaurant.fromJson(r.value))
      .where((r) => r.userId == userId)
      .toList();
  }
  Future<List<MapGeometry>> getAllGeometriesForUser(String userId) async {
  final records = await _geometryStore.find(_db);
  return records
      .map((r) => MapGeometry.fromJson(r.value))
      .where((g) => g.userId == userId)
      .toList();
  }
  Future<Restaurant?> getRestaurant(String id) async {
    final record = await _restaurantStore.record(id).get(_db);
    if (record == null) return null;
    return Restaurant.fromJson(record);
  }

  Future<List<Restaurant>> getAllRestaurants() async {
    final records = await _restaurantStore.find(_db);
    return records.map((r) => Restaurant.fromJson(r.value)).toList();
  }

  Future<void> deleteRestaurant(String id) async {
    await _restaurantStore.record(id).delete(_db);
  }

  // Méthodes géométrie

  Future<void> saveGeometry(MapGeometry geometry) async {
    await _geometryStore.record(geometry.id).put(_db, geometry.toJson());
  }

  Future<MapGeometry?> getGeometry(String id) async {
    final record = await _geometryStore.record(id).get(_db);
    if (record == null) return null;
    return MapGeometry.fromJson(record);
  }

  Future<List<MapGeometry>> getAllGeometries() async {
    final records = await _geometryStore.find(_db);
    return records.map((r) => MapGeometry.fromJson(r.value)).toList();
  }

  Future<void> deleteGeometry(String id) async {
    await _geometryStore.record(id).delete(_db);
  }

  Future<User?> getUserByUsername(String username) async {
    final record = await _userStore.record(username).get(_db);
    if (record == null) return null;
    return User.fromJson(record);
  }

  Future<bool> userExists(String username) async {
    final record = await _userStore.record(username).get(_db);
    return record != null;
  }

  Future<void> saveUser(User user) async {
    await _userStore.record(user.username).put(_db, user.toJson());
  }
}

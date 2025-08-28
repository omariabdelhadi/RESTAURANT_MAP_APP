import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'dart:convert';

class SessionManager extends ChangeNotifier {
  User? _currentUser;
  final SharedPreferences _prefs;
  static const String _userKey = 'current_user';

  SessionManager._(this._prefs) {
    _loadUser();
  }

  User? get currentUser => _currentUser;

  static Future<SessionManager> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SessionManager._(prefs);
  }

  void _loadUser() {
    try {
      final userJson = _prefs.getString(_userKey);
      if (userJson != null) {
        final Map<String, dynamic> userData = json.decode(userJson);
        _currentUser = User.fromJson(userData);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement de la session: $e');
      _prefs.remove(_userKey);
      _currentUser = null;
    }
  }

  Future<void> login(User user) async {
    try {
      await _prefs.setString(_userKey, json.encode(user.toJson()));
      _currentUser = user;
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur lors de la connexion: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _prefs.remove(_userKey);
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur lors de la déconnexion: $e');
      rethrow;
    }
  }

  bool get isLoggedIn => _currentUser != null;
}

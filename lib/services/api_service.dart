import 'package:dio/dio.dart';
import '../models/restaurant_model.dart';
import '../models/geometry_model.dart';

class ApiService {
  static const String _baseUrl = 'http://localhost:8000/api'; // Change this to your actual API URL
  final Dio _dio;

  ApiService() : _dio = Dio(BaseOptions(baseUrl: _baseUrl));

  // Authentication
  Future<String?> login(String username, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'username': username,
        'password': password,
      });
      return response.data['token'];
    } on DioException {
      return null;
    }
  }

  Future<bool> register(String username, String password) async {
    try {
      final response = await _dio.post('/auth/register', data: {
        'username': username,
        'password': password,
      });
      return response.statusCode == 201;
    } on DioException {
      return false;
    }
  }

  // Restaurant CRUD operations
  Future<List<Restaurant>> getRestaurants() async {
    try {
      final response = await _dio.get('/restaurants');
      return (response.data as List)
          .map((json) => Restaurant.fromJson(json))
          .toList();
    } on DioException {
      return [];
    }
  }

  Future<Restaurant?> getRestaurant(String id) async {
    try {
      final response = await _dio.get('/restaurants/$id');
      return Restaurant.fromJson(response.data);
    } on DioException {
      return null;
    }
  }

  Future<Restaurant?> createRestaurant(Restaurant restaurant) async {
    try {
      final response = await _dio.post(
        '/restaurants',
        data: restaurant.toJson(),
      );
      return Restaurant.fromJson(response.data);
    } on DioException {
      return null;
    }
  }

  Future<Restaurant?> updateRestaurant(Restaurant restaurant) async {
    try {
      final response = await _dio.put(
        '/restaurants/${restaurant.id}',
        data: restaurant.toJson(),
      );
      return Restaurant.fromJson(response.data);
    } on DioException {
      return null;
    }
  }

  Future<bool> deleteRestaurant(String id) async {
    try {
      await _dio.delete('/restaurants/$id');
      return true;
    } on DioException {
      return false;
    }
  }

  // Geometry CRUD operations
  Future<List<MapGeometry>> getGeometries() async {
    try {
      final response = await _dio.get('/geometries');
      return (response.data as List)
          .map((json) => MapGeometry.fromJson(json))
          .toList();
    } on DioException {
      return [];
    }
  }

  Future<MapGeometry?> getGeometry(String id) async {
    try {
      final response = await _dio.get('/geometries/$id');
      return MapGeometry.fromJson(response.data);
    } on DioException {
      return null;
    }
  }

  Future<MapGeometry?> createGeometry(MapGeometry geometry) async {
    try {
      final response = await _dio.post(
        '/geometries',
        data: geometry.toJson(),
      );
      return MapGeometry.fromJson(response.data);
    } on DioException {
      return null;
    }
  }

  Future<MapGeometry?> updateGeometry(MapGeometry geometry) async {
    try {
      final response = await _dio.put(
        '/geometries/${geometry.id}',
        data: geometry.toJson(),
      );
      return MapGeometry.fromJson(response.data);
    } on DioException {
      return null;
    }
  }

  Future<bool> deleteGeometry(String id) async {
    try {
      await _dio.delete('/geometries/$id');
      return true;
    } on DioException {
      return false;
    }
  }
}

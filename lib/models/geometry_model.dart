import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:tuple/tuple.dart';

enum GeometryType {
  point,
  polyline,
  polygon,
  circle,
}

class MapGeometry {
  final String id;
  final GeometryType type;
  final List<LatLng> points;
  final double? radius; // Only for circles
  final String? name;
  final String? description; // Added description field
  final DateTime createdAt;
  final String userId;
  
  MapGeometry({
    required this.id,
    required this.type,
    required this.points,
    this.radius,
    this.name,
    this.description,
    required this.createdAt,
    required this.userId,
  });

  factory MapGeometry.fromJson(Map<String, dynamic> json) {
    return MapGeometry(
      id: json['id'] as String,
      type: GeometryType.values.firstWhere(
        (e) => e.toString() == 'GeometryType.${json['type']}',
      ),
      points: (json['points'] as List<dynamic>).map((point) {
        return LatLng(
          point['latitude'] as double,
          point['longitude'] as double,
        );
      }).toList(),
      radius: json['radius'] as double?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      userId: json['userId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'points': points.map((point) => {
        'latitude': point.latitude,
        'longitude': point.longitude,
      }).toList(),
      'radius': radius,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'userId': userId,
    };
  }

  // Helper method to convert to appropriate Flutter Map objects
  dynamic toMapObject({Color color = const Color(0xFF2196F3)}) {
    switch (type) {
      case GeometryType.point:
        return Marker(
          width: 30.0,
          height: 30.0,
          point: points.first,
          child: Icon(Icons.location_pin, color: color),
        );
      case GeometryType.polyline:
        return Polyline(
          points: points,
          strokeWidth: 2.0,
          color: color,
        );
      case GeometryType.polygon:
        return Polygon(
          points: points,
          color: color.withOpacity(0.2),
          borderColor: color,
          borderStrokeWidth: 2.0,
        );
      case GeometryType.circle:
        return CircleMarker(
          point: points.first,
          radius: radius ?? 50.0,
          color: color.withOpacity(0.2),
          borderColor: color,
          borderStrokeWidth: 2.0,
        );
    }
  }
}

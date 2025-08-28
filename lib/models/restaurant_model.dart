import 'package:latlong2/latlong.dart';

class Restaurant {
  final String id;
  final String name;
  final String? description;
  final List<String> images; // Liste des images en base64
  final LatLng coordinates;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;
  final bool isOpen;
  final int? employeeCount;
  final String? ownerName;
  final String? ownerDegrees;
  final int? openingYear;
  final String? signatureDishes;
  final List<String> cuisineTypes;
  final List<String> availableServices;
  final List<String> paymentMethods;
  final String? priceRange;
  final String? noiseLevel;
  final String? atmosphere;
  final int? rating;
  final String? ratingComment;

  Restaurant({
    required this.id,
    required this.name,
    this.description,
    required this.images,
    required this.coordinates,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    required this.isOpen,
    this.employeeCount,
    this.ownerName,
    this.ownerDegrees,
    this.openingYear,
    this.signatureDishes,
    this.cuisineTypes = const [],
    this.availableServices = const [],
    this.paymentMethods = const [],
    this.priceRange,
    this.noiseLevel,
    this.atmosphere,
    this.rating,
    this.ratingComment,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    // Convertir la chaîne d'images séparées par des virgules en liste
    List<String> imagesList = [];
    if (json['imageData'] != null) {
      imagesList = (json['imageData'] as String).split(',').where((img) => img.isNotEmpty).toList();
    }

    return Restaurant(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      images: imagesList,
      coordinates: LatLng(
        json['coordinates_lat'] as double,
        json['coordinates_lng'] as double,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      userId: json['userId'] as String,
      isOpen: (json['isOpen'] as int?) == 1,
      employeeCount: json['employeeCount'] as int?,
      ownerName: json['ownerName'] as String?,
      ownerDegrees: json['ownerDegrees'] as String?,
      openingYear: json['openingYear'] as int?,
      signatureDishes: json['signatureDishes'] as String?,
      cuisineTypes: json['cuisineTypes'] != null ? (json['cuisineTypes'] as String).split(',').where((s) => s.isNotEmpty).toList() : [],
      availableServices: json['availableServices'] != null ? (json['availableServices'] as String).split(',').where((s) => s.isNotEmpty).toList() : [],
      paymentMethods: json['paymentMethods'] != null ? (json['paymentMethods'] as String).split(',').where((s) => s.isNotEmpty).toList() : [],
      priceRange: json['priceRange'] as String?,
      noiseLevel: json['noiseLevel'] as String?,
      atmosphere: json['atmosphere'] as String?,
      rating: json['rating'] != null 
        ? (json['rating'] is String 
            ? int.tryParse(json['rating'])
            : json['rating'] as int?)
        : null,
      ratingComment: json['ratingComment'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageData': images.join(','),
      'coordinates_lat': coordinates.latitude,
      'coordinates_lng': coordinates.longitude,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'userId': userId,
      'isOpen': isOpen ? 1 : 0,
      'employeeCount': employeeCount,
      'ownerName': ownerName,
      'ownerDegrees': ownerDegrees,
      'openingYear': openingYear,
      'signatureDishes': signatureDishes,
      'cuisineTypes': cuisineTypes.join(','),
      'availableServices': availableServices.join(','),
      'paymentMethods': paymentMethods.join(','),
      'priceRange': priceRange,
      'noiseLevel': noiseLevel,
      'atmosphere': atmosphere,
      'rating': rating,
      'ratingComment': ratingComment?.isEmpty == true ? null : ratingComment,
    };
  }

  Restaurant copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? images,
    LatLng? coordinates,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    bool? isOpen,
    int? employeeCount,
    String? ownerName,
    String? ownerDegrees,
    int? openingYear,
    String? signatureDishes,
    List<String>? cuisineTypes,
    List<String>? availableServices,
    List<String>? paymentMethods,
    String? priceRange,
    String? noiseLevel,
    String? atmosphere,
    int? rating,
    String? ratingComment,
  }) {
    return Restaurant(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      images: images ?? this.images,
      coordinates: coordinates ?? this.coordinates,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      isOpen: isOpen ?? this.isOpen,
      employeeCount: employeeCount ?? this.employeeCount,
      ownerName: ownerName ?? this.ownerName,
      ownerDegrees: ownerDegrees ?? this.ownerDegrees,
      openingYear: openingYear ?? this.openingYear,
      signatureDishes: signatureDishes ?? this.signatureDishes,
      cuisineTypes: cuisineTypes ?? this.cuisineTypes,
      availableServices: availableServices ?? this.availableServices,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      priceRange: priceRange ?? this.priceRange,
      noiseLevel: noiseLevel ?? this.noiseLevel,
      atmosphere: atmosphere ?? this.atmosphere,
      rating: rating ?? this.rating,
      ratingComment: ratingComment ?? this.ratingComment,
    );
  }
}

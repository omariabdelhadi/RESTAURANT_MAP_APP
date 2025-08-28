import 'package:flutter/foundation.dart';

class User {
  final String id;
  final String username;
  final String? passwordHash;  // Optional for session storage

  User({
    required this.id,
    required this.username,
    this.passwordHash,  // Made optional
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      passwordHash: json['passwordHash'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'passwordHash': passwordHash,
    };
  }
}

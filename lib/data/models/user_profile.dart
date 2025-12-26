import 'package:hive/hive.dart';

part 'user_profile.g.dart';

/// User profile model
@HiveType(typeId: 0)
class UserProfile {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String email;

  @HiveField(2)
  final String? pilotType; // 'Student' | 'Instructor'

  @HiveField(3)
  final String? licenseType; // 'FAA' | 'EASA'

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final DateTime updatedAt;

  @HiveField(6)
  final String? fullName;

  UserProfile({
    required this.id,
    required this.email,
    this.pilotType,
    this.licenseType,
    this.fullName,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Create from Supabase response
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      pilotType: json['pilot_type'] as String?,
      licenseType: json['license_type'] as String?,
      fullName: json['full_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  /// Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'pilot_type': pilotType,
      'license_type': licenseType,
      'full_name': fullName,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with modified fields
  UserProfile copyWith({
    String? id,
    String? email,
    String? pilotType,
    String? licenseType,
    String? fullName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      pilotType: pilotType ?? this.pilotType,
      licenseType: licenseType ?? this.licenseType,
      fullName: fullName ?? this.fullName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Check if profile is complete (has pilot type and license type)
  bool get isComplete => pilotType != null && licenseType != null;
  
  /// Get display name (full name or email)
  String get displayName => fullName ?? email.split('@').first;
}

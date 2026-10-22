class UserLocationModel {
  final String userId;
  final String username;
  final String fullName;
  final String role;
  final double? latitude;
  final double? longitude;
  final String? address;
  final bool isSharingLocation;
  final DateTime? lastLocationUpdatedAt;
  final double? distanceInKm;

  UserLocationModel({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.role,
    this.latitude,
    this.longitude,
    this.address,
    required this.isSharingLocation,
    this.lastLocationUpdatedAt,
    this.distanceInKm,
  });

  factory UserLocationModel.fromJson(Map<String, dynamic> json) {
    return UserLocationModel(
      userId: json['userId']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      address: json['address']?.toString(),
      isSharingLocation: json['isSharingLocation'] == true,
      lastLocationUpdatedAt: json['lastLocationUpdatedAt'] != null
          ? DateTime.tryParse(json['lastLocationUpdatedAt'].toString())
          : null,
      distanceInKm: json['distanceInKm'] != null
          ? (json['distanceInKm'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'fullName': fullName,
      'role': role,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'isSharingLocation': isSharingLocation,
      'lastLocationUpdatedAt': lastLocationUpdatedAt?.toIso8601String(),
      'distanceInKm': distanceInKm,
    };
  }
}

class LocationHistoryModel {
  final int id;
  final double latitude;
  final double longitude;
  final String? address;
  final double? speed;
  final DateTime recordedAt;

  LocationHistoryModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.address,
    this.speed,
    required this.recordedAt,
  });

  factory LocationHistoryModel.fromJson(Map<String, dynamic> json) {
    return LocationHistoryModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      address: json['address']?.toString(),
      speed: json['speed'] != null ? (json['speed'] as num).toDouble() : null,
      recordedAt: json['recordedAt'] != null
          ? DateTime.tryParse(json['recordedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

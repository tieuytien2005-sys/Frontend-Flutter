class UserModel {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String role;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Role can be a single string or a list of roles
    String parsedRole = 'Customer';
    if (json['roles'] is List && (json['roles'] as List).isNotEmpty) {
      parsedRole = (json['roles'] as List).first.toString();
    } else if (json['role'] != null) {
      parsedRole = json['role'].toString();
    }

    return UserModel(
      id: (json['id'] ?? json['userId'] ?? '').toString(),
      username: (json['username'] ?? json['userName'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: (json['fullName'] ?? json['name'] ?? json['username'] ?? '').toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      role: parsedRole,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'role': role,
    };
  }
}

class UpdateUserRequest {
  final String fullName;
  final String? phoneNumber;

  UpdateUserRequest({
    required this.fullName,
    this.phoneNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      if (phoneNumber != null && phoneNumber!.isNotEmpty) 'phoneNumber': phoneNumber,
    };
  }
}

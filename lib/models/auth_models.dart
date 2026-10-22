import 'dart:convert';

class RegisterRequest {
  final String fullName;
  final String username;
  final String email;
  final String password;
  final String role;

  RegisterRequest({
    required this.fullName,
    required this.username,
    required this.email,
    required this.password,
    required this.role,
  });

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'username': username,
      'email': email,
      'password': password,
      'role': role,
    };
  }
}

class LoginStep1Request {
  final String username;
  final String password;

  LoginStep1Request({
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
    };
  }
}

class VerifyOtpRequest {
  final String username;
  final String otpCode;

  VerifyOtpRequest({
    required this.username,
    required this.otpCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'otpCode': otpCode,
    };
  }
}

class AuthResponse {
  final String? token;
  final String? username;
  final String? role;
  final String? email;
  final String? fullName;
  final String? message;
  final bool isSuccess;

  AuthResponse({
    this.token,
    this.username,
    this.role,
    this.email,
    this.fullName,
    this.message,
    this.isSuccess = true,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    String? token = json['token'] ?? json['accessToken'] ?? json['jwt'];
    String? role = json['role'] ?? json['roles']?.toString();
    String? username = json['username'] ?? json['userName'];
    String? email = json['email'];
    String? fullName = json['fullName'] ?? json['name'];
    String? message = json['message'] ?? json['msg'];

    // If role or username is not in top-level JSON, attempt to extract from JWT claims
    if (token != null && token.isNotEmpty) {
      try {
        final claims = _decodeJwtPayload(token);
        role ??= claims['role'] ??
            claims['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'];
        username ??= claims['unique_name'] ??
            claims['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'] ??
            claims['sub'];
        email ??= claims['email'] ??
            claims['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'];
      } catch (_) {}
    }

    return AuthResponse(
      token: token,
      username: username,
      role: role,
      email: email,
      fullName: fullName,
      message: message,
      isSuccess: true,
    );
  }

  static Map<String, dynamic> _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      return {};
    }
    final normalized = base64Url.normalize(parts[1]);
    final resp = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(resp) as Map<String, dynamic>;
  }
}
